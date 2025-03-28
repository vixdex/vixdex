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
  return <div>Hello Vix.dex</div>;
}
