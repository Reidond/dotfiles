#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Defaults (override via env if desired)
PRESET="${PRESET:-slow}"
CRF="${CRF:-22}"
AUDIO_BR="${AUDIO_BR:-160k}"

NO_AUDIO=0

usage() {
  cat <<'EOF'
Usage:
  mkv_to_h265_mp4.sh [OPTIONS] [DIR]

Converts .mkv/.webm files in DIR (default: current directory) to .mp4 (H.265/HEVC),
overwriting outputs safely (temp file + atomic rename).

Options:
  -n, --no-audio      Remove audio entirely (ffmpeg -an)
  -h, --help          Show this help

Env overrides:
  PRESET=slow|slower|veryslow
  CRF=22
  AUDIO_BR=160k       (ignored when --no-audio is used)

Examples:
  ./mkv_to_h265_mp4.sh
  ./mkv_to_h265_mp4.sh "/path/to/folder"
  ./mkv_to_h265_mp4.sh --no-audio
  CRF=20 PRESET=slower ./mkv_to_h265_mp4.sh
EOF
}

encode_one() {
  local in="$1"
  local out="${in%.*}.mp4"

  # Temp dir next to the output so the final mv is an atomic rename on same filesystem
  local tmpdir tmpout
  tmpdir="$(mktemp -d "${out}.tmpdir.XXXXXXXX")"
  tmpout="${tmpdir}/$(basename -- "$out")"

  # Always clean temp on exit from this function (success or failure)
  trap 'rm -rf -- "$tmpdir"' RETURN

  printf 'Converting: %s\n      -> %s\n' "$in" "$out" >&2

  # Build args safely (avoids word-splitting bugs)
  local -a args
  args=(
    -hide_banner
    -nostdin
    -y
    -i "$in"
    -map 0:v:0
    -c:v libx265
    -preset "$PRESET"
    -crf "$CRF"
    -tag:v hvc1
    -movflags +faststart
  )

  if (( NO_AUDIO )); then
    args+=( -an )
  else
    args+=(
      -map 0:a:0?
      -c:a aac
      -b:a "$AUDIO_BR"
    )
  fi

  args+=( "$tmpout" )

  ffmpeg "${args[@]}"

  # Overwrite output atomically (replaces existing .mp4 only after successful encode)
  mv -f -- "$tmpout" "$out"

  rm -rf -- "$tmpdir"
  trap - RETURN
}

main() {
  local dir="."

  while (($#)); do
    case "$1" in
      -n|--no-audio)
        NO_AUDIO=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf 'Error: unknown option: %s\n\n' "$1" >&2
        usage >&2
        exit 2
        ;;
      *)
        dir="$1"
        shift
        ;;
    esac
  done

  if [[ ! -d "$dir" ]]; then
    printf 'Error: not a directory: %s\n' "$dir" >&2
    exit 2
  fi

  command -v ffmpeg >/dev/null 2>&1 || { printf 'Error: ffmpeg not found in PATH\n' >&2; exit 127; }
  command -v mktemp >/dev/null 2>&1 || { printf 'Error: mktemp not found in PATH\n' >&2; exit 127; }
  command -v find  >/dev/null 2>&1 || { printf 'Error: find not found in PATH\n' >&2; exit 127; }

  local count=0

  # Top-level only (no recursion). Remove "-maxdepth 1" to recurse.
  while IFS= read -r -d '' file; do
    count=$((count + 1))
    encode_one "$file"
  done < <(
    find "$dir" -maxdepth 1 -type f \( -iname '*.mkv' -o -iname '*.webm' \) -print0
  )

  if [[ "$count" -eq 0 ]]; then
    printf 'No .mkv/.webm files found in: %s\n' "$dir" >&2
  else
    printf 'Done. Converted %s file(s).\n' "$count" >&2
  fi
}

main "$@"
