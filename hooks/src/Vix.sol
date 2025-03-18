// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency,CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
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
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;
    using Volatility for int;
    using BondingCurve for uint;

    error invalidLiquidityAction();
    mapping(address=>bool) public isPairInitiated;
    mapping(address=>uint) public pairInitiatedTime;
    mapping(address=>uint) public pairEndingTime;
    uint constant public SLOPE = 300; //0.03% || 0.0003
    uint constant public FEE = 10000; //1% || 0.01
    uint constant public BASE_PRICE = 0.0000060 * 1e18;
    uint constant public IV_TOKEN_SUPPLY = 250 * 1000000 * (10**18);
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

    mapping(address=>VixTokenData) vixTokens;
    address public baseToken;

    struct CallbackData {
    uint256 amountEach; 
    Currency currency0;
    Currency currency1;
    address sender;
    }


    //initiating BaseHook with IPoolManager
    constructor(IPoolManager poolManager,address _baseToken) BaseHook(poolManager) {
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

    
    function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata data) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        BeforeSwapDelta beforeSwapDelta;
        uint256 amountInOutPositive = params.amountSpecified > 0 
        ? uint256(params.amountSpecified) 
        : uint256(-params.amountSpecified);

        address _deriveAsset = abi.decode(data, (address));
        if(params.zeroForOne){

            bool zeroIsBase = (Currency.unwrap(key.currency0) == baseToken );
            (int128 _deltaSpecified, int128 _deltaUnspecified) = zeroForOneOperator(key, _deriveAsset, params, amountInOutPositive,zeroIsBase);
            beforeSwapDelta = toBeforeSwapDelta(_deltaSpecified, _deltaUnspecified);
            
        }else{

        }
        return (this.beforeSwap.selector,beforeSwapDelta, 0);
    }
