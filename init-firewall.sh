#!/bin/bash
#===============================================================================
# Firewall Whitelist pro Claude Code Container
#===============================================================================
# Tento script nastaví iptables pravidla, která povolí pouze:
# - DNS (pro rozlišení doménových jmen)
# - SSH (pro git operace)
# - HTTPS na whitelisted domény (npm, GitHub, Anthropic API, atd.)
#
# Vše ostatní je ZABLOKOVÁNO - Claude Code nemůže komunikovat s neznámými servery
#===============================================================================

set -e

# Barvy pro výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

#-------------------------------------------------------------------------------
# Konfigurace - Povolené domény
#-------------------------------------------------------------------------------
# Přidej další domény podle potřeby (např. pro specifické npm balíčky)
ALLOWED_DOMAINS=(
    # Anthropic API
    "api.anthropic.com"
    "statsig.anthropic.com"
    "sentry.io"
    "claude.ai"

    # Sentry (error reporting)
    "ingest.sentry.io"
    "o19718.ingest.sentry.io"
    "o4504430941937664.ingest.sentry.io"

    # npm registry
    "registry.npmjs.org"
    "npmjs.org"
    "npmjs.com"

    # npm CDNs (used by some packages)
    "unpkg.com"
    "cdn.jsdelivr.net"

    # GitHub
    "github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    "codeload.github.com"
    "github-releases.githubusercontent.com"

    # Pro Playwright (stahování prohlížečů)
    "playwright.azureedge.net"
    "playwright-akamai.azureedge.net"
    "playwright-verizon.azureedge.net"

    # Node.js / npm CDN
    "nodejs.org"
    "registry.yarnpkg.com"

    # VS Code / Cursor Marketplace
    "marketplace.visualstudio.com"
    "gallerycdn.vsassets.io"
    "vscode.blob.core.windows.net"
    "update.code.visualstudio.com"

    # Python / PyPI
    "pypi.org"
    "files.pythonhosted.org"

    # Docker Hub
    "registry-1.docker.io"
    "auth.docker.io"
    "production.cloudflare.docker.com"
)

#-------------------------------------------------------------------------------
# Funkce pro logování
#-------------------------------------------------------------------------------
log_info() {
    echo -e "${GREEN}[FIREWALL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[FIREWALL]${NC} $1"
}

log_error() {
    echo -e "${RED}[FIREWALL]${NC} $1"
}

#-------------------------------------------------------------------------------
# Kontrola, zda běžíme jako root
#-------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    log_error "Tento script musí běžet jako root (sudo)"
    exit 1
fi

#-------------------------------------------------------------------------------
# Kontrola dostupnosti iptables
#-------------------------------------------------------------------------------
if ! command -v iptables &> /dev/null; then
    log_error "iptables není nainstalován"
    exit 1
fi

#-------------------------------------------------------------------------------
# Reset existujících pravidel
#-------------------------------------------------------------------------------
log_info "Resetuji existující iptables pravidla..."

iptables -F OUTPUT 2>/dev/null || true
iptables -F INPUT 2>/dev/null || true

#-------------------------------------------------------------------------------
# Povolení localhost (interní komunikace)
#-------------------------------------------------------------------------------
log_info "Povoluji localhost komunikaci..."

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

#-------------------------------------------------------------------------------
# Povolení established/related spojení (odpovědi na naše požadavky)
#-------------------------------------------------------------------------------
log_info "Povoluji established spojení..."

iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

#-------------------------------------------------------------------------------
# Povolení DNS (UDP a TCP port 53)
#-------------------------------------------------------------------------------
log_info "Povoluji DNS (port 53)..."

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

#-------------------------------------------------------------------------------
# Povolení komunikace po LOKÁLNÍ SÍTI (LAN)
#-------------------------------------------------------------------------------
# DŮVOD: Webový projekt komunikuje s lokálními zařízeními:
#   - WebSockets a HTTP na nestandardních portech (např. 8080)
#   - TCP komunikace s lokálními službami
#   - UDP komunikace včetně broadcastů pro device discovery
# 
# Toto povoluje VEŠKEROU komunikaci na privátních IP rozsazích,
# ale NEPOVOLUJE komunikaci s veřejným internetem mimo whitelist.
#-------------------------------------------------------------------------------
log_info "Povoluji komunikaci po lokální síti (LAN)..."

# Privátní IPv4 rozsahy (RFC 1918)
# 10.0.0.0/8     - Class A private network
# 172.16.0.0/12  - Class B private network  
# 192.168.0.0/16 - Class C private network (nejčastější domácí sítě)

# TCP na lokální síti - všechny porty
iptables -A OUTPUT -p tcp -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -p tcp -d 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -p tcp -d 192.168.0.0/16 -j ACCEPT
log_info "  ✓ TCP na privátních IP rozsazích"

