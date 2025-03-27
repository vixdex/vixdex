# Vixdex

VixDex - Decentralized Volatility Trading Protocol

## About this Project
VixDex is a decentralized volatility trading protocol. It is a Uniswap V4 hook that introduces a custom pricing model for trading directly on volatility on-chain. VixDex allows traders to take positions on whether an asset’s volatility will increase or decrease, similar to VIX options trading but in a fully decentralized and automated manner.
## How it Works
Traders can buy:

HIGH-IV Tokens → Value increases when IV is high.

LOW-IV Tokens → Value increases when IV is low.

Positions expire in 24H or 7D, and at the end of each cycle, new tokens are minted.

Price is mostly influenced by IV, with minor adjustments from supply and demand.

HIGH-IV and LOW-IV tokens are inversely correlated—when one increases, the other decreases.


## 🛠️ Key Features

✅ No Liquidity Providers (LPs) Needed – The contract itself manages token issuance and pricing.

✅ Uniswap V3 Integration – The contract retrieves data from Uniswap V3, performs IV-related calculations, and executes trades fully on-chain.

✅ Customizable Pricing Curve – The mechanism determining token prices may evolve to optimize efficiency.

✅ Automated Market Reset – Every 24H/7D, positions expire, and new IV tokens are issued.

✅ Fully On-Chain & Decentralized – Built on Ethereum & Uniswap V4 hooks.

## ⚙️ Design

   The Uniswap V4 hook is deployed as a No-Op hook that overrides specific permissions on the Uniswap V4 pool manager. The following hooks are overridden:

   `beforeAddLiquidity`

   `beforeSwap`

   `afterSwap`

   `beforeSwapReturnDelta`


## Limitations of the VixDex Volatility Trading Protocol

🔹 🚧 Proof of Concept Stage: VixDex is currently a proof of concept, introducing how volatility trading can be done directly in DeFi. This lays the foundation for a fully optimized version.

🔹 ⛽ High Gas Fees: The protocol's on-chain computations result in higher gas costs. Future optimizations using math libraries, bitwise operations, or assembly coding can improve efficiency.

🔹 📈 Static Price Curve Slope: The pricing mechanism relies on a fixed slope, which may limit flexibility. A dynamic curve could enhance adaptability and efficiency.

🔹 🔄 Static Reserve Swap Mechanism: The reserve swap mechanism, tied to the pricing curve, remains in static slope as 3% (0.03). While it helps VPT (Vix Pair Tokens) pricing react to IV changes.

🔹 📝 Function Naming: Some function names could be more intuitive and structured for better clarity and developer experience.

🔹 🧮 On-Chain Math Complexity: The protocol relies on heavy mathematical computations on-chain. However, this can be optimized using Solidity math libraries, bitwise operations, or assembly for better performance.

🔹 💰 Base Token Decimal Constraint: The base token must be 18 decimals, allowing WETH but excluding USDC & USDT. Expanding support for different decimals can improve usability.

🔹 ⚡ No Native Coin Support: The protocol does not yet support ETH as a base token, limiting direct native coin transactions.

🔹 📊 Volume Calculation Limitation: Currently, volume data is fetched from The Graph, but not all trading pairs have an indexer. A universal volume-tracking mechanism can address this gap.

💡 The good news? All these challenges are solvable! Fixing them will make VixDex an super-efficient 

## ⚠️ Disclaimer

VixDex is currently under development, and its implementation is subject to change. While the core concept and goal of enabling decentralized volatility trading will remain the same, various aspects such as pricing mechanisms, token handling, and market dynamics may evolve as the project progresses.


Stay tuned for updates as we build and refine VixDex! 