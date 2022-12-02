module nucleus::decimal {
    use std::error;
    use nucleus::u256;
    use nucleus::u256::U256;


    /***********/
    /* Structs */
    /***********/

    /// This struct is used to store values of currencies and fees.
    struct Decimal has store, copy, drop {
        value: U256,
        decimals: u8,
    }


    /*************/
    /* Constants */
    /*************/

    const MAX_U64: u128 = 18446744073709551615;
    const MAX_U8: u64   = 255;

    /**********/
    /* Errors */
    /**********/

    /// A calculation resulted in a value that requires more than 255 decimals.
    const ETOO_MANY_DECIMALS: u64 = 0x01;


    /*************/
    /* Functions */
    /*************/

    /// Returns the number zero.
    public fun zero(): Decimal {
        Decimal {
            value: u256::zero(),
            decimals: 0,
        }
    }

    /// Returns the number one.
    public fun one(): Decimal {
        Decimal {
            value: u256::from_u64(1),
            decimals: 0,
        }
    }

    /// Transforms the given integer into a Decimal representing it.
    public fun from_u64(x: u64): Decimal {
        Decimal {
            value: u256::from_u64(x),
            decimals: 0,
        }
    }

    /// Transforms the given integer into a Decimal representing it.
    public fun from_u128(x: u128): Decimal {
        Decimal {
            value: u256::from_u128(x),
            decimals: 0
        }
    }

    /// Transforms the given integer into a Decimal representing it with the
    /// specified amount of decimal places.
    public fun from_integer_u64(x: u64, decimals: u8): Decimal {
        with_decimals(from_u64(x), decimals)
    }

    /// Transforms the given integer into a Decimal representing it with the
    /// specified amount of decimal places.
    public fun from_integer_u128(x: u128, decimals: u8): Decimal {
        with_decimals(from_u128(x), decimals)
    }

    /// Transforms a decimal represented integer (such as the return value of 
    /// coin::balance), into a Decimal representing it with the specified amount
    /// of decimal places.
    public fun from_decimal_u64(x: u64, decimals: u8): Decimal {
        Decimal {
            value: u256::from_u64(x),
            decimals,
        }
    }

    /// Transforms a decimal represented integer (such as the return value of 
    /// coin::supply), into a Decimal representing it with the specified amount
    /// of decimal places.
    public fun from_decimal_u128(x: u128, decimals: u8): Decimal {
        Decimal {
            value: u256::from_u128(x),
            decimals,
        }
    }

    fun internal_with_decimals(n: U256, d: u8, mul: bool): U256 {
        let ten = u256::from_u64(10);
        
        loop {
            if (d == 0) break;

            if (mul) {
                n = u256::mul(n, ten);
            } else {
                n = u256::div(n, ten);
            };


            d = d - 1;
        };

        n
    }

    /// Converts a Decimal from its original number of decimal places to its new 
    /// number of decimal places.
    public fun with_decimals(n: Decimal, decimals: u8): Decimal {
        if (n.decimals == decimals) return n;

        let positive = decimals > n.decimals;
        let diff = if (positive) decimals - n.decimals else n.decimals - decimals;
        n.decimals = decimals;

        let v = n.value;
        let v = internal_with_decimals(v, diff, positive);

        n.value = v;

        n
    }

    /// Return the integer representation of this Decimal using the new amount of
    /// decimal places.
    /// Use sparingly in contexts with values that require more than 64 buts.
    public fun decimal_repr(n: Decimal, decimals: u8): u64 {
        let n = with_decimals(n, decimals);

        u256::as_u64(n.value)
    }

    /// Create a Decimal from the division of two integers.
    public fun fraction(numerator: u64, denominator: u64): Decimal {
        div(from_u64(numerator), from_u64(denominator))
    }

    /// Get the number of decimal places of the given Decimal.
    public fun decimals(d: Decimal): u8 {
        d.decimals
    }

    /// Get the underlying value of the given Decimal as a u64.
    public fun value_u64(d: Decimal): u64 {
        u256::as_u64(d.value)
    }

    /// Get the underlying value of the given Decimal as a u128.
    public fun value_u128(d: Decimal): u128 {
        u256::as_u128(d.value)
    }

    public fun raw_v0(d: Decimal): u64 {
        u256::get(&d.value, 0)
    }

    public fun raw_v1(d: Decimal): u64 {
        u256::get(&d.value, 1)
    }

    public fun raw_v2(d: Decimal): u64 {
        u256::get(&d.value, 2)
    }

    public fun raw_v3(d: Decimal): u64 {
        u256::get(&d.value, 3)
    }
    

    /// Get the integer value represented by the given Decimal. This function
    /// will truncate anything after the decimal.
    public fun floored(a: Decimal): u64 {
        value_u64(a) / decimal_repr(pow(from_u64(10), (a.decimals as u64)), 0)
    }

    /// Set the decimal places of the two numbers to the larger of the two.
    public fun to_most_decimals(a: Decimal, b: Decimal): (Decimal, Decimal) {
        if (a.decimals > b.decimals) {
            (a, with_decimals(b, a.decimals))
        } else if (a.decimals < b.decimals) {
            (with_decimals(a, b.decimals), b)
        } else {
            (a, b) // same decimals
        }
    }
    
    /// Set the decimal places of the two numbers to the smaller of the two.
    public fun to_least_decimals(a: Decimal, b: Decimal): (Decimal, Decimal) {
        if (a.decimals < b.decimals) {
            (a, with_decimals(b, a.decimals))
        } else if (a.decimals > b.decimals) {
            (with_decimals(a, b.decimals), b)
        } else {
            (a, b) // same decimals
        }
    }

    /// Set the decimal places of the two numbers to the larger of the two, minimised.
    public fun to_most_decimals_and_minimised(a: Decimal, b: Decimal): (Decimal, Decimal) {
        let a = minimised(a);
        let b = minimised(b);
        to_most_decimals(a, b)
    }

    /// Set the decimal places of the two numbers to the smaller of the two, minimised.
    public fun to_least_decimals_and_minimised(a: Decimal, b: Decimal): (Decimal, Decimal) {
        let a = minimised(a);
        let b = minimised(b);
        to_least_decimals(a, b)
    }

    /// minimises trailing zeroes 
    fun minimise(v: U256, d: u64): (U256, u64) {
        if (u256::compare(&v, &u256::zero()) == 0) return (u256::zero(), 0);
        let ten = u256::from_u64(10);
        loop {
            if (d == 0) return (v, d);

            if (minimisable(v)) {
                v = u256::div(v, ten);
                d = d - 1;
            } else return (v, d);
        }
    }

    fun minimisable(v: U256): bool {
        let v0 = u256::get(&v, 0);

        (v0 / 10) * 10 == v0
    }

    /// minimises trailing zeroes 
    public fun minimised(d: Decimal): Decimal {
        let (v, d) = minimise(d.value, (d.decimals as u64));

        assert!(d < MAX_U8, error::out_of_range(ETOO_MANY_DECIMALS));

        Decimal {
            value: v,
            decimals: (d as u8)
        }
    }

    /// Checks whether the given number is zero.
    public fun is_zero(x: Decimal): bool {
        u256::compare(&x.value, &u256::zero()) == 0
    }

    /// Checks whether the two given Decimals represent the same value.
    public fun is_eq(a: Decimal, b: Decimal): bool {
        let (a, b) = to_most_decimals_and_minimised(a, b);

        u256::compare(&a.value, &b.value) == 0
    }

    /// Checks whether the first Decimal represents a value less than the other Decimal.
    public fun is_lt(a: Decimal, b: Decimal): bool {
        let (a, b) = to_most_decimals_and_minimised(a, b);
        
        u256::compare(&a.value, &b.value) == 1
    }

    /// Checks whether the first Decimal represents a value greater than the other Decimal.
    public fun is_gt(a: Decimal, b: Decimal): bool {
        let (a, b) = to_most_decimals_and_minimised(a, b);
        
        u256::compare(&a.value, &b.value) == 2
    }

    /// Checks whether the first Decimal represents a value less than or equal 
    /// to the other Decimal.
    public fun is_le(a: Decimal, b: Decimal): bool {
        let (a, b) = to_most_decimals_and_minimised(a, b);
        
        let res = u256::compare(&a.value, &b.value);
        res == 0 || res == 1 
    }

    /// Checks whether the first Decimal represents a value greater than or equal 
    /// to the other Decimal.
    public fun is_ge(a: Decimal, b: Decimal): bool {
        let (a, b) = to_most_decimals_and_minimised(a, b);
        
        let res = u256::compare(&a.value, &b.value);
        res == 0 || res == 2 
    }


    /// Adds two Decimals.
    // a/10^d_a + b/10^d_b 
    public fun add(a: Decimal, b: Decimal): Decimal {
        let (a, b) = to_most_decimals_and_minimised(a, b);        

        minimised(Decimal {
            value: u256::add(a.value, b.value),
            decimals: a.decimals
        })
    }

    /// Subtracts two Decimals.
    // a/10^d_a - b/10^d_b 
    public fun sub(a: Decimal, b: Decimal): Decimal {
        let (a, b) = to_most_decimals_and_minimised(a, b);

        minimised(Decimal {
            value: u256::sub(a.value, b.value),
            decimals: a.decimals
        })
    }



    /// Multiplies two Decimals.
    // a/10^d_a * b/10^d_b = (a*b)/(10^d_a*10^d_b) = (a*b)/10^(d_a + d_b)
    public fun mul(a: Decimal, b: Decimal): Decimal {
        let decs = (a.decimals as u64) + (b.decimals as u64);
        
        let (v, d) = minimise(u256::mul(a.value, b.value), decs);

        assert!(d < MAX_U8, error::out_of_range(ETOO_MANY_DECIMALS));

        Decimal {
            value: v,
            decimals: (d as u8)
        }
    }

    /// Divides two Decimals.
    // a/10^d_a / b/10^d_b = (a/b)/(10^d_a/10^d_b) = (a/b)/10^(d_a - d_b)
    public fun div(dividend: Decimal, divisor: Decimal): Decimal {
        if (divisor.decimals > dividend.decimals) {
            dividend = with_decimals(dividend, divisor.decimals);
        };

        let decs = ((dividend.decimals - divisor.decimals) as u64);

        let (v, d) = minimise(u256::div(dividend.value, divisor.value), decs);

        assert!(d < MAX_U8, error::out_of_range(ETOO_MANY_DECIMALS));

        Decimal {
            value: v,
            decimals: (d as u8)
        }
    }


    public fun pow(base: Decimal, exp: u64): Decimal {
        if (exp == 0) return one();
 
        let acc = base;

        loop {
            if (exp == 1) break;

            acc = mul(acc, base);

            exp = exp - 1;
        };

        acc
    }


    /// Perform the exponentiation operation ona Decimal base using an integer exponent.
    // exponentiation by squaring
    public fun pow_by_squaring(base: Decimal, exp: u64): Decimal {
        let acc = if (exp % 2 != 0) { base } else { one() };

        let n = exp / 2;
        loop {
            if (n == 0) {
                break
            };

            base = mul(base, base);

            if (n % 2 != 0) {
                acc = mul(acc, base);
            };

            n = n / 2;
        };

        acc
    }
}
