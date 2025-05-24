// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {PoolKey, Currency} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Router is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IPositionManager public immutable positionManager;
    UniversalRouter public immutable router;
    IPoolManager public immutable poolManager;
    IPermit2 public immutable permit2;

    constructor(
        address _positionManager,
        address payable _router,
        address _poolManager,
        address _permit2
    ) {
        positionManager = IPositionManager(_positionManager);
        router = UniversalRouter(_router);
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
    }

    function createPool(
        address _token0,
        address _token1,
        uint24 lpFee,
        int24 tickSpacing,
        address hookContract,
        uint160 sqrtStartPriceX96
    ) public {
        require(_token0 != address(0) && _token1 != address(0), "Router: Token addresses cannot be zero");
        require(_token0 != _token1, "Router: Tokens must be different");
        Currency currency0 = Currency.wrap(_token0);
        Currency currency1 = Currency.wrap(_token1);
        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookContract)
        });
        positionManager.initializePool(pool, sqrtStartPriceX96);
    }

    function approveTokenWithPermit2(
        address token,
        uint160 amount,
        uint48 expiration
    ) external {
        // Using forceApprove instead of deprecated safeApprove
        IERC20(token).forceApprove(address(permit2), type(uint256).max);
        permit2.approve(token, address(router), amount, expiration);
    }

    function ExactInputSwapSingle(
        PoolKey calldata key,
        uint128 amountIn,
        uint128 minAmountOut,
        bool zeroForOne,
        bytes memory hookData,
        address recipient
    ) external nonReentrant returns (uint256 amountOut) {
        address outputToken = zeroForOne
            ? Currency.unwrap(key.currency1)
            : Currency.unwrap(key.currency0);

        uint256 balanceBefore = IERC20(outputToken).balanceOf(address(this));

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory inputs = new bytes[](1);
        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: hookData
            })
        );
        params[1] = abi.encode(
            zeroForOne ? key.currency0 : key.currency1,
            amountIn
        );
        params[2] = abi.encode(
            zeroForOne ? key.currency1 : key.currency0,
            minAmountOut
        );

        inputs[0] = abi.encode(actions, params);
        IERC20(zeroForOne ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1)).safeTransferFrom(msg.sender, address(this), amountIn);

        router.execute(commands, inputs, block.timestamp + 60);

        uint256 balanceAfter = IERC20(outputToken).balanceOf(address(this));
        amountOut = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;

        require(amountOut >= minAmountOut, "Insufficient output received");

        if (amountOut > 0) {
            IERC20(outputToken).safeTransfer(recipient, amountOut);
        }
    }

    function ExactOutputSwapSingle(
        PoolKey calldata key,
        uint128 amountOut,
        uint128 maxAmountIn,
        bool zeroForOne,
        bytes memory hookData,
        address recipient
    ) external nonReentrant returns (uint256 amountIn) {
        address inputToken = zeroForOne
            ? Currency.unwrap(key.currency0)
            : Currency.unwrap(key.currency1);
        address outputToken = zeroForOne
            ? Currency.unwrap(key.currency1)
            : Currency.unwrap(key.currency0);

        uint256 balanceBefore = IERC20(inputToken).balanceOf(address(this));

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_OUT_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory inputs = new bytes[](1);
        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            IV4Router.ExactOutputSingleParams({
                poolKey: key,
                zeroForOne: zeroForOne,
                amountOut: amountOut,
                amountInMaximum: maxAmountIn,
                hookData: hookData
            })
        );
        params[1] = abi.encode(
            zeroForOne ? key.currency0 : key.currency1,
            maxAmountIn
        );
        params[2] = abi.encode(
            zeroForOne ? key.currency1 : key.currency0,
            amountOut
        );

        inputs[0] = abi.encode(actions, params);
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), maxAmountIn);
        router.execute(commands, inputs, block.timestamp + 60);

        uint256 balanceAfter = IERC20(inputToken).balanceOf(address(this));
        amountIn = balanceBefore > balanceAfter ? balanceBefore - balanceAfter : 0;

        require(amountIn <= maxAmountIn, "Too much input used");

        uint256 balanceOutput = IERC20(outputToken).balanceOf(address(this));
        require(balanceOutput >= amountOut, "Insufficient output received");
        uint256 balanceInput = IERC20(inputToken).balanceOf(address(this));
        if (balanceOutput > 0) {
            IERC20(outputToken).safeTransfer(recipient, balanceOutput);
        }
        if(balanceInput > 0){
            IERC20(inputToken).safeTransfer(recipient, balanceInput);
        }
        
    }
}
