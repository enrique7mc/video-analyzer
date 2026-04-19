# video-analyzer

Claude Code plugin that extracts frames from a video (local file or URL) so Claude can analyze them visually. Ships a `/video-analyzer:video` slash command backed by ffmpeg.

## Install

Requires [ffmpeg](https://ffmpeg.org/) on your `PATH`:

```bash
brew install ffmpeg
```

Then add the marketplace and install the plugin inside Claude Code:

```
/plugin marketplace add enrique7mc/video-analyzer
/plugin install video-analyzer@video-analyzer
```

## Usage

```
/video-analyzer:video <video_path_or_url> [options]
```

> Claude Code plugin commands are always namespaced as `/<plugin>:<command>`. The short form `/video` will not resolve — use the fully-qualified name above.

Options:

- `--mode <mode>` — `smart` (default), `keyframes`, or `interval`
- `--fps <n>` — Frames per second for interval mode (default: 1)
- `--max <n>` — Maximum frames to extract (default: 20)
- `--output <dir>` — Custom output directory

Modes:

- **smart** — Scene change detection with interval fallback. Best for app walkthroughs and demos.
- **keyframes** — Extract I-frames only. Good for quick overview of longer videos.
- **interval** — Fixed FPS extraction. Best when you need even time coverage.

## Examples

```
/video-analyzer:video walkthrough.mov
/video-analyzer:video bug.mp4 --max 30
/video-analyzer:video demo.mov --mode interval --fps 0.5
/video-analyzer:video "https://example.com/demo.mp4"
```

Extracted frames land in `frames/<video_name>_<timestamp>/` inside the plugin directory and Claude reads each one with the Read tool to describe or debug what's on screen.

## Standalone script

You can also run the extractor directly without Claude Code:

```bash
bash analyze_video.sh <video_path_or_url> [options]
```
