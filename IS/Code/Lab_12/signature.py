import hashlib
import json
import math
import secrets
import time
from pathlib import Path

# =========================
# Fixed parameters
# =========================




# Pre-generated RSA key pair (~2048-bit modulus) so the program starts immediately.
RSA_P = 117871716168484462230720946141749422133340051542000287148152998652479595746077936823435955924023502303521326300809942266789851788404396856844498902126428205504050927337347501773902388652226125297667044030657547955947495655766192011518019703431810506064460118154056045550980311316155293456194930230630145045539
RSA_Q = 126664486893196665474712719813896289558488819718027706935322047217130380013889389494582729319480178053177189516249415345561284845999459189149447078425280329444544274777778936194029892919155536218761975041365241673495221211523131380474033420816989600098524276345309258043319429136251617314435115296358604598101
RSA_E = 65537

# 2048-bit MODP group from RFC 3526.
MODP_2048_HEX = """

FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1
29024E088A67CC74020BBEA63B139B22514A08798E3404DD
EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245
E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED
EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D
C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F
83655D23DCA3AD961C62F356208552BB9ED529077096966D
670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B
E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9
DE2BCBF6955817183995497CEA956AE515D2261898FA0510
15728E5A8AACAA68FFFFFFFFFFFFFFFF
""".replace("\n", "").replace(" ", "")

MODP_P = int(MODP_2048_HEX, 16)
ELGAMAL_G = 2

# For Schnorr we use the prime-order subgroup of the same MODP group.
SCHNORR_Q = (MODP_P - 1) // 2
SCHNORR_G = 4  # 2^2 mod p, element of the subgroup of order q


# =========================
# Helpers
# =========================

def sha256_bytes(data: bytes) -> bytes:
    return hashlib.sha256(data).digest()


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def hash_to_int(data: bytes, modulus: int | None = None) -> int:
    value = int.from_bytes(sha256_bytes(data), "big")
    if modulus is not None:
        value %= modulus
        if value == 0:
            value = 1
    return value


