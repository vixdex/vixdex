'use client';
import { motion } from 'framer-motion';
import { useState } from 'react';

const BuySell = ({
  selectedPair,
  setSelectedPair,
  quantity,
  setQuantity,
  pairs,
  balance,
  handleTrade,
}) => {
  const [activeTab, setActiveTab] = useState('high'); // 'high' or 'low'

  return (
    <motion.div
      className="w-[30%] bg-[#1a1e22]  p-4 flex flex-col  justify-center"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5, delay: 0.2 }}
    >
      <h3 className="text-[#E2C19B] font-semibold mb-2">
        Trade {selectedPair}
      </h3>

      {/* Tabs */}
      <div className="flex space-x-2 mb-4">
        <motion.button
          onClick={() => setActiveTab('high')}
          className={`flex-1 p-2 rounded font-semibold ${
            activeTab === 'high'
              ? 'bg-[#3EAFA4] text-[#F7EFDE]'
              : 'bg-[#252a2f] text-[#E2C19B] hover:bg-[#E2C19B] hover:text-[#121418]'
          }`}
          whileHover={{ scale: 1.05 }}
        >
          High
        </motion.button>
        <motion.button
          onClick={() => setActiveTab('low')}
          className={`flex-1 p-2 rounded font-semibold ${
            activeTab === 'low'
              ? 'bg-[#3EAFA4] text-[#F7EFDE]'
              : 'bg-[#252a2f] text-[#E2C19B] hover:bg-[#E2C19B] hover:text-[#121418]'
          }`}
          whileHover={{ scale: 1.05 }}
        >
          Low
        </motion.button>
      </div>

      {/* Quantity Input */}
      <input
        type="number"
        value={quantity}
        onChange={(e) => setQuantity(e.target.value)}
        placeholder="Quantity"
        className="w-full p-2 mb-4 bg-[#121418] border border-[#503A39] rounded text-[#F7EFDE]"
      />

      {/* Tab Content */}
      <div className="flex space-x-2 mb-4">
        <motion.button
          onClick={() => handleTrade('buy', activeTab)}
          className="flex-1 bg-[#3EAFA4] p-2 rounded font-semibold hover:bg-[#E2C19B]"
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
        >
          Buy {activeTab === 'high' ? 'High' : 'Low'}
        </motion.button>
        <motion.button
          onClick={() => handleTrade('sell', activeTab)}
          className="flex-1 bg-[#E2C19B] text-[#121418] p-2 rounded font-semibold hover:bg-[#3EAFA4] hover:text-[#F7EFDE]"
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
        >
          Sell {activeTab === 'high' ? 'High' : 'Low'}
        </motion.button>
      </div>

      {/* Current Price and Balance */}
      <p className="text-sm mb-2">
        Current Price:{' '}
        {pairs.find((p) => p.pair === selectedPair)?.price.toFixed(4) || 'N/A'}
      </p>
      <p className="text-sm">Balance: {balance.toFixed(2)} USDT</p>
    </motion.div>
  );
};

export default BuySell;
