#[allow(duplicate_alias)]
module lpr::wbtc {
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::tx_context::{TxContext, Self};

    public struct WBTC has drop {}

    #[allow(unused_function)]
    fun init(witness: WBTC, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"WBTC", b"", b"", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(WBTC {}, ctx);
  }
}
