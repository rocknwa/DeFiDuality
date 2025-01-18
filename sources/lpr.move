 #[lint_allow(self_transfer)]
 #[allow(duplicate_alias)]
 module lpr::lpr {
   use std::option;
   use sui::transfer;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, TreasuryCap, Coin};
    use sui::event::emit;
    use lpr::wbtc::WBTC;
    use lpr::usdc::USDC;
    use lpr::lpwbtc::LPWBTC;
    use lpr::lpusdc::LPUSDC;

    const MIN_COLLATERAL_RATIO: u64 = 150; // 150% collateral
    const FLOAT_SCALING: u64 = 1_000_000_000; // Scaling for decimal handling
    const WBTC_TO_USDC_RATE: u64 = 90000 * FLOAT_SCALING; 

    // Reward distribution rate constants
    const REWARD_RATE_WBTC: u64 = 60; // Reward per WBTC per time unit
    const REWARD_RATE_USDC: u64 = 2;  // Reward per USDC per time unit


    // Define a public struct named LPR with the `has drop` attribute.
// This indicates that instances of LPR can be explicitly dropped (deleted) when no longer needed.
public struct LPR has drop {}

// Define the main LendingPool struct, which contains key financial and operational details
// about the lending pool. It has `has key` (can be stored in global storage) 
// and `has store` (allows storage in the Move module) attributes.
public struct LendingPool has key, store {
    id: UID, // Unique identifier for the lending pool.
    wbtc_supply: Balance<WBTC>, // Balance of WBTC tokens supplied to the pool.
    usdc_supply: Balance<USDC>, // Balance of USDC tokens supplied to the pool.
    lpwbtc_supply: Balance<LPWBTC>, // Balance of LPWBTC tokens (liquidity provider tokens for WBTC).
    lpusdc_supply: Balance<LPUSDC>, // Balance of LPUSDC tokens (liquidity provider tokens for USDC).
    treasury_cap_usdc: TreasuryCap<USDC>, // Treasury cap for USDC to limit total mintable supply.
    treasury_cap_wbtc: TreasuryCap<WBTC>, // Treasury cap for WBTC to limit total mintable supply.
    treasury_cap_lpusdc: TreasuryCap<LPUSDC>, // Treasury cap for LPUSDC tokens.
    treasury_cap_lpwbtc: TreasuryCap<LPWBTC>, // Treasury cap for LPWBTC tokens.
    treasury_cap_lpr: TreasuryCap<LPR>, // Treasury cap for LPR tokens.
    borrowed_usdc: u64, // Total amount of USDC currently borrowed from the pool.
    borrowed_wbtc: u64, // Total amount of WBTC currently borrowed from the pool.
    staked_wbtc: u64, // Total amount of WBTC staked in the pool.
    staked_usdc: u64, // Total amount of USDC staked in the pool.
    last_reward_time: u64, // Timestamp of the last reward distribution.
}

// Define an event for withdrawals, with a message attribute for custom details.
// The `has copy` attribute allows duplication, and `has drop` allows cleanup.
public struct WithdrawalEvent has copy, drop {
    message: vector<u8> // Event message, stored as a vector of bytes.
}

// Define an event for deposits, with similar functionality to WithdrawalEvent.
public struct DepositEvent has copy, drop {
    message: vector<u8> // Event message, stored as a vector of bytes.
}

// Define an event for transfers, used to track token movements.
public struct TransferEvent has copy, drop {
    message: vector<u8> // Event message, stored as a vector of bytes.
}

// Define an event for rewards, to record reward distributions.
public struct RewardEvent has copy, drop {
    message: vector<u8> // Event message, stored as a vector of bytes.
}

// Initialization function for the Lending Pool Reward (LPR) token.
// This function uses a witness object and the transaction context (`ctx`)
// to create and register the LPR token with associated metadata.
#[allow(lint(share_owned))]
fun init(witness: LPR, ctx: &mut TxContext) {
    // Create the LPR currency with its metadata (name, symbol, description, etc.).
    let (treasury_cap, metadata) = coin::create_currency<LPR>(
        witness,                  // The LPR witness struct required for initialization.
        9,                        // Decimal precision of the token.
        b"LPR",                   // Token symbol.
        b"Liquidity Pool Reward Coin", // Token name.
        b"Coin of SUI Lending Pool",   // Token description.
        option::none(),           // Optional URI for additional metadata (not used here).
        ctx                       // Transaction context.
    );

    // Transfer the treasury cap to the sender of the transaction.
    transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

    // Share the metadata object publicly so it can be accessed by others.
    transfer::public_share_object(metadata);
}

