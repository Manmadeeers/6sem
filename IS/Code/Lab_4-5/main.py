import time
import collections
import matplotlib.pyplot as plt
import os

# --- КОНСТАНТЫ И ДАННЫЕ ВАРИАНТОВ ---
ALPHABET = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
KEYWORD = "безопасность"
FIRST_NAME = "Илья"
LAST_NAME = "Филипюк"

# Имена файлов для чтения данных
FILE_V1 = "text_v1.txt"  # Файл для Варианта 1 (минимум 5000 знаков)
FILE_V2 = "text_v2.txt"  # Файл для Варианта 2 (минимум 500 знаков)

def load_text(filename, min_length):
    """Читает текст из файла и проверяет его длину."""
    if not os.path.exists(filename):
        # Если файла нет, создаем заглушку, чтобы скрипт не падал сразу
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
    """Строит гистограмму частот и сохраняет её как изображение."""
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

# --- АЛГОРИТМЫ ВАРИАНТА 1 (ПОДСТАНОВКА) ---

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

# --- АЛГОРИТМЫ ВАРИАНТА 2 (ПЕРЕСТАНОВКА) ---

def route_spiral_encrypt(text, rows=10):
    cols = (len(text) + rows - 1) // rows
    padded_text = text.ljust(rows * cols)
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

def multiple_permutation_encrypt(text):
    def permute(s, key):
        key_indices = sorted(range(len(key)), key=lambda k: key[k])
        cols = len(key)
        rows = (len(s) + cols - 1) // cols
        padded = s.ljust(rows * cols)
        res = ""
        for idx in key_indices:
            for r in range(rows):
                res += padded[r * cols + idx]
        return res
    return permute(permute(text, FIRST_NAME), LAST_NAME)

# --- ГЛАВНЫЙ ЦИКЛ ---

def run_experiment(name, text, cipher_func, prefix, **kwargs):
    print(f"\n>>> Исследование: {name}")
    
    # 1. Исходная гистограмма
    save_histogram(text, f"Исходный текст ({name})", f"{prefix}_original.png")
    
    # 2. Шифрование и замер времени
    start_time = time.perf_counter()
    encrypted = cipher_func(text, **kwargs)
    end_time = time.perf_counter()
    
    print(f"Время выполнения: {(end_time - start_time):.6f} сек.")
    print(f"Файлы графиков сохранены с префиксом: {prefix}")
    
    # 3. Зашифрованная гистограмма
    save_histogram(encrypted, f"Зашифрованный текст ({name})", f"{prefix}_encrypted.png")

if __name__ == "__main__":
    if not os.path.exists("plots"): os.makedirs("plots")
    
    print("Чтение исходных данных из файлов...")
    
    # Загружаем тексты из файлов (UTF-8)
    text_v1 = load_text(FILE_V1, 5000)
    text_v2 = load_text(FILE_V2, 500)
    
    print(f"Данные загружены. V1: {len(text_v1)} зн., V2: {len(text_v2)} зн.")
    
    # ВАРИАНТ 1
    run_experiment("Шифр Цезаря с ключом", text_v1, caesar_keyword_cipher, "plots/v1_caesar")
    run_experiment("Таблица Трисемуса", text_v1, trisemus_cipher, "plots/v1_trisemus")
    
    # ВАРИАНТ 2
    run_experiment("Маршрутная спираль", text_v2, route_spiral_encrypt, "plots/v2_spiral", rows=10)
    run_experiment("Множественная перестановка", text_v2, multiple_permutation_encrypt, "plots/v2_multiple")

    print("\nИсследования завершены. Результаты в папке 'plots'.")