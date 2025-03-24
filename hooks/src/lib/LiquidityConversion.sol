// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library LiquidityConversion {
   uint256 constant PRECISION = 1e18; // Used for fixed-point precision
function tickToPrice(int24 tick) internal pure returns (uint256) {
        // Replace this with Uniswap's tick formula
        return uint256(1e18) * uint256(uint24(tick));
}

function tickLiquidity(uint128 liquidity,int24 tick,int24 tickSpacing,uint8 decimal0,uint8 decimal1) internal pure returns(uint amount0,uint amount1,uint adjustedPrice,uint token0PriceInToken1,uint token1PriceInToken0){
        int24 bottomTick = (tick / tickSpacing) * tickSpacing;
        int24 topTick = bottomTick + tickSpacing;

        uint256 sa = tickToPrice(bottomTick / 2);
        uint256 sb = tickToPrice(topTick / 2);
        uint256 sp = sqrt(tickToPrice(tick));

        amount0 = (liquidity * (sb - sp)) / (sp * sb / PRECISION);
        amount1 = (liquidity * (sp - sa)) / PRECISION;

        // Adjust amounts for token decimals
        amount0 = amount0 / (10 ** decimal0);
        amount1 = amount1 / (10 ** decimal1);

        // Compute adjusted price
        uint256 price = tickToPrice(tick);
        adjustedPrice = price / (10 ** (decimal1 - decimal0));

        // Token prices
        token0PriceInToken1 = adjustedPrice;
        token1PriceInToken0 = (PRECISION * 10 ** decimal0) / adjustedPrice;

        return (amount0, amount1, adjustedPrice, token0PriceInToken1, token1PriceInToken0);
}

 function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}