// Function to create a lending pool. It initializes a LendingPool struct
// with zero balances, treasury caps, and default values for all attributes.
public fun create_pool(
    cap_usdc: TreasuryCap<USDC>,         // Treasury cap for USDC tokens.
    cap_lpusdc: TreasuryCap<LPUSDC>,     // Treasury cap for LPUSDC tokens.
    cap_wbtc: TreasuryCap<WBTC>,         // Treasury cap for WBTC tokens.
    cap_lpwbtc: TreasuryCap<LPWBTC>,     // Treasury cap for LPWBTC tokens.
    cap_lpr: TreasuryCap<LPR>,           // Treasury cap for LPR tokens.
    ctx: &mut TxContext                  // Transaction context for the operation.
): LendingPool {
    LendingPool {
        id: object::new(ctx),           // Generate a new unique ID for the pool.
        wbtc_supply: balance::zero(),   // Initialize WBTC supply to zero.
        usdc_supply: balance::zero(),   // Initialize USDC supply to zero.
        lpwbtc_supply: balance::zero(), // Initialize LPWBTC supply to zero.
        lpusdc_supply: balance::zero(), // Initialize LPUSDC supply to zero.
        treasury_cap_usdc: cap_usdc,    // Assign the provided USDC treasury cap.
        treasury_cap_wbtc: cap_wbtc,    // Assign the provided WBTC treasury cap.
        treasury_cap_lpusdc: cap_lpusdc, // Assign the provided LPUSDC treasury cap.
        treasury_cap_lpwbtc: cap_lpwbtc, // Assign the provided LPWBTC treasury cap.
        treasury_cap_lpr: cap_lpr,      // Assign the provided LPR treasury cap.
        borrowed_usdc: 0,               // Initialize borrowed USDC amount to zero.
        borrowed_wbtc: 0,               // Initialize borrowed WBTC amount to zero.
        staked_wbtc: 0,                 // Initialize staked WBTC amount to zero.
        staked_usdc: 0,                 // Initialize staked USDC amount to zero.
        last_reward_time: 0,            // Set the last reward distribution time to zero.
    }
}

// Function to mint USDC tokens.
// The tokens are minted using the treasury cap and transferred to the transaction sender.
public fun mint_usdc(
    cap: &mut TreasuryCap<USDC>,       // Mutable reference to the USDC treasury cap.
    amount: u64,                       // Amount of USDC to mint (in base units).
    ctx: &mut TxContext                // Transaction context for the operation.
) {
    let minted_coin = coin::mint(cap, amount * FLOAT_SCALING, ctx); // Mint the specified amount of USDC.
    let sender = tx_context::sender(ctx); // Get the address of the transaction sender.
    transfer::public_transfer(minted_coin, sender); // Transfer the minted coins to the sender.
}

// Function to mint SUI tokens.
// Similar to `mint_usdc`, but for SUI tokens.
public fun mint_sui(
    cap: &mut TreasuryCap<SUI>,        // Mutable reference to the SUI treasury cap.
    amount: u64,                       // Amount of SUI to mint (in base units).
    ctx: &mut TxContext                // Transaction context for the operation.
) {
    let minted = coin::mint(cap, amount * FLOAT_SCALING, ctx); // Mint the specified amount of SUI.
    let sender = tx_context::sender(ctx); // Get the address of the transaction sender.
    transfer::public_transfer(minted, sender); // Transfer the minted coins to the sender.
}

// Function to mint WBTC tokens.
// Similar to `mint_usdc`, but for WBTC tokens.
public fun mint_wbtc(
    cap: &mut TreasuryCap<WBTC>,       // Mutable reference to the WBTC treasury cap.
    amount: u64,                       // Amount of WBTC to mint (in base units).
    ctx: &mut TxContext                // Transaction context for the operation.
) {
    let minted_coin = coin::mint(cap, amount * FLOAT_SCALING, ctx); // Mint the specified amount of WBTC.
    let sender = tx_context::sender(ctx); // Get the address of the transaction sender.
    transfer::public_transfer(minted_coin, sender); // Transfer the minted coins to the sender.
}

