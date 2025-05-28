// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IBondingCurve {
  function settingPrice(uint256 slope, uint256 circulation, uint256 basePrice) external pure returns (uint256);
  function costOfPurchasingToken(uint256 slope,uint256 circulation,uint256 purchaseToken, uint256 basePrice) external pure returns (uint);
  function costOfSellingToken(uint256 slope,uint256 circulation, uint256 sellToken, uint256 basePrice) external pure returns (uint);
}