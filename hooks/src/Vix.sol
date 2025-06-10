// SPDX-License-Identifier: UNLICENSED


pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {Currency,CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Volatility} from "./lib/Volatility.sol";
import {VolatileERC20} from "./VolatileERC20.sol";
import {BondingCurve} from "./lib/BondingCurve.sol";
import {ImpliedVolatility} from "./lib/ImpliedVolatility.sol";
import {BeforeSwapDelta, toBeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LiquidityConversion} from "./lib/LiquidityConversion.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import "forge-std/console.sol";  // Foundry's console library
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IVolumeOracle} from "./interfaces/IVolumeOracle.sol";

/**
 * @title Vix - Implied Volatility Trading Contract
 * @notice This contract facilitates direct trading based on the implied volatility of a given asset.
 *         It issues two types of tokens per asset:
 *         1. **High Volatility Token (HVT)**: Its value increases when demand and market volatility rise.
 *         2. **Low Volatility Token (LVT)**: Its value increases when demand rises but market volatility decreases.
 *         Users can trade these tokens in a liquidity pool, allowing speculation on market volatility.
 * 
 * @dev This contract utilizes a **custom bonding curve** for pricing, where the price is determined by the 
 *      circulating supply (holding). Instead of relying purely on token holdings, the contract maintains 
 *      an internal accounting system that tracks volatility shifts separately. 
 *      
 *      - **Bonding Curve Mechanism**: The price of each token is influenced by both user demand and the 
 *        contract's internal volatility tracking system. When a user buys a token, the supply increases, 
 *        influencing the bonding curve.
 *      - **Volatility Impact on Pricing**: The contract adjusts its internal holding value (not an actual 
 *        token balance, just a numerical tracker) based on market volatility changes and it will change the price.
 *      - **Reserve Adjustment**: To ensure fair liquidity, the reserves of both HVT and LVT are dynamically 
 *        shifted. When volatility increases, more reserve shifts towards HVT, making it more expensive, 
 *        and when volatility decreases, the reverse happens.
 * 
 * @custom:warning This contract is still under development(not ready for production). Many comments are missing, and some are AI-generated comments.
 *                 Please review the code logic carefully to understand what it exactly doing.
 */

contract Vix is BaseHook{

    // events
    event PairInitiated(address indexed _deriveToken, address indexed _vixHighToken, address indexed _vixLowToken,uint _initiatedTime,uint initiatedIV);
    event HookSwap(bytes32 indexed id, address indexed sender,int128 amount0,int128 amount1,uint128 hookLPfeeAmount0,uint128 hookLPfeeAmount1);
    event AfterVPTSwap(address indexed poolAddress,uint iv,uint price0,uint price1,uint timeStamp);

    //libraris
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;
    using Volatility for int;
    using BondingCurve for uint;
    using ImpliedVolatility for uint160;
    using LiquidityConversion for uint128;
    //errors
    error invalidLiquidityAction();
    // state variables
    mapping(address=>bool) public isPairInitiated;
    mapping(address=>uint) public pairInitiatedTime;
    mapping(address=>uint) public pairEndingTime;
    uint public SLOPE;
    uint public FEE; //1% || 0.01
    uint public BASE_PRICE;
    uint constant public IV_TOKEN_SUPPLY = 250 * 1000000 * (10**18);
    uint constant public RESERVE_SHIFT_SLOPE = 3 * 1e16; //3% and equal to 0.03 * 1e18 || according to reserve shift math
    struct VixTokenData {
        address vixHighToken;
        address vixLowToken;
        uint circulation0;
        uint circulation1;
        uint contractHoldings0;
        uint contractHoldings1;
        uint reserve0;
        uint reserve1;
        address poolAddress;
        uint160 averageIV; // average implied volatility of the pair
        uint160 counts; // iv counts for take average
        address deriveInitiator; // address that initiated the pair
        uint earnings; // earnings of the derive initiator
    }

    struct HookData{
        address poolAdd;
    }

    mapping(address=>VixTokenData) vixTokens;

    address public baseToken;

    struct CallbackData {
    uint256 amountEach; 
    Currency currency0;
    Currency currency1;
    address sender;
    bool isWithdraw;
    }
    //
    address public owner;
    mapping(address => uint) public earnings;
    //Bonding curve contract
    IBondingCurve public bondingCurve;
    IVolumeOracle public volumeOracle;

    //initiating BaseHook with IPoolManager
    constructor(IPoolManager poolManager,address _baseToken,address _bondingCurve,address _volumeOracle,uint slope, uint fee,uint basePrice) BaseHook(poolManager) {
        baseToken = _baseToken;
        SLOPE = slope;
        FEE = fee;
        BASE_PRICE = basePrice;
        bondingCurve = IBondingCurve(_bondingCurve);
        volumeOracle = IVolumeOracle(_volumeOracle);
        owner = msg.sender; // setting the owner of the contract
    }

//getting Hook permission  

// we are just permitting the 4 types of hooks
function getHookPermissions() public pure override returns (Hooks.Permissions memory){
    return Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
    });
}


