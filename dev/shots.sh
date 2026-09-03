#!/usr/bin/env bash
# Renders a fixed set of views of the world.
#
# The point is that the set never changes: the same camera positions, the same
# times of day, the same seed. That makes two runs from different weeks directly
# comparable, which is the only way to see whether the game is getting better
# rather than just getting different.
#
#   dev/shots.sh [output-directory]
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$PROJECT/build/shots}"
RES="${RES:-1600x900}"
SEED="${SEED:-20260903}"

mkdir -p "$OUT"

shoot() {
  local name="$1"; shift
  echo "  $name"
  "$GODOT" --path "$PROJECT" --resolution "$RES" res://dev/capture.tscn -- \
    --out="$OUT/$name.png" --seed="$SEED" --warmup=1400 "$@" \
    2>&1 | grep -E "scene:|player:|still streaming|SHADER ERROR" || true
}

echo "rendering into $OUT"
shoot 01-valley      --pos=-40,90,220 --look=20,0,0     --time=0.32
shoot 02-riverbank   --pos=-2,4.0,30  --look=26,1.2,-6  --time=0.40
shoot 03-forest      --player=1 --yaw=118 --pitch=-12   --time=0.40
shoot 04-evening     --player=1 --yaw=250 --pitch=-8    --time=0.72
shoot 05-map         --pos=-30,300,320 --look=10,0,-60  --time=0.45
echo "done"
