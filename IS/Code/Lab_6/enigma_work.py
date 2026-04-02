from string import ascii_uppercase as ABC
import sys
ROTOR_WIRINGS = {
    "III": "BDFHJLCPRTXVZNYEIWGAKMUSQO",
    "V":   "ESOVPZJAYQUIRHXLNFTGKDCMWB",
    "Gamma":"FSOKANUERHMBTIYCWLQPXZVGJD",
}
REFLECTOR_C_DUNN_PAIRS = [
    ("A","R"),("B","D"),("C","O"),("E","J"),("F","N"),("G","T"),
    ("H","K"),("I","V"),("L","M"),("P","W"),("Q","Z"),("S","X"),("U","Y")
]

def wiring_to_map(wiring):
    return {ABC[i]: wiring[i] for i in range(26)}

def invert_map(m):
    return {v:k for k,v in m.items()}

def reflector_from_pairs(pairs):
    m = {}
    for a,b in pairs:
        m[a]=b
        m[b]=a
    return m

class Rotor:
    def __init__(self, name, wiring, position='A'):
        self.name = name
        self.wiring_str = wiring
        self.forward_map = wiring_to_map(wiring)
        self.backward_map = invert_map(self.forward_map)
        self.pos = ABC.index(position.upper())

    def step(self, n=1):
        self.pos = (self.pos + n) % 26

    def at_full_revolution(self):
        return self.pos == 0

    def encode_forward(self, ch):
        idx = (ABC.index(ch) + self.pos) % 26
        stepped_in = ABC[idx]
        mapped = self.forward_map[stepped_in]
        out_idx = (ABC.index(mapped) - self.pos) % 26
        return ABC[out_idx]

    def encode_backward(self, ch):
        idx = (ABC.index(ch) + self.pos) % 26
        stepped_in = ABC[idx]
        mapped = self.backward_map[stepped_in]
        out_idx = (ABC.index(mapped) - self.pos) % 26
        return ABC[out_idx]

    def __repr__(self):
        return f"<Rotor {self.name} pos={ABC[self.pos]}>"

class Reflector:
    def __init__(self, pairs):
        self.map = reflector_from_pairs(pairs)

    def reflect(self, ch):
        return self.map.get(ch, ch)

class EnigmaMachine:
    def __init__(self, rotor_left, rotor_mid, rotor_right, reflector,
                 step_left=1, step_mid=1, step_right=1):
        self.L = rotor_left
        self.M = rotor_mid
        self.R = rotor_right
        self.Re = reflector
        self.step_left = step_left
        self.step_mid = step_mid
        self.step_right = step_right

    def step_rotors(self):
        if self.step_right > 0:
            self.R.step(self.step_right)
            right_full = False
            if self.R.pos == 0:
                right_full = True
        else:
            self.R.step(1)
            right_full = (self.R.pos == 0)

        if self.step_mid > 0:
            self.M.step(self.step_mid)
            mid_full = (self.M.pos == 0)
        else:
            if right_full:
                self.M.step(1)
            mid_full = (self.M.pos == 0)

        if self.step_left > 0:
            self.L.step(self.step_left)
        else:
            if mid_full:
                self.L.step(1)

    def process_char(self, ch):
        if ch not in ABC:
            return ch
        self.step_rotors()
        c = ch
        c = self.R.encode_forward(c)
        c = self.M.encode_forward(c)
        c = self.L.encode_forward(c)
        c = self.Re.reflect(c)
        c = self.L.encode_backward(c)
        c = self.M.encode_backward(c)
        c = self.R.encode_backward(c)
        return c

    def process_text(self, text, verbose=False):
        out = []
        for ch in text.upper():
            if ch in ABC:
                res = self.process_char(ch)
                out.append(res)
                if verbose:
                    print(f"{ch} -> {res}    positions: L={ABC[self.L.pos]} M={ABC[self.M.pos]} R={ABC[self.R.pos]}")
            else:
                out.append(ch)
        return "".join(out)

def create_variant_12(initial_positions=("A","A","A")):
    L = Rotor("III", ROTOR_WIRINGS["III"], position=initial_positions[0])
    M = Rotor("Gamma", ROTOR_WIRINGS["Gamma"], position=initial_positions[1])
    R = Rotor("V", ROTOR_WIRINGS["V"], position=initial_positions[2])
    Re = Reflector(REFLECTOR_C_DUNN_PAIRS)
    return EnigmaMachine(L, M, R, Re, step_left=1, step_mid=1, step_right=2)

def batch_encrypt(fullname, initial_positions_list):
    results = []
    for pos in initial_positions_list:
        init = tuple(p.upper() for p in pos)
        machine = create_variant_12(initial_positions=init)
        cleaned = ''.join(ch for ch in fullname.upper() if ch in ABC)
        cipher = machine.process_text(cleaned)
        results.append((pos.upper(), cleaned, cipher))
    return results

def estimate_cryptostability():
    keyspace_rotor_positions = 26**3
    rotor_selection = 1
    reflector_selection = 1
    total_keyspace = keyspace_rotor_positions * rotor_selection * reflector_selection
    analysis = []
    analysis.append(f"Keyspace from rotor positions only: {keyspace_rotor_positions} (~2.6e4)")
    analysis.append(f"Total keyspace used in this implementation (rotor positions): {total_keyspace}")
    analysis.append("Known weaknesses: reflector makes mapping involutive, so no letter can map to itself after full path; short effective keyspace compared to modern ciphers.")
    return "\n".join(analysis)

def main():
    if len(sys.argv) >= 2:
        fullname = " ".join(sys.argv[1:])
    else:
        fullname = input("Enter full name (First Middle Last): ")

    presets = ["AAA","BCD","MNO","XYZ","QWE"]
    results = batch_encrypt(fullname, presets)
    print("Encryption results for variant 12 (L=III, M=Gamma, R=V, Reflector=C Dünn, steps 1-1-2):")
    for pos, plain, cipher in results:
        print(f"Initial positions: {pos}   Plain: {plain}   Cipher: {cipher}")
    print("\nCryptostability assessment:")
    print(estimate_cryptostability())

if __name__ == '__main__':
    main()