// Function to convert WBTC to USDC.
// Uses a predefined exchange rate (`WBTC_TO_USDC_RATE`) to calculate the equivalent USDC amount.
public fun convert_wbtc_to_usdc(
    wbtc_amount: u64 // Amount of WBTC to convert (in base units).
): u64 {
    wbtc_amount * WBTC_TO_USDC_RATE / FLOAT_SCALING // Perform the conversion using the exchange rate.
}

// Function to convert USDC to WBTC.
// Uses the inverse of `WBTC_TO_USDC_RATE` to calculate the equivalent WBTC amount.
public fun convert_usdc_to_wbtc(
    usdc_amount: u64 // Amount of USDC to convert (in base units).
): u64 {
    usdc_amount * FLOAT_SCALING / WBTC_TO_USDC_RATE // Perform the conversion using the exchange rate.
}


   // Function to borrow USDC tokens from the lending pool.
public fun borrow_usdc(
    pool: &mut LendingPool,  // Reference to the LendingPool structure.
    usdc_amount: u64,        // Amount of USDC to borrow (in base units).
    ctx: &mut TxContext      // Transaction context for the operation.
) {
    // Calculate the total WBTC collateral value in the pool.
    let wbtc_collateral_value = pool.staked_wbtc;

    // Convert the desired USDC amount to the scaled format for precision.
    let usdc_amount_borrowed = usdc_amount * FLOAT_SCALING;

    // Calculate the required WBTC collateral based on the borrowing amount.
    let required_collateral = convert_usdc_to_wbtc(usdc_amount_borrowed) * MIN_COLLATERAL_RATIO / 100;

    // Ensure the borrower has enough WBTC collateral.
    assert!(wbtc_collateral_value >= required_collateral, 1);

    // Check if the pool has enough USDC supply; mint more if needed.
    if (balance::value(&pool.usdc_supply) < usdc_amount * FLOAT_SCALING) {
        let mint_amount = (usdc_amount * FLOAT_SCALING) - balance::value(&pool.usdc_supply);
        let minted_coin = coin::mint(&mut pool.treasury_cap_usdc, mint_amount, ctx);
        balance::join(&mut pool.usdc_supply, coin::into_balance(minted_coin));
    };

    // Borrow the requested USDC amount from the pool's supply.
    let usdc_borrowed = coin::take(&mut pool.usdc_supply, usdc_amount * FLOAT_SCALING, ctx);

    // Update the pool's borrowed USDC balance.
    pool.borrowed_usdc = pool.borrowed_usdc + usdc_amount_borrowed;

    // Transfer the borrowed USDC to the borrower's account.
    let sender = tx_context::sender(ctx);
    transfer::public_transfer(usdc_borrowed, sender);

    // Reward the user with LPR tokens for participating in the protocol.
    reward_user_with_lpr(&mut pool.treasury_cap_lpr, ctx);
}

// Function to borrow WBTC tokens from the lending pool.
public fun borrow_wbtc(
    pool: &mut LendingPool,  // Reference to the LendingPool structure.
    wbtc_amount: u64,        // Amount of WBTC to borrow (in base units).
    ctx: &mut TxContext      // Transaction context for the operation.
) {
    // Calculate the total USDC collateral value in the pool.
    let usdc_collateral_value = pool.staked_usdc;

    // Convert the desired WBTC amount to the scaled format for precision.
    let wbtc_amount_borrowed = wbtc_amount * FLOAT_SCALING;

    // Calculate the required USDC collateral based on the borrowing amount.
    let required_collateral = convert_wbtc_to_usdc(wbtc_amount_borrowed) * MIN_COLLATERAL_RATIO / 100;

    // Ensure the borrower has enough USDC collateral.
    assert!(usdc_collateral_value >= required_collateral, 1);

    // Check if the pool has enough WBTC supply; mint more if needed.
    if (balance::value(&pool.wbtc_supply) < wbtc_amount * FLOAT_SCALING) {
        let mint_amount = (wbtc_amount * FLOAT_SCALING) - balance::value(&pool.wbtc_supply);
        let minted_coin = coin::mint(&mut pool.treasury_cap_wbtc, mint_amount, ctx);
        balance::join(&mut pool.wbtc_supply, coin::into_balance(minted_coin));
    };

    // Borrow the requested WBTC amount from the pool's supply.
    let wbtc_borrowed = coin::take(&mut pool.wbtc_supply, wbtc_amount * FLOAT_SCALING, ctx);

    // Update the pool's borrowed WBTC balance.
    pool.borrowed_wbtc = pool.borrowed_wbtc + wbtc_amount_borrowed;

    // Transfer the borrowed WBTC to the borrower's account.
    let sender = tx_context::sender(ctx);
    transfer::public_transfer(wbtc_borrowed, sender);

    // Reward the user with LPR tokens for participating in the protocol.
    reward_user_with_lpr(&mut pool.treasury_cap_lpr, ctx);
}

