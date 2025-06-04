pragma circom 2.1.6;

function isNegative(x) {
    // half babyjubjub field size
    return x > 10944121435919637611123202872628637544274182200208017171849102093287904247808 ? 1 : 0;
}

function div_ceil(m, n) {
    return (m + n - 1) \ n;
}

function log_ceil(n) {
   var n_temp = n;
   for (var i = 0; i < 254; i++) {
       if (n_temp == 0) {
          return i;
       }
       n_temp = n_temp \ 2;
   }
   return 254;
}

function SplitFn(in, n, m) {
    return [in % (1 << n), (in \ (1 << n)) % (1 << m)];
}

function SplitThreeFn(in, n, m, k) {
    return [in % (1 << n), (in \ (1 << n)) % (1 << m), (in \ (1 << (n + m))) % (1 << k)];
}

// 1 if true, 0 if false
function long_gt(n, k, a, b) {
    for (var i = k - 1; i >= 0; i--) {
        if (a[i] > b[i]) return 1;
        if (a[i] < b[i]) return 0;
    }
    return 0;
}

template long_sub(n, k){
    signal input a[k];
    signal input b[k];
    signal output out[k];
    var diff[k];    // Size k
    var borrow[k];  // Size k
    
    for (var i = 0; i < k; i++) {
        if (i == 0) {
            if (a[i] >= b[i]) {
                diff[i] = a[i] - b[i];
                borrow[i] = 0;
            } else {
                diff[i] = a[i] - b[i] + (1 << n);
                borrow[i] = 1;
            }
        } else {
            if (a[i] >= b[i] + borrow[i - 1]) {
                diff[i] = a[i] - b[i] - borrow[i - 1];
                borrow[i] = 0;
            } else {
                diff[i] = (1 << n) + a[i] - b[i] - borrow[i - 1];
                borrow[i] = 1;
            }
        }
    }
    out <-- diff;
}

template long_scalar_mult(n, k){
    signal input a;
    signal input b[k];
    signal output out[k + 1];
    var result[k + 1];  // Size k + 1 for overflow
    
    for (var i = 0; i <= k; i++) {
        result[i] = 0;
    }
    
    for (var i = 0; i < k; i++) {
        var temp = result[i] + (a * b[i]);
        result[i] = temp % (1 << n);
        result[i + 1] = result[i + 1] + (temp \ (1 << n));
    }
    for (var i = 0; i < k + 1; i++){
        out[i] <-- result[i];
    }

}

//n bits per register
// a has k + m registers
// b has k registers
// outputs k + m + 1 register 
// output = remainder || quotient, result of long division a / b
// remainder has k registers
// quotient has m + 1 register
template long_div(n, k, m){
    signal input a[k + m];
    signal input b[k];
    signal output out[m + k + 1];

    var quotient[m + 1];     // quotient size m+1, remainder size k
    var remainder[m + k];   // Size m + k
    var dividend[k + 1];    // Size k + 1
    
    // Initialize arrays
    remainder = a;
    
    for (var i = 0; i <= k; i++) {
        dividend[i] = 0;
    }
    //component short_division[m + 1];

    for (var i = m; i >= 0; i--) {
        if (i == m) {
            dividend[k] = 0;
            for (var j = k - 1; j >= 0; j--) {
                dividend[j] = remainder[j + m];
            }
        } else {
            for (var j = k; j >= 0; j--) {
                dividend[j] = remainder[j + i];
            }
        }
        log("we divide by", k);
        quotient[i] = short_div(n, k)(dividend, b);
        log("we got", quotient[i]);
        var mult_shift[k + 1] = long_scalar_mult(n, k) (quotient[i], b);
        var subtrahend[m + k];
        
        for (var j = 0; j < m + k; j++) {
            subtrahend[j] = 0;
        }
        
        for (var j = 0; j <= k; j++) {
            if (i + j < m + k) {
                subtrahend[i + j] = mult_shift[j];
            }
        }
        
        remainder = long_sub(n, m + k) (remainder, subtrahend);
    }
    
    for (var i = 0; i < k; i++){
        out[i] <-- remainder[i];
    }
    for (var i = k; i < k + m + 1; i++){
        out[i] <-- quotient[i - k];
    }
    
}

