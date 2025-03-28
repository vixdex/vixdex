const { ethers } = require('ethers');
const axios = require('axios');
require('dotenv').config();

const UNISWAP_V3_SUBGRAPH_URL = process.env.NEXT_PUBLIC_GRAPH_API;
const WETH_ADDRESS = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
console.log(UNISWAP_V3_SUBGRAPH_URL);

async function fetchEthPrice(poolAddress) {
  const formattedPoolAddress = poolAddress.toLowerCase();
  const query = `
    query GetEthPrice($poolAddress: String!) {
      pools(where: { id: $poolAddress }) {
        id
        token0 { symbol id }
        token1 { symbol id }
        token0Price
        token1Price
      }
    }
  `;
  const variables = { poolAddress: formattedPoolAddress };

  try {
    const response = await axios.post(
      UNISWAP_V3_SUBGRAPH_URL,
      { query, variables },
      { headers: { 'Content-Type': 'application/json' } }
    );
    const poolData = response.data.data.pools[0];
    if (!poolData)
      throw new Error(`No data found for pool: ${formattedPoolAddress}`);

    let ethPrice;
    if (poolData.token0.id.toLowerCase() === WETH_ADDRESS) {
      ethPrice = parseFloat(poolData.token1Price);
    } else if (poolData.token1.id.toLowerCase() === WETH_ADDRESS) {
      ethPrice = parseFloat(poolData.token0Price);
    } else {
      throw new Error(`Pool ${formattedPoolAddress} does not contain WETH`);
    }
    return ethPrice;
  } catch (error) {
    console.error('Error fetching ETH price:', error.message);
    return null;
  }
}

async function fetchPoolVolume(poolAddress, ethPricePoolAddress) {
  if (!poolAddress || typeof poolAddress !== 'string') {
    throw new Error('poolAddress is undefined or not a string');
  }

  const formattedPoolAddress = poolAddress.toLowerCase(); // Re-add this for consistency
  const query = `
      {
        poolDayDatas(first: 1, orderBy: date, orderDirection: desc, where: { pool: "${formattedPoolAddress}" }) {
          date
          volumeUSD
        }
      }
    `;

  try {
    const ethPrice = await fetchEthPrice(ethPricePoolAddress);
    if (!ethPrice) throw new Error('Failed to fetch ETH price');

    const response = await axios.post(
      UNISWAP_V3_SUBGRAPH_URL,
      { query },
      { headers: { 'Content-Type': 'application/json' } }
    );
    const poolData = response.data.data.poolDayDatas[0];
    if (!poolData)
      throw new Error(`No data found for pool: ${formattedPoolAddress}`);

    const volumeUSD = parseFloat(poolData.volumeUSD);
    const volumeETH = volumeUSD / ethPrice;
    return ethers.parseEther(volumeETH.toString());
  } catch (error) {
    console.error('Error fetching pool volume:', error.message);
    throw error;
  }
}

async function deployCurrency(deriveToken, poolAddress) {
  const abi = [
    'function deploy2Currency(address deriveToken, string[2] memory _tokenName, string[2] memory _tokenSymbol, address _poolAddress, uint160 volume, uint deadline) returns(address[2] memory)',
    'function getVixData(address deriveAsset) public view returns (address vixHighToken, address _vixLowToken, uint _circulation0, uint _circulation1, uint _contractHoldings0, uint _contractHoldings1, uint _reserve0, uint _reserve1, address _poolAddress)',
  ];

  const provider = new ethers.JsonRpcProvider(process.env.NEXT_PUBLIC_RPC_URL);
  const privateKey = process.env.NEXT_PUBLIC_PRIVATE_KEY;

  const signer = new ethers.Wallet(privateKey, provider);
  const contractAddress = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS;
  const contract = new ethers.Contract(contractAddress, abi, signer);

  const tokenNames = ['TokenA', 'TokenB'];
  const tokenSymbols = ['TKA', 'TKB'];
  const ethPricePool = '0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8'; // USDC-WETH pool for ETH price

  try {
    // Fetch pool volume in ETH
    console.log('Fetching pool volume...');
    const V = await fetchPoolVolume(poolAddress, ethPricePool);
    console.log('Volume fetched (in wei):', V.toString());

    // Convert wei to ETH
    const volumeinETH = ethers.formatEther(V);
    console.log('Volume fetched (in ETH):', volumeinETH);

    const volume = ethers.parseEther(volumeinETH);

    const code = await provider.getCode(contractAddress);
    if (code === '0x')
      throw new Error('No contract deployed at the given address.');

    const block = await provider.getBlock('latest');
    const deadline = block.timestamp + 3600 * 24;

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

    console.log('Fetching VIX Data...');
    const result = await contract.getVixData(deriveToken);
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
    throw error;
  }
}

// Example usage
const deriveToken = '0x514910771AF9Ca656af840dff83E8264EcF986CA'; // WBTC
const poolAddress = '0xa6Cc3C2531FdaA6Ae1A3CA84c2855806728693e8';

deployCurrency(deriveToken, poolAddress)
  .then((data) => console.log('Returned Vix Data:', data))
  .catch((err) => console.error('Deployment failed:', err));

module.exports = { deployCurrency, fetchPoolVolume };
