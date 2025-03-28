// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Router} from "../src/Router.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";
import {PoolKey,Currency} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

contract RouterTest is Test, DeployPermit2{
    Router myRouter;
    address public _psm = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address payable _router = payable(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af);
    address public _poolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address public permit2;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address mainSender = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address token0 = 0xE79c84ce6e1fc15CC8f2082B3Ac1A78fe3d369F3;
    address token1 = 0xC4422D4DF6f1d7b264dcFe108FC5e88DCe56289F;
    address hook = 0xDd8b031e558186f16995D16868f669aa0c8588c8;
    address deriveAddress = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    uint160 volume = 966;
    struct HookData{
        address deriveAsset;
        uint160 volume;
    }
function setUp() external {
    permit2 = deployPermit2();
     IERC20 _weth = IERC20(weth);
    myRouter = new Router(_psm,_router,_poolManager,permit2);
    console.log("weth balance of router: ",_weth.balanceOf(mainSender));
    console.log("address of contract: ",address(myRouter));
    vm.prank(mainSender);
    uint amount = 1 ether;
    _weth.transfer(address(myRouter),amount);
    console.log("weth balance of router: ",_weth.balanceOf(address(myRouter)));
    
}
function test_poolInit()external{
    vm.prank(mainSender);
    uint160 SQRT_PRICE_1_1 = 79228162514264337593543950336;
    myRouter.createPool(weth,token1,500,10,hook,SQRT_PRICE_1_1);

    vm.prank(mainSender);
    PoolKey memory key = PoolKey({
    currency0: Currency.wrap(weth),
    currency1: Currency.wrap(token1),
    fee: 500,
    tickSpacing: 10,
    hooks: IHooks(hook)
    });
    bytes memory hookData =  abi.encode(HookData(deriveAddress,volume));
    uint48 deadline = uint48(block.timestamp)+ 3600;
    myRouter.ExactInputSwapSingle(
    weth,
    1e18,
    deadline,
     key,
     1e18,
     0,
     permit2,
     true,
     hookData
     );

    myRouter.ExactInputSwapSingle(
    token1,
    39122000000000000000000,
    deadline,
     key,
     39122000000000000000000,
     0,
     permit2,
     false,
     hookData
     );
  console.log("balance of token0: ",IERC20(token0).balanceOf(address(myRouter)));
}



}