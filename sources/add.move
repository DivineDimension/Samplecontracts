module sender::sample{

    // module contents
   use std::debug;

   struct Value has store,copy,drop{
       add:u64,
       div:u64

   }
     
    public entry fun sum(a: u64, b: u64): u64 {
        a + b
        

    }
      
    public fun division(a: u64, b: u64): u64 {
        a / b
    }
 #[test]
    public entry fun test_sum() {
         let c= sum(5,5);
         debug::print(&c);
        
        let d= division(10,2);
        debug::print(&d);
        let _k = Value{
            add:c,
            div:d

         };

     
         
    }

}