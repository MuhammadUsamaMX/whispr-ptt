# whispr-ptt

Push-to-talk speech-to-text for Arch Linux.

Press **F9** to start recording. Press **F9** again to stop and have the text typed at your cursor.

This project runs directly with `pywhispercpp` and does not depend on OpenWhispr.

## How it works

```
Press F9   -> pw-record starts capturing mic (16 kHz mono)
While held -> live speech preview updates in notification
Press F9   -> recording stops -> pywhispercpp transcribes
           -> ydotool types text at cursor
           -> only copies to clipboard if typing fails
```

- **Key listener**: `python-evdev` on physical keyboard devices only (virtual/ydotool devices excluded)
- **Hotkey**: F9 toggle — press once to start, once to stop (configurable)
- **Audio**: PipeWire `pw-record` at 16 kHz mono
- **Live preview**: partial transcription shown in notification while you speak
- **Typing**: `ydotool type` — clipboard only used as a fallback when typing fails
- **Notifications**: `notify-send` (live preview + clipboard fallback only)
- **Daemon**: `systemd --user` service, starts on login

## Requirements

- Arch Linux (or Arch-based)
- Wayland desktop session (GNOME or other)
- PipeWire

## Install

```bash
git clone https://github.com/MuhammadUsamaMX/whispr-ptt.git
cd whispr-ptt
bash install.sh
```

The installer will:

1. Install required packages (`python-evdev`, `ydotool`, `wl-clipboard`, `libnotify`, `pipewire`, etc.)
2. Ask you to select a Whisper model
3. Install `whispr-ptt` to `/usr/local/bin/whispr-ptt`
4. Enable `ydotoold.service` and `whispr-ptt.service`

After install, re-login once so `input` group changes apply.

## Model selection

Models are stored in `/usr/local/share/whispr`.

| # | Model | Size | Speed |
|---|-------|------|-------|
| 1 | `tiny.en` | 75 MB | ~100 ms |
| 2 | `base.en` | 140 MB | ~300 ms |
| 3 | `large-v3-turbo` | 1.5 GB | requires GPU |

To change model after install, edit `/usr/local/bin/whispr-ptt` line:
```python
MODEL = "/usr/local/share/whispr/ggml-base.en.bin"
```
Then: `systemctl --user restart whispr-ptt`

## Hotkey

Default is **F9 toggle**. Can be changed in `/usr/local/bin/whispr-ptt`:

```python
# Toggle mode (single key, press once to start, once to stop)
HOTKEY = ("f9",)

# Hold mode (hold to record, release to transcribe)
HOTKEY = ("shift", "r")
```

Then restart: `systemctl --user restart whispr-ptt`

## Notifications

| When | Notification shown |
|------|--------------------|
| Startup | "whispr-ptt ready — Press F9" |
| Recording | "Recording..." |
| While speaking | Live speech preview updates in-place |
| Text typed successfully | Notification dismissed silently |
| Typing failed | "Copied to clipboard" with text |
| Error | Error message shown |

## Service commands

```bash
systemctl --user status whispr-ptt
systemctl --user restart whispr-ptt
journalctl --user -u whispr-ptt -f
```

## Full OpenWhispr removal

If OpenWhispr popups still appear, remove old artifacts:

```bash
pkill -f 'OpenWhispr.AppImage|openwhispr|open-whispr' 2>/dev/null || true
sudo rm -f /usr/local/bin/OpenWhispr.AppImage /usr/local/bin/whispr
rm -f ~/.local/share/applications/*open*whispr*.desktop
rm -f ~/.config/autostart/*open*whispr*.desktop
```

## Uninstall

```bash
bash uninstall.sh
```

## License

MIT
