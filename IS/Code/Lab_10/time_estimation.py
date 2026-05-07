import random
import time
from statistics import mean

# ------------------------------------------------------------
# Study of modular exponentiation time:
# y = a^x mod n
#
# Requirements covered:
# - a: decimal values from 5 to 35
# - x: prime numbers from 10^3 to 10^100
# - n: numbers with 1024-bit and 2048-bit binary length
# - output: tabular form + simple ASCII chart
# ------------------------------------------------------------


def is_probable_prime(n, rounds=12):
    """Miller-Rabin primality test."""
    if n < 2:
        return False

    small_primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31]
    for p in small_primes:
        if n == p:
            return True
        if n % p == 0:
            return False

    d = n - 1
    s = 0
    while d % 2 == 0:
        s += 1
        d //= 2

    for _ in range(rounds):
        a = random.randrange(2, n - 1)
        x = pow(a, d, n)

        if x == 1 or x == n - 1:
            continue

        for _ in range(s - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False

    return True


def next_prime(n):
    """Find the next prime number >= n."""
    if n <= 2:
        return 2
    candidate = n if n % 2 == 1 else n + 1
    while not is_probable_prime(candidate):
        candidate += 2
    return candidate


def generate_prime_exponents():
    """
    8 prime values x, fairly distributed in the range 10^3 ... 10^100.
    We take powers with evenly spread exponents.
    """
    powers = [3, 17, 31, 45, 59, 73, 87, 100]
    return [next_prime(10 ** p) for p in powers]


def generate_modulus(bit_length):
    """
    Generate an odd number with exactly the requested bit length.
    It does not have to be prime for modular exponentiation timing.
    """
    n = random.getrandbits(bit_length)
    n |= (1 << (bit_length - 1))  # force exact bit length
    n |= 1  # make odd
    return n


def short_bigint(n, head=12, tail=12):
    s = str(n)
    if len(s) <= head + tail + 3:
        return s
    return f"{s[:head]}...{s[-tail:]}"


def measure_time(a, x, n, repeats=7):
    """
    Measure average runtime of y = a^x mod n.
    Returns (y, average_time_ms).
    """
    timings = []
    y = None

    for _ in range(repeats):
        start = time.perf_counter()
        y = pow(a, x, n)
        end = time.perf_counter()
        timings.append((end - start) * 1000)

    return y, mean(timings)


def print_table(results):
    print("\nRESULT TABLE")
    print("-" * 118)
    print(
        f"{'a':>3} | {'x digits':>8} | {'x (short)':>29} | "
        f"{'n bits':>6} | {'n (short)':>29} | {'time (ms)':>10}"
    )
    print("-" * 118)

    for row in results:
        print(
            f"{row['a']:>3} | "
            f"{row['x_digits']:>8} | "
            f"{row['x_short']:>29} | "
            f"{row['n_bits']:>6} | "
            f"{row['n_short']:>29} | "
            f"{row['time_ms']:>10.6f}"
        )

    print("-" * 118)


def print_ascii_chart(results):
    print("\nASCII CHART OF EXECUTION TIME")
    max_time = max(row["time_ms"] for row in results)
    scale = 50 / max_time if max_time > 0 else 1

    for row in results:
        label = f"a={row['a']}, x=10^{row['power_hint']}, n={row['n_bits']}"
        bar = "#" * max(1, int(row["time_ms"] * scale))
        print(f"{label:<28} | {bar} {row['time_ms']:.6f} ms")


def main():
    print("Modular Exponentiation Timing Study")
    print("Expression: y = a^x mod n")
    print()

    # You may use 1 or 2 values of a according to the task.
    a_values = [5, 35]

    # 8 prime values x in the range 10^3 ... 10^100
    x_values = generate_prime_exponents()

    # Two moduli: 1024-bit and 2048-bit
    n_values = {
        1024: generate_modulus(1024),
        2048: generate_modulus(2048),
    }

    results = []

    print("Selected parameters:")
    print(f"a values: {a_values}")
    print("x values: ")
    for x in x_values:
        print(f"  digits={len(str(x)):<3} value={short_bigint(x)}")
    print("n values:")
    for bits, n in n_values.items():
        print(f"  {bits} bits: {short_bigint(n)}")

    for a in a_values:
        for x in x_values:
            power_hint = len(str(x)) - 1
            for n_bits, n in n_values.items():
                y, avg_time_ms = measure_time(a, x, n, repeats=7)

                results.append(
                    {
                        "a": a,
                        "x_digits": len(str(x)),
                        "x_short": short_bigint(x),
                        "n_bits": n_bits,
                        "n_short": short_bigint(n),
                        "time_ms": avg_time_ms,
                        "power_hint": power_hint,
                        "y_short": short_bigint(y),
                    }
                )

    print_table(results)
    print_ascii_chart(results)

    print("\nExample computed values y:")
    for row in results[:6]:
        print(
            f"a={row['a']}, x=10^{row['power_hint']}, n={row['n_bits']} bits "
            f"=> y={row['y_short']}"
        )


if __name__ == "__main__":
    main()
