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
    mapping(uint256=>mapping(uint256=>bool)) public isPairInitiated;
    mapping(uint256=>mapping(uint256=>uint)) public pairInitiatedTime;
    mapping(uint256=>mapping(uint256=>uint)) public pairEndingTime;
    struct VixTokenData {
        address VIXHIGHTOKEN;
        address VIXLOWTOKEN;
    }

    mapping(uint256=>mapping(uint256=>VixTokenData)) vixTokens;
    address public USDC;

    //initiating BaseHook with IPoolManager
    constructor(IPoolManager _poolManager,address _usdc) BaseHook(_poolManager) {
        USDC = _usdc;
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


    function deploy2Currency(uint256 _currency1Id,uint256 _currency2Id, string[2] memory _tokenName, string[2] memory _tokenSymbol,uint deadline) public returns(address[2] memory){
        console.log("isPairInitiated: ",isPairInitiated[_currency1Id][_currency2Id]);
        console.log("pairEndingTime: ",pairEndingTime[_currency1Id][_currency2Id]);
        console.log("deadline: ",block.timestamp);
        require((isPairInitiated[_currency1Id][_currency2Id] == false || pairEndingTime[_currency1Id][_currency2Id] < block.timestamp),"Pair still active");
        require(isPairedWithUSDC(_currency1Id, _currency2Id),"Pair not paired with USDC");
        isPairInitiated[_currency1Id][_currency2Id] = true;
        pairInitiatedTime[_currency1Id][_currency2Id] = block.timestamp;
        pairEndingTime[_currency1Id][_currency2Id] = block.timestamp + deadline;
        address[2] memory vixTokenAddresses;
        for(uint i = 0; i < 2; i++){
            uint twentyFourHours = 3600 * 24;

            VolatileERC20 v_token = new VolatileERC20(_tokenName[i], _tokenSymbol[i],twentyFourHours);
            vixTokenAddresses[i] = address(v_token);
            mintVixToken(address(this),address(v_token),250 * 1000000 * (10**18));
        }
        vixTokens[_currency1Id][_currency2Id] = VixTokenData(vixTokenAddresses[0],vixTokenAddresses[1]);
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

    function isPairedWithUSDC(uint256 currency_id0, uint256 currency_id1) public view returns (bool){
        bool isUsdc = currency_id0 == uint256(uint160(USDC)) || currency_id1 == uint256(uint160(USDC));
        require(isUsdc == true,"only USDC pair");
        return true;
    }

    function resetPair(uint256 currency_id0, uint256 currency_id1,uint deadline) public returns (address[2] memory) {
        require(isPairInitiated[currency_id0][currency_id1] == true,"Pair not initiated");
        if(pairEndingTime[currency_id0][currency_id1] < block.timestamp){

            address VHT = vixTokens[currency_id0][currency_id1].VIXHIGHTOKEN;
            address VLT = vixTokens[currency_id0][currency_id1].VIXLOWTOKEN;
            VolatileERC20 VHTContract = VolatileERC20(VHT);
            VolatileERC20 VLTContract = VolatileERC20(VLT);


            (address[2] memory vixAdd)  = deploy2Currency(currency_id0,currency_id1,[VHTContract.name(),VLTContract.name()],[VHTContract.symbol(),VLTContract.symbol()], deadline);
            return vixAdd;
        }else{
            revert("Pair not expired");
            return [address(0),address(0)];
        }
    }


}