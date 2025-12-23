#!/bin/bash
#===============================================================================
# RPI 5 Host Setup Script pro Claude Code Development Environment
#===============================================================================
# Spusť tento skript jednou na čerstvém Raspbian OS:
#   chmod +x setup-host.sh
#   ./setup-host.sh
#===============================================================================

set -e  # Zastav při chybě

# Barvy pro výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RPI 5 Setup pro Claude Code          ${NC}"
echo -e "${GREEN}========================================${NC}"

#-------------------------------------------------------------------------------
# 1. Aktualizace systému
#-------------------------------------------------------------------------------
echo -e "\n${YELLOW}[1/6] Aktualizace systému...${NC}"
sudo apt update && sudo apt upgrade -y

#-------------------------------------------------------------------------------
# 2. Instalace základních nástrojů
#-------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/6] Instalace základních nástrojů...${NC}"
sudo apt install -y \
    git \
    curl \
    wget \
    htop \
    tree \
    jq \
    ca-certificates \
    gnupg \
    lsb-release

#-------------------------------------------------------------------------------
# 3. Instalace Dockeru (oficiální způsob pro ARM64)
#-------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/6] Instalace Dockeru...${NC}"

# Přidání Docker GPG klíče
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Přidání Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalace Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Přidání uživatele do docker skupiny (aby nebylo potřeba sudo)
sudo usermod -aG docker $USER

#-------------------------------------------------------------------------------
# 4. Vytvoření adresářové struktury
#-------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/6] Vytvoření adresářové struktury...${NC}"

# Hlavní složka pro projekty (PŘEŽIJE reset kontejneru)
mkdir -p ~/projects

# Složka pro Docker konfiguraci
mkdir -p ~/claude-code-docker

# Složka pro sdílené volume (node_modules cache apod.)
mkdir -p ~/claude-code-docker/volumes/npm-cache
mkdir -p ~/claude-code-docker/volumes/playwright-cache

echo -e "${GREEN}Vytvořeno:${NC}"
echo "  ~/projects/                  - tvoje projekty (git repos)"
echo "  ~/claude-code-docker/        - Docker konfigurace"
echo "  ~/claude-code-docker/volumes - persistentní cache"

#-------------------------------------------------------------------------------
# 5. Konfigurace SSH (volitelné ale doporučené)
#-------------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/6] Konfigurace SSH...${NC}"

# Povolení SSH pokud není
sudo systemctl enable ssh
sudo systemctl start ssh

# Získání IP adresy
IP_ADDR=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}SSH je aktivní.${NC}"
echo -e "Připoj se z laptopu pomocí: ${YELLOW}ssh $USER@$IP_ADDR${NC}"
echo -e "Nebo pomocí hostname:       ${YELLOW}ssh $USER@$(hostname).local${NC}"

#-------------------------------------------------------------------------------
# 6. Nastavení hostname (volitelné)
#-------------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/6] Kontrola hostname...${NC}"
CURRENT_HOSTNAME=$(hostname)
echo -e "Aktuální hostname: ${GREEN}$CURRENT_HOSTNAME${NC}"
echo -e "Pro změnu použij: ${YELLOW}sudo raspi-config${NC} → System Options → Hostname"

#-------------------------------------------------------------------------------
# Hotovo!
#-------------------------------------------------------------------------------
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup dokončen!                       ${NC}"
echo -e "${GREEN}========================================${NC}"

# Přidání užitečných aliasů do .bashrc
echo -e "\n${YELLOW}[BONUS]${NC} Přidávám užitečné aliasy do ~/.bashrc..."

cat >> ~/.bashrc << 'EOF'

# Claude Code Docker aliases
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dce='docker compose exec dev bash'
alias dcl='docker compose logs -f'

# Tmux alias - připojí se k existující session nebo vytvoří novou
alias claude-session='cd ~/claude-code-docker && docker compose exec dev tmux attach -t claude 2>/dev/null || docker compose exec dev tmux new -s claude'
EOF

source ~/.bashrc 2>/dev/null || true

echo -e "${GREEN}Aliasy přidány:${NC}"
echo "  dc, dcu, dcd, dce, dcl - Docker Compose zkratky"
echo "  claude-session - Připojení k Claude Code v tmux"

echo -e "\n${YELLOW}DŮLEŽITÉ: Odhlás se a znovu přihlas (nebo restartuj),${NC}"
echo -e "${YELLOW}aby se projevilo přidání do docker skupiny!${NC}"
echo -e "\nPo restartu ověř Docker příkazem:"
echo -e "  ${YELLOW}docker run hello-world${NC}"

echo -e "\n${GREEN}Další kroky:${NC}"
echo -e "1. Zkopíruj Dockerfile a docker-compose.yml do ~/claude-code-docker/"
echo -e "2. Spusť: cd ~/claude-code-docker && docker compose up -d --build"
echo -e "3. Připoj se do kontejneru: docker compose exec dev bash"

echo -e "\n${GREEN}IP adresa pro připojení z laptopů: ${YELLOW}$IP_ADDR${NC}"
