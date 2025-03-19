'use client';
import { useState } from 'react';
import Head from 'next/head';
import { motion, AnimatePresence } from 'framer-motion';

// Assuming these are your token icons (you'll need to import actual images or use SVGs)
const tokenIcons = {
  Bitcoin: 'https://cryptologos.cc/logos/bitcoin-btc-logo.png?v=032', // Replace with your local asset or SVG
  Ethereum: 'https://cryptologos.cc/logos/ethereum-eth-logo.png?v=032',
  Ripple: 'https://cryptologos.cc/logos/xrp-xrp-logo.png?v=032',
};

export default function CreateVolatilityPair() {
  const [asset, setAsset] = useState('');
  const [poolAddress, setPoolAddress] = useState('');
  const [timePeriod, setTimePeriod] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState('');

  const assets = ['Bitcoin', 'Ethereum', 'Ripple'];
  const periods = ['1 day', '7 days'];

  const handleSubmit = (e) => {
    e.preventDefault();
    setIsLoading(true);
    setMessage('');

    setTimeout(() => {
      const pairSymbol = `${asset.slice(0, 3).toUpperCase()}-HV${
        timePeriod === '1 day' ? '1D' : '7D'
      }`;
      setIsLoading(false);
      setMessage(
        `New pair ${pairSymbol} created successfully and is now available for trading.`
      );
      setAsset('');
      setPoolAddress('');
      setTimePeriod('');
    }, 2000);
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
          {/* Asset Name with Beautified Dropdown */}
          <motion.div
            initial={{ x: -50, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="relative"
          >
            <label className="block text-sm mb-2 text-[#E2C19B]">
              Asset Name
            </label>
            <select
              value={asset}
              onChange={(e) => setAsset(e.target.value)}
              className="w-full p-4 bg-[#121418] border border-[#503A39] rounded-lg text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors duration-300 appearance-none cursor-pointer"
              required
            >
              <option value="" disabled>
                Choose an asset
              </option>
              {assets.map((a) => (
                <option
                  key={a}
                  value={a}
                  className="bg-[#1a1e22]  text-[#F7EFDE]"
                >
                  {a}
                </option>
              ))}
            </select>
            {/* Dropdown Arrow */}
            <div className="absolute right-4 top-12 pointer-events-none">
              <svg
                className="w-4 h-4 text-[#E2C19B]"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </div>
            {/* Selected Asset Icon */}
            {asset && (
              <img
                src={tokenIcons[asset]}
                alt={`${asset} icon`}
                className="absolute right-10 top-12 w-5 h-5 "
              />
            )}
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

          {/* Period with Button Selection */}
          <motion.div
            initial={{ x: -50, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.3 }}
          >
            <label className="block text-sm mb-2 text-[#E2C19B]">Period</label>
            <div className="flex space-x-4">
              {periods.map((p) => (
                <motion.button
                  key={p}
                  type="button"
                  onClick={() => setTimePeriod(p)}
                  className={`flex-1 py-3 px-4 rounded-lg border border-[#503A39] text-[#F7EFDE] font-semibold transition-colors duration-300 ${
                    timePeriod === p
                      ? 'bg-[#3EAFA4] text-[#F7EFDE]'
                      : 'bg-[#121418] hover:bg-[#E2C19B] hover:text-[#121418]'
                  }`}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  transition={{ duration: 0.2 }}
                >
                  {p === '1 day' ? '1 Day Volatility' : '7 Day Volatility'}
                </motion.button>
              ))}
            </div>
          </motion.div>

          {/* Review Section */}
          <AnimatePresence>
            {asset && poolAddress && timePeriod && (
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
                <p>
                  Period: <span className="text-[#F7EFDE]">{timePeriod}</span>
                </p>
                <p className="mt-2">
                  Proposed Pair:{' '}
                  <span className="text-[#3EAFA4] font-semibold">
                    {`${asset.slice(0, 3).toUpperCase()}-HV${
                      timePeriod === '1 day' ? '1D' : '7D'
                    }`}
                  </span>
                </p>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Submit Button */}
          <motion.button
            type="submit"
            disabled={isLoading || !asset || !poolAddress || !timePeriod}
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
