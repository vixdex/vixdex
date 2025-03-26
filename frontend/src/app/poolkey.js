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

const POOL_MANAGER_ADDRESS = '0x000000000004444c5dc75cB358380D2e3dE08A90'; // Verify this!

// Provider and Wallet
const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
const wallet = new ethers.Wallet(
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
  provider
);

const poolManager = new ethers.Contract(
  POOL_MANAGER_ADDRESS,
  POOL_MANAGER_ABI,
  wallet
);

const poolkey = {
  currency0: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  currency1: '0xDCaAbDcc97Fe195229B9ecAD7140c5C189e4066b',
  fee: 3000,
  tickSpacing: 60,
  hooks: '0x97d267B69dE5BC1f78d3894aF0fbc71e1aDc4Cc8',
};

async function checkPoolExists() {
  try {
    const poolData = await poolManager.getPool(poolkey);
    console.log(`Pool found:`, poolData);
  } catch (error) {
    console.log('Pool not initialized or does not exist.');
  }
}

checkPoolExists();
