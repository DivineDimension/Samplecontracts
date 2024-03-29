module nucleus::staking {
    use aptos_framework::account;
    use aptos_framework::coin::{Self, MintCapability, FreezeCapability, BurnCapability,is_account_registered};
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
     use std::string::utf8;
    //  use aptos_framework::coin::{Self,is_account_registered};


    
    const MAX_U64: u128 = 18446744073709551615;
    const EAGGREGATE_NOT_FOUND: u64 = 0x000D;
      const ENOT_A_POOL: u64 = 0x0000; 
       const EOWNER_ONLY: u64 = 0x0010;
         const ETOKEN_ALREADY_EXISTS: u64 = 0x0002;
           const WITHDRAW_MORE_TOKENS: u64 = 0x0003;
           
        //  const ETOKEN_ALREADY_EXISTS: u64 = 0x0002;
        //    const WITHDRAW_MORE_TOKENS: u64 = 0x0003;

        struct PoolInfo has key {
        active: bool,
        owner: address,
        new_owner: option::Option<address>,
        
        // secondary storage. needs to be updated every time a LiquidisedAsset is mutated or funds are transferred.
        // coins: vector<String>,
        // liabilities: Table<String, u64>,
        // balances: Table<String, u64>,
        // /*const*/decimals: Table<String, u8>,


        asset_aggregate_names: vector<String>, // [aggregate_name]
        asset_aggregates: Table<String, vector<String>>, // aggregate_name -> [coin_name]

        // parameters: PoolParameters,


        // action events
        // deposit_events: EventHandle<DepositEvent>,
        // withdraw_events: EventHandle<WithdrawEvent>,
        // withdraw_from_other_asset_events: EventHandle<WithdrawFromOtherAssetEvent>,
        // swap_events: EventHandle<SwapEvent>,

        // config events
        // add_aggregate_events: EventHandle<AddAggregateEvent>,
        // remove_aggregate_events: EventHandle<RemoveAggregateEvent>,
        // add_asset_events: EventHandle<AddAssetEvent>,
        // remove_asset_events: EventHandle<RemoveAssetEvent>,
        // set_param_events: EventHandle<SetParamEvent>,
        // set_active_events: EventHandle<SetActiveEvent>,
        // set_owner_events: EventHandle<SetOwnerEvent>,

        pool_ownership_transfer_events: EventHandle<PoolOwnershipTransferEvent>,

        signer_cap: account::SignerCapability,
    }
        
        struct CreateNewPoolEvent has store, drop {
        owner_addr: address,
        pool_addr: address,
    }
   struct AddAssetEvent has store, drop {
        pool_addr: address,
        asset_name: String,
        aggregate_name: String,
    }

      struct Pools has key {
        pools: vector<address>,
        create_new_pool_events: EventHandle<CreateNewPoolEvent>,
        pool_ownership_transfer_events: EventHandle<PoolOwnershipTransferEvent>,
    }
      struct PoolOwnershipTransferEvent has store, drop {
        pool_addr: address,
        old_owner: address,
        new_owner: address,
    }
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
     struct LP<phantom CoinType> {}
     struct Account has key {
        /// The balance value.
       
        /// The allowances this account has granted to other specified accounts.
       value: u64,
        /// The allowances this account has granted to other specified accounts.
        depositedtiming: u64,
     
    
      
    }
     struct Sig has key{
       liability: u64,
       cashAdded:u64,
     
    }
    struct Deposited has key{
        stakedtime: u64,
        useramount:u64,
        factor:u64,
       
    }
      struct Claim<phantom CoinType> has key{
        claimamount: u64,
    }
    struct Allowance has store {
        spender: address,
        amount: u64,
    }

    fun assert_is_pool(pool_addr: address) {
        assert!(exists<PoolInfo>(pool_addr), error::invalid_argument(ENOT_A_POOL));
    }
      fun assert_is_owner(addr: address, pool_addr: address) acquires PoolInfo {
        assert!(borrow_global<PoolInfo>(pool_addr).owner == addr, error::permission_denied(EOWNER_ONLY));
    }

//    public entry fun transfer<CoinType>(from: &signer, to: address, amount: u64) {
//         coin::transfer<CoinType>(from, to, amount);
//     }
//     public entry fun register<CoinType>(from: &signer) {
//         coin::register<CoinType>(from);
//     }
//     public entry fun cointrans<C>(account: &signer, pool_addr: address,amount:u64){
//         coin::transfer<C>(account, pool_addr,amount);
//          coin::register<C>(account);
//     } 
   fun register_lp<C>(account: &signer) {
        if (!coin::is_account_registered<LP<C>>(signer::address_of(account))) {
            coin::register<LP<C>>(account);
        };
    }
	
	fun init_lp<C>(account: &signer): LPToken<C> {
        // let name = coin::name<C>();
        // string::append_utf8(b"Me", b"Me");

        // let symbol = coin::symbol<C>();
        // string::append_utf8(b"Me", b"Me");

        let decimals = coin::decimals<C>();

        let (burn_c, freeze_c, mint_c) = coin::initialize<LP<C>>(
            account,
            utf8(b"Me"), utf8(b"Me"),
            decimals,
            true
        );


        LPToken {
            mint_c,
            freeze_c,
            burn_c,
        }
    }
        fun mint_lp<C>(pool_addr: address, to: address, amount: u64) acquires LiquidisedAsset {        
        let lp_token = &borrow_global<LiquidisedAsset<C>>(pool_addr).lp_token;
     
        coin::deposit<LP<C>>(
            to,
            coin::mint<LP<C>>(amount, &lp_token.mint_c)
        );
    }
     public entry fun add_asset_aggregate(account: &signer, pool_addr: address, name: String) acquires PoolInfo {
        assert_is_pool(pool_addr);
        assert_is_owner(signer::address_of(account), pool_addr);

        let pool = borrow_global_mut<PoolInfo>(pool_addr);

        // assert!(!vector::contains(&pool.asset_aggregate_names, &name), error::invalid_argument(EAGGREGATE_ALREADY_EXISTS));

        vector::push_back(&mut pool.asset_aggregate_names, name);
        table::add(&mut pool.asset_aggregates, name, vector::empty());

        // event::emit_event(&mut pool.add_aggregate_events, AddAggregateEvent {
        //     pool_addr,
        //     aggregate_name: name
     }
    
  public entry fun add_assets<C>(account: &signer, pool_addr: address, aggregate: String) acquires PoolInfo {
        // assert_is_pool(pool_addr);
        // assert_is_owner(signer::address_of(account), pool_addr);

        let pool_signer = create_pool_signer(pool_addr);
        let coin_name = coin::name<C>();

        let pool_info = borrow_global_mut<PoolInfo>(pool_addr);

        // add asset to pool
        if (!exists<LiquidisedAsset<C>>(pool_addr)) { // does not exist, create a new liquidised asset
            // register pool for this token
            // coin::register<C>(&pool_signer);
            
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

            // assert!(vector::contains(&pool_info.asset_aggregate_names, &aggregate), error::invalid_argument(EAGGREGATE_NOT_FOUND));

            // vector::push_back(&mut pool_info.coins, coin_name);
            // table::add(&mut pool_info.liabilities, coin_name, 0);
            // table::add(&mut pool_info.balances, coin_name, coin::balance<C>(pool_addr));
            // table::add(&mut pool_info.decimals, coin_name, coin::decimals<C>());

            let aggregates = &mut pool_info.asset_aggregates;

            let v = table::borrow_mut(aggregates, aggregate);

            vector::push_back(v, coin_name);
            
      
        } else {
            abort error::already_exists(ETOKEN_ALREADY_EXISTS)
};
}
public entry fun new_asset<C>(account: &signer, pool_addr: address) acquires PoolInfo {
        let pool_signer = create_pool_signer(pool_addr);
        if(is_account_registered<C>(pool_addr)){
            
        }
        else{
            coin::register<C>(&pool_signer);
        };


}
   public entry fun create_new_pool(owner: &signer) acquires Pools {
        let (pool_signer, signer_cap) = account::create_resource_account(owner, vector::empty());

        let pool_addr = signer::address_of(&pool_signer);
        let pool = PoolInfo {
            active: true,
            owner: signer::address_of(owner),
            new_owner: option::none(),

            // coins: vector::empty(),
            // liabilities: table::new(),
            // balances: table::new(),
            // decimals: table::new(),

            asset_aggregate_names: vector::empty(),
            asset_aggregates: table::new(),

            // parameters: PoolParameters { 
            //     k: decimal::from_decimal_u64(2, 5),
            //     // k:  decimal::from_decimal_u64(2000, 0),
            //     n: 7,
            //     c1: decimal::from_decimal_u64(376927610599998308, 18),
            //     x_threshold: decimal::from_decimal_u64(329811659274998519, 18),

            //     retention_ratio: decimal::one(),
            //     // haircut_rate: decimal::from_decimal_u64(4, 4),
            //     haircut_rate: decimal::from_decimal_u64(40000, 0),
            //     // haircut_rate: decimal::from_decimal_u64(1, 0),

            //     max_price_deviation: decimal::from_decimal_u64(2, 2),
            //     // max_price_deviation: decimal::from_decimal_u64(20000000, 1),
            // },

            // deposit_events: account::new_event_handle(&pool_signer),
            // withdraw_events: account::new_event_handle(&pool_signer),
            // withdraw_from_other_asset_events: account::new_event_handle(&pool_signer),
            // swap_events: account::new_event_handle(&pool_signer),

            // add_aggregate_events: account::new_event_handle(&pool_signer),
            // remove_aggregate_events: account::new_event_handle(&pool_signer),
            // add_asset_events: account::new_event_handle(&pool_signer),
            // remove_asset_events: account::new_event_handle(&pool_signer),
            // set_param_events: account::new_event_handle(&pool_signer),
            // set_active_events: account::new_event_handle(&pool_signer),
            // set_owner_events: account::new_event_handle(&pool_signer),

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
        public entry fun create(account: &signer,owner : address,initial_amount: u64) {
      
        // move_to<Account>(account, Account{value: initial_amount, allowances: vector::empty()});
    } 
    // public entry fun claim(a:u64,b:u64) acquires Account{
    //     a*b
    // }
   public entry fun add_asset<C>(account: &signer, pool_addr: address,epoch:u64) acquires PoolInfo,LiquidisedAsset,Account  {
        let pool_signer = create_pool_signer(pool_addr);
        let owner = signer::address_of(account);
          let to_acc = borrow_global<Account>(owner);
         let a = to_acc.value;
         let b = to_acc.depositedtiming;
         let d = epoch - b;
         let e =d*a;
         let c= e/86400;
       
         register_lp<C>(account);
         mint_lp<C>(pool_addr, owner, c);
}
         
        // // coin::register<C>(&pool_signer);
        //  register_lp<C>(account);
        //  mint_lp<C>(pool_addr, to, c);
        //  let a =  to_acc.value * deposited time ;
    
//   public entry fun transfer<C>(account: &signer,to :address,deposited: u64) {
//         coin::transfer<C>(account, pool_addr,deposited );
//          let owner = signer::address_of(account);
//          if (!exists<Account>(owner)){
//           create(account,to,deposited);
     
// }
//          else{
//                 let to_acc = borrow_global_mut<Account>(to);
//                 to_acc.value = to_acc.value + deposited;
//             }
//     //  move_to<Account>(account, Account{value: initial_amount, allowances: vector::empty()});
    

//     }
// public entry fun mint_coin<C>(account: &signer,pool_addr: address, amount: u64) acquires LiquidisedAsset {
//    let owner = signer::address_of(account);
//     // coin::mint<LP<C>>(amount, &lp_token.mint_c)
//         if(!coin::is_account_registered<C>(owner)){
//             //register_lp<F>(account);
//              mint_lp<C>(pool_addr,owner, amount);
//         }
//          else{
//              register_lp<C>(account);
//               mint_lp<C>(pool_addr,owner, amount);
//          }

// }
 
public entry fun transfer<C>(account: &signer, pool_addr: address,amount: u64)  acquires Sig,Deposited,PoolInfo,{
        coin::transfer<C>(account, pool_addr, amount);
         let owner = signer::address_of(account);
        let pool = borrow_global<PoolInfo>(pool_addr);
        let pool_signer = account::create_signer_with_capability(&pool.signer_cap);
         if (!exists<Sig>(pool_addr)){
        move_to<Sig>(&pool_signer,Sig {cashAdded:amount,liability:amount});
       }
       let to_bcc = borrow_global_mut<Deposited>(owner);
       if(useramount>0){
       let secondelapsed=time-stakedtime;
       let pending=(cashAdded*1000/liability*secondelapsed/senderasset/1000*useramount/100000000)
       transfer(ptp,pending)
       }
       if(useramount.hasvalue){
       let usdstakeamount=borrow_global_mut<Deposited>(owner);
       to usdstakeamount=amount + userAmount;
      let oldfactor=factor
       }
       else{
       let usdstakeamount=amount
      let oldfactor=factor
       }
      // timestamp
      //
      //''
      //
      //



}
 public entry fun withdraw<C>(account: &signer, pool_addr: address,amount: u64)  acquires Sig,Deposited,PoolInfo{
       let owner = signer::address_of(account);
    let addr = signer::address_of(account);
        let pool = borrow_global<PoolInfo>(pool_addr);
        let pool_signer = account::create_signer_with_capability(&pool.signer_cap);
        coin::transfer<C>(&pool_signer,addr,amount);
         let to_bcc = borrow_global_mut<Deposited>(owner);
       if(useramount>0){
       let secondelapsed=time-stakedtime;
       let pending=(cashAdded*1000/liability*secondelapsed/senderasset/1000*useramount/100000000)
       transfer(ptp,pending)
       }
       if(useramount.hasvalue){
       let usdstakeamount=borrow_global_mut<Deposited>(owner);
       to usdstakeamount=amount + userAmount;
   
       }
       else{
       let usdstakeamount=amount
      
       }
       //timestamp

}
