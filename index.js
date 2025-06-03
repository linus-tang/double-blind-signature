const snarkjs = require("snarkjs");
const fs = require("fs");

async function run() {
    // Generate the witness
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        {
            message: "123",
            blinding_factor: "456",
            private_key: "789"
        },
        "circuit_js/circuit.wasm",
        "circuit_final.zkey"
    );

    console.log("Proof:", proof);
    console.log("Public Signals:", publicSignals);

    // Verify the proof
    const vKey = JSON.parse(fs.readFileSync("verification_key.json"));
    const res = await snarkjs.groth16.verify(vKey, publicSignals, proof);

    if (res === true) {
        console.log("Verification OK");
    } else {
        console.log("Invalid proof");
    }
}

run().then(() => {
    process.exit(0);
}).catch((error) => {
    console.error(error);
    process.exit(1);
}); 