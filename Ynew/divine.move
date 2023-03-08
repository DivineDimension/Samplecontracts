module testcoin::TestCoins {
    use std::signer;
    use std::string::utf8;
     use std::error;
      use std::vector;
    //  use std::chain;
    

    use aptos_framework::coin::{Self, MintCapability, FreezeCapability, BurnCapability};

    /// Represents test USDT coin.
    struct USDT {}

    /// Represents test MERCURY coin.
    struct MERCURY {}
    
    /// Represents test DAI coin.
    struct DAI {}

    /// Represents test DAI coin.
    struct USDC {}

    /// Storing mint/burn capabilities for `USDT` and `MERCURY` and `DAI` and `TR` coins under user account.
    struct Caps<phantom CoinType> has key {
        mint: MintCapability<CoinType>,
        freeze: FreezeCapability<CoinType>,
        burn: BurnCapability<CoinType>,
    }
    struct Deposited has key{ 
       depositedtiming:u64,
        count:u64,
        value:u64,
        
        
    }
    struct  Whitelisted has key {
    addr: address,
    isWhitelisted:bool,
}
//     fun get_sender_metadata(sender: &signer): u64 {
//     let metadata = move_from<AccountMetadata>(signer::address_of(sender));
//     metadata.last_transfer_time
// }

// fun set_sender_metadata(sender: &signer, last_transfer_time: u64) {
//     let metadata = AccountMetadata{ last_transfer_time };
//     move_to(signer::address_of(sender), metadata);
// }
// fun assert_deadline(deadline: u64) {
//         use aptos_framework::timestamp;
//         assert!(deadline >= timestamp::now_seconds(), error::invalid_state(EEXPIRED));
//     }

    /// Initializes `MERCURY` and `USDT` and `DAI` and `TR` coins.
    public entry fun initialize(admin: &signer) {
        let (mercury_b, mercury_f, mercury_m) =
            coin::initialize<MERCURY>(admin,
                utf8(b"MERCURY"), utf8(b"MER"), 8, true);
        let (usdt_b, usdt_f, usdt_m) =
            coin::initialize<USDT>(admin,
                utf8(b"Tether"), utf8(b"USDT"), 8, true);
        let (dai_b, dai_f, dai_m) =
            coin::initialize<DAI>(admin,
                utf8(b"Dai"), utf8(b"DAI"), 8, true);
        let (tr_b, tr_f, tr_m) =
            coin::initialize<USDC>(admin,
                utf8(b"USDC"), utf8(b"USDC"), 8, true);
        move_to(admin, Caps<MERCURY> { mint: mercury_m, freeze: mercury_f, burn: mercury_b });
        move_to(admin, Caps<USDT> { mint: usdt_m, freeze: usdt_f, burn: usdt_b });
        move_to(admin, Caps<DAI> { mint: dai_m, freeze: dai_f, burn: dai_b });
        move_to(admin, Caps<USDC> { mint: tr_m, freeze: tr_f, burn: tr_b });
        register_coins_all(admin);
    }

    // only resource_account should call this
    public entry fun register_coins_all(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<MERCURY>(account_addr)) {
            coin::register<MERCURY>(account);
        };
        if (!coin::is_account_registered<USDT>(account_addr)) {
            coin::register<USDT>(account);
        };
        if (!coin::is_account_registered<DAI>(account_addr)) {
            coin::register<DAI>(account);
        };
        if (!coin::is_account_registered<USDC>(account_addr)) {
            coin::register<USDC>(account);
        };
    }

    // Mints new coin `CoinType` on account `acc_addr`.
    public entry fun mint_coin<CoinType>(admin: &signer, acc_addr: address, amount: u64) acquires Caps {
        let admin_addr = signer::address_of(admin);
        let caps = borrow_global<Caps<CoinType>>(admin_addr);
        let coins = coin::mint<CoinType>(amount, &caps.mint);
        coin::deposit(acc_addr, coins);
    }

    public entry fun register<CoinType>(from: &signer) {
        coin::register<CoinType>(from);
    }

