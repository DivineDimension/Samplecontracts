/// Module with common utility and calculation functions.
module nucleus::utils {
    use nucleus::decimal::{ // my own implementation of a floating decimal
        Decimal, 
        zero, one, 
        is_eq, is_lt, is_gt, is_le, is_ge, 
        add, sub, 
        mul, div,
        pow,
    };

    /*************/
    /* Functions */
    /*************/

    /// Yellow Paper Def. 2.4 (Price Slippage Curve)
    /// = g(xr, i) or g(xr, j)
    /// The result of this function is always >= 0.
    public fun slippage_func(
        k: Decimal,
        n: u64,
        c1: Decimal,
        x_threshold: Decimal,
        x: Decimal,
    ): Decimal {
        if (is_lt(x, x_threshold)) {
            sub(c1, x)
        } else {
            div(k, pow(x, n))
        }
    }

    /// Yellow Paper Def. 2.4 (Asset Slippage)
    /// Calculates the slippage from or slippage to.
    /// = -Si or -Sj
    public fun slippage(
        k: Decimal,
        n: u64,
        c1: Decimal,
        x_threshold: Decimal,
        cash: Decimal,
        liability: Decimal,
        d_cash: Decimal,
        add_cash: bool
    ): Decimal {
        let cov_before = div(cash, liability);
        let cov_after = div(
            (if (add_cash) {
                add(cash, d_cash)
            } else {
                sub(cash, d_cash)
            }), 
            liability
        );

        if (is_eq(cov_before, cov_after)) {
            return zero()
        };

        let slippage_before = slippage_func(k, n, c1, x_threshold, cov_before);
        let slippage_after = slippage_func(k, n, c1, x_threshold, cov_after);

        if (is_gt(cov_before, cov_after)) {
            div(sub(slippage_after, slippage_before), sub(cov_before, cov_after))
        } else {
            div(sub(slippage_before, slippage_after), sub(cov_after, cov_before))
        }
    }

    /// Yellow Paper Def. 2.5 (Swapping Slippage)
    /// = 1 + (-Si) - (-Sj)
    public fun swapping_slippage(
        ns_i: Decimal,
        ns_j: Decimal,
    ): Decimal {
        sub(add(one(), ns_i), ns_j)
    }

    /// Yellow Paper Def. 4.0 (Haircut)
    /// Applies the haircut rate to the amount.
    public fun apply_haircut(
        amount: Decimal,
        rate: Decimal,
    ): Decimal {
        mul(amount, rate)
    }

    /// Applies the dividend to the amount.
    public fun apply_dividend(
        amount: Decimal,
        ratio: Decimal,
    ): Decimal {
        mul(amount, sub(one(), ratio))
    }

    /// Yellow Paper Def. 5.2 (Withdrawal Fee)
    /// When cov_before >= 1, fee is 0
    /// When cov_before < 1, we apply a fee to prevent withdrawal arbitrage
    public fun withdrawal_fee(
        k: Decimal,
        n: u64,
        c1: Decimal,
        x_threshold: Decimal,
        cash: Decimal,
        liability: Decimal,
        amount: Decimal,
    ): Decimal {
        let cov_before = div(cash, liability);

        if (is_ge(cov_before, one())) {
            return zero()
        };

        if (is_le(liability, amount)) {
            return zero()
        };

        let cash_after = if (is_gt(cash, amount)) {
            sub(cash, amount)
        } else {
            zero()
        };

        let cov_after = div(cash_after, sub(liability, amount));
        let slippage_before = slippage_func(k, n, c1, x_threshold, cov_before);
        let slippage_after = slippage_func(k, n, c1, x_threshold, cov_after);
        let slippage_neutral = slippage_func(k, n, c1, x_threshold, one());

        // calculate fee
        // = ((Li - Di) * slippage_after) + (g(1) * Di) - (Li * slippage_before)
        let a = add(mul(sub(liability, amount), slippage_after), slippage_neutral);
        let b = mul(liability, slippage_before);

        // handle underflow case
        if (is_gt(a, b)) {
            sub(a, b)
        } else {
            zero()
        }
    }


    /// Yellow Paper Def. 6.2 (Arbitrage Fee) / Deposit fee
    /// When cov_before <= 1, fee is 0
    /// When cov_before > 1, we apply a fee to prevent deposit arbitrage
    public fun deposit_fee(
        k: Decimal,
        n: u64,
        c1: Decimal,
        x_threshold: Decimal,
        cash: Decimal,
        liability: Decimal,
        amount: Decimal,
    ): Decimal {
        if (is_eq(liability, zero())) {
            return zero()
        };

        let cov_before = div(cash, liability);
        if (is_le(cov_before, one())) {
            return zero()
        };

        let cov_after = div(add(cash, amount), add(liability, amount));
        let slippage_before = slippage_func(k, n, c1, x_threshold, cov_before);
        let slippage_after = slippage_func(k, n, c1, x_threshold, cov_after);

        // return (Li + Di) * g(cov_after) - Li * g(cov_before)
        sub(mul(add(liability, amount), slippage_after), mul(liability, slippage_before))
    }

}
