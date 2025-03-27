'use client';
import { motion, AnimatePresence } from 'framer-motion';

const Transactions = ({
  activeTab,
  setActiveTab,
  transactions,
  selectedPair,
}) => {
  return (
    <motion.div
      className="h-1/3 bg-[#1a1e22] p-4 "
      initial={{ y: 50, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5 }}
    >
      <div className="flex space-x-4 mb-4">
        {['market', 'myTrades'].map((tab) => (
          <motion.button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 rounded ${
              activeTab === tab
                ? 'bg-[#3EAFA4]'
                : 'bg-[#252a2f] hover:bg-[#E2C19B]'
            }`}
            whileHover={{ scale: 1.05 }}
          >
            {tab === 'market' ? 'Market Transactions' : 'My Trades'}
          </motion.button>
        ))}
      </div>
      <div className="h-[70%]  rounded-lg p-2 overflow-auto">
        {activeTab === 'market' && (
          <div className="max-w-full mx-auto bg-[#1a1e22] rounded-xl border border-[#503A39] overflow-hidden">
            <table className="w-full text-left">
              <thead>
                <tr className="bg-[#121418]">
                  {['time', 'type', 'amount', 'price'].map((field) => (
                    <th
                      key={field}
                      className="p-3 text-[#E2C19B] font-semibold cursor-pointer hover:text-[#3EAFA4] transition-colors duration-200"
                    >
                      {field === 'time'
                        ? 'Time'
                        : field === 'type'
                        ? 'Type'
                        : field === 'amount'
                        ? 'Amount'
                        : 'Price'}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                <AnimatePresence>
                  {transactions.filter((t) => t.pair === selectedPair).length >
                  0 ? (
                    transactions
                      .filter((t) => t.pair === selectedPair)
                      .map((t, index) => (
                        <motion.tr
                          key={t.id}
                          initial={{ opacity: 0, y: 20 }}
                          animate={{ opacity: 1, y: 0 }}
                          exit={{ opacity: 0, y: -20 }}
                          transition={{ duration: 0.3, delay: index * 0.05 }}
                          className="border-t border-[#503A39] hover:bg-[#252a2f] transition-colors duration-200"
                        >
                          <td className="p-3 text-[#F7EFDE]">{t.time}</td>
                          <td
                            className={`p-3 ${
                              t.type === 'buy'
                                ? 'text-[#3EAFA4]'
                                : 'text-[#E2C19B]'
                            }`}
                          >
                            {t.type.toUpperCase()}
                          </td>
                          <td className="p-3 text-[#F7EFDE]">{t.amount}</td>
                          <td className="p-3 text-[#F7EFDE]">
                            {t.price.toFixed(4)}
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
                      <td
                        colSpan={4}
                        className="p-3 text-center text-[#E2C19B]"
                      >
                        No transactions for {selectedPair}
                      </td>
                    </motion.tr>
                  )}
                </AnimatePresence>
              </tbody>
            </table>
          </div>
        )}
        {activeTab === 'myTrades' && (
          <div className="max-w-full mx-auto bg-[#1a1e22] rounded-xl border border-[#503A39] overflow-hidden">
            <table className="w-full text-left">
              <thead>
                <tr className="bg-[#121418]">
                  {['time', 'pair', 'type', 'amount', 'price'].map((field) => (
                    <th
                      key={field}
                      className="p-3 text-[#E2C19B] font-semibold cursor-pointer hover:text-[#3EAFA4] transition-colors duration-200"
                    >
                      {field === 'time'
                        ? 'Time'
                        : field === 'pair'
                        ? 'Pair'
                        : field === 'type'
                        ? 'Type'
                        : field === 'amount'
                        ? 'Amount'
                        : 'Price'}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                <AnimatePresence>
                  {transactions.length > 0 ? (
                    transactions.map((t, index) => (
                      <motion.tr
                        key={t.id}
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        transition={{ duration: 0.3, delay: index * 0.05 }}
                        className="border-t border-[#503A39] hover:bg-[#252a2f] transition-colors duration-200"
                      >
                        <td className="p-3 text-[#F7EFDE]">{t.time}</td>
                        <td className="p-3 text-[#F7EFDE]">{t.pair}</td>
                        <td
                          className={`p-3 ${
                            t.type === 'buy'
                              ? 'text-[#3EAFA4]'
                              : 'text-[#E2C19B]'
                          }`}
                        >
                          {t.type.toUpperCase()}
                        </td>
                        <td className="p-3 text-[#F7EFDE]">{t.amount}</td>
                        <td className="p-3 text-[#F7EFDE]">
                          {t.price.toFixed(4)}
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
                      <td
                        colSpan={5}
                        className="p-3 text-center text-[#E2C19B]"
                      >
                        No transaction history
                      </td>
                    </motion.tr>
                  )}
                </AnimatePresence>
              </tbody>
            </table>
          </div>
        )}
      </div>
    </motion.div>
  );
};

export default Transactions;