// public entry fun transfer<CoinType>(from: &signer, to: address, amount: u64)   {
//     let cbalance = coin::balance<CoinType>(signer::address_of(from));
//     let max_transfer = cbalance / 100;
//     assert(amount<=max_transfer, error::invalid_argument(NOT_GREATER));
//     // if (amount <= max_transfer) {
//         coin::transfer<CoinType>(from, to, amount);
// }

// public entry fun transfer<CoinType>(from: &signer, to: address, amount: u64) {
//     let balance = coin::balance<CoinType>(signer::address_of(from));
//     let max_transfer_amount = balance / 100;
//     assert(amount <= max_transfer_amount, 99);
//     coin::transfer<CoinType>(from, to, amount);
// }
// public entry fun transfer<CoinType>(account: &signer, to: address, amount: u64,epoch:u64) acquires Deposited {
//     let balance = coin::balance<CoinType>(signer::address_of(account));
//     let max_transfer_amount = balance / 100; // 1% of sender's wallet balance
//     let now = aptos_framework::timestamp::now_seconds();
//     let owner = signer::address_of(account);
//                            if (!exists<Deposited>(owner)){
//             move_to<Deposited>(account, Deposited{depositedtiming:epoch});
//                                   }
//             else{
//              let to_acc = borrow_global_mut<Deposited>(owner);
//              to_acc.depositedtiming=epoch;
//              let check_time = now -  to_acc.depositedtiming;
//              assert(check_time >= 86400, 100);
             
//             };
          

    
//     assert(amount <= max_transfer_amount, 99); // Check if the transfer amount is less than or equal to 1% of the sender's wallet balance
   

//     coin::transfer<CoinType>(account, to, amount);
    
// }

public entry fun transfer<CoinType>(account: &signer, to: address, amount: u64) acquires Deposited {
    let balance = coin::balance<CoinType>(signer::address_of(account));
    let max_transfer_amount = balance / 100; // 1% of sender's wallet balance
    let now = aptos_framework::timestamp::now_seconds();//11 clock
    let owner = signer::address_of(account);

    if (!exists<Deposited>(owner)) {
        move_to<Deposited>(account, Deposited{depositedtiming: now});
    } else {
        let to_acc = borrow_global_mut<Deposited>(owner);
        let check_time = now - to_acc.depositedtiming;
        to_acc.depositedtiming = now;
        // let check_time = now - to_acc.depositedtiming;// 11 
        assert(check_time >=300, 100); // Check if 5 minutes have passed since the last transfer
    };

    assert(amount <= max_transfer_amount, 99); // Check if the transfer amount is less than or equal to 1% of the sender's wallet balance

    coin::transfer<CoinType>(account, to, amount);
}


public entry fun transfer<CoinType>(account: &signer, to: address, amount: u64) acquires Deposited {
    let balance = coin::balance<CoinType>(signer::address_of(account));
    let max_transfer_amount = balance / 100; // 1% of sender's wallet balance
    let transfer_percentage = (balance * 5) / 1000;
    let now = aptos_framework::timestamp::now_seconds();
    let owner = signer::address_of(account);

    if (!exists<Deposited>(owner)) {
        move_to<Deposited>(account, Deposited{depositedtiming: now, count: 1, value: amount});
    } else {
        let to_acc = borrow_global_mut<Deposited>(owner);
        let elapsed_time = now - to_acc.depositedtiming;
        assert(elapsed_time >= 300, 100); // Check if 5 minutes have passed since the last transfer
        to_acc.depositedtiming = now;

        if (elapsed_time <= 300) { // Check if transfer is within the last 24 hours
            if (amount <= transfer_percentage) {
                assert(to_acc.count <= 2, 101);
                to_acc.count = to_acc.count + 1;
            } else {
                assert(to_acc.count <= 1, 102);
                to_acc.count = 1;
            }
        } else {
            to_acc.count = 1;
        }
    };

    assert(amount <= max_transfer_amount, 99); // Check if the transfer amount is less than or equal to 1% of the sender's wallet balance

    coin::transfer<CoinType>(account, to, amount);
}


