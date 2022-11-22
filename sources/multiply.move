module hlo::sample{

    // module contents
   use std::debug;   
   use std::signer;

   struct Value has key,store,copy,drop{   
       calc:u64,
       minus:u64

   }
     
    public entry fun mul(a: u64, b: u64): u64 {        
        a * b
        

    }
      
    public fun sub(a: u64, b: u64): u64 {
        a - b
    }
//  #[test]
    public entry fun test_sum(account: &signer) {
         let c= mul(5,3);
         debug::print(&c);
        
        let d= sub(6,2);
        debug::print(&d);
        // let _k = Value{
        //     add:c,
        //     div:d
        //   };
         move_to<Value>(account, Value {
            calc:c,
            minus:d
        })
     
  }

}