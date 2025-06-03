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

// in is an m bit number
// split into ceil(m/n) n-bit registers
function splitOverflowedRegister(m, n, in) {
    var nRegisters = div_ceil(m, n);
    var out[nRegisters];  // Exact size needed

    for (var i = 0; i < nRegisters; i++) {
        out[i] = (in \ (1 << (n * i))) % (1 << n);
    }
    
    return out;
}

// m bits per overflowed register (values are potentially negative)
// n bits per properly-sized register
// in has k registers
function getProperRepresentation(m, n, k, in) {
    var ceilMN = div_ceil(m, n);
    var maxSize = k + ceilMN;
    
    var pieces[k][ceilMN];  // k x ceilMN matrix
    
    // Initialize pieces array
    for (var i = 0; i < k; i++) {
        if (isNegative(in[i]) == 1) {
            var negPieces[ceilMN] = splitOverflowedRegister(m, n, -1 * in[i]);
            for (var j = 0; j < ceilMN; j++) {
                pieces[i][j] = -1 * negPieces[j];
            }
        } else {
            var posPieces[ceilMN] = splitOverflowedRegister(m, n, in[i]);
            for (var j = 0; j < ceilMN; j++) {
                pieces[i][j] = posPieces[j];
            }
        }
    }

    var out[maxSize];     // Size k + ceilMN
    var carries[maxSize]; // Size k + ceilMN
    
    // Initialize arrays
    for (var i = 0; i < maxSize; i++) {
        out[i] = 0;
        carries[i] = 0;
    }

    // Process each register
    for (var registerIdx = 0; registerIdx < maxSize; registerIdx++) {
        var thisRegisterValue = registerIdx > 0 ? carries[registerIdx - 1] : 0;

        var start = registerIdx >= ceilMN ? registerIdx - ceilMN + 1 : 0;
        
        for (var i = start; i <= registerIdx && i < k; i++) {
            thisRegisterValue += pieces[i][registerIdx - i];
        }

        if (isNegative(thisRegisterValue) == 1) {
            var thisRegisterAbs = -1 * thisRegisterValue;
            out[registerIdx] = (1 << n) - (thisRegisterAbs % (1 << n));
            carries[registerIdx] = -1 * (thisRegisterAbs \ (1 << n)) - 1;
        } else {
            out[registerIdx] = thisRegisterValue % (1 << n);
            carries[registerIdx] = thisRegisterValue \ (1 << n);
        }
    }

    return out;
}

// 1 if true, 0 if false
function long_gt(n, k, a, b) {
    for (var i = k - 1; i >= 0; i--) {
        if (a[i] > b[i]) return 1;
        if (a[i] < b[i]) return 0;
    }
    return 0;
}

function long_sub(n, k, a, b) {
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
    return diff;
}

function long_scalar_mult(n, k, a, b) {
    var out[k + 1];  // Size k + 1 for overflow
    
    for (var i = 0; i <= k; i++) {
        out[i] = 0;
    }
    
    for (var i = 0; i < k; i++) {
        var temp = out[i] + (a * b[i]);
        out[i] = temp % (1 << n);
        out[i + 1] = out[i + 1] + (temp \ (1 << n));
    }
    return out;
}

function long_div(n, k, m, a, b) {
    var quotient[m + 1];     // quotient size m+1, remainder size k
    var remainder_ans[k];
    var remainder[m + k];   // Size m + k
    var dividend[k + 1];    // Size k + 1
    
    // Initialize arrays
    remainder = a
    
    for (var i = 0; i <= k; i++) {
        dividend[i] = 0;
    }

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

        quotient[i] = short_div(n, k, dividend, b);
        
        var mult_shift[k + 1] = long_scalar_mult(n, k, quotient[i], b);
        var subtrahend[m + k];
        
        for (var j = 0; j < m + k; j++) {
            subtrahend[j] = 0;
        }
        
        for (var j = 0; j <= k; j++) {
            if (i + j < m + k) {
                subtrahend[i + j] = mult_shift[j];
            }
        }
        
        remainder = long_sub(n, m + k, remainder, subtrahend);
    }
    
    for (var i = 0; i < k; i++) {
        remainder_ans = remainder[i];
    }
    

    return quotient;
}

function short_div_norm(n, k, a, b) {
    var qhat = (a[k] * (1 << n) + a[k - 1]) \ b[k - 1];
    if (qhat > (1 << n) - 1) {
        qhat = (1 << n) - 1;
    }

    var mult[k + 1] = long_scalar_mult(n, k, qhat, b);
    if (long_gt(n, k + 1, mult, a) == 1) {
        mult = long_sub(n, k + 1, mult, b);
        if (long_gt(n, k + 1, mult, a) == 1) {
            return qhat - 2;
        } else {
            return qhat - 1;
        }
    }
    return qhat;
}

function short_div(n, k, a, b) {
    var scale = (1 << n) \ (1 + b[k - 1]);
    var norm_a[k + 1] = long_scalar_mult(n, k + 1, scale, a);
    var norm_b[k + 1] = long_scalar_mult(n, k, scale, b);

    return (norm_b[k] != 0) ? 
        short_div_norm(n, k + 1, norm_a, norm_b) : 
        short_div_norm(n, k, norm_a, norm_b);
}

function prod(n, k, a, b) {
    var prod_val[2 * k - 1];  // Size 2k-1
    var out[2 * k];           // Size 2k
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
    out[0] = split[0][0];

    // Process remaining values
    if (2 * k - 1 > 1) {
        var sumAndCarry[2] = SplitFn(split[0][1] + split[1][0], n, n);
        out[1] = sumAndCarry[0];
        carry[1] = sumAndCarry[1];

        for (var i = 2; i < 2 * k - 1; i++) {
            sumAndCarry = SplitFn(split[i][0] + split[i-1][1] + split[i-2][2] + carry[i-1], n, n);
            out[i] = sumAndCarry[0];
            carry[i] = sumAndCarry[1];
        }
        out[2 * k - 1] = split[2*k-2][1] + split[2*k-3][2] + carry[2*k-2];
    }

    return out;
} 
