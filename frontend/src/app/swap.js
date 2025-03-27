const { ethers } = require('ethers');

// Type definitions
class PoolKey {
  constructor(currency0, currency1, fee, tickSpacing, hooks) {
    this.currency0 = currency0;
    this.currency1 = currency1;
    this.fee = fee;
    this.tickSpacing = tickSpacing;
    this.hooks = hooks;
  }
}

class SwapExactInSingle {
  constructor(poolKey, zeroForOne, amountIn, amountOutMinimum, hookData) {
    this.poolKey = poolKey;
    this.zeroForOne = zeroForOne;
    this.amountIn = amountIn;
    this.amountOutMinimum = amountOutMinimum;
    this.hookData = hookData;
  }
}

// Constants
const VIX_HIGH_TOKEN = '0x037010d7F84447D9f7D666481a9fd1961d7144D9';
const ETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const POOL_MANAGER_ADDRESS = '0x000000000004444c5dc75cB358380D2e3dE08A90';
const HOOKS = '0x16978904Dad6fD20093D0454Ab4420B3adcFcCc8';

// Setup provider and wallet
const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
const wallet = new ethers.Wallet(
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
  provider
);

// ABI definitions
const poolManagerAbi = [
  'function swap(tuple(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks) key, tuple(bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96) params, bytes hookData) external returns (tuple(int256 amount0, int256 amount1) swapDelta)',
  'function settle() external payable returns (uint256)',
  'function initialize(tuple(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks) key, uint160 sqrtPriceX96) external returns (int24 tick)',
  'event Initialize(bytes32 indexed id, address indexed currency0, address indexed currency1, uint24 fee, int24 tickSpacing, address hooks, uint160 sqrtPriceX96, int24 tick)',
];

// Contract instance
const poolManager = new ethers.Contract(
  POOL_MANAGER_ADDRESS,
  poolManagerAbi,
  wallet
);

// Check if pool is initialized
async function isPoolInitialized(poolKey) {
  const poolId = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'address', 'uint24', 'int24', 'address'],
      [
        poolKey.currency0,
        poolKey.currency1,
        poolKey.fee,
        poolKey.tickSpacing,
        poolKey.hooks,
      ]
    )
  );
  // You could query the contract state, but for simplicity, we'll attempt initialization and catch if already initialized
  return poolId;
}

// Swap function
async function executeExactInSwap() {
  try {
    // Define pool key
    const poolKey = new PoolKey(ETH_ADDRESS, VIX_HIGH_TOKEN, 3000, 60, HOOKS);

    // Check wallet balance
    const balance = await provider.getBalance(wallet.address);
    console.log('Wallet ETH balance:', ethers.formatEther(balance));
    if (balance < ethers.parseEther('10')) {
      throw new Error('Insufficient ETH balance');
    }

    // Initialize pool if needed (example sqrtPriceX96 for 1:1 ratio)
    try {
      const sqrtPriceX96 = '79228162514264337593543950336'; // 1:1 price (adjust as needed)
      const initTx = await poolManager.initialize(
        {
          currency0: poolKey.currency0,
          currency1: poolKey.currency1,
          fee: poolKey.fee,
          tickSpacing: poolKey.tickSpacing,
          hooks: poolKey.hooks,
        },
        sqrtPriceX96,
        { gasLimit: 200000 }
      );
      await initTx.wait();
      console.log('Pool initialized');
    } catch (error) {
      console.log(
        'Pool already initialized or initialization failed:',
        error.message
      );
    }

    // Swap parameters
    const amountIn = ethers.parseEther('10');
    // Simplify hookData to just caller address for testing
    const hookData = ethers.AbiCoder.defaultAbiCoder().encode(
      ['address'],
      [wallet.address]
    );

    const swapParams = new SwapExactInSingle(
      poolKey,
      true,
      amountIn,
      '0',
      hookData
    );

    const poolKeyStruct = {
      currency0: swapParams.poolKey.currency0,
      currency1: swapParams.poolKey.currency1,
      fee: swapParams.poolKey.fee,
      tickSpacing: swapParams.poolKey.tickSpacing,
      hooks: swapParams.poolKey.hooks,
    };

    const swapStruct = {
      zeroForOne: swapParams.zeroForOne,
      amountSpecified: swapParams.amountIn,
      sqrtPriceLimitX96: 0,
    };

    // Estimate gas
    const gasEstimate = await poolManager.swap.estimateGas(
      poolKeyStruct,
      swapStruct,
      swapParams.hookData,
      { value: amountIn }
    );
    console.log('Gas estimate:', gasEstimate.toString());

    // Execute swap
    const swapTx = await poolManager.swap(
      poolKeyStruct,
      swapStruct,
      swapParams.hookData,
      {
        value: amountIn,
        gasLimit: (gasEstimate * 120n) / 100n,
      }
    );

    console.log('Swap transaction hash:', swapTx.hash);
    const swapReceipt = await swapTx.wait();
    console.log('Swap confirmed in block:', swapReceipt.blockNumber);

    // Settle payment
    const settleTx = await poolManager.settle({
      value: amountIn,
      gasLimit: 100000,
    });
    await settleTx.wait();

    // Parse swap result
    const swapEvent = swapReceipt.logs.find(
      (log) =>
        log.topics[0] ===
        ethers.id(
          'Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)'
        )
    );
    if (swapEvent) {
      const decoded = ethers.AbiCoder.defaultAbiCoder().decode(
        ['int128', 'int128', 'uint160', 'uint128', 'int24', 'uint24'],
        swapEvent.data
      );
      const amountOut = decoded[1].abs();
      console.log('VIX received:', ethers.formatEther(amountOut));
      return amountOut;
    }
  } catch (error) {
    console.error('Swap failed:', error);
    throw error;
  }
}

// Execute the swap
executeExactInSwap()
  .then((amountOut) =>
    console.log(
      'Swap completed successfully, received:',
      ethers.formatEther(amountOut)
    )
  )
  .catch((err) => console.error('Swap execution failed:', err));
