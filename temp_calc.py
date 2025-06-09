import binascii

# Convert hex strings to integers
def hex_to_int(hex_str):
    return int(hex_str, 16)

# Convert signature chunks to single integer
signature_chunks = [
    '4fd883ed7e03d1105c9b015c5cabae4c',
    '06eeaeb2b7f390bc6987b441997131d7',
    '9d5472bc279c22c667693189525eb48d',
    '62e7de940acfa035f773eb22a24f9119',
    '7dbadae9b3d27d75add54b78a62dcd9a',
    '1b1e090dbc42066f6df6df4c9fa7b150',
    '097586c58bb487c58e466e578b9bc8f1',
    '747fe76bc07baa514637d17633526a67',
    'cf7ee2d0232fb95044cef798c6c3c8cb',
    '3603592c1bbcc2f3f1bb690ec1d6f14f',
    '83e5ab7f59727ef1a62080e10dde4fb5',
    '01bb97bcc90cb60ac22db2faf3b72823',
    '6a65def79725cacd4c847337d0c93d5c',
    '31470ac47598ef9e2f33967f4e40b83d',
    'a263c90c48d4c9d7958a3832bbdfa4d5',
    '430f8a9890646304a800cb933af87343',
    '742a536bb7a0a727e3b9e8ba2ac9721f',
    '2a78da0c1b5e4e5f9f5f7e74ea8743b5',
    'f29c4b1d2789b09366719fd8299421d6',
    'c4d31a9dbe6f92653de43032d342df3c',
    '32087ed414bdfa25027124074875cab6',
    'f297e2256172d836f1d4f0b2587e43cc',
    'f6257ed9eeec6730b986e3e6dd12e626',
    '909edad78fc5f30a8d1bc122cf65954d',
    '0f544f42621206defc77d82bfbe59444',
    'e5d5104e16d83c230c94ed1d456b1730',
    '48c9660e8e778e41fe805a0cfdc4baf4',
    '10994bdcf6614affb8d01b6824ca3f82',
    '16f6dd1a87c91563d14032e14efaf24f',
    'cdf644a80fe86c89d1e4af513ff2f064',
    'cde0a0315d5bf360d60f92a00d10fd10',
    '27988898c82616bdc7349c1bdfad7945'
]

# Convert N chunks to single integer
N_chunks = [
    'bc87de23a1304d3b48f74b0e1568a35c',
    'f91a4498312b4ab1e8e7f4ff66df8ba3',
    'e2ec552e03f6ad9eaf5c20094ccbd24e',
    'b24f066936bb8bac87ac79ce9bb9c1ee',
    'd62966fe300ba48089764d3a2b9a79d3',
    '09a2076c5ecaea0e3a28b2b20e790eb5',
    '95b1527fd4ff15f1fa6a2709cf7a6e8a',
    'f3a9e6b346ae8671b2c900a769456ea9',
    '96aa9f3939cd89715d0a41d695d9f0e6',
    '6fb2683ac27f68e466555078696c5966',
    '82486f528d9e2944801054c431c46254',
    '68734f850cfd1193741f6494bc013e97',
    'eeedb17da39c542647fb03265d08aea7',
    '5fc7ee63ec03290aa27171cadaee1a9e',
    '96af9e6e827ce501bf8105d7a181b684',
    'be37b3acc95d1d3697364566e697bc17',
    '1e7c6ce1a0bbc4eea6ccfd28e9f13811',
    '491f3790f127fda1bf331e0df56f10db',
    'e606db9456e57d85607305c34f71b360',
    '070c1e090c0050d779de40c1d5f16780',
    'a77121ef0d9d02c09f839779a90c77b1',
    '262dae2075805a66673499301502f4a2',
    '660fa3136a4a77aa8d9a61efe846876f',
    'f9498f3df83c96eae691b91d02ea66c7',
    'c662cd2e4e512dcb9ea4309d97d8ad40',
    '748917feb84b0b04478049f19a385f06',
    '10fce28f6f101400969d6c042c49ec16',
    '177201bd9576ff6b52d25587e5130b77',
    'b182a5b7761485f31d05940eb4e9fff8',
    'cef7debe2b8b466947d9bac82c2e260a',
    'fea668bfbd53bdc6cb5e5b534b8f52f2',
    '65a46ef98264d15eed41c343bf31f6e5'
]

# Combine chunks into single integers
signature = int(''.join(signature_chunks), 16)
N = int(''.join(N_chunks), 16)
e = 65537

# Calculate signature^e mod N
result = pow(signature, e, N)

# Convert result to hex and split into 32-character chunks
result_hex = hex(result)[2:].zfill(len(hex(N)[2:]))
chunks = [result_hex[i:i+32] for i in range(0, len(result_hex), 32)]

# Print chunks in the format needed for the test case
print('\"double_blind_hash\": [')
for chunk in chunks:
    print(f'    \"{chunk}\",')
print(']') 