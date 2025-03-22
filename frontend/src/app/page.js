'use client';
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

import BuySell from '../components/BuySell';
import Transactions from '../components/Transactions';
import Chart from '@/Components/Chart';

// Mock data
const mockPairs = [
  { pair: 'BTC-VOL/USDT', price: 0.0523 },
  { pair: 'ETH-VOL/USDT', price: 0.0345 },
  { pair: 'XRP-VOL/USDT', price: 0.0123 },
];

const initialChartData = Array.from({ length: 60 }, (_, i) => ({
  time: Math.floor(Date.now() / 1000) - (60 - i) * 60,
  value: 0.05 + Math.random() * 0.01,
}));

const mockTransactions = [
  {
    id: 1,
    pair: 'BTC-VOL/USDT',
    type: 'buy',
    amount: 10,
    price: 0.052,
    time: '2025-03-19 10:00',
  },
  {
    id: 2,
    pair: 'ETH-VOL/USDT',
    type: 'sell',
    amount: 5,
    price: 0.035,
    time: '2025-03-19 10:05',
  },
];

export default function TradingPlatform() {
  const [selectedPair, setSelectedPair] = useState(mockPairs[0].pair);
  const [orderType, setOrderType] = useState('market');
  const [quantity, setQuantity] = useState('');
  const [price, setPrice] = useState('');
  const [chartTimeFrame, setChartTimeFrame] = useState('1m');
  const [activeTab, setActiveTab] = useState('market');
  const [pairs, setPairs] = useState(mockPairs);
  const [balance, setBalance] = useState(1000);
  const [showWarning, setShowWarning] = useState(null);
  const [transactions, setTransactions] = useState(mockTransactions);
  const [chartData, setChartData] = useState(initialChartData);
  const [messages, setMessages] = useState([
    { id: 1, user: 'Trader1', message: 'Bullish on BTC-VOL!', time: '10:00' },
    { id: 2, user: 'Trader2', message: 'Selling ETH-VOL now.', time: '10:02' },
  ]);
  const [newMessage, setNewMessage] = useState('');
  const [chatOpen, setChatOpen] = useState(true);

  useEffect(() => {
    const interval = setInterval(() => {
      setPairs((prev) =>
        prev.map((p) => ({
          ...p,
          price: p.price * (1 + (Math.random() - 0.5) * 0.02),
        }))
      );
      const currentPrice = pairs.find((p) => p.pair === selectedPair).price;
      setChartData((prev) => [
        ...prev.slice(-59),
        { time: Math.floor(Date.now() / 1000), value: currentPrice },
      ]);
    }, 5000);
    return () => clearInterval(interval);
  }, [pairs, selectedPair]);

  const handleTrade = (action) => {
    if (!quantity || (orderType === 'limit' && !price)) {
      alert('Please enter quantity and price (for limit orders).');
      return;
    }
    const currentPrice = pairs.find((p) => p.pair === selectedPair).price;
    const tradeAmount =
      orderType === 'market'
        ? quantity * currentPrice
        : quantity * parseFloat(price);
    const slippage =
      orderType === 'market'
        ? Math.random() * 2
        : Math.abs((currentPrice - price) / currentPrice) * 100;
    const priceImpact = (quantity * currentPrice) / 10000;
    if (slippage > 1 || priceImpact > 2) {
      setShowWarning({
        action,
        slippage: slippage.toFixed(2),
        priceImpact: priceImpact.toFixed(2),
        tradeAmount,
      });
      return;
    }
    executeTrade(action, tradeAmount);
  };

  const executeTrade = (action, tradeAmount) => {
    setBalance((prev) =>
      action === 'buy' ? prev - tradeAmount : prev + tradeAmount
    );
    const currentPrice = pairs.find((p) => p.pair === selectedPair).price;
    setTransactions((prev) => [
      ...prev,
      {
        id: prev.length + 1,
        pair: selectedPair,
        type: action,
        amount: parseFloat(quantity),
        price: currentPrice,
        time: new Date().toISOString().slice(0, 16).replace('T', ' '),
      },
    ]);
    setChartData((prev) => [
      ...prev.slice(-59),
      { time: Math.floor(Date.now() / 1000), value: currentPrice },
    ]);
    setQuantity('');
    setPrice('');
    setShowWarning(null);
  };

  const handleSendMessage = () => {
    if (!newMessage.trim()) return;
    setMessages([
      ...messages,
      {
        id: messages.length + 1,
        user: 'You',
        message: newMessage,
        time: new Date().toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit',
        }),
      },
    ]);
    setNewMessage('');
  };

  return (
    <div className="flex flex-col h-screen bg-[#121418] text-[#F7EFDE] font-sans px-20 py-6">
      {/* Top Section: Chart + Buy/Sell (2/3) */}
      <div className="h-2/3 flex my-4">
        <Chart
          selectedPair={selectedPair}
          chartTimeFrame={chartTimeFrame}
          setChartTimeFrame={setChartTimeFrame}
          chartData={chartData}
        />
        <BuySell
          selectedPair={selectedPair}
          setSelectedPair={setSelectedPair}
          orderType={orderType}
          setOrderType={setOrderType}
          quantity={quantity}
          setQuantity={setQuantity}
          price={price}
          setPrice={setPrice}
          pairs={pairs}
          balance={balance}
          handleTrade={handleTrade}
        />
      </div>

      {/* Bottom Section: Transactions */}
      <Transactions
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        transactions={transactions}
        selectedPair={selectedPair}
      />

      {/* Warning Overlay */}
      <AnimatePresence>
        {showWarning && (
          <motion.div
            className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50 z-50"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <div className="bg-[#252a2f] p-6 rounded-lg text-[#F7EFDE]">
              <p className="text-[#E2C19B] font-semibold mb-2">Trade Warning</p>
              <p>Slippage: {showWarning.slippage}%</p>
              <p>Price Impact: {showWarning.priceImpact}%</p>
              <p>Cost: {showWarning.tradeAmount.toFixed(2)} USDT</p>
              <div className="flex space-x-2 mt-4">
                <motion.button
                  onClick={() =>
                    executeTrade(showWarning.action, showWarning.tradeAmount)
                  }
                  className="bg-[#3EAFA4] p-2 rounded hover:bg-[#E2C19B]"
                  whileHover={{ scale: 1.05 }}
                >
                  Confirm
                </motion.button>
                <motion.button
                  onClick={() => setShowWarning(null)}
                  className="bg-[#E2C19B] text-[#121418] p-2 rounded hover:bg-[#3EAFA4] hover:text-[#F7EFDE]"
                  whileHover={{ scale: 1.05 }}
                >
                  Cancel
                </motion.button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Dummy Chat Box with Close Button */}
      {chatOpen ? (
        <motion.div
          className="fixed bottom-4 right-4 w-80 bg-[#1a1e22] rounded-xl border border-[#503A39] shadow-lg overflow-hidden"
          initial={{ opacity: 0, y: 50 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          <div className="bg-[#121418] p-3 text-[#E2C19B] font-semibold flex justify-between items-center">
            <span>Community Chat</span>
            <motion.button
              onClick={() => setChatOpen(false)}
              className="bg-[#E2C19B] text-[#121418] w-6 h-6 rounded-full flex items-center justify-center hover:bg-[#3EAFA4] hover:text-[#F7EFDE] transition-colors duration-300"
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.9 }}
            >
              ×
            </motion.button>
          </div>
          <div className="h-64 bg-[#121418] p-3 overflow-auto">
            {messages.map((msg) => (
              <motion.div
                key={msg.id}
                className="mb-2"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.3 }}
              >
                <p className="text-[#F7EFDE] text-sm">
                  <span className="text-[#3EAFA4] font-semibold">
                    {msg.user}
                  </span>{' '}
                  ({msg.time}): {msg.message}
                </p>
              </motion.div>
            ))}
          </div>
          <div className="p-3 bg-[#1a1e22] border-t border-[#503A39]">
            <div className="flex space-x-2">
              <input
                type="text"
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                placeholder="Type a message..."
                className="flex-1 p-2 bg-[#121418] border border-[#503A39] rounded text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4]"
              />
              <motion.button
                onClick={handleSendMessage}
                className="bg-[#3EAFA4] text-[#F7EFDE] px-4 py-2 rounded font-semibold hover:bg-[#E2C19B] transition-colors duration-300"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                Send
              </motion.button>
            </div>
          </div>
        </motion.div>
      ) : (
        <motion.button
          onClick={() => setChatOpen(true)}
          className="fixed bottom-4 right-4 bg-[#3EAFA4] text-[#F7EFDE] px-4 py-2 rounded-full font-semibold hover:bg-[#E2C19B] transition-colors duration-300"
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.3 }}
        >
          Open Chat
        </motion.button>
      )}
    </div>
  );
}
