// Define the test proof function first
async function generateTestProof() {
    console.log('Starting test proof generation');
    const loading = document.getElementById('loading');
    const proofOutput = document.getElementById('proofOutput');
    const proofProgress = document.getElementById('proofProgress');
    const progressBar = document.getElementById('progressBar');

    if (loading) loading.style.display = 'block';
    proofOutput.value = '';
    proofProgress.style.display = 'block';
    progressBar.style.width = '10%';

    try {
        // Check if wasm file exists
        const wasmPath = "circuit_js/group_signature_js/group_signature.wasm";
        console.log('Checking wasm file:', wasmPath);
        const wasmResponse = await fetch(wasmPath);
        if (!wasmResponse.ok) {
            throw new Error(`Wasm file not found at ${wasmPath}`);
        }
        console.log('Wasm file found and accessible');

        // Simulate progress: fetching input
        progressBar.style.width = '30%';
        console.log('Fetching test input...');
        const input = await fetch('test_input.json').then(r => r.json());
        progressBar.style.width = '50%';

        console.log('Generating proof...');
        const { proof, publicSignals } = await snarkjs.groth16.fullProve(
            input,
            wasmPath,
            "circuit_0001.zkey"
        );
        progressBar.style.width = '100%';

        proofOutput.value = JSON.stringify({
            proof: proof,
            publicSignals: publicSignals
        }, null, 2);
    } catch (error) {
        console.error('Error during proof generation:', error);
        if (error.message && error.message.includes("Assert Failed")) {
            proofOutput.value = 'Error: Signature does not verify!';
        } else {
            proofOutput.value = 'Error: ' + error.message;
        }
    } finally {
        if (loading) loading.style.display = 'none';
        setTimeout(() => {
            proofProgress.style.display = 'none';
            progressBar.style.width = '0%';
        }, 800);
    }
}

// Make it available globally
window.generateTestProof = generateTestProof;

console.log('Script loaded successfully');

// Define functions in global scope first
window.testFunction = function() {
    console.log('Test function called');
    generateTestProof();
};

function getArrayInputs(textareaId) {
    const textarea = document.getElementById(textareaId);
    return textarea.value.split('\n').map(line => line.trim()).filter(line => line !== '');
}

