// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/console.sol";  // Foundry's console library

library BondingCurve{
    function settingPrice(uint slope, uint circulation, uint basePrice) internal pure returns (uint){
        uint price = (slope * circulation)+basePrice;
        return price;
    }

    function costOfPurchasingToken(uint circulation, uint _purchaseToken, uint slope, uint basePrice,uint fee) internal pure returns (uint){
        uint n0 = circulation;
        uint k = _purchaseToken;
        uint256 cost = ((slope * n0 / 1e18) * k / 1e18) + ((slope * k / 1e18) * k / (2 * 1e18)) + (basePrice * k / 1e18);

        // Apply fee correctly
        cost = (cost * (1e18 - fee)) / 1e18;        
        return cost;
    }

    function costOfSellingToken(uint circulation,uint _sellToken, uint slope, uint basePrice,uint fee) internal pure returns (uint){
        uint n0 = circulation;
        uint k = _sellToken;
        //uint cost = (slope * n0 * k) - ((slope * k * k) / 2) + (basePrice * k);
        uint256 cost = ((slope * n0 / 1e18) * k / 1e18) - ((slope * k / 1e18) * k / (2 * 1e18)) + (basePrice * k / 1e18);

        // Apply fee correctly
        cost = (cost * (1e18 - fee)) / 1e18;        
        return cost;
    }

    function tokensForGivenCost(
        uint256 circulation,
        uint256 cost,
        uint256 slope,
        uint256 fee,
        uint256 basePrice
    ) internal pure returns (uint256) {
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
       function sqrt(uint x) internal pure returns (int y) {
        if (x == 0) return 0;
        uint z = (x + 1) / 2;
        y = int(x);
        while (z < uint(y)) {
            y = int(z);
            z = (x / z + z) / 2;
        }
    }

}