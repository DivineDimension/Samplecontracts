// Since aptos does not yet support any way to look up prices of toknes,
// this module defines a capability to manually or through the API update
// the price of specific tokens.
// This does, unfortunately, cost gas.
// Only the account with the same address of the module can set the price.
module nucleus::price_provider {
    use std::signer;
    use std::error;
    use std::string;
    use aptos_std::table;
    use aptos_framework::coin;

    /***********/
    /* Structs */
    /***********/

    struct PriceStore has key {
        values: table::Table<string::String, u64>
    }

    /**********/
    /* Errors */
    /**********/
    
    /// The price provider is not set up globally.
    const ENOT_SET_UP: u64 = 0x0000;
    /// The account used to set the price of a token is not @nucleus.
    const ESETTER_NOT_NUCLEUS: u64 = 0x0001;
    /// The token whose price is being queried has no price set.
    const ENO_PRICE_SET: u64 = 0x0002;

    
    /*************/
    /* Functions */
    /*************/

    /// Set the price of a currency using its name.
    /// This function requires the calling account to be @nucleus.
    public entry fun set_price_by_name(
        account: &signer, 
        name: string::String, 
        price: u64
    ) acquires PriceStore {
        let addr = signer::address_of(account);
        
        assert!(
            addr == @nucleus, 
            error::permission_denied(ESETTER_NOT_NUCLEUS)
        );

        if (exists<PriceStore>(addr)) {
            let price_store = borrow_global_mut<PriceStore>(addr);

            table::upsert(&mut price_store.values, name, price);
        } else {
            let price_store = PriceStore {
                values: table::new(),
            };

            table::upsert(&mut price_store.values, name, price);


            move_to<PriceStore>(account, price_store);
        };
    }

    /// Set the price of a currency using its type.
    /// This function requires the calling account to be @nucleus.
    public entry fun set_price<C>(account: &signer, price: u64) 
    acquires PriceStore {
        set_price_by_name(account, coin::name<C>(), price);
    }

    /// Get the price of a currency using its name.
    public fun get_price_by_name(name: string::String): u64 acquires PriceStore {
        assert!(exists<PriceStore>(@nucleus), error::invalid_state(ENOT_SET_UP));
        
        let t = &borrow_global<PriceStore>(@nucleus).values;

        assert!(table::contains(t, name), error::invalid_state(ENO_PRICE_SET));

        *table::borrow(t, name)
    }

    /// Get the price of a currency using its type.
    public fun get_price<C>(): u64 acquires PriceStore {
        get_price_by_name(coin::name<C>())
    }
}