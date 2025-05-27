// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Router.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PoolKey, Currency} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

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
}
