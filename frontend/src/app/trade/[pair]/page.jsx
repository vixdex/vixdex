'use client';
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Link from 'next/link';
import { useParams } from 'next/navigation'; // To get dynamic route params

// Mock data for pairs and chart (replace with API/websocket in production)
const mockPairs = [
  { pair: 'BTC-VOL/USDT', price: 0.0523 },
  { pair: 'ETH-VOL/USDT', price: 0.0345 },
  { pair: 'XRP-VOL/USDT', price: 0.0123 },
];

const mockChartData = Array.from({ length: 60 }, (_, i) => ({
  time: Math.floor(Date.now() / 1000) - (60 - i) * 60, // 1-minute intervals
  value: 0.05 + Math.random() * 0.01, // Random price fluctuations
}));

export default function TradePair() {
  const { pair } = useParams(); // Get pair from URL (e.g., "BTC-VOL/USDT")
  const [selectedPair, setSelectedPair] = useState(pair || mockPairs[0].pair);
  const [orderType, setOrderType] = useState('market'); // market, limit, stop-loss
  const [quantity, setQuantity] = useState('');
  const [price, setPrice] = useState('');
  const [chartTimeFrame, setChartTimeFrame] = useState('1m');
  const [showMeme, setShowMeme] = useState(null);
  const [balance, setBalance] = useState(1000); // Mock balance in USDT

  // Simulate real-time price updates
  useEffect(() => {
    const interval = setInterval(() => {
      setPairs((prev) =>
        prev.map((p) => ({
          ...p,
          price: p.price * (1 + (Math.random() - 0.5) * 0.02),
        }))
      );
    }, 5000); // Update every 5 seconds
    return () => clearInterval(interval);
  }, []);

  const [pairs, setPairs] = useState(mockPairs);

  const handleTrade = (action) => {
    if (!quantity || (orderType === 'limit' && !price)) {
      alert('Please enter quantity and price (for limit orders).');
      return;
    }
    // Simulate trade execution
    const tradeAmount =
      orderType === 'market'
        ? quantity * pairs.find((p) => p.pair === selectedPair).price
        : quantity * parseFloat(price);
    setBalance((prev) =>
      action === 'buy' ? prev - tradeAmount : prev + tradeAmount
    );
    setShowMeme(action === 'buy' ? 'To the Moon! 🚀' : 'Diamond Hands! 💎');
    setTimeout(() => setShowMeme(null), 2000); // Hide meme after 2s
    setQuantity('');
    setPrice('');
  };

  return (
    <div className="min-h-screen bg-[#121418] text-[#F7EFDE] font-sans flex flex-col">
      <div className="flex flex-1">
        {/* Left Sidebar: Pair List */}
        <motion.aside
          className="w-64 bg-[#1a1e22] p-4 border-r border-[#503A39]"
          initial={{ x: -50, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ duration: 0.5 }}
        >
          <h2 className="text-[#E2C19B] text-lg font-semibold mb-4">
            Volatility Pairs
          </h2>
          {pairs.map((p) => (
            <motion.button
              key={p.pair}
              onClick={() => setSelectedPair(p.pair)}
              className={`w-full text-left p-2 mb-2 rounded-lg ${
                selectedPair === p.pair
                  ? 'bg-[#3EAFA4] text-[#F7EFDE]'
                  : 'bg-[#121418] hover:bg-[#252a2f]'
              } transition-colors duration-300`}
              whileHover={{ scale: 1.05 }}
              transition={{ duration: 0.2 }}
            >
              {p.pair} - {p.price.toFixed(4)}
            </motion.button>
          ))}
        </motion.aside>

        {/* Central Area: Real-Time Chart */}
        <motion.main
          className="flex-1 p-6"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.2 }}
        >
          <div className="bg-[#1a1e22] p-4 rounded-xl border border-[#503A39]">
            <h2 className="text-[#E2C19B] text-lg font-semibold mb-4">
              {selectedPair} Chart
            </h2>
            {/* Placeholder for chart (use a library like recharts or lightweight-charts) */}
            <div className="h-96 bg-[#121418] rounded-lg flex items-center justify-center">
              <p className="text-[#F7EFDE]">
                Real-time chart placeholder for {selectedPair}
              </p>
            </div>
            <div className="flex space-x-4 mt-4">
              {['1m', '5m', '1h', '1d'].map((tf) => (
                <motion.button
                  key={tf}
                  onClick={() => setChartTimeFrame(tf)}
                  className={`px-3 py-1 rounded-lg ${
                    chartTimeFrame === tf
                      ? 'bg-[#3EAFA4]'
                      : 'bg-[#252a2f] hover:bg-[#E2C19B]'
                  } transition-colors duration-300`}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  {tf}
                </motion.button>
              ))}
            </div>
          </div>
        </motion.main>

        {/* Right Panel: Order Placement, Order Book, Trade History */}
        <motion.aside
          className="w-80 bg-[#1a1e22] p-4 border-l border-[#503A39]"
          initial={{ x: 50, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ duration: 0.5 }}
        >
          {/* Order Placement */}
          <div className="mb-6">
            <h3 className="text-[#E2C19B] font-semibold mb-2">Place Order</h3>
            <select
              value={orderType}
              onChange={(e) => setOrderType(e.target.value)}
              className="w-full p-2 mb-2 bg-[#121418] border border-[#503A39] rounded-lg text-[#F7EFDE]"
            >
              <option value="market">Market</option>
              <option value="limit">Limit</option>
              <option value="stop-loss">Stop-Loss</option>
            </select>
            <input
              type="number"
              value={quantity}
              onChange={(e) => setQuantity(e.target.value)}
              placeholder="Quantity"
              className="w-full p-2 mb-2 bg-[#121418] border border-[#503A39] rounded-lg text-[#F7EFDE]"
            />
            {orderType !== 'market' && (
              <input
                type="number"
                value={price}
                onChange={(e) => setPrice(e.target.value)}
                placeholder="Price"
                className="w-full p-2 mb-2 bg-[#121418] border border-[#503A39] rounded-lg text-[#F7EFDE]"
              />
            )}
            <div className="flex space-x-2">
              <motion.button
                onClick={() => handleTrade('buy')}
                className="flex-1 bg-[#3EAFA4] text-[#F7EFDE] p-2 rounded-lg font-semibold hover:bg-[#E2C19B]"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                transition={{ duration: 0.2 }}
              >
                Buy 🚀
              </motion.button>
              <motion.button
                onClick={() => handleTrade('sell')}
                className="flex-1 bg-[#E2C19B] text-[#121418] p-2 rounded-lg font-semibold hover:bg-[#3EAFA4] hover:text-[#F7EFDE]"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                transition={{ duration: 0.2 }}
              >
                Sell 🪂
              </motion.button>
            </div>
          </div>

          {/* Order Book Placeholder */}
          <div className="mb-6">
            <h3 className="text-[#E2C19B] font-semibold mb-2">Order Book</h3>
            <div className="h-32 bg-[#121418] rounded-lg flex items-center justify-center">
              <p>Order book placeholder</p>
            </div>
          </div>

          {/* Trade History Placeholder */}
          <div>
            <h3 className="text-[#E2C19B] font-semibold mb-2">Trade History</h3>
            <div className="h-32 bg-[#121418] rounded-lg flex items-center justify-center">
              <p>Trade history placeholder</p>
            </div>
          </div>
        </motion.aside>
      </div>

      {/* Bottom Section: Balance and Positions */}
      <motion.footer
        className="bg-[#1a1e22] p-4 border-t border-[#503A39]"
        initial={{ y: 50, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.5, delay: 0.3 }}
      >
        <p className="text-[#F7EFDE]">Balance: {balance.toFixed(2)} USDT</p>
        <p className="text-[#E2C19B]">Open Positions: None (placeholder)</p>
      </motion.footer>

      {/* Meme Overlay */}
      <AnimatePresence>
        {showMeme && (
          <motion.div
            className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50 z-50"
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.8 }}
            transition={{ duration: 0.3 }}
          >
            <div className="bg-[#252a2f] p-6 rounded-lg text-[#F7EFDE] text-xl font-bold">
              {showMeme}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