// Function to repay borrowed USDC tokens to the lending pool.
public fun repay_usdc(
    pool: &mut LendingPool,  // Reference to the LendingPool structure.
    repayment: Coin<USDC>,   // The USDC coin used for repayment.
    ctx: &mut TxContext      // Transaction context for the operation.
) {
    // Get the value of the repaid USDC tokens.
    let repaid_amount = repayment.value();

    // Add the repaid USDC tokens back to the pool's supply.
    balance::join(&mut pool.usdc_supply, coin::into_balance(repayment));

    // Update the pool's borrowed USDC balance.
    pool.borrowed_usdc = pool.borrowed_usdc - repaid_amount;

    // Reward the user with LPR tokens for repaying their loan.
    reward_user_with_lpr(&mut pool.treasury_cap_lpr, ctx);
}

// Function to repay borrowed WBTC tokens to the lending pool.
public fun repay_wbtc(
    pool: &mut LendingPool,  // Reference to the LendingPool structure.
    repayment: Coin<WBTC>,   // The WBTC coin used for repayment.
    ctx: &mut TxContext      // Transaction context for the operation.
) {
    // Get the value of the repaid WBTC tokens.
    let repaid_amount = coin::value(&repayment);

    // Add the repaid WBTC tokens back to the pool's supply.
    balance::join(&mut pool.wbtc_supply, coin::into_balance(repayment));

    // Update the pool's borrowed WBTC balance.
    pool.borrowed_wbtc = pool.borrowed_wbtc - repaid_amount;

    // Reward the user with LPR tokens for repaying their loan.
    reward_user_with_lpr(&mut pool.treasury_cap_lpr, ctx);
}


    
public fun withdraw_staked_wbtc(
    amount: Coin<LPWBTC>,  
    pool: &mut LendingPool,  // Reference to the lending pool.
    ctx: &mut TxContext  // Transaction context.
) {
    assert!(pool.borrowed_wbtc == 0 && pool.borrowed_usdc == 0, 1); // Ensure no outstanding loans.

    let coin_amount = amount.value();  // Get the withdrawal amount.
    assert!(pool.staked_wbtc >= coin_amount, 2);  // Ensure sufficient staked balance.

    balance::join(&mut pool.lpwbtc_supply, coin::into_balance(amount));  // Return LPWBTC to the pool.

    let withdrawn_coin = coin::take(&mut pool.wbtc_supply, coin_amount, ctx);  // Withdraw WBTC from the pool.
    pool.staked_wbtc = pool.staked_wbtc - coin_amount;  // Update staked balance.

    let sender = tx_context::sender(ctx);  // Get the sender's address.
    transfer::public_transfer(withdrawn_coin, sender);  // Transfer WBTC to the user.

    emit(WithdrawalEvent { message: b"Staked WBTC withdrawn successfully." });  // Emit event.
}

    
public fun withdraw_staked_usdc(
    amount: Coin<LPUSDC>,  
    pool: &mut LendingPool,
    ctx: &mut TxContext
) {
    assert!(pool.borrowed_wbtc == 0 && pool.borrowed_usdc == 0, 1);  // Ensure no outstanding loans.

    let coin_amount = amount.value();  // Get the withdrawal amount.
    assert!(pool.staked_usdc >= coin_amount, 2);  // Ensure sufficient staked balance.

    balance::join(&mut pool.lpusdc_supply, coin::into_balance(amount));  // Return LPUSDC to the pool.

    let withdrawn_coin = coin::take(&mut pool.usdc_supply, coin_amount, ctx);  // Withdraw USDC from the pool.
    pool.staked_usdc = pool.staked_usdc - coin_amount;  // Update staked balance.

    let sender = tx_context::sender(ctx);  // Get the sender's address.
    transfer::public_transfer(withdrawn_coin, sender);  // Transfer USDC to the user.

    emit(WithdrawalEvent { message: b"Staked USDC withdrawn successfully." });  // Emit event.
}

