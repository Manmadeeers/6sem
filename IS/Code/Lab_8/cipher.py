from time import perf_counter
LCG_A = 430
LCG_C = 2531
LCG_M = 11979

RC4_N_BITS = 8
RC4_KEY = [122, 125, 48, 84, 201]


def read_int(prompt: str, default: int | None = None, min_value: int | None = None) -> int:
    while True:
        raw = input(prompt).strip()
        if raw == "" and default is not None:
            value = default
        else:
            try:
                value = int(raw)
            except ValueError:
                print("Ошибка: введите целое число.")
                continue

        if min_value is not None and value < min_value:
            print(f"Ошибка: число должно быть не меньше {min_value}.")
            continue

        return value


def lcg_generate(seed: int, count: int, a: int = LCG_A, c: int = LCG_C, m: int = LCG_M) -> list[int]:
    sequence = []
    x = seed % m

    for _ in range(count):
        x = (a * x + c) % m
        sequence.append(x)

    return sequence


def lcg_mode() -> None:
    print("\n--- PRS generator (Linear congruent generator) ---")
    print(f"Parameters: a = {LCG_A}, c = {LCG_C}, m = {LCG_M}")

    seed = read_int("Enter X0 (example:  7): ", default=7, min_value=0)
    count = read_int("Enter the amount of numbers to generate: ", default=20, min_value=1)

    start = perf_counter()
    sequence = lcg_generate(seed, count)
    elapsed = perf_counter() - start

    print("\nGenerated PSR:")
    print(sequence)

    print("\nNormalized values  Xi / m:")
    normalized = [round(x / LCG_M, 6) for x in sequence]
    print(normalized)

    speed = count / elapsed if elapsed > 0 else float("inf")
    print("\nGeneration speed evaluation:")
    print(f"Time: {elapsed:.8f} s")
    print(f"Speed: {speed:.2f} numbers/s")


def rc4_ksa(key: list[int], n_bits: int = RC4_N_BITS) -> list[int]:
    n = 1 << n_bits
    s = list(range(n))
    j = 0

    for i in range(n):
        j = (j + s[i] + key[i % len(key)]) % n
        s[i], s[j] = s[j], s[i]

    return s


def rc4_keystream(key: list[int], length: int, n_bits: int = RC4_N_BITS) -> list[int]:
    n = 1 << n_bits
    s = rc4_ksa(key, n_bits)
    i = 0
    j = 0
    stream = []

    for _ in range(length):
        i = (i + 1) % n
        j = (j + s[i]) % n
        s[i], s[j] = s[j], s[i]
        t = (s[i] + s[j]) % n
        stream.append(s[t])

    return stream


def rc4_encrypt(data: bytes, key: list[int], n_bits: int = RC4_N_BITS) -> tuple[bytes, list[int]]:
    stream = rc4_keystream(key, len(data), n_bits)
    encrypted = bytes(b ^ k for b, k in zip(data, stream))
    return encrypted, stream


def rc4_mode() -> None:
    print("\n--- RC4---")
    print(f"n = {RC4_N_BITS}, size S = 2^{RC4_N_BITS} = {1 << RC4_N_BITS}")
    print(f"Key: {RC4_KEY}")

    default_text = "Cryptography ensures your data safety"
    text = input(f"Enter the message to be encrypted [Enter = '{default_text}']: ").strip()
    if not text:
        text = default_text

    data = text.encode("utf-8")

    start = perf_counter()
    encrypted, stream = rc4_encrypt(data, RC4_KEY, RC4_N_BITS)
    elapsed = perf_counter() - start

    decrypted, _ = rc4_encrypt(encrypted, RC4_KEY, RC4_N_BITS)

    print("\nSource message:")
    print(text)

    print("\nSource message bytes:")
    print(list(data))

    print("\nGenerated PSR for RC4:")
    print(stream)

    print("\nEncrypted message (hex):")
    print(encrypted.hex())

    print("\nEncrypted message (bytes):")
    print(list(encrypted))

    print("\nDecrypted message:")
    print(decrypted.decode('utf-8'))

    speed = len(data) / elapsed if elapsed > 0 else float("inf")
    print("\nGeneration/encryption speed evaluation:")
    print(f"Time: {elapsed:.8f} s")
    print(f"Speed: {speed:.2f} byte/s")


def main() -> None:
    while True:
        print("\n==============================")
        print("1. PSR generation (Linear congruent generator)")
        print("2. RC4")
        print("0. Exit")
        print("==============================")

        choice = input("Choose: ").strip()

        if choice == "1":
            lcg_mode()
        elif choice == "2":
            rc4_mode()
        elif choice == "0":
            print("Exiting.")
            break
        else:
            print("Error: choose 0, 1 or 2.")


if __name__ == "__main__":
    main()
