  module fcode::creating {
    /***********/
    /* Imports */
    
    /***********/
    //''
    //
    //

    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::event::EventHandle;
    use aptos_std::table; 
    use aptos_std::table::Table; 
    use std::string;
    use std::string::String;
    use std::option;
    use std::signer;
    use std::vector;
    use std::error;
    use std::debug;
    //   use aptos_framework::coin::{Self, MintCapability, FreezeCapability, BurnCapability};


     const MAX_U64: u128 = 18446744073709551615;

 struct PoolInfo has key {
        active: bool,
        owner: address,
        new_owner: option::Option<address>,
        
        


        asset_aggregate_names: vector<String>, // [aggregate_name]
        asset_aggregates: Table<String, vector<String>>, // aggregate_name -> [coin_name]

        

        
        pool_ownership_transfer_events: EventHandle<PoolOwnershipTransferEvent>,

        signer_cap: account::SignerCapability,
    }

     struct Pools has key {
        pools: vector<address>,
        create_new_pool_events: EventHandle<CreateNewPoolEvent>,
        pool_ownership_transfer_events: EventHandle<PoolOwnershipTransferEvent>,
    }
      struct CreateNewPoolEvent has store, drop {
        owner_addr: address,
        pool_addr: address,
    }
   struct PoolOwnershipTransferEvent has store, drop {
        pool_addr: address,
        old_owner: address,
        new_owner: address,
    }
//    struct Caps<phantom CoinType> has key {
//         mint: MintCapability<CoinType>,
//         freeze: FreezeCapability<CoinType>,
//         burn: BurnCapability<CoinType>,
//     }


  public entry fun createpool(owner: &signer) acquires Pools {
        let (pool_signer, signer_cap) = account::create_resource_account(owner, vector::empty());

        let pool_addr = signer::address_of(&pool_signer);
        let pool = PoolInfo {
            active: true,
            owner: signer::address_of(owner),
            new_owner: option::none(),

            asset_aggregate_names: vector::empty(),
            asset_aggregates: table::new(),

            pool_ownership_transfer_events: account::new_event_handle(&pool_signer),


            signer_cap
        };
        move_to<PoolInfo>(&pool_signer, pool);

        if (!exists<Pools>(signer::address_of(owner))) {
            move_to<Pools>(owner, Pools {
                pools: vector::empty(),
                create_new_pool_events: account::new_event_handle(owner),
                pool_ownership_transfer_events: account::new_event_handle(owner),

            });
        };

        let pools = borrow_global_mut<Pools>(signer::address_of(owner));
        vector::push_back(&mut pools.pools, pool_addr);

        event::emit_event(&mut pools.create_new_pool_events, CreateNewPoolEvent {
            owner_addr: signer::address_of(owner),
            pool_addr,
        });
    }
        fun create_pool_signer(pool_addr: address): signer acquires PoolInfo {
        
        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);

        account::create_signer_with_capability(&pool_info.signer_cap)
    }
     public entry fun add_asset<T>(account: &signer, pool_addr: address) acquires PoolInfo {
        let pool_signer = create_pool_signer(pool_addr);
        coin::register<T>(&pool_signer);
    }
        public entry fun transfer <T>(account: &signer, pool_addr: address,amount: u64) {
        // let pool_signer = create_pool_signer(pool_addr);
        coin::transfer<T>(account, pool_addr, amount);

    }
       public entry fun dispense<T>(to: &signer, pool_addr: address) acquires PoolInfo {
        let pool = borrow_global_mut<PoolInfo>(pool_addr);
        let pool_signer = account::create_signer_with_capability(&pool.signer_cap);
        coin::transfer<T>(&pool_signer, signer::address_of(to), 200000000);

    }
  }