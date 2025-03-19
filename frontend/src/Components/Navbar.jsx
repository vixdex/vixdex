'use client';
import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Link from 'next/link'; // Import Next.js Link component

export default function Navbar() {
  const [walletAddress, setWalletAddress] = useState(null);
  const [balance, setBalance] = useState(null);
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);

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

  const disconnectWallet = () => {
    setWalletAddress(null);
    setBalance(null);
    setIsDropdownOpen(false);
  };

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

  useEffect(() => {
    if (typeof window.ethereum !== 'undefined') {
      window.ethereum.request({ method: 'eth_accounts' }).then((accounts) => {
        if (accounts.length > 0) {
          setWalletAddress(accounts[0]);
          fetchBalance(accounts[0]);
        }
      });

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
      className="p-6 sm:px-20 flex items-center justify-between bg-[#121418]"
      initial={{ y: -50, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5 }}
    >
      {/* Logo */}
      <motion.h1
        className="text-2xl font-sans text-[#F7EFDE] font-bold tracking-wide"
        whileHover={{ scale: 1.05 }}
        transition={{ duration: 0.2 }}
      >
        Vix
        <span className="text-[#E2C19B] font-bold">.dex</span>
      </motion.h1>

      {/* Navigation Links */}
      <nav className="flex space-x-8">
        <Link href="/tradePairs">
          <motion.span
            className="text-[#F7EFDE] font-semibold hover:text-[#3EAFA4] transition-colors duration-300"
            whileHover={{ scale: 1.05 }}
            transition={{ duration: 0.2 }}
          >
            Trade
          </motion.span>
        </Link>
        <Link href="/create">
          <motion.span
            className="text-[#F7EFDE] font-semibold hover:text-[#3EAFA4] transition-colors duration-300"
            whileHover={{ scale: 1.05 }}
            transition={{ duration: 0.2 }}
          >
            Create Volatility
          </motion.span>
        </Link>
        <Link href="/contact">
          <motion.span
            className="text-[#F7EFDE] font-semibold hover:text-[#3EAFA4] transition-colors duration-300"
            whileHover={{ scale: 1.05 }}
            transition={{ duration: 0.2 }}
          >
            Contact
          </motion.span>
        </Link>
      </nav>

      {/* Wallet Controls */}
      <div className="relative flex items-center">
        {walletAddress ? (
          <motion.div
            className="text-[#F7EFDE] cursor-pointer"
            onClick={() => setIsDropdownOpen((prev) => !prev)}
            transition={{ duration: 0.2 }}
          >
            <span className="text-lg px-4 py-2 rounded-lg border border-[#503A39] bg-[#1a1e22]">
              {`${walletAddress.slice(0, 9)}...${walletAddress.slice(-4)}`}
            </span>

            {/* Dropdown */}
            <AnimatePresence>
              {isDropdownOpen && (
                <motion.div
                  className="absolute right-0 mt-3 w-56 bg-[#1a1e22] border border-[#503A39] rounded-xl p-4 shadow-lg z-50"
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  transition={{ duration: 0.3 }}
                  onClick={(e) => e.stopPropagation()}
                >
                  <div className="text-sm text-[#F7EFDE] mb-4">
                    <span className="block font-semibold text-[#E2C19B]">
                      Balance:
                    </span>
                    <span>
                      {balance !== null ? `${balance} ETH` : 'Loading...'}
                    </span>
                  </div>

                  <motion.button
                    className="w-full bg-[#3EAFA4] text-[#F7EFDE] rounded-lg px-4 py-2 font-semibold hover:bg-[#E2C19B] transition-colors duration-300"
                    onClick={disconnectWallet}
                    whileHover={{ scale: 1.05 }}
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
          <motion.button
            className="bg-[#3EAFA4] text-[#F7EFDE] border border-[#503A39] rounded-lg px-6 py-2 font-semibold hover:bg-[#E2C19B] transition-colors duration-300"
            onClick={connectWallet}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            transition={{ duration: 0.2 }}
          >
            Connect Wallet
          </motion.button>
        )}
      </div>
    </motion.header>
  );
}
