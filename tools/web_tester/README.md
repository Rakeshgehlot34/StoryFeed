# ShortsSplitter Local Web Tester

A standalone local web application to test video splitting, 9:16 Shorts conversions, crop-to-fill, blurred backgrounds, and solid letterboxing directly on your PC with instant video playback.

## Features
- **Zero Python Dependencies:** Uses standard Python library (`http.server`, `urllib`, `subprocess`). No `pip install` required.
- **Fast Local Transcoding:** Runs local FFmpeg with multi-threaded `libx264` ultrafast preset and AAC audio.
- **100% Matching Logic:** Uses the exact same filter graphs and split rules as the ShortsSplitter Flutter application.
- **Instant In-Browser Playback:** Built-in phone mockup with HTML5 video player and HTTP range streaming.
- **Defect-Free Guarantee:** Explicitly maps `-map 0:v` and `-map 0:a?` to guarantee no black screens or dropped video streams.

## Quick Start
Run from the repository root:
```bash
./run_web_tester.sh
```
Or directly with Python:
```bash
python3 tools/web_tester/server.py 8080
```
Then open:
```
http://localhost:8080
```

