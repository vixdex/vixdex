// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IVolumeOracle {
    struct VolumeData {
        uint256 volume24HrInUSD;
        uint256 volume24HrInBaseToken;
        uint256 volume24HrInQuoteToken;
        uint256 lastUpdatedAt;
        uint256 expiresAt;
    }

    function volumeDataByV3Pool(address _v3PoolAddress) external view returns (
        uint256 volume24HrInUSD,
        uint256 volume24HrInBaseToken,
        uint256 volume24HrInQuoteToken,
        uint256 lastUpdatedAt,
        uint256 expiresAt
    );

    function owner() external view returns (address);

    function setVolumeData(
        uint256 _volume24HrInUSD,
        uint256 _volume24HrInBaseToken,
        uint256 _volume24HrInQuoteToken,
        address _v3PoolAddress
    ) external;

    function getVolumeData(address _v3PoolAddress) external view returns (VolumeData memory);
}