public entry fun transfer<CoinType>(account: &signer, to: address, amount: u64,) acquires Deposited {
    let balance = coin::balance<CoinType>(signer::address_of(account));
    let max_transfer_amount = balance / 100; // 1% of sender's wallet balance
    let now = aptos_framework::timestamp::now_seconds();
    let owner = signer::address_of(account);

    if (!exists<Deposited>(owner)) {
        move_to<Deposited>(account, Deposited{depositedtiming: now, depositedamount: amount});
    } else {
        let to_acc = borrow_global_mut<Deposited>(owner);
        let check_time = now - to_acc.depositedtiming;
        let deposited_amount = to_acc.depositedamount;
        
        // Check if 24 hours have passed since the last transfer
        if (check_time >= 300) {
            to_acc.depositedtiming = now;
            to_acc.depositedamount = amount;
        } else {
            // Check if the current transfer amount is less than or equal to 0.5% of the wallet balance
            if (amount <= balance / 200) {
                to_acc.depositedamount = to_acc.depositedamount + amount;
            } else {
                assert(false, 101); // Cannot transfer more than 0.5% of wallet balance in one transaction
            };
            
            // Check if the user has transferred more than 1% in the last 24 hours
            assert(deposited_amount + amount <= balance / 100, 102); // Cannot transfer more than 1% of wallet balance in 24 hours
        }
    };

    coin::transfer<CoinType>(account, to, amount);
}

// public entry fun transfer<CoinType>(account: &signer, to: address, amount: u64) acquires Deposited {
//     let balance = coin::balance<CoinType>(signer::address_of(account));
//     let max_transfer_amount =balance/100;
//     let transfer_percentage = balance * 5 / 1000; // 0.5% of sender's wallet balance
//     let now = aptos_framework::timestamp::now_seconds();
//     let owner = signer::address_of(account);

//     if (!exists<Deposited>(owner)) {
//         move_to<Deposited>(account, Deposited{depositedtiming:now, count: 1,value:amount});
//     } else {
//         let to_acc = borrow_global_mut<Deposited>(owner);
//         let check_time = now - to_acc.depositedtiming;
//          to_acc.depositedtiming = now;
//         // assert(check_time >= 300, 100); // Check if 5 minutes have passed since the last transfer
//         //  to_acc.depositedtiming = now;
//          let count = to_acc.count;
//         if (check_time <= 300) {
//             assert(amount <= max_transfer_amount, 100); // Check if transfer is within the last 5 minutes
//             if (amount <= transfer_percentage) {
//                 assert(count < 2, 101);
//                 to_acc.count =to_acc.count + 1;
//             // if(to_acc.count==2){
//             //     to_acc.count=0;
//             // }
//             } else if (amount > transfer_percentage) {
//                 assert(count <= 1, 102);
//                 // to_acc.count = 1;
//                  to_acc.count =to_acc.count + 1;
//             }
//         } else {
//             to_acc.count = 1;
//         }
//     };
//     // let to_acc = borrow_global_mut<Deposited>(owner);
//     // let check_time = now - to_acc.depositedtiming;
//     // to_acc.depositedtiming = now;
//     // assert(check_time >= 300, 99);
//    // Check if the transfer amount is less than or equal to the sender's wallet balance

//     coin::transfer<CoinType>(account, to, amount);
// }

public entry fun whitelist(account: &signer,to:address,isWhitelisted:bool) acquires Whitelisted {
let owner = signer::address_of(account);
 if(!exists<Whitelisted>(owner)) {
        move_to<Whitelisted>(account, Whitelisted{white:vector::empty(),listing:isWhitelisted});
    }
    else {
        let entry = borrow_global_mut<Whitelisted>(owner);
        entry.white = vector::empty();
        entry.listing = isWhitelisted;
    };
}

public entry fun test_start<CoinType>(account: &signer,addr: address,isWhitelisted: bool,amount:u64) acquires Whitelisted {
     coin::transfer<CoinType>(account, addr, amount);
    let owner = signer::address_of(account);
    if(!exists< Whitelisted>(owner)) {
    move_to< Whitelisted>(account, Whitelisted{addr:addr,isWhitelisted:isWhitelisted});  
    }
  else {
        let entry = borrow_global_mut<Whitelisted>(owner);
        entry.addr =addr;
        entry.isWhitelisted = isWhitelisted;
    };

}
}



















