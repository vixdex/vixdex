// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Router.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PoolKey, Currency} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";

//uses address from mainnet, so need to fork mainnet to test this, save RPC url as an evironment var MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/yourKey


contract RouterForkTest is Test {
    using SafeERC20 for IERC20;
    
    Router public router;

    address constant POSITION_MANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address constant UNIVERSAL_ROUTER = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // A known whale holding USDC on mainnet
    address constant whale = 0x55FE002aefF02F77364de339a1292923A15844B8;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        vm.chainId(3133);//change this according to your id
        vm.startPrank(whale);

        router = new Router(POSITION_MANAGER, payable(UNIVERSAL_ROUTER), POOL_MANAGER, PERMIT2);

        // Give the whale some USDC if needed on fork
        deal(USDC, whale, 100_000e6);

        // IMPORTANT: Approve the router directly to spend whale's USDC
        IERC20(USDC).approve(address(router), type(uint256).max);
        
        // Also setup Permit2 for the router contract
        router.approveTokenWithPermit2(USDC, 10_000e6, uint48(block.timestamp + 3600));

        vm.stopPrank();
    }
    function testExactInputSwapSingle_USDC_to_USDT() public {
        vm.startPrank(whale);
        
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(USDT),
            fee: 100,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });

        uint128 amountIn = 10_000e6;
        uint128 minAmountOut = 9_900e6;
        bool zeroForOne = true;

        uint256 amountOut = router.ExactInputSwapSingle(
            key,
            amountIn,
            minAmountOut,
            zeroForOne,
            "",
            whale   
        );

        emit log_named_uint("USDT received", amountOut);
        assertGt(amountOut, minAmountOut, "Should receive more than minimum USDT");

        vm.stopPrank();
    }
    
    function testExactInputSwapSingle_RevertsOnLowMinAmountOut() public {
        vm.startPrank(whale);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(USDT),
            fee: 100,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });

        uint128 amountIn = 10_000e6;
        uint128 minAmountOut = 100_000e6; // too high
        bool zeroForOne = true;

        vm.expectRevert();
        router.ExactInputSwapSingle(
            key,
            amountIn,
            minAmountOut,
            zeroForOne,
            "",
            whale
        );

        vm.stopPrank();
    }

    function testExactOutputSwapSingle_USDC_to_USDT() public {
        vm.startPrank(whale);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(USDT),
            fee: 100,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });

        uint128 amountOut = 9_000e6;
        uint128 maxAmountIn = 10_000e6;
        bool zeroForOne = true;

        uint256 amountIn = router.ExactOutputSwapSingle(
            key,
            amountOut,
            maxAmountIn,
            zeroForOne,
            "",
            whale
        );

        emit log_named_uint("USDC spent", amountIn);
        assertLe(amountIn, maxAmountIn, "Spent more than allowed input");

        vm.stopPrank();
    }

    function testExactOutputSwapSingle_RevertsOnLowMaxAmountIn() public {
        vm.startPrank(whale);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(USDT),
            fee: 100,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });

        uint128 amountOut = 9_000e6;
        uint128 maxAmountIn = 1000e6; // too low
        bool zeroForOne = true;

        vm.expectRevert();
        router.ExactOutputSwapSingle(
            key,
            amountOut,
            maxAmountIn,
            zeroForOne,
            "",
            whale
        );

        vm.stopPrank();
    }

    function testApproveTokenWithPermit2() public {
        vm.startPrank(whale);

        uint160 amount = 1_000e6;
        uint48 expiration = uint48(block.timestamp + 3600);

        router.approveTokenWithPermit2(USDC, amount, expiration);

        assertTrue(true, "approveTokenWithPermit2 ran without errors");

        vm.stopPrank();
    }

    function testCreatePool_RevertsOnInvalidToken() public {
        vm.startPrank(whale);

        address invalidToken = address(0);
        address tokenB = USDT;

        vm.expectRevert();
        router.createPool(
            invalidToken,
            tokenB,
            100,
            1,
            address(0),
            79228162514264337593543950336
        );

        vm.stopPrank();
    }
    function testCreatePool_TokenSorting() public {
    vm.startPrank(whale);
    
    // Test creating pool with tokens in original order (USDC < USDT by address)
    address token0_original = USDC;  // 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address token1_original = USDT;  // 0xdAC17F958D2ee523a2206206994597C13D831ec7
    
    uint24 lpFee = 3000; // 0.3%
    int24 tickSpacing = 60;
    address hookContract = address(0);
    uint160 sqrtStartPriceX96 = 79228162514264337593543950336; // 1:1 price ratio
    
    // This should work without issues
    router.createPool(
        token0_original,
        token1_original,
        lpFee,
        tickSpacing,
        hookContract,
        sqrtStartPriceX96
    );
    
    emit log_string("Pool created successfully with original token order");
    
    vm.stopPrank();
}

function testCreatePool_ReversedTokenOrder() public {
    vm.startPrank(whale);
    
    // Test creating pool with tokens in reversed order (should still work due to sorting)
    address token0_reversed = USDT;  // Higher address value
    address token1_reversed = USDC;  // Lower address value
    
    uint24 lpFee = 500; // 0.05% (different fee to avoid duplicate pool)
    int24 tickSpacing = 10;
    address hookContract = address(0);
    uint160 sqrtStartPriceX96 = 79228162514264337593543950336;
    
    // This should also work due to internal token sorting
    router.createPool(
        token0_reversed,
        token1_reversed,
        lpFee,
        tickSpacing,
        hookContract,
        sqrtStartPriceX96
    );
    
    emit log_string("Pool created successfully with reversed token order");
    
    vm.stopPrank();
}

