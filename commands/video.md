Extract frames from a video (local file or URL) and analyze them visually.

## Usage

The user provides a video path or URL after `/video-analyzer:video`, with optional flags:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/analyze_video.sh $ARGUMENTS
```

If no `--max` is specified in `$ARGUMENTS`, add `--max 20` as default.

## Options

- `--mode <mode>` — `smart` (default), `keyframes`, or `interval`
- `--fps <n>` — Frames per second for interval mode (default: 1)
- `--max <n>` — Maximum frames to extract (default: 20)
- `--output <dir>` — Custom output directory

## Examples

- `/video-analyzer:video walkthrough.mov` — Analyze a local video
- `/video-analyzer:video bug.mp4 --max 30` — More frames for detailed debugging
- `/video-analyzer:video "https://example.com/demo.mp4"` — Analyze from URL

## Behavior

1. Run the extraction command above, passing all user arguments through
2. Parse the output to find the frames directory path (last lines list frame paths)
3. Use Glob to find all `frame_*.png` files in the output directory
4. Read **every** extracted frame using the Read tool — do not skip any
5. Analyze what you see, adapting to context:
   - **Debugging** (simulator recordings, screen recordings, app walkthroughs): Focus on UI state, error messages, unexpected behavior, and transitions between screens. Call out anything that looks broken or unusual.
   - **General** (any other video): Summarize the content, describe key scenes and notable details across the timeline.
6. Report the output directory path so the user can reference individual frames later
7. If the script fails, show the error output to the user
