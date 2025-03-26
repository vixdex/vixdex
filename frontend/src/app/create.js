const { ethers } = require('ethers');

async function deployCurrency() {
  // ABI including both functions and the event
  const abi = [
    'function deploy2Currency(address deriveToken, string[2] memory _tokenName, string[2] memory _tokenSymbol, address _poolAddress, uint160 volume, uint deadline) returns(address[2] memory)',
    'function getVixData(address deriveAsset) public view returns (address vixHighToken, address _vixLowToken, uint _circulation0, uint _circulation1, uint _contractHoldings0, uint _contractHoldings1, uint _reserve0, uint _reserve1, address _poolAddress)',
    'event PairInitiated(address indexed deriveToken, address vixToken1, address vixToken2, uint256 initiatedTime, uint256 endingTime, uint160 initialIv)',
  ];

  const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
  const signer = await provider.getSigner(0);

  const contractAddress = '0x97d267B69dE5BC1f78d3894aF0fbc71e1aDc4Cc8';
  const contract = new ethers.Contract(contractAddress, abi, signer);

  const deriveToken = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599'; // WBTC
  const tokenNames = ['TokenA', 'TokenB'];
  const tokenSymbols = ['TKA', 'TKB'];
  const poolAddress = '0xCBCdF9626bC03E24f779434178A73a0B4bad62eD';
  const volume = ethers.parseEther('722'); // 722 ETH as uint160 (assuming compatible scale)
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

    const receipt = await tx.wait();
    console.log('Transaction confirmed in block:', receipt.blockNumber);

    // Step 2: Parse the PairInitiated event to get initial addresses
    const event = receipt.logs
      .map((log) => {
        try {
          return contract.interface.parseLog(log);
        } catch (e) {
          return null;
        }
      })
      .find((parsedLog) => parsedLog && parsedLog.name === 'PairInitiated');

    let vixTokenAddresses;
    if (event) {
      vixTokenAddresses = [event.args.vixToken1, event.args.vixToken2];
      console.log('Deployed addresses from event:', vixTokenAddresses);
    } else {
      throw new Error('PairInitiated event not found in transaction logs.');
    }

    // Step 3: Call getVixData to retrieve all values
    const vixData = await contract.getVixData(deriveToken);
    const [
      vixHighToken,
      vixLowToken,
      circulation0,
      circulation1,
      contractHoldings0,
      contractHoldings1,
      reserve0,
      reserve1,
      returnedPoolAddress,
    ] = vixData;

    console.log('Vix Data:', {
      vixHighToken,
      vixLowToken,
      circulation0: circulation0.toString(),
      circulation1: circulation1.toString(),
      contractHoldings0: contractHoldings0.toString(),
      contractHoldings1: contractHoldings1.toString(),
      reserve0: reserve0.toString(),
      reserve1: reserve1.toString(),
      poolAddress: returnedPoolAddress,
    });

    // Return the full data, including the two addresses
    return {
      vixHighToken,
      vixLowToken,
      circulation0,
      circulation1,
      contractHoldings0,
      contractHoldings1,
      reserve0,
      reserve1,
      poolAddress: returnedPoolAddress,
    };
  } catch (error) {
    console.error(
      'Error deploying currency or fetching vix data:',
      error.message
    );
    if (error.reason) console.error('Revert reason:', error.reason);
    throw error;
  }
}

deployCurrency()
  .then((data) => console.log('Returned Vix Data:', data))
  .catch((err) => console.error('Deployment failed:', err));
