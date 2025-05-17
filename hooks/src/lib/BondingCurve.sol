// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/console.sol";  // Foundry's console library

    /**
     * @title Bonding Curve Library
     * @dev This library provides the necessary functions to operate a bonding curve.
     * @dev It is used to calculate the cost of purchasing/selling tokens
     * @dev and to calculate the number of tokens that can be purchased/sold
     * @dev for a given cost.
     * @notice This library is used by the `vix` contract.
     */

library BondingCurve{

    /**
     * @dev This function calculates the price of a token given the bonding curve parameters.
     * @param slope The slope of the bonding curve.
     * @param circulation The current circulation of the token.
     * @param basePrice The base price of the token.
     * @return The price of the token.
     */
    function settingPrice(uint slope, uint circulation, uint basePrice) internal pure returns (uint){
        uint price = (slope * circulation)+basePrice;
        return price;
    }

    /**
     * @dev This function calculates the cost of purchasing a specified number of tokens based on the bonding curve parameters.
     * @param circulation The current circulation of the token.
     * @param _purchaseToken The number of tokens to be purchased.
     * @param slope The slope of the bonding curve.
     * @param basePrice The base price of the token.
     * @param fee The transaction fee applied to the purchase, represented as a fraction of 1e18.
     * @return The total cost of purchasing the specified number of tokens, including the fee.
     */


    function costOfPurchasingToken(uint circulation, uint _purchaseToken, uint slope, uint basePrice,uint fee) internal pure returns (uint){
        uint n0 = circulation;
        uint k = _purchaseToken;
        uint256 cost = ((slope * n0 / 1e18) * k / 1e18) + ((slope * k / 1e18) * k / (2 * 1e18)) + (basePrice * k / 1e18);

        // Apply fee correctly
        cost = (cost * (1e18 - fee)) / 1e18;        
        return cost;
    }
    

    /**
     * @dev This function calculates the cost of selling a specified number of tokens based on the bonding curve parameters.
     * @param circulation The current circulation of the token.
     * @param _sellToken The number of tokens to be sold.
     * @param slope The slope of the bonding curve.
     * @param basePrice The base price of the token.
     * @param fee The transaction fee applied to the sale, represented as a fraction of 1e18.
     * @return The total revenue from selling the specified number of tokens, including the fee.
     */

    function costOfSellingToken(uint circulation,uint _sellToken, uint slope, uint basePrice,uint fee) internal pure returns (uint){
        uint n0 = circulation;
        uint k = _sellToken;
        //uint cost = (slope * n0 * k) - ((slope * k * k) / 2) + (basePrice * k);
        uint256 cost = ((slope * n0 / 1e18) * k / 1e18) - ((slope * k / 1e18) * k / (2 * 1e18)) + (basePrice * k / 1e18);

        // Apply fee correctly
        cost = (cost * (1e18 - fee)) / 1e18;        
        return cost;
    }

    /**
     * @dev This function calculates the number of tokens that can be purchased with a specified cost based on the bonding curve parameters.
     * @param circulation The current circulation of the token.
     * @param cost The cost of purchasing the tokens.
     * @param slope The slope of the bonding curve.
     * @param fee The transaction fee applied to the purchase, represented as a fraction of 1e18.
     * @param basePrice The base price of the token.
     * @return The total number of tokens that can be purchased with the specified cost, including the fee.
     */

    function tokensForGivenCost(uint256 circulation,uint256 cost,uint256 slope,uint256 fee,uint256 basePrice) internal pure returns (uint256) {
        require(cost > 0, "Cost must be greater than zero");

        // Adjust cost by removing fee impact
        uint256 adjustedCost = (cost * 1e18) / (1e18 + fee); // Keeps precision
        uint256 a = slope / 2;
        uint256 b = (slope * (circulation / 1e18)) + basePrice;
        int256 c = -int256(adjustedCost); // Keep precision

        // Calculate discriminant safely
        int256 discriminant = int256(b) * int256(b) - 4 * int256(a) * c;
        require(discriminant >= 0, "Discriminant must be non-negative"); // Prevents underflow

        // Convert discriminant to uint before sqrt
        int256 sqrtDiscriminant = int(sqrt(uint(discriminant)));

        // Solve for tokens using quadratic formula
        int256 k = (int256(sqrtDiscriminant) - int256(b)) / (2 * int256(a));
        require(k >= 0, "Invalid token amount");

        return uint256(k);
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

// function sqrt(uint256 x) public pure returns (uint256 result) {
//     if (x == 0) {
//         return 0;
//     }

//     // Calculate the square root of the perfect square of a power of two that is the closest to x.
//     uint256 xAux = uint256(x);
//     result = 1;
//     if (xAux >= 0x100000000000000000000000000000000) {
//         xAux >>= 128;
//         result <<= 64;
//     }
//     if (xAux >= 0x10000000000000000) {
//         xAux >>= 64;
//         result <<= 32;
//     }
//     if (xAux >= 0x100000000) {
//         xAux >>= 32;
//         result <<= 16;
//     }
//     if (xAux >= 0x10000) {
//         xAux >>= 16;
//         result <<= 8;
//     }
//     if (xAux >= 0x100) {
//         xAux >>= 8;
//         result <<= 4;
//     }
//     if (xAux >= 0x10) {
//         xAux >>= 4;
//         result <<= 2;
//     }
//     if (xAux >= 0x8) {
//         result <<= 1;
//     }

//     // The operations can never overflow because the result is max 2^127 when it enters this block.
//     unchecked {
//         result = (result + x / result) >> 1;
//         result = (result + x / result) >> 1;
//         result = (result + x / result) >> 1;
//         result = (result + x / result) >> 1;
//         result = (result + x / result) >> 1;
//         result = (result + x / result) >> 1;
//         result = (result + x / result) >> 1; // Seven iterations should be enough
//         uint256 roundedDownResult = x / result;
//         return result >= roundedDownResult ? roundedDownResult : result;
//     }
// }

}