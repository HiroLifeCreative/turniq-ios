"""Envuelve en L("…") los textos de Sources/Turniq que tienen traducción
en i18n_table.py y regenera Sources/Turniq/Lang.swift.
Uso: python3 tools/i18n_wrap.py Sources/Turniq   (requiere tree-sitter-swift)"""
import sys, glob, re
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from i18n_table import T
import tree_sitter_swift as tss
from tree_sitter import Language, Parser
P = Parser(Language(tss.language()))
SKIP_FILES = {'Lang.swift'}

def key_of(lit):
    """literal fuente (con comillas) -> clave con %@ por cada \\( ... ) de primer nivel"""
    s = lit[1:-1]; out = ''; i = 0
    while i < len(s):
        if s.startswith('\\(', i):
            depth = 1; i += 2
            while i < len(s) and depth:
                c = s[i]
                if c == '(': depth += 1
                elif c == ')': depth -= 1
                i += 1
            out += '%@'
        else:
            out += s[i]; i += 1
    return out

exact = {k: v for k, v in T if not k.endswith('…') or k == 'Buscando tu ubicación…'}
prefix = [(k[:-1], v) for k, v in T if k.endswith('…') and k != 'Buscando tu ubicación…']
used = {}; hits = {}
def lookup(key):
    if key in exact: return key
    for p, v in prefix:
        if key.startswith(p): return p + '…'
    return None

table = dict(T)
for f in sorted(glob.glob(sys.argv[1] + '/*.swift')):
    name = f.split('/')[-1]
    if name in SKIP_FILES: continue
    src = open(f, 'rb').read()
    tree = P.parse(src)
    lits = []
    def walk(n):
        if n.type == 'line_string_literal':
            lits.append((n.start_byte, n.end_byte))
        for c in n.children: walk(c)
    walk(tree.root_node)
    todo = []
    for a, b in lits:
        lit = src[a:b].decode()
        # ya envuelto
        if src[max(0, a-2):a] == b'L(':
            k0 = key_of(lit); t0 = lookup(k0)
            if t0 is not None:
                used[k0] = table[t0]; hits[t0] = hits.get(t0, 0) + 1
            else:
                print('  SIN TRADUCCION:', name, lit[:70])
            continue
        # contextos que no son texto visible
        pre = src[max(0, a-30):a].decode(errors='ignore')
        if re.search(r'(systemName:|systemImage:|case |forKey:|identifier:)\s*$', pre): continue
        k = key_of(lit)
        tk = lookup(k)
        if tk is None: continue
        used[k] = table[tk]; hits[tk] = hits.get(tk, 0) + 1
        todo.append((a, b))
    # insertar de atrás hacia adelante, ajustando literales que contienen a otros
    text = bytearray(src)
    for a, b in sorted(todo, reverse=True):
        inner = sum(1 for (x, y) in todo if x > a and y < b)
        b2 = b + inner * 3
        text[b2:b2] = b')'
        text[a:a] = b'L('
    if todo:
        open(f, 'wb').write(bytes(text))
    print(name, len(todo))
missing = [k for k, _ in T if k not in hits]
print('SIN USO:', missing)
# generar Lang.swift
rows = ''.join('    "%s": "%s",\n' % (k, v) for k, v in sorted(used.items()))
open(sys.argv[1] + '/Lang.swift', 'w').write('''import Foundation

// MARK: - Idioma (español / inglés)
// Los textos viven en español en el código. `L("…")` devuelve el
// mismo texto o su traducción al inglés según Ajustes → Apariencia →
// Idioma. Las interpolaciones se conservan: L("Hola, \\\\(nombre)")
// busca la clave "Hola, %@" y vuelve a colocar los valores en orden.

enum Lang {
    /// true = inglés. Lo actualiza Store cada vez que cambian los ajustes.
    static var en = false
}

/// Texto con sus valores interpolados separados.
struct LS: ExpressibleByStringInterpolation {
    var key: String
    var args: [String]

    init(stringLiteral value: String) {
        key = value
        args = []
    }

    init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        args = stringInterpolation.args
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var args: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {}

        mutating func appendLiteral(_ literal: String) {
            key += literal
        }

        mutating func appendInterpolation<T>(_ value: T) {
            key += "%@"
            args.append(String(describing: value))
        }
    }
}

/// Traduce (si la app está en inglés) y coloca los valores.
func L(_ s: LS) -> String {
    let format = Lang.en ? (enStrings[s.key] ?? s.key) : s.key
    if s.args.isEmpty { return format }
    let parts = format.components(separatedBy: "%@")
    var out = ""
    for (i, part) in parts.enumerated() {
        out += part
        if i < parts.count - 1 {
            out += i < s.args.count ? s.args[i] : ""
        }
    }
    return out
}

/// Español → inglés. Si falta una clave se muestra el texto en español.
let enStrings: [String: String] = [
''' + rows + ''']
''')
print('claves:', len(used))
