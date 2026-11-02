"""Turn the TerraPrinter STL of Elbrus into a height grid for the game.

stl_path out_gd out_png
The STL is a disc of radius 100 mm on a plinth; x east, y north, z up.
"""
import struct, sys, math, base64, zlib
stl, out_gd, out_png = sys.argv[1:4]
REACH = 620.0           # game metres from the centre to the edge of the grid
CROP = 65.0             # STL millimetres that map to REACH
N_IN, N_OUT = 256, 128
AXIS = (0.94, -0.34)    # HeightField.ELBRUS_AXIS, west summit to east, in (x, z)

data = open(stl, 'rb').read()
n = struct.unpack_from('<I', data, 80)[0]
R = 100.0
s = [[0.0]*N_IN for _ in range(N_IN)]; c = [[0]*N_IN for _ in range(N_IN)]
for t in range(n):
    v = struct.unpack_from('<9f', data, 84 + t*50 + 12)
    if min(v[2], v[5], v[8]) < 1.0:
        continue
    for k in range(3):
        x, y, z = v[3*k], v[3*k+1], v[3*k+2]
        i = int((x + R) / (2*R) * N_IN); j = int((R - y) / (2*R) * N_IN)
        if 0 <= i < N_IN and 0 <= j < N_IN:
            s[j][i] += z; c[j][i] += 1
g = [[s[j][i]/c[j][i] if c[j][i] else float('nan') for i in range(N_IN)] for j in range(N_IN)]
for _ in range(8):
    for j in range(N_IN):
        for i in range(N_IN):
            if math.isnan(g[j][i]):
                nb = [g[b][a] for a, b in ((i-1, j), (i+1, j), (i, j-1), (i, j+1))
                      if 0 <= a < N_IN and 0 <= b < N_IN and not math.isnan(g[b][a])]
                if nb: g[j][i] = sum(nb)/len(nb)

def at_mm(x, y):
    """Bilinear height at STL millimetres (x east, y north)."""
    fi = (x + R) / (2*R) * N_IN - 0.5; fj = (R - y) / (2*R) * N_IN - 0.5
    i0 = max(0, min(N_IN-2, int(math.floor(fi)))); j0 = max(0, min(N_IN-2, int(math.floor(fj))))
    a = min(max(fi - i0, 0), 1); b = min(max(fj - j0, 0), 1)
    q = [g[j0][i0], g[j0][i0+1], g[j0+1][i0], g[j0+1][i0+1]]
    q = [0.0 if math.isnan(v) else v for v in q]
    return (q[0]*(1-a) + q[1]*a)*(1-b) + (q[2]*(1-a) + q[3]*a)*b

# The two summits, in millimetres.
cells = sorted(((g[j][i], i, j) for j in range(N_IN) for i in range(N_IN) if not math.isnan(g[j][i])), reverse=True)
top = cells[0]
second = next(p for p in cells if math.hypot(p[1]-top[1], p[2]-top[2]) > 10)
def mm(p): return ((p[1] + 0.5) / N_IN * 2*R - R, R - (p[2] + 0.5) / N_IN * 2*R)
west_mm, east_mm = mm(top), mm(second)          # the higher is the western
mid = ((west_mm[0] + east_mm[0]) / 2, (west_mm[1] + east_mm[1]) / 2)
# West to east in game (x, z) terms: z is south, so -y.
we = (east_mm[0] - west_mm[0], -(east_mm[1] - west_mm[1]))
turn = math.atan2(AXIS[1], AXIS[0]) - math.atan2(we[1], we[0])
print('west', west_mm, top[0], 'east', east_mm, second[0], 'turn deg %.1f' % math.degrees(turn))

def game_to_mm(gx, gz):
    # Undo the turn, scale, and put north back up.
    ca, sa = math.cos(-turn), math.sin(-turn)
    lx = gx * ca - gz * sa; lz = gx * sa + gz * ca
    k = CROP / REACH
    return mid[0] + lx * k, mid[1] - lz * k