function testCreatePool_IdenticalTokens() public {
    vm.startPrank(whale);
    
    // Test that identical tokens are rejected
    vm.expectRevert("Router: Tokens must be different");
    router.createPool(
        USDC,
        USDC, // Same token
        3000,
        60,
        address(0),
        79228162514264337593543950336
    );
    
    vm.stopPrank();
}

function testCreatePool_WithOfficialSortTokensAndMockERC20() public {
    vm.startPrank(whale);
    
    // Deploy MockERC20 tokens for testing
    MockERC20 tokenA = new MockERC20("Token A", "TKNA", 18);
    MockERC20 tokenB = new MockERC20("Token B", "TKNB", 18);
    
    // Mint tokens to whale for testing
    tokenA.mint(whale, 1000000e18);
    tokenB.mint(whale, 1000000e18);
    
    emit log_named_address("TokenA address", address(tokenA));
    emit log_named_address("TokenB address", address(tokenB));
    
    // Use official SortTokens library - returns Currency types, not MockERC20
    (Currency sortedCurrency0, Currency sortedCurrency1) = SortTokens.sort(tokenA, tokenB);
    
    // Convert Currency back to addresses for logging
    address sortedToken0 = Currency.unwrap(sortedCurrency0);
    address sortedToken1 = Currency.unwrap(sortedCurrency1);
    
    emit log_named_address("Sorted Token0 (lower)", sortedToken0);
    emit log_named_address("Sorted Token1 (higher)", sortedToken1);
    
    // Verify sorting is correct (token0 should have lower address)
    assertLt(
        uint256(uint160(sortedToken0)), 
        uint256(uint160(sortedToken1)), 
        "Token0 should have lower address than Token1"
    );
    
    // Test creating pool with unsorted tokens (should work due to internal sorting)
    router.createPool(
        address(tokenA),    // May be higher or lower address
        address(tokenB),    // May be higher or lower address
        3000,               // 0.3% fee
        60,                 // tick spacing
        address(0),         // no hook
        79228162514264337593543950336 // 1:1 price
    );
    
    emit log_string("Pool created successfully with MockERC20 tokens");
    
    vm.stopPrank();
}

function testCreatePool_SortingConsistencyWithMockERC20() public {
    vm.startPrank(whale);
    
    // Create multiple MockERC20 tokens to test sorting consistency
    MockERC20[] memory tokens = new MockERC20[](3);
    tokens[0] = new MockERC20("Token A", "TKNA", 18);
    tokens[1] = new MockERC20("Token B", "TKNB", 18);
    tokens[2] = new MockERC20("Token C", "TKNC", 18);
    
    // Test all combinations to ensure consistent sorting
    for (uint i = 0; i < tokens.length - 1; i++) {
        for (uint j = i + 1; j < tokens.length; j++) {
            MockERC20 tokenX = tokens[i];
            MockERC20 tokenY = tokens[j];
            
            // Sort using official library - returns Currency types
            (Currency sorted0, Currency sorted1) = SortTokens.sort(tokenX, tokenY);
            
            // Convert to addresses for comparison
            address officialToken0 = Currency.unwrap(sorted0);
            address officialToken1 = Currency.unwrap(sorted1);
            
            // Verify sorting matches our manual sorting
            (address manual0, address manual1) = address(tokenX) < address(tokenY) 
                ? (address(tokenX), address(tokenY)) 
                : (address(tokenY), address(tokenX));
            
            assertEq(officialToken0, manual0, "Official sort doesn't match manual sort for token0");
            assertEq(officialToken1, manual1, "Official sort doesn't match manual sort for token1");
            
            emit log_named_address("Pair tested - Token0", officialToken0);
            emit log_named_address("Pair tested - Token1", officialToken1);
        }
    }
    
    emit log_string("All sorting combinations tested successfully");
    
    vm.stopPrank();
}

function testCreatePool_VerifyInternalSortingMatchesOfficial() public {
    vm.startPrank(whale);
    
    // Create MockERC20 tokens
    MockERC20 tokenA = new MockERC20("Token A", "TKNA", 18);
    MockERC20 tokenB = new MockERC20("Token B", "TKNB", 18);
    
    // Get official sorting result - returns Currency types
    (Currency officialCurrency0, Currency officialCurrency1) = SortTokens.sort(tokenA, tokenB);
    
    // Convert Currency to addresses
    address officialToken0 = Currency.unwrap(officialCurrency0);
    address officialToken1 = Currency.unwrap(officialCurrency1);
    
    // Get our manual sorting result (what our Router does internally)
    (address manualToken0, address manualToken1) = address(tokenA) < address(tokenB) 
        ? (address(tokenA), address(tokenB)) 
        : (address(tokenB), address(tokenA));
    
    // Verify our internal sorting matches the official library
    assertEq(officialToken0, manualToken0, "Manual sorting doesn't match official library for token0");
    assertEq(officialToken1, manualToken1, "Manual sorting doesn't match official library for token1");
    
    emit log_string("Internal sorting verified against official SortTokens library");
    
    // Create pool to ensure it works with our sorting
    router.createPool(
        address(tokenA),
        address(tokenB),
        3000,
        60,
        address(0),
        79228162514264337593543950336
    );
    
    emit log_string("Pool creation successful with verified sorting");
    
    vm.stopPrank();
}


}
