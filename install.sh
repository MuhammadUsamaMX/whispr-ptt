#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
#  whispr-ptt installer for Arch Linux
#  Hold Shift+R → speak → release → text typed at cursor
# ─────────────────────────────────────────────────────────────────────────────

REPO="https://github.com/MuhammadUsamaMX/whispr-ptt"
OPENWHISPR_VER="1.7.0"
OPENWHISPR_URL="https://github.com/OpenWhispr/openwhispr/releases/download/v${OPENWHISPR_VER}/OpenWhispr-${OPENWHISPR_VER}-linux-x86_64.AppImage"
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

heading "Installing dependencies"
sudo pacman -S --noconfirm --needed \
  ydotool wl-clipboard pipewire pipewire-pulse curl python \
  vulkan-radeon vulkan-icd-loader 2>&1 | grep -E "installing|already installed|error" || true
info "Dependencies installed"

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

# ── Download OpenWhispr AppImage (for whisper-server & key-listener binaries) ─
heading "Downloading OpenWhispr AppImage"
APPIMAGE_PATH="/usr/local/bin/OpenWhispr.AppImage"
if [[ ! -f "$APPIMAGE_PATH" ]]; then
  sudo curl -L --progress-bar "$OPENWHISPR_URL" -o "$APPIMAGE_PATH"
  sudo chmod +x "$APPIMAGE_PATH"
  info "OpenWhispr AppImage downloaded"
else
  info "OpenWhispr AppImage already present"
fi

# ── Extract binaries from AppImage ───────────────────────────────────────────
heading "Extracting whisper-server and key-listener binaries"
EXTRACT_DIR=$(mktemp -d)
pushd "$EXTRACT_DIR" > /dev/null
"$APPIMAGE_PATH" --appimage-extract > /dev/null 2>&1 &
PID=$!
echo -n "Extracting..."
while kill -0 $PID 2>/dev/null; do echo -n "."; sleep 1; done
echo ""
wait $PID
popd > /dev/null

BIN_SRC="$EXTRACT_DIR/squashfs-root/resources/bin"
sudo cp "$BIN_SRC/whisper-server-linux-x64"  "$BIN_DIR/openwhispr-whisper-server"
sudo cp "$BIN_SRC/linux-key-listener-x64"    "$BIN_DIR/openwhispr-key-listener"
sudo cp "$BIN_SRC/linux-fast-paste"          "$BIN_DIR/openwhispr-fast-paste" 2>/dev/null || true
sudo cp "$BIN_SRC"/libggml*.so*              /usr/local/lib/ 2>/dev/null || true
sudo chmod +x "$BIN_DIR/openwhispr-whisper-server" "$BIN_DIR/openwhispr-key-listener"
sudo ldconfig
rm -rf "$EXTRACT_DIR"
info "Binaries extracted"

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
sudo sed -i "s|MODEL.*=.*\".*\"|MODEL          = \"${MODEL_FILE}\"|" "$BIN_DIR/whispr-ptt"
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

# ── Desktop entry ─────────────────────────────────────────────────────────────
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/openwhispr.desktop << 'EOF'
[Desktop Entry]
Name=OpenWhispr
Exec=env GGML_VULKAN=1 /usr/local/bin/OpenWhispr.AppImage --no-sandbox
Icon=openwhispr
Type=Application
Categories=Utility;AudioVideo;
Comment=AI-powered speech-to-text
StartupNotify=true
EOF
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

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