rim = [at_mm(*game_to_mm(REACH * math.cos(a), REACH * math.sin(a))) for a in [t * math.tau / 360 for t in range(360)]]
rim_level = sorted(rim)[len(rim)//4]           # the lower quarter: valleys, not ridges
peak = top[0]
out = []
for j in range(N_OUT):
    row = []
    for i in range(N_OUT):
        gx = ((i + 0.5) / N_OUT * 2 - 1) * REACH; gz = ((j + 0.5) / N_OUT * 2 - 1) * REACH
        r = math.hypot(gx, gz) / REACH
        h = (at_mm(*game_to_mm(gx, gz)) - rim_level) / (peak - rim_level)
        t = min(max((r - 0.62) / (1.0 - 0.62), 0), 1)
        fade = 1 - t*t*(3 - 2*t)
        row.append(max(0.0, h) * fade)
    out.append(row)
# No blur: the game samples this bicubically, which is smoothing enough, and a
# blur on top filled the saddle in.
bl = out
hi = max(max(r) for r in bl)
q = bytearray()
for row in bl:
    for v in row:
        q += struct.pack('<H', int(round(min(v / hi, 1.0) * 65535)))
b64 = base64.b64encode(bytes(q)).decode()
def to_game(p):
    dx, dy = p[0] - mid[0], p[1] - mid[1]
    lx, lz = dx * REACH / CROP, -dy * REACH / CROP
    ca, sa = math.cos(turn), math.sin(turn)
    return (lx * ca - lz * sa, lx * sa + lz * ca)
wg, eg = to_game(west_mm), to_game(east_mm)
lines = [
    "class_name ElbrusRelief",
    "extends RefCounted",
    "",
    "## The great mountain's shape, taken from a real terrain model of Elbrus.",
    "##",
    "## Generated, not written: a TerraPrinter 3D print of the massif (terrain",
    "## data via terraprinter.com, map data (c) OpenStreetMap contributors) was",
    "## averaged into a grid, the middle %d mm of it turned so the line through the" % CROP,
    "## two summits runs along HeightField.ELBRUS_AXIS, scaled to the mountain's",
    "## reach, and faded to nothing towards the rim so its skirts meet the range",
    "## around it. Heights are 0..1 of the summit, row by row from north-west.",
    "## Regenerate with the script kept beside the model rather than editing this.",
    "",
    "const SIZE := %d" % N_OUT,
    "## Where the two summits stand, in metres from the mountain's centre.",
    "const WEST_SUMMIT := Vector2(%.1f, %.1f)" % wg,
    "const EAST_SUMMIT := Vector2(%.1f, %.1f)" % eg,
    "",
    "const DATA := \"%s\"" % b64,
    "",
    "static var _heights := PackedFloat32Array()",
    "",
    "static func _ensure() -> void:",
    "\tif not _heights.is_empty():",
    "\t\treturn",
    "\tvar raw := Marshalls.base64_to_raw(DATA)",
    "\t_heights.resize(SIZE * SIZE)",
    "\tfor index in SIZE * SIZE:",
    "\t\t_heights[index] = float(raw.decode_u16(index * 2)) / 65535.0",
    "",
    "static func _cell(i: int, j: int) -> float:",
    "\treturn _heights[clampi(j, 0, SIZE - 1) * SIZE + clampi(i, 0, SIZE - 1)]",
    "",
    "## Height, 0..1, at a point given in metres from the centre (x east, z south),",
    "## `reach` metres to the edge. Bicubic, so slopes have no creases at the cell",
    "## edges: snow and rock are chosen from steepness, and a crease is a cliff.",
    "static func height(x: float, z: float, reach: float) -> float:",
    "\t_ensure()",
    "\tvar fi := (x / reach * 0.5 + 0.5) * float(SIZE) - 0.5",
    "\tvar fj := (z / reach * 0.5 + 0.5) * float(SIZE) - 0.5",
    "\tvar i0 := floori(fi)",
    "\tvar j0 := floori(fj)",
    "\tvar tx := fi - float(i0)",
    "\tvar tz := fj - float(j0)",
    "\tvar rows := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])",
    "\tfor dj in 4:",
    "\t\tvar j := j0 - 1 + dj",
    "\t\trows[dj] = _catmull_rom(",
    "\t\t\t_cell(i0 - 1, j), _cell(i0, j), _cell(i0 + 1, j), _cell(i0 + 2, j), tx",
    "\t\t)",
    "\treturn maxf(0.0, _catmull_rom(rows[0], rows[1], rows[2], rows[3], tz))",
    "",
    "static func _catmull_rom(a: float, b: float, c: float, d: float, t: float) -> float:",
    "\treturn b + 0.5 * t * (c - a + t * (2.0 * a - 5.0 * b + 4.0 * c - d + t * (3.0 * (b - c) + d - a)))",
    "",
]
open(out_gd, 'w').write("\n".join(lines))
# A preview of the result.
raw = b''
for row in bl:
    raw += b'\x00' + bytes(int(255 * v / hi) for v in row)
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
open(out_png, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', N_OUT, N_OUT, 8, 0, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
print('rim level %.2f peak %.2f, summits in game m: west %s east %s, sep %.0f m' % (rim_level, peak, wg, eg, math.dist(wg, eg)))
