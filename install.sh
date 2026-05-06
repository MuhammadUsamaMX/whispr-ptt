#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
#  whispr-ptt installer for Arch Linux
#  Standalone — no external apps required
#  Hold Shift+R → speak → release → text typed at cursor
# ─────────────────────────────────────────────────────────────────────────────

MODELS_DIR="/usr/local/share/whispr"
BIN_DIR="/usr/local/bin"

# Available models (name : HuggingFace URL : size)
declare -A MODEL_URLS=(
  [tiny.en]="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin"
  [base.en]="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
  [large-v3-turbo]="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }
heading() { echo -e "\n${CYAN}══ $* ══${NC}"; }

# ── Check Arch ────────────────────────────────────────────────────────────────
[[ -f /etc/arch-release ]] || error "This installer is for Arch Linux only."

heading "Installing system dependencies"
sudo pacman -S --noconfirm --needed \
  python python-evdev ydotool wl-clipboard \
  pipewire pipewire-pulse \
  vulkan-radeon vulkan-icd-loader 2>&1 | grep -E "installing|already installed|error" || true
info "System dependencies installed"

heading "Installing pywhispercpp (whisper.cpp Python bindings)"
if python3 -c "import pywhispercpp" 2>/dev/null; then
  info "pywhispercpp already installed"
else
  sudo pip install pywhispercpp --break-system-packages --quiet
  info "pywhispercpp installed"
fi

# ── uinput kernel module ──────────────────────────────────────────────────────
heading "Configuring uinput"
echo "uinput" | sudo tee /etc/modules-load.d/uinput.conf > /dev/null
sudo modprobe uinput 2>/dev/null || true
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", TAG+="uaccess"' \
  | sudo tee /etc/udev/rules.d/70-uinput.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger /dev/uinput 2>/dev/null || true
sudo usermod -aG input "$USER"
info "uinput configured (re-login needed for group change)"

# ── Pick whisper model ────────────────────────────────────────────────────────
heading "Select Whisper model"
echo ""
echo "  1) tiny.en       ~75 MB   ← fastest, English only, ~100ms transcription"
echo "  2) base.en       ~140 MB  ← good balance, English only, ~300ms"
echo "  3) large-v3-turbo ~1.5 GB ← heaviest, multilingual, best accuracy (needs GPU)"
echo ""
read -rp "Choose model [1/2/3] (default: 1): " MODEL_CHOICE
case "${MODEL_CHOICE:-1}" in
  2) MODEL_KEY="base.en" ;;
  3) MODEL_KEY="large-v3-turbo" ;;
  *) MODEL_KEY="tiny.en" ;;
esac

sudo mkdir -p "$MODELS_DIR"
MODEL_FILE="$MODELS_DIR/ggml-${MODEL_KEY}.bin"
if [[ ! -f "$MODEL_FILE" ]]; then
  info "Downloading ggml-${MODEL_KEY}.bin ..."
  sudo curl -L --progress-bar "${MODEL_URLS[$MODEL_KEY]}" -o "$MODEL_FILE"
else
  info "Model ggml-${MODEL_KEY}.bin already present"
fi

# ── Install whispr-ptt daemon ─────────────────────────────────────────────────
heading "Installing whispr-ptt"
sudo cp "$(dirname "$0")/whispr-ptt" "$BIN_DIR/whispr-ptt"
sudo chmod +x "$BIN_DIR/whispr-ptt"
# Patch model path in the installed script
sudo sed -i "s|^MODEL  = .*|MODEL  = \"${MODEL_FILE}\"|" "$BIN_DIR/whispr-ptt"
info "whispr-ptt installed to $BIN_DIR/whispr-ptt"

# ── Set GGML_VULKAN globally ──────────────────────────────────────────────────
grep -q "GGML_VULKAN" ~/.bashrc  || echo 'export GGML_VULKAN=1' >> ~/.bashrc
[[ -f ~/.zshrc ]] && { grep -q "GGML_VULKAN" ~/.zshrc || echo 'export GGML_VULKAN=1' >> ~/.zshrc; }

# ── ydotoold user service ─────────────────────────────────────────────────────
heading "Enabling ydotoold service"
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/ydotoold.service << 'EOF'
[Unit]
Description=ydotoold daemon
After=default.target

[Service]
ExecStart=/usr/bin/ydotoold
Restart=on-failure

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now ydotoold.service 2>/dev/null || true
info "ydotoold service enabled"

# ── whispr-ptt user service ───────────────────────────────────────────────────
heading "Enabling whispr-ptt service"
cat > ~/.config/systemd/user/whispr-ptt.service << EOF
[Unit]
Description=whispr-ptt push-to-talk daemon (Shift+R)
After=graphical-session.target pipewire.service ydotoold.service
Wants=ydotoold.service

[Service]
ExecStart=/usr/local/bin/whispr-ptt
Restart=on-failure
RestartSec=3
Environment=GGML_VULKAN=1

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now whispr-ptt.service
info "whispr-ptt service started"

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  whispr-ptt installed successfully!        ${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "  Hold  Shift+R  → speak → release → text typed at cursor"
echo "  Text also copied to clipboard as fallback."
echo ""
warn "Re-login (or run: newgrp input) for input group to take effect."
echo ""
echo "  View logs:   journalctl --user -u whispr-ptt -f"
echo "  Status:      systemctl --user status whispr-ptt"
echo "  Uninstall:   bash uninstall.sh"
echo ""
