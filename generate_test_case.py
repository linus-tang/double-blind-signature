import random
import math
import json
from typing import List, Tuple

def generate_random_bits(n_bits: int) -> int:
    """Generate a random n-bit integer."""
    return random.randint(0, (1 << n_bits) - 1)

def split_into_chunks(num: int, chunk_size: int, num_chunks: int) -> List[str]:
    """Split a number into chunks of specified size and format as decimal strings."""
    chunks = []
    for i in range(num_chunks):
        chunk = (num >> (i * chunk_size)) & ((1 << chunk_size) - 1)
        chunks.append(str(chunk))
    return chunks

def generate_rsa_key_pair() -> Tuple[int, int, int]:
    """Generate a simple RSA key pair (N, e, d) where e=65537."""
    # For simplicity, we'll use small primes for testing
    p = 17
    q = 19
    N = p * q
    phi = (p - 1) * (q - 1)
    e = 65537
    d = pow(e, -1, phi)
    return N, e, d

def generate_test_case():
    # Generate RSA key pair
    N, e, d = generate_rsa_key_pair()
    
    # Generate random message hash and election ID (250 bits each)
    message_hash = generate_random_bits(250)
    election_id = generate_random_bits(250)
    
    # Generate random signer_sk (512 bits)
    signer_sk = generate_random_bits(512)
    
    # Calculate double_blind_hash = signer_sk^e mod N
    double_blind_hash = pow(signer_sk, e, N)
    
    # Generate two public keys (N values)
    public_N = [N, generate_random_bits(512)]
    
    # Format all 512-bit numbers into 5 chunks of 103 bits
    def format_512bit(num: int) -> List[str]:
        return split_into_chunks(num, 103, 5)
    
    # Create the test case
    test_case = {
        "double_blind_hash": format_512bit(double_blind_hash),
        "signer_sk": format_512bit(signer_sk),
        "signer_pk_N": format_512bit(N),
        "signer_pk_e": str(e),
        "public_N": [format_512bit(n) for n in public_N],
        "public_e": [str(e), str(e)],
        "message_hash": str(message_hash),
        "election_id": str(election_id)
    }
    
    return test_case

if __name__ == "__main__":
    # Set random seed for reproducibility
    random.seed(42)
    
    # Generate test case
    test_case = generate_test_case()
    
    # Format the output as a C-style comment
    output = "/* INPUT =\n"
    output += json.dumps(test_case, indent=4)
    output += "\n*/"
    
    print(output) 