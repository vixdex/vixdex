'use client';
import { useState } from 'react';
import Head from 'next/head';
import { motion, AnimatePresence } from 'framer-motion';
import { deployCurrency } from '../deployData';
import { initializePool } from '../v4';

export default function CreateVolatilityPair() {
  const [asset, setAsset] = useState('');
  const [poolAddress, setPoolAddress] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    setMessage('');

    try {
      // Step 1: Deploy the currency pair and get Vix data
      const vixData = await deployCurrency(asset, poolAddress);
      if (!vixData) {
        throw new Error('No VIX data returned after deployment');
      }

      setMessage(
        `Pair deployed! High Token: ${vixData.vixHighToken}, Low Token: ${vixData.vixLowToken} `
      );

      // Step 2: Initialize pools for high and low VIX tokens
      setMessage((prev) => `${prev}\nInitializing High VIX pool...`);
      await initializePool(vixData.vixHighToken);
      setMessage((prev) => `${prev}\nHigh VIX pool initialized!`);

      setMessage((prev) => `${prev}\nInitializing Low VIX pool...`);
      await initializePool(vixData.vixLowToken);
      setMessage(
        (prev) =>
          `${prev}\nLow VIX pool initialized!\nAll operations completed successfully!`
      );
    } catch (error) {
      setMessage(`Error: ${error.message}`);
    }

    setIsLoading(false);
    setAsset('');
    setPoolAddress('');
  };

  return (
    <div className="min-h-screen bg-[#121418] text-[#F7EFDE] font-sans overflow-hidden relative">
      <Head>
        <title>Create New Volatility Pair</title>
        <meta
          name="description"
          content="Create custom volatility trading pairs"
        />
      </Head>

      <main className="max-w-2xl mx-auto p-10 sm:p-16 relative z-10">
        <motion.form
          onSubmit={handleSubmit}
          className="space-y-8 bg-[#1a1e22] p-8 rounded-xl border border-[#503A39]"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          {/* Asset Name */}
          <motion.div
            initial={{ x: -50, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="relative"
          >
            <label className="block text-sm mb-2 text-[#E2C19B]">
              Derived Asset
            </label>
            <input
              type="text"
              value={asset}
              onChange={(e) => setAsset(e.target.value)}
              placeholder="e.g., 0x1234...5678"
              className="w-full p-4 bg-[#121418] border border-[#503A39] rounded-lg text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors duration-300"
              required
            />
          </motion.div>

          {/* Pool Address */}
          <motion.div
            initial={{ x: -50, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.2 }}
          >
            <label className="block text-sm mb-2 text-[#E2C19B]">
              Pool Address
            </label>
            <input
              type="text"
              value={poolAddress}
              onChange={(e) => setPoolAddress(e.target.value)}
              placeholder="e.g., 0x1234...5678"
              className="w-full p-4 bg-[#121418] border border-[#503A39] rounded-lg text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors duration-300"
              required
            />
          </motion.div>

          {/* Review Section */}
          <AnimatePresence>
            {asset && poolAddress && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 20 }}
                transition={{ duration: 0.5 }}
                className="p-6 bg-[#121418] rounded-lg border border-[#503A39]"
              >
                <h2 className="text-lg font-semibold text-[#E2C19B] mb-3">
                  Review Your Pair
                </h2>
                <p>
                  Asset: <span className="text-[#F7EFDE]">{asset}</span>
                </p>
                <p>
                  Pool Address:{' '}
                  <span className="text-[#F7EFDE]">
                    {poolAddress.slice(0, 6)}...{poolAddress.slice(-4)}
                  </span>
                </p>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Submit Button */}
          <motion.button
            type="submit"
            disabled={isLoading || !asset || !poolAddress}
            className={`w-full py-3 bg-[#3EAFA4] text-[#F7EFDE] rounded-lg font-semibold transition-colors duration-300 ${
              isLoading ? 'opacity-50 cursor-not-allowed' : 'hover:bg-[#E2C19B]'
            }`}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            transition={{ duration: 0.2 }}
          >
            {isLoading ? (
              <motion.span
                className="flex items-center justify-center"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.2 }}
              >
                <motion.svg
                  className="h-5 w-5 mr-2"
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
                    opacity="0.25"
                  />
                  <path fill="#E2C19B" d="M4 12a8 8 0 018-8v8H4z" />
                </motion.svg>
                Creating...
              </motion.span>
            ) : (
              'Create Pair'
            )}
          </motion.button>

          {/* Feedback Message */}
          <AnimatePresence>
            {message && (
              <motion.div
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.8 }}
                transition={{ duration: 0.5 }}
                className="p-4 rounded-lg bg-[#1a1e22] text-[#F7EFDE] border border-[#3EAFA4]"
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
