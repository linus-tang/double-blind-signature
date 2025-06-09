import json
def hex_to_bigint(hex_str):
    return int(hex_str, 16)

def format_from_base2_121(chunks):
    base = 2**121
    num = 0
    for i, chunk_str in enumerate(chunks):
        num += int(chunk_str) * (base**i)
    return num

with open('input (8).json', 'r') as f:
    data = json.load(f)

signer_pk_N_chunks = data['signer_pk_N']
signer_sk_chunks = data['signer_sk']
message_hash_str = data['message_hash']

# Reassemble signer_pk_N and signer_sk from chunks
signer_pk_N = format_from_base2_121(signer_pk_N_chunks)
signer_sk = format_from_base2_121(signer_sk_chunks)

# Convert message_hash to BigInt
message_hash = int(message_hash_str)

print(f'signer_pk_N (hex): {hex(signer_pk_N)}')
print(f'signer_sk (hex): {hex(signer_sk)}')
print(f'message_hash (hex): {hex(message_hash)}')
