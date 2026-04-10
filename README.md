# ollama-screenshot-renamer

[![macOS](https://img.shields.io/badge/platform-macOS-black)](#)
[![Ollama](https://img.shields.io/badge/requires-Ollama-5A67D8)](#)
[![Python](https://img.shields.io/badge/python-3.x-blue)](#)
[![Shell](https://img.shields.io/badge/shell-zsh%20%7C%20bash-green)](#)
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
- Keeps user-specific settings in a config file

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
├── config.env                # created by you
├── rename-screenshots-daily.sh
└── launchd/
    └── com.example.rename-screenshots.plist
```

### Files

- `config.env.example`  
  Example config file. Copy this to `config.env` and edit the values.

- `rename-screenshots-daily.sh`  
  Main script that scans your screenshot folder and renames matching files.

- `launchd/com.example.rename-screenshots.plist`  
  Template LaunchAgent. You generate a user-specific plist from it during setup.

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

### 3. Pull a vision-capable model

Example:

```bash
ollama pull qwen2.5vl:7b
```

### 4. Create your config file

```bash
cp config.env.example config.env
```

Open `config.env` and edit the values you want to change.

At minimum, verify:

```bash
SCREENSHOT_DIR="$HOME/Documents/Screenshots"
MODEL="qwen2.5vl:7b"
```

### 5. Make the script executable

```bash
chmod +x rename-screenshots-daily.sh
```

### 6. Test in dry-run mode

```bash
DRY_RUN=1 ./rename-screenshots-daily.sh
```

Then inspect the log:

```bash
tail -100 ~/Library/Logs/rename-screenshots.log
```

Example:

```text
DRY RUN: Screen Shot 2026-04-05 at 18.23.14.png -> cats-on-bed_screenshot_2026-04-05.png
```

### 7. Enable real renaming

Once the dry run looks correct:

```bash
DRY_RUN=0 ./rename-screenshots-daily.sh
```

---

## Schedule with launchd

### 1. Define setup variables

Run these commands from the repo root:

```bash
REPO_DIR="$(pwd)"
LABEL="com.${USER}.rename-screenshots"
PLIST_OUT="$HOME/Library/LaunchAgents/${LABEL}.plist"
CONFIG_FILE="$REPO_DIR/config.env"
SCRIPT_PATH="$REPO_DIR/rename-screenshots-daily.sh"
```

### 2. Make sure your LaunchAgents folder exists

```bash
mkdir -p "$HOME/Library/LaunchAgents"
```

### 3. Generate your user-specific plist from the template

```bash
source "$CONFIG_FILE"

sed \
  -e "s|__LABEL__|$LABEL|g" \
  -e "s|__CONFIG_FILE__|$CONFIG_FILE|g" \
  -e "s|__SCRIPT_PATH__|$SCRIPT_PATH|g" \
  -e "s|__DRY_RUN__|$DRY_RUN|g" \
  -e "s|__SCHEDULE_HOUR__|$SCHEDULE_HOUR|g" \
  -e "s|__SCHEDULE_MINUTE__|$SCHEDULE_MINUTE|g" \
  -e "s|__STDOUT_LOG__|$STDOUT_LOG|g" \
  -e "s|__STDERR_LOG__|$STDERR_LOG|g" \
  launchd/com.example.rename-screenshots.plist > "$PLIST_OUT"
```

### 4. Load the LaunchAgent

```bash
launchctl bootout gui/$(id -u) "$PLIST_OUT" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST_OUT"
launchctl enable gui/$(id -u)/"$LABEL"
launchctl kickstart -k gui/$(id -u)/"$LABEL"
```

### 5. Switch from dry run to real renaming

Set this in `config.env`:

```bash
DRY_RUN="0"
```

Then regenerate and reload the plist:

```bash
source "$CONFIG_FILE"

sed \
  -e "s|__LABEL__|$LABEL|g" \
  -e "s|__CONFIG_FILE__|$CONFIG_FILE|g" \
  -e "s|__SCRIPT_PATH__|$SCRIPT_PATH|g" \
  -e "s|__DRY_RUN__|$DRY_RUN|g" \
  -e "s|__SCHEDULE_HOUR__|$SCHEDULE_HOUR|g" \
  -e "s|__SCHEDULE_MINUTE__|$SCHEDULE_MINUTE|g" \
  -e "s|__STDOUT_LOG__|$STDOUT_LOG|g" \
  -e "s|__STDERR_LOG__|$STDERR_LOG|g" \
  launchd/com.example.rename-screenshots.plist > "$PLIST_OUT"

launchctl bootout gui/$(id -u) "$PLIST_OUT" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST_OUT"
launchctl kickstart -k gui/$(id -u)/"$LABEL"
```

---

## Advanced Config

All normal user-specific changes should go into `config.env`.

### Common settings

```bash
SCREENSHOT_DIR="$HOME/Documents/Screenshots"
MODEL="qwen2.5vl:7b"
LOGFILE="$HOME/Library/Logs/rename-screenshots.log"
DRY_RUN="1"
MAX_FILES="200"
SCHEDULE_HOUR="21"
SCHEDULE_MINUTE="0"
```

### Change the screenshot folder

Example:

```bash
SCREENSHOT_DIR="$HOME/Desktop"
```

or:

```bash
SCREENSHOT_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Screenshots"
```

### Change the model

Example:

```bash
MODEL="qwen2.5vl:7b"
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

Then regenerate the plist and reload it.

### Change screenshot matching

If your Mac uses a different screenshot filename pattern, update this:

```bash
SCREENSHOT_NAME_REGEX='^(Screen[[:space:]]Shot|Screenshot|Screen_Shot|Screen-Shot)'
```

### Change the already-renamed pattern

If you change the target filename format, update this too:

```bash
ALREADY_RENAMED_REGEX='^[a-z0-9-]+_screenshot_[0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]+)?\.(png|jpg|jpeg)$'
```

### Change accepted word count

```bash
MIN_WORDS="3"
MAX_WORDS="6"
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

### launchd is not running it

Check:

```bash
launchctl print gui/$(id -u)/"$LABEL"
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
