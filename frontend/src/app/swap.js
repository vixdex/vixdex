const { ethers } = require('ethers');

// Universal Router ABI
const UNIVERSAL_ROUTER_ABI = [
  {
    inputs: [
      { name: 'recipient', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'amountOutMin', type: 'uint256' },
      { name: 'path', type: 'bytes' },
      { name: 'deadline', type: 'uint256' },
    ],
    name: 'swapExactETHForTokens',
    outputs: [{ name: 'amounts', type: 'uint256[]' }],
    stateMutability: 'payable',
    type: 'function',
  },
];

// Constants
const UNIVERSAL_ROUTER_ADDRESS = '0x66a9893cc07d91d95644aedd05d03f95e1dba8af'; // Update with actual router address
const VIX_HIGH_TOKEN = '0x037010d7F84447D9f7D666481a9fd1961d7144D9';
const ETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const SWAP_AMOUNT_ETH = ethers.parseEther('10'); // 10 ETH
const DEADLINE = Math.floor(Date.now() / 1000) + 60 * 10; // 10 min deadline

// Provider & Wallet
const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
const wallet = new ethers.Wallet(
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
  provider
);

// Universal Router Contract
const router = new ethers.Contract(
  UNIVERSAL_ROUTER_ADDRESS,
  UNIVERSAL_ROUTER_ABI,
  wallet
);

async function swapEthForVix() {
  try {
    console.log('🔄 Initiating ETH → VIX Token Swap...');

    const balance = await provider.getBalance(wallet.address);
    console.log(`💰 Wallet ETH balance: ${ethers.formatEther(balance)} ETH`);

    if (balance < SWAP_AMOUNT_ETH) {
      console.error('❌ Insufficient ETH balance!');
      return;
    }

    const path = ethers.solidityPacked(
      ['address', 'address'],
      [ETH_ADDRESS, VIX_HIGH_TOKEN]
    );

    console.log('📏 Estimating gas...');
    const estimatedGas = await router.swapExactETHForTokens.estimateGas(
      wallet.address,
      SWAP_AMOUNT_ETH,
      0, // amountOutMin (set to 0 for now, use slippage control in production)
      path,
      DEADLINE,
      { value: SWAP_AMOUNT_ETH }
    );

    console.log(`📊 Estimated Gas: ${estimatedGas.toString()}`);

    console.log('🚀 Sending Swap Transaction...');
    const tx = await router.swapExactETHForTokens(
      wallet.address,
      SWAP_AMOUNT_ETH,
      0,
      path,
      DEADLINE,
      { value: SWAP_AMOUNT_ETH, gasLimit: estimatedGas * 2n }
    );

    console.log(`🔄 Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`✅ Swap Successful! Hash: ${receipt.transactionHash}`);
  } catch (error) {
    console.error('❌ Swap Failed:', error);
  }
}

swapEthForVix();
