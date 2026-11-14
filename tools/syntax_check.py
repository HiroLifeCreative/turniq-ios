import sys, glob
import tree_sitter_swift as tss
from tree_sitter import Language, Parser
p = Parser(Language(tss.language()))
bad = 0
for f in sorted(glob.glob(sys.argv[1] + '/*.swift')):
    src = open(f, 'rb').read()
    tree = p.parse(src)
    errs = []
    def walk(n):
        if n.type == 'ERROR' or n.is_missing:
            errs.append((n.start_point[0] + 1, n.type, src[n.start_byte:n.end_byte][:60]))
            return
        for c in n.children: walk(c)
    walk(tree.root_node)
    print(f.split('/')[-1], 'OK' if not errs else errs[:6])
    bad += len(errs)
print('errors:', bad)
