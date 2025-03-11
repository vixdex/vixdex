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
    address usdc;
    function setUp()external {

        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        address hookAddress = address(
            uint160(
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                    Hooks.AFTER_SWAP_FLAG
            )
        );       
        console.log(hookAddress);
        usdc = address(Currency.unwrap(currency0));
        console.log(usdc);
        deployCodeTo("Vix.sol",abi.encode(manager,address(usdc)),hookAddress);
        hook = Vix(hookAddress);
            (key, ) = initPool(
            currency0,
            currency1,
            hook,
            3000,
            SQRT_PRICE_1_1
        );

    }



    function test_deploy2Currency() public{
        uint pairDeadline= 3600 * 24;
        //deploying two currency
        (address[2] memory vixAdd) = hook.deploy2Currency(key.currency0.toId(),key.currency1.toId(),["HIGH-VIX-BTC","LOW-VIX-BTC"],["HVB","LVP"],pairDeadline);
        console.log("HIGH-VIX-TOKEN: ",vixAdd[0]);
        console.log("LOW-VIX-TOKEN:",vixAdd[1]);
        address vixToken1 = vixAdd[0];
        address vixToken2 = vixAdd[1];
        MockERC20 vixToken1Contract = MockERC20(vixToken1);
        MockERC20 vixToken2Contract = MockERC20(vixToken2);
        console.log("before reset pair");
        console.log("vixtoken1 address: ",vixToken1);
        console.log("vixtoken2 address: ",vixToken2);
        //checking total supply
        console.log("HIGH-VIX balance: ",vixToken1Contract.totalSupply());
        console.log("LOW-VIX balance: ",vixToken2Contract.totalSupply());
        //transfering token
        hook.transferVixtoken(address(this), 50 * (10**18),vixToken1);
        assertEq(vixToken1Contract.totalSupply(), 250 * 1000000 * (10**18));
        assertEq(vixToken2Contract.totalSupply(), 250 * 1000000 * (10**18));
        assertEq(vixToken1Contract.balanceOf(address(this)), 50 * (10**18));
        //expect revert when trying to reset pair before deadline
        uint deadline = 3600 * 24;
        vm.expectRevert();
        hook.resetPair(key.currency0.toId(), key.currency1.toId(),deadline);
        //expect revert when transfering token after deadline
        vm.warp(block.timestamp + 25 hours);
        vm.expectRevert("TOKEN EXPIRED, MINTING CLOSED");
        hook.transferVixtoken(address(this), 250 * (10**18),vixToken1);

        //expect reseting pair after deadline
        
        (address[2] memory vixAdd2) = hook.resetPair(key.currency0.toId(), key.currency1.toId(),deadline);
        address vixToken1Reset = vixAdd2[0];
        address vixToken2Reset = vixAdd2[1];
        MockERC20 vixToken1ResetContract = MockERC20(vixToken1Reset);
        MockERC20 vixToken2ResetContract = MockERC20(vixToken2Reset);

        //

        console.log("after reset pair");
        console.log("vixtoken1 address: ",vixToken1Reset);
        console.log("vixtoken2 address: ",vixToken2Reset);
        //checking total supply
        console.log("HIGH-VIX balance: ",vixToken1ResetContract.totalSupply());
        console.log("LOW-VIX balance: ",vixToken2ResetContract.totalSupply());
        //expect transfering token after deadline
        hook.transferVixtoken(address(this), 250 * (10**18),vixToken1Reset);
        assertEq(vixToken1ResetContract.balanceOf(address(this)), 250 * (10**18));


    }

    

}