/**
 * @notice beforeAddLiquidty hook will revert if called

 */

function _beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)internal view override  returns (bytes4){
    revert invalidLiquidityAction();
}


/**
 * @dev Hook function executed before a swap occurs in the pool.
 *      This function determines the swap direction and computes the 
 *      necessary deltas for the swap.
 * 
 * @param key The pool key containing details of the liquidity pool.
 * @param params Swap parameters including amount specified and swap direction.
 * @param data Encoded additional data, expected to contain the derived asset address.
 * 
 * @return bytes4 Selector for the beforeSwap function.
 * @return BeforeSwapDelta Struct containing the calculated deltas for the swap.
 * @return uint24 Always returns 0, can be used for future extensibility.
 */
    
function _beforeSwap(address sender,PoolKey calldata key,SwapParams calldata params,bytes calldata data) internal override returns (bytes4, BeforeSwapDelta, uint24) {
    BeforeSwapDelta beforeSwapDelta;
    HookData memory hookData = abi.decode(data, (HookData));
    console.log("pool address: ",hookData.poolAdd);
    bool isBaseZero = Currency.unwrap(key.currency0) == baseToken;
        uint256 amountInOutPositive = params.amountSpecified > 0
        ? uint256(params.amountSpecified)
        : uint256(-params.amountSpecified);
        
    bytes32 id = keccak256(abi.encode(key)); // using keecak256 to generate bytes32 id for key
    if(isBaseZero){ 
        // for Buy(ZeroForOneSwap) -> only  exactOut - costOfPurchase function will be called
        // for Sell(OneForZeroSwap) -> only exactIn - costOfSell function will be called
     
        //checking the mode of swap 
        if(params.zeroForOne){
            //reverting if the swap is exactIn
            require(params.amountSpecified > 0, "exactIn not allowed");
            // buy token function will call
            (int128 _deltaSpecified, int128 _deltaUnspecified) =buyOperator(key, amountInOutPositive, isBaseZero, hookData.poolAdd);
            beforeSwapDelta = toBeforeSwapDelta(_deltaSpecified, _deltaUnspecified);
            //here specified amount is token1 that mean exact out!.
            emit HookSwap(id, sender, _deltaUnspecified,_deltaSpecified,0, 0);

        }else{
            //reverting if the swap is exactOut
            require(params.amountSpecified < 0, "exactOut not allowed");
            // sell token function will call
            (int128 _deltaSpecified, int128 _deltaUnspecified) = sellOperator(key, amountInOutPositive, isBaseZero, hookData.poolAdd);
            beforeSwapDelta = toBeforeSwapDelta(_deltaSpecified, _deltaUnspecified);
            emit HookSwap(id, sender, _deltaUnspecified,_deltaSpecified,0, 0);
        }
        
    }else{
        // for Buy(OneForZeroSwap) -> only exactOut - costOfPurchase function will be called
        // for Sell(ZeroForOneSwap) -> only exactIn - costOfSell function will be called
        //checking the mode of swap
        if(params.zeroForOne){
            //reverting if the swap is exactOut
            require(params.amountSpecified < 0, "exactOut not allowed");
            // sell token function will call
            (int128 _deltaSpecified, int128 _deltaUnspecified) = sellOperator(key, amountInOutPositive, isBaseZero, hookData.poolAdd);
            beforeSwapDelta = toBeforeSwapDelta(_deltaSpecified, _deltaUnspecified);
            emit HookSwap(id, sender,_deltaSpecified,_deltaUnspecified,0, 0);          

        }else{
            //reverting if the swap is exactIn
            require(params.amountSpecified > 0, "exactIn not allowed");
            // buy token function will call
            (int128 _deltaSpecified, int128 _deltaUnspecified) = buyOperator(key, amountInOutPositive, isBaseZero, hookData.poolAdd);
            beforeSwapDelta = toBeforeSwapDelta(_deltaSpecified, _deltaUnspecified);
            emit HookSwap(id, sender,_deltaSpecified,_deltaUnspecified,0, 0);

        }
    }
    return (this.beforeSwap.selector, beforeSwapDelta, 0);
}
//after swap help us to swap the reserve between vix tokens and mint or burn the contract
//holding according to current IV changes by comparing with initial iv. 
//the contract holdings gonna take part in the pricing
function _afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata data)internal override returns (bytes4, int128){
    HookData memory hookData = abi.decode(data, (HookData));
    address _poolAdd = hookData.poolAdd;
    address _poolAddress = vixTokens[_poolAdd].poolAddress;
    uint160 volume = uint160(volumeOracle.getVolumeData(_poolAddress).volume24HrInQuoteToken);
    uint160 iv = calculateIv(_poolAddress,volume,hookData.poolAdd);
    if(vixTokens[_poolAdd].reserve0 >0 && vixTokens[_poolAdd].reserve1 >0){
        // when we deployed the vix, we take the iv, in after swap, i calc iv again and compare with initial IV
        // initial IV > current IV, reserve swap from high token to low token,
        // and contract holding also burn for high token and mint for low toke.
        // vice versa. we know that contract holding is take part in pricing the token!. 
        (uint reserveShift,uint tokenBurn) =  swapReserve(vixTokens[_poolAdd].averageIV,iv,vixTokens[_poolAdd].reserve0,vixTokens[_poolAdd].reserve1,vixTokens[_poolAdd].circulation0,vixTokens[_poolAdd].circulation1,_poolAdd);
        console.log("reserve shift: ",reserveShift);
        console.log("token burn: ",tokenBurn);
    }
    // updating the average IV
    vixTokens[_poolAdd].averageIV = (vixTokens[_poolAdd].averageIV * vixTokens[_poolAdd].counts + iv) / (vixTokens[_poolAdd].counts + 1);
    vixTokens[_poolAdd].counts += 1; // incrementing the counts for average IV calculation
    console.log("average IV: ",vixTokens[_poolAdd].averageIV);
    console.log("counts: ",vixTokens[_poolAdd].counts);
    console.log("contract holding0: ",vixTokens[_poolAdd].contractHoldings0);
    console.log("contract holding1: ",vixTokens[_poolAdd].contractHoldings1);
    // after swap event
           emit AfterVPTSwap(
            _poolAddress,
            iv,
            bondingCurve.settingPrice(SLOPE,(vixTokens[_poolAdd].contractHoldings0/1e18), BASE_PRICE),
            bondingCurve.settingPrice(SLOPE,(vixTokens[_poolAdd].contractHoldings1/1e18), BASE_PRICE),
            block.timestamp
        );
    
    return(this.afterSwap.selector,0);
}



