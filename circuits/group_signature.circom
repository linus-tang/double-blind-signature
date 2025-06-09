pragma circom 2.1.6;

include "../libs/circomlib/circuits/poseidon.circom";
include "../libs/circom-secp256k1/circuits/bigint.circom";

// Converts a number into its binary representation using bitwise operations
// numBits: number of bits in the output
// num: input number to convert to binary
// bits: output array of bits
template Binary (numBits) {
    signal input num;
    signal output bits[numBits];

    var accum;
    for (var i = 0; i < numBits; i ++) {
        // Extract each bit using right shift and bitwise AND with 1
        bits[i] <-- (num >> i) & 1;
        // Ensure the bit is binary (0 or 1) using quadratic constraint
        bits[i] === bits[i] * bits[i];
        // Accumulate the binary value by multiplying each bit with its power of 2
        accum += (2**i) * bits[i];
    }
    // Verify the accumulated value equals the input number
    accum === num;
}

// Expands a k-register number to an m-register number by padding with zeros
// n: bits per register
// k: number of input registers
// m: number of output registers (m >= k)
template expand(n, k, m) {
   // assert (k > m);
    signal input in[k];
    signal output out[m];
    // Copy input values to output
    for (var i = 0; i < k; i++){
        out[i] <== in[i];
    }
    // Pad remaining registers with zeros
    for (var i = k; i < m; i++){
        out[i] <== 0;
    }
}

// Selects between a number and 1 based on a bit 
// n: bits per register
// k: number of registers
// a: input number
// bit: selection bit (0 or 1)
// out: output number (a if bit=1, 1 if bit=0)
template BigSelect(n, k){
    signal input a[k];
    signal input bit;
    signal output out[k];
    
    // For all registers except the first, multiply by the bit
    for (var i = 1; i < k; i++){
        out[i] <== a[i] * bit;
    }
    // For the first register, multiply by bit and add (1-bit)
    out[0] <== a[0] * bit + (1 - bit);
}

// Computes a modulo p where a < p^2
// n: bits per register
// k: number of registers for p
// a: input number (2k registers)
// p: modulus (k registers)
// remainder: output remainder (k registers)

/*
template Modulo (n, k) {
    signal input a[2 * k];
    signal input p[k];
    signal quotient[k + 1];
    signal output remainder[k];
    
    signal help[2][100];
    // Perform long division to get quotient and remainder

    //component help_div = template_long_div(n, k, k);
    //help_div.a <-- a;
    //help_div.b <-- p;
    //help <-- help_div.out;

    help <-- long_div(n, k, k, a, p);

    // Extract quotient from division result
    for (var i = 0; i < k + 1; i++){
        quotient[i] <-- help[0][i];
    }

    // Extract remainder from division result
    for (var i = 0; i < k; i++){
        remainder[i] <-- help[1][i];
    }

    // Verify the result by checking a = p * quotient + remainder
    component product = BigMult(n, k + 1);
    for (var i = 0; i < k; i++){
        product.a[i] <== p[i];
    }
    product.a[k] <== 0;
    product.b <== quotient;

    // Expand remainder to match product size
    component exp_remainder = expand(n, k, 2 * k);
    exp_remainder.in <== remainder;

    // Add product and remainder
    component sum = BigAdd(n, 2 * k);
    for (var i = 0; i < 2 * k; i++){
        sum.a[i] <== product.out[i];
    }
    
    sum.b <== exp_remainder.out;

    // Verify the sum equals the original input
    component equal = BigIsEqual(2 * k);
    equal.in[0] <== a;
    for (var i = 0; i < 2 * k; i++){
        equal.in[1][i] <== sum.out[i];
    }
   
    equal.out === 1;
    //reminder <== quotient[1];
}
*/

