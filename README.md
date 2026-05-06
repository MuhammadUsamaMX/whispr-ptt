# whispr-ptt

> **Push-to-talk speech-to-text for Arch Linux — works system-wide, no app needed.**
>
> Hold `Shift+R` → speak → release → transcribed text typed at your cursor.

Powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) and [OpenWhispr](https://github.com/OpenWhispr/openwhispr)'s bundled binaries. Runs entirely on-device. No cloud, no subscription.

---

## How it works

```
Hold Shift+R  →  pw-record captures mic  →  whisper-server transcribes
→  ydotool types text at cursor  →  also copied to clipboard as fallback
```

- **Key listener** — OpenWhispr's `linux-key-listener` binary (evdev, works on Wayland + X11)
- **Audio** — PipeWire `pw-record` at 16 kHz mono
- **Transcription** — whisper.cpp HTTP server on `127.0.0.1:18080`
- **GPU acceleration** — Vulkan via `GGML_VULKAN=1` (uses your iGPU/dGPU automatically)
- **Text injection** — `ydotool type` (no clipboard paste shortcut, no accidental Enter)
- **Runs as a systemd user service** — starts on login, zero manual steps

---

## Requirements

- Arch Linux (or Arch-based: Manjaro, EndeavourOS, Garuda, CachyOS…)
- Wayland or X11
- PipeWire (default on modern Arch)

---

## Install

```bash
git clone https://github.com/MuhammadUsamaMX/whispr-ptt.git
cd whispr-ptt
bash install.sh
```

The installer will:

1. Install `ydotool`, `wl-clipboard`, `vulkan-radeon`, `vulkan-icd-loader` via `pacman`
2. Download the OpenWhispr AppImage and extract `whisper-server` + `linux-key-listener`
3. Ask you to **pick a Whisper model** (see below)
4. Install `whispr-ptt` daemon to `/usr/local/bin`
5. Enable `ydotoold` and `whispr-ptt` as systemd user services (auto-start on login)
6. Add a `udev` rule so `/dev/uinput` is accessible

> **After install:** re-login once (or run `newgrp input`) so the `input` group takes effect.

---

## Whisper models

The installer lets you choose one of three models:

| # | Model | Size | Speed | Quality | Best for |
|---|-------|------|-------|---------|----------|
| 1 | `tiny.en` | **75 MB** | ⚡ ~100 ms | Good | Fast dictation, English only |
| 2 | `base.en` | **140 MB** | ⚡ ~300 ms | Better | Everyday use, English only |
| 3 | `large-v3-turbo` | **1.5 GB** | 🐢 ~5–20 s\* | Best | Multilingual, highest accuracy |

> \* `large-v3-turbo` is slow on CPU/iGPU. Recommended only if you have a dedicated NVIDIA/AMD GPU.

Models are stored at `/usr/local/share/whispr/`. You can swap the model at any time by editing line 17 of `/usr/local/bin/whispr-ptt`:

```python
MODEL = "/usr/local/share/whispr/ggml-base.en.bin"
```

Then restart: `systemctl --user restart whispr-ptt`

---

## Usage

| Action | Result |
|--------|--------|
| Hold `Shift+R` | Starts recording |
| Release `Shift+R` | Transcribes and types text at cursor |
| No focused text field | Text is still copied to clipboard |

### Logs

```bash
journalctl --user -u whispr-ptt -f
```

### Status

```bash
systemctl --user status whispr-ptt
```

### Change the hotkey

Edit `/usr/local/bin/whispr-ptt` line 16:

```python
HOTKEY = "Ctrl+Alt+Space"   # any key supported by linux-key-listener
```

Then restart: `systemctl --user restart whispr-ptt`

---

## Uninstall

```bash
bash uninstall.sh
```

Removes all binaries, services, udev rules, desktop entries and cache. Optionally removes downloaded models.

---

## Troubleshooting

**Text not typing at cursor**
```bash
# Check ydotoold is running
pgrep ydotoold
# Manually start it
ydotoold &
```

**`/dev/uinput` not accessible**
```bash
sudo modprobe uinput
sudo udevadm trigger /dev/uinput
# Then re-login so input group applies
```

**Whisper server not starting**
```bash
journalctl --user -u whispr-ptt -n 30
```

**Slow transcription**
Switch to `tiny.en` model — it runs in ~100 ms on any CPU.

---

## Credits

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — fast on-device Whisper inference
- [OpenWhispr](https://github.com/OpenWhispr/openwhispr) — ships `whisper-server` and `linux-key-listener` binaries used here
- [ydotool](https://github.com/ReimuNotMoe/ydotool) — Wayland-compatible input injection

---

## License

MIT
