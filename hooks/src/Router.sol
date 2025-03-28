// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {PoolKey,Currency} from "v4-core/src/types/PoolKey.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/src/interfaces/IAllowanceTransfer.sol";
import { UniversalRouter } from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import { Commands } from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IV4Router } from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import { IPermit2 } from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import "forge-std/console.sol";

contract Router{
    using StateLibrary for IPoolManager;
    IPositionManager public immutable positionManager;
    UniversalRouter public immutable router;
    IPoolManager public immutable poolManager;
    IPermit2 public immutable permit2;

    constructor(address _positionManager,address payable _router,address _poolManager,address _permit2){
       
        positionManager = IPositionManager(_positionManager);
        router = UniversalRouter(_router);
        poolManager = IPoolManager(_poolManager);
        permit2 = IPermit2(_permit2);
    }

    function createPool(address _token0, address _token1,uint24 lpFee, int24 tickSpacing, address hookContract, uint160 sqrtStartPriceX96) public{
        console.log(_token0,_token1);
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

  function ExactInputSwapSingle(address token0, uint160 token0Amount,uint48 expiration,PoolKey calldata key,uint128 amountIn,uint128 minAmountOut,address _permit2,bool zeroForOne,bytes memory hookData)  external returns (uint256 amountOut){
    //approving token0 and token1 for router
    IERC20(token0).approve(_permit2, type(uint256).max);
    permit2.approve(token0, address(router), token0Amount, expiration);


    //swap for exact Input
    bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
    bytes memory actions = abi.encodePacked(
    uint8(Actions.SWAP_EXACT_IN_SINGLE),
    uint8(Actions.SETTLE_ALL),
    uint8(Actions.TAKE_ALL)
    );
    bytes[] memory params = new bytes[](3);
    bytes[] memory inputs = new bytes[](1);
    params[0] = abi.encode(
        IV4Router.ExactInputSingleParams({
        poolKey: key,
        zeroForOne: zeroForOne,            // true if we're swapping token0 for token1
        amountIn: amountIn,          // amount of tokens we're swapping
        amountOutMinimum: 0, // minimum amount we expect to receive
       // sqrtPriceLimitX96: uint160(0),  // no price limit set -> mention in doc but not in IV4Router
        hookData: hookData             // no hook data needed
        })
    );
    


    // encode SETTLE_ALL parameters
    params[1] = abi.encode(zeroForOne?key.currency0:key.currency1, amountIn);
    // Third parameter: specify output tokens from the swap
    params[2] = abi.encode(zeroForOne?key.currency1:key.currency0, 0);
    // Combine actions and params into inputs
    inputs[0] = abi.encode(actions, params);
    // Execute the swap
    router.execute(commands, inputs, block.timestamp);
}
}