def int_to_bytes(value: int, length: int | None = None) -> bytes:
    if length is None:
        length = max(1, (value.bit_length() + 7) // 8)
    return value.to_bytes(length, "big")


def short_int(value: int, head: int = 16, tail: int = 16) -> str:
    s = str(value)
    if len(s) <= head + tail + 3:
        return s
    return f"{s[:head]}...{s[-tail:]}"


def read_message() -> bytes:
    print("1 - Enter text manually")
    print("2 - Load text file")
    choice = input("Choose input method: ").strip()

    if choice == "2":
        path = Path(input("Enter file path: ").strip().strip('"'))
        if not path.exists():
            raise FileNotFoundError("File not found.")
        return path.read_bytes()

    text = input("Enter message text: ").strip()
    if not text:
        raise ValueError("Message must not be empty.")
    return text.encode("utf-8")


def benchmark(func, repeats: int) -> float:
    start = time.perf_counter()
    for _ in range(repeats):
        func()
    end = time.perf_counter()
    return ((end - start) * 1000) / repeats


def save_json(path: Path, data: dict):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


# =========================
# RSA signature
# =========================

class RSASignature:
    def __init__(self):
        self.p = RSA_P
        self.q = RSA_Q
        self.n = self.p * self.q
        phi = (self.p - 1) * (self.q - 1)
        self.e = RSA_E
        self.d = pow(self.e, -1, phi)

    def sign(self, message: bytes) -> int:
        h = hash_to_int(message) % self.n
        return pow(h, self.d, self.n)

    @staticmethod
    def verify(message: bytes, signature: int, public_key: dict) -> bool:
        n = int(public_key["n"])
        e = int(public_key["e"])
        h = hash_to_int(message) % n
        return pow(signature, e, n) == h

    def public_key_dict(self) -> dict:
        return {
            "algorithm": "RSA",
            "n": str(self.n),
            "e": str(self.e),
        }


# =========================
# ElGamal signature
# =========================

class ElGamalSignature:
    def __init__(self):
        self.p = MODP_P
        self.g = ELGAMAL_G
        self.x = secrets.randbelow(self.p - 3) + 2
        self.y = pow(self.g, self.x, self.p)

    def sign(self, message: bytes) -> tuple[int, int]:
        h = hash_to_int(message, self.p - 1)

        while True:
            k = secrets.randbelow(self.p - 2) + 1
            if math.gcd(k, self.p - 1) == 1:
                break

        r = pow(self.g, k, self.p)
        s = ((h - self.x * r) * pow(k, -1, self.p - 1)) % (self.p - 1)
        return r, s

    @staticmethod
    def verify(message: bytes, signature: tuple[int, int], public_key: dict) -> bool:
        r, s = signature
        p = int(public_key["p"])
        g = int(public_key["g"])
        y = int(public_key["y"])

        if not (1 < r < p):
            return False
        if not (0 <= s < p - 1):
            return False

        h = hash_to_int(message, p - 1)
        left = (pow(y, r, p) * pow(r, s, p)) % p
        right = pow(g, h, p)
        return left == right

    def public_key_dict(self) -> dict:
        return {
            "algorithm": "ElGamal",
            "p": str(self.p),
            "g": str(self.g),
            "y": str(self.y),
        }


# =========================
# Schnorr signature
# =========================

class SchnorrSignature:
    def __init__(self):
        self.p = MODP_P
        self.q = SCHNORR_Q
        self.g = SCHNORR_G
        self.x = secrets.randbelow(self.q - 1) + 1
        self.y = pow(self.g, self.x, self.p)
        self.p_bytes = (self.p.bit_length() + 7) // 8

    def sign(self, message: bytes) -> tuple[int, int]:
        k = secrets.randbelow(self.q - 1) + 1
        r = pow(self.g, k, self.p)
        e = hash_to_int(message + int_to_bytes(r, self.p_bytes), self.q)
        s = (k - self.x * e) % self.q
        return e, s

    @staticmethod
    def verify(message: bytes, signature: tuple[int, int], public_key: dict) -> bool:
        e, s = signature
        p = int(public_key["p"])
        q = int(public_key["q"])
        g = int(public_key["g"])
        y = int(public_key["y"])
        p_bytes = (p.bit_length() + 7) // 8

        if not (0 < e < q):
            return False
        if not (0 <= s < q):
            return False

        r_check = (pow(g, s, p) * pow(y, e, p)) % p
        e_check = hash_to_int(message + int_to_bytes(r_check, p_bytes), q)
        return e_check == e

    def public_key_dict(self) -> dict:
        return {
            "algorithm": "Schnorr",
            "p": str(self.p),
            "q": str(self.q),
            "g": str(self.g),
            "y": str(self.y),
        }


# =========================
# Reporting
# =========================

def export_public_keys(rsa: RSASignature, elgamal: ElGamalSignature, schnorr: SchnorrSignature):
    rsa_path = Path("rsa_public_key.json")
    elgamal_path = Path("elgamal_public_key.json")
    schnorr_path = Path("schnorr_public_key.json")

    save_json(rsa_path, rsa.public_key_dict())
    save_json(elgamal_path, elgamal.public_key_dict())
    save_json(schnorr_path, schnorr.public_key_dict())

    return rsa_path, elgamal_path, schnorr_path


def print_signature_preview(name: str, signature):
    print(f"\n{name} signature:")
    if isinstance(signature, tuple):
        print(f"part 1: {short_int(signature[0])}")
        print(f"part 2: {short_int(signature[1])}")
    else:
        print(short_int(signature))

def make_modified_message(message: bytes) -> bytes:
    if not message:
        return b"x"
    return message + b" [modified]"


def main():
    print("Digital Signature Console Application")
    print("Algorithms: RSA, ElGamal, Schnorr")
    print("Hash function: SHA-256")
    print()

    message = read_message()
    modified_message = make_modified_message(message)

    repeats_input = input("Benchmark repetitions [default: 30]: ").strip()
    repeats = int(repeats_input) if repeats_input else 30
    if repeats <= 0:
        repeats = 30

    rsa = RSASignature()
    elgamal = ElGamalSignature()
    schnorr = SchnorrSignature()

    rsa_key_path, elgamal_key_path, schnorr_key_path = export_public_keys(rsa, elgamal, schnorr)

    rsa_public = load_json(rsa_key_path)
    elgamal_public = load_json(elgamal_key_path)
    schnorr_public = load_json(schnorr_key_path)

    rsa_signature = rsa.sign(message)
    elgamal_signature = elgamal.sign(message)
    schnorr_signature = schnorr.sign(message)

    rsa_ok = RSASignature.verify(message, rsa_signature, rsa_public)
    elgamal_ok = ElGamalSignature.verify(message, elgamal_signature, elgamal_public)
    schnorr_ok = SchnorrSignature.verify(message, schnorr_signature, schnorr_public)

    # Demonstration of mismatch between message and signature
    rsa_bad = RSASignature.verify(modified_message, rsa_signature, rsa_public)
    elgamal_bad = ElGamalSignature.verify(modified_message, elgamal_signature, elgamal_public)
    schnorr_bad = SchnorrSignature.verify(modified_message, schnorr_signature, schnorr_public)

    rsa_sign_time = benchmark(lambda: rsa.sign(message), repeats)
    rsa_verify_time = benchmark(lambda: RSASignature.verify(message, rsa_signature, rsa_public), repeats)

    elgamal_sign_time = benchmark(lambda: elgamal.sign(message), repeats)
    elgamal_verify_time = benchmark(lambda: ElGamalSignature.verify(message, elgamal_signature, elgamal_public), repeats)

    schnorr_sign_time = benchmark(lambda: schnorr.sign(message), repeats)
    schnorr_verify_time = benchmark(lambda: SchnorrSignature.verify(message, schnorr_signature, schnorr_public), repeats)

    print("\n" + "=" * 72)
    print("INPUT DATA")
    print("=" * 72)
    print(f"Original message: {message.decode('utf-8', errors='replace')}")
    print(f"Modified message: {modified_message.decode('utf-8', errors='replace')}")
    print(f"Original message size: {len(message)} bytes")
    print(f"SHA-256 (original): {sha256_hex(message)}")
    print(f"SHA-256 (modified): {sha256_hex(modified_message)}")

    print("\n" + "=" * 72)
    print("PUBLIC KEYS")
    print("=" * 72)
    print(f"RSA public key saved to: {rsa_key_path.resolve()}")
    print(f"ElGamal public key saved to: {elgamal_key_path.resolve()}")
    print(f"Schnorr public key saved to: {schnorr_key_path.resolve()}")

    print("\n" + "=" * 72)
    print("KEY PARAMETERS")
    print("=" * 72)
    print(f"RSA modulus length: {rsa.n.bit_length()} bits")
    print(f"ElGamal modulus length: {MODP_P.bit_length()} bits")
    print(f"Schnorr modulus length: {MODP_P.bit_length()} bits")
    print(f"Schnorr subgroup order length: {SCHNORR_Q.bit_length()} bits")

    print("\n" + "=" * 72)
    print("RSA")
    print("=" * 72)
    print_signature_preview("RSA", rsa_signature)
    print(f"Verified for original message: {rsa_ok}")
    print(f"Verified for modified message: {rsa_bad}")
    print(f"Average sign time: {rsa_sign_time:.3f} ms")
    print(f"Average verify time: {rsa_verify_time:.3f} ms")

    print("\n" + "=" * 72)
    print("ELGAMAL")
    print("=" * 72)
    print_signature_preview("ElGamal", elgamal_signature)
    print(f"Verified for original message: {elgamal_ok}")
    print(f"Verified for modified message: {elgamal_bad}")
    print(f"Average sign time: {elgamal_sign_time:.3f} ms")
    print(f"Average verify time: {elgamal_verify_time:.3f} ms")

    print("\n" + "=" * 72)
    print("SCHNORR")
    print("=" * 72)
    print_signature_preview("Schnorr", schnorr_signature)
    print(f"Verified for original message: {schnorr_ok}")
    print(f"Verified for modified message: {schnorr_bad}")
    print(f"Average sign time: {schnorr_sign_time:.3f} ms")
    print(f"Average verify time: {schnorr_verify_time:.3f} ms")

    print("\n" + "=" * 72)
    print("COMPARISON")
    print("=" * 72)

    sign_results = {
        "RSA": rsa_sign_time,
        "ElGamal": elgamal_sign_time,
        "Schnorr": schnorr_sign_time,
    }
    verify_results = {
        "RSA": rsa_verify_time,
        "ElGamal": elgamal_verify_time,
        "Schnorr": schnorr_verify_time,
    }

    fastest_sign = min(sign_results, key=sign_results.get)
    fastest_verify = min(verify_results, key=verify_results.get)

    print(f"Fastest signing: {fastest_sign}")
    print(f"Fastest verification: {fastest_verify}")
    print("Mismatch demonstration result: for all algorithms, verification of the modified message must be False.")


if __name__ == "__main__":
    main()