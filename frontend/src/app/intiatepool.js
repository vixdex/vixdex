import { ethers } from 'ethers';
// Setup provider and contract
const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
const signer = await provider.getSigner(0);

const contractAddress = '0x97d267B69dE5BC1f78d3894aF0fbc71e1aDc4Cc8';
const contractABI = [
  // Minimal ABI for this function
  'function getVixData(address deriveAsset) public view returns (address vixHighToken, address vixLowToken, uint256 circulation0, uint256 circulation1, uint256 contractHoldings0, uint256 contractHoldings1, uint256 reserve0, uint256 reserve1, address poolAddress)',
];

const contract = new ethers.Contract(contractAddress, contractABI, signer);

async function getVixData(deriveAssetAddress) {
  try {
    // Call the function
    const result = await contract.getVixData(deriveAssetAddress);

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
      poolAddress,
    ] = result;

    // Log or return the results
    console.log({
      vixHighToken,
      vixLowToken,
      circulation0: circulation0.toString(),
      circulation1: circulation1.toString(),
      contractHoldings0: contractHoldings0.toString(),
      contractHoldings1: contractHoldings1.toString(),
      reserve0: reserve0.toString(),
      reserve1: reserve1.toString(),
      poolAddress,
    });

    return {
      vixHighToken,
      vixLowToken,
      circulation0,
      circulation1,
      contractHoldings0,
      contractHoldings1,
      reserve0,
      reserve1,
      poolAddress,
    };
  } catch (error) {
    console.error('Error fetching VIX data:', error);
    throw error;
  }
}

// Example usage
const deriveAssetAddress = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599'; // Your derived token address
getVixData(deriveAssetAddress);
