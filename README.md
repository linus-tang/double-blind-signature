# Double Blind Signature Circuit

This repository contains a Circom implementation of a group signature scheme. The circuit allows for creating and verifying signatures within a group context while maintaining privacy properties.

## Components

### Binary Template
Converts numbers to their binary representation and performs range checks.

### Modulo Template
Implements modular arithmetic operations with range checks.

### SmallExpMod Template
Implements modular exponentiation (a^b mod p) using square-and-multiply algorithm.

### GroupSignature Template
Implements the group signature scheme, allowing a signer to create a signature that can be verified against multiple public keys.

## Usage

1. Install dependencies:
```bash
npm install circomlib
```

2. Compile the circuit:
```bash
circom circuits/group_signature.circom --r1cs --wasm --sym
```

3. Run with sample input:
```bash
node generate_witness.js group_signature.wasm input.json witness.wtns
```

## Test Input
A sample input file is provided in `circuits/input.json` with the following values:
- a: 25
- b: 39
- p: 251