import base64
import math
import secrets
import time

BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


def random_100_bit_number():
    return secrets.randbits(100) | (1 << 99)


def generate_superincreasing_sequence(z: int):
    seq = [secrets.randbelow(128) + 2]
    total = seq[0]

    for _ in range(z - 2):
        next_value = total + secrets.randbelow(total + 128) + 1
        seq.append(next_value)
        total += next_value

    last_value = random_100_bit_number()
    while last_value <= total:
        last_value = random_100_bit_number()

    seq.append(last_value)
    return seq


def choose_modulus_and_multiplier(super_seq):
    total = sum(super_seq)
    q = total + secrets.randbelow(total) + 1

    while True:
        r = secrets.randbelow(q - 2) + 2
        if math.gcd(r, q) == 1:
            return q, r


class MerkleHellmanKnapsack:
    def __init__(self, z: int):
        self.z = z
        self.private_key = generate_superincreasing_sequence(z)
        self.q, self.r = choose_modulus_and_multiplier(self.private_key)
        self.public_key = [(self.r * w) % self.q for w in self.private_key]
        self.r_inv = pow(self.r, -1, self.q)

    def encrypt_value(self, value: int) -> int:
        bits = f"{value:0{self.z}b}"
        return sum(int(bit) * b for bit, b in zip(bits, self.public_key))

    def decrypt_value(self, cipher_value: int) -> int:
        s = (cipher_value * self.r_inv) % self.q
        bits = [0] * self.z

        for i in range(self.z - 1, -1, -1):
            if self.private_key[i] <= s:
                bits[i] = 1
                s -= self.private_key[i]

        if s != 0:
            raise ValueError("Decryption error: remainder is not zero.")

        return int("".join(map(str, bits)), 2)


def prepare_ascii_payload(text: str):
    for encoding in ("cp1251", "utf-8"):
        try:
            raw = text.encode(encoding)
            return {
                "kind": "ascii",
                "encoding": encoding,
                "values": list(raw),
            }
        except UnicodeEncodeError:
            pass
    raise ValueError("Failed to encode the text into an 8-bit format.")


def restore_ascii_payload(values, encoding: str):
    return bytes(values).decode(encoding)


def prepare_base64_payload(text: str):
    raw = text.encode("utf-8")
    encoded = base64.b64encode(raw).decode("ascii")
    pad_count = len(encoded) - len(encoded.rstrip("="))
    core = encoded.rstrip("=")

    return {
        "kind": "base64",
        "pad_count": pad_count,
        "values": [BASE64_ALPHABET.index(ch) for ch in core],
        "encoded_text": encoded,
    }


def restore_base64_payload(values, pad_count: int):
    core = "".join(BASE64_ALPHABET[v] for v in values)
    encoded = core + ("=" * pad_count)
    raw = base64.b64decode(encoded)
    return raw.decode("utf-8")


def encrypt_message(crypto: MerkleHellmanKnapsack, payload: dict):
    start = time.perf_counter()
    ciphertext = [crypto.encrypt_value(v) for v in payload["values"]]
    elapsed = time.perf_counter() - start
    return ciphertext, elapsed


def decrypt_message(crypto: MerkleHellmanKnapsack, payload: dict, ciphertext):
    start = time.perf_counter()
    values = [crypto.decrypt_value(c) for c in ciphertext]

    if payload["kind"] == "ascii":
        text = restore_ascii_payload(values, payload["encoding"])
    else:
        text = restore_base64_payload(values, payload["pad_count"])

    elapsed = time.perf_counter() - start
    return text, values, elapsed


def main():
    print("Merkle-Hellman Knapsack Cryptosystem")
    print("1 - Base64 (z = 6)")
    print("2 - ASCII / 8-bit (z = 8)")

    choice = input("Select mode: ").strip()
    if choice == "1":
        z = 6
        mode_name = "Base64"
    elif choice == "2":
        z = 8
        mode_name = "ASCII / 8-bit"
    else:
        print("Invalid mode selection.")
        return

    fio = input("Enter your surname, name, and patronymic: ").strip()
    if not fio:
        print("The message must not be empty.")
        return

    crypto = MerkleHellmanKnapsack(z)

    if choice == "1":
        payload = prepare_base64_payload(fio)
    else:
        payload = prepare_ascii_payload(fio)

    ciphertext, enc_time = encrypt_message(crypto, payload)
    decrypted_text, recovered_values, dec_time = decrypt_message(crypto, payload, ciphertext)

    print("\n--- Private Key (Superincreasing Sequence) ---")
    print(crypto.private_key)
    print("Bit length of the largest element:", crypto.private_key[-1].bit_length())

    print("\n--- Key Parameters ---")
    print("q =", crypto.q)
    print("r =", crypto.r)

    print("\n--- Public Key (Normal Sequence) ---")
    print(crypto.public_key)

    print("\n--- Original Encoding ---")
    print("Mode:", mode_name)
    if payload["kind"] == "base64":
        print("Base64 string:", payload["encoded_text"])
    else:
        print("Encoding used:", payload["encoding"])
    print("Numeric blocks:", payload["values"])

    print("\n--- Ciphertext ---")
    print(ciphertext)

    print("\n--- Decryption ---")
    print("Recovered numeric blocks:", recovered_values)
    print("Decrypted message:", decrypted_text)

    print("\n--- Execution Time ---")
    print(f"Encryption: {enc_time:.8f} sec")
    print(f"Decryption: {dec_time:.8f} sec")


if __name__ == "__main__":
    main()