function buyOperator(PoolKey calldata key,uint amount,bool zeroIsBase,address _poolAdd) private returns (int128,int128){
    VixTokenData storage vixTokenData = vixTokens[_poolAdd];
   bool isHighToken = (address(Currency.unwrap(key.currency0)) == vixTokenData.vixHighToken || address(Currency.unwrap(key.currency1)) == vixTokenData.vixHighToken);
    return isHighToken ? buyHighToken(key,vixTokenData,amount,zeroIsBase) : buyLowToken(key,vixTokenData,amount,zeroIsBase);
}

function sellOperator(PoolKey calldata key,uint amount,bool zeroIsBase,address _poolAdd) private returns (int128,int128){
    VixTokenData storage vixTokenData = vixTokens[_poolAdd];
   bool isHighToken = (address(Currency.unwrap(key.currency0)) == vixTokenData.vixHighToken || address(Currency.unwrap(key.currency1)) == vixTokenData.vixHighToken);
    return isHighToken ? sellHighToken(key,vixTokenData,amount,zeroIsBase) : sellLowToken(key,vixTokenData,amount,zeroIsBase);
}

function buyHighToken(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 purchaseToken = amountInOutPositive/1e18;
    require(purchaseToken > 0, "amount should be greater than 0");
    uint contractHoldings = vixTokenData.contractHoldings0/1e18;
    uint256 curveCost = bondingCurve.costOfPurchasingToken(SLOPE,contractHoldings,purchaseToken,BASE_PRICE);
    uint fees = (curveCost * FEE) / 1e18;
    uint256 cost = curveCost+fees;
    earnings[owner] += fees/2; // owner will get the fees
    vixTokenData.earnings += fees/2; // derive initiator will get the fees

   unchecked {
     vixTokenData.contractHoldings0 += amountInOutPositive;
    vixTokenData.circulation0 += amountInOutPositive;
    vixTokenData.reserve0 += cost;
   }  
    if(zeroIsBase){
        key.currency0.take(poolManager, address(this), cost, true);
        key.currency1.settle(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.take(poolManager, address(this), cost, true);
        key.currency0.settle(poolManager, address(this), amountInOutPositive, true);
    }
    return (-int128(uint128(amountInOutPositive)), int128(uint128(cost)));
}

function buyLowToken(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 purchaseToken = amountInOutPositive/1e18;
    require(purchaseToken > 0, "amount should be greater than 0");
    uint contractHoldings = vixTokenData.contractHoldings1/1e18;
    uint256 curveCost = bondingCurve.costOfPurchasingToken(SLOPE,contractHoldings,purchaseToken,BASE_PRICE);
    uint fees = (curveCost * FEE) / 1e18;
    uint256 cost = curveCost+fees;
    earnings[owner] += (fees/2); // owner will get the fees
    vixTokenData.earnings += (fees/2); // derive initiator will get the fees
    unchecked {
    vixTokenData.contractHoldings1 += amountInOutPositive;
    vixTokenData.circulation1 += amountInOutPositive;
    vixTokenData.reserve1 += cost;
    }
    if(zeroIsBase){
        key.currency0.take(poolManager, address(this), cost, true);
        key.currency1.settle(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.take(poolManager, address(this), cost, true);
        key.currency0.settle(poolManager, address(this), amountInOutPositive, true);
    }
    return (-int128(uint128(amountInOutPositive)), int128(uint128(cost)));
}

function sellHighToken(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 salesToken = amountInOutPositive/1e18;
    require(salesToken > 0, "amount should be greater than 0");
    uint contractHoldings = vixTokenData.contractHoldings0/1e18;
    uint256 curveCost = bondingCurve.costOfSellingToken(SLOPE,contractHoldings,salesToken,BASE_PRICE);
    uint fees = (curveCost * FEE) / 1e18;
    uint256 baseToken_returns = curveCost - ((curveCost * FEE) / 1e18);
    earnings[owner] += fees;
    unchecked {
    vixTokenData.contractHoldings0 -= amountInOutPositive;
    vixTokenData.circulation0 -= amountInOutPositive;
    vixTokenData.reserve0 -= baseToken_returns;
    }
    if(zeroIsBase){
        key.currency0.settle(poolManager, address(this),baseToken_returns, true);
        key.currency1.take(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.settle(poolManager, address(this),baseToken_returns, true);
        key.currency0.take(poolManager, address(this), amountInOutPositive, true);
    }
    return (int128(uint128(amountInOutPositive)), -int128(uint128(baseToken_returns)));
}

function sellLowToken(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 salesToken = amountInOutPositive/1e18;
    require(salesToken > 0, "amount should be greater than 0");
    uint contractHoldings = vixTokenData.contractHoldings1/1e18;
    uint256 curveCost = bondingCurve.costOfSellingToken(SLOPE,contractHoldings,salesToken,BASE_PRICE);
    uint fees = (curveCost * FEE) / 1e18;
    uint256 baseToken_returns = curveCost - ((curveCost * FEE) / 1e18);
    earnings[owner] += fees;
    unchecked {
            vixTokenData.contractHoldings1 -= amountInOutPositive;
            vixTokenData.circulation1 -= amountInOutPositive;
            vixTokenData.reserve1 -= baseToken_returns;
    }
    if(zeroIsBase){
        key.currency0.settle(poolManager, address(this),baseToken_returns, true);
        key.currency1.take(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.settle(poolManager, address(this),baseToken_returns, true);
        key.currency0.take(poolManager, address(this), amountInOutPositive, true);
    }
    return (int128(uint128(amountInOutPositive)), -int128(uint128(baseToken_returns)));
}

function withdrawEarningsForOwner() public {
    require(owner == msg.sender,"Not authorized to withdraw earnings");
    uint256 amountEarned = earnings[msg.sender];
    require(amountEarned > 0, "No earnings to withdraw");
    earnings[msg.sender] = 0; // State change before external call
    Currency base = Currency.wrap(baseToken); 
    console.log("amount earned for owner: ",amountEarned);
        poolManager.unlock(
        abi.encode(
            CallbackData(
                amountEarned,
                base,
                base,
                msg.sender,
                true
            )
        )
    );
    
}

function withdrawEarningsForInitiator(address _poolAdd) public {
    VixTokenData storage vixTokenData = vixTokens[_poolAdd];
    require(vixTokenData.deriveInitiator == msg.sender,"Not authorized to withdraw earnings");
    uint256 amountEarned = vixTokenData.earnings;
    require(amountEarned > 0, "No earnings to withdraw");
    vixTokenData.earnings = 0; // State change before external call
    Currency base = Currency.wrap(baseToken); 
        poolManager.unlock(
        abi.encode(
            CallbackData(
                amountEarned,
                base,
                base,
                msg.sender,
                true
            )
        )
    );
}




/**
 * @dev Deploys two volatile ERC20 tokens for a given derived asset and initializes their liquidity.
 *      Ensures that an existing pair is either inactive or expired before deploying new tokens.
 *
 * @param deriveToken The address of the derived asset for which the volatile tokens are created.
 * @param _tokenName An array containing the names of the two volatile tokens.
 * @param _tokenSymbol An array containing the symbols of the two volatile tokens.
 *
 * @return address[2] The addresses of the newly deployed volatile ERC20 tokens.
 */

function deploy2Currency(address deriveToken, string[2] memory _tokenName, string[2] memory _tokenSymbol,address _poolAddress ) public returns(address[2] memory){
    require((isPairInitiated[deriveToken] == false || pairEndingTime[deriveToken] < block.timestamp),"Pair still active");
    isPairInitiated[deriveToken] = true;
    pairInitiatedTime[deriveToken] = block.timestamp;
    address[2] memory vixTokenAddresses;
    for(uint i = 0; i < 2; i++){
            VolatileERC20 v_token = new VolatileERC20(_tokenName[i], _tokenSymbol[i]);
            vixTokenAddresses[i] = address(v_token);
            mintVixToken(address(this),address(v_token),IV_TOKEN_SUPPLY);
    }

    uint160 volume = uint160(volumeOracle.getVolumeData(_poolAddress).volume24HrInQuoteToken);
    uint160 initialIv = calculateIv(_poolAddress,volume,deriveToken);
    vixTokens[deriveToken] = VixTokenData(vixTokenAddresses[0],vixTokenAddresses[1],0,0,0,0,0,0,_poolAddress,initialIv,0,msg.sender,0);
    liquidateVixTokenToPm(IV_TOKEN_SUPPLY, vixTokenAddresses[0], vixTokenAddresses[1]);
    emit PairInitiated(deriveToken,vixTokenAddresses[0],vixTokenAddresses[1],block.timestamp,initialIv);
    return (vixTokenAddresses);
}

/**
 * @dev Transfers a specified amount of Vix tokens to the pool manager for liquidity provisioning.
 *
 * @param amountEach The amount of each Vix token to be transferred.
 * @param currency0 The address of the first currency (token) being transferred.
 * @param currency1 The address of the second currency (token) being transferred.
 *
 * @return bool Returns true if the operation is successful.
 */

function liquidateVixTokenToPm(uint256 amountEach, address currency0, address currency1) internal returns (bool) {
    
    poolManager.unlock(
        abi.encode(
            CallbackData(
                amountEach, 
                Currency.wrap(currency0),
                Currency.wrap(currency1),
               address(this),
               false
            )
        )
    );
}

/**
 * @dev Callback function triggered by the pool manager to handle unlocking and transferring tokens.
 *      This function settles and transfers liquidity amounts between the pool and the contract/sender.
 *
 * @param data Encoded callback data containing details of the transfer operation.
 *
 * @return bytes Returns an empty byte array upon successful execution.
 */

function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
    CallbackData memory callbackData = abi.decode(data, (CallbackData));
    if(callbackData.isWithdraw){
        callbackData.currency0.settle(poolManager,address(this),callbackData.amountEach,true);
        callbackData.currency0.take(poolManager,callbackData.sender,callbackData.amountEach,false);
    }else{
        	callbackData.currency0.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false 
    );
    callbackData.currency1.settle(
            poolManager,
            callbackData.sender,
            callbackData.amountEach,
            false
    );

    callbackData.currency0.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true 
    );
    callbackData.currency1.take(
            poolManager,
            address(this),
            callbackData.amountEach,
            true
    );
    }
	return "";
}

function mintVixToken(address to,address _token,uint _amount) internal returns (bool){
    VolatileERC20 v_token = VolatileERC20(_token);
    v_token.mint(to, _amount);
    return true;
}



function getVixData(address poolAdd)public view returns (address vixHighToken,address _vixLowToken,uint _circulation0,uint _circulation1,uint _contractHoldings0,uint _contractHoldings1,uint _reserve0,uint _reserve1,address _poolAddress){
     VixTokenData memory vixTokenData = vixTokens[poolAdd];
     return (vixTokenData.vixHighToken,vixTokenData.vixLowToken,vixTokenData.circulation0,vixTokenData.circulation1,vixTokenData.contractHoldings0,vixTokenData.contractHoldings1,vixTokenData.reserve0,vixTokenData.reserve1,vixTokenData.poolAddress);
}

/**
 * @dev it will calculate the implied volatility of the pair
 *
 * @param _poolAddress poolAddress of the pair from uniswap v3.
 * @param volume volume of the pool in ETH from uniswap v3.
 * @return _iv it will return the iv.
 */

function calculateIv(address _poolAddress,uint160 volume,address poolAdd) public view returns (uint160 _iv){
    console.log("pool address: ",_poolAddress); 
   address poolAddress= _poolAddress;
   IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
    uint128 liquidity = pool.liquidity();
    (,int24 tick,,,,,) = pool.slot0();
    int24 tickSpacing = pool.tickSpacing();
    address token0 = pool.token0();
    address token1 = pool.token1();
    uint24 fee = pool.fee();
    uint8 decimal0 = MockERC20(token0).decimals();
    uint8 decimal1 = MockERC20(token1).decimals();
    // Compute sqrt ratios
    int24 bottomTick = (tick / tickSpacing) * tickSpacing;
    int24 upperTick = bottomTick + tickSpacing;

    uint160 sa = TickMath.getSqrtRatioAtTick(bottomTick);
    uint160 sb = TickMath.getSqrtRatioAtTick(upperTick);
    uint160 sp = TickMath.getSqrtRatioAtTick(tick);
 
    // Call tickLiquidity with full args
    (uint liq,uint amount0,uint amount1,uint160 scaleFactor) = LiquidityConversion.tickLiquidity(
        liquidity,
        sa, // bottom tick
        sb, // top tick
        sp, // current tick
        decimal0,
        decimal1,
        tick < 0
    );
    console.log("amount0: ",amount0);
    console.log("amount1: ",amount1);
    console.log("liquidity: ",liq);
    console.log("scaleFactor: ",scaleFactor);
    uint160 scaledDownFee = uint160(fee);
    uint160 iv =  volume.ivCalculation(uint160(liq),scaleFactor,scaledDownFee,false);//added the isScaled boolean
    console.log("iv: ",iv);
    return iv;
}


function swapReserve(uint averageIV, uint currentIv, uint reserve0, uint reserve1,uint circulation0,uint circulation1,address poolAdd) public  returns(uint,uint){
    if(averageIV > currentIv && reserve0 > 1 ether){
        /* 
        1. swap certain amount of reserve0 (high token Reserve) to reserve1 (low token Reserve) 
        2. burn contract holding 0 (high token) and mint contract holding 1 (low token)
        3. price of high token will decrease due to burn of contract holding 0 
        4. price of low token will increase due to mint of contract holding 1
        4. for smooth sell and buy, we swapped reserve
        */
        uint reserveShift = (RESERVE_SHIFT_SLOPE * reserve0) / 1e18;
        require(reserveShift > 0,"reserve shift should be greater than 0");
        uint tokenBurn = (reserveShift * circulation0) / (reserve0+1);
        uint tokenMint = (reserveShift * circulation1) / (reserve1+1);


        vixTokens[poolAdd].reserve0 -= reserveShift;
        vixTokens[poolAdd].reserve1 += reserveShift;
        vixTokens[poolAdd].contractHoldings0 -= tokenBurn;
        vixTokens[poolAdd].contractHoldings1 += tokenMint;
        return (reserveShift,tokenBurn);


    }else if(averageIV < currentIv && reserve1 >  1 ether){
        /* 
        1. swap certain amount of reserve1 (low token Reserve) to reserve0 (high token Reserve) 
        2. burn contract holding 1 (low token) and mint contract holding 0 (high token)
        3. price of low token will decrease due to burn of contract holding 1 
        4. price of high token will increase due to mint of contract holding 0
        4. for smooth sell and buy, we swapped reserve
        */

        uint reserveShift = (RESERVE_SHIFT_SLOPE * reserve1) / 1e18;
        require(reserveShift > 0,"reserve shift should be greater than 0");
        uint tokenBurn = (reserveShift * circulation1) / (reserve1+1);
        uint tokenMint = (reserveShift * circulation0) / (reserve0+1);
        vixTokens[poolAdd].reserve0 += reserveShift;
        vixTokens[poolAdd].reserve1 -= reserveShift;
        vixTokens[poolAdd].contractHoldings1 -= tokenBurn;
        vixTokens[poolAdd].contractHoldings0 += tokenMint;
        return (reserveShift,tokenMint);
    }else{
        return (0,0);
    }
     
}

function vixTokensPrice(uint contractHoldings) public view returns(uint){
    uint price = ((SLOPE * contractHoldings) / 1e18) + BASE_PRICE;
    return (price); // we should do price/1e18 for readable price
    
}


}

// derive token position will be act as isBaseZero in liquidityConversion.sol
// we should support multiple fee in iv calculation
// 
