pragma circom 2.1.6;

include "circomlib/poseidon.circom";
include "https://github.com/0xPARC/circom-secp256k1/blob/master/circuits/bigint.circom";

template Binary (numBits) {
    signal input num;
    signal output bits[numBits];

    var accum;
    for (var i = 0; i < numBits; i ++) {
        bits[i] <-- (num >> i) & 1;
        bits[i] === bits[i] * bits[i];
        accum += (2**i) * bits[i];
    }
    accum === num;
}

template Modulo (numBits) {
    signal input a;
    signal input p;
    signal quotient;
    signal product;
    signal p_minus_one_minus_remainder;
    signal output remainder;

    component range_check_1;
    component range_check_2;

    quotient <-- a \ p;
    product <== p * quotient;
    remainder <== a - product;
    p_minus_one_minus_remainder <== p - 1 - remainder;

    range_check_1 = Binary(numBits);
    range_check_2 = Binary(numBits);
    range_check_1.num <== remainder;
    range_check_2.num <== p_minus_one_minus_remainder;
}

template SmallExpMod (numBits_p, numBits_b) { // a**b mod p
    signal input a;
    signal input b;
    signal input p;
    signal b_bits[numBits_b];
    signal powers_of_a[numBits_b];
    signal select_one_or_pow[numBits_b];
    signal intermediate_products[numBits_b + 1];
    signal output exp;

    component bin;
    component mod[numBits_b];
    component more_mod[numBits_b];


    bin = Binary (numBits_b);
    bin.num <== b;
    b_bits <== bin.bits;

    powers_of_a[0] <== a;
    for (var i = 1; i < numBits_b; i ++) {
        mod[i] = Modulo(numBits_p);
        mod[i].a <== powers_of_a[i-1] * powers_of_a[i-1];
        mod[i].p <== p;
        powers_of_a[i] <== mod[i].remainder;
    }

    intermediate_products[0] <== 1;
    for (var i = 0; i < numBits_b; i ++) {
        more_mod[i] = Modulo(numBits_p);
        select_one_or_pow[i] <== b_bits[i] * (powers_of_a[i] - 1) + 1;
        more_mod[i].a <== intermediate_products[i] * (select_one_or_pow[i]);
        more_mod[i].p <== p;
        intermediate_products[i+1] <== more_mod[i].remainder;
    }

    exp <== intermediate_products[numBits_b];

}

template GroupSignature(numBits_p, numBits_b, sizeGroup){
    signal input message;
    signal input signer_sk, public_N[sizeGroup], public_e[sizeGroup];

    
    signal signature_ver[sizeGroup];


    for (var i = 0; i < sizeGroup; i++) {
        component ver = SmallExpMod(numBits_p, numBits_b);
        ver.a <== signer_sk;
        ver.b <== public_e[i];
        ver.p <== public_N[i];
        signature_ver[i] <== ver.exp;
    }

    signal help[sizeGroup];
    help[0] <== signature_ver[0] - message;
    for (var i = 1; i < sizeGroup; i++){
        help[i] <== help[i - 1] * (signature_ver[i] - message);
    }
    help[sizeGroup - 1] === 0;    
}

component main = SmallExpMod (8,6);

/* INPUT = {
    "a": "25",
    "b": "39",
    "p": "251"
} */ 