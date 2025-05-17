// SPDX-License-Identifier: UNLICENSED


pragma solidity ^0.8.26;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
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
    event PairInitiated(address indexed _deriveToken, address indexed _vixHighToken, address indexed _vixLowToken,uint _initiatedTime ,uint256 _deadline,uint initiatedIV);
    event PairExpired(address indexed deriveToken, address indexed vixHighToken, address indexed vixLowToken, uint initatedIV, uint expiredTime);
    event HookSwap(bytes32 indexed id, address indexed sender,int128 amount0,int128 amount1,uint128 hookLPfeeAmount0,uint128 hookLPfeeAmount1);


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
    uint constant public SLOPE = 1e9; // 0.000000000000001
    uint constant public FEE = 10000; //1% || 0.01
    uint constant public BASE_PRICE = 0.0000060 * 1e18;
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
        uint160 initialIv;
    }

    struct HookData{
        address deriveAsset;
        uint160 volume;
    }

    mapping(address=>VixTokenData) vixTokens;

    address public baseToken;

    struct CallbackData {
    uint256 amountEach; 
    Currency currency0;
    Currency currency1;
    address sender;
    }


    //initiating BaseHook with IPoolManager
    constructor(IPoolManager poolManager,address _baseToken) BaseHook(poolManager) {
        baseToken = _baseToken;
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

function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata , bytes calldata)internal view override  returns (bytes4){
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
    
function _beforeSwap(address sender,PoolKey calldata key,IPoolManager.SwapParams calldata params,bytes calldata data) internal override returns (bytes4, BeforeSwapDelta, uint24) {
    console.log("swap triggered");
    BeforeSwapDelta beforeSwapDelta;
    uint256 amountInOutPositive = params.amountSpecified > 0
        ? uint256(params.amountSpecified)
        : uint256(-params.amountSpecified);

    HookData memory hookData = abi.decode(data, (HookData));
    address _deriveAsset = hookData.deriveAsset;
    bool zeroIsBase = (Currency.unwrap(key.currency0) == baseToken);
    require(pairEndingTime[_deriveAsset] > block.timestamp,"Pair expired!, reset it");
    if (params.zeroForOne) {
        // it can handle buy/sell of volatile tokens!. and it can also handle the
        // token sorting  
        (int128 _deltaSpecified, int128 _deltaUnspecified) = zeroForOneOperator(
            key,
            _deriveAsset,
            params,
            amountInOutPositive,
            zeroIsBase
        );
        beforeSwapDelta = toBeforeSwapDelta(_deltaSpecified, _deltaUnspecified);
    }else{
        (int128 _deltaSpecified, int128 _deltaUnspecified) = oneForZeroOperator(
            key,
            _deriveAsset,
            params,
            amountInOutPositive,
            zeroIsBase
        );
        beforeSwapDelta = toBeforeSwapDelta(_deltaSpecified, _deltaUnspecified);
        bytes32 id = keccak256(abi.encode(key)); // using keecak256 to generate bytes32 id for key

        //amount1 is deltaspecified if the amountSpecified is positive, amount0 is deltaunspecified if the amountSpecified is negative 
        if(params.amountSpecified < 0){
            emit HookSwap(id,sender,_deltaSpecified,_deltaUnspecified,0, 0); 
        }else{
            emit HookSwap(id,sender,_deltaUnspecified,_deltaSpecified,0, 0); 

        }
    }
    return (this.beforeSwap.selector, beforeSwapDelta, 0);
}
//after swap help us to swap the reserve between vix tokens and mint or burn the contract
//holding according to current IV changes by comparing with initial iv. 
//the contract holdings gonna take part in the pricing
function _afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata data)internal override returns (bytes4, int128){
    HookData memory hookData = abi.decode(data, (HookData));
    address _deriveAsset = hookData.deriveAsset;
    address _poolAddress = vixTokens[_deriveAsset].poolAddress;
    uint160 initialIv = vixTokens[_deriveAsset].initialIv;
    uint160 iv = calculateIv(_poolAddress,hookData.volume);
    if(vixTokens[_deriveAsset].reserve0 >0 && vixTokens[_deriveAsset].reserve1 >0){
        // when we deployed the vix, we take the iv, in after swap, i calc iv again and compare with initial IV
    // initial IV > current IV, reserve swap from high token to low token,
    // and contract holding also burn for high token and mint for low toke.
    // vice versa. we know that contract holding is take part in pricing the token!. 
        (uint reserveShift,uint tokenBurn) =  swapReserve(initialIv,iv,vixTokens[_deriveAsset].reserve0,vixTokens[_deriveAsset].reserve1,vixTokens[_deriveAsset].circulation0,vixTokens[_deriveAsset].circulation1,_deriveAsset);
        console.log("reserve shift: ",reserveShift);
        console.log("token burn: ",tokenBurn);

    }
    return(this.afterSwap.selector,0);
}