# UDP na lokální síti - všechny porty
iptables -A OUTPUT -p udp -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -p udp -d 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -p udp -d 192.168.0.0/16 -j ACCEPT
log_info "  ✓ UDP na privátních IP rozsazích"

# UDP Broadcast - pro device discovery a podobné protokoly
# 255.255.255.255 - limited broadcast (všechny sítě)
# x.x.x.255 - directed broadcast (konkrétní subnet) - pokryto výše přes /16, /12, /8
iptables -A OUTPUT -p udp -d 255.255.255.255 -j ACCEPT
log_info "  ✓ UDP broadcast (255.255.255.255)"

# Link-local adresy (169.254.0.0/16) - pro mDNS, LLMNR, apod.
iptables -A OUTPUT -p udp -d 169.254.0.0/16 -j ACCEPT
iptables -A OUTPUT -p tcp -d 169.254.0.0/16 -j ACCEPT
log_info "  ✓ Link-local adresy (169.254.0.0/16)"

# Multicast adresy (224.0.0.0/4) - pro mDNS (224.0.0.251), SSDP, apod.
iptables -A OUTPUT -p udp -d 224.0.0.0/4 -j ACCEPT
log_info "  ✓ Multicast (224.0.0.0/4)"

#-------------------------------------------------------------------------------
# Povolení SSH (port 22) - pro git operace
#-------------------------------------------------------------------------------
log_info "Povoluji SSH (port 22)..."

iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

#-------------------------------------------------------------------------------
# Povolení HTTPS (port 443) na whitelisted domény
#-------------------------------------------------------------------------------
log_info "Povoluji HTTPS na whitelisted domény..."

for domain in "${ALLOWED_DOMAINS[@]}"; do
    # Resolve domain to IP addresses
    if ips=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u); then
        for ip in $ips; do
            if [ -n "$ip" ]; then
                iptables -A OUTPUT -p tcp --dport 443 -d "$ip" -j ACCEPT
                log_info "  ✓ $domain → $ip"
            fi
        done
    else
        log_warn "  ✗ Nelze resolvovat: $domain (přeskakuji)"
    fi
done

#-------------------------------------------------------------------------------
# Povolení HTTP (port 80) - některé registry ho používají pro redirect
#-------------------------------------------------------------------------------
log_info "Povoluji HTTP (port 80) na whitelisted domény..."

for domain in "${ALLOWED_DOMAINS[@]}"; do
    if ips=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u); then
        for ip in $ips; do
            if [ -n "$ip" ]; then
                iptables -A OUTPUT -p tcp --dport 80 -d "$ip" -j ACCEPT
            fi
        done
    fi
done

#-------------------------------------------------------------------------------
# Blokování všeho ostatního (default deny pro OUTPUT)
#-------------------------------------------------------------------------------
log_info "Nastavuji default DENY pro odchozí spojení..."

iptables -A OUTPUT -j DROP

#-------------------------------------------------------------------------------
# Validace - test že pravidla fungují
#-------------------------------------------------------------------------------
log_info "Validuji firewall pravidla..."

# Test 1: DNS by měl fungovat
if getent hosts github.com &>/dev/null; then
    log_info "  ✓ DNS funguje"
else
    log_error "  ✗ DNS nefunguje!"
    exit 1
fi

# Test 2: Whitelisted doména by měla být dostupná
if curl -s --connect-timeout 5 -o /dev/null https://api.anthropic.com 2>/dev/null || \
   curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" https://registry.npmjs.org 2>/dev/null | grep -q "200\|301\|302"; then
    log_info "  ✓ Whitelisted domény dostupné"
else
    log_warn "  ⚠ Nelze ověřit dostupnost (může být OK)"
fi

#-------------------------------------------------------------------------------
# Výpis aktivních pravidel
#-------------------------------------------------------------------------------
log_info "Aktivní OUTPUT pravidla:"
iptables -L OUTPUT -n --line-numbers | head -20

#-------------------------------------------------------------------------------
# Hotovo
#-------------------------------------------------------------------------------
echo ""
log_info "========================================="
log_info "  Firewall úspěšně nakonfigurován!"
log_info "========================================="
log_info ""
log_info "POVOLENO:"
log_info "  Lokální síť (LAN):"
echo "    - 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16"
echo "    - UDP broadcast, multicast"
echo "    - Všechny porty (TCP/UDP)"
log_info ""
log_info "  Internet (pouze whitelist):"
for domain in "${ALLOWED_DOMAINS[@]}"; do
    echo "    - $domain"
done
log_info ""
log_info "BLOKOVÁNO:"
echo "    - Vše ostatní na internetu"
log_info "========================================="
