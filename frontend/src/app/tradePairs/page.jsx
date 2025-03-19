'use client';
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Link from 'next/link'; // Import Link for navigation

// Mock data (replace with API call in production)
const mockPairs = [
  { pair: 'BTC-HV7D/USDT', price: 0.0523, change24h: 2.5, volume: 1250000 },
  { pair: 'BTC-HV30D/USDT', price: 0.0489, change24h: -1.2, volume: 980000 },
  { pair: 'ETH-HV7D/USDT', price: 0.0345, change24h: 3.8, volume: 750000 },
  { pair: 'ETH-HV30D/USDT', price: 0.0312, change24h: 0.9, volume: 620000 },
  { pair: 'XRP-HV7D/USDT', price: 0.0123, change24h: -0.5, volume: 450000 },
  { pair: 'XRP-HV30D/USDT', price: 0.0118, change24h: 1.7, volume: 390000 },
];

export default function VolatilityPairs() {
  const [pairs, setPairs] = useState(mockPairs);
  const [search, setSearch] = useState('');
  const [filters, setFilters] = useState({
    asset: '',
    timePeriod: '',
    baseCurrency: 'USDT',
  });
  const [sortField, setSortField] = useState(null);
  const [sortDirection, setSortDirection] = useState('asc');

  // Filter and sort pairs
  const filteredPairs = pairs
    .filter((pair) => {
      const matchesSearch = pair.pair
        .toLowerCase()
        .includes(search.toLowerCase());
      const matchesAsset = filters.asset
        ? pair.pair.startsWith(filters.asset)
        : true;
      const matchesPeriod = filters.timePeriod
        ? pair.pair.includes(filters.timePeriod)
        : true;
      const matchesBase = pair.pair.endsWith(filters.baseCurrency);
      return matchesSearch && matchesAsset && matchesPeriod && matchesBase;
    })
    .sort((a, b) => {
      if (!sortField) return 0;
      const valueA = a[sortField];
      const valueB = b[sortField];
      return sortDirection === 'asc' ? valueA - valueB : valueB - valueA;
    });

  // Handle sorting
  const handleSort = (field) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  // Simulate real-time update (replace with API/websocket in production)
  const refreshData = () => {
    setPairs((prev) =>
      prev.map((pair) => ({
        ...pair,
        price: pair.price * (1 + (Math.random() - 0.5) * 0.02), // ±2% random change
        change24h: pair.change24h + (Math.random() - 0.5) * 0.5, // ±0.5% random change
      }))
    );
  };

  useEffect(() => {
    const interval = setInterval(refreshData, 10000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen bg-[#121418] text-[#F7EFDE] font-sans p-6">
      {/* Top Section: Search and Filters */}
      <motion.div
        className="max-w-4xl mx-auto mb-8 space-y-6"
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search pairs (e.g., BTC)"
            className="w-full sm:w-1/3 p-3 bg-[#1a1e22] border border-[#503A39] rounded-lg text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors duration-300"
          />
          <motion.button
            onClick={refreshData}
            className="bg-[#3EAFA4] text-[#F7EFDE] px-4 py-2 rounded-lg font-semibold hover:bg-[#E2C19B] transition-colors duration-300"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            transition={{ duration: 0.2 }}
          >
            Create New Pair
          </motion.button>
        </div>

        {/* Filters */}
        <div className="flex flex-wrap gap-4">
          <select
            value={filters.asset}
            onChange={(e) => setFilters({ ...filters, asset: e.target.value })}
            className="p-3 bg-[#1a1e22] border border-[#503A39] rounded-lg text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors duration-300"
          >
            <option value="">All Assets</option>
            <option value="BTC">Bitcoin</option>
            <option value="ETH">Ethereum</option>
            <option value="XRP">Ripple</option>
          </select>

          <select
            value={filters.timePeriod}
            onChange={(e) =>
              setFilters({ ...filters, timePeriod: e.target.value })
            }
            className="p-3 bg-[#1a1e22] border border-[#503A39] rounded-lg text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors duration-300"
          >
            <option value="">All Periods</option>
            <option value="HV7D">7 Days</option>
            <option value="HV30D">30 Days</option>
          </select>

          <select
            value={filters.baseCurrency}
            onChange={(e) =>
              setFilters({ ...filters, baseCurrency: e.target.value })
            }
            className="p-3 bg-[#1a1e22] border border-[#503A39] rounded-lg text-[#F7EFDE] focus:outline-none focus:border-[#3EAFA4] transition-colors duration-300"
          >
            <option value="USDT">USDT</option>
            <option value="USD">USD</option>
          </select>
        </div>
      </motion.div>

      {/* Main Section: Table */}
      <motion.div
        className="max-w-4xl mx-auto bg-[#1a1e22] rounded-xl border border-[#503A39] overflow-hidden"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.5, delay: 0.2 }}
      >
        <table className="w-full text-left">
          <thead>
            <tr className="bg-[#121418]">
              {['pair', 'price', 'change24h', 'volume', 'action'].map(
                (field) => (
                  <th
                    key={field}
                    onClick={
                      field !== 'action' ? () => handleSort(field) : null
                    }
                    className={`p-4 text-[#E2C19B] font-semibold ${
                      field !== 'action'
                        ? 'cursor-pointer hover:text-[#3EAFA4]'
                        : ''
                    } transition-colors duration-200`}
                  >
                    {field === 'pair'
                      ? 'Pair Name'
                      : field === 'change24h'
                      ? '24h Change'
                      : field === 'action'
                      ? 'Action'
                      : field.charAt(0).toUpperCase() + field.slice(1)}
                    {sortField === field && field !== 'action' && (
                      <span className="ml-1">
                        {sortDirection === 'asc' ? '↑' : '↓'}
                      </span>
                    )}
                  </th>
                )
              )}
            </tr>
          </thead>
          <tbody>
            <AnimatePresence>
              {filteredPairs.length > 0 ? (
                filteredPairs.map((pair, index) => (
                  <motion.tr
                    key={pair.pair}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -20 }}
                    transition={{ duration: 0.3, delay: index * 0.05 }}
                    className="border-t border-[#503A39] hover:bg-[#252a2f] transition-colors duration-200"
                  >
                    <td className="p-4">{pair.pair}</td>
                    <td className="p-4">{pair.price.toFixed(4)}</td>
                    <td
                      className={`p-4 ${
                        pair.change24h >= 0
                          ? 'text-[#3EAFA4]'
                          : 'text-[#E2C19B]'
                      }`}
                    >
                      {pair.change24h.toFixed(1)}%
                    </td>
                    <td className="p-4">{(pair.volume / 1000).toFixed(0)}K</td>
                    <td className="p-4">
                      <Link href={`/trade/${pair.pair}`}>
                        <motion.button
                          className="bg-[#3EAFA4] text-[#F7EFDE] px-4 py-2 rounded-lg font-semibold hover:bg-[#E2C19B] transition-colors duration-300"
                          whileHover={{ scale: 1.05 }}
                          whileTap={{ scale: 0.95 }}
                          transition={{ duration: 0.2 }}
                        >
                          Trade Now
                        </motion.button>
                      </Link>
                    </td>
                  </motion.tr>
                ))
              ) : (
                <motion.tr
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.3 }}
                >
                  <td colSpan="5" className="p-4 text-center text-[#E2C19B]">
                    No pairs found
                  </td>
                </motion.tr>
              )}
            </AnimatePresence>
          </tbody>
        </table>
      </motion.div>
    </div>
  );
}
