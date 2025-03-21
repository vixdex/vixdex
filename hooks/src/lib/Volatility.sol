// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Volatility Library
 * @notice This library provides functions to calculate volatility of a pool but not used by any contract!.
 */
library Volatility{

    /**  
     * @notice Updates the mean of the tick price.
     * @param oldTickMean The current mean of the tick price.
     * @param newTick The new tick price.
     * @param n The number of samples.
     * @return tickMean The new mean of the tick price.
     */
    function updateTickMean(int oldTickMean, int newTick, int n) internal pure returns (int tickMean) {
        if (n == 0) return newTick; 
        tickMean = oldTickMean + (newTick - oldTickMean) / n;
        return tickMean;
    }

    /** 
     * @notice Updates the M2 value which is used to calculate the variance. (Welford’s Algorithm or online methode)
     * @param M2 The current M2 value.
     * @param newTick The new tick price.
     * @param oldTickMean The current mean of the tick price.
     * @param newTickMean The new mean of the tick price.
     * @return m2 The new M2 value.
     */
    function updateM2(int M2,int newTick,int oldTickMean,int newTickMean) internal pure returns (int m2) {
        
    int diff1 = newTick - oldTickMean;
    int diff2 = newTick - newTickMean;
    
    if (diff1 == 0 || diff2 == 0) return M2 ; // Prevent M2 from staying zero

   // m2 = M2 + (diff1 * diff2)+1; //adding 1 will avoid volatility be zero
    m2 = M2 + (diff1 * diff2);
    return m2;
    }

    /** 
     * @notice Calculates the variance of the tick price.
     * @param M2 The M2 value.
     * @param n_greaterThanOne The number of samples minus one.
     * @return variance The variance of the tick price.
     */
    function calculateVariance(int M2,int n_greaterThanOne) internal pure returns (int variance) {
        require(n_greaterThanOne > 1,"N should be greater than 1");
        variance = M2 /(n_greaterThanOne -1);
        return variance;   
    }

    /** 
     * @notice Calculates the volatility of the tick price.
     * @param variance The variance of the tick price.
     * @param meanTick The mean of the tick price.
     * @return volatility  The volatility of the tick price.
     */
    function getVolatility(int variance,int meanTick) internal pure returns(int volatility){
        require(variance >= 0, "Variance cannot be negative");
        require(meanTick != 0, "Mean tick cannot be zero to avoid division by zero");
        if (variance == 0) return 1; // Setting a baseline volatility
        int stdDev = sqrt(uint(variance));
        //Coefficient of Variation (CV) c
        volatility = ((stdDev *100)/abs(meanTick));
      
        return volatility;
    }
    /**
        * @notice Calculates the normalized volatility of the tick price.
        * @param variance The variance of the tick price.
        * @param meanTick The mean of the tick price.
        * @param liquidityDepth The liquidity available at current price level.
        * @return normalizedVolatility The volatility normalized by liquidity depth.
    */
    function getNormalizedVolatilityUsingLiquidity(int256 variance, int256 meanTick, int256 liquidityDepth) internal pure returns (int256 normalizedVolatility) {
        require(variance >= 0, "Variance cannot be negative");
     require(meanTick != 0, "Mean tick cannot be zero");
        require(liquidityDepth > 0, "Liquidity depth must be greater than zero");

        int256 stdDev = sqrt(uint256(variance));
        int256 volatility = (stdDev * 100) / abs(meanTick); // Standard volatility formula
        normalizedVolatility = volatility / liquidityDepth; // Adjust for liquidity depth

        return normalizedVolatility;
    }

    /**
        * @notice Calculates the normalized volatility of the tick price.
        * @param currentRawVolatile The current raw volatility of the tick price.
        * @param maxVolatile The maximum raw volatility of the tick price.
        * @return normalizedVolatility The normalized volatility of the tick price.
        * 
        * This function calculates the normalized volatility as follows:
        * normalizedVolatility = (currentRawVolatile - 1)/(maxVolatile - 1) * 100
        * 
        * This is a linear mapping of the raw volatility to a normalized value between 0 and 100.
        * The normalized volatility is useful for comparing the volatility of different tick prices.
    */


    function getNormalizedVolatility(int currentRawVolatile, int maxVolatile) internal pure returns(int){
            
            require(maxVolatile > 1, "Max volatility must be greater than 1");
            require(currentRawVolatile >= 1, "Current volatility must be at least 1");
            int normalizedVolatile = ((currentRawVolatile - 1) * 100) / (maxVolatile - 1);            
            return normalizedVolatile;
    }
    
    
    function getLogNormalizedVolatility(int currentRawVolatile, int maxVolatile) internal pure returns (int) {
    require(maxVolatile > 1, "Max volatility must be greater than 1");
    require(currentRawVolatile >= 1, "Current volatility must be at least 1");

    int logCurrent = log2(uint256(currentRawVolatile)); 
    int logMax = log2(uint256(maxVolatile));

    int normalizedVolatile = (logCurrent * 100) / logMax;
    return normalizedVolatile;
	}

/**
 * @notice Log base 2 function using binary search method
 */
function log2(uint256 x) internal pure returns (int) {
    require(x > 0, "Log input must be greater than 0");

    int result = 0;
    while (x >= 2) {
        x >>= 1; // Equivalent to dividing by 2
        result++;
    }
    return result;
}


    /** 
     * @notice it is babylonian square root method
     * @param x The variance of the tick price.
     * @return y  square root.
     */
    function sqrt(uint x) internal pure returns (int y) {
        if (x == 0) return 0;
        uint z = (x + 1) / 2;
        y = int(x);
        while (z < uint(y)) {
            y = int(z);
            z = (x / z + z) / 2;
        }
    }

    function abs(int x) internal pure returns (int) {
    return x < 0 ? -x : x;
    }
}

/*

This Volatility library works using mean, variance, and standard deviation, but instead of the traditional batch method, it follows an incremental approach using Welford’s Algorithm to update values dynamically
 */
