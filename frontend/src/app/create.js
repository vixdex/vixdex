const { ethers } = require('ethers');

async function deployCurrency() {
  // ABI including both functions

  const abi = [
    'function deploy2Currency(address deriveToken, string[2] memory _tokenName, string[2] memory _tokenSymbol, address _poolAddress, uint160 volume, uint deadline) returns(address[2] memory)',

    'function getVixData(address deriveAsset) public view returns (address vixHighToken, address _vixLowToken, uint _circulation0, uint _circulation1, uint _contractHoldings0, uint _contractHoldings1, uint _reserve0, uint _reserve1, address _poolAddress)',
  ];

  const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545'); // Ensure your local node is running

  const privateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // Replace with a funded private key

  const signer = new ethers.Wallet(privateKey, provider);

  const contractAddress = '0x16978904Dad6fD20093D0454Ab4420B3adcFcCc8';

  const contract = new ethers.Contract(contractAddress, abi, signer);

  const deriveToken = '0x514910771AF9Ca656af840dff83E8264EcF986CA'; // WBTC

  const tokenNames = ['TokenA', 'TokenB'];

  const tokenSymbols = ['TKA', 'TKB'];

  const poolAddress = '0xa6Cc3C2531FdaA6Ae1A3CA84c2855806728693e8';

  const volume = ethers.parseEther('722'); // Assuming correct format

  const block = await provider.getBlock('latest');

  const currentTimestamp = block.timestamp;

  const deadline = currentTimestamp + 3600 * 24; // 24 hours

  try {
    const code = await provider.getCode(contractAddress);

    if (code === '0x') {
      throw new Error('No contract deployed at the given address.');
    }

    // Step 1: Deploy the currency pair

    console.log('Deploying currency pair...');

    const tx = await contract.deploy2Currency(
      deriveToken,

      tokenNames,

      tokenSymbols,

      poolAddress,

      volume,

      deadline,

      { gasLimit: 5000000 }
    );

    console.log('Transaction hash:', tx.hash);

    await tx.wait();

    console.log('Deployment confirmed!');

    // Step 2: Fetch VIX Data using getVixData

    console.log('Fetching VIX Data...');

    const result = await contract.getVixData(deriveToken);

    // Destructure the returned values

    const [
      vixHighToken,

      vixLowToken,

      circulation0,

      circulation1,

      contractHoldings0,

      contractHoldings1,

      reserve0,

      reserve1,

      fetchedPoolAddress,
    ] = result;

    const vixData = {
      vixHighToken,

      vixLowToken,

      circulation0: circulation0.toString(),

      circulation1: circulation1.toString(),

      contractHoldings0: contractHoldings0.toString(),

      contractHoldings1: contractHoldings1.toString(),

      reserve0: reserve0.toString(),

      reserve1: reserve1.toString(),

      poolAddress: fetchedPoolAddress,
    };

    return vixData;
  } catch (error) {
    console.error('Error:', error);
  }
}

deployCurrency()
  .then((data) => console.log('Returned Vix Data:', data))

  .catch((err) => console.error('Deployment failed:', err));
