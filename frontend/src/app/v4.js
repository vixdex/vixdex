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
const VIX_HIGH_TOKEN = '0x84200F6630cd483F10c998643Fe2bd6d96B071c3';
const VIX_LOW_TOKEN = '0xDCaAbDcc97Fe195229B9ecAD7140c5C189e4066b';
const ETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const POOL_MANAGER_ADDRESS = '0x000000000004444c5dc75cB358380D2e3dE08A90'; // Verify this!
const FEE = 3000; // 0.3%
const TICK_SPACING = 60;
const HOOKS = '0x97d267B69dE5BC1f78d3894aF0fbc71e1aDc4Cc8';
const SQRT_PRICE_X96 = BigInt('792281625142643375935439503360');
// 1 ETH = 100 VIX

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

    console.log('poolkey', poolKey);
    console.log('⏳ Estimating gas for transaction...');
    const estimatedGas = await poolManager.initialize.estimateGas(
      poolKey,
      SQRT_PRICE_X96
    );

    console.log(`📏 Estimated Gas: ${estimatedGas.toString()}`);
    console.log('🚀 Sending transaction...');
    const tx = await poolManager.initialize(poolKey, SQRT_PRICE_X96, {
      gasLimit: estimatedGas * 2n,
    });

    console.log(`🔄 Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`✅ Transaction confirmed! Hash: ${receipt.transactionHash}`);
    console.log(`📜 Pool ${poolName} initialized successfully!\n`);
  } catch (error) {
    console.error('❌ Transaction failed:', error);
    if (error.data) {
      console.log('🔍 Revert data:', error.data);
      if (error.data === '0x7983c051') {
        console.log('⚠️ Pool already initialized');
      } else if (error.data.startsWith('0x6e6c9830')) {
        console.log('⚠️ Invalid pool parameters or token addresses');
      }
    }
  }
}

async function main() {
  try {
    console.log('\n🔄 Starting Pool Initialization Process...\n');
    const network = await provider.getNetwork();
    console.log(
      `🌐 Connected to network: ${network.name} (chainId: ${network.chainId})`
    );

    // Verify wallet balance
    const balance = await provider.getBalance(wallet.address);
    console.log(`💰 Wallet balance: ${ethers.formatEther(balance)} ETH`);

    await initializePool(VIX_HIGH_TOKEN);
    await initializePool(VIX_LOW_TOKEN);

    console.log('\n✅ All pools processed successfully!\n');
  } catch (error) {
    console.error('❌ Error initializing pools:', error);
  }
}

main();
