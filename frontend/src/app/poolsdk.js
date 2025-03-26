import { ethers } from 'ethers';
import { Pool, Position, nearestUsableTick } from '@uniswap/v3-sdk';
import { Token, CurrencyAmount } from '@uniswap/sdk-core'; // Explicitly import Token

// Verify ethers is loaded correctly
if (!ethers || !ethers.constants) {
  throw new Error(
    'ethers.js is not properly imported. Please check your installation.'
  );
}
console.log('ethers.constants.AddressZero:', ethers.constants.AddressZero);

// Setup provider and signer
const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
const wallet = new ethers.Wallet(
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
  provider
);

// Uniswap V3 contract addresses (mainnet)
const FACTORY_ADDRESS = '0x1F98431c8aD98523631AE4a59f267346ea31F984';
const POSITION_MANAGER_ADDRESS = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88';
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

// Your token addresses
const VIX_HIGH_TOKEN = '0x84200F6630cd483F10c998643Fe2bd6d96B071c3';
const VIX_LOW_TOKEN = '0xDCaAbDcc97Fe195229B9ecAD7140c5C189e4066b';

// ABIs
const FACTORY_ABI = [
  'function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool)',
  'function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool)',
];
const POOL_ABI = [
  'function initialize(uint160 sqrtPriceX96) external',
  'function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked)',
];
const POSITION_MANAGER_ABI = [
  'function mint((address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline)) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)',
];

// Contract instances
const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, wallet);
const positionManager = new ethers.Contract(
  POSITION_MANAGER_ADDRESS,
  POSITION_MANAGER_ABI,
  wallet
);

// Fee tier (0.3% = 3000)
const FEE = 3000;
const TICK_SPACING = 60; // Tick spacing for 0.3% fee tier

// Define tokens (assuming 18 decimals for simplicity; adjust if different)
const chainId = 1; // Mainnet
const WETH = new Token(chainId, WETH_ADDRESS, 18, 'WETH', 'Wrapped Ether');
const VIX_HIGH = new Token(chainId, VIX_HIGH_TOKEN, 18, 'VIXH', 'Vix High');
const VIX_LOW = new Token(chainId, VIX_LOW_TOKEN, 18, 'VIXL', 'Vix Low');

// Function to create and initialize a pool
async function createAndInitializePool(tokenA, tokenB, initialPrice) {
  const [token0, token1] =
    tokenA.address < tokenB.address ? [tokenA, tokenB] : [tokenB, tokenA];

  // Check if pool exists
  let poolAddress = await factory.getPool(token0.address, token1.address, FEE);
  if (poolAddress === ethers.constants.AddressZero) {
    // Create pool
    const tx = await factory.createPool(token0.address, token1.address, FEE);
    const receipt = await tx.wait();
    poolAddress = receipt.events[0].args.pool;
    console.log(`Pool created at: ${poolAddress}`);

    // Initialize pool with initial price
    const poolContract = new ethers.Contract(poolAddress, POOL_ABI, wallet);
    const sqrtPriceX96 = Pool.getSqrtRatioAtTick(
      Math.round(Math.log(initialPrice) / Math.log(1.0001)) // Convert price to tick
    );
    await poolContract.initialize(sqrtPriceX96);
    console.log('Pool initialized');
  } else {
    console.log(`Pool already exists at: ${poolAddress}`);
  }
  return poolAddress;
}

// Function to add liquidity
async function addLiquidity(tokenA, tokenB, amountADesired, amountBDesired) {
  const [token0, token1] =
    tokenA.address < tokenB.address ? [tokenA, tokenB] : [tokenB, tokenA];
  const amount0Desired = token0.equals(tokenA)
    ? amountADesired
    : amountBDesired;
  const amount1Desired = token1.equals(tokenB)
    ? amountBDesired
    : amountADesired;

  // Get pool address
  const poolAddress = await factory.getPool(
    token0.address,
    token1.address,
    FEE
  );
  const poolContract = new ethers.Contract(poolAddress, POOL_ABI, wallet);
  const slot0 = await poolContract.slot0();

  // Create pool instance
  const pool = new Pool(
    token0,
    token1,
    FEE,
    slot0.sqrtPriceX96.toString(),
    0, // Liquidity (will be updated after adding)
    slot0.tick
  );

  // Define position (e.g., ±500 ticks around current price)
  const tickLower = nearestUsableTick(slot0.tick - 500, TICK_SPACING);
  const tickUpper = nearestUsableTick(slot0.tick + 500, TICK_SPACING);

  // Create position
  const position = new Position({
    pool,
    liquidity: ethers.utils.parseEther('1').toString(), // Initial liquidity (adjust as needed)
    tickLower,
    tickUpper,
  });

  // Calculate amounts based on desired inputs
  const amount0 = CurrencyAmount.fromRawAmount(
    token0,
    ethers.utils.parseEther(amount0Desired.toString())
  );
  const amount1 = CurrencyAmount.fromRawAmount(
    token1,
    ethers.utils.parseEther(amount1Desired.toString())
  );

  // Mint position
  const params = {
    token0: token0.address,
    token1: token1.address,
    fee: FEE,
    tickLower,
    tickUpper,
    amount0Desired: amount0.quotient.toString(),
    amount1Desired: amount1.quotient.toString(),
    amount0Min: 0,
    amount1Min: 0,
    recipient: wallet.address,
    deadline: Math.floor(Date.now() / 1000) + 60 * 20,
  };

  const tx = await positionManager.mint(params, {
    value: ethers.utils.parseEther('1'),
  }); // Include ETH for WETH
  const receipt = await tx.wait();
  console.log(`Liquidity added, tokenId: ${receipt.events[0].args.tokenId}`);
}

// Main execution
async function main() {
  // Initial prices (e.g., 1 VixHigh = 0.01 ETH, 1 VixLow = 0.005 ETH)
  const vixHighInitialPrice = 0.01;
  const vixLowInitialPrice = 0.005;

  // Create and initialize VixHigh/WETH pool
  await createAndInitializePool(VIX_HIGH, WETH, vixHighInitialPrice);
  // Add liquidity (e.g., 100 VixHigh and 1 ETH)
  await addLiquidity(VIX_HIGH, WETH, 100, 1);

  // Create and initialize VixLow/WETH pool
  await createAndInitializePool(VIX_LOW, WETH, vixLowInitialPrice);
  // Add liquidity (e.g., 200 VixLow and 1 ETH)
  await addLiquidity(VIX_LOW, WETH, 200, 1);
}

main().catch(console.error);
