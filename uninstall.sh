#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }

echo -e "${RED}════════════════════════════════════════════${NC}"
echo -e "${RED}  Uninstalling whispr-ptt                   ${NC}"
echo -e "${RED}════════════════════════════════════════════${NC}"
echo ""

# Stop and disable services
systemctl --user stop    whispr-ptt.service  2>/dev/null && info "Stopped whispr-ptt service"     || true
systemctl --user disable whispr-ptt.service  2>/dev/null && info "Disabled whispr-ptt service"    || true
systemctl --user stop    ydotoold.service    2>/dev/null && info "Stopped ydotoold service"       || true
systemctl --user disable ydotoold.service    2>/dev/null && info "Disabled ydotoold service"      || true

# Remove service files
rm -f ~/.config/systemd/user/whispr-ptt.service
rm -f ~/.config/systemd/user/ydotoold.service
systemctl --user daemon-reload
info "Removed service files"

# Remove binaries
sudo rm -f /usr/local/bin/whispr-ptt
info "Removed binaries"

# Remove models (ask first)
if [[ -d /usr/local/share/whispr ]]; then
  read -rp "Remove downloaded models in /usr/local/share/whispr? [y/N]: " RM_MODELS
  if [[ "${RM_MODELS,,}" == "y" ]]; then
    sudo rm -rf /usr/local/share/whispr
    info "Removed models"
  else
    warn "Models kept at /usr/local/share/whispr"
  fi
fi

# Remove udev rule and module config
sudo rm -f /etc/udev/rules.d/70-uinput.rules
sudo rm -f /etc/modules-load.d/uinput.conf
sudo udevadm control --reload-rules 2>/dev/null || true
info "Removed udev rules"

# Remove desktop entry and autostart
rm -f ~/.local/share/applications/whispr-ptt.desktop
rm -f ~/.config/autostart/whispr-ptt.desktop
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
info "Removed desktop entries"

# Remove leftover OpenWhispr artifacts that can still trigger prompts/popups
pkill -f 'OpenWhispr.AppImage|openwhispr|open-whispr' 2>/dev/null || true
systemctl --user stop app-gnome-openwhispr-25064.scope app-gnome-openwhispr-60166.scope \
                    app-open-whispr-25064.scope app-open-whispr-60166.scope 2>/dev/null || true
sudo rm -f /usr/local/bin/OpenWhispr.AppImage /usr/local/bin/whispr
rm -f ~/.local/share/applications/*open*whispr*.desktop 2>/dev/null || true
rm -f ~/.config/autostart/*open*whispr*.desktop 2>/dev/null || true
sudo rm -f /usr/share/applications/*open*whispr*.desktop 2>/dev/null || true
sudo rm -f /usr/local/share/applications/*open*whispr*.desktop 2>/dev/null || true
info "Removed leftover OpenWhispr artifacts"

# Remove cache
rm -rf ~/.cache/whispr-ptt
info "Removed cache"

# Remove GGML_VULKAN from shell configs
sed -i '/export GGML_VULKAN/d' ~/.bashrc  2>/dev/null || true
sed -i '/export GGML_VULKAN/d' ~/.zshrc   2>/dev/null || true
info "Cleaned shell config"

echo ""
info "whispr-ptt fully uninstalled."
warn "The 'input' group membership remains — remove manually if desired: sudo gpasswd -d $USER input"
echo ""
