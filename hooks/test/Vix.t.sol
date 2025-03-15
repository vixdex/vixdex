// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {Vix} from "../src/Vix.sol";
contract VixTest is Test,Deployers {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Vix hook;
    address baseToken;
    function setUp()external {

        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        address hookAddress = address(
            uint160(
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            )
        );       
        console.log(hookAddress);
        Currency ethCurrency = Currency.wrap(address(0));
        address baseToken = Currency.unwrap(ethCurrency);
        
        deployCodeTo("Vix.sol",abi.encode(manager,address(baseToken)),hookAddress);
        hook = Vix(hookAddress);
            (key, ) = initPool(
            ethCurrency,
            currency1,
            hook,
            3000,
            SQRT_PRICE_1_1
        );

    }



    function test_deploy2CurrencyWithBaseToken() public{
        uint pairDeadline= 3600 * 24;
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        //deploying two currency
        (address[2] memory vixAdd) = hook.deploy2Currency(token0,token1,["HIGH-VIX-BTC","LOW-VIX-BTC"],["HVB","LVP"],pairDeadline);
        console.log("HIGH-VIX-TOKEN: ",vixAdd[0]);
        console.log("LOW-VIX-TOKEN:",vixAdd[1]);
        address vixToken1 = vixAdd[0];
        address vixToken2 = vixAdd[1];
        MockERC20 vixToken1Contract = MockERC20(vixToken1);
        MockERC20 vixToken2Contract = MockERC20(vixToken2);
  
        //transfering token
        hook.transferVixtoken(address(this), 50 * (10**18),vixToken1);
        assertEq(vixToken1Contract.totalSupply(), 250 * 1000000 * (10**18));
        assertEq(vixToken2Contract.totalSupply(), 250 * 1000000 * (10**18));
        assertEq(vixToken1Contract.balanceOf(address(this)), 50 * (10**18));

        //swap
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
        takeClaims: false,
        settleUsingBurn: false
        });

            swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }
            ), 
            settings,
             ZERO_BYTES
             );

        //expect revert when trying to reset pair before deadline
        // uint deadline = 3600 * 24;
        // vm.expectRevert();
        // hook.resetPair(token0,token1,deadline);
        // //expect revert when transfering token after deadline
        // vm.warp(block.timestamp + 25 hours);
        // vm.expectRevert("TOKEN EXPIRED, MINTING CLOSED");
        // hook.transferVixtoken(address(this), 250 * (10**18),vixToken1);
     


        // //expect reseting pair after deadline
        
        // (address[2] memory vixAdd2) = hook.resetPair(token0,token1,deadline);
        // address vixToken1Reset = vixAdd2[0];
        // address vixToken2Reset = vixAdd2[1];
        // MockERC20 vixToken1ResetContract = MockERC20(vixToken1Reset);
        // MockERC20 vixToken2ResetContract = MockERC20(vixToken2Reset);

        // //


        // //expect transfering token after deadline
        // hook.transferVixtoken(address(this), 250 * (10**18),vixToken1Reset);
        // assertEq(vixToken1ResetContract.balanceOf(address(this)), 250 * (10**18));


    }

    

}