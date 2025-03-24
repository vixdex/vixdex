// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

library LiquidityConversion {
    using TickMath for int24;


    function tickLiquidity(uint128 liquidity,int24 tick,int24 tickSpacing,uint8 decimal0,uint8 decimal1, bool isBaseZero) internal pure returns (uint amount0, uint amount1,uint scaledAdjustedPrice,uint inversePrice,uint liq,uint p1,uint p2) {
    int24 bottomTick = tick / tickSpacing * tickSpacing;
    int24 upperTick = bottomTick + tickSpacing;

    uint160 sa = bottomTick.getSqrtRatioAtTick() / (1 << 96);
    uint160 sb = upperTick.getSqrtRatioAtTick() / (1 << 96);
    uint160 sp = tick.getSqrtRatioAtTick() / (1 << 96);

    amount0 = (liquidity * (sb - sp)) / (sp * sb);
    amount1 = liquidity * (sp - sa);

    // Price of USDC in ETH (USDC/ETH) for ETH as token1 , Price of ETH in USDC for ETH as token0
    uint adjustedPrice = (uint256(sp) * uint256(sp) * 1e18) / (10 ** (decimal1 - decimal0));
    scaledAdjustedPrice = adjustedPrice;

    // Price of ETH in USDC (ETH/USDC) for eth as token1, Price of USDC in ETH for eth as token0 - Reciprocal of `scaledAdjustedPrice`
    inversePrice = (1e36) / scaledAdjustedPrice; 

    if(isBaseZero){
        uint part1 = amount0 / (1 * 10**decimal0);
        uint part2 = (amount1 * inversePrice) / ((1 * 10**decimal0) * (1 * 10**decimal1));
        liq = (part1 + part2) * 1e18;
        return (amount0, amount1, scaledAdjustedPrice, inversePrice, liq, part1, part2);
    }else{
    uint256 part1 = amount1 / (1 * 10**decimal1);
    uint256 part2 = (amount0 * scaledAdjustedPrice) / ((1 * 10**decimal0) * (1 * 10**decimal1));
    liq = (part1 + part2) * 1e18;
    return (amount0, amount1, scaledAdjustedPrice, inversePrice, liq, part1, part2);
    }
 
    }

}

/*
if ETH in not a token0, scaledAdjustedPrice is the price of USDC in ETH.
if ETH in not a token0, inversePrice is the price of ETH in USDC.
if ETH in not a token0, liq is the liquidity in ETH.

if ETH is a token0, scaledAdjustedPrice is the price of ETH in USDC.
if ETH is a token0, inversePrice is the price of USDC in ETH.
if ETH is a token0, liq is the liquidity in USDC.
 */



