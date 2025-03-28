const UNISWAP_V3_SUBGRAPH_URL =
  'https://gateway.thegraph.com/api/980d851dd2584dc8ecf369692a33b5a0/subgraphs/id/5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV';
// WETH address (Ethereum mainnet)
const WETH_ADDRESS = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';

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
    const response = await fetch(UNISWAP_V3_SUBGRAPH_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query, variables }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const result = await response.json();

    if (result.errors) {
      throw new Error(
        `GraphQL error: ${result.errors.map((e) => e.message).join(', ')}`
      );
    }

    const poolData = result.data.pools[0];
    if (!poolData) {
      console.log(`No data found for pool: ${formattedPoolAddress}`);
      return;
    }

    let ethPrice;
    if (poolData.token0.id.toLowerCase() === WETH_ADDRESS) {
      // WETH is token0, price is token1 per token0 (e.g., USDC per WETH)
      ethPrice = parseFloat(poolData.token1Price);
      console.log(`ETH Price: ${ethPrice} ${poolData.token1.symbol} per ETH`);
    } else if (poolData.token1.id.toLowerCase() === WETH_ADDRESS) {
      // WETH is token1, price is token0 per token1 (e.g., USDC per WETH)
      ethPrice = parseFloat(poolData.token0Price);
      console.log(`ETH Price: ${ethPrice} ${poolData.token0.symbol} per ETH`);
    } else {
      console.log(`Pool ${formattedPoolAddress} does not contain WETH`);
      return;
    }

    return ethPrice;
  } catch (error) {
    console.error('Error fetching ETH price:', error.message);
  }
}

// Example usage
const poolAddress = '0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8'; // USDC/WETH pool
fetchEthPrice(poolAddress);
