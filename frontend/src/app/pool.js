import { ethers } from 'ethers';

// Setup provider and signer
const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
const wallet = new ethers.Wallet(
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
  provider
);

// Uniswap V3 contract addresses
const FACTORY_ADDRESS = '0x1F98431c8aD98523631AE4a59f267346ea31F984';
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

// Your token addresses
const VIX_HIGH_TOKEN = '0x84200F6630cd483F10c998643Fe2bd6d96B071c3';
const VIX_LOW_TOKEN = '0xDCaAbDcc97Fe195229B9ecAD7140c5C189e4066b';

// ABIs
const FACTORY_ABI = [
  'function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool)',
  'function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool)',
];
const POOL_ABI = ['function initialize(uint160 sqrtPriceX96) external'];

// Contract instances
const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, wallet);

// Fee tier (0.3% = 3000)
const FEE = 3000;

// Function to create and initialize a pool
async function createAndInitializePool(tokenA, tokenB, initialPrice) {
  try {
    console.log(`\nChecking pool for tokens: ${tokenA} & ${tokenB}`);

    const [token0, token1] =
      tokenA < tokenB ? [tokenA, tokenB] : [tokenB, tokenA];
    console.log(`Sorted tokens: token0 = ${token0}, token1 = ${token1}`);

    let poolAddress = await factory.getPool(token0, token1, FEE);
    console.log(`Existing pool address: ${poolAddress}`);

    if (poolAddress === ethers.ZeroAddress) {
      console.log('Pool does not exist, creating pool...');
      const tx = await factory.createPool(token0, token1, FEE);
      console.log('Pool creation transaction sent:', tx.hash);
      const receipt = await tx.wait();

      if (
        receipt.events &&
        receipt.events.length > 0 &&
        receipt.events[0].args
      ) {
        poolAddress = receipt.events[0].args.pool;
        console.log(`Pool created at: ${poolAddress}`);
      } else {
        throw new Error(
          'Pool creation event not found. Check transaction logs.'
        );
      }

      // Initialize pool with initial price (sqrtPriceX96)
      const pool = new ethers.Contract(poolAddress, POOL_ABI, wallet);
      const sqrtPriceX96 = ethers.BigNumber.from(
        Math.sqrt(initialPrice) * 2 ** 96
      ).toString();
      console.log(`Initializing pool with sqrtPriceX96: ${sqrtPriceX96}`);
      await pool.initialize(sqrtPriceX96);
      console.log('Pool initialized');
    } else {
      console.log(`Pool already exists at: ${poolAddress}`);
    }

    return poolAddress;
  } catch (error) {
    console.error('Error in createAndInitializePool:', error);
    throw error;
  }
}

// Main execution
async function main() {
  try {
    console.log('Starting pool initialization...');

    const vixHighInitialPrice = 0.01;
    const vixLowInitialPrice = 0.005;

    // Create and initialize VixHigh/WETH pool
    const poolVixHigh = await createAndInitializePool(
      VIX_HIGH_TOKEN,
      WETH_ADDRESS,
      vixHighInitialPrice
    );
    console.log(`VixHigh/WETH Pool Address: ${poolVixHigh}`);

    // Create and initialize VixLow/WETH pool
    const poolVixLow = await createAndInitializePool(
      VIX_LOW_TOKEN,
      WETH_ADDRESS,
      vixLowInitialPrice
    );
    console.log(`VixLow/WETH Pool Address: ${poolVixLow}`);

    console.log('Pool initialization completed successfully.');
  } catch (error) {
    console.error('Error in main execution:', error);
  }
}

main().catch(console.error);
