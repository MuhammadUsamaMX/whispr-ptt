# whispr-ptt

Push-to-talk speech-to-text for Arch Linux.

Hold Shift+R to record, release to transcribe, and text is typed at the cursor.

This project now runs directly with `pywhispercpp` and does not depend on OpenWhispr.

## How it works

```
Hold Shift+R -> pw-record captures mic -> pywhispercpp transcribes
-> ydotool types text at cursor -> wl-copy keeps clipboard fallback
```

- Key listener: `python-evdev` on physical keyboard devices only
- Audio: PipeWire `pw-record` at 16 kHz mono
- Transcription: `pywhispercpp`
- Typing: `ydotool type`
- Notifications: `notify-send`
- Daemon: `systemd --user` service

## Requirements

- Arch Linux (or Arch-based)
- Wayland desktop session
- PipeWire

## Install

```bash
git clone https://github.com/MuhammadUsamaMX/whispr-ptt.git
cd whispr-ptt
bash install.sh
```

The installer will:

1. Install required packages (`python-evdev`, `ydotool`, `wl-clipboard`, `libnotify`, etc.)
2. Ask you to select a Whisper model
3. Install `whispr-ptt` to `/usr/local/bin/whispr-ptt`
4. Enable `ydotoold.service` and `whispr-ptt.service`

After install, re-login once so `input` group changes apply.

## Model selection

Models are stored in `/usr/local/share/whispr`.

- `tiny.en`: fastest, English only
- `base.en`: better quality, English only
- `large-v3-turbo`: best quality, multilingual, much heavier

## Service commands

```bash
systemctl --user status whispr-ptt
systemctl --user restart whispr-ptt
journalctl --user -u whispr-ptt -f
```

## Full OpenWhispr removal

If OpenWhispr popups still appear (for example "start recording" prompts), remove old OpenWhispr artifacts completely:

```bash
pkill -f 'OpenWhispr.AppImage|openwhispr|open-whispr' 2>/dev/null || true
sudo rm -f /usr/local/bin/OpenWhispr.AppImage /usr/local/bin/whispr
rm -f ~/.local/share/applications/*open*whispr*.desktop
rm -f ~/.config/autostart/*open*whispr*.desktop
sudo rm -f /usr/share/applications/*open*whispr*.desktop
sudo rm -f /usr/local/share/applications/*open*whispr*.desktop
```

Then verify nothing is left:

```bash
systemctl --user list-units --all --no-pager | rg -i 'openwhispr|open-whispr' || true
pgrep -af 'OpenWhispr.AppImage|openwhispr|open-whispr' || true
```

## Uninstall whispr-ptt

```bash
bash uninstall.sh
```

## License

MIT