function extractRSAFromSSH(sshKey) {
    try {
        console.log('extractRSAFromSSH input:', sshKey);
        
        // Remove the key type and comment
        const keyParts = sshKey.split(' ');
        if (keyParts.length < 2) {
            throw new Error('Invalid SSH key format');
        }
        console.log('Key parts:', keyParts);

        // Decode the base64 part
        const keyData = atob(keyParts[1]);
        console.log('Decoded key data length:', keyData.length);
        
        // Convert to array of bytes
        const bytes = new Uint8Array(keyData.length);
        for (let i = 0; i < keyData.length; i++) {
            bytes[i] = keyData.charCodeAt(i);
        }
        console.log('First few bytes:', Array.from(bytes.slice(0, 10)));

        // Skip the key type length and key type
        let offset = 0;
        const keyTypeLen = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
        console.log('Key type length:', keyTypeLen);
        offset += 4 + keyTypeLen;

        // Read public exponent (e) length and value
        const eLen = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += 4;
        const eBytes = bytes.slice(offset, offset + eLen);
        offset += eLen;
        const eHex = Array.from(eBytes).map(b => b.toString(16).padStart(2, '0')).join('');
        const e = BigInt('0x' + eHex);
        console.log('e length:', eLen, 'e value:', e);

        // Read modulus (n) length and value
        const nLen = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += 4;
        const nBytes = bytes.slice(offset, offset + nLen);
        console.log('n length:', nLen, 'N bytes length:', nBytes.length);

        // Handle potential leading zero byte for n if present (ASN.1 DER encoding)
        let actualNBytes = nBytes;
        if (nBytes.length > 0 && nBytes[0] === 0x00) {
            actualNBytes = nBytes.slice(1);
        }

        const nHex = Array.from(actualNBytes)
            .map(b => b.toString(16).padStart(2, '0'))
            .join('');
        console.log('N hex:', nHex);
        const n = BigInt('0x' + nHex);

        return { n, e };
    } catch (error) {
        console.error('Error in extractRSAFromSSH:', error);
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
    const message = document.getElementById('message').value;
    const signer_sk = document.getElementById('signer_sk').value;
    const publicKeys = getArrayInputs('nValue');
    const proofOutput = document.getElementById('proofOutput');
    const loading = document.getElementById('loading');
    
    loading.style.display = 'block';
    proofOutput.value = '';

    try {
        // Get double_blind_hash
        const doubleBlindHash = await getDoubleBlindHash();
        console.log('Double blind hash:', doubleBlindHash);
        console.log('Double blind hash first chunk:', doubleBlindHash[0]);
        
        // Process signer's SSHSIG
        const { n: signerN, s: signerS } = processSSHSIG(signer_sk);
        console.log('Signer N:', signerN);
        console.log('Signer N first chunk:', signerN[0]);
        console.log('Signer S:', signerS);
        console.log('Signer S first chunk:', signerS[0]);

        // Process public keys
        const rsaParams = publicKeys.map(extractRSAFromSSH);
        
        // Check if any e is not 65537
        const invalidE = rsaParams.find(p => p.e !== 65537n);
        if (invalidE) {
            throw new Error('All public keys must have e=65537');
        }

        // Extract N values and format them into base 2^121 chunks
        let formattedNValues = rsaParams.map(p => formatToBase2_121(p.n));
        console.log('Formatted N values extracted (first chunk of each):', formattedNValues.map(n => n[0]));

        // Add signer's N if not already present in the list
        const signerNExists = formattedNValues.some(nArr => nArr[0] === signerN[0] && nArr.every((val, idx) => val === signerN[idx]));

        if (!signerNExists) {
            formattedNValues.push(signerN);
        }

        // Randomize order
        formattedNValues = formattedNValues.sort(() => Math.random() - 0.5);

        // Check length and pad if needed
        if (formattedNValues.length > 20) {
            throw new Error('Maximum 20 public keys allowed');
        }
        const oneInChunks = formatToBase2_121(1n); // Pre-calculate 1n in chunk format
        while (formattedNValues.length < 20) {
            formattedNValues.push(oneInChunks);
        }

        // Hash the message - keep as a single value
        const messageHash = await hashMessage(message);
        console.log('Message hash:', messageHash);

        const input = {
            double_blind_hash: doubleBlindHash,
            signer_sk: signerS, // Using the actual signature value
            signer_pk_N: signerN, // Using the signer's N
            public_N: formattedNValues,
            message_hash: messageHash, // Pass as a single value
            election_id: "0"
        };

        console.log('Final input values:');
        console.log('double_blind_hash:', input.double_blind_hash);
        console.log('signer_sk:', input.signer_sk);
        console.log('signer_pk_N:', input.signer_pk_N);
        console.log('public_N:', input.public_N);
        console.log('message_hash:', input.message_hash);

        // Save inputs to a JSON file for local debugging
        const inputJsonString = JSON.stringify(input, (key, value) => {
            if (typeof value === 'bigint') {
                return value.toString();
            }
            return value;
        }, 2);
        const blob = new Blob([inputJsonString], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'input.json';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log('Input values saved to input.json');

        const { proof, publicSignals } = await snarkjs.groth16.fullProve(
            input,
            "circuit_js/group_signature_js/group_signature.wasm",
            "circuit_0001.zkey"
        );

        proofOutput.value = JSON.stringify({
            proof: proof,
            publicSignals: publicSignals
        }, null, 2);
    } catch (error) {
        proofOutput.value = 'Error: ' + error.message;
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

// Debug the button element immediately
const testButton = document.getElementById('testProofButton');
console.log('Button element found:', testButton);

// Try both ways of attaching the event listener
if (testButton) {
    // Method 1: Direct onclick
    testButton.onclick = function() {
        console.log('Button clicked via onclick');
        generateTestProof();
    };
    
    // Method 2: addEventListener
    testButton.addEventListener('click', function() {
        console.log('Button clicked via addEventListener');
        generateTestProof();
    });
    
    console.log('Event listeners attached');
} else {
    console.error('Could not find test proof button!');
}

// Add a test function to verify global scope
window.testFunction = function() {
    console.log('Test function called');
};

// Helper function to format a number into base 2^121 chunks
function formatToBase2_121(num) {
    const base = BigInt(2) ** BigInt(121);
    const chunks = [];
    let remaining = BigInt(num);
    
    // Get 34 chunks
    for (let i = 0; i < 34; i++) {
        chunks.push(remaining % base);
        remaining = remaining / base;
    }
    
    // Convert chunks to decimal strings
    return chunks.map(chunk => chunk.toString());
}

// Helper function to parse double_blind_hash.txt
async function getDoubleBlindHash() {
    try {
        const response = await fetch('double_blind_hash.txt');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const hexString = await response.text();
        if (!hexString) {
            throw new Error('File is empty');
        }
        // Remove any whitespace and ensure it starts with 0x
        const cleanHex = hexString.trim();
        if (!cleanHex.startsWith('0x')) {
            // Convert to BigInt
            const value = BigInt('0x' + cleanHex);
            // Format into base 2^121 chunks
            return formatToBase2_121(value);
        } else {
            // Already has 0x prefix
            const value = BigInt(cleanHex);
            return formatToBase2_121(value);
        }
    } catch (error) {
        console.error('Error reading double_blind_hash.txt:', error);
        throw new Error('Failed to read double_blind_hash.txt: ' + error.message);
    }
}

// Helper function to hash a message (using SHA-256 for now)
async function hashMessage(message) {
    const encoder = new TextEncoder();
    const data = encoder.encode(message);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    return BigInt('0x' + hashHex);
}

// Helper function to process SSHSIG
function processSSHSIG(sshSig) {
    try {
        console.log('processSSHSIG input:', sshSig);
        
        // Get the signer's public key
        const signerPk = document.getElementById('signer_pk').value.trim();
        console.log('Signer public key:', signerPk);
        
        if (!signerPk) {
            throw new Error('Signer public key is required');
        }

        // Extract N and e from the public key
        const { n, e } = extractRSAFromSSH(signerPk);
        console.log('Extracted n:', n);
        console.log('Extracted e:', e);
        
        // Verify e is 65537
        if (e !== 65537n) {
            throw new Error('Invalid e value in public key');
        }

        // Get signature from SSHSIG
        const cleanSig = sshSig.trim();
        console.log('Cleaned signature:', cleanSig);
        const sigBytes = new Uint8Array(atob(cleanSig).split('').map(c => c.charCodeAt(0)));
        console.log('Signature bytes:', Array.from(sigBytes));
        const s = BigInt('0x' + Array.from(sigBytes)
            .map(b => b.toString(16).padStart(2, '0'))
            .join(''));
        console.log('Signature value (raw):', s);
        
        // Mask signer_sk to 4096 bits by taking it modulo 2^4096
        const modulus4096 = BigInt(2) ** BigInt(4096);
        const maskedS = s % modulus4096;
        console.log('Signature value (masked to 4096 bits):', maskedS);

        // Return the signature as signer_sk and the public key modulus as signer_pk_N
        return {
            n: formatToBase2_121(n),
            s: formatToBase2_121(maskedS)
        };
    } catch (error) {
        console.error('Error in processSSHSIG:', error);
        throw new Error(`Invalid SSHSIG format: ${error.message}`);
    }
} 