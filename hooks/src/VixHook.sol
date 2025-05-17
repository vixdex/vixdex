// SPDX-License-Identifier: UNLICENSED


pragma solidity ^0.8.26;
import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency,CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

contract VixHook is BaseHook{

    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;

        address public baseToken;

        struct HookData{
        address deriveAsset;
        uint160 volume;
        }

function getHookPermissions() public pure override returns (Hooks.Permissions memory){
    return Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
    });
}

function _beforeAddLiquidity(address,PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata , bytes calldata)internal view override  returns (bytes4){
    revert();
}

function _beforeSwap(address sender,PoolKey calldata key,IPoolManager.SwapParams calldata params,bytes calldata data) internal override returns (bytes4, BeforeSwapDelta, uint24) {
    BeforeSwapDelta beforeSwapDelta;
    HookData memory hookData = abi.decode(data, (HookData));
    bool isBaseZero = Currency.unwrap(key.currency0) == baseToken;

    if(isBaseZero){ 
        // for Buy(ZeroForOneSwap) -> only  exactOut - costOfPurchase function will be called
        // for Sell(OneForZeroSwap) -> only exactIn - costOfSell function will be called

        //checking the mode of swap 
        if(params.zeroForOne){
            //reverting if the swap is exactIn
            require(params.amountSpecified < 0, "exactIn not allowed");
            // buy token function will call


        }else{
            //reverting if the swap is exactOut
            require(params.amountSpecified > 0, "exactOut not allowed");
            // sell token function will call
        }
        
    }else{
        // for Buy(OneForZeroSwap) -> only exactOut - costOfPurchase function will be called
        // for Sell(ZeroForOneSwap) -> only exactIn - costOfSell function will be called
        //checking the mode of swap
        if(params.zeroForOne){
            //reverting if the swap is exactOut
            require(params.amountSpecified > 0, "exactOut not allowed");
            // sell token function will call
        }else{
            //reverting if the swap is exactIn
            require(params.amountSpecified < 0, "exactIn not allowed");
            // buy token function will call
        }
    }
    
}

function buyHighToken(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 cost = vixTokenData.circulation0.costOfPurchasingToken(amountInOutPositive, SLOPE, BASE_PRICE, FEE);
    vixTokenData.contractHoldings0 += amountInOutPositive;
    vixTokenData.circulation0 += amountInOutPositive;
    vixTokenData.reserve0 += cost;
    if(zeroIsBase){
        key.currency0.take(poolManager, address(this), cost, true);
        key.currency1.settle(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.take(poolManager, address(this), cost, true);
        key.currency0.settle(poolManager, address(this), amountInOutPositive, true);
    }
    return (-int128(uint128(amountInOutPositive)), int128(uint128(cost)));
}

function buyLowToken(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 cost = vixTokenData.circulation1.costOfPurchasingToken(amountInOutPositive, SLOPE, BASE_PRICE, FEE);
    vixTokenData.contractHoldings1 += amountInOutPositive;
    vixTokenData.circulation1 += amountInOutPositive;
    vixTokenData.reserve1 += cost;
    if(zeroIsBase){
        key.currency0.take(poolManager, address(this), cost, true);
        key.currency1.settle(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.take(poolManager, address(this), cost, true);
        key.currency0.settle(poolManager, address(this), amountInOutPositive, true);
    }
    return (-int128(uint128(amountInOutPositive)), int128(uint128(cost)));
}

function sellHighToken(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 baseToken_returns = vixTokenData.circulation0.costOfSellingToken(amountInOutPositive, SLOPE, BASE_PRICE, FEE);
    vixTokenData.contractHoldings0 -= amountInOutPositive;
    vixTokenData.circulation0 -= amountInOutPositive;
    vixTokenData.reserve0 -= baseToken_returns;
    if(zeroIsBase){
        key.currency0.settle(poolManager, address(this),baseToken_returns, true);
        key.currency1.take(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.settle(poolManager, address(this),baseToken_returns, true);
        key.currency0.take(poolManager, address(this), amountInOutPositive, true);
    }
    return (int128(uint128(amountInOutPositive)), -int128(uint128(baseToken_returns)));
}

function sellLowToken(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 baseToken_returns = vixTokenData.circulation1.costOfSellingToken(amountInOutPositive, SLOPE, BASE_PRICE, FEE);
    vixTokenData.contractHoldings1 -= amountInOutPositive;
    vixTokenData.circulation1 -= amountInOutPositive;
    vixTokenData.reserve1 -= baseToken_returns;
    if(zeroIsBase){
        key.currency0.settle(poolManager, address(this),baseToken_returns, true);
        key.currency1.take(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.settle(poolManager, address(this),baseToken_returns, true);
        key.currency0.take(poolManager, address(this), amountInOutPositive, true);
    }
    return (int128(uint128(amountInOutPositive)), -int128(uint128(baseToken_returns)));
}


}