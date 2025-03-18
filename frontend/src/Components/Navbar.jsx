'use client';
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

export default function Navbar() {
  const [walletAddress, setWalletAddress] = useState(null);
  const [balance, setBalance] = useState(null);
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);

  // Connect to MetaMask
  const connectWallet = async () => {
    if (typeof window.ethereum !== 'undefined') {
      try {
        const accounts = await window.ethereum.request({
          method: 'eth_requestAccounts',
        });
        setWalletAddress(accounts[0]);
        fetchBalance(accounts[0]);
      } catch (error) {
        console.error('Failed to connect wallet:', error);
        alert(
          'Failed to connect. Please ensure MetaMask is installed and unlocked.'
        );
      }
    } else {
      alert('Please install MetaMask to connect your wallet.');
    }
  };

  // Disconnect wallet
  const disconnectWallet = () => {
    setWalletAddress(null);
    setBalance(null);
    setIsDropdownOpen(false); // Close dropdown on disconnect
  };

  // Fetch wallet balance
  const fetchBalance = async (address) => {
    if (typeof window.ethereum !== 'undefined') {
      try {
        const balanceWei = await window.ethereum.request({
          method: 'eth_getBalance',
          params: [address, 'latest'],
        });
        const balanceEth = parseFloat((parseInt(balanceWei) / 1e18).toFixed(4));
        setBalance(balanceEth);
      } catch (error) {
        console.error('Failed to fetch balance:', error);
        setBalance('Error');
      }
    }
  };

  // Check if wallet is already connected and fetch balance on load
  useEffect(() => {
    if (typeof window.ethereum !== 'undefined') {
      window.ethereum.request({ method: 'eth_accounts' }).then((accounts) => {
        if (accounts.length > 0) {
          setWalletAddress(accounts[0]);
          fetchBalance(accounts[0]);
        }
      });

      // Listen for account changes
      window.ethereum.on('accountsChanged', (accounts) => {
        if (accounts.length > 0) {
          setWalletAddress(accounts[0]);
          fetchBalance(accounts[0]);
        } else {
          setWalletAddress(null);
          setBalance(null);
          setIsDropdownOpen(false);
        }
      });
    }
  }, []);

  return (
    <motion.header
      className="p-4 flex items-center justify-between border-b border-[#CCFF00] bg-black relative z-20"
      initial={{ y: -50, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5 }}
    >
      {/* Left: Vix.dex Logo */}
      <motion.h1
        className="text-3xl font-['Playfair_Display'] text-[#CCFF00]"
        whileHover={{ scale: 1.05 }}
        transition={{ duration: 0.2 }}
      >
        Vix.dex
      </motion.h1>

      {/* Right: Wallet Controls */}
      <div className="relative flex items-center space-x-4">
        {walletAddress ? (
          <motion.div
            className="text-[#CCFF00] cursor-pointer"
            onClick={() => setIsDropdownOpen(!isDropdownOpen)}
            whileHover={{ scale: 1.05 }}
            transition={{ duration: 0.2 }}
          >
            <span className="text-l bg-[#1a1a1a] px-3 py-1 rounded-full border border-[#CCFF00] shadow-[0_0_5px_rgba(204,255,0,0.3)]">
              {`${walletAddress.slice(0, 9)}...${walletAddress.slice(-4)}`}
            </span>

            {/* Dropdown */}
            <AnimatePresence>
              {isDropdownOpen && (
                <motion.div
                  className="absolute right-0 mt-2 w-48 bg-[#1a1a1a] border border-[#CCFF00] rounded-lg shadow-[0_0_15px_rgba(204,255,0,0.5)] p-4 z-30"
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  transition={{ duration: 0.3 }}
                >
                  {/* Balance */}
                  <div className="text-sm text-white mb-3">
                    <span className="block font-bold text-[#CCFF00]">
                      Balance:
                    </span>
                    <span>
                      {balance !== null ? `${balance} ETH` : 'Loading...'}
                    </span>
                  </div>

                  {/* Disconnect Button */}
                  <motion.button
                    className="w-full bg-[#CCFF00] text-black border-2 border-white rounded-full px-3 py-1 font-bold cursor-pointer shadow-[0_0_10px_rgba(204,255,0,0.5)] hover:shadow-[0_0_15px_#CCFF00] transition-shadow duration-300"
                    onClick={disconnectWallet}
                    whileHover={{ scale: 1.05, boxShadow: '0 0 15px #CCFF00' }}
                    whileTap={{ scale: 0.95 }}
                    transition={{ duration: 0.2 }}
                  >
                    Disconnect
                  </motion.button>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        ) : (
          /* Connect Wallet Button */
          <motion.button
            className="bg-[#CCFF00] text-black border-2 border-white rounded-full px-4 py-2 font-bold cursor-pointer shadow-[0_0_10px_rgba(204,255,0,0.5)] hover:shadow-[0_0_15px_#CCFF00] transition-shadow duration-300"
            onClick={connectWallet}
            whileHover={{ scale: 1.1, boxShadow: '0 0 15px #CCFF00' }}
            whileTap={{ scale: 0.95 }}
            transition={{ duration: 0.3 }}
          >
            Connect Wallet
          </motion.button>
        )}
      </div>
    </motion.header>
  );
}
