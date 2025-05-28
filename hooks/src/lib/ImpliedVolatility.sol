// SPDX-License-Identifier: UNLICENSED

/**
 * @title ImpliedVolatility
 * @notice This library provides a utility to calculate implied volatility from a given volume and tick liquidity
 */
pragma solidity ^0.8.26;
import "forge-std/console.sol";

library ImpliedVolatility {
    /**
     * @notice Calculate the implied volatility from a given volume and tick liquidity
     * @param volume The volume of the trade
     * @param tickLiquidity The liquidity of the tick
     * @param fee The fee of the trade
     * @param isScaled to see if the inputs are already scaled
     * @return The implied volatility (return value is scaled to 15 decimals)
     */
     function ivCalculation(
        uint160 volume,
        uint160 tickLiquidity,
        uint160 scaleFactor,
        uint160 fee,
        bool isScaled
    ) internal pure returns (uint160) {
        uint160 ratio;
        
        if (isScaled) {
            // Values are already scaled, use them directly
            ratio = volume / tickLiquidity;
        }else {
            // Apply scaling to the calculation
            uint160 scaleDownTickLiquidity = tickLiquidity / (uint160(10) ** scaleFactor);
            require(scaleDownTickLiquidity > 0, "tickLiquidity must be greater than zero");
            ratio = (volume * 1e18) / scaleDownTickLiquidity; // Scale volume to 18 decimals);
        }
        uint256 sqrtResult = sqrt(ratio);
        
        // Safety check for uint160 overflow
        require(sqrtResult <= type(uint160).max, "sqrt result too large for uint160");
        
        uint160 sqrtRatio = uint160(sqrtResult);

        return (2 * fee * sqrtRatio);
    }

    /**
     * @notice Calculate the square root of a given number
     * @param x The number to calculate the square root of
     * @return result The square root of the number
     */
    function sqrt(uint256 x) public pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }
        if (x <= 16) {
        if (x == 1) return 1;
        if (x <= 4) return x == 4 ? 2 : 1;
        if (x <= 9) return x == 9 ? 3 : 2;
        if (x <= 16) return x == 16 ? 4 : 3;
    }
        assembly {
            // Initial bit-scan approximation
            let xAux := x
            result := 1

            if iszero(lt(xAux, 0x100000000000000000000000000000000)) {
                xAux := shr(128, xAux)
                result := shl(64, result)
            }
            if iszero(lt(xAux, 0x10000000000000000)) {
                xAux := shr(64, xAux)
                result := shl(32, result)
            }
            if iszero(lt(xAux, 0x100000000)) {
                xAux := shr(32, xAux)
                result := shl(16, result)
            }
            if iszero(lt(xAux, 0x10000)) {
                xAux := shr(16, xAux)
                result := shl(8, result)
            }
            if iszero(lt(xAux, 0x100)) {
                xAux := shr(8, xAux)
                result := shl(4, result)
            }
            if iszero(lt(xAux, 0x10)) {
                xAux := shr(4, xAux)
                result := shl(2, result)
            }
            if iszero(lt(xAux, 0x8)) {
                result := shl(1, result)
            }

            // Six Newton-Raphson iterations
            result := shr(1, add(result, div(x, result)))
            result := shr(1, add(result, div(x, result)))
            result := shr(1, add(result, div(x, result)))
            result := shr(1, add(result, div(x, result)))
            result := shr(1, add(result, div(x, result)))
            result := shr(1, add(result, div(x, result)))

            // Final correction: if result² > x, decrement
            let sq := mul(result, result)
            if gt(sq, x) {
                result := sub(result, 1)
            }
        }
    }
}

// fee should scaled!. for example, 0.3% fee should be  0.003 * 1000 = 3
