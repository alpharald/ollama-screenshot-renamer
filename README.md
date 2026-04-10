# ollama-screenshot-renamer

[![macOS](https://img.shields.io/badge/platform-macOS-black)](#)
[![Ollama](https://img.shields.io/badge/requires-Ollama-5A67D8)](#)
[![Python](https://img.shields.io/badge/python-3.x-blue)](#)
[![Shell](https://img.shields.io/badge/shell-zsh-green)](#)
[![Status](https://img.shields.io/badge/status-experimental-orange)](#)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#)

Rename macOS screenshots automatically with a local vision model running in Ollama.

This project scans a screenshot folder on a schedule, sends each screenshot to a vision-capable model, generates a short descriptive filename, and renames the file to this format:

```text
description_screenshot_yyyy-mm-dd.png
```

Example:

```text
cats-on-bed_screenshot_2026-04-05.png
```

---

## Warning

This project renames files in place.

Before enabling real renaming:

- Start in dry-run mode.
- Test on a small folder first.
- Back up important screenshots.
- Review the proposed filenames in the log.
- Make sure your screenshot folder and model are configured correctly.

The goal of this repo is to keep user-specific changes in one place: `config.env`.

---

## Features

- Local-first screenshot renaming with Ollama
- Native macOS scheduling with `launchd`
- Dry-run mode enabled by default
- Skips files already renamed into the target format
- Handles filename collisions safely
- Uses file creation date for the `yyyy-mm-dd` suffix
- Keeps user-specific settings in one config file

---

## Requirements

- macOS
- Ollama installed and running
- A vision-capable Ollama model
- Python 3
- `zsh`

---

## Repo Layout

```text
.
├── README.md
├── config.env.example
├── config.env                      # created by the user
├── rename-screenshots-daily.sh
├── install-launchagent.sh
└── launchd/
    └── com.example.rename-screenshots.plist
```

### Files

- `config.env.example`  
  Example config file. Copy this to `config.env` and edit the values.

- `rename-screenshots-daily.sh`  
  Main script that scans your screenshot folder and renames matching files.

- `install-launchagent.sh`  
  Generates and loads your user-specific LaunchAgent plist from the template.

- `launchd/com.example.rename-screenshots.plist`  
  Template LaunchAgent file with placeholders.

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/ollama-screenshot-renamer.git
cd ollama-screenshot-renamer
```

### 2. Make sure Ollama is installed and running

```bash
ollama list
```

### 3. Pull the default model

```bash
ollama pull gemma4:e2b
```

If you want to use another model, change `MODEL` in `config.env`.

### 4. Create your config file

```bash
cp config.env.example config.env
```

Open `config.env` and verify at minimum:

```bash
SCREENSHOT_DIR="$HOME/Documents/Screenshots"
MODEL="gemma4:e2b"
```

### 5. Make the scripts executable

```bash
chmod +x rename-screenshots-daily.sh
chmod +x install-launchagent.sh
```

### 6. Test in dry-run mode

```bash
DRY_RUN=1 ./rename-screenshots-daily.sh
```

Then inspect the log:

```bash
tail -100 "$HOME/Library/Logs/rename-screenshots.log"
```

Example:

```text
DRY RUN: Screen Shot 2026-04-05 at 18.23.14.png -> cats-on-bed_screenshot_2026-04-05.png
```

### 7. Enable real renaming manually

Once the dry run looks correct:

```bash
DRY_RUN=0 ./rename-screenshots-daily.sh
```

### 8. Install the scheduled LaunchAgent

```bash
./install-launchagent.sh
```

This generates a user-specific plist in:

```bash
$HOME/Library/LaunchAgents/
```

and loads it automatically.

### 9. Switch scheduled runs from dry run to real renaming

Edit `config.env`:

```bash
DRY_RUN="0"
```

Then re-run:

```bash
./install-launchagent.sh
```

That regenerates and reloads the LaunchAgent with the updated settings.

---

## Advanced Config

All normal user-specific changes should go in `config.env`.

### Main settings

```bash
LABEL="com.${USER}.rename-screenshots"

SCREENSHOT_DIR="$HOME/Documents/Screenshots"
MODEL="gemma4:e2b"
OLLAMA_API_URL="http://localhost:11434/api/chat"

LOGFILE="$HOME/Library/Logs/rename-screenshots.log"
STDOUT_LOG="$HOME/Library/Logs/rename-screenshots.stdout.log"
STDERR_LOG="$HOME/Library/Logs/rename-screenshots.stderr.log"

DRY_RUN="1"
MAX_FILES="200"

MIN_WORDS="3"
MAX_WORDS="6"

SCHEDULE_HOUR="21"
SCHEDULE_MINUTE="0"

SCREENSHOT_NAME_REGEX='^(Screen[[:space:]]Shot|Screenshot|Screen_Shot|Screen-Shot)'
ALREADY_RENAMED_REGEX='^[a-z0-9-]+_screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]+)?\.(png|jpg|jpeg)$'
```

### Change the screenshot folder

Examples:

```bash
SCREENSHOT_DIR="$HOME/Desktop"
```

```bash
SCREENSHOT_DIR="$HOME/Documents/Screenshots"
```

```bash
SCREENSHOT_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Screenshots"
```

### Change the model

Example:

```bash
MODEL="gemma4:e2b"
```

Make sure it exists:

```bash
ollama list
```

### Change the schedule

Example for 07:30:

```bash
SCHEDULE_HOUR="7"
SCHEDULE_MINUTE="30"
```

Then re-run:

```bash
./install-launchagent.sh
```

### Change screenshot matching

If your Mac uses a different screenshot filename pattern, update:

```bash
SCREENSHOT_NAME_REGEX='^(Screen[[:space:]]Shot|Screenshot|Screen_Shot|Screen-Shot)'
```

### Change the already-renamed pattern

If you change the output filename format, update this too:

```bash
ALREADY_RENAMED_REGEX='^[a-z0-9-]+_screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]+)?\.(png|jpg|jpeg)$'
```

### Change accepted word count

```bash
MIN_WORDS="3"
MAX_WORDS="6"
```

### Optional overrides

These usually do not need to be changed, but you can set them if you want:

```bash
SCRIPT_PATH="/full/path/to/rename-screenshots-daily.sh"
PLIST_OUT="$HOME/Library/LaunchAgents/com.custom.rename-screenshots.plist"
```

---

## Example

Input:

```text
Screen Shot 2026-04-05 at 18.23.14.png
```

Possible output:

```text
cats-on-bed_screenshot_2026-04-05.png
```

---

## Troubleshooting

### Nothing happens

Check:

- Ollama is running
- the selected model exists
- `SCREENSHOT_DIR` is correct
- your files match `SCREENSHOT_NAME_REGEX`

### Files are skipped

Inspect:

```bash
tail -100 "$HOME/Library/Logs/rename-screenshots.log"
tail -100 "$HOME/Library/Logs/rename-screenshots.stderr.log"
```

Common causes:

- model output is empty
- output becomes invalid after sanitization
- output is outside the configured word range
- files are already renamed
- files do not match your screenshot regex

### The LaunchAgent is not running

Check:

```bash
source config.env
launchctl print "gui/$(id -u)/$LABEL"
```

And inspect:

```bash
tail -100 "$HOME/Library/Logs/rename-screenshots.stdout.log"
tail -100 "$HOME/Library/Logs/rename-screenshots.stderr.log"
```

---

## Safety Recommendations

- Keep `DRY_RUN="1"` until the results are consistently good.
- Test on a small folder first.
- Back up important screenshots.
- Review the logs before enabling scheduled real renaming.
- Do not point it at a mixed image archive until your screenshot regex is correct.

---

## Limitations

- Depends heavily on model quality
- Descriptions may still be imperfect
- No confidence score yet
- No quarantine folder yet
- No fallback model yet

---

## License

MIT