// Implements modular exponentiation using square-and-multiply algorithm
// n: bits per register
// k: number of registers for a and p
// bBits: number of bits in b
// a: base
// b: exponent
// p: modulus
// out: result of a^b mod p
template LongExpMod(n, k) { // a**b mod p
    signal input a[k];
    signal input p[k];
    signal powers_of_a[17][k];
    signal output out[k];

    // Initialize first power
    powers_of_a[0] <== a;
    // Compute powers of a using square-and-multiply

    component bigModMul [17];

    for (var i = 1; i < 17; i++)
    {
        bigModMul [i] = BigMultModP(n, k);
        bigModMul [i].a <== powers_of_a[i - 1];
        bigModMul [i].b <== powers_of_a[i - 1];
        bigModMul [i].p <== p;
        powers_of_a[i] <== bigModMul [i].out;
    }

    // Compute final result using binary exponentiation

    bigModMul[0] = BigMultModP(n, k);
    bigModMul[0].a <== powers_of_a[0];
    bigModMul[0].b <== powers_of_a[16];
    bigModMul[0].p <== p;

    out <== bigModMul[0].out;
}

// Implements a group signature scheme where:
// 1. Each member has a private key and public key (N, e)
// 2. The signature is verified by checking if signer_sk^signer_pk_e ≡ message_hash mod signer_pk_N
// 3. The signer's public key must match one of the group's public keys
// n: bits per register
// k: number of registers for numbers
// sizeGroup: number of members in the group
template GroupSignature(n, k, sizeGroup){
    signal input double_blind_hash[k];   // Hash of the "double-blind" message
    signal input signer_sk[k];           // Signer's double-blind key
    signal input signer_pk_N[k];         // Signer's public key modulus
    signal input public_N[sizeGroup][k]; // Group public key modulus
    signal input message_hash;           // Hash of the message we are creating group signature for
    signal input election_id;            // Election ID
    signal output nullifier;             // Hash part of double-blind key with election ID

    // Verify the signature using modular exponentiation
    component ver = LongExpMod(n, k);
    ver.a <== signer_sk;
    ver.p <== signer_pk_N;

    // Check if the verification result matches the message hash
    component ver_message = BigIsEqual(k);
    ver_message.in[0] <== double_blind_hash;
    ver_message.in[1] <== ver.out;
    ver_message.out === 1;

    // Verify the signer is a member of the group by checking public keys
    signal help[sizeGroup + 1];
    component eq_check[sizeGroup + 1], long_eq_check[sizeGroup + 1];
    help[0] <== 1;
    for (var i = 1; i < sizeGroup + 1; i++){
        // Check if public key modulus matches
        long_eq_check[i] = BigIsEqual(k);
        long_eq_check[i].in[0] <== public_N[i - 1];
        long_eq_check[i].in[1] <== signer_pk_N;
        // Update help signal based on matches
        help[i] <== (1 - long_eq_check[i].out) * help[i - 1];
    }
    // Ensure at least one match was found
    help[sizeGroup] === 0;    

    component nullifier_hash;
    nullifier_hash = Poseidon(2);
    nullifier_hash.inputs[0] <== signer_sk[0];
    nullifier_hash.inputs[1] <== election_id;
    nullifier <== nullifier_hash.out;
}

component main { public [ message_hash, election_id ] } = GroupSignature(121,34,20);
/* INPUT =
{
    "double_blind_hash": [
        "875355558853261574109667567685",
        "38092419418133180883450553543"
    ],
    "signer_sk": [
        "1157469625553510763204603205019",
        "840070342364635425355467079971"
    ],
    "signer_pk_N": [
        "501301839642406524626337067218",
        "384225782253023810501597626265"
    ],
    "public_N": [
        [
            "501301839642406524626337067218",
            "384225782253023810501597626265"
        ],
        [
            "125974714791502980755141813543",
            "698200227022155396867952339828"
        ]
    ],
    "message_hash": "1462695611900419492420222463127356316122306150381916561462150981837933193873",
    "election_id": "53988163955230919261059858900286949444710370960254075948873351460078693361"
}
*/