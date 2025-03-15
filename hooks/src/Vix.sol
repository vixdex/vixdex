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
import "forge-std/console.sol";  // Foundry's console library
contract Vix is BaseHook{
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using Volatility for int;
    mapping(address=>mapping(address=>bool)) public isPairInitiated;
    mapping(address=>mapping(address=>uint)) public pairInitiatedTime;
    mapping(address=>mapping(address=>uint)) public pairEndingTime;
    struct VixTokenData {
        address VIXHIGHTOKEN;
        address VIXLOWTOKEN;
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
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

     function _beforeAddLiquidity(address, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata , bytes calldata)internal view override  returns (bytes4){
         
            return this.beforeAddLiquidity.selector;
     }

    function _afterAddLiquidity(address,PoolKey calldata key,IPoolManager.ModifyLiquidityParams calldata,BalanceDelta delta,BalanceDelta,bytes calldata) internal override returns (bytes4, BalanceDelta){
                      return (this.afterAddLiquidity.selector, delta);

    }

    function _afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata) internal override returns (bytes4, int128){

        return (this.afterSwap.selector, 0);
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
        vixTokens[_currency0][_currency1] = VixTokenData(vixTokenAddresses[0],vixTokenAddresses[1]);
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

            address VHT = vixTokens[_currency0][_currency1].VIXHIGHTOKEN;
            address VLT = vixTokens[_currency0][_currency1].VIXLOWTOKEN;
            VolatileERC20 VHTContract = VolatileERC20(VHT);
            VolatileERC20 VLTContract = VolatileERC20(VLT);


            (address[2] memory vixAdd)  = deploy2Currency(_currency0,_currency1,[VHTContract.name(),VLTContract.name()],[VHTContract.symbol(),VLTContract.symbol()], deadline);
            return vixAdd;
        }else{
            revert("Pair not expired");
            return [address(0),address(0)];
        }
    }


}