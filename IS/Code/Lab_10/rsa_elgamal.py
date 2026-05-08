import base64
import math
import secrets
import time
from pathlib import Path

BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
ASCII_ENCODINGS = ("cp1251", "utf-8")

# Pre-generated demo keys so the program starts immediately.
# RSA modulus size: about 512 bits
RSA_P = 109128071290248944840517186250257601343673332571315400685002521760808581292023
RSA_Q = 84362875356490907791255522068091692760201620293340159498236187690572669052011

# ElGamal prime size: about 512 bits
ELGAMAL_P = 8718452168509237661871058140090079394582274050763880418550638197047230928117229453593750405235568990875074026960386712511653956378913819905595053495613723
ELGAMAL_G = 5


class RSA:
    def __init__(self):
        self.p = RSA_P
        self.q = RSA_Q
        self.n = self.p * self.q
        self.e = 65537
        phi = (self.p - 1) * (self.q - 1)
        self.d = pow(self.e, -1, phi)
        self.block_bytes = (self.n.bit_length() + 7) // 8

    def encrypt_values(self, values):
        return [pow(v, self.e, self.n) for v in values]

    def decrypt_values(self, blocks):
        return [pow(c, self.d, self.n) for c in blocks]

    def ciphertext_size_bytes(self, blocks):
        return len(blocks) * self.block_bytes


class ElGamal:
    def __init__(self):
        self.p = ELGAMAL_P
        self.g = ELGAMAL_G
        self.x = secrets.randbelow(self.p - 3) + 2
        self.y = pow(self.g, self.x, self.p)
        self.block_bytes = (self.p.bit_length() + 7) // 8

    def encrypt_values(self, values):
        result = []
        for m in values:
            k = secrets.randbelow(self.p - 3) + 2
            a = pow(self.g, k, self.p)
            b = (m * pow(self.y, k, self.p)) % self.p
            result.append((a, b))
        return result

    def decrypt_values(self, blocks):
        result = []
        for a, b in blocks:
            s = pow(a, self.x, self.p)
            m = (b * pow(s, -1, self.p)) % self.p
            result.append(m)
        return result

    def ciphertext_size_bytes(self, blocks):
        return len(blocks) * 2 * self.block_bytes


