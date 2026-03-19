import time
import collections
import matplotlib.pyplot as plt
import os

ALPHABET = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
KEYWORD = "безопасность"
FIRST_NAME = "Илья"
LAST_NAME = "Филипюк"

FILE_V1 = "text_v1.txt"
FILE_V2 = "text_v2.txt"

def load_text(filename, min_length):
    if not os.path.exists(filename):
        placeholder = ("введите ваш текст здесь " * (min_length // 10))[:min_length]
        with open(filename, "w", encoding="utf-8") as f:
            f.write(placeholder)
        print(f"(!) Файл {filename} не найден. Создан шаблон.")
        return placeholder
    with open(filename, "r", encoding="utf-8") as f:
        content = f.read().strip()
    if len(content) < min_length:
        print(f"(!) Предупреждение: файл {filename} содержит {len(content)} знаков (минимум {min_length}).")
    return content

def save_histogram(text, title, filename):
    counter = collections.Counter(c for c in text.lower() if c in ALPHABET)
    total = sum(counter.values())
    chars = sorted(ALPHABET)
    frequencies = [(counter.get(char, 0) / total * 100) if total > 0 else 0 for char in chars]
    plt.figure(figsize=(12, 6))
    bars = plt.bar(chars, frequencies, color='skyblue', edgecolor='navy')
    plt.title(title, fontsize=14)
    plt.xlabel('Символы алфавита', fontsize=12)
    plt.ylabel('Частота (%)', fontsize=12)
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    for bar in bars:
        yval = bar.get_height()
        if yval > 0:
            plt.text(bar.get_x() + bar.get_width()/2, yval + 0.1, f'{yval:.1f}', ha='center', va='bottom', fontsize=8)
    plt.savefig(filename)
    plt.close()

def caesar_keyword_cipher(text, encrypt=True):
    unique_key = ""
    for char in KEYWORD:
        if char not in unique_key and char in ALPHABET:
            unique_key += char
    remaining = "".join([c for c in ALPHABET if c not in unique_key])
    cipher_alphabet = unique_key + remaining
    trans_table = str.maketrans(ALPHABET, cipher_alphabet) if encrypt else str.maketrans(cipher_alphabet, ALPHABET)
    return text.lower().translate(trans_table)

def trisemus_cipher(text, encrypt=True):
    unique_key = []
    for char in KEYWORD:
        if char not in unique_key and char in ALPHABET:
            unique_key.append(char)
    table = unique_key + [c for c in ALPHABET if c not in unique_key]
    rows, cols = 3, 11
    result = []
    for char in text.lower():
        if char not in table:
            result.append(char); continue
        idx = table.index(char)
        r, c = divmod(idx, cols)
        new_idx = (((r + 1) if encrypt else (r - 1)) % rows) * cols + c
        result.append(table[new_idx])
    return "".join(result)

def route_spiral_cipher(text, rows=10, encrypt=True):
    cols = (len(text) + rows - 1) // rows
    size = rows * cols
    
    if encrypt:
        padded_text = text.ljust(size)
        matrix = [list(padded_text[i*cols : (i+1)*cols]) for i in range(rows)]
        result = []
        top, bottom, left, right = 0, rows - 1, 0, cols - 1
        while top <= bottom and left <= right:
            for i in range(left, right + 1): result.append(matrix[top][i])
            top += 1
            for i in range(top, bottom + 1): result.append(matrix[i][right])
            right -= 1
            if top <= bottom:
                for i in range(right, left - 1, -1): result.append(matrix[bottom][i])
                bottom -= 1
            if left <= right:
                for i in range(bottom, top - 1, -1): result.append(matrix[i][left])
                left += 1
        return "".join(result)
    else:
        matrix = [[None for _ in range(cols)] for _ in range(rows)]
        top, bottom, left, right = 0, rows - 1, 0, cols - 1
        idx = 0
        while top <= bottom and left <= right:
            for i in range(left, right + 1):
                matrix[top][i] = text[idx]
                idx += 1
            top += 1
            for i in range(top, bottom + 1):
                matrix[i][right] = text[idx]
                idx += 1
            right -= 1
            if top <= bottom:
                for i in range(right, left - 1, -1):
                    matrix[bottom][i] = text[idx]
                    idx += 1
                bottom -= 1
            if left <= right:
                for i in range(bottom, top - 1, -1):
                    matrix[i][left] = text[idx]
                    idx += 1
                left += 1
        return "".join("".join(row) for row in matrix).strip()

def multiple_permutation_cipher(text, encrypt=True):
    def get_permute_indices(key):
        return sorted(range(len(key)), key=lambda k: key[k])

    def encrypt_step(s, key):
        indices = get_permute_indices(key)
        cols = len(key)
        rows = (len(s) + cols - 1) // cols
        padded = s.ljust(rows * cols)
        res = ""
        for idx in indices:
            for r in range(rows):
                res += padded[r * cols + idx]
        return res

    def decrypt_step(s, key):
        indices = get_permute_indices(key)
        cols = len(key)
        rows = len(s) // cols
        matrix = [[None for _ in range(cols)] for _ in range(rows)]
        idx_in_s = 0
        for col_idx in indices:
            for row_idx in range(rows):
                matrix[row_idx][col_idx] = s[idx_in_s]
                idx_in_s += 1
        return "".join("".join(row) for row in matrix)

    if encrypt:
        return encrypt_step(encrypt_step(text, FIRST_NAME), LAST_NAME)
    else:
        return decrypt_step(decrypt_step(text, LAST_NAME), FIRST_NAME).strip()

def run_experiment(name, text, cipher_func, prefix, **kwargs):
    print(f"\n>>> Исследование: {name}")
    save_histogram(text, f"Исходный текст ({name})", f"{prefix}_original.png")
    
    start_time = time.perf_counter()
    encrypted = cipher_func(text, **kwargs)
    end_time = time.perf_counter()
    
    print(f"Время выполнения: {(end_time - start_time):.6f} сек.")
    
    print("-" * 20)
    print(f"Зашифрованный текст (первые 500 символов):")
    print(encrypted[:500])
    if len(encrypted) > 500:
        print("... [текст обрезан для вывода] ...")
    
    if "encrypt" in cipher_func.__code__.co_varnames:
        decrypted = cipher_func(encrypted, encrypt=False, **kwargs)
        print("\nРасшифрованный текст (первые 500 символов):")
        print(decrypted[:500])
        if len(decrypted) > 500:
            print("... [текст обрезан для вывода] ...")
        
    print("-" * 20)
    
    print(f"Файлы графиков сохранены с префиксом: {prefix}")
    save_histogram(encrypted, f"Зашифрованный текст ({name})", f"{prefix}_encrypted.png")

if __name__ == "__main__":
    if not os.path.exists("plots"): os.makedirs("plots")
    print("Чтение исходных данных из файлов...")
    text_v1 = load_text(FILE_V1, 5000)
    text_v2 = load_text(FILE_V2, 500)
    print(f"Данные загружены. V1: {len(text_v1)} зн., V2: {len(text_v2)} зн.")
    
    run_experiment("Шифр Цезаря с ключом", text_v1, caesar_keyword_cipher, "plots/v1_caesar")
    run_experiment("Таблица Трисемуса", text_v1, trisemus_cipher, "plots/v1_trisemus")
    
    run_experiment("Маршрутная спираль", text_v2, route_spiral_cipher, "plots/v2_spiral", rows=10)
    run_experiment("Множественная перестановка", text_v2, multiple_permutation_cipher, "plots/v2_multiple")
    print("\nИсследования завершены. Результаты в папке 'plots'.")