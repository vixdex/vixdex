// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "forge-std/console.sol";

library LiquidityConversion {
    using TickMath for int24;

    uint256 private constant Q96 = 2**96;
    uint256 private constant Q192 = 2**192;
    uint256 private constant ONE_E18 = 1e18;
    uint256 private constant ONE_E36 = 1e36;

    /// @notice Converts sqrtPriceX96 to price
    function sqrtPriceX96ToPrice(uint sqrtPriceX96) internal pure returns (uint price) {
        assembly {
            let sp := sqrtPriceX96
            let product := mul(sp, sp)
            let q192 := exp(2, 192)
            price := div(product, q192)
        }
    }

  

    /// @param liquidity raw Uniswap V3 liquidity
    /// @param sa sqrtPrice at lower tick
    /// @param sb sqrtPrice at upper tick
    /// @param sp current sqrtPrice
    /// @param decimal0 decimal of token0
    /// @param decimal1 decimal of token1
    /// @param isNegativeTick whether current tick is negative
    // @returns it return liquidity and scale factor .. Note: liquidity is scaled to 18 decimals & with it decimal value for example BTC is 8 decimals means value is scaled to 18 decimals+8 decimals = 26 decimals
    function tickLiquidity(
        uint128 liquidity,
        uint160 sa,
        uint160 sb,
        uint160 sp,
        uint8 decimal0,
        uint8 decimal1,
        bool isNegativeTick
    ) internal pure returns (uint liq,uint amount0,uint amount1,uint160 scaleFactor) {
        assembly {
        // === amount0 = calAmount0(liquidity, sp, sb) ===
        let a0 := sp
        let b0 := sb
        if gt(a0, b0) {
            let temp := a0
            a0 := b0
            b0 := temp
        }
        let diff0 := sub(b0, a0)
        let intermediate0 := div(mul(liquidity, diff0), a0)
        amount0 := div(mul(intermediate0, Q96), b0)

        // === amount1 = calAmount1(liquidity, sa, sp) ===
        let a1 := sa
        let b1 := sp
        if gt(a1, b1) {
            let temp := a1
            a1 := b1
            b1 := temp
        }
        let diff1 := sub(b1, a1)
        amount1 := div(mul(liquidity, diff1), Q96)

        // === price = sp * sp / Q192 (adjusted if tick is negative) ===
        let price := div(mul(sp, sp), Q192)
        if isNegativeTick {
            price := div(mul(mul(sp, ONE_E18), sp), Q192)
        }

        // === tick liquidity ===
        liq := add(mul(amount0, price), amount1)
        if isNegativeTick{
            liq := add(mul(amount0,price),mul(amount1, ONE_E18))
        }

        // === scaleFactor = isNegativeTick ? 36 : 18 ===
        switch isNegativeTick
        case 1 {
            scaleFactor := add(18,decimal1)
        }
        default {
            scaleFactor := decimal1
        }
    }
    }
    }
