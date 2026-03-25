#!/bin/bash
# analyze_video.sh — Extract frames from a video for visual analysis
# Usage: analyze_video.sh <video_path> [--mode keyframes|interval|smart] [--fps 1] [--max 20]

set -euo pipefail

VIDEO=""
MODE="smart"
FPS="1"
MAX_FRAMES=20
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    --max) MAX_FRAMES="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: analyze_video.sh <video_path> [options]"
      echo ""
      echo "Options:"
      echo "  --mode <mode>    Extraction mode: keyframes, interval, smart (default: smart)"
      echo "                   keyframes  — extract I-frames (scene changes)"
      echo "                   interval   — extract at fixed FPS"
      echo "                   smart      — scene detection + interval fallback"
      echo "  --fps <n>        Frames per second for interval mode (default: 1)"
      echo "  --max <n>        Maximum frames to extract (default: 20)"
      echo "  --output <dir>   Output directory (default: ./frames/<basename>)"
      echo ""
      echo "Examples:"
      echo "  analyze_video.sh walkthrough.mov"
      echo "  analyze_video.sh bug.mp4 --mode keyframes --max 30"
      echo "  analyze_video.sh demo.mov --mode interval --fps 0.5"
      exit 0
      ;;
    *) VIDEO="$1"; shift ;;
  esac
done

if [[ -z "$VIDEO" ]]; then
  echo "Error: No video file provided"
  echo "Usage: analyze_video.sh <video_path_or_url> [--mode keyframes|interval|smart] [--fps 1] [--max 20]"
  exit 1
fi

# Download if VIDEO is a URL
DOWNLOADED=""
if [[ "$VIDEO" =~ ^https?:// ]]; then
  # Extract filename from URL (strip query params)
  URL_PATH="${VIDEO%%\?*}"
  URL_BASENAME=$(basename "$URL_PATH")
  # Fall back to "video.mp4" if basename has no extension
  if [[ "$URL_BASENAME" != *.* ]]; then
    URL_BASENAME="video.mp4"
  fi
  DOWNLOADED="/tmp/video-analyzer-dl_${URL_BASENAME}"
  echo "Downloading: $VIDEO"
  if ! curl -fSL --progress-bar -o "$DOWNLOADED" "$VIDEO"; then
    echo "Error: Failed to download: $VIDEO"
    rm -f "$DOWNLOADED"
    exit 1
  fi
  echo ""
  VIDEO="$DOWNLOADED"
fi

if [[ ! -f "$VIDEO" ]]; then
  echo "Error: File not found: $VIDEO"
  exit 1
fi

# Derive output directory from video filename
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASENAME=$(basename "$VIDEO" | sed 's/\.[^.]*$//')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="${SCRIPT_DIR}/frames/${BASENAME}_${TIMESTAMP}"
fi
mkdir -p "$OUTPUT_DIR"

# Get video info
DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null | cut -d. -f1)
RESOLUTION=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$VIDEO" 2>/dev/null)
TOTAL_FRAMES=$(ffprobe -v quiet -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$VIDEO" 2>/dev/null || echo "unknown")

echo "Video: $(basename "$VIDEO")"
echo "Duration: ${DURATION}s | Resolution: ${RESOLUTION} | Total frames: ${TOTAL_FRAMES}"
echo "Mode: ${MODE} | Max frames: ${MAX_FRAMES}"
echo "Output: ${OUTPUT_DIR}"
echo ""

extract_keyframes() {
  ffmpeg -v quiet -i "$VIDEO" \
    -vf "select='eq(ptype,I)',scale=iw*min(1\,1920/iw):ih*min(1\,1920/iw)" \
    -vsync vfr \
    -frame_pts 1 \
    "$OUTPUT_DIR/frame_%04d.png" 2>/dev/null
}

extract_interval() {
  ffmpeg -v quiet -i "$VIDEO" \
    -vf "fps=${FPS},scale=iw*min(1\,1920/iw):ih*min(1\,1920/iw)" \
    "$OUTPUT_DIR/frame_%04d.png" 2>/dev/null
}

extract_scene_detect() {
  # Scene change detection with threshold
  ffmpeg -v quiet -i "$VIDEO" \
    -vf "select='gt(scene,0.3)',scale=iw*min(1\,1920/iw):ih*min(1\,1920/iw)" \
    -vsync vfr \
    -frame_pts 1 \
    "$OUTPUT_DIR/frame_%04d.png" 2>/dev/null
}

case "$MODE" in
  keyframes)
    echo "Extracting I-frames (keyframes)..."
    extract_keyframes
    ;;
  interval)
    echo "Extracting at ${FPS} fps..."
    extract_interval
    ;;
  smart)
    echo "Running scene detection..."
    extract_scene_detect
    SCENE_COUNT=$(find "$OUTPUT_DIR" -maxdepth 1 -name 'frame_*.png' | wc -l | tr -d ' ')
    if [[ "$SCENE_COUNT" -lt 3 ]]; then
      echo "Scene detection found only ${SCENE_COUNT} frames, falling back to interval..."
      rm -f "$OUTPUT_DIR"/frame_*.png
      # Calculate fps to get ~MAX_FRAMES across the duration
      if [[ -n "$DURATION" && "$DURATION" -gt 0 ]]; then
        CALC_FPS=$(echo "scale=2; $MAX_FRAMES / $DURATION" | bc)
        # Clamp to at most 2 fps
        if (( $(echo "$CALC_FPS > 2" | bc -l) )); then
          CALC_FPS="2"
        fi
        FPS="$CALC_FPS"
      fi
      extract_interval
    fi
    ;;
  *)
    echo "Error: Unknown mode: $MODE"
    exit 1
    ;;
esac

# Trim to max frames — keep evenly spaced subset
FRAME_FILES=()
while IFS= read -r f; do FRAME_FILES+=("$f"); done < <(find "$OUTPUT_DIR" -maxdepth 1 -name 'frame_*.png' | sort)
TOTAL=${#FRAME_FILES[@]}

if [[ "$TOTAL" -eq 0 ]]; then
  echo "Error: No frames extracted. The video may be corrupted or in an unsupported format."
  exit 1
fi

if [[ "$TOTAL" -gt "$MAX_FRAMES" ]]; then
  echo "Extracted ${TOTAL} frames, trimming to ${MAX_FRAMES} evenly spaced..."
  # Calculate which frames to keep
  KEEP_INDICES=()
  for ((i=0; i<MAX_FRAMES; i++)); do
    IDX=$(echo "scale=0; $i * ($TOTAL - 1) / ($MAX_FRAMES - 1)" | bc)
    KEEP_INDICES+=("$IDX")
  done

  # Remove frames not in keep list
  for ((i=0; i<TOTAL; i++)); do
    KEEP=false
    for idx in "${KEEP_INDICES[@]}"; do
      if [[ "$i" -eq "$idx" ]]; then
        KEEP=true
        break
      fi
    done
    if [[ "$KEEP" == "false" ]]; then
      rm "${FRAME_FILES[$i]}"
    fi
  done
fi

# Rename remaining frames sequentially
REMAINING=()
while IFS= read -r f; do REMAINING+=("$f"); done < <(find "$OUTPUT_DIR" -maxdepth 1 -name 'frame_*.png' | sort)
for ((i=0; i<${#REMAINING[@]}; i++)); do
  NEW_NAME=$(printf "$OUTPUT_DIR/frame_%03d.png" $((i+1)))
  if [[ "${REMAINING[$i]}" != "$NEW_NAME" ]]; then
    mv "${REMAINING[$i]}" "$NEW_NAME"
  fi
done

FINAL_COUNT=$(find "$OUTPUT_DIR" -maxdepth 1 -name 'frame_*.png' | wc -l | tr -d ' ')

# Clean up downloaded temp file
if [[ -n "$DOWNLOADED" ]]; then
  rm -f "$DOWNLOADED"
fi

echo ""
echo "Done! Extracted ${FINAL_COUNT} frames."
echo ""
echo "Frames:"
find "$OUTPUT_DIR" -maxdepth 1 -name 'frame_*.png' | sort
