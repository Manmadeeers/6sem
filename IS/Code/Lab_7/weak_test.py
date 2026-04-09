import binascii

class DES:
    def __init__(self, key_hex):
        self.key = self.hex_to_bits(key_hex)
        self.subkeys = self.generate_subkeys(self.key)

    @staticmethod
    def hex_to_bits(hex_str):
        hex_str = hex_str.replace(" ", "")
        return bin(int(hex_str, 16))[2:].zfill(64)

    @staticmethod
    def bits_to_hex(bits):
        return hex(int(bits, 2))[2:].zfill(16).upper()

    def permute(self, bits, table):
        return "".join(bits[i - 1] for i in table)

    def generate_subkeys(self, key):
        # Tables for subkey generation
        PC1 = [57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18, 10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36,
               63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22, 14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4]
        PC2 = [14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10, 23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2, 41, 52, 31, 37,
               47, 55, 30, 40, 51, 45, 33, 48, 44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32]
        SHIFTS = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]

        key_56 = self.permute(key, PC1)
        C, D = key_56[:28], key_56[28:]
        subkeys = []
        for shift in SHIFTS:
            C = C[shift:] + C[:shift]
            D = D[shift:] + D[:shift]
            subkeys.append(self.permute(C + D, PC2))
        return subkeys

    def f_function(self, R, subkey):
        # Simplified F-function for logic demonstration
        # In a real DES, this includes Expansion, S-boxes, and P-permutation
        return "".join('1' if R[i] != subkey[i % 48] else '0' for i in range(len(R)))

    def encrypt_block(self, block_hex, verbose=False):
        bits = self.hex_to_bits(block_hex)
        L, R = bits[:32], bits[32:]
        
        if verbose:
            print(f"Initial L: {self.bits_to_hex(L).zfill(8)}, R: {self.bits_to_hex(R).zfill(8)}")

        for i in range(16):
            new_R = "".join('1' if L[j] != self.f_function(R, self.subkeys[i])[j] else '0' for j in range(32))
            L, R = R, new_R
            if verbose:
                print(f"Round {i+1:2}: L={self.bits_to_hex(L).zfill(8)}, R={self.bits_to_hex(R).zfill(8)}")
        
        return self.bits_to_hex(R + L) # Final Swap

def calculate_avalanche(bits1, bits2):
    return sum(b1 != b2 for b1, b2 in zip(bits1, bits2))

def analyze_keys():
    weak_keys = ["0101010101010101", "1F1F1F1F0E0E0E0E", "E0E0E0E0F1F1F1F1", "FEFEFEFEFEFEFEFE"]
    semi_weak_pairs = [
        ("01FE01FE01FE01FE", "FE01FE01FE01FE01"),
        ("1FE01FE00EF10EF1", "E01FE01FF10EF10E")
    ]
    
    plaintext = "0123456789ABCDEF"
    plaintext_alt = "0123456789ABCDEE" # 1 bit difference
    
    print("=== Analysis of Weak Keys ===")
    for wk in weak_keys:
        des = DES(wk)
        c1 = des.encrypt_block(plaintext)
        c2 = des.encrypt_block(plaintext_alt)
        
        b1 = bin(int(c1, 16))[2:].zfill(64)
        b2 = bin(int(c2, 16))[2:].zfill(64)
        diff = calculate_avalanche(b1, b2)
        
        # Check if encryption is its own decryption
        c_double = des.encrypt_block(c1)
        is_self_inverse = c_double.upper() == plaintext.upper()
        
        print(f"Key: {wk}")
        print(f"  Ciphertext: {c1}")
        print(f"  Avalanche (1-bit change): {diff} bits")
        print(f"  Self-inverse: {is_self_inverse}")
        print("-" * 30)

    print("\n=== Analysis of Semi-Weak Keys ===")
    for k1, k2 in semi_weak_pairs:
        des1 = DES(k1)
        des2 = DES(k2)
        
        c1 = des1.encrypt_block(plaintext)
        # Encrypting ciphertext from k1 with k2 should yield plaintext
        p_recovered = des2.encrypt_block(c1)
        
        print(f"Key Pair: {k1} / {k2}")
        print(f"  P -> K1 -> C: {c1}")
        print(f"  C -> K2 -> P: {p_recovered}")
        print(f"  Recovered successfully: {p_recovered.upper() == plaintext.upper()}")
        print("-" * 30)

if __name__ == "__main__":
    analyze_keys()