public fun send_wbtc_receive_usdc(
    pool: &mut LendingPool,  // Reference to the lending pool.
    recipient: address,  // Address to receive USDC.
    wbtc_amount: Coin<WBTC>,  // Amount of WBTC to send.
    ctx: &mut TxContext
) {
    let value = coin::value(&wbtc_amount);  // Get WBTC value.
    let usdc_equivalent = convert_wbtc_to_usdc(value);  // Convert to USDC equivalent.

    // Ensure enough USDC supply, mint if necessary.
    if (balance::value(&pool.usdc_supply) < usdc_equivalent) {
        let mint_amount = usdc_equivalent - balance::value(&pool.usdc_supply);
        let minted_coin = coin::mint(&mut pool.treasury_cap_usdc, mint_amount, ctx);
        balance::join(&mut pool.usdc_supply, coin::into_balance(minted_coin));
    };

    balance::join(&mut pool.wbtc_supply, coin::into_balance(wbtc_amount));  // Add WBTC to the pool.

    let usdc_coin = coin::take(&mut pool.usdc_supply, usdc_equivalent, ctx);  // Take USDC from the pool.
    transfer::public_transfer(usdc_coin, recipient);  // Transfer USDC to recipient.

    reward_user_with_lpr(&mut pool.treasury_cap_lpr, ctx);  // Reward user with LPR tokens.

    emit(TransferEvent { message: b"WBTC sent, USDC received successfully. LPR token reward granted." });  // Emit event.
}

   public fun send_usdc_receive_wbtc(
    pool: &mut LendingPool,
    recipient: address,  // Address to receive WBTC.
    usdc_amount: Coin<USDC>,  // Amount of USDC to send.
    ctx: &mut TxContext
) {
    let value = coin::value(&usdc_amount);  // Get USDC value.
    let wbtc_equivalent = convert_usdc_to_wbtc(value);  // Convert to WBTC equivalent.

    // Ensure enough WBTC supply, mint if necessary.
    if (balance::value(&pool.wbtc_supply) < wbtc_equivalent) {
        let mint_amount = wbtc_equivalent - balance::value(&pool.wbtc_supply);
        let minted_coin = coin::mint(&mut pool.treasury_cap_wbtc, mint_amount, ctx);
        balance::join(&mut pool.wbtc_supply, coin::into_balance(minted_coin));
    };

    balance::join(&mut pool.usdc_supply, coin::into_balance(usdc_amount));  // Add USDC to the pool.

    let wbtc_coin = coin::take(&mut pool.wbtc_supply, wbtc_equivalent, ctx);  // Take WBTC from the pool.
    transfer::public_transfer(wbtc_coin, recipient);  // Transfer WBTC to recipient.

    reward_user_with_lpr(&mut pool.treasury_cap_lpr, ctx);  // Reward user with LPR tokens.

    emit(TransferEvent { message: b"Transfer successful: USDC sent, WBTC received. LPR token reward granted." });  // Emit event.
}

