#[allow(duplicate_alias)]
module lpr::lpusdc {
  use std::option;
  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  public struct LPUSDC has drop {}
  
fun init(witness: LPUSDC, ctx: &mut TxContext) {

			let (treasury_cap, metadata) = coin::create_currency<LPUSDC>(
            witness, 
            9, 
            b"LPUSDC", 
            b"LPUSDC Coin", 
            b"Liquidity Pool version of USDC", 
            option::none(), 
            ctx
        );

      transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
      
			transfer::public_freeze_object(metadata);
  }

  // ** Test Functions

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(LPUSDC {}, ctx);
  }
}