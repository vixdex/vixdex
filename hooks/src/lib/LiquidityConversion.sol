// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FixedPoint96} from '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import {FullMath} from '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "forge-std/console.sol";

library LiquidityConversion {
    using TickMath for int24;
    uint256 private constant Q96 = 2**96;
    uint256 private constant Q192 = 2**192;


    function sqrtPriceX96ToPrice(uint sqrtPriceX96) internal pure returns (uint price){
        return (sqrtPriceX96 ** 2) /Q192;
    }

    function calAmount0(uint liq,uint pa,uint pb) internal pure returns (uint){
        if (pa > pb) {
         uint256 temp = pa;
         pa = pb;
         pb = temp;

        }

        //liq * Q96 * (pb-pa) /pa /pb

        uint256 intermediate = FullMath.mulDiv(liq, pb - pa, pa); // Compute safely
        uint result = FullMath.mulDiv(intermediate,Q96,pb);
        return result;

    }
    function calAmount1(uint liq,uint pa,uint pb) internal pure returns (uint){
        //(liq * (pb - pa) / Q96)
        if (pa > pb) {
         uint256 temp = pa;
         pa = pb;
         pb = temp;

        }
        uint numerator = liq * (pb-pa);
        console.log("numerator: ",numerator);
        uint result = numerator/Q96;
        return result;
    }


    function tickLiquidity(uint128 liquidity,int24 tick,int24 tickSpacing,bool isBaseZero) internal pure returns (uint liq, uint160 scaleFactor) {
            // liquidity = 22510401004259913887;
            // tick = 195879;
            uint amount0;
            uint amount1;
            uint inversePrice;
            int24 bottomTick = tick / tickSpacing * tickSpacing;
            int24 upperTick = bottomTick + tickSpacing;
            uint160 sa = bottomTick.getSqrtRatioAtTick();
            uint160 sb = upperTick.getSqrtRatioAtTick();
            uint160 sp = tick.getSqrtRatioAtTick();
            console.log("liquidity: ",liquidity);
            console.log("tick: ",tick);

            amount0 = calAmount0(liquidity,sb,sp);
            console.log("amount0: ",amount0);
            amount1 = calAmount1(liquidity,sa, sp);
            console.log("amount1: ",amount1);
             uint price;
            
            if(tick < 0){
                price = FullMath.mulDiv(sp * 1e18, sp, Q192); // Safe computation
                inversePrice = 1e36/(price);
                liq = isBaseZero?(amount1*inversePrice)+amount0:(amount0*price)+amount1; 
                scaleFactor = 36;

            }else{
                price = FullMath.mulDiv(sp , sp, Q192);
                inversePrice = 1e18/(price);
                liq = isBaseZero?(amount1*inversePrice)+amount0:(amount0*price)+amount1; 
                scaleFactor = 18;
            }

            /*
             Price - price of token0 on token1. eg: 1 USDC = 0.003ETH on usdc/eth pair
             inversePrice - price of token1 on token0. eg:1 ETH = 3000USDC on usdc/eth pair
              --notes: returning liq for positive tick is scaled to 18 but for negative scaled to 36 
              to convert to realtime price for positive tick is scaledPrice/10**(decimal1-decimal0)
                but for negative tick is scaledPrice/10**18
             */
             console.log("liquidity",liq);
            console.log(price);
            console.log(inversePrice);  
            return (liq,scaleFactor);
    }

}








/*
if ETH in not a token0, scaledAdjustedPrice is the price of USDC in ETH.
if ETH in not a token0, inversePrice is the price of ETH in USDC.
if ETH in not a token0, liq is the liquidity in ETH.

if ETH is a token0, scaledAdjustedPrice is the price of ETH in USDC.
if ETH is a token0, inversePrice is the price of USDC in ETH.
if ETH is a token0, liq is the liquidity in USDC.

    if(isBaseZero){
        uint part1 = amount0 / (1 * 10**decimal0);
        console.log("part1:", part1);
        uint part2 = (amount1 * inversePrice) / ((1 * 10**decimal0) * (1 * 10**decimal1));
        console.log("part2:", part2);
        liq = (part1 + part2) * 1e18;
        console.log("liq:", liq);
        return (amount0, amount1, scaledAdjustedPrice, inversePrice, liq, part1, part2);
    }else{
    uint256 part1 = amount1 / (1 * 10**decimal1);
            console.log("part1:", part1);

    uint256 part2 = (amount0 * scaledAdjustedPrice) / ((1 * 10**decimal0) * (1 * 10**decimal1));
            console.log("part2:", part2);

    liq = (part1 + part2) * 1e18;
    return (amount0, amount1, scaledAdjustedPrice, inversePrice, liq, part1, part2);
    }
 */



