// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/lib/ImpliedVolatility.sol";

contract ImpliedVolatilityTest is Test {
    using ImpliedVolatility for uint160;

    function setUp() public {}

    // Test sqrt function accuracy
    function testSqrtAccuracy() public {
        // Test perfect squares
        assertEq(ImpliedVolatility.sqrt(0), 0);
        assertEq(ImpliedVolatility.sqrt(1), 1);
        assertEq(ImpliedVolatility.sqrt(4), 2);
        assertEq(ImpliedVolatility.sqrt(9), 3);
        assertEq(ImpliedVolatility.sqrt(16), 4);
        assertEq(ImpliedVolatility.sqrt(25), 5);
        assertEq(ImpliedVolatility.sqrt(100), 10);
        assertEq(ImpliedVolatility.sqrt(10000), 100);
        
        // Test non-perfect squares (floor values)
        assertEq(ImpliedVolatility.sqrt(2), 1);   // floor(√2) = 1
        assertEq(ImpliedVolatility.sqrt(3), 1);   // floor(√3) = 1
        assertEq(ImpliedVolatility.sqrt(8), 2);   // floor(√8) = 2
        assertEq(ImpliedVolatility.sqrt(15), 3);  // floor(√15) = 3
        assertEq(ImpliedVolatility.sqrt(99), 9);  // floor(√99) = 9
        
        // Test large numbers
        assertEq(ImpliedVolatility.sqrt(1000000), 1000);
        assertEq(ImpliedVolatility.sqrt(999999), 999);
    }

    // Test IV calculation with realistic values
    function testIvCalculation() public {
        // Test case 1: Basic calculation
        uint160 volume = 1000e18;      // 1000 tokens
        uint160 tickLiquidity = 500e18; // 500 tokens liquidity
        uint160 scaleFactor = 6;        // Scale factor
        uint160 fee = 3;               // 0.3% fee (3/1000)
        
        uint160 iv = volume.ivCalculation(tickLiquidity, scaleFactor, fee,false);//added the isScaled bool
        console.log("IV Test 1:", iv);
        
        // Verify IV is reasonable (should be > 0)
        assertGt(iv, 0);
    }

    // Gas measurement for full IV calculation
    function testIvCalculationGas() public {
        uint160 volume = 1000e18;
        uint160 tickLiquidity = 500e18;
        uint160 scaleFactor = 6;
        uint160 fee = 3;
        
        uint256 gasBefore = gasleft();
        uint160 iv = volume.ivCalculation(tickLiquidity, scaleFactor, fee,false);//added the isScaled bool 
        uint256 gasAfter = gasleft();
        
        console.log("IV calculation gas used:", gasBefore - gasAfter);
        console.log("IV result:", iv);
    }

    // Original sqrt for comparison
    function originalSqrt(uint160 y) internal pure returns (uint160 z) {
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

    // Edge case testing
    function testEdgeCases() public {
        // Test maximum uint160 value
        uint160 maxVal = type(uint160).max;
        uint256 result = ImpliedVolatility.sqrt(maxVal);
        console.log("sqrt(max uint160):", result);
        
        // Verify it doesn't overflow
        assertLe(result, type(uint160).max);
        
        // Test some boundary values
        assertEq(ImpliedVolatility.sqrt(1), 1);
        assertEq(ImpliedVolatility.sqrt(2), 1);
        assertEq(ImpliedVolatility.sqrt(3), 1);
        assertEq(ImpliedVolatility.sqrt(4), 2);
    }

    // Comprehensive gas optimization comparison across value ranges
    function testGasOptimizationComparison() public {
        console.log("=== GAS OPTIMIZATION COMPARISON ===");
        console.log("Testing sqrt gas costs: Original vs Optimized");
        console.log("");
        
        // Define test ranges
        uint256[] memory testValues = new uint256[](10);
        testValues[0] = 4;           // Small perfect square
        testValues[1] = 100;         // Medium perfect square
        testValues[2] = 1000;        // Small non-perfect
        testValues[3] = 10000;       // Large perfect square
        testValues[4] = 50000;       // Medium non-perfect
        testValues[5] = 1000000;     // Large perfect square
        testValues[6] = 5000000;     // Large non-perfect
        testValues[7] = 10**12;      // Very large
        testValues[8] = 10**15;      // Extremely large
        testValues[9] = 10**18;      // Maximum test value
        
        uint256 iterations = 10;  // Number of iterations for averaging
        uint256 totalOriginalGas = 0;
        uint256 totalOptimizedGas = 0;
        
        // Warm up both functions
        ImpliedVolatility.sqrt(1000);
        originalSqrt(1000);
        
        console.log("Value | Original | Optimized | Savings | % Saved");
        console.log("------------------------------------------------");
        
        for (uint i = 0; i < testValues.length; i++) {
            uint256 value = testValues[i];
            
            // Measure original sqrt
            uint256 originalGasTotal = 0;
            for (uint j = 0; j < iterations; j++) {
                uint256 gasBefore = gasleft();
                originalSqrt(uint160(value));
                uint256 gasAfter = gasleft();
                originalGasTotal += (gasBefore - gasAfter);
            }
            uint256 originalGasAvg = originalGasTotal / iterations;
            
            // Measure optimized sqrt
            uint256 optimizedGasTotal = 0;
            for (uint j = 0; j < iterations; j++) {
                uint256 gasBefore = gasleft();
                ImpliedVolatility.sqrt(value);
                uint256 gasAfter = gasleft();
                optimizedGasTotal += (gasBefore - gasAfter);
            }
            uint256 optimizedGasAvg = optimizedGasTotal / iterations;
            
            // Calculate savings
            uint256 gasSavings = originalGasAvg > optimizedGasAvg ? 
                                originalGasAvg - optimizedGasAvg : 0;
            uint256 percentSaved = originalGasAvg > 0 ? 
                                  (gasSavings * 100) / originalGasAvg : 0;
            
            // Accumulate totals
            totalOriginalGas += originalGasAvg;
            totalOptimizedGas += optimizedGasAvg;
            
            // Log results
            console.log("Value:", value);
            console.log("  Original gas:", originalGasAvg);
            console.log("  Optimized gas:", optimizedGasAvg);
            console.log("  Gas savings:", gasSavings);
            console.log("  Percent saved:", percentSaved);
            console.log("---");
        }
        
        // Summary statistics
        uint256 totalSavings = totalOriginalGas - totalOptimizedGas;
        uint256 overallPercentSaved = (totalSavings * 100) / totalOriginalGas;
        
        console.log("=== SUMMARY ===");
        console.log("Total original gas:", totalOriginalGas);
        console.log("Total optimized gas:", totalOptimizedGas);
        console.log("Total gas saved:", totalSavings);
        console.log("Overall efficiency gain:", overallPercentSaved, "%");
        console.log("Average gas per optimized call:", totalOptimizedGas / testValues.length);
        console.log("Average gas per original call:", totalOriginalGas / testValues.length);
    }

    // Detailed analysis for specific ranges
    function testDetailedRangeAnalysis() public {
        console.log("");
        console.log("=== DETAILED RANGE ANALYSIS ===");
        
        // Small numbers analysis
        console.log("SMALL NUMBERS (1-1000):");
        _analyzeRange(1, 1000, 200, 5);
        
        // Medium numbers analysis  
        console.log("MEDIUM NUMBERS (1K-1M):");
        _analyzeRange(1000, 1000000, 200000, 5);
        
        // Large numbers analysis
        console.log("LARGE NUMBERS (1M-1B):");
        _analyzeRange(1000000, 1000000000, 200000000, 5);
        
        // Very large numbers
        console.log("VERY LARGE NUMBERS:");
        uint256[] memory veryLarge = new uint256[](3);
        veryLarge[0] = 10**12;
        veryLarge[1] = 10**15;
        veryLarge[2] = 10**18;
        _analyzeSpecificValues(veryLarge);
    }
    
    function _analyzeRange(uint256 start, uint256 end, uint256 step, uint256 iterations) internal {
        uint256 totalOriginal = 0;
        uint256 totalOptimized = 0;
        uint256 count = 0;
        
        for (uint256 value = start; value <= end && count < 5; value += step) {
            count++;
            
            // Measure original
            uint256 originalGas = _measureGas(value, iterations, true);
            // Measure optimized  
            uint256 optimizedGas = _measureGas(value, iterations, false);
            
            totalOriginal += originalGas;
            totalOptimized += optimizedGas;
        }
        
        if (count > 0) {
            uint256 avgOriginal = totalOriginal / count;
            uint256 avgOptimized = totalOptimized / count;
            uint256 savings = avgOriginal - avgOptimized;
            uint256 percentSaved = (savings * 100) / avgOriginal;
            
            console.log("  Average Original gas:", avgOriginal);
            console.log("  Average Optimized gas:", avgOptimized);
            console.log("  Average Savings:", savings, "gas");
            console.log("  Percent saved:", percentSaved, "%");
        }
        console.log("");
    }
    
    function _analyzeSpecificValues(uint256[] memory values) internal {
        for (uint i = 0; i < values.length; i++) {
            uint256 originalGas = _measureGas(values[i], 5, true);
            uint256 optimizedGas = _measureGas(values[i], 5, false);
            uint256 savings = originalGas - optimizedGas;
            uint256 percentSaved = (savings * 100) / originalGas;
            
            console.log("  Value:", values[i]);
            console.log("    Original:", originalGas, "gas");
            console.log("    Optimized:", optimizedGas, "gas");
            console.log("    Saved:", savings, "gas");
            console.log("    Percent:", percentSaved, "%");
        }
        console.log("");
    }
    
    function _measureGas(uint256 value, uint256 iterations, bool useOriginal) internal returns (uint256) {
        uint256 totalGas = 0;
        
        for (uint i = 0; i < iterations; i++) {
            uint256 gasBefore = gasleft();
            if (useOriginal) {
                originalSqrt(uint160(value));
            } else {
                ImpliedVolatility.sqrt(value);
            }
            uint256 gasAfter = gasleft();
            totalGas += (gasBefore - gasAfter);
        }
        
        return totalGas / iterations;
    }

    // Simple gas comparison for quick testing
    function testSimpleGasComparison() public {
        uint256 testValue = 10**15;
        
        // Warm up
        ImpliedVolatility.sqrt(1000);
        originalSqrt(1000);
        
        // Measure original
        uint256 gasBefore = gasleft();
        originalSqrt(uint160(testValue));
        uint256 gasAfter = gasleft();
        uint256 originalGas = gasBefore - gasAfter;
        
        // Measure optimized
        gasBefore = gasleft();
        ImpliedVolatility.sqrt(testValue);
        gasAfter = gasleft();
        uint256 optimizedGas = gasBefore - gasAfter;
        
        uint256 savings = originalGas - optimizedGas;
        uint256 percentSaved = (savings * 100) / originalGas;
        
        console.log("=== SIMPLE COMPARISON ===");
        console.log("Test value:", testValue);
        console.log("Original gas:", originalGas);
        console.log("Optimized gas:", optimizedGas);
        console.log("Gas savings:", savings);
        console.log("Percent saved:", percentSaved, "%");
    }
}