function zeroForOneOperator(PoolKey calldata key,address _deriveAsset,IPoolManager.SwapParams calldata params,uint amountInOutPositive,bool zeroIsBase) public returns(int128,int128) {
    VixTokenData storage vixTokenData = vixTokens[_deriveAsset];
    console.log("currency0: ",Currency.unwrap(key.currency0));
    console.log("currency1: ",Currency.unwrap(key.currency1));
    console.log("vixHighToken: ",vixTokenData.vixHighToken);
    console.log("vixLowToken: ",vixTokenData.vixLowToken);
    address _currency0 = Currency.unwrap(key.currency0);
    address _currency1 = Currency.unwrap(key.currency1);
    int128 _deltaSpecified;
    int128 _deltaUnspecified;
    bool isHighToken = (_currency0 == vixTokenData.vixHighToken || _currency1 == vixTokenData.vixHighToken);
    bool isExactIn = params.amountSpecified < 0;
    
    if (isHighToken) {
        console.log("isHighToken");
        uint circulation0 = vixTokenData.circulation0;
        if (isExactIn) {
            if (zeroIsBase) {
                // Buying vixHighToken with exact input
               (uint _tokenReturns) =  circulation0.tokensForGivenCost(amountInOutPositive,SLOPE,FEE,BASE_PRICE);
               uint tokenReturns = _tokenReturns * 1e18;
               vixTokens[_deriveAsset].contractHoldings0 += tokenReturns;
               vixTokens[_deriveAsset].circulation0 += tokenReturns;
               vixTokens[_deriveAsset].reserve0 += amountInOutPositive;
                key.currency0.take(
                    poolManager,
                    address(this),
                    amountInOutPositive,
                    true
                );
                console.log("take passed");


                key.currency1.settle(
                    poolManager,
                    address(this),
                    tokenReturns,
                    true
                );

                console.log("settle passed");

                _deltaSpecified = int128(uint128(amountInOutPositive));
                _deltaUnspecified = -int128(uint128(tokenReturns));
            } else {
                // Selling vixHighToken with exact input
            }
        } else {
            if (zeroIsBase) {
                // Buying vixHighToken with exact output
            } else {
                // Selling vixHighToken with exact output
            }
        }
    } else {
                console.log("low iv token");
        if (isExactIn) {
            if (zeroIsBase) {
                // Buying vixLowToken with exact input
            } else {
                // Selling vixLowToken with exact input
            }
        } else {
            if (zeroIsBase) {
                // Buying vixLowToken with exact output
            } else {
                // Selling vixLowToken with exact output
            }
        }
    }

    return (_deltaSpecified, _deltaUnspecified);
}

    function oneForZeroOperator() public{

    }


    function deploy2Currency(address deriveToken, string[2] memory _tokenName, string[2] memory _tokenSymbol,uint deadline) public returns(address[2] memory){
        console.log("isPairInitiated: ",isPairInitiated[deriveToken]);
        console.log("pairEndingTime: ",pairEndingTime[deriveToken]);
        console.log("deadline: ",block.timestamp);
        require((isPairInitiated[deriveToken] == false || pairEndingTime[deriveToken] < block.timestamp),"Pair still active");
        isPairInitiated[deriveToken] = true;
        pairInitiatedTime[deriveToken] = block.timestamp;
        pairEndingTime[deriveToken] = block.timestamp + deadline;
        address[2] memory vixTokenAddresses;
        for(uint i = 0; i < 2; i++){
            uint twentyFourHours = 3600 * 24;

            VolatileERC20 v_token = new VolatileERC20(_tokenName[i], _tokenSymbol[i],twentyFourHours);
            vixTokenAddresses[i] = address(v_token);
            mintVixToken(address(this),address(v_token),IV_TOKEN_SUPPLY);
        }
        vixTokens[deriveToken] = VixTokenData(vixTokenAddresses[0],vixTokenAddresses[1],BASE_PRICE,BASE_PRICE,0,0,0,0,0,0);
        liquidateVixTokenToPm(IV_TOKEN_SUPPLY, vixTokenAddresses[0], vixTokenAddresses[1]);
        return (vixTokenAddresses);
    }

    function liquidateVixTokenToPm(uint256 amountEach, address currency0, address currency1) internal returns (bool) {
    
       poolManager.unlock(
        abi.encode(
            CallbackData(
                amountEach, 
                Currency.wrap(currency0),
                Currency.wrap(currency1),
               address(this)
            )
        )
       );
    }

    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));
	    console.log("callbackData: ",callbackData.amountEach);
	    callbackData.currency0.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false 
        );
        callbackData.currency1.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false
        );

        callbackData.currency0.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true 
        );
        callbackData.currency1.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true
        );
	    return "";
    }

    function mintVixToken(address to,address _token,uint _amount) internal returns (bool){
        VolatileERC20 v_token = VolatileERC20(_token);
        v_token.mint(to, _amount);
        return true;
    }



    function resetPair(address deriveToken,uint deadline) public returns (address[2] memory) {
        require(isPairInitiated[deriveToken] == true,"Pair not initiated");
        if(pairEndingTime[deriveToken] < block.timestamp){

            address VHT = vixTokens[deriveToken].vixHighToken;
            address VLT = vixTokens[deriveToken].vixLowToken;
            VolatileERC20 VHTContract = VolatileERC20(VHT);
            VolatileERC20 VLTContract = VolatileERC20(VLT);


            (address[2] memory vixAdd)  = deploy2Currency(deriveToken,[VHTContract.name(),VLTContract.name()],[VHTContract.symbol(),VLTContract.symbol()], deadline);
            return vixAdd;
        }else{
            revert("Pair not expired");
        }
    }


}

/* 

Swap mechanism: 
 1. zeroForOne/ExactIn:
        - swapper swap by giving ETH as cost for IV token (high IV/low IV token)
        -we have to check which IV token user wish to buy whether it is high or low
        - then we have to check whether it is ZeroForOne and it is ExactIn
        - calculate token amount to be swap using tokensForGivenCost() function
        - take claims from the poolmanager using take() function for given amount
        - settle the wished IV token using settle() function
        - set toBeforeSwapDelta(amountSpecified (cost amount of IV token),amountUnspecified (returned amount of IV token))
 2. oneForZero/ExactOut:
*/