/**
 * @dev Handles the swap logic when swapping from token0 to token1 (zeroForOne).
 *      Determines whether the asset being swapped is a high or low volatility token 
 *      and routes the execution accordingly.
 *
 * @param key The pool key containing details of the liquidity pool.
 * @param _deriveAsset The address of the derived asset being swapped.
 * @param params Swap parameters including amount specified and swap direction.
 * @param amountInOutPositive The absolute value of the swap amount.
 * @param zeroIsBase Boolean indicating whether currency0 is the base token.
 *
 * @return int128 The delta amount of the specified token after processing the swap.
 * @return int128 The delta amount of the unspecified token after processing the swap.
 */

function zeroForOneOperator(PoolKey calldata key,address _deriveAsset,IPoolManager.SwapParams calldata params,uint256 amountInOutPositive,bool zeroIsBase) public returns (int128, int128) {
    VixTokenData storage vixTokenData = vixTokens[_deriveAsset];
    address _currency0 = Currency.unwrap(key.currency0);
    address _currency1 = Currency.unwrap(key.currency1);
    bool isHighToken = (_currency0 == vixTokenData.vixHighToken || _currency1 == vixTokenData.vixHighToken);
    bool isExactIn = params.amountSpecified < 0;
    
    return isHighToken
        ? processHighToken_ZeroOne(key, vixTokenData, amountInOutPositive, zeroIsBase, isExactIn)
        : processLowToken_ZeroOne(key, vixTokenData, amountInOutPositive, zeroIsBase, isExactIn);
}

/**
 * @dev Processes a swap involving a high-volatility token when swapping from token0 to token1.
 *      Determines whether the swap is an exact input or exact output transaction and 
 *      routes the execution accordingly.
 *
 * @param key The pool key containing details of the liquidity pool.
 * @param vixTokenData Storage reference to the Vix token data for the derived asset.
 * @param amountInOutPositive The absolute value of the swap amount.
 * @param zeroIsBase Boolean indicating whether currency0 is the base token.
 * @param isExactIn Boolean indicating if the swap is an exact input transaction (true) or exact output (false).
 *
 * @return int128 The delta amount of the specified token after processing the swap.
 * @return int128 The delta amount of the unspecified token after processing the swap.
 */

function processHighToken_ZeroOne(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase,bool isExactIn) private returns (int128, int128) {
    uint256 circulation = vixTokenData.circulation0;
    if (isExactIn) {
        return zeroIsBase
            ? buyHighTokenExactInput(key, vixTokenData, amountInOutPositive,zeroIsBase)
            : sellHighTokenExactInput(key, vixTokenData, amountInOutPositive,zeroIsBase);
    } else {
        return zeroIsBase
            ? buyHighTokenExactOutput(key, vixTokenData, amountInOutPositive,zeroIsBase)
            : sellHighTokenExactOutput(key, vixTokenData, amountInOutPositive,zeroIsBase);
    }
}



/**
 * @dev Handles the purchase of a high-volatility token with an exact input amount.
 *      Calculates the number of tokens returned based on the given cost, updates the 
 *      circulation and reserves, and transfers the appropriate amounts between the pool 
 *      and contract.
 *
 * @param key The pool key containing details of the liquidity pool.
 * @param vixTokenData Storage reference to the Vix token data for the derived asset.
 * @param amountInOutPositive The exact input amount of currency0 used to purchase the high-volatility token.
 *
 * @return int128 The delta amount of currency0 spent in the swap (positive value).
 * @return int128 The delta amount of the high-volatility token received in the swap (negative value).
 */

function buyHighTokenExactInput(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    console.log("buy high vix");
    uint256 tokenReturns = vixTokenData.circulation0.tokensForGivenCost(amountInOutPositive, SLOPE, FEE, BASE_PRICE) * 1e18;
    console.log("token Return: ",tokenReturns);
    vixTokenData.contractHoldings0 += tokenReturns;
    vixTokenData.circulation0 += tokenReturns;
    vixTokenData.reserve0 += amountInOutPositive;
    if(zeroIsBase){
        key.currency0.take(poolManager, address(this), amountInOutPositive, true);
        key.currency1.settle(poolManager, address(this), tokenReturns, true);
    }else{
        key.currency1.take(poolManager, address(this), amountInOutPositive, true);
        key.currency0.settle(poolManager, address(this), tokenReturns, true);       
    }
    return (int128(uint128(amountInOutPositive)), -int128(uint128(tokenReturns)));
}

/**
 * @dev Handles the purchase of a high-volatility token with an exact output amount.
 *      Determines the required cost to obtain the desired number of tokens, updates
 *      circulation and reserves, and transfers the appropriate amounts between the
 *      pool and contract.
 *
 * @param key The pool key containing details of the liquidity pool.
 * @param vixTokenData Storage reference to the Vix token data for the derived asset.
 * @param amountInOutPositive The exact output amount of high-volatility tokens to be received.
 *
 * @return int128 The delta amount of the high-volatility token spent in the swap (negative value).
 * @return int128 The delta amount of currency0 required to complete the swap (positive value).
 */

function buyHighTokenExactOutput(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 cost = vixTokenData.circulation0.costOfPurchasingToken(amountInOutPositive, SLOPE, BASE_PRICE, FEE);
    vixTokenData.contractHoldings0 += amountInOutPositive;
    vixTokenData.circulation0 += amountInOutPositive;
    vixTokenData.reserve0 += cost;
    if(zeroIsBase){
        key.currency0.take(poolManager, address(this), cost, true);
        key.currency1.settle(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.take(poolManager, address(this), cost, true);
        key.currency0.settle(poolManager, address(this), amountInOutPositive, true);
    }
    return (-int128(uint128(amountInOutPositive)), int128(uint128(cost)));
}

function processLowToken_ZeroOne(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase,bool isExactIn) private returns (int128, int128) {
    uint256 circulation = vixTokenData.circulation1;
    if (isExactIn) {
        return zeroIsBase
            ? buyLowTokenExactInput(key, vixTokenData, amountInOutPositive,zeroIsBase)
            : sellLowTokenExactInput(key, vixTokenData, amountInOutPositive, zeroIsBase);
    } else {
        return zeroIsBase
            ? buyLowTokenExactOutput(key, vixTokenData, amountInOutPositive,zeroIsBase)
            : sellLowTokenExactOutput(key, vixTokenData, amountInOutPositive,zeroIsBase);
    }
}

function buyLowTokenExactInput(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 tokenReturns = vixTokenData.circulation1.tokensForGivenCost(amountInOutPositive, SLOPE, FEE, BASE_PRICE) * 1e18;
    vixTokenData.contractHoldings1 += tokenReturns;
    vixTokenData.circulation1 += tokenReturns;
    vixTokenData.reserve1 += amountInOutPositive;
    if(zeroIsBase){
        key.currency0.take(poolManager, address(this), amountInOutPositive, true);
        key.currency1.settle(poolManager, address(this), tokenReturns, true);
    }else{
        key.currency1.take(poolManager, address(this), amountInOutPositive, true);
        key.currency0.settle(poolManager, address(this), tokenReturns, true);
    }
    return (int128(uint128(amountInOutPositive)), -int128(uint128(tokenReturns)));
}



function buyLowTokenExactOutput(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 cost = vixTokenData.circulation1.costOfPurchasingToken(amountInOutPositive, SLOPE, BASE_PRICE, FEE);
    vixTokenData.contractHoldings1 += amountInOutPositive;
    vixTokenData.circulation1 += amountInOutPositive;
    vixTokenData.reserve1 += cost;
    if(zeroIsBase){
        key.currency0.take(poolManager, address(this), cost, true);
        key.currency1.settle(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.take(poolManager, address(this), cost, true);
        key.currency0.settle(poolManager, address(this), amountInOutPositive, true);
    }
    return (-int128(uint128(amountInOutPositive)), int128(uint128(cost)));
}

    
function oneForZeroOperator(PoolKey calldata key,address _deriveAsset,IPoolManager.SwapParams calldata params,uint256 amountInOutPositive,bool zeroIsBase) public returns (int128, int128) {
    VixTokenData storage vixTokenData = vixTokens[_deriveAsset];
    address _currency0 = Currency.unwrap(key.currency0);
    address _currency1 = Currency.unwrap(key.currency1);
    bool isHighToken = (_currency0 == vixTokenData.vixHighToken || _currency1 == vixTokenData.vixHighToken);
    bool isExactIn = params.amountSpecified < 0;
    console.log("one for zero operator triggered");
    return isHighToken
        ? processHighToken_OneZero(key, vixTokenData, amountInOutPositive, zeroIsBase, isExactIn)
        : processLowToken_OneZero(key, vixTokenData, amountInOutPositive, zeroIsBase, isExactIn);
}

function processHighToken_OneZero(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase,bool isExactIn) private returns (int128, int128) {
    if (isExactIn) {
        return zeroIsBase
            ? sellHighTokenExactInput(key, vixTokenData, amountInOutPositive, zeroIsBase)
            : buyHighTokenExactInput(key, vixTokenData, amountInOutPositive, zeroIsBase);
    } else {
        return zeroIsBase
            ?  sellHighTokenExactOutput(key, vixTokenData, amountInOutPositive, zeroIsBase)
            : buyHighTokenExactOutput(key, vixTokenData, amountInOutPositive,zeroIsBase);
    }
}

function sellHighTokenExactInput(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 baseToken_returns = vixTokenData.circulation0.costOfSellingToken(amountInOutPositive, SLOPE, BASE_PRICE, FEE);
    vixTokenData.contractHoldings0 -= amountInOutPositive;
    vixTokenData.circulation0 -= amountInOutPositive;
    vixTokenData.reserve0 -= baseToken_returns;
    if(zeroIsBase){
        key.currency0.settle(poolManager, address(this),baseToken_returns, true);
        key.currency1.take(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.settle(poolManager, address(this),baseToken_returns, true);
        key.currency0.take(poolManager, address(this), amountInOutPositive, true);
    }
    return (int128(uint128(amountInOutPositive)), -int128(uint128(baseToken_returns)));
}

function sellHighTokenExactOutput(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {

   uint tokensToSell =  vixTokenData.circulation0.tokensForGivenCost(amountInOutPositive,SLOPE,FEE,BASE_PRICE) * 1e18;
   vixTokenData.circulation0 -= tokensToSell;
   vixTokenData.contractHoldings0 -= tokensToSell;
   vixTokenData.reserve0 -= amountInOutPositive;
   if(zeroIsBase){
        key.currency0.settle(poolManager,address(this),amountInOutPositive,true);
        key.currency1.take(poolManager,address(this),tokensToSell,true);
   }else{
        key.currency1.settle(poolManager,address(this),amountInOutPositive,true);
        key.currency0.take(poolManager,address(this),tokensToSell,true);
   }
   return  (-int128(uint128(amountInOutPositive)), int128(uint128(tokensToSell)));
}

function processLowToken_OneZero(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase,bool isExactIn) private returns (int128, int128) {
    if (isExactIn) {
        return zeroIsBase
            ?  sellLowTokenExactInput(key, vixTokenData, amountInOutPositive,zeroIsBase)
            : buyLowTokenExactInput(key, vixTokenData, amountInOutPositive,zeroIsBase);
    } else {
        return zeroIsBase
            ? sellLowTokenExactOutput(key, vixTokenData, amountInOutPositive,zeroIsBase)
            : buyLowTokenExactOutput(key, vixTokenData, amountInOutPositive,zeroIsBase);
    }
}

function sellLowTokenExactInput(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
    uint256 baseToken_returns = vixTokenData.circulation1.costOfSellingToken(amountInOutPositive, SLOPE, BASE_PRICE, FEE);
    vixTokenData.contractHoldings1 -= amountInOutPositive;
    vixTokenData.circulation1 -= amountInOutPositive;
    vixTokenData.reserve1 -= baseToken_returns;
    if(zeroIsBase){
        key.currency0.settle(poolManager, address(this),baseToken_returns, true);
        key.currency1.take(poolManager, address(this), amountInOutPositive, true);
    }else{
        key.currency1.settle(poolManager, address(this),baseToken_returns, true);
        key.currency0.take(poolManager, address(this), amountInOutPositive, true);
    }
    return (int128(uint128(amountInOutPositive)), -int128(uint128(baseToken_returns)));
}

function sellLowTokenExactOutput(PoolKey calldata key,VixTokenData storage vixTokenData,uint256 amountInOutPositive,bool zeroIsBase) private returns (int128, int128) {
   uint tokensToSell =  vixTokenData.circulation1.tokensForGivenCost(amountInOutPositive,SLOPE,FEE,BASE_PRICE) * 1e18;
   vixTokenData.circulation1 -= tokensToSell;
   vixTokenData.contractHoldings1 -= tokensToSell;
   vixTokenData.reserve1 -= amountInOutPositive;
    if(zeroIsBase){
        key.currency0.settle(poolManager,address(this),amountInOutPositive,true);
        key.currency1.take(poolManager,address(this),tokensToSell,true);
    }else{
        key.currency1.settle(poolManager,address(this),amountInOutPositive,true);
        key.currency0.take(poolManager,address(this),tokensToSell,true);
    }
   return  (-int128(uint128(amountInOutPositive)), int128(uint128(tokensToSell)));
}

/**
 * @dev Deploys two volatile ERC20 tokens for a given derived asset and initializes their liquidity.
 *      Ensures that an existing pair is either inactive or expired before deploying new tokens.
 *
 * @param deriveToken The address of the derived asset for which the volatile tokens are created.
 * @param _tokenName An array containing the names of the two volatile tokens.
 * @param _tokenSymbol An array containing the symbols of the two volatile tokens.
 * @param deadline The duration (in seconds) after which the token pair will expire.
 *
 * @return address[2] The addresses of the newly deployed volatile ERC20 tokens.
 */

function deploy2Currency(address deriveToken, string[2] memory _tokenName, string[2] memory _tokenSymbol,address _poolAddress,uint160 volume,uint deadline) public returns(address[2] memory){
    require((isPairInitiated[deriveToken] == false || pairEndingTime[deriveToken] < block.timestamp),"Pair still active");
    isPairInitiated[deriveToken] = true;
    pairInitiatedTime[deriveToken] = block.timestamp;
    pairEndingTime[deriveToken] = block.timestamp + deadline;
    address[2] memory vixTokenAddresses;
    for(uint i = 0; i < 2; i++){
            uint twentyFourHours = 3600 * 24;

            VolatileERC20 v_token = new VolatileERC20(_tokenName[i], _tokenSymbol[i],twentyFourHours);
            vixTokenAddresses[i] = address(v_token);
            mintVixToken(address(this),address(v_token),IV_TOKEN_SUPPLY);
    }

    uint160 initialIv = calculateIv(_poolAddress,volume);
    vixTokens[deriveToken] = VixTokenData(vixTokenAddresses[0],vixTokenAddresses[1],0,0,0,0,0,0,_poolAddress,initialIv);
    liquidateVixTokenToPm(IV_TOKEN_SUPPLY, vixTokenAddresses[0], vixTokenAddresses[1]);
    emit PairInitiated(deriveToken,vixTokenAddresses[0],vixTokenAddresses[1],block.timestamp,block.timestamp + deadline,initialIv);
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
               address(this)
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
	return "";
}

function mintVixToken(address to,address _token,uint _amount) internal returns (bool){
    VolatileERC20 v_token = VolatileERC20(_token);
    v_token.mint(to, _amount);
    return true;
}

/**
 * @dev Resets a token pair if the existing pair has expired. Deploys new currency tokens
 *      and assigns them to the provided deriveToken address.
 *
 * @param deriveToken The address of the token for which the pair is being reset.
 * @param deadline The new expiration deadline for the pair.
 *
 * @return address[2] memory Returns the addresses of the newly deployed currency tokens.
 */

function resetPair(address deriveToken,uint deadline,address _poolAddress,uint160 volume) public returns (address[2] memory) {
    require(isPairInitiated[deriveToken] == true,"Pair not initiated");
    if(pairEndingTime[deriveToken] < block.timestamp){

            address VHT = vixTokens[deriveToken].vixHighToken;
            address VLT = vixTokens[deriveToken].vixLowToken;
            VolatileERC20 VHTContract = VolatileERC20(VHT);
            VolatileERC20 VLTContract = VolatileERC20(VLT);

            (address[2] memory vixAdd)  = deploy2Currency(deriveToken,[VHTContract.name(),VLTContract.name()],[VHTContract.symbol(),VLTContract.symbol()],_poolAddress,volume ,deadline);
            emit PairExpired(deriveToken,VHT,VLT,vixTokens[deriveToken].initialIv,block.timestamp);
            return vixAdd;
    }else{
            revert("Pair not expired");
    }
}

function getVixData(address deriveAsset)public view returns (address vixHighToken,address _vixLowToken,uint _circulation0,uint _circulation1,uint _contractHoldings0,uint _contractHoldings1,uint _reserve0,uint _reserve1,address _poolAddress){
     VixTokenData memory vixTokenData = vixTokens[deriveAsset];
     return (vixTokenData.vixHighToken,vixTokenData.vixLowToken,vixTokenData.circulation0,vixTokenData.circulation1,vixTokenData.contractHoldings0,vixTokenData.contractHoldings1,vixTokenData.reserve0,vixTokenData.reserve1,vixTokenData.poolAddress);
}

/**
 * @dev it will calculate the implied volatility of the pair
 *
 * @param _poolAddress poolAddress of the pair from uniswap v3.
 * @param volume volume of the pool in ETH from uniswap v3.
 * @return _iv it will return the iv.
 */

function calculateIv(address _poolAddress,uint160 volume) public view returns (uint160 _iv){
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
    (uint liq,uint160 scaleFactor) = liquidity.tickLiquidity(tick,tickSpacing,false);
    uint160 scaledDownFee = uint160(fee/1000);
    uint160 iv =  volume.ivCalculation(uint160(liq),scaleFactor,scaledDownFee);
    console.log("iv: ",iv);
    return iv;
}


function swapReserve(uint initialIv, uint currentIv, uint reserve0, uint reserve1,uint circulation0,uint circulation1,address deriveAsset) public  returns(uint,uint){
    if(initialIv > currentIv && reserve0 > 1 ether){
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


        vixTokens[deriveAsset].reserve0 -= reserveShift;
        vixTokens[deriveAsset].reserve1 += reserveShift;
        vixTokens[deriveAsset].contractHoldings0 -= tokenBurn;
        vixTokens[deriveAsset].contractHoldings1 += tokenMint;
        return (reserveShift,tokenBurn);


    }else if(initialIv < currentIv && reserve1 >  1 ether){
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
        vixTokens[deriveAsset].reserve0 += reserveShift;
        vixTokens[deriveAsset].reserve1 -= reserveShift;
        vixTokens[deriveAsset].contractHoldings1 -= tokenBurn;
        vixTokens[deriveAsset].contractHoldings0 += tokenMint;
        return (reserveShift,tokenMint);
    }else{
        return (0,0);
    }
     
}

function vixTokensPrice(uint contractHoldings) public pure returns(uint){
    uint price = ((SLOPE * contractHoldings) / 1e18) + BASE_PRICE;
    return (price); // we should do price/1e18 for readable price
    
}


}

