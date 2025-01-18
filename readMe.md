# DeFiDuality

**DeFiDuality** is a decentralized finance (DeFi) protocol designed to facilitate staking, lending, borrowing, and token rewards. The protocol supports two main tokens: **USDC** and **WBTC**, offering users the ability to stake assets, earn rewards, and perform collateralized lending and borrowing seamlessly.

## Features

### 1. **Staking**
- Users can stake **USDC** and **WBTC** to earn liquidity provider tokens (**LPUSDC** and **LPWBTC**).
- Staked tokens contribute to the protocol’s liquidity pool.

### 2. **Lending and Borrowing**
- Borrow **USDC** by collateralizing **WBTC**, and vice versa.
- Ensure sufficient collateral to avoid liquidation.
- Real-time conversion rates and collateral ratio checks.

### 3. **Rewards System**
- Earn **LPR** tokens as rewards for staking, borrowing, or swapping tokens.
- Reward calculation is time-based and proportional to the amount staked.

### 4. **Swapping**
- Swap **WBTC** for **USDC**, or **USDC** for **WBTC** within the protocol.
- Automatically adjusts pool balances and mints tokens if necessary.

### 5. **Transparency**
- Users can query pool balances, staked amounts, borrowed tokens, and rewards earned.
- Event-driven updates for all major actions.

## Technical Overview

### Contract Components
- **LendingPool:** Core structure managing liquidity, staking, borrowing, and rewards.
- **TreasuryCaps:** Control minting and burning of tokens securely.
- **Clock Integration:** Time-based reward calculations for staking.

### Key Functions
- **`stake_wbtc` and `stake_usdc`:** Stake tokens and receive liquidity tokens.
- **`borrow_usdc` and `borrow_wbtc`:** Borrow tokens by providing sufficient collateral.
- **`repay_usdc` and `repay_wbtc`:** Repay borrowed tokens and reclaim collateral.
- **`claim_rewards`:** Claim accrued rewards in **LPR** tokens.
- **`send_usdc_receive_wbtc` and `send_wbtc_receive_usdc`:** Swap tokens within the protocol.

### Safety Features
- Ensures collateral requirements are met before borrowing.
- Validates pool balances and mints tokens as needed.
- Emits events for transparency on staking, borrowing, and rewards.

## Installation and Deployment

1. Clone the repository:
   ```bash
   git clone https://github.com/rocknwa/DeFiDuality
   cd DeFiDuality
   ```

2. Install dependencies (specific to the blockchain environment, e.g., Sui or Ethereum):
   ```bash
   sui move build
   ```

3. Deploy the contracts:
   ```bash
   sui move publish --path .
   ```

4. Initialize the LendingPool:
   - Ensure **TreasuryCaps** for tokens are set.
   - Use the `create_pool` function to deploy the LendingPool instance.

## Usage

### Staking Example
```move
stake_wbtc(pool, clock, wbtc_coin, ctx);
```

### Borrowing Example
```move
borrow_usdc(pool, usdc_amount, ctx);
```

### Rewards Example
```move
claim_rewards(pool, clock, ctx);
```

### Swap Example
```move
send_usdc_receive_wbtc(pool, recipient, usdc_amount, ctx);
```

## Contribution

We welcome contributions to **DeFiDuality**. To get started:

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Commit your changes and submit a pull request.

 

**DeFiDuality** — Empowering decentralized finance with dual-token functionality and seamless user experience.

**