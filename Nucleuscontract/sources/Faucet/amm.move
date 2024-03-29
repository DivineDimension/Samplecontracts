module nucleus::mv {
    /***********/
    /* Imports */
    /***********/

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

    use nucleus::utils;
    use nucleus::decimal;
    use nucleus::decimal::Decimal;

    /*************/
    /* Constants */
    /*************/

    const MAX_U64: u128 = 18446744073709551615;
 

    /***********/
    /* Structs */
    /***********/    

    /// A Liquidised asset of a coin exising in a pool.
    struct LiquidisedAsset<phantom CoinType> has key {
        name: String, // The name of the token/coin liquidised.
        aggregate: String, // The name of the asset aggregate containing this asset,
        liability: u64,
    
        lp_token: LPToken<CoinType>,
    
        // asset events
        balance_update_events: EventHandle<BalanceUpdateEvent>,
        liability_update_events: EventHandle<LiabilityUpdateEvent>,
        aggregate_changed_events: EventHandle<AggregateChangedEvent>
    }

    /// LP token capabilities
    struct LPToken<phantom CoinType> has store {
        mint_c: coin::MintCapability<LP<CoinType>>,
        freeze_c: coin::FreezeCapability<LP<CoinType>>,
        burn_c: coin::BurnCapability<LP<CoinType>>,
    }

    /// LP token coin struct
    struct LP<phantom CoinType> {}

    /// General information about the pool
    struct PoolInfo has key {
        active: bool,
        owner: address,
        new_owner: option::Option<address>,
        
        // secondary storage. needs to be updated every time a LiquidisedAsset is mutated or funds are transferred.
        coins: vector<String>,
        liabilities: Table<String, u64>,
        balances: Table<String, u64>,
        /*const*/decimals: Table<String, u8>,


        asset_aggregate_names: vector<String>, // [aggregate_name]
        asset_aggregates: Table<String, vector<String>>, // aggregate_name -> [coin_name]

        parameters: PoolParameters,


        // action events
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
        withdraw_from_other_asset_events: EventHandle<WithdrawFromOtherAssetEvent>,
        swap_events: EventHandle<SwapEvent>,

        // config events
        add_aggregate_events: EventHandle<AddAggregateEvent>,
        remove_aggregate_events: EventHandle<RemoveAggregateEvent>,
        add_asset_events: EventHandle<AddAssetEvent>,
        remove_asset_events: EventHandle<RemoveAssetEvent>,
        set_param_events: EventHandle<SetParamEvent>,
        set_active_events: EventHandle<SetActiveEvent>,
        set_owner_events: EventHandle<SetOwnerEvent>,

        pool_ownership_transfer_events: EventHandle<PoolOwnershipTransferEvent>,

        signer_cap: account::SignerCapability,
    }
    
    /// The parameters of the pool.
    struct PoolParameters has store, copy, drop {
        k: Decimal,
        n: u64,
        c1: Decimal,
        x_threshold: Decimal,

        retention_ratio: Decimal,
        haircut_rate: Decimal,

        max_price_deviation: Decimal,
    }

    /// Holds the addresses of all the existing pools a user is the owner of.
    struct Pools has key {
        pools: vector<address>,
        create_new_pool_events: EventHandle<CreateNewPoolEvent>,
        pool_ownership_transfer_events: EventHandle<PoolOwnershipTransferEvent>,
    }

    
    /**********/
    /* Events */
    /**********/

    struct CreateNewPoolEvent has store, drop {
        owner_addr: address,
        pool_addr: address,
    }

    struct DepositEvent has store, drop {
        pool_addr: address,
        by: address,
        amount: u64,
        liquidity: u64,
        decimals: u8,
        asset: String,
    }

    struct WithdrawEvent has store, drop {
        pool_addr: address,
        by: address,
        amount: u64,
        liquidity: u64,
        decimals: u8,
        asset: String,
    }

    struct WithdrawFromOtherAssetEvent has store, drop {
        pool_addr: address,
        by: address,
        amount: u64,
        amount_decimals: u8,
        liquidity: u64,
        liquidity_decimals: u8,
        asset_f: String,
        asset_t: String,
    }

    struct SwapEvent has store, drop {
        pool_addr: address,
        by: address,
        amount_f: u64,
        decimals_f: u8,
        amount_t: u64,
        decimals_t: u8,
        asset_f: String,
        asset_t: String,
    }


    struct AddAggregateEvent has store, drop {
        pool_addr: address,
        aggregate_name: String,
    }

    struct RemoveAggregateEvent has store, drop {
        pool_addr: address,
        aggregate_name: String,
    }

    struct AddAssetEvent has store, drop {
        pool_addr: address,
        asset_name: String,
        aggregate_name: String,
    }

    struct RemoveAssetEvent has store, drop {
        pool_addr: address,
        asset_name: String,
        aggregate_name: String,
    }

    struct SetParamEvent has store, drop {
        pool_addr: address,
        param_name: String,
        new_value: u64,
        decimals: u8,
    }

    struct SetActiveEvent has store, drop {
        pool_addr: address,
        new_value: bool,
    }

    struct SetOwnerEvent has store, drop {
        pool_addr: address,
        old_owner: address,
        new_owner: address,
    }



    struct PoolOwnershipTransferEvent has store, drop {
        pool_addr: address,
        old_owner: address,
        new_owner: address,
    }



    struct BalanceUpdateEvent has store, drop {
        pool_addr: address,
        asset_name: String,
        old_balance: u64,
        new_balance: u64,
        decimals: u8,
    }

    struct LiabilityUpdateEvent has store, drop {
        pool_addr: address,
        asset_name: String,
        old_liability: u64,
        new_liability: u64,
        decimals: u8,
    }

    struct AggregateChangedEvent has store, drop {
        pool_addr: address,
        asset_name: String,
        old_aggregate: String,
        new_aggregate: String,
    }

    struct Deposit has key {
        // pool_addr: address,
        cash: u64,
        liability: u64,
        // totalsupply: u64,
        // amount: u64,
        // fee: u64,

    }
    struct Usd has key {
        usd:u64,
    }

    const ENOT_A_POOL: u64 = 0x0000;    
    /// The given pool does not contain an asset matching the requested token.
    const ENO_SUCH_TOKEN: u64 = 0x0001;
    /// The given pool already contains an asset matching the requested token.
    const ETOKEN_ALREADY_EXISTS: u64 = 0x0002;
    /// The token trying to be used does not track total supply.
    const ETOKEN_NOT_TRACKING_SUPPLY: u64 = 0x0003;
    /// There is insufficient liquidity to mint.
    const EINSUFFICIENT_LIQ_MINT: u64 = 0x0004;
    /// The deadline given for an action has passed and the action is expired.
    const EEXPIRED: u64 = 0x0005;
    /// A zero amount was given.
    const EZERO_AMOUNT: u64 = 0x0006;
    /// There is insufficient liquidity to burn.
    const EINSUFFICIENT_LIQ_BURN: u64 = 0x0007;
    /// The amount is too low.
    const EAMOUNT_TOO_LOW: u64 = 0x0008;
    /// There is not enough cash to facilitate the operation.
    const ENOT_ENOUGH_CASH: u64 = 0x0009;
    /// The coverage ratio is too low.
    const ECOV_RATIO_LOW: u64 = 0x000A;
    /// The two given tokens are the same.
    const ESAME_TOKEN: u64 = 0x000B;
    /// The given aggregate to create already exists.
    const EAGGREGATE_ALREADY_EXISTS: u64 = 0x000C;
    /// The given aggregate was not found.
    const EAGGREGATE_NOT_FOUND: u64 = 0x000D;
    /// The given aggregate to destroy is not empty.
    const EAGGREGATE_NOT_EMPTY: u64 = 0x000E;
    /// The two assets are of different aggregates.
    const EDIFFERENT_AGGREGATES: u64 = 0x000F;
    /// Only the owner has access.
    const EOWNER_ONLY: u64 = 0x0010;
    /// The claimant of the ownership transfer is not the intended recipient.
    const ENOT_NEW_OWNER: u64 = 0x0011;
    /// The pool is inactive.
    const EPOOL_INACTIVE: u64 = 0x0012;
    /// The price deviation is too high.
    const EPRICE_DEV: u64 = 0x0013;
    /// There is zero liability for an asset.
    const EZERO_LIABILITY: u64 = 0x0014;
    /// The total supply of a coin is too large to fit into 64 bits.
    const ETOTAL_SUPPLY_EXCEEDS_MAX: u64 = 0x0015;

    const IDEAL_AMOUNT: u64 = 0x0016;
    const SLIPPAGE_ONE: u64 = 0x0017;
    const SLIPPAGE_TWO: u64 = 0x0018;
    const SLIPPAGE: u64 = 0x0019;
    const CASHADDED: u64 = 0x0020;
    const LIABILITY: u64 = 0x0021;
    // const TOTALSUPPLY: u64 = 0x0022;

    fun assert_is_pool(pool_addr: address) {
        assert!(exists<PoolInfo>(pool_addr), error::invalid_argument(ENOT_A_POOL));
    }

    fun assert_has_token<C>(pool_addr: address) {
        assert!(exists<LiquidisedAsset<C>>(pool_addr), error::invalid_argument(ENO_SUCH_TOKEN));
    }

    fun assert_deadline(deadline: u64) {
        use aptos_framework::timestamp;
        assert!(deadline >= timestamp::now_seconds(), error::invalid_state(EEXPIRED));
    }

    fun assert_is_owner(addr: address, pool_addr: address) acquires PoolInfo {
        assert!(borrow_global<PoolInfo>(pool_addr).owner == addr, error::permission_denied(EOWNER_ONLY));
    }

    fun assert_is_active(pool_addr: address) acquires PoolInfo {
        assert!(borrow_global<PoolInfo>(pool_addr).active, error::permission_denied(EPOOL_INACTIVE));
    }

    fun assert_aggregates<A, B>(pool_addr: address) acquires LiquidisedAsset {
        let a_agg = borrow_global<LiquidisedAsset<A>>(pool_addr).aggregate;
        let b_agg = borrow_global<LiquidisedAsset<B>>(pool_addr).aggregate;

        // assert!(a_agg == b_agg, error::invalid_argument(EDIFFERENT_AGGREGATES));
    }

    /// Create a new pool under the ownership of the signer who called the function.
    /// This function moves a nucleus::pool::Pools struct to the owners address.
    /// That struct contains the addresses of all of the pools owned by the user.
    public entry fun create_new_pool(owner: &signer) acquires Pools {
        let (pool_signer, signer_cap) = account::create_resource_account(owner, vector::empty());

        let pool_addr = signer::address_of(&pool_signer);
        let pool = PoolInfo {
            active: true,
            owner: signer::address_of(owner),
            new_owner: option::none(),

            coins: vector::empty(),
            liabilities: table::new(),
            balances: table::new(),
            decimals: table::new(),

            asset_aggregate_names: vector::empty(),
            asset_aggregates: table::new(),

            parameters: PoolParameters { 
                k: decimal::from_decimal_u64(2, 5),
                // k:  decimal::from_decimal_u64(2000, 0),
                n: 7,
                c1: decimal::from_decimal_u64(376927610599998308, 18),
                x_threshold: decimal::from_decimal_u64(329811659274998519, 18),

                retention_ratio: decimal::one(),
                // haircut_rate: decimal::from_decimal_u64(4, 4),
                haircut_rate: decimal::from_decimal_u64(40000, 0),
                // haircut_rate: decimal::from_decimal_u64(1, 0),

                max_price_deviation: decimal::from_decimal_u64(2, 2),
                // max_price_deviation: decimal::from_decimal_u64(20000000, 1),
            },

            deposit_events: account::new_event_handle(&pool_signer),
            withdraw_events: account::new_event_handle(&pool_signer),
            withdraw_from_other_asset_events: account::new_event_handle(&pool_signer),
            swap_events: account::new_event_handle(&pool_signer),

            add_aggregate_events: account::new_event_handle(&pool_signer),
            remove_aggregate_events: account::new_event_handle(&pool_signer),
            add_asset_events: account::new_event_handle(&pool_signer),
            remove_asset_events: account::new_event_handle(&pool_signer),
            set_param_events: account::new_event_handle(&pool_signer),
            set_active_events: account::new_event_handle(&pool_signer),
            set_owner_events: account::new_event_handle(&pool_signer),

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


    public fun get_pools(owner: address): vector<address> acquires Pools {
        if (exists<Pools>(owner)) {
            borrow_global<Pools>(owner).pools
        } else {
            vector::empty()
        }
    }


    fun create_pool_signer(pool_addr: address): signer acquires PoolInfo {
        
        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);

        account::create_signer_with_capability(&pool_info.signer_cap)
    }

    /// Adds an asset aggregate to the pool.
    /// Account must be the owner of the pool.
    public entry fun add_asset_aggregate(account: &signer, pool_addr: address, name: String) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);

        let pool = borrow_global_mut<PoolInfo>(pool_addr);

        assert!(!vector::contains(&pool.asset_aggregate_names, &name), error::invalid_argument(EAGGREGATE_ALREADY_EXISTS));

        vector::push_back(&mut pool.asset_aggregate_names, name);
        table::add(&mut pool.asset_aggregates, name, vector::empty());

        event::emit_event(&mut pool.add_aggregate_events, AddAggregateEvent {
            pool_addr,
            aggregate_name: name
        });
    }

    /// Removes an asset aggregate from the pool.
    /// The aggregate to be removed must be empty of any assets.
    /// Account must be the owner of the pool.
    public entry fun remove_asset_aggregate(account: &signer, pool_addr: address, name: String) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);

        let pool = borrow_global_mut<PoolInfo>(pool_addr);

        assert!(vector::contains(&pool.asset_aggregate_names, &name), error::invalid_argument(EAGGREGATE_NOT_FOUND));

        assert!(vector::length(table::borrow(&pool.asset_aggregates, name)) == 0, error::invalid_state(EAGGREGATE_NOT_EMPTY));
    

        let v = table::remove(&mut pool.asset_aggregates, name);

        vector::destroy_empty(v);

        event::emit_event(&mut pool.remove_aggregate_events, RemoveAggregateEvent {
            pool_addr,
            aggregate_name: name
        });
    }

    /// Adds an asset to the pool with the given aggregate.
    /// Account must be the owner of the pool.
    public entry fun add_asset<C>(account: &signer, pool_addr: address, aggregate: String) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);

        let pool_signer = create_pool_signer(pool_addr);
        let coin_name = coin::name<C>();

        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);

        // add asset to pool
        if (!exists<LiquidisedAsset<C>>(pool_addr)) { // does not exist, create a new liquidised asset
            // register pool for this token
            coin::register<C>(&pool_signer);
            
            // make the LP token and register
            let lp_token = init_lp<C>(account);
            register_lp<C>(&pool_signer);

            // add liquidised asset data to pool
            move_to<LiquidisedAsset<C>>(&pool_signer, LiquidisedAsset<C> {
                name: coin_name,
                aggregate,
                liability: 0,

                lp_token,

                balance_update_events: account::new_event_handle(&pool_signer),
                liability_update_events: account::new_event_handle(&pool_signer),
                aggregate_changed_events: account::new_event_handle(&pool_signer),

            });

            // add the asset type to the types of assets in the pool.

            assert!(vector::contains(&pool_info.asset_aggregate_names, &aggregate), error::invalid_argument(EAGGREGATE_NOT_FOUND));

            vector::push_back(&mut pool_info.coins, coin_name);
            table::add(&mut pool_info.liabilities, coin_name, 0);
            table::add(&mut pool_info.balances, coin_name, coin::balance<C>(pool_addr));
            table::add(&mut pool_info.decimals, coin_name, coin::decimals<C>());

            let aggregates = &mut pool_info.asset_aggregates;

            let v = table::borrow_mut(aggregates, aggregate);

            vector::push_back(v, coin_name);
            
            event::emit_event(&mut pool_info.add_asset_events, AddAssetEvent {
                pool_addr,
                asset_name: coin_name,
                aggregate_name: aggregate,
            });
        } else {
            abort error::already_exists(ETOKEN_ALREADY_EXISTS)
        };
    }

    /// Removes an asset from the pool.
    /// Account must be the owner of the pool.
    public entry fun remove_asset<C>(account: &signer, pool_addr: address) acquires PoolInfo, LiquidisedAsset {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);

        let coin_name = coin::name<C>();
        
        assert!(!exists<PoolInfo>(pool_addr), error::not_found(ENOT_A_POOL));

        // add asset to pool
        if (exists<LiquidisedAsset<C>>(pool_addr)) { // does not exist, create a new liquidised asset
            // add liquidised asset data to pool
            let asset = move_from<LiquidisedAsset<C>>(pool_addr);

            // add the asset type to the types of assets in the pool.
            let pool_info = borrow_global_mut<PoolInfo>(pool_addr);

            let (_, i) = vector::index_of(&pool_info.coins, &coin_name);
            vector::remove(&mut pool_info.coins, i);

            table::remove(&mut pool_info.liabilities, coin_name);
            table::remove(&mut pool_info.balances, coin_name);
            table::remove(&mut pool_info.decimals, coin_name);

            let aggregates = &mut pool_info.asset_aggregates;

            let v = table::borrow_mut(aggregates, asset.aggregate);

            let (_, i) = vector::index_of(v, &coin_name);
            vector::remove(v, i);
            

            event::emit_event(&mut pool_info.remove_asset_events, RemoveAssetEvent{
                pool_addr,
                asset_name: coin_name,
                aggregate_name: asset.aggregate,
            });

            let LiquidisedAsset {
                name: _,
                aggregate: _,
                liability: _,

                lp_token,

                balance_update_events,
                liability_update_events,
                aggregate_changed_events,
            } = asset;

            event::destroy_handle(balance_update_events);
            event::destroy_handle(liability_update_events);
            event::destroy_handle(aggregate_changed_events);

            destroy_lp<C>(lp_token);
        } else {
            abort error::already_exists(ETOKEN_ALREADY_EXISTS)
        };
    }

    /// Changes the aggregate of an already existing asset.
    /// Account must be the owner of the pool.
    public entry fun set_aggregate_for_asset<C>(account: &signer, pool_addr: address, aggregate: String) acquires PoolInfo, LiquidisedAsset {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);

        assert!(vector::contains(&borrow_global<PoolInfo>(pool_addr).asset_aggregate_names, &aggregate), error::invalid_argument(EAGGREGATE_NOT_FOUND));

        let old_agg = *&borrow_global<LiquidisedAsset<C>>(pool_addr).aggregate;
        let coin_name = coin::name<C>();

        let v = table::borrow_mut(&mut borrow_global_mut<PoolInfo>(pool_addr).asset_aggregates, old_agg);

        let (_, i) = vector::index_of(v, &old_agg);
        vector::remove(v, i);

        let _ = v;

        let v = table::borrow_mut(&mut borrow_global_mut<PoolInfo>(pool_addr).asset_aggregates, aggregate);

        vector::push_back(v, aggregate);

        borrow_global_mut<LiquidisedAsset<C>>(pool_addr).aggregate = aggregate;

        event::emit_event(&mut borrow_global_mut<LiquidisedAsset<C>>(pool_addr).aggregate_changed_events, AggregateChangedEvent {
            pool_addr,
            asset_name: coin_name,
            old_aggregate: old_agg,
            new_aggregate: aggregate,
        });
    }

    /// Sets whether the pool is active and can be used for withdrawal, deposit, and swapping.
    /// Account must be the owner of the pool.
    public entry fun set_active(account: &signer, pool_addr: address, active: bool) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).active = active;

        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_active_events, SetActiveEvent {
            pool_addr,
            new_value: active
        });
    }

    /// Transfers the ownership of the pool to the given address. Be careful!
    /// Account must be the current owner of the pool.
    /// The transfer must then be accepted by the new owner, or cancelled by the old owner.
    public entry fun set_owner(account: &signer, pool_addr: address, new_owner_addr: address) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).new_owner = option::some(new_owner_addr);

        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_owner_events, SetOwnerEvent {
            pool_addr,
            old_owner: signer::address_of(account),
            new_owner: new_owner_addr,
        });
    } 

    /// Cancels the ownership trasfer.
    /// Account must be the current owner of the pool.
    public entry fun cancel_ownership_transfer(account: &signer, pool_addr: address) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).new_owner = option::none();

        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_owner_events, SetOwnerEvent {
            pool_addr,
            old_owner: signer::address_of(account),
            new_owner: signer::address_of(account),
        });
    }

    /// Accept an ownership transfer and become the new owner of the pool.
    public entry fun accept_ownership(account: &signer, pool_addr: address) acquires PoolInfo, Pools {
        assert_is_pool(pool_addr);

        let pool = borrow_global_mut<PoolInfo>(pool_addr);

        assert!(option::is_some(&pool.new_owner), error::permission_denied(ENOT_NEW_OWNER));
        assert!(*option::borrow(&pool.new_owner) == signer::address_of(account), error::permission_denied(ENOT_NEW_OWNER));

        let old_owner = pool.owner;
        
        let old_pools = borrow_global_mut<Pools>(old_owner);
        let (_, i) = vector::index_of(&old_pools.pools, &pool_addr);
        vector::remove(&mut old_pools.pools, i);

        event::emit_event(&mut old_pools.pool_ownership_transfer_events, PoolOwnershipTransferEvent {
            pool_addr,
            old_owner,
            new_owner: signer::address_of(account),
        });

        let _ = old_pools;

        if (!exists<Pools>(signer::address_of(account))) {
            move_to<Pools>(account, Pools {
                pools: vector::empty(),
                create_new_pool_events: account::new_event_handle(account),
                pool_ownership_transfer_events: account::new_event_handle(account),
            });
        };

        let pools = borrow_global_mut<Pools>(signer::address_of(account));

        vector::push_back(&mut pools.pools, pool_addr);


        
        event::emit_event(&mut pools.pool_ownership_transfer_events, PoolOwnershipTransferEvent {
            pool_addr,
            old_owner,
            new_owner: signer::address_of(account),
        });
        event::emit_event(&mut pool.pool_ownership_transfer_events, PoolOwnershipTransferEvent {
            pool_addr,
            old_owner,
            new_owner: signer::address_of(account),
        });
    }

    

    /// Set the slippage parameter `k`. 
    /// Given as a decimal representation (ie like coins, (i, d) where for example (i = 505) / (d = 10) == 5.05)
    /// Account must be the owner of the pool.
    public entry fun set_param_k(account: &signer, pool_addr: address, k: u64, decimals: u8) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).parameters.k = decimal::from_decimal_u64(k, decimals);

        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_param_events, SetParamEvent {
            pool_addr,
            param_name: string::utf8(b"k"),
            new_value: k,
            decimals
        });
    }

    /// Set the slippage parameter `n`. 
    /// Account must be the owner of the pool.
    public entry fun set_param_n(account: &signer, pool_addr: address, n: u64) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).parameters.n = n;

        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_param_events, SetParamEvent {
            pool_addr,
            param_name: string::utf8(b"n"),
            new_value: n,
            decimals: 0
        });
    }

    /// Set the slippage parameter `c1`. 
    /// Given as a decimal representation (ie like coins, (i, d) where for example (i = 505) / (d = 10) == 5.05)
    /// Account must be the owner of the pool.
    public entry fun set_param_c1(account: &signer, pool_addr: address, c1: u64, decimals: u8) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).parameters.c1 = decimal::from_decimal_u64(c1, decimals);

        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_param_events, SetParamEvent {
            pool_addr,
            param_name: string::utf8(b"c1"),
            new_value: c1,
            decimals
        });
    }

    /// Set the slippage parameter `x_threshold`. 
    /// Given as a decimal representation (ie like coins, (i, d) where for example (i = 505) / (d = 10) == 5.05)
    /// Account must be the owner of the pool.
    public entry fun set_param_x_threshold(account: &signer, pool_addr: address, x_threshold: u64, decimals: u8) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).parameters.x_threshold = decimal::from_decimal_u64(x_threshold, decimals);

        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_param_events, SetParamEvent {
            pool_addr,
            param_name: string::utf8(b"x_threshold"),
            new_value: x_threshold,
            decimals
        });
    }

    /// Set the parameter `retention_ratio`. 
    /// Given as a decimal representation (ie like coins, (i, d) where for example (i = 505) / (d = 10) == 5.05)
    /// Account must be the owner of the pool.
    public entry fun set_param_retention_ratio(account: &signer, pool_addr: address, retention_ratio: u64, decimals: u8) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).parameters.retention_ratio = decimal::from_decimal_u64(retention_ratio, decimals);
    
        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_param_events, SetParamEvent {
            pool_addr,
            param_name: string::utf8(b"retention_ratio"),
            new_value: retention_ratio,
            decimals
        });
    }

    /// Set the parameter `haircut_rate`. 
    /// Given as a decimal representation (ie like coins, (i, d) where for example (i = 505) / (d = 10) == 5.05)
    /// Account must be the owner of the pool.
    public entry fun set_param_haircut_rate(account: &signer, pool_addr: address, haircut_rate: u64, decimals: u8) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).parameters.haircut_rate = decimal::from_decimal_u64(haircut_rate, decimals);
        
        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_param_events, SetParamEvent {
            pool_addr,
            param_name: string::utf8(b"haircut_rate"),
            new_value: haircut_rate,
            decimals
        });
    }

    /// Set the parameter `max_price_deviation`. 
    /// Given as a decimal representation (ie like coins, (i, d) where for example (i = 505) / (d = 10) == 5.05)
    /// Account must be the owner of the pool.
    public entry fun set_param_max_price_deviation(account: &signer, pool_addr: address, max_price_deviation: u64, decimals: u8) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);
        
        borrow_global_mut<PoolInfo>(pool_addr).parameters.max_price_deviation = decimal::from_decimal_u64(max_price_deviation, decimals);
        
        event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).set_param_events, SetParamEvent {
            pool_addr,
            param_name: string::utf8(b"max_price_deviation"),
            new_value: max_price_deviation,
            decimals
        });
    }


    // gets the total supply of lp tokens
    fun get_total_supply<C>(): Decimal {
        let decimals = coin::decimals<LP<C>>();
        let result = coin::supply<LP<C>>();
        
        assert!(option::is_some(&result), error::invalid_state(ETOKEN_NOT_TRACKING_SUPPLY));

        let total_supply = *option::borrow<u128>(&result);

        decimal::from_decimal_u128(total_supply, decimals)
    }

    fun update_liability<C>(pool_addr: address, amount: u64, add: bool) acquires PoolInfo, LiquidisedAsset {
        let pool = borrow_global_mut<PoolInfo>(pool_addr);
        let asset = borrow_global_mut<LiquidisedAsset<C>>(pool_addr);
        let name = *&asset.name;

        let (old_liability, new_liability) = if (add) {
            asset.liability = asset.liability + amount;

            let liab = table::borrow_mut<String, u64>(&mut pool.liabilities, name);

            let old = *liab;

            *liab = *liab + amount;    

            (old, *liab)
        } else {
            assert!(asset.liability >= amount, error::invalid_state(EAMOUNT_TOO_LOW));

            asset.liability = asset.liability - amount;

            let liab = table::borrow_mut<String, u64>(&mut pool.liabilities, name);

            let old = *liab;

            *liab = *liab - amount;    

            (old, *liab)
        };

        event::emit_event(&mut asset.liability_update_events, LiabilityUpdateEvent {
            pool_addr,
            asset_name: name,
            old_liability,
            new_liability,
            decimals: coin::decimals<C>(),
        });
    }

    fun update_balance<C>(pool_addr: address, amount: u64, add: bool) acquires PoolInfo, LiquidisedAsset {
        let pool = borrow_global_mut<PoolInfo>(pool_addr);
        let asset = borrow_global_mut<LiquidisedAsset<C>>(pool_addr);
        let name = *&asset.name;

        let (old_balance, new_balance) = if (add) {
            let bal = table::borrow_mut<String, u64>(&mut pool.balances, name);

            let old = *bal;

            *bal = *bal + amount;

            (old, *bal)    
        } else {
            let bal = table::borrow_mut<String, u64>(&mut pool.balances, name);

            assert!(*bal >= amount, error::invalid_state(EAMOUNT_TOO_LOW));

            let old = *bal;

            *bal = *bal - amount;    

            (old, *bal)
        };

        event::emit_event(&mut asset.balance_update_events, BalanceUpdateEvent {
            pool_addr,
            asset_name: name,
            old_balance,
            new_balance,
            decimals: coin::decimals<C>(),
        });
    }

    fun check_price_deviation<A, B>(
        pool_addr: address
    ) acquires PoolInfo {
        use nucleus::price_provider::get_price;

        let a_price = get_price<A>();
        let b_price = get_price<B>();

        let max_price_deviation = borrow_global<PoolInfo>(pool_addr).parameters.max_price_deviation;

        if (b_price > a_price) {
            let d = decimal::div(decimal::from_u64(b_price - a_price), decimal::from_u64(b_price));

            assert!(decimal::is_le(d, max_price_deviation), error::invalid_state(EPRICE_DEV));
        } else {
            let d = decimal::div(decimal::from_u64(a_price - b_price), decimal::from_u64(a_price));

            assert!(decimal::is_le(d, max_price_deviation), error::invalid_state(EPRICE_DEV));
        };
    }

    fun get_equilibrium_coverage_ratio(pool_addr: address): Decimal acquires PoolInfo {
        let total_cash = decimal::zero();
        let total_liability = decimal::zero();

        let pool = borrow_global<PoolInfo>(pool_addr);

        let i = 0;
        while (i < vector::length(&pool.coins)) {
            let coin = *vector::borrow(&pool.coins, i);

            let decimals = *table::borrow(&pool.decimals, coin);

            let price = decimal::from_decimal_u64(nucleus::price_provider::get_price_by_name(coin), decimals);

            let cash = decimal::mul(decimal::from_decimal_u64(*table::borrow(&pool.balances, coin), decimals), price);
            let liability = decimal::mul(decimal::from_decimal_u64(*table::borrow(&pool.liabilities, coin), decimals), price);
        
            total_cash = decimal::add(total_cash, cash);
            total_liability = decimal::add(total_liability, liability);

            i = i + 1;
        };

        // if there are no liabilities or no assets in the pool, return equilibrium state = 1
        if (decimal::is_eq(total_cash, decimal::zero()) || decimal::is_eq(total_liability, decimal::zero())) {
            return decimal::one()
        };

        decimal::div(total_cash, total_liability)
    }

    fun init_lp<C>(account: &signer): LPToken<C> {
        let name = coin::name<C>();
        string::append_utf8(&mut name, b" Nucleus LP");

        let symbol = coin::symbol<C>();
        string::append_utf8(&mut symbol, b" NLP");

        let decimals = coin::decimals<C>();

        let (burn_c, freeze_c, mint_c) = coin::initialize<LP<C>>(
            account,
            name,
            symbol,
            decimals,
            true
        );


        LPToken {
            mint_c,
            freeze_c,
            burn_c,
        }
    }

    fun destroy_lp<C>(lp_token: LPToken<C>) {
        let LPToken {
            mint_c,
            freeze_c,
            burn_c,
        } = lp_token;

        coin::destroy_burn_cap(burn_c);
        coin::destroy_freeze_cap(freeze_c);
        coin::destroy_mint_cap(mint_c);
    }

    fun mint_lp<C>(pool_addr: address, to: address, amount: u64) acquires LiquidisedAsset {        
        let lp_token = &borrow_global<LiquidisedAsset<C>>(pool_addr).lp_token;

        coin::deposit<LP<C>>(
            to,
            coin::mint<LP<C>>(amount, &lp_token.mint_c)
        );
    }

    fun burn_lp<C>(pool_addr: address, from: &signer, amount: u64) acquires LiquidisedAsset {
        let lp_token = &borrow_global<LiquidisedAsset<C>>(pool_addr).lp_token;

        coin::burn<LP<C>>(
            coin::withdraw<LP<C>>(from, amount), 
            &lp_token.burn_c
        );
    }

    fun transfer_lp<C>(from: &signer, to: address, amount: u64) {
        coin::transfer<LP<C>>(from, to, amount);
    }

    fun register_lp<C>(account: &signer) {
        if (!coin::is_account_registered<LP<C>>(signer::address_of(account))) {
            coin::register<LP<C>>(account);
        };
    }


    // fun internal_deposit<C>(
    //     pool_addr: address,
    //     amount: u64,
    //     to: address,
    // ): Decimal acquires LiquidisedAsset, PoolInfo {
    //     let asset = borrow_global_mut<LiquidisedAsset<C>>(pool_addr);
    //     let pool = borrow_global_mut<PoolInfo>(pool_addr);
        
    //     let decimals = coin::decimals<C>();

    //     let amount = decimal::from_decimal_u64(amount, decimals);

    //     let total_supply = get_total_supply<C>();

    //     let cash = decimal::from_decimal_u64(coin::balance<C>(pool_addr), decimals);
    //     let liability = decimal::from_decimal_u64(asset.liability, decimals);
    
    //     let fee = utils::deposit_fee(
    //         pool.parameters.k, 
    //         pool.parameters.n, 
    //         pool.parameters.c1, 
    //         pool.parameters.x_threshold,
    //         cash,
    //         liability,
    //         amount
    //     ); 

    //     if(decimal::is_gt(fee, amount)){
    //         fee = decimal::from_decimal_u64(0,0);
    //     };
    //     if(decimal::is_eq(fee, amount)){
    //         fee = decimal::from_decimal_u64(0,0);
    //     };
            

    //     // Calculate amount of LP to mint : ( deposit - fee ) * TotalAssetSupply / Liability
    //     let liquidity = if (decimal::is_eq(liability, decimal::zero())) {
    //         decimal::sub(amount, fee)
    //     } else {
    //         decimal::div(decimal::mul(decimal::sub(amount, fee), total_supply), liability)
    //     };

    //     let _ = pool;
    //     // let eq_cov = get_equilibrium_coverage_ratio(pool_addr);
    //     let eq_cov = decimal::one();

    //     let pool = borrow_global_mut<PoolInfo>(pool_addr);


    //     if (decimal::is_lt(eq_cov, decimal::one())) {
    //         liquidity = decimal::div(liquidity, eq_cov);
    //     };
    //     if(decimal::is_eq(liquidity,decimal::zero())){
    //         liquidity = amount;
    //     };

    //     assert!(decimal::is_gt(liquidity, decimal::zero()), error::resource_exhausted(EINSUFFICIENT_LIQ_MINT));

    //     // update stored data

    //     let (_, _) = (pool, asset);

    //     update_balance<C>(pool_addr, decimal::decimal_repr(amount, decimals), true);
        
    //     update_liability<C>(pool_addr, decimal::decimal_repr(decimal::sub(amount, fee), decimals), true);

        

    //     mint_lp<C>(pool_addr, to, decimal::decimal_repr(liquidity, decimals));

    //     liquidity
    // }

    /// Deposits amount of tokens into pool ensuring deadline
    // public entry fun deposit<C>(
    //     account: &signer,
    //     pool_addr: address,
    //     amount: u64,
    //     deadline: u64,
    // ) acquires LiquidisedAsset, PoolInfo, Deposit {
    //     assert_deadline(deadline);
    //     assert_is_pool(pool_addr);
    //     assert_is_active(pool_addr);
    //     assert_has_token<C>(pool_addr);

    //     // register the account for the LP token if needed
    //     register_lp<C>(account);

    //     assert!(amount > 0, error::invalid_argument(EZERO_AMOUNT));

    //     coin::transfer<C>(account, pool_addr, amount);
    //     move_to<Deposit>(account, Deposit{cash: amount,liability: amount, totalsupply: amount, fee: amount});
    //      let to_cs = borrow_global_mut<Deposit>(owner);
    //      let to_css = borrow_global_mut<Deposit>(owner);
    //       let to_lp = borrow_global_mut<Deposit>(owner);
    //      if(or(cash == 0 , liability == 0))
    //      to_cs.liquidity = amount;
    //      else(
    //         //   depositFee(cash,liability),
    //         to_cs.liquidity=amount - fee;
    //      )
        
    //     //  App.globalPut(Bytes("cashAdded"), cash + amount), 
    //     // App.globalPut(Bytes("Liability"), (liability) + (amount - fee.load())),
    //     // App.globalPut(Bytes("Totalsupply"),totalsupply+(liquidity.load())),
    //     if(lp.hasvalue())
    //     //  .Then(App.localPut(Int(0), Bytes("USDCe"),userLP.value() + liquidity.load()))
    //     // .Else(App.localPut(Int(0), Bytes("USDCe"), liquidity.load())),

    //     let liquidity = internal_deposit<C>(pool_addr, amount, signer::address_of(account));

    //     let decimals = coin::decimals<C>();

    //     event::emit_event(&mut borrow_global_mut<PoolInfo>(pool_addr).deposit_events, DepositEvent {
    //         pool_addr,
    //         by: signer::address_of(account),
    //         amount,
    //         liquidity: decimal::decimal_repr(liquidity, decimals),
    //         decimals,
    //         asset: coin::name<C>()
    //     });
    // }