template short_div_norm(n, k){
    signal input a[k + 1];
    signal input b[k];
    signal output out;
    log("we want to divide by", k);
    var flag_zero = (b[k - 1] == 0) ? 1 : 0;
    var qhat = (a[k] * (1 << n) + a[k - 1]) \ (b[k - 1] + flag_zero);
    if (qhat > (1 << n) - 1) {
        qhat = (1 << n) - 1;
    }

    var mult[k + 1];
    component multiply = long_scalar_mult(n, k);
    multiply.a <-- qhat;
    for (var i = 0; i < k; i++){
        multiply.b[i] <-- b[i];
    }
    for (var i = 0; i < k + 1; i++){
        mult[i] = multiply.out[i];
    }

    var flag = long_gt(n, k + 1, mult, a);
    component subtract = long_sub(n, k + 1);
    subtract.a <-- mult;
    for (var i = 0; i < k; i++){
        subtract.b[i] <-- b[i];
    }
    subtract.b[k] <-- 0;
    mult = subtract.out;
    var flag2 = long_gt(n, k + 1, mult, a);
    out <-- qhat - flag - flag2 * flag;
    
}

template short_div(n, k) {
    signal input a[k + 1];
    signal input b[k];
    signal output out;
    var scale = (1 << n) \ (1 + b[k - 1]);
    var norm_a[k + 1];
    component mult_a = long_scalar_mult(n, k + 1);
    mult_a.a <-- scale;
    for (var i = 0; i < k + 1; i++){
        mult_a.b[i] <-- a[i];
    }
    for (var i = 0; i < k + 1; i++){
        norm_a[i] = mult_a.out[i];
    }
    var norm_b[k + 1];
    component mult_b = long_scalar_mult(n, k);
    mult_b.a <-- scale;
    for (var i = 0; i < k; i++){
        mult_b.b[i] <-- b[i];
    }
    for (var i = 0; i < k + 1; i++){
        norm_b[i] = mult_b.out[i];
    }
    var flag = (norm_b[k] != 0) ? 1 : 0;
    component result1_div = short_div_norm(n, k + 1);
    for (var i = 0; i < k + 1; i++){
        result1_div.a[i] <-- norm_a[i];
        result1_div.b[i] <-- norm_b[i];
    }
    result1_div.a[k + 1] <-- 0;
    var result1 = result1_div.out;

    component result2_div = short_div_norm(n, k);
    for (var i = 0; i < k; i++){
        result2_div.a[i] <-- norm_a[i];
        result2_div.b[i] <-- norm_b[i];
    }
    result2_div.a[k] <-- norm_a[k];
    var result2 = result2_div.out;
    out <-- result1 * flag + result2 * ( 1- flag);
}

template prod(n, k){
    signal input a[k];
    signal input b[k];
    signal output out[2 * k];
    var prod_val[2 * k - 1];  // Size 2k-1
    var result[2 * k];           // Size 2k
    var split[2 * k - 1][3];  // Size (2k-1) x 3
    var carry[2 * k - 1];     // Size 2k-1
    
    // Initialize arrays
    for (var i = 0; i < 2 * k - 1; i++) {
        prod_val[i] = 0;
        carry[i] = 0;
        if (i < k) {
            for (var a_idx = 0; a_idx <= i; a_idx++) {
                prod_val[i] += a[a_idx] * b[i - a_idx];
            }
        } else {
            for (var a_idx = i - k + 1; a_idx < k; a_idx++) {
                prod_val[i] += a[a_idx] * b[i - a_idx];
            }
        }
    }

    // Compute splits
    for (var i = 0; i < 2 * k - 1; i++) {
        split[i] = SplitThreeFn(prod_val[i], n, n, n);
    }

    // Initialize first values
    carry[0] = 0;
    result[0] = split[0][0];

    // Process remaining values
    if (2 * k - 1 > 1) {
        var sumAndCarry[2] = SplitFn(split[0][1] + split[1][0], n, n);
        result[1] = sumAndCarry[0];
        carry[1] = sumAndCarry[1];

        for (var i = 2; i < 2 * k - 1; i++) {
            sumAndCarry = SplitFn(split[i][0] + split[i-1][1] + split[i-2][2] + carry[i-1], n, n);
            result[i] = sumAndCarry[0];
            carry[i] = sumAndCarry[1];
        }
        result[2 * k - 1] = split[2*k-2][1] + split[2*k-3][2] + carry[2*k-2];
    }

    out <-- result;
} 


template test_something(k){
    
    signal input a;
    signal input b;
    signal output c;
    var test;
    test = a + b;
    c <-- test;
}
template test_run(n, k, m){
    //log("long division result", long_div(n, k, m, [1, 1, 1, 1], [0, 1]));
}

component main = long_div(1, 2, 3);
/* INPUT = {
    "a": ["0", "1", "0", "1", "1"],
    "b": ["1", "1"]
} */
