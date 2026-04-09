import time
from Crypto.Cipher import DES
class DES_EEE3_App:
    def __init__(self, full_key_str):
        # Подготовка ключей по Варианту А: "Информационнаябезопаснос"
        key_bytes = full_key_str.encode('cp1251', errors='ignore')
        # Разделяем на 3 части по 8 байт
        self.k1 = key_bytes[0:8].ljust(8, b'\0')
        self.k2 = key_bytes[8:16].ljust(8, b'\0')
        self.k3 = key_bytes[16:24].ljust(8, b'\0')
        self.block_size = 8
    def add_padding(self, data):
        padding_len = self.block_size - (len(data) % self.block_size)
        padding = bytes([padding_len]) * padding_len
        return data + padding
    def remove_padding(self, data):
        padding_len = data[-1]
        return data[:-padding_len]
    def split_to_lr(self, block):
        """Разбивает 8-байтовый блок на левую (L) и правую (R) части по 4 байта"""
        left = block[:4]
        right = block[4:]
        return left.hex(), right.hex()
    def encrypt_step_by_step(self, block, show_lr=False):
        """Алгоритм DES-EEE3 с выводом L и R блоков на каждом этапе"""
        c1 = DES.new(self.k1, DES.MODE_ECB)
        c2 = DES.new(self.k2, DES.MODE_ECB)
        c3 = DES.new(self.k3, DES.MODE_ECB)
        # Этап 1: E(K1)
        res_e1 = c1.encrypt(block)
        if show_lr:
            l, r = self.split_to_lr(res_e1)
            print(f"  [Stage 1] L: {l}, R: {r}")
        # Этап 2: E(K2)
        res_e2 = c2.encrypt(res_e1)
        if show_lr:
            l, r = self.split_to_lr(res_e2)
            print(f"  [Stage 2] L: {l}, R: {r}")
        # Этап 3: E(K3)
        res_e3 = c3.encrypt(res_e2)
        if show_lr:
            l, r = self.split_to_lr(res_e3)
            print(f"  [Stage 3] L: {l}, R: {r}")
        return [res_e1, res_e2, res_e3]
    def decrypt_step_by_step(self, block, show_lr=False):
        """Алгоритм дешифрования для EEE3 с выводом L и R блоков"""
        c1 = DES.new(self.k1, DES.MODE_ECB)
        c2 = DES.new(self.k2, DES.MODE_ECB)
        c3 = DES.new(self.k3, DES.MODE_ECB)
        # Этап 1: D(K3)
        res_d1 = c3.decrypt(block)
        if show_lr:
            l, r = self.split_to_lr(res_d1)
            print(f"  [Stage 1] L: {l}, R: {r}")
        # Этап 2: D(K2)
        res_d2 = c2.decrypt(res_d1)
        if show_lr:
            l, r = self.split_to_lr(res_d2)
            print(f"  [Stage 2] L: {l}, R: {r}")
        # Этап 3: D(K1)
        res_d3 = c1.decrypt(res_d2)
        if show_lr:
            l, r = self.split_to_lr(res_d3)
            print(f"  [Stage 3] L: {l}, R: {r}")
        return [res_d1, res_d2, res_d3]
    def run_full_encryption(self, text):
        data = self.add_padding(text.encode('utf-8'))
        res = b""
        print("\nEncryption Steps (L/R split per block):")
        for i in range(0, len(data), 8):
            block = data[i:i+8]
            print(f"Block {i//8 + 1}:")
            steps = self.encrypt_step_by_step(block, show_lr=True)
            res += steps[-1]
        return res
    def run_full_decryption(self, encrypted_data):
        padded = b""
        print("\nDecryption Steps (L/R split per block):")
        for i in range(0, len(encrypted_data), 8):
            block = encrypted_data[i:i+8]
            print(f"Block {i//8 + 1}:")
            steps = self.decrypt_step_by_step(block, show_lr=True)
            padded += steps[-1]
        return self.remove_padding(padded).decode('utf-8')
    def count_diff_bits(self, b1, b2):
        return sum(bin(byte1 ^ byte2).count('1') for byte1, byte2 in zip(b1, b2))
    def analyze_avalanche_steps(self, text):
        print("\n--- Step-by-step analysis of avalanche effect (first block) ---")
        data_orig = self.add_padding(text.encode('utf-8'))[:8]
        data_mod = bytearray(data_orig)
        data_mod[0] ^= 1
        steps_orig = self.encrypt_step_by_step(data_orig)
        steps_mod = self.encrypt_step_by_step(data_mod)
        labels = ["Stage 1: E(K1)", "Stage 2: E(K2)", "Stage 3: E(K3)"]
        for i in range(3):
            diff = self.count_diff_bits(steps_orig[i], steps_mod[i])
            percent = (diff / 64) * 100
            print(f"{labels[i]}: changed {diff} of 64 bits ({percent:.2f}%)")
if __name__ == "__main__":
    print("=== DES-EEE3 ===")
    full_key = "Информационнаябезопаснос"
    print(f"Key string: {full_key}")
    app = DES_EEE3_App(full_key)
    print(f"K1: {app.k1.decode('cp1251', errors='replace')}")
    print(f"K2: {app.k2.decode('cp1251', errors='replace')}")
    print(f"K3: {app.k3.decode('cp1251', errors='replace')}")
    user_msg = input("\nEnter the message to be encrypted: ")
    # 1. Шифрование
    print("\n--- Encryption process ---")
    start_enc = time.time()
    encrypted = app.run_full_encryption(user_msg)
    end_enc = time.time()
    print(f"\nFinal Cipher (hex): {encrypted.hex()}")
    print(f"Encryption time: {end_enc - start_enc:.6f} сек")
    # 2. Расшифрование
    print("\n--- Decryption process ---")
    start_dec = time.time()
    decrypted = app.run_full_decryption(encrypted)
    end_dec = time.time()
    print(f"\nFinal Result: {decrypted}")
    print(f"Decryption time: {end_dec - start_dec:.6f} сек")
    # 3. Лавинный эффект
    app.analyze_avalanche_steps(user_msg)