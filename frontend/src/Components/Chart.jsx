'use client';
import { motion } from 'framer-motion';
import { useEffect, useRef, useState } from 'react';

const Chart = ({
  selectedPair,
  chartTimeFrame,
  setChartTimeFrame,
  chartData, // Not used here, but kept for potential future use
}) => {
  const chartContainerRef = useRef(null);
  const widgetRef = useRef(null);
  const [activeTab, setActiveTab] = useState('high'); // 'high' or 'low'

  useEffect(() => {
    // Cleanup previous widget instance if it exists
    if (widgetRef.current) {
      widgetRef.current.remove();
    }

    // Create the TradingView widget
    const script = document.createElement('script');
    script.src = 'https://s3.tradingview.com/tv.js';
    script.async = true;
    script.onload = () => {
      widgetRef.current = new window.TradingView.widget({
        width: '100%',
        height: '100%',
        symbol: 'BTCUSD', // Use selectedPair, default to BTCUSD if not provided.... selectedPair ||
        interval:
          chartTimeFrame === '1m' ? '1' : chartTimeFrame === '5m' ? '5' : '60', // Map to TradingView intervals
        timezone: 'Etc/UTC',
        theme: 'dark',
        style: '1', // Candlestick chart
        locale: 'en',
        toolbar_bg: '#1a1e22',
        enable_publishing: false,
        allow_symbol_change: true,
        container_id: 'tradingview_chart',
      });
    };
    document.body.appendChild(script);

    // Cleanup on unmount
    return () => {
      if (widgetRef.current) {
        widgetRef.current.remove();
      }
      document.body.removeChild(script);
    };
  }, [selectedPair, chartTimeFrame]); // Re-render chart when pair or timeframe changes

  return (
    <motion.div
      className="w-[70%] bg-[#1a1e22] mr-4 h-full p-4 flex flex-col"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
    >
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-[#E2C19B] text-lg font-semibold">{selectedPair}</h2>
        <div className="flex space-x-2">
          <motion.button
            onClick={() => setActiveTab('high')}
            className={`px-4 py-2 rounded font-semibold ${
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
            className={`px-4 py-2 rounded font-semibold ${
              activeTab === 'low'
                ? 'bg-[#3EAFA4] text-[#F7EFDE]'
                : 'bg-[#252a2f] text-[#E2C19B] hover:bg-[#E2C19B] hover:text-[#121418]'
            }`}
            whileHover={{ scale: 1.05 }}
          >
            Low
          </motion.button>
        </div>
      </div>

      {/* Chart Container */}
      <div
        id="tradingview_chart"
        ref={chartContainerRef}
        className="h-[80%] rounded-lg flex-grow "
      />
      <p className="text-sm text-[#E2C19B] mt-2">
        Viewing {activeTab === 'high' ? 'High' : 'Low'} context for{' '}
        {selectedPair}
      </p>
    </motion.div>
  );
};

export default Chart;