public fun stake_wbtc(
    pool: &mut LendingPool,  // Reference to the lending pool.
    clock: &sui::clock::Clock,  // Clock for timestamp.
    wbtc_coin: Coin<WBTC>,  // WBTC coin to stake.
    ctx: &mut TxContext  // Transaction context.
) {
    let amount = coin::value(&wbtc_coin);  // Get the amount to stake.
    
    balance::join(&mut pool.wbtc_supply, coin::into_balance(wbtc_coin));  // Add to WBTC supply.

    pool.staked_wbtc = pool.staked_wbtc + amount;  // Update staked WBTC balance.
    pool.last_reward_time = sui::clock::timestamp_ms(clock);  // Record the timestamp.

    let lpwbtc_coin = coin::mint(&mut pool.treasury_cap_lpwbtc, amount, ctx);  // Mint LPWBTC.
    let sender = tx_context::sender(ctx);  // Get sender's address.
    transfer::public_transfer(lpwbtc_coin, sender);  // Transfer LPWBTC to the sender.

    emit(DepositEvent {
        message: b"WBTC staked successfully and added to LendingPool supply.",  // Emit event.
    });
}


    /// Stake USDC tokens and transfer them to the LendingPool's USDC supply
    public fun stake_usdc(
        pool: &mut LendingPool,
        clock: &sui::clock::Clock,
        usdc_coin: Coin<USDC>,
        ctx: &mut TxContext
    ) {

        let amount = coin::value(&usdc_coin);

        // Add staked USDC to the LendingPool's supply
        balance::join(&mut pool.usdc_supply, coin::into_balance(usdc_coin));

        // Record the staked amount in the user's staking account
        pool.staked_usdc = pool.staked_usdc + amount;

        let lpusdc_coin = coin::mint(&mut pool.treasury_cap_lpusdc, amount, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(lpusdc_coin, sender);
        pool.last_reward_time = sui::clock::timestamp_ms(clock);

        emit(DepositEvent {
            message: b"USDC staked successfully and added to LendingPool supply.",
        });
    }

    /// Claim staking rewards
    public fun claim_rewards(
        pool: &mut LendingPool,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext
    ) {
        let current_time = sui::clock::timestamp_ms(clock);


        let time_elapsed = current_time - pool.last_reward_time;

        // Calculate rewards for WBTC and USDC
        let wbtc_rewards = pool.staked_wbtc * REWARD_RATE_WBTC * time_elapsed;
        let usdc_rewards = pool.staked_usdc * REWARD_RATE_USDC * time_elapsed;

        // Mint lpr tokens as rewards
        let total_rewards = wbtc_rewards + usdc_rewards;
        let reward_coin = coin::mint(&mut pool.treasury_cap_lpr, total_rewards, ctx);

        // Transfer rewards to the user
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(reward_coin, sender);

        // Update the last reward time
        pool.last_reward_time = current_time;

        emit(RewardEvent {
            message: b"Rewards claimed successfully.",
        });
    }

       /// Returns the current WBTC balance in the LendingPool.
public fun get_pool_wbtc_balance(pool: &LendingPool): u64 {
    // Access the value of WBTC tokens in the pool's supply.
    pool.wbtc_supply.value()
}

/// Returns the current USDC balance in the LendingPool.
public fun get_pool_usdc_balance(pool: &LendingPool): u64 {
    // Access the value of USDC tokens in the pool's supply.
    pool.usdc_supply.value()
}

/// Returns the total amount of WBTC staked in the LendingPool.
public fun get_staked_wbtc_balance(pool: &LendingPool): u64 {
    // Retrieve the amount of WBTC tokens staked in the pool.
    pool.staked_wbtc
}

/// Returns the total amount of USDC staked in the LendingPool.
public fun get_staked_usdc_balance(pool: &LendingPool): u64 {
    // Retrieve the amount of USDC tokens staked in the pool.
    pool.staked_usdc
}

/// Returns the total amount of USDC borrowed from the LendingPool.
public fun get_borrowed_usdc_balance(pool: &LendingPool): u64 {
    // Retrieve the amount of USDC tokens borrowed from the pool.
    pool.borrowed_usdc
}

/// Returns the total amount of WBTC borrowed from the LendingPool.
public fun get_borrowed_wbtc_balance(pool: &LendingPool): u64 {
    // Retrieve the amount of WBTC tokens borrowed from the pool.
    pool.borrowed_wbtc
}

/// Mints LPR tokens as a reward for the user and transfers them to the sender.
/// - Parameters:
///   - cap: A mutable reference to the LPR token's TreasuryCap, which manages minting.
///   - ctx: The transaction context containing details about the sender and transaction state.
fun reward_user_with_lpr(cap: &mut TreasuryCap<LPR>, ctx: &mut TxContext) {
    // Define the reward amount as a scaled value.
    let reward_amount = 1 * FLOAT_SCALING;

    // Mint the reward tokens using the TreasuryCap.
    let reward = coin::mint(cap, reward_amount, ctx);

    // Identify the sender of the transaction.
    let sender = tx_context::sender(ctx);

    // Transfer the minted reward tokens to the sender's address.
    transfer::public_transfer(reward, sender);

    // Emit a RewardEvent to log the reward action.
    emit(RewardEvent {
        message: b"LPR token reward granted", // Event message for logging.
    });
}

      #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(DEX {}, ctx)
    }
}
