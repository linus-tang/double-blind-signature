import sys
import re
import struct
import base64

def clean_base64(data: str) -> str:
    data = re.sub(r'\s+', '', data)
    if "Signature:" in data:
        data = data.split("Signature:")[1]
    data += '=' * ((4 - len(data) % 4) % 4)
    return data

def read_uint32(blob: bytes, offset: int):
    return struct.unpack(">I", blob[offset:offset+4])[0], offset + 4

def read_string(blob: bytes, offset: int):
    length, offset = read_uint32(blob, offset)
    return blob[offset:offset+length], offset + length

def parse_ssh_signature(b64_blob: str):
    b64 = clean_base64(b64_blob)
    blob = base64.b64decode(b64)
    assert blob.startswith(b'SSHSIG'), f"Bad magic: {blob[:6]!r}"
    off = 6
    _,         off = read_uint32(blob, off)
    pub_blob,  off = read_string(blob, off)
    _,         off = read_string(blob, off)
    _,         off = read_string(blob, off)
    _,         off = read_string(blob, off)
    sig_blob,  off = read_string(blob, off)
    _,         off2 = read_string(sig_blob, 0)
    sig_mpint, _     = read_string(sig_blob, off2)
    return pub_blob, sig_mpint

def peel_mpint(blob: bytes) -> bytes:
    if len(blob) > 4:
        length, = struct.unpack(">I", blob[:4])
        if length == len(blob) - 4:
            return blob[4:]
    return blob

def rsa_decrypt(sig_bytes: bytes, pub_blob: bytes):
    # parse public key: "ssh-rsa", mpint e, mpint n
    off = 0
    _,        off = read_string(pub_blob, off)   # skip "ssh-rsa"
    e_bytes,  off = read_string(pub_blob, off)
    n_bytes,  off = read_string(pub_blob, off)
    e = int.from_bytes(e_bytes, "big")
    n = int.from_bytes(n_bytes, "big")
    mod_len = len(n_bytes)

    # pad signature and convert to integer s
    sig = sig_bytes.rjust(mod_len, b"\x00")
    s = int.from_bytes(sig, "big")

    # compute m = s^e mod n
    m = pow(s, e, n)
    m_bytes = m.to_bytes(mod_len, "big")
    return e, n, s, m_bytes

def extract_hash_from_padded(m_bytes: bytes) -> bytes:
    # strip PKCS#1 v1.5 padding
    i = 0
    while i < len(m_bytes) and m_bytes[i] == 0x00: i += 1
    if i >= len(m_bytes) or m_bytes[i] != 0x01:
        raise ValueError("PKCS#1 padding: missing 0x01")
    i += 1
    while i < len(m_bytes) and m_bytes[i] == 0xFF: i += 1
    if i >= len(m_bytes) or m_bytes[i] != 0x00:
        raise ValueError("PKCS#1 padding: missing 0x00")
    i += 1

    # locate SHA-512 DigestInfo
    DI = bytes.fromhex("3051300d060960864801650304020305000440")
    idx = m_bytes.find(DI, i)
    if idx < 0:
        raise ValueError("DigestInfo not found")
    start = idx + len(DI)
    return m_bytes[start:start+64]

if __name__ == "__main__":
    print("Paste your SSHSIG (Base64), then Ctrl-D:")
    blob64     = sys.stdin.read()
    pub_blob,  sig_mpint = parse_ssh_signature(blob64)
    sig_raw    = peel_mpint(sig_mpint)

    e, n, s, m_bytes = rsa_decrypt(sig_raw, pub_blob)

    # recompute and verify
    m_check = pow(s, e, n)
    if m_check == int.from_bytes(m_bytes, "big"):
        print("✔ Verification: s^e mod n equals the padded block m_bytes")
    else:
        print("✖ Verification FAILED: s^e mod n does not match m_bytes")

    print(f"\ne (decimal): {e}")
    print(f"n (hex): {n.to_bytes((n.bit_length()+7)//8, 'big').hex()}")
    print(f"s (decimal): {s}")
    print(f"s (hex): {s.to_bytes((s.bit_length()+7)//8, 'big').hex()}")

    print("\n=== full padded block m = s^e mod n (hex) ===")
    print(m_bytes.hex())

    h = extract_hash_from_padded(m_bytes)
    print("\n=== extracted SHA-512 digest (hex) ===")
    print(h.hex())
