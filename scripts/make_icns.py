import struct
import sys

def icns_chunk(ctype, data):
    return struct.pack('>4sI', ctype.encode(), len(data) + 8) + data

def build_icns(png_dir, out_path):
    entries = [
        ('ic11', 'icon_32x32.png'),
        ('ic12', 'icon_32x32@2x.png'),
        ('ic07', 'icon_128x128.png'),
        ('ic08', 'icon_256x256.png'),
        ('ic09', 'icon_512x512.png'),
        ('ic10', 'icon_512x512@2x.png'),
    ]
    payload = b''
    for ctype, name in entries:
        with open(f'{png_dir}/{name}', 'rb') as f:
            payload += icns_chunk(ctype, f.read())
    with open(out_path, 'wb') as f:
        f.write(b'icns' + struct.pack('>I', len(payload) + 8) + payload)

if __name__ == '__main__':
    build_icns(sys.argv[1], sys.argv[2])
