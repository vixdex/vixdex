const axios = require('axios');

const UNISWAP_V3_SUBGRAPH_URL =
  'https://gateway.thegraph.com/api/980d851dd2584dc8ecf369692a33b5a0/subgraphs/id/5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV';

// WETH address (Ethereum mainnet)
const WETH_ADDRESS = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';

// Function to fetch real-time ETH price from a pool
async function fetchEthPrice(poolAddress) {
  const formattedPoolAddress = poolAddress.toLowerCase();

  const query = `
    query GetEthPrice($poolAddress: String!) {
      pools(where: { id: $poolAddress }) {
        id
        token0 {
          symbol
          id
        }
        token1 {
          symbol
          id
        }
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
      {
        headers: { 'Content-Type': 'application/json' },
      }
    );

    const result = response.data;

    if (result.errors) {
      throw new Error(
        `GraphQL error: ${result.errors.map((e) => e.message).join(', ')}`
      );
    }

    const poolData = result.data.pools[0];
    if (!poolData) {
      throw new Error(`No data found for pool: ${formattedPoolAddress}`);
    }

    let ethPrice;
    if (poolData.token0.id.toLowerCase() === WETH_ADDRESS) {
      ethPrice = parseFloat(poolData.token1Price); // Price of token1 (e.g., USDC) per ETH
    } else if (poolData.token1.id.toLowerCase() === WETH_ADDRESS) {
      ethPrice = parseFloat(poolData.token0Price); // Price of token0 (e.g., USDC) per ETH
    } else {
      throw new Error(`Pool ${formattedPoolAddress} does not contain WETH`);
    }

    return ethPrice; // Returns price in terms of the paired token (e.g., USDC per ETH)
  } catch (error) {
    console.error('Error fetching ETH price:', error.message);
    return null; // Return null on error to handle gracefully in the caller
  }
}

// Function to fetch pool volume and convert USD to ETH
async function fetchPoolVolume(poolAddress, ethPricePoolAddress) {
  const formattedPoolAddress = poolAddress.toLowerCase();

  const query = `
    {
      poolDayDatas(first: 1, orderBy: date, orderDirection: desc, where: { pool: "${formattedPoolAddress}" }) {
        date
        volumeUSD
      }
    }
  `;

  try {
    // Fetch ETH price from the specified pool (could be the same or different pool)
    const ethPrice = await fetchEthPrice(ethPricePoolAddress);
    if (!ethPrice) {
      console.log('Skipping volume conversion due to ETH price fetch failure');
      return;
    }

    const response = await axios.post(
      UNISWAP_V3_SUBGRAPH_URL,
      { query },
      {
        headers: { 'Content-Type': 'application/json' },
      }
    );

    const result = response.data;

    if (result.errors) {
      throw new Error(
        `GraphQL error: ${result.errors.map((e) => e.message).join(', ')}`
      );
    }

    const poolData = result.data.poolDayDatas[0];
    if (!poolData) {
      console.log(`No data found for pool: ${formattedPoolAddress}`);
      return;
    }

    const volumeUSD = parseFloat(poolData.volumeUSD);
    const volumeETH = volumeUSD / ethPrice; // Convert USD volume to ETH

    console.log(`Pool Data for ${formattedPoolAddress}:`);
    console.log(`Date: ${new Date(poolData.date * 1000).toISOString()}`);
    console.log(`Volume USD: $${volumeUSD.toLocaleString()}`);
    console.log(
      `Volume ETH: ${volumeETH.toLocaleString(undefined, {
        maximumFractionDigits: 4,
      })} ETH (at ${ethPrice} USD/ETH)`
    );
  } catch (error) {
    if (error.response) {
      console.error(
        'Error fetching pool volume:',
        `HTTP error! status: ${error.response.status}`
      );
    } else {
      console.error('Error fetching pool volume:', error.message);
    }
  }
}

const poolAddress1 = '0xa6Cc3C2531FdaA6Ae1A3CA84c2855806728693e8'; // USDC-WETH pool (for volume)

const ethPricePool = '0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8'; // USDC-WETH pool (for ETH price)

fetchPoolVolume(poolAddress1, ethPricePool);

module.exports = { fetchPoolVolume };