def read_text_file(path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-8", "cp1251"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            pass
    raise ValueError("Could not decode the text file.")


def get_source_text() -> str:
    print("1 - Enter text manually")
    print("2 - Load text from .txt file")
    choice = input("Choose input method: ").strip()

    if choice == "2":
        path = Path(input("Enter path to .txt file: ").strip().strip('"'))
        if not path.exists():
            raise FileNotFoundError("File not found.")
        return read_text_file(path)

    text = input("Enter surname, name, patronymic: ").strip()
    if not text:
        raise ValueError("Text must not be empty.")
    return text


def prepare_ascii_payload(text: str) -> dict:
    for encoding in ASCII_ENCODINGS:
        try:
            raw = text.encode(encoding)
            return {
                "mode": "ASCII / 8-bit",
                "encoding": encoding,
                "raw_bytes": raw,
                "values": list(raw),
            }
        except UnicodeEncodeError:
            pass
    raise ValueError("Could not encode the text into 8-bit form.")


def restore_ascii_payload(values, encoding: str) -> str:
    return bytes(values).decode(encoding)


def prepare_base64_payload(text: str) -> dict:
    raw = text.encode("utf-8")
    encoded = base64.b64encode(raw).decode("ascii")
    pad_count = len(encoded) - len(encoded.rstrip("="))
    core = encoded.rstrip("=")

    return {
        "mode": "Base64",
        "encoding": "base64",
        "raw_bytes": raw,
        "encoded_text": encoded,
        "pad_count": pad_count,
        "values": [BASE64_ALPHABET.index(ch) for ch in core],
    }


def restore_base64_payload(values, pad_count: int) -> str:
    core = "".join(BASE64_ALPHABET[v] for v in values)
    encoded = core + ("=" * pad_count)
    return base64.b64decode(encoded).decode("utf-8")


def restore_text(payload: dict, values) -> str:
    if payload["mode"] == "ASCII / 8-bit":
        return restore_ascii_payload(values, payload["encoding"])
    return restore_base64_payload(values, payload["pad_count"])


def preview_list(items, limit=3) -> str:
    if len(items) <= limit:
        return str(items)
    return f"{items[:limit]} ... total blocks: {len(items)}"


def preview_pairs(items, limit=2) -> str:
    if len(items) <= limit:
        return str(items)
    return f"{items[:limit]} ... total pairs: {len(items)}"


def benchmark_algorithm(name: str, cipher, payload: dict, source_text: str) -> dict:
    t1 = time.perf_counter()
    encrypted = cipher.encrypt_values(payload["values"])
    enc_time = time.perf_counter() - t1

    t2 = time.perf_counter()
    decrypted_values = cipher.decrypt_values(encrypted)
    dec_time = time.perf_counter() - t2

    restored_text = restore_text(payload, decrypted_values)
    ciphertext_size = cipher.ciphertext_size_bytes(encrypted)
    plaintext_size = len(payload["raw_bytes"])
    ratio = ciphertext_size / plaintext_size
    growth_percent = (ratio - 1.0) * 100.0

    if name == "RSA":
        cipher_preview = preview_list(encrypted)
    else:
        cipher_preview = preview_pairs(encrypted)

    return {
        "name": name,
        "enc_time_ms": enc_time * 1000,
        "dec_time_ms": dec_time * 1000,
        "ciphertext_size": ciphertext_size,
        "plaintext_size": plaintext_size,
        "ratio": ratio,
        "growth_percent": growth_percent,
        "restored_ok": restored_text == source_text,
        "restored_text": restored_text,
        "cipher_preview": cipher_preview,
    }


def print_report(payload: dict, rsa: RSA, elgamal: ElGamal, rsa_result: dict, elgamal_result: dict):
    print("\n" + "=" * 72)
    print("INPUT DATA")
    print("=" * 72)
    print(f"Encoding mode: {payload['mode']}")
    print(f"Original text size: {len(payload['raw_bytes'])} bytes")
    print(f"Encoded block count: {len(payload['values'])}")

    if payload["mode"] == "ASCII / 8-bit":
        print(f"Byte encoding used: {payload['encoding']}")
    else:
        print(f"Base64 text: {payload['encoded_text']}")

    print("\n" + "=" * 72)
    print("KEY INFORMATION")
    print("=" * 72)
    print(f"RSA modulus length: {rsa.n.bit_length()} bits")
    print(f"ElGamal prime length: {elgamal.p.bit_length()} bits")

    print("\n" + "=" * 72)
    print("RSA")
    print("=" * 72)
    print(f"Encryption time: {rsa_result['enc_time_ms']:.3f} ms")
    print(f"Decryption time: {rsa_result['dec_time_ms']:.3f} ms")
    print(f"Ciphertext size: {rsa_result['ciphertext_size']} bytes")
    print(f"Ciphertext / plaintext: {rsa_result['ratio']:.2f}x")
    print(f"Relative size growth: {rsa_result['growth_percent']:.2f}%")
    print(f"Restored correctly: {rsa_result['restored_ok']}")
    print(f"Decrypted text: {rsa_result['restored_text']}")
    print(f"Cipher preview: {rsa_result['cipher_preview']}")

    print("\n" + "=" * 72)
    print("ELGAMAL")
    print("=" * 72)
    print(f"Encryption time: {elgamal_result['enc_time_ms']:.3f} ms")
    print(f"Decryption time: {elgamal_result['dec_time_ms']:.3f} ms")
    print(f"Ciphertext size: {elgamal_result['ciphertext_size']} bytes")
    print(f"Ciphertext / plaintext: {elgamal_result['ratio']:.2f}x")
    print(f"Relative size growth: {elgamal_result['growth_percent']:.2f}%")
    print(f"Restored correctly: {elgamal_result['restored_ok']}")
    print(f"Decrypted text: {elgamal_result['restored_text']}")
    print(f"Cipher preview: {elgamal_result['cipher_preview']}")

    print("\n" + "=" * 72)
    print("COMPARISON")
    print("=" * 72)

    faster_enc = "RSA" if rsa_result["enc_time_ms"] < elgamal_result["enc_time_ms"] else "ElGamal"
    faster_dec = "RSA" if rsa_result["dec_time_ms"] < elgamal_result["dec_time_ms"] else "ElGamal"
    smaller_cipher = "RSA" if rsa_result["ciphertext_size"] < elgamal_result["ciphertext_size"] else "ElGamal"

    print(f"Faster encryption: {faster_enc}")
    print(f"Faster decryption: {faster_dec}")
    print(f"Smaller ciphertext: {smaller_cipher}")


def main():
    print("RSA and ElGamal Text Encryption Demo")
    print("Supported encoding modes: Base64 and ASCII / 8-bit")
    print("Pre-generated demo keys are used to avoid long startup time.")
    print()

    source_text = get_source_text()

    print("\n1 - Base64")
    print("2 - ASCII / 8-bit")
    mode = input("Choose encoding mode: ").strip()

    if mode == "1":
        payload = prepare_base64_payload(source_text)
    elif mode == "2":
        payload = prepare_ascii_payload(source_text)
    else:
        raise ValueError("Invalid encoding mode.")

    print("\nLoading RSA keys...")
    rsa = RSA()

    print("Loading ElGamal keys...")
    elgamal = ElGamal()

    print("Running RSA encryption/decryption...")
    rsa_result = benchmark_algorithm("RSA", rsa, payload, source_text)

    print("Running ElGamal encryption/decryption...")
    elgamal_result = benchmark_algorithm("ElGamal", elgamal, payload, source_text)

    print_report(payload, rsa, elgamal, rsa_result, elgamal_result)


if __name__ == "__main__":
    main()
