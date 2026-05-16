import hashlib
import time
from pathlib import Path


def sha256_hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def measure_hash_time(data: bytes, repeats: int = 1000):
    start = time.perf_counter()
    for _ in range(repeats):
        hashlib.sha256(data).digest()
    end = time.perf_counter()

    total_time = end - start
    avg_time = total_time / repeats
    throughput_mb_s = (len(data) * repeats) / total_time / (1024 * 1024) if total_time > 0 else 0

    return total_time, avg_time, throughput_mb_s


def read_text_file(path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-8", "cp1251"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            pass
    raise ValueError("Could not decode the file.")


def get_input_data() -> bytes:
    print("1 - Enter text manually")
    print("2 - Load text from file")

    choice = input("Choose input method: ").strip()

    if choice == "2":
        file_path = Path(input("Enter file path: ").strip().strip('"'))
        if not file_path.exists():
            raise FileNotFoundError("File not found.")

        text = read_text_file(file_path)
        return text.encode("utf-8")

    text = input("Enter message: ")
    return text.encode("utf-8")


def main():
    print("SHA-256 Hashing Console Application")
    print("The SHA-256 algorithm processes messages of arbitrary length")
    print("(within the limits of the SHA-256 specification).")
    print()

    data = get_input_data()

    digest = sha256_hash(data)

    print("\n--- Hash Result ---")
    print(f"Message size: {len(data)} bytes")
    print(f"SHA-256: {digest}")

    repeats_input = input("\nEnter number of benchmark repetitions [default: 1000]: ").strip()
    repeats = int(repeats_input) if repeats_input else 1000

    total_time, avg_time, throughput_mb_s = measure_hash_time(data, repeats)

    print("\n--- Performance Evaluation ---")
    print(f"Repetitions: {repeats}")
    print(f"Total time: {total_time:.6f} sec")
    print(f"Average time per hash: {avg_time * 1000:.6f} ms")
    print(f"Throughput: {throughput_mb_s:.2f} MB/s")


if __name__ == "__main__":
    main()