// public entry fun depositfee()acquires Deposit{
// let coverageratio1 = cash*1000/liability
// }
   public entry fun deposit<C>(account: &signer, pool_addr: address,amount: u64)  acquires Deposit,PoolInfo {
  coin::transfer<C>(account,pool_addr,amount); //transaction
   let owner = signer::address_of(account);
  let pool = borrow_global<PoolInfo>(pool_addr); //global-pool,pool_signer
  let pool_signer = account::create_signer_with_capability(&pool.signer_cap);
 
 
 
    if (!exists<Deposit>(pool_addr)){ //store
        move_to<Deposit>(&pool_signer, Deposit{cash: amount, liability:amount});
    }
    else{
         let to_check = borrow_global_mut<Deposit>(pool_addr); //amount update

    
        //  if(amount>0)
		 to_check.liability=amount;
		 to_check.cash=amount;
    };
	
  }


//  if (!exists<LiquidisedAsset<C>>(pool_addr))
//  if (!exists<Pools>(signer::address_of(owner)))

   public entry fun withdraw<C>(account: &signer, pool_addr: address,amount: u64)  acquires Deposit,PoolInfo {
     
     let addr = signer::address_of(account);
    let pool = borrow_global<PoolInfo>(pool_addr);
  let pool_signer = account::create_signer_with_capability(&pool.signer_cap);
  coin::transfer<C>(&pool_signer,addr,amount);
  let owner = signer::address_of(account);
  let to_check = borrow_global_mut<Deposit>(pool_addr); 
 	 to_check.liability=to_check.liability-amount;
	 to_check.cash= to_check.cash - amount;
         
       
	//
 }

 }
	

