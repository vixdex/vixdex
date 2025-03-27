'use client';
import { useState } from 'react';
import { motion } from 'framer-motion';

const mockMessages = [
  { id: 1, user: 'Trader1', message: 'Bullish on BTC-VOL!', time: '10:00' },
  { id: 2, user: 'Trader2', message: 'Selling ETH-VOL now.', time: '10:02' },
];

const ChatBox = () => {
  const [messages, setMessages] = useState(mockMessages);
  const [newMessage, setNewMessage] = useState('');
  const [isOpen, setIsOpen] = useState(true);

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

  if (!isOpen) {
    return (
      <motion.button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-4 right-4 bg-[#3EAFA4] text-[#F7EFDE] px-4 py-2 rounded-full font-semibold hover:bg-[#E2C19B] transition-colors duration-300"
        initial={{ opacity: 0, scale: 0.8 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.3 }}
      >
        Open Chat
      </motion.button>
    );
  }

  return (
    <motion.div
      className="fixed bottom-4 right-4 w-80 bg-[#1a1e22] rounded-xl border border-[#503A39] shadow-lg overflow-hidden"
      initial={{ opacity: 0, y: 50 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      {/* Chat Header with Close Button */}
      <div className="bg-[#121418] p-3 text-[#E2C19B] font-semibold flex justify-between items-center">
        <span>Community Chat</span>
        <motion.button
          onClick={() => setIsOpen(false)}
          className="bg-[#E2C19B] text-[#121418] w-6 h-6 rounded-full flex items-center justify-center hover:bg-[#3EAFA4] hover:text-[#F7EFDE] transition-colors duration-300"
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.9 }}
        >
          ×
        </motion.button>
      </div>

      {/* Chat Messages */}
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
              <span className="text-[#3EAFA4] font-semibold">{msg.user}</span> (
              {msg.time}): {msg.message}
            </p>
          </motion.div>
        ))}
      </div>

      {/* Message Input */}
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
  );
};

export default ChatBox;
