// SPDX-License-Identifier: UNLICENSED

/**
 * @title ImpliedVolatility 
 * @notice This library provides a utility to calculate implied volatility from a given volume and tick liquidity
 */
pragma solidity ^0.8.26;

library ImpliedVolatility {
    /**
     * @notice Calculate the implied volatility from a given volume and tick liquidity
     * @param volume The volume of the trade
     * @param tickLiquidity The liquidity of the tick
     * @param fee The fee of the trade
     * @return The implied volatility (return value is scaled to 12 decimals)
     */
    function ivCalculation(uint160 volume, uint160 tickLiquidity,uint160 fee) 
        internal 
        pure 
        returns (uint160) 
    {
        uint160 ratio = (volume * 1e18)/ tickLiquidity; // scaled to 18 decimals
        uint160 sqrtRatio = sqrt(ratio); // scaled down to 9 decimals
        
        return (2 * fee * sqrtRatio) ; // fee is alread scaled to 3 decimals  so to bring the correct scaled down value is value/1e12
    }

    /**
     * @notice Calculate the square root of a given number
     * @param y The number to calculate the square root of
     * @return z The square root of the number
     */

    function sqrt(uint160 y) internal pure returns (uint160 z) {
        if (y > 3) {
            z = y;
            uint160 x = (y + 1) / 2;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

// fee should scaled!. for example, 0.3% fee should be  0.003 * 1000 = 3