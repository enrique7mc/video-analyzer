# Video Analyzer

Extract frames from videos for visual analysis by Claude.

## Usage

```bash
bash analyze_video.sh <video_path_or_url> [options]
```

### Options

- `--mode <mode>` — `smart` (default), `keyframes`, or `interval`
- `--fps <n>` — Frames per second for interval mode (default: 1)
- `--max <n>` — Maximum frames to extract (default: 20)
- `--output <dir>` — Output directory (default: ./frames/<name>)

### Modes

- **smart** — Scene change detection with interval fallback. Best for app walkthroughs and demos.
- **keyframes** — Extract I-frames only. Good for quick overview of longer videos.
- **interval** — Fixed FPS extraction. Best when you need even time coverage.

## Examples

```bash
# App walkthrough — smart mode picks scene changes
bash analyze_video.sh walkthrough.mov

# Bug repro — more frames to catch the moment
bash analyze_video.sh bug.mp4 --max 30

# Long demo — one frame every 2 seconds
bash analyze_video.sh demo.mov --mode interval --fps 0.5

# Video from a URL
bash analyze_video.sh "https://example.com/demo.mp4"
```

## After extraction

Frames are saved as PNG files in `./frames/<video_name>/` by default (gitignored). Claude can read them with the Read tool for visual analysis.

## Requirements

- ffmpeg (installed via homebrew)
