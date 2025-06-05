function getArrayInputs(textareaId) {
    const textarea = document.getElementById(textareaId);
    return textarea.value.split('\n').map(line => line.trim()).filter(line => line !== '');
}

function extractRSAFromSSH(sshKey) {
    try {
        // Remove the key type and comment
        const keyParts = sshKey.split(' ');
        if (keyParts.length < 2) {
            throw new Error('Invalid SSH key format');
        }

        // Decode the base64 part
        const keyData = atob(keyParts[1]);
        
        // Convert to array of bytes
        const bytes = new Uint8Array(keyData.length);
        for (let i = 0; i < keyData.length; i++) {
            bytes[i] = keyData.charCodeAt(i);
        }

        // Skip the key type length and key type
        let offset = 0;
        const keyTypeLen = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += 4 + keyTypeLen;

        // Skip the key length
        offset += 4;

        // The remaining data is the RSA key in ASN.1 DER format
        // For simplicity, we'll use a fixed e value of 65537 (0x10001)
        // and extract N from the key data
        const n = BigInt('0x' + Array.from(bytes.slice(offset + 4, offset + 4 + 256))
            .map(b => b.toString(16).padStart(2, '0'))
            .join(''));
        const e = 65537n;

        return { n, e };
    } catch (error) {
        throw new Error(`Failed to extract RSA parameters: ${error.message}`);
    }
}

function validateInputs() {
    const message = document.getElementById('message').value;
    const signer_sk = document.getElementById('signer_sk').value;
    const publicKeys = getArrayInputs('publicKeys');
    const nValues = getArrayInputs('nValue');
    const eValues = getArrayInputs('eValue');

    if (!message || !signer_sk) {
        alert('Please fill in all required fields');
        return false;
    }

    if (publicKeys.length === 0 && (nValues.length === 0 || eValues.length === 0)) {
        alert('Please enter either SSH public keys or both N and e values');
        return false;
    }

    if (nValues.length !== eValues.length && nValues.length > 0 && eValues.length > 0) {
        alert('Number of N values must match number of e values');
        return false;
    }

    return true;
}

async function generateProof() {
    if (!validateInputs()) return;

    const message = document.getElementById('message').value;
    const signer_sk = document.getElementById('signer_sk').value;
    const publicKeys = getArrayInputs('publicKeys');
    const nValues = getArrayInputs('nValue');
    const eValues = getArrayInputs('eValue');
    
    const loading = document.getElementById('loading');
    const proofOutput = document.getElementById('proofOutput');

    loading.style.display = 'block';
    proofOutput.value = '';

    try {
        let paddedN, paddedE;
        
        if (publicKeys.length > 0) {
            // Use SSH keys if provided (priority)
            const rsaParams = publicKeys.map(extractRSAFromSSH);
            paddedN = [...rsaParams.map(p => p.n.toString()), ...Array(20 - rsaParams.length).fill('1')];
            paddedE = [...rsaParams.map(p => p.e.toString()), ...Array(20 - rsaParams.length).fill('0')];
            
            // Display extracted values in textboxes
            document.getElementById('nValue').value = rsaParams.map(p => p.n.toString()).join('\n');
            document.getElementById('eValue').value = rsaParams.map(p => p.e.toString()).join('\n');
        } else if (nValues.length > 0 && eValues.length > 0) {
            // Use provided N and e values
            paddedN = [...nValues, ...Array(20 - nValues.length).fill('1')];
            paddedE = [...eValues, ...Array(20 - eValues.length).fill('0')];
        } else {
            throw new Error('No valid input provided');
        }

        const { proof, publicSignals } = await snarkjs.groth16.fullProve(
            {
                message: message.toString(),
                signer_sk: signer_sk.toString(),
                public_N: paddedN,
                public_e: paddedE
            },
            "circuit_js/circuit.wasm",
            "circuit_final.zkey"
        );

        proofOutput.value = JSON.stringify({
            proof: proof,
            publicSignals: publicSignals
        }, null, 2);
    } catch (error) {
        if (error.message.includes("Assert Failed")) {
            proofOutput.value = 'Error: Signature does not verify!';
        } else {
            proofOutput.value = 'Error: ' + error.message;
        }
    } finally {
        loading.style.display = 'none';
    }
}

async function verifyProof() {
    const verificationResult = document.getElementById('verificationResult');
    const proofOutput = document.getElementById('proofOutput');
    
    try {
        const proofData = JSON.parse(proofOutput.value);
        if (!proofData.proof || !proofData.publicSignals) {
            throw new Error('Invalid proof format');
        }

        const verificationKey = await fetch('verification_key.json').then(r => r.json());
        const res = await snarkjs.groth16.verify(verificationKey, proofData.publicSignals, proofData.proof);
        verificationResult.textContent = res ? 'Verified!' : 'Invalid proof';
        verificationResult.style.color = res ? 'green' : 'red';
    } catch (error) {
        verificationResult.textContent = 'Error: ' + error.message;
        verificationResult.style.color = 'red';
    }
}

// Add event listener to clear verification result when proof output is edited
document.getElementById('proofOutput').addEventListener('input', function() {
    document.getElementById('verificationResult').textContent = '';
}); 