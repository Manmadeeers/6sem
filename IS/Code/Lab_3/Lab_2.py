import math

def is_prime(num):
    """Проверка числа на простоту."""
    if num < 2: return False
    for i in range(2, int(math.sqrt(num)) + 1):
        if num % i == 0:
            return False
    return True

def get_primes_in_range(start, end):
    """Поиск всех простых чисел в интервале [start, end]."""
    primes = []
    for i in range(start, end + 1):
        if is_prime(i):
            primes.append(i)
    return primes

def get_canonical_form(n):
    """Разложение числа на простые множители (каноническая форма)."""
    if n < 2: return str(n)
    d = 2
    temp = n
    factors = {}
    while d * d <= temp:
        while temp % d == 0:
            factors[d] = factors.get(d, 0) + 1
            temp //= d
        d += 1
    if temp > 1:
        factors[temp] = factors.get(temp, 0) + 1
    
    return " * ".join([f"{p}^{a}" if a > 1 else f"{p}" for p, a in sorted(factors.items())])

def gcd(a, b):
    """НОД двух чисел (алгоритм Евклида)."""
    while b:
        a, b = b, a % b
    return a

def main():
    print("--- Лабораторная работа: Основы теории чисел ---")
    
    # Ввод данных
    try:
        m = int(input("Введите число m (нижняя граница): "))
        n = int(input("Введите число n (верхняя граница): "))
    except ValueError:
        print("Ошибка: введите целые числа.")
        return

    # 1. Интервал [2, n]
    primes_to_n = get_primes_in_range(2, n)
    count_n = len(primes_to_n)
    theo_n = n / math.log(n) if n > 1 else 0
    
    print(f"\n1. Интервал [2, {n}]:")
    print(f"   Простые числа: {primes_to_n}")
    print(f"   Количество (факт): {count_n}")
    print(f"   Значение n/ln(n): {math.floor(theo_n)}")
    print(f"   Разница: {math.floor(abs(count_n - theo_n))}")

    # 2. Интервал [m, n]
    primes_m_n = get_primes_in_range(m, n)
    print(f"\n2. Интервал [{m}, {n}]:")
    print(f"   Простые числа: {primes_m_n}")
    print(f"   Количество: {len(primes_m_n)}")
    print("   (Для сравнения с решетом Эратосфена используйте этот список)")

    # 3. Каноническая форма
    print(f"\n3. Каноническое разложение:")
    print(f"   m = {m} => {get_canonical_form(m)}")
    print(f"   n = {n} => {get_canonical_form(n)}")

    # 4. Конкатенация m || n
    concat_val = int(str(m) + str(n))
    is_concat_prime = is_prime(concat_val)
    print(f"\n4. Конкатенация {m}||{n} = {concat_val}:")
    print(f"   Результат: {'ПРОСТОЕ' if is_concat_prime else 'СОСТАВНОЕ'}")

    # 5. НОД (m, n)
    res_gcd = gcd(m, n)
    print(f"\n5. НОД({m}, {n}) = {res_gcd}")

    # 6. Дополнительно: НОД трех чисел (если нужно для отчета)
    print("\n6. Проверка НОД трех чисел:")
    try:
        val1 = int(input("   Введите первое число для НОД: "))
        val2 = int(input("   Введите второе число для НОД: "))
        val3 = int(input("   Введите третье число для НОД: "))

        tmp_res = gcd(val1,val2)
        final_res = gcd(tmp_res,val3)
        print(f"   НОД({val1}, {val2}, {val3}) = {final_res}")
    except ValueError:
        pass

if __name__ == "__main__":
    main()