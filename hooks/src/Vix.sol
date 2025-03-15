// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency,CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Volatility} from "./lib/Volatility.sol";
import {VolatileERC20} from "./VolatileERC20.sol";
import {BondingCurve} from "./lib/BondingCurve.sol";
import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import "forge-std/console.sol";  // Foundry's console library
contract Vix is BaseHook{
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using Volatility for int;
    using BondingCurve for uint;

    error invalidLiquidityAction();
    mapping(address=>mapping(address=>bool)) public isPairInitiated;
    mapping(address=>mapping(address=>uint)) public pairInitiatedTime;
    mapping(address=>mapping(address=>uint)) public pairEndingTime;
    uint constant public SLOPE = 300; //0.03% || 0.0003
    uint constant public FEE = 10000; //1% || 0.01
    uint constant public BASE_PRICE = 0.0000060 * 1e18;
    struct VixTokenData {
        address vixHighToken;
        address vixLowToken;
        uint price0;
        uint price1;
        uint circulation0;
        uint circulation1;
        uint contractHoldings0;
        uint contractHoldings1;
        uint reserve0;
        uint reserve1;
    }

    mapping(address=>mapping(address=>VixTokenData)) vixTokens;
    address public baseToken;

    //initiating BaseHook with IPoolManager
    constructor(IPoolManager _poolManager,address _baseToken) BaseHook(_poolManager) {
        baseToken = _baseToken;
    }

    //getting Hook permission  
    function getHookPermissions() public pure override returns (Hooks.Permissions memory){
            return Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: true,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

     function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata , bytes calldata)internal view override  returns (bytes4){
         revert invalidLiquidityAction();
     }

    
     function _beforeRemoveLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata , bytes calldata)internal view override  returns (bytes4){
         revert invalidLiquidityAction();
     }

    
    function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata data) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        uint256 amountInOutPositive = params.amountSpecified > 0? uint256(params.amountSpecified): uint256(-params.amountSpecified);
        if(params.zeroForOne){
            if(params.amountSpecified  < 0){
                address _currency0 = Currency.unwrap(key.currency0);
                address _currency1 = Currency.unwrap(key.currency1);
                uint circulation = vixTokens[_currency0][_currency1].circulation0;
                uint tokenForGivenCost = circulation.tokensForGivenCost(amountInOutPositive,SLOPE,FEE,BASE_PRICE);
                console.log("tokenForGivenCost: ",tokenForGivenCost);
            }

        }else{

        }
        //BeforeSwapDelta beforeSwapDelta = toBeforeSwapDelta(-1,1); // (specified , unspecified) )
        return (this.beforeSwap.selector,BeforeSwapDeltaLibrary.ZERO_DELTA , 0);
    }


    function deploy2Currency(address _currency0,address _currency1, string[2] memory _tokenName, string[2] memory _tokenSymbol,uint deadline) public returns(address[2] memory){
        console.log("isPairInitiated: ",isPairInitiated[_currency0][_currency1]);
        console.log("pairEndingTime: ",pairEndingTime[_currency0][_currency1]);
        console.log("deadline: ",block.timestamp);
        require((isPairInitiated[_currency0][_currency1] == false || pairEndingTime[_currency0][_currency1] < block.timestamp),"Pair still active");
        require(isPairedWithBaseToken(_currency0, _currency1),"Pair not paired with Base Token");
        isPairInitiated[_currency0][_currency1] = true;
        pairInitiatedTime[_currency0][_currency1] = block.timestamp;
        pairEndingTime[_currency0][_currency1] = block.timestamp + deadline;
        address[2] memory vixTokenAddresses;
        for(uint i = 0; i < 2; i++){
            uint twentyFourHours = 3600 * 24;

            VolatileERC20 v_token = new VolatileERC20(_tokenName[i], _tokenSymbol[i],twentyFourHours);
            vixTokenAddresses[i] = address(v_token);
            mintVixToken(address(this),address(v_token),250 * 1000000 * (10**18));
        }
        vixTokens[_currency0][_currency1] = VixTokenData(vixTokenAddresses[0],vixTokenAddresses[1],BASE_PRICE,BASE_PRICE,0,0,0,0,0,0);
        return (vixTokenAddresses);
    }

    function transferVixtoken(address to, uint256 value, address _token) public returns (bool) {
       VolatileERC20 v_token = VolatileERC20(_token);
        v_token.transfer(to, value);
        return true;
    }

    function mintVixToken(address to,address _token,uint _amount) internal returns (bool){
        VolatileERC20 v_token = VolatileERC20(_token);
        v_token.mint(to, _amount);
        return true;
    }

function isPairedWithBaseToken(address _currency0, address _currency1) public view returns (bool) {
    bool isValid = (_currency0 == baseToken) || (_currency1 == baseToken);

    require(isValid, "Pair not paired with base token");
    return true;
}

    function resetPair(address _currency0, address _currency1,uint deadline) public returns (address[2] memory) {
        require(isPairInitiated[_currency0][_currency1] == true,"Pair not initiated");
        if(pairEndingTime[_currency0][_currency1] < block.timestamp){

            address VHT = vixTokens[_currency0][_currency1].vixHighToken;
            address VLT = vixTokens[_currency0][_currency1].vixLowToken;
            VolatileERC20 VHTContract = VolatileERC20(VHT);
            VolatileERC20 VLTContract = VolatileERC20(VLT);


            (address[2] memory vixAdd)  = deploy2Currency(_currency0,_currency1,[VHTContract.name(),VLTContract.name()],[VHTContract.symbol(),VLTContract.symbol()], deadline);
            return vixAdd;
        }else{
            revert("Pair not expired");
        }
    }


}