 module dex::dex {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::event::{Self, emit};

    // Struct to track staking data
    public struct StakingAccount has key, store {
        id: UID,
        staked_weth: Balance<WETH>,
        staked_usdc: Balance<USDC>,
        last_reward_time: u64,
    }

    // Reward distribution rate constants
    const REWARD_RATE_WETH: u64 = 10; // Reward per WETH per time unit
    const REWARD_RATE_USDC: u64 = 5;  // Reward per USDC per time unit

    /// Stake WETH tokens
    public fun stake_weth(
        account: &mut StakingAccount,
        weth_coin: Coin<WETH>,
        ctx: &mut TxContext
    ) {
        balance::join(&mut account.staked_weth, coin::into_balance(weth_coin));
        account.last_reward_time = clock::now(ctx);

        emit(DepositEvent {
            message: b"WETH staked successfully.",
        });
    }

    /// Stake USDC tokens
    public fun stake_usdc(
        account: &mut StakingAccount,
        usdc_coin: Coin<USDC>,
        ctx: &mut TxContext
    ) {
        balance::join(&mut account.staked_usdc, coin::into_balance(usdc_coin));
        account.last_reward_time = clock::now(ctx);

        emit(DepositEvent {
            message: b"USDC staked successfully.",
        });
    }

    /// Claim staking rewards
    public fun claim_rewards(
        account: &mut StakingAccount,
        pool: &mut LendingPool,
        ctx: &mut TxContext
    ) {
        let current_time = clock::now(ctx);
        let time_elapsed = current_time - account.last_reward_time;

        // Calculate rewards for WETH and USDC
        let weth_rewards = balance::value(&account.staked_weth) * REWARD_RATE_WETH * time_elapsed;
        let usdc_rewards = balance::value(&account.staked_usdc) * REWARD_RATE_USDC * time_elapsed;

        // Mint DEX tokens as rewards
        let total_rewards = weth_rewards + usdc_rewards;
        let reward_coin = coin::mint(&mut pool.treasury_cap_dex, total_rewards, ctx);

        // Transfer rewards to the user
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(reward_coin, sender);

        // Update the last reward time
        account.last_reward_time = current_time;

        emit(RewardEvent {
            message: b"Rewards claimed successfully.",
        });
    }

    /// Unstake WETH tokens
    public fun unstake_weth(
        account: &mut StakingAccount,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let unstaked_coin = coin::take(&mut account.staked_weth, amount, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(unstaked_coin, sender);

        emit(WithdrawalEvent {
            message: b"WETH unstaked successfully.",
        });
    }

    /// Unstake USDC tokens
    public fun unstake_usdc(
        account: &mut StakingAccount,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let unstaked_coin = coin::take(&mut account.staked_usdc, amount, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(unstaked_coin, sender);

        emit(WithdrawalEvent {
            message: b"USDC unstaked successfully.",
        });
    }
}


module dex::dex {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::event::{Self, emit};

    // Struct to track staking data
    public struct StakingAccount has key, store {
        id: UID,
        staked_weth: Balance<WETH>,
        staked_usdc: Balance<USDC>,
        last_reward_time: u64,
    }

    // Reward distribution rate constants
    const REWARD_RATE_WETH: u64 = 6; // Reward per WETH per time unit
    const REWARD_RATE_USDC: u64 = 2;  // Reward per USDC per time unit

    /// Stake WETH tokens and transfer them to the LendingPool's WETH supply
    public fun stake_weth(
        account: &mut StakingAccount,
        pool: &mut LendingPool,
        weth_coin: Coin<WETH>,
        ctx: &mut TxContext
    ) {
        // Add staked WETH to the LendingPool's supply
        balance::join(&mut pool.weth_supply, coin::into_balance(weth_coin));

        // Record the staked amount in the user's staking account
        balance::join(&mut account.staked_weth, coin::into_balance(weth_coin));
        account.last_reward_time = clock::now(ctx);

        emit(DepositEvent {
            message: b"WETH staked successfully and added to LendingPool supply.",
        });
    }

    /// Stake USDC tokens and transfer them to the LendingPool's USDC supply
    public fun stake_usdc(
        account: &mut StakingAccount,
        pool: &mut LendingPool,
        usdc_coin: Coin<USDC>,
        ctx: &mut TxContext
    ) {
        // Add staked USDC to the LendingPool's supply
        balance::join(&mut pool.usdc_supply, coin::into_balance(usdc_coin));

        // Record the staked amount in the user's staking account
        balance::join(&mut account.staked_usdc, coin::into_balance(usdc_coin));
        account.last_reward_time = clock::now(ctx);

        emit(DepositEvent {
            message: b"USDC staked successfully and added to LendingPool supply.",
        });
    }

    /// Claim staking rewards
    public fun claim_rewards(
        account: &mut StakingAccount,
        pool: &mut LendingPool,
        ctx: &mut TxContext
    ) {
        let current_time = clock::now(ctx);
        let time_elapsed = current_time - account.last_reward_time;

        // Calculate rewards for WETH and USDC
        let weth_rewards = balance::value(&account.staked_weth) * REWARD_RATE_WETH * time_elapsed;
        let usdc_rewards = balance::value(&account.staked_usdc) * REWARD_RATE_USDC * time_elapsed;

        // Mint DEX tokens as rewards
        let total_rewards = weth_rewards + usdc_rewards;
        let reward_coin = coin::mint(&mut pool.treasury_cap_dex, total_rewards, ctx);

        // Transfer rewards to the user
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(reward_coin, sender);

        // Update the last reward time
        account.last_reward_time = current_time;

        emit(RewardEvent {
            message: b"Rewards claimed successfully.",
        });
    }

    /// Unstake WETH tokens and remove them from the LendingPool's WETH supply
    public fun unstake_weth(
        account: &mut StakingAccount,
        pool: &mut LendingPool,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Remove the amount from the LendingPool's supply
        let unstaked_coin = coin::take(&mut pool.weth_supply, amount, ctx);

        // Update the user's staking balance
        let unstaked_user_coin = coin::take(&mut account.staked_weth, amount, ctx);
         balance::join(&mut account.staked_weth, coin::into_balance(unstaked_user_coin));

        // Transfer the unstaked coin back to the user
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(unstaked_coin, sender);

        emit(WithdrawalEvent {
            message: b"WETH unstaked successfully and removed from LendingPool supply.",
        });
    }

    /// Unstake USDC tokens and remove them from the LendingPool's USDC supply
    public fun unstake_usdc(
        account: &mut StakingAccount,
        pool: &mut LendingPool,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Remove the amount from the LendingPool's supply
        let unstaked_coin = coin::take(&mut pool.usdc_supply, amount, ctx);

        // Update the user's staking balance
        let unstaked_user_coin = coin::take(&mut account.staked_usdc, amount, ctx);
        balance::join(&mut account.staked_usdc, coin::into_balance(unstaked_user_coin));

        // Transfer the unstaked coin back to the user
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(unstaked_coin, sender);

        emit(WithdrawalEvent {
            message: b"USDC unstaked successfully and removed from LendingPool supply.",
        });
    }
}
