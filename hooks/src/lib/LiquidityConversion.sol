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

    /// @notice Calculate amount0 using liquidity, price A and price B
    // function calAmount0(uint liq, uint pa, uint pb) internal pure returns (uint result) {
    //     uint Q96 = 2**96;
    //     assembly {
    //         if gt(pa, pb) {
    //             let temp := pa
    //             pa := pb
    //             pb := temp
    //         }

    //         let diff := sub(pb, pa)
    //         let intermediate := div(mul(liq, diff), pa)
    //         result := div(mul(intermediate, Q96), pb)
    //     }
    // }

    // /// @notice Calculate amount1 using liquidity, price A and price B
    // function calAmount1(uint liq, uint pa, uint pb) internal pure returns (uint result) {
    //     uint Q96 = 2**96;
    //     assembly {
    //         if gt(pa, pb) {
    //             let temp := pa
    //             pa := pb
    //             pb := temp
    //         }

    //         let diff := sub(pb, pa)
    //         let numerator := mul(liq, diff)
    //         result := div(numerator, Q96)
    //     }
    // }

    /// @notice Calculates effective liquidity and scale factor
    /// @param liquidity raw Uniswap V3 liquidity
    /// @param sa sqrtPrice at lower tick
    /// @param sb sqrtPrice at upper tick
    /// @param sp current sqrtPrice
    /// @param isDeriveZero whether base token is token0
    /// @param isNegativeTick whether current tick is negative
    // @returns it return liquidity and scale factor .. Note: liquidity is scaled to 18 decimals & with it decimal value for example BTC is 8 decimals means value is scaled to 18 decimals+8 decimals = 26 decimals
    function tickLiquidity(
        uint128 liquidity,
        uint160 sa,
        uint160 sb,
        uint160 sp,
        bool isDeriveZero,
        bool isNegativeTick
    ) internal pure returns (uint liq, uint160 scaleFactor) {
        console.log("isBaseZero",isDeriveZero);
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
        let amount0 := div(mul(intermediate0, Q96), b0)

        // === amount1 = calAmount1(liquidity, sa, sp) ===
        let a1 := sa
        let b1 := sp
        if gt(a1, b1) {
            let temp := a1
            a1 := b1
            b1 := temp
        }
        let diff1 := sub(b1, a1)
        let amount1 := div(mul(liquidity, diff1), Q96)

        // === price = sp * sp / Q192 (adjusted if tick is negative) ===
        let price := div(mul(sp, sp), Q192)
        if iszero(iszero(isNegativeTick)) {
            price := div(mul(mul(sp, ONE_E18), sp), Q192)
        }

        // === inversePrice = isNegativeTick ? ONE_E36 / price : ONE_E18 / price ===
        let inversePrice := div(ONE_E18, price)
        if iszero(iszero(isNegativeTick)) {
            inversePrice := div(ONE_E36, price)
        }

        // === liq = based on isBaseZero ===
        switch isBaseZero
        case 1 {
            liq := add(div(mul(amount1, inversePrice), ONE_E18), amount0)
        }
        default {
            liq := add(div(mul(amount0, price), ONE_E18), amount1)
        }

        // === scaleFactor = isNegativeTick ? 36 : 18 ===
        switch isNegativeTick
        case 1 {
            scaleFactor := 36
        }
        default {
            scaleFactor := 18
        }
    }
    }
    }
