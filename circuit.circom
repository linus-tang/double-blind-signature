pragma circom 2.0.0;

// Helper function to compute hash
template Hash() {
    signal input in;
    signal output out;
    
    // Simple hash function using field arithmetic
    // In a real implementation, you'd want to use a proper hash function
    out <== in * in + 7;
}

// Circuit for blinding a message
template BlindMessage() {
    signal input message;
    signal input blinding_factor;
    signal output blinded_message;
    
    blinded_message <== message + blinding_factor;
}

// Circuit for signing a blinded message
template SignBlindedMessage() {
    signal input blinded_message;
    signal input private_key;
    signal output signature;
    
    signature <== blinded_message * private_key;
}

// Circuit for unblinding a signature
template UnblindSignature() {
    signal input blinded_signature;
    signal input blinding_factor;
    signal input private_key;
    signal output unblinded_signature;
    
    unblinded_signature <== blinded_signature - (blinding_factor * private_key);
}

// Main circuit that combines all steps
template BlindSignature() {
    // Inputs
    signal input message;
    signal input blinding_factor;
    signal input private_key;
    
    // Outputs
    signal output final_signature;
    
    // Components
    component blind = BlindMessage();
    component sign = SignBlindedMessage();
    component unblind = UnblindSignature();
    
    // Connect the components
    blind.message <== message;
    blind.blinding_factor <== blinding_factor;
    
    sign.blinded_message <== blind.blinded_message;
    sign.private_key <== private_key;
    
    unblind.blinded_signature <== sign.signature;
    unblind.blinding_factor <== blinding_factor;
    unblind.private_key <== private_key;
    
    final_signature <== unblind.unblinded_signature;
}

component main = BlindSignature(); 