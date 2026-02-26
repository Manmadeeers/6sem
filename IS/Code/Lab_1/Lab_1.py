# entropy_two_fios_fixed.py
import math
from collections import Counter, OrderedDict
import matplotlib.pyplot as plt
import os
import string

# ---------- ПАРАМЕТРЫ ----------
SER_FILE = "ser_text.txt"   # кириллица (сербский)
GER_FILE = "ger_text.txt"   # латиница (немецкий)
OUTPUT_DIR = "output_entropy"
KEEP_SPACES = True     # True: считать пробелы; False: убрать пробелы при подсчётах символов
IGNORE_PUNCT = False   # True: удалить знаки пунктуации
LOWERCASE = True       # True: привести к нижнему регистру (для латиницы)
# ---------- ВАШИ ФИО (замените на реальные) ----------
fio_cyr = "Филипјук Илија Андрејевич"    # ФИО на сербском (кириллица)
fio_lat = "Ilja Andrejewitsch Filipjuk"  # ФИО на немецком (латиница)
# ---------------------------------

def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def preprocess(text):
    if LOWERCASE:
        text = text.lower()
    if not KEEP_SPACES:
        text = text.replace(" ", "")
    if IGNORE_PUNCT:
        text = ''.join(ch for ch in text if ch not in string.punctuation)
    return text

def char_frequencies(text):
    counts = Counter(text)
    total = sum(counts.values()) if counts else 0
    probs = OrderedDict(sorted(((c, cnt/total) for c,cnt in counts.items()), key=lambda x: (-x[1], x[0]))) if total>0 else OrderedDict()
    return counts, probs, total

def entropy_from_probs(probs):
    H = 0.0
    for p in probs:
        if p > 0:
            H -= p * math.log2(p)
    return H

def bits_from_bytes_bytes(data_bytes):
    return ''.join(f"{b:08b}" for b in data_bytes)

def binary_entropy(p):
    if p == 0 or p == 1:
        return 0.0
    return -p*math.log2(p) - (1-p)*math.log2(1-p)

def channel_capacity_bsc(q):
    return 1.0 - binary_entropy(q)

def plot_histogram(counts, title, filename, top_n=60):
    items = sorted(counts.items(), key=lambda x: -x[1])
    items = items[:top_n]
    labels = [x[0] for x in items]
    values = [x[1] for x in items]
    plt.figure(figsize=(12,5))
    plt.bar(labels, values)
    plt.title(title)
    plt.xlabel('Symbol')
    plt.ylabel('Count')
    plt.tight_layout()
    plt.savefig(filename, dpi=200)
    plt.close()

def analyze_file(path):
    raw = read_file(path)
    proc = preprocess(raw)
    counts, probs, total = char_frequencies(proc)
    H = entropy_from_probs(list(probs.values()))
    return {"raw": raw, "proc": proc, "counts": counts, "probs": probs, "total": total, "H": H}

def compute_info_for_fio(fio, H_alpha, use_spaces=KEEP_SPACES, ignore_punct=IGNORE_PUNCT, lower=LOWERCASE):
    # подготовить строку ФИО для подсчёта N_symbols
    s = fio
    if lower: s = s.lower()
    if not use_spaces: s = s.replace(" ", "")
    if ignore_punct:
        s = ''.join(ch for ch in s if ch not in string.punctuation)
    N_symbols = len(s)
    I_alpha = N_symbols * H_alpha
    # двоичное представление (ASCII если возможно, иначе UTF-8)
    try:
        name_bytes = fio.encode("ascii")
        encoding = "ascii"
    except UnicodeEncodeError:
        name_bytes = fio.encode("utf-8")
        encoding = "utf-8"
    bits = bits_from_bytes_bytes(name_bytes)
    N_bits = len(bits)
    # оценим бинарную энтропию по битам имени (локально)
    cntb = Counter(bits)
    p1 = cntb.get('1',0) / N_bits if N_bits>0 else 0
    H_bits_local = binary_entropy(p1)
    I_binary = N_bits * H_bits_local  # источникная информация в битах
    return {
        "fio": fio,
        "N_symbols": N_symbols,
        "I_alpha": I_alpha,
        "encoding": encoding,
        "bytes": len(name_bytes),
        "N_bits": N_bits,
        "p1_bits": p1,
        "H_bits_local": H_bits_local,
        "I_binary": I_binary
    }

def has_cyrillic(s):
    for ch in s:
        if '\u0400' <= ch <= '\u04FF' or '\u0500' <= ch <= '\u052F':
            return True
    return False

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Анализ файлов алфавитов
    ser_result = analyze_file(SER_FILE) if os.path.exists(SER_FILE) else None
    ger_result = analyze_file(GER_FILE) if os.path.exists(GER_FILE) else None

    if ser_result:
        print(f"{SER_FILE}: symbols={ser_result['total']}, H_cyr={ser_result['H']:.6f} bits/symbol")
        plot_histogram(ser_result["counts"], f"Serbian (Cyr) symbol counts", os.path.join(OUTPUT_DIR, "ser_hist.png"))
        with open(os.path.join(OUTPUT_DIR, "ser_freqs.txt"), "w", encoding="utf-8") as f:
            f.write("symbol\tcount\tprob\n")
            for c,cnt in ser_result["counts"].most_common():
                f.write(f"{repr(c)}\t{cnt}\t{ser_result['probs'][c]:.8f}\n")
    else:
        print(f"Файл {SER_FILE} не найден.")

    if ger_result:
        print(f"{GER_FILE}: symbols={ger_result['total']}, H_lat={ger_result['H']:.6f} bits/symbol")
        plot_histogram(ger_result["counts"], f"German (Latn) symbol counts", os.path.join(OUTPUT_DIR, "ger_hist.png"))
        with open(os.path.join(OUTPUT_DIR, "ger_freqs.txt"), "w", encoding="utf-8") as f:
            f.write("symbol\tcount\tprob\n")
            for c,cnt in ger_result["counts"].most_common():
                f.write(f"{repr(c)}\t{cnt}\t{ger_result['probs'][c]:.8f}\n")
    else:
        print(f"Файл {GER_FILE} не найден.")

    # Вычисления информации для двух ФИО
    outputs = []
    if ser_result:
        res_cyr = compute_info_for_fio(fio_cyr, ser_result["H"])
        outputs.append(("Cyrillic FIO (uses ser_text.txt entropy)", res_cyr))
    else:
        print("Пропущен расчёт для кириллицы — файл отсутствует.")
    if ger_result:
        res_lat = compute_info_for_fio(fio_lat, ger_result["H"])
        outputs.append(("Latin FIO (uses ger_text.txt entropy)", res_lat))
    else:
        print("Пропущен расчёт для латиницы — файл отсутствует.")

    # Бинарная статистика по всем байтам файлов (для оценки H_bits общего)
    all_bits = ""
    for fname in (SER_FILE, GER_FILE):
        if os.path.exists(fname):
            with open(fname, "rb") as f:
                all_bits += ''.join(f"{b:08b}" for b in f.read())
    if all_bits:
        cntbits = Counter(all_bits)
        p1_all = cntbits.get('1',0)/len(all_bits)
        H_bits_all = binary_entropy(p1_all)
        with open(os.path.join(OUTPUT_DIR, "binary_stats.txt"), "w", encoding="utf-8") as f:
            f.write(f"total_bits\t{len(all_bits)}\nP1\t{p1_all:.8f}\nH_bits\t{H_bits_all:.12f}\n")
    else:
        p1_all = None
        H_bits_all = None

    # Вывод результатов
    summary_lines = []
    for caption, r in outputs:
        summary_lines.append(f"--- {caption} ---")
        summary_lines.append(f"FIO: {r['fio']}")
        summary_lines.append(f"N_symbols (after preprocessing rules) = {r['N_symbols']}")
        summary_lines.append(f"Information using alphabet entropy: I_alpha = {r['I_alpha']:.6f} bits")
        summary_lines.append(f"Encoding used for binary form: {r['encoding']}, bytes = {r['bytes']}, bits = {r['N_bits']}")
        summary_lines.append(f"Local bit stats for name: P(1)={r['p1_bits']:.6f}, H_bits_local={r['H_bits_local']:.6f} bits/bit")
        summary_lines.append(f"Source information in binary representation: I_source (I_binary) = {r['I_binary']:.6f} bits")
        # если есть общая H_bits_all, посчитаем I_binary по ней также
        if H_bits_all is not None:
            I_bin_using_all = r['N_bits'] * H_bits_all
            summary_lines.append(f"Information in binary representation (H_bits from files) = {I_bin_using_all:.6f} bits")

        # влияние ошибок q: теперь I_eff = min(I_source, N_bits * C)
        qs = [0.1, 0.5, 1.0]
        for q in qs:
            C = channel_capacity_bsc(q)
            I_eff = min(r['I_binary'], r['N_bits'] * C)
            summary_lines.append(f"p={q}: capacity C={C:.8f} bits/bit, effective I_eff = {I_eff:.6f} bits")
        summary_lines.append("")

    # сохранить и вывести
    out_path = os.path.join(OUTPUT_DIR, "fio_results.txt")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(summary_lines))
    print("\n".join(summary_lines))
    print(f"Готово. Сводка сохранена в: {out_path}")

if __name__ == "__main__":
    main()