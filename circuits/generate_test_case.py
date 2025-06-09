import random
import math

# Parameters
BITS_PER_CHUNK = 121  # Bits per chunk
NUM_CHUNKS = 34  # Number of chunks for numbers
GROUP_SIZE = 20  # Number of group members
SIGNER_PK_E = 65537  # Fixed exponent value

# Calculate the maximum value for each chunk
MAX_CHUNK_VALUE = 2**BITS_PER_CHUNK - 1

def chunks_to_int(chunks):
    """Convert chunks to a single integer"""
    result = 0
    for i, chunk in enumerate(chunks):
        result += chunk * (2**(BITS_PER_CHUNK * i))
    return result

def int_to_chunks(num):
    """Convert an integer to chunks"""
    chunks = []
    for _ in range(NUM_CHUNKS):
        chunks.append(num % (2**BITS_PER_CHUNK))
        num //= (2**BITS_PER_CHUNK)
    return chunks

def generate_number():
    """Generate a number split into NUM_CHUNKS chunks of BITS_PER_CHUNK bits each"""
    chunks = []
    for _ in range(NUM_CHUNKS):
        chunks.append(random.randint(0, MAX_CHUNK_VALUE))
    return chunks

def generate_250bit_number():
    """Generate a 250-bit number"""
    return random.randint(0, 2**250 - 1)

# Generate signer_pk_N first since it needs to be one of public_N
signer_pk_N = generate_number()
signer_pk_N_int = chunks_to_int(signer_pk_N)

# Generate public_N, making sure signer_pk_N is included
public_N = [signer_pk_N]  # First public key is signer's
for _ in range(GROUP_SIZE - 1):
    public_N.append(generate_number())

# Generate signer_sk
signer_sk = generate_number()
signer_sk_int = chunks_to_int(signer_sk)

# Calculate double_blind_hash to satisfy the congruence
# We need: signer_sk^65537 ≡ double_blind_hash (mod signer_pk_N)
double_blind_hash_int = pow(signer_sk_int, SIGNER_PK_E, signer_pk_N_int)
double_blind_hash = int_to_chunks(double_blind_hash_int)

# Generate message_hash and election_id as 250-bit numbers
message_hash = generate_250bit_number()
election_id = generate_250bit_number()

# Format the output
print("/* INPUT =")
print("{")
print('    "double_blind_hash": [')
for i, chunk in enumerate(double_blind_hash):
    print(f'        "{chunk}"' + ("," if i < len(double_blind_hash)-1 else ""))
print("    ],")
print('    "signer_sk": [')
for i, chunk in enumerate(signer_sk):
    print(f'        "{chunk}"' + ("," if i < len(signer_sk)-1 else ""))
print("    ],")
print('    "signer_pk_N": [')
for i, chunk in enumerate(signer_pk_N):
    print(f'        "{chunk}"' + ("," if i < len(signer_pk_N)-1 else ""))
print("    ],")
print('    "public_N": [')
for i, pk in enumerate(public_N):
    print("        [")
    for j, chunk in enumerate(pk):
        print(f'            "{chunk}"' + ("," if j < len(pk)-1 else ""))
    print("        ]" + ("," if i < len(public_N)-1 else ""))
print("    ],")
print(f'    "message_hash": "{message_hash}",')
print(f'    "election_id": "{election_id}"')
print("}")
print("*/") 