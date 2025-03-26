'use client';
import { useState, useEffect } from 'react';
import Head from 'next/head';
import { motion, AnimatePresence } from 'framer-motion';
import { ethers } from 'ethers';

const abi = [
  'function name() view returns (string)',
  'function vixTokensPrice(uint circulation) pure returns(uint)',
  'function deploy2Currency(address deriveToken, string[2] memory _tokenName, string[2] memory _tokenSymbol, address _poolAddress, uint160 volume, uint deadline) returns(address[2] memory)',
];

export default function CreateVolatilityPair() {
  const [asset, setAsset] = useState('');
  const [poolAddress, setPoolAddress] = useState('');
  const [timePeriod, setTimePeriod] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [contract, setContract] = useState(null);
  const [provider, setProvider] = useState(null);
  const [isInitialized, setIsInitialized] = useState(false);

  // Initialize provider and contract
  useEffect(() => {
    const init = async () => {
      try {
        const newProvider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
        const signer = await newProvider.getSigner(0);
        const contractAddress = '0xF6a4c2dE753cc1a128C1e7A44608Ff57AC8dCcC8';
        const newContract = new ethers.Contract(contractAddress, abi, signer);

        setProvider(newProvider);
        setContract(newContract);
        setIsInitialized(true); // Mark as initialized only after successful setup
      } catch (error) {
        console.error('Failed to initialize contract:', error);
        setMessage(
          'Failed to connect to blockchain network. Please check your local node.'
        );
        setIsInitialized(false);
      }
    };
    init();
  }, []);

  const deriveToken = asset;
  const tokenNames = ['TokenA', 'TokenB'];
  const tokenSymbols = ['TKA', 'TKB'];
  const poolAddr = poolAddress;
  const volume = ethers.parseEther('1000');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    setMessage('');

    if (!isInitialized || !contract || !provider) {
      setMessage('Contract not initialized. Please wait or refresh the page.');
      setIsLoading(false);
      return;
    }

    try {
      // Verify contract exists
      const code = await provider.getCode(contract.address);
      if (code === '0x') {
        throw new Error('No contract deployed at the given address.');
      }

      // Get current timestamp
      const block = await provider.getBlock('latest');
      const currentTimestamp = block.timestamp;
      const deadline = currentTimestamp + 3600 * 24;

      // Send transaction
      console.log('Deploying currency pair...');
      const tx = await contract.deploy2Currency(
        deriveToken,
        tokenNames,
        tokenSymbols,
        poolAddress,
        volume,
        deadline,
        { gasLimit: 50000000 }
      );
      console.log('Transaction hash:', tx.hash);
      console.log(
        deriveToken,
        tokenNames,
        tokenSymbols,
        poolAddress,
        volume,
        deadline
      );

      // Wait for confirmation
      const receipt = await tx.wait();
      console.log('Transaction confirmed in block:', receipt.blockNumber);

      setTimeout(() => {
        setIsLoading(false);
        setMessage(
          `New pair ${deriveToken.slice(0, 3).toUpperCase()}-HV${
            timePeriod === '1 day' ? '1D' : '7D'
          } created successfully and is now available for trading.`
        );
        setAsset('');
        setPoolAddress('');
        setTimePeriod('');
      }, 2000);
    } catch (error) {
      console.error('Error deploying currency:', error.message);
      if (error.reason) console.error('Revert reason:', error.reason);
      setMessage(`Error: ${error.message}`);
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#121418] text-[#F7EFDE] font-sans">
      <Head>
        <title>Create New Volatility Pair</title>
        <meta
          name="description"
          content="Create custom volatility trading pairs"
        />
      </Head>

      <main className="container mx-auto px-4 py-8 md:p-16">
        <motion.form
          onSubmit={handleSubmit}
          className="max-w-lg mx-auto bg-[#1a1e22] p-6 rounded-lg border border-[#503A39] space-y-6"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          <div className="space-y-4">
            <motion.div
              initial={{ x: -20, opacity: 0 }}
              animate={{ x: 0, opacity: 1 }}
              transition={{ duration: 0.5, delay: 0.1 }}
            >
              <label className="block text-sm font-medium text-[#E2C19B] mb-1">
                Asset Name
              </label>
              <input
                type="text"
                value={asset}
                onChange={(e) => setAsset(e.target.value)}
                placeholder="e.g., Bitcoin"
                className="w-full px-3 py-2 bg-[#121418] border border-[#503A39] rounded-md text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors"
                required
              />
            </motion.div>

            <motion.div
              initial={{ x: -20, opacity: 0 }}
              animate={{ x: 0, opacity: 1 }}
              transition={{ duration: 0.5, delay: 0.2 }}
            >
              <label className="block text-sm font-medium text-[#E2C19B] mb-1">
                Pool Address
              </label>
              <input
                type="text"
                value={poolAddress}
                onChange={(e) => setPoolAddress(e.target.value)}
                placeholder="e.g., 0x1234...5678"
                className="w-full px-3 py-2 bg-[#121418] border border-[#503A39] rounded-md text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors"
                required
              />
            </motion.div>
          </div>

          <AnimatePresence>
            {asset && poolAddress && (
              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.95 }}
                transition={{ duration: 0.3 }}
                className="bg-[#121418] p-4 rounded-md border border-[#503A39]"
              >
                <h2 className="text-md font-medium text-[#E2C19B] mb-2">
                  Pair Preview
                </h2>
                <div className="space-y-1 text-sm">
                  <p>
                    Asset: <span className="text-[#F7EFDE]">{asset}</span>
                  </p>
                  <p>
                    Pool:{' '}
                    <span className="text-[#F7EFDE]">
                      {poolAddress.slice(0, 6)}...{poolAddress.slice(-4)}
                    </span>
                  </p>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <motion.button
            type="submit"
            disabled={isLoading || !asset || !poolAddress || !isInitialized}
            className={`w-full py-2 bg-[#3EAFA4] text-[#F7EFDE] rounded-md font-medium transition-all ${
              isLoading || !isInitialized
                ? 'opacity-60 cursor-not-allowed'
                : 'hover:bg-[#E2C19B] hover:shadow-md'
            }`}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            transition={{ duration: 0.2 }}
          >
            {isLoading ? (
              <motion.span
                className="flex items-center justify-center gap-2"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.2 }}
              >
                <motion.svg
                  className="w-4 h-4"
                  animate={{ rotate: 360 }}
                  transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
                  viewBox="0 0 24 24"
                >
                  <circle
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="#E2C19B"
                    strokeWidth="4"
                    fill="none"
                    opacity="0.3"
                  />
                  <path fill="#E2C19B" d="M4 12a8 8 0 018-8v8H4z" />
                </motion.svg>
                Processing...
              </motion.span>
            ) : !isInitialized ? (
              'Initializing...'
            ) : (
              'Create Pair'
            )}
          </motion.button>

          <AnimatePresence>
            {message && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 10 }}
                transition={{ duration: 0.3 }}
                className="p-3 rounded-md bg-[#1a1e22] border border-[#3EAFA4] text-sm text-[#F7EFDE]"
              >
                {message}
              </motion.div>
            )}
          </AnimatePresence>
        </motion.form>
      </main>
    </div>
  );
}
