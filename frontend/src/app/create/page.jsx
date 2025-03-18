'use client';
import { useState } from 'react';
import Head from 'next/head';
import { motion, AnimatePresence } from 'framer-motion';

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
    <div className="min-h-screen bg-black text-white font-sans overflow-hidden relative">
      <Head>
        <title>Create New Volatility Pair</title>
        <meta
          name="description"
          content="Create custom volatility trading pairs"
        />
      </Head>
      {/* Spinning Wheel Background Animation */}
      <motion.div
        className="absolute top-0 left-0 w-full h-full opacity-10 pointer-events-none"
        animate={{ rotate: 360 }}
        transition={{ duration: 20, repeat: Infinity, ease: 'linear' }}
      >
        <svg className="w-full h-full" viewBox="0 0 100 100">
          <circle
            cx="50"
            cy="50"
            r="45"
            stroke="#CCFF00"
            strokeWidth="2"
            fill="none"
          />
          <path
            d="M50 5 A45 45 0 0 1 95 50"
            stroke="#CCFF00"
            strokeWidth="4"
            fill="none"
          />
        </svg>
      </motion.div>

      <main className="max-w-2xl mx-auto p-10 sm:p-20 relative z-10 ">
        <form onSubmit={handleSubmit} className="space-y-8">
          {/* Step 1: Select Asset */}
          <motion.div
            initial={{ x: -100, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.1 }}
          >
            <label className="block text-sm mb-2">Asset Name</label>
            <select
              value={asset}
              onChange={(e) => setAsset(e.target.value)}
              className="w-full p-3 bg-[#1a1a1a] border border-[#CCFF00] rounded text-white focus:outline-none focus:ring-2 focus:ring-[#CCFF00] bg-gradient-to-r from-[#1a1a1a] to-[#2a2a2a] transition-shadow duration-300 focus:shadow-[0_0_10px_#CCFF00]"
              required
            >
              <option value="">Choose an asset</option>
              {assets.map((a) => (
                <option key={a} value={a}>
                  {a}
                </option>
              ))}
            </select>
          </motion.div>

          {/* Step 2: Pool Address */}
          <motion.div
            initial={{ x: -100, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.2 }}
          >
            <label className="block text-sm mb-2">Pool Address</label>
            <input
              type="text"
              value={poolAddress}
              onChange={(e) => setPoolAddress(e.target.value)}
              placeholder="e.g., 0x1234...5678"
              className="w-full p-3 bg-[#1a1a1a] border border-[#CCFF00] rounded text-white focus:outline-none focus:ring-2 focus:ring-[#CCFF00] bg-gradient-to-r from-[#1a1a1a] to-[#2a2a2a] transition-shadow duration-300 focus:shadow-[0_0_10px_#CCFF00]"
              required
            />
          </motion.div>

          {/* Step 3: Period */}
          <motion.div
            initial={{ x: -100, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.3 }}
          >
            <label className="block text-sm mb-2">Period</label>
            <select
              value={timePeriod}
              onChange={(e) => setTimePeriod(e.target.value)}
              className="w-full p-3 bg-[#1a1a1a] border border-[#CCFF00] rounded text-white focus:outline-none focus:ring-2 focus:ring-[#CCFF00] bg-gradient-to-r from-[#1a1a1a] to-[#2a2a2a] transition-shadow duration-300 focus:shadow-[0_0_10px_#CCFF00]"
              required
            >
              <option value="">Select period</option>
              {periods.map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
          </motion.div>

          {/* Review and Confirm */}
          <AnimatePresence>
            {asset && poolAddress && timePeriod && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 20 }}
                transition={{ duration: 0.5 }}
                className="p-4 bg-[#1a1a1a] rounded border border-[#CCFF00] shadow-lg"
              >
                <h2 className="text-lg font-['Playfair_Display'] text-[#CCFF00] mb-2 animate-pulse">
                  Review Your Pair
                </h2>
                <p>Asset: {asset}</p>
                <p>
                  Pool Address: {poolAddress.slice(0, 6)}...
                  {poolAddress.slice(-4)}
                </p>
                <p>Period: {timePeriod}</p>
                <p className="mt-2">
                  Proposed Pair:{' '}
                  <span className="text-[#CCFF00] font-bold">
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
            className={`w-full py-3 bg-[#CCFF00] text-black border-2 border-white rounded-full font-bold cursor-pointer shadow-[0_0_10px_rgba(204,255,0,0.5)] hover:shadow-[0_0_15px_#CCFF00] transition-shadow duration-300 ${
              isLoading ? 'opacity-50 cursor-not-allowed' : ''
            }`}
            whileHover={{ scale: 1.1, boxShadow: '0 0 15px #CCFF00' }}
            whileTap={{ scale: 0.95 }}
            transition={{ duration: 0.3 }}
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
                    stroke="#CCFF00"
                    strokeWidth="4"
                    fill="none"
                    opacity="0.25"
                  />
                  <path fill="#CCFF00" d="M4 12a8 8 0 018-8v8H4z" />
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
                className={`p-4 rounded ${
                  message.includes('successfully')
                    ? 'bg-[#CCFF00] text-black shadow-[0_0_20px_#CCFF00]'
                    : 'bg-red-600 text-white'
                }`}
              >
                {message}
              </motion.div>
            )}
          </AnimatePresence>
        </form>
      </main>
    </div>
  );
}
