const { ethers } = require('ethers');

// PoolManager ABI
const POOL_MANAGER_ABI = [
  {
    inputs: [
      {
        components: [
          { name: 'currency0', type: 'address' },
          { name: 'currency1', type: 'address' },
          { name: 'fee', type: 'uint24' },
          { name: 'tickSpacing', type: 'int24' },
          { name: 'hooks', type: 'address' },
        ],
        name: 'key',
        type: 'tuple',
      },
      { name: 'sqrtPriceX96', type: 'uint160' },
    ],
    name: 'initialize',
    outputs: [{ name: 'tick', type: 'int24' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
];

// Constants
const ETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const POOL_MANAGER_ADDRESS = '0x000000000004444c5dc75cB358380D2e3dE08A90'; // Verify this!
const FEE = 3000; // 0.3%
const TICK_SPACING = 60;
const HOOKS = '0x16978904Dad6fD20093D0454Ab4420B3adcFcCc8';
const SQRT_PRICE_X96 = BigInt('792281625142643375935439503360');

// Provider and Wallet
const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
const wallet = new ethers.Wallet(
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
  provider
);

// PoolManager Contract
const poolManager = new ethers.Contract(
  POOL_MANAGER_ADDRESS,
  POOL_MANAGER_ABI,
  wallet
);

async function initializePool(tokenAddress) {
  try {
    console.log(`🔹 Initializing pool for ${tokenAddress} / ETH...`);
    const poolName = `ETH / ${tokenAddress.substring(0, 6)}...`;

    // Ensure correct token order
    const currency0 = ETH_ADDRESS < tokenAddress ? ETH_ADDRESS : tokenAddress;
    const currency1 = ETH_ADDRESS < tokenAddress ? tokenAddress : ETH_ADDRESS;

    const poolKey = {
      currency0,
      currency1,
      fee: FEE,
      tickSpacing: TICK_SPACING,
      hooks: HOOKS,
    };

    const estimatedGas = await poolManager.initialize.estimateGas(
      poolKey,
      SQRT_PRICE_X96
    );

    const tx = await poolManager.initialize(poolKey, SQRT_PRICE_X96, {
      gasLimit: estimatedGas * 2n,
    });

    const receipt = await tx.wait();
    console.log(`✅ Pool ${poolName} initialized: ${receipt.transactionHash}`);
    return { success: true, txHash: receipt.transactionHash };
  } catch (error) {
    console.error('❌ Pool initialization failed:', error);
    throw error;
  }
}

module.exports = { initializePool };
