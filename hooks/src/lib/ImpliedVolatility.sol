// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library ImpliedVolatility{

    function dailyIV(uint fee,uint dailyVolume,uint tickLiquidity) internal pure returns (uint){
             uint dailyVolByTickLiq = dailyVolume/tickLiquidity;
             uint sqrtDailyVolByTickLiq = sqrt(dailyVolByTickLiq);
             uint daily = 5*fee*sqrtDailyVolByTickLiq;
             return daily;
    }

    function annualizedIV(uint fee,uint dailyVolume,uint tickLiquidity)public pure returns (uint){
            uint _diailyIv = dailyIV(fee, dailyVolume, tickLiquidity);
            uint annualized = _diailyIv*sqrt(365);
            return annualized;
    }


    /** 
     * @notice it is babylonian square root method
     * @param x The variance of the tick price.
     * @return y  square root.
     */
    function sqrt(uint x) internal pure returns (uint) {
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