// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    address public baseToken;
    address public deriveAsset;
    address[2] ivTokenAdd;
    uint160 _volume = 724;
    struct HookData{
        address deriveAsset;
        uint160 volume;
    }

    function setUp()external {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();   
        console.log("_baseTokenCurrency: ",Currency.unwrap(currency0));
        baseToken = address(Currency.unwrap(currency0));
        deriveAsset = address(Currency.unwrap(currency1));
        address hookAddress = address(
            uint160(
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG |
                    Hooks.AFTER_SWAP_FLAG
            )
        );
        deployCodeTo("Vix.sol",abi.encode(manager,baseToken),hookAddress);

        hook = Vix(hookAddress);
        uint256 pairDeadline = block.timestamp + (3600*24);

        uint160 tickLiquidity = 13401+4761696;
        uint160 fee = 0.003 * 1000;
        (address[2] memory ivTokenAddresses) = hook.deploy2Currency(deriveAsset,["HIGH-IV-BTC","LOW-IV-BTC"],["HIVB","LIVB"],address(0xCBCdF9626bC03E24f779434178A73a0B4bad62eD),_volume,pairDeadline);
        ivTokenAdd = ivTokenAddresses;
        assertEq(MockERC20(ivTokenAdd[0]).balanceOf(address(manager)), MockERC20(ivTokenAdd[0]).totalSupply());
        assertEq(MockERC20(ivTokenAdd[1]).balanceOf(address(manager)), MockERC20(ivTokenAdd[1]).totalSupply());
        console.log("vix token 0 address",ivTokenAdd[0]);
        console.log("vix token 1 address",ivTokenAdd[1]);
        uint token0ClaimID = CurrencyLibrary.toId(Currency.wrap(ivTokenAdd[0]));
        uint token1ClaimID = CurrencyLibrary.toId(Currency.wrap(ivTokenAdd[1]));

        uint token0ClaimsBalance = manager.balanceOf(
            address(hook),
            token0ClaimID
        );
        uint token1ClaimsBalance = manager.balanceOf(
            address(hook),
            token1ClaimID
        );

        console.log("token0 claims balance: ",token0ClaimsBalance);
        console.log("token1 claims balance: ",token1ClaimsBalance);
        console.log("hook address: ",address(hook));

    }

    function test_swapHighVolatileToken_ExactIn() public{
        //vm.skip(true);
       
        Currency token0;
        Currency token1;

        (token0,token1) = SortTokens.sort(MockERC20(baseToken),MockERC20(ivTokenAdd[0]));
        //initializing Pool for base token & high IV token

        (key, ) = initPool(
            token0,
            token1, //high IV token
            hook,
            3000,
            SQRT_PRICE_1_1
        );
     
        //swap
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
        takeClaims: false,
        settleUsingBurn: false
        });
        console.log("balanceOf high vix token before swap:",MockERC20(ivTokenAdd[0]).balanceOf(address(this)));
   
        bytes memory hookData =  abi.encode(HookData(deriveAsset, _volume));

        swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
            zeroForOne: true,
            amountSpecified: -1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }
            ), 
            settings,
            hookData
        );
          (address vixHighToken,address _vixLowToken,uint _circulation0,uint _circulation1,uint _contractHoldings0,uint _contractHoldings1,uint _reserve0,uint _reserve1,address _poolAddress) =hook.getVixData(deriveAsset);
          console.log("circulation0: ",_circulation0);
          console.log("reserve0: ",_reserve0);
          console.log("contractHoldings0: ",_contractHoldings0);
          console.log("balanceOf high vix after swap:",MockERC20(ivTokenAdd[0]).balanceOf(address(this)));

        uint balance = MockERC20(ivTokenAdd[0]).balanceOf(address(this));
        uint halfVixToken = MockERC20(ivTokenAdd[0]).balanceOf(address(this));
        MockERC20(ivTokenAdd[0]).approve(address(swapRouter),halfVixToken);
        swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
                zeroForOne:false,
                amountSpecified: -int(halfVixToken),
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            hookData
        );

        console.log("balanceOf high vix after sold:",MockERC20(ivTokenAdd[0]).balanceOf(address(this)));

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

    function test_swapHighVolatileToken_ExactOut() external{
        //    vm.skip(true);
        Currency token0;
        Currency token1;

        (token0,token1) = SortTokens.sort(MockERC20(baseToken),MockERC20(ivTokenAdd[0]));
        //initializing Pool for base token & high IV token
        (key, ) = initPool(
            token0,
            token1, //high IV token
            hook,
            3000,
            SQRT_PRICE_1_1
        );

        //swap
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
        takeClaims: false,
        settleUsingBurn: false
        });
        console.log("balanceOf high vix token before swap in exact out:",MockERC20(ivTokenAdd[0]).balanceOf(address(this)));
        bytes memory hookData =  abi.encode(HookData(deriveAsset, _volume));

        swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
            zeroForOne: true,
            amountSpecified: 166665 * 1 ether,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }
            ), 
            settings,
            hookData
        );
        console.log("balanceOf high vix token after swap in exact out:",MockERC20(ivTokenAdd[0]).balanceOf(address(this)));
        uint balance = MockERC20(ivTokenAdd[0]).balanceOf(address(this));

        MockERC20(ivTokenAdd[0]).approve(address(swapRouter),uint(balance));
        swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
                zeroForOne:false,
                amountSpecified: 0.9 ether, //base token oneForZero means vix/eth 
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            hookData
        );

        console.log("balanceOf high vix after sold:",MockERC20(ivTokenAdd[0]).balanceOf(address(this)));
    }

    function test_swapLowVolatileToken_ExactIn() external{
        //vm.skip(true);
        Currency token0;
        Currency token1;

        (token0,token1) = SortTokens.sort(MockERC20(baseToken),MockERC20(ivTokenAdd[1]));
        //initializing Pool for base token & low IV token
        (key, ) = initPool(
            token0,
            token1, //low IV token
            hook,
            3000,
            SQRT_PRICE_1_1
        );

        //swap
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
        takeClaims: false,
        settleUsingBurn: false
        });
        console.log("balanceOf low vix token before swap:",MockERC20(ivTokenAdd[1]).balanceOf(address(this)));
        bytes memory hookData =   abi.encode(HookData(deriveAsset, _volume));

        swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
            zeroForOne: true,
            amountSpecified: -1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }
            ), 
            settings,
            hookData
        );
        console.log("balanceOf low vix token after swap:",MockERC20(ivTokenAdd[1]).balanceOf(address(this)));

        uint balance = MockERC20(ivTokenAdd[1]).balanceOf(address(this));
        uint halfVixToken = MockERC20(ivTokenAdd[1]).balanceOf(address(this));
        MockERC20(ivTokenAdd[1]).approve(address(swapRouter),halfVixToken);
        swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
                zeroForOne:false,
                amountSpecified: -int(halfVixToken),
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            hookData
        );

        console.log("balanceOf vix1 after:",MockERC20(ivTokenAdd[1]).balanceOf(address(this)));

    }

    function test_swapLowVolatileToken_ExactOut() external{
        //vm.skip(true);
        Currency token0;
        Currency token1;

        (token0,token1) = SortTokens.sort(MockERC20(baseToken),MockERC20(ivTokenAdd[1]));
        //initializing Pool for base token & low IV token
        (key, ) = initPool(
            token0,
            token1, //low IV token
            hook,
            3000,
            SQRT_PRICE_1_1
        );

        //swap
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
        takeClaims: false,
        settleUsingBurn: false
        });
        console.log("balanceOf low vix token before in exact out:",MockERC20(ivTokenAdd[1]).balanceOf(address(this)));
        bytes memory hookData = abi.encode(HookData(deriveAsset, _volume));

        swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
            zeroForOne: true,
            amountSpecified: 166665 * 1 ether,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }
            ), 
            settings,
            hookData
        );
        console.log("balanceOf low vix token after swap in exact out:",MockERC20(ivTokenAdd[1]).balanceOf(address(this)));
        
      
         uint balance = MockERC20(ivTokenAdd[1]).balanceOf(address(this));

        MockERC20(ivTokenAdd[1]).approve(address(swapRouter),uint(balance));
        swapRouter.swap(
            key,
            IPoolManager.SwapParams(
            {
                zeroForOne:false,
                amountSpecified: 0.9 ether, //base token oneForZero means vix/eth 
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            hookData
        );

        console.log("balanceOf low vix token after sold:",MockERC20(ivTokenAdd[1]).balanceOf(address(this)));
    
    }

    function test_calculateIv() external{
       (uint reserveShift,uint tokenBurn) = hook.swapReserve(20930878980,23861137419,1000000000000000000,1000000000000000000,1000000000000000000000,1000000000000000000000,address(0));
       console.log("reserve shift: ",reserveShift);
       console.log("token burn: ",tokenBurn);
        uint price = hook.vixTokensPrice((166670 * 1e18));
        uint160 volume = 3590;
        uint iv =  hook.calculateIv(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8, volume);
        console.log("iv: ",iv);
        console.log("price: ",price);
    }

    // function test_resetPair() external{
    //     //expect revert when trying to reset pair before deadline
    //     uint deadline = 3600 * 24;
    //     vm.expectRevert();
    //     hook.resetPair(token0,token1,deadline);
    //     //expect revert when transfering token after deadline
    //     vm.warp(block.timestamp + 25 hours);
    //     vm.expectRevert("TOKEN EXPIRED, MINTING CLOSED");
    //     hook.transferVixtoken(address(this), 250 * (10**18),vixTokens[0]);
    // }
    
    

}


/*

Limitations:
    1. ETH should be in token1 for the liquidity conversion to work correctly.(because it is static right now)
 */


