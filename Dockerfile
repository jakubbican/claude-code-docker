#===============================================================================
# Dockerfile pro Claude Code Development Environment
#===============================================================================
# ARM64 kompatibilní obraz pro RPI 5
# Obsahuje: Node.js, Git, Claude Code, Playwright, Firewall whitelist
#===============================================================================

FROM node:20-bookworm

# Metadata
LABEL maintainer="your-email@example.com"
LABEL description="Claude Code development environment for RPI 5 with firewall isolation"

# Nastavení prostředí
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=development

# Playwright - nastavení pro headless prohlížeče
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0

# Claude config directory (bude mountováno jako volume)
ENV CLAUDE_CONFIG_DIR=/home/node/.claude

#-------------------------------------------------------------------------------
# 1. Systémové závislosti
#-------------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    # Základní nástroje
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    tree \
    jq \
    zip \
    unzip \
    # TMUX - pro persistentní sessions (odpojení/připojení k běžícímu Claude)
    tmux \
    # Build nástroje (pro nativní npm moduly)
    build-essential \
    python3 \
    # FIREWALL - iptables pro síťovou izolaci
    iptables \
    iproute2 \
    dnsutils \
    # Playwright závislosti (pro headless Chrome/Chromium)
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    libgtk-3-0 \
    # Fonty pro správné renderování
    fonts-liberation \
    fonts-noto-color-emoji \
    # Utility
    procps \
    locales \
    sudo \
    && rm -rf /var/lib/apt/lists/* \
    #---------------------------------------------------------------------------
    # GitHub CLI (gh) - instalace z oficiálního repozitáře
    #---------------------------------------------------------------------------
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

#-------------------------------------------------------------------------------
# 2. Nastavení locale (čeština)
#-------------------------------------------------------------------------------
RUN sed -i '/cs_CZ.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=cs_CZ.UTF-8
ENV LC_ALL=cs_CZ.UTF-8

#-------------------------------------------------------------------------------
# 3. Konfigurace uživatele (ne root pro bezpečnost)
#-------------------------------------------------------------------------------
# V node:20-bookworm image už existuje user "node" s UID/GID 1000
# Použijeme ho místo vytváření nového uživatele
ARG USERNAME=node

# Přidáme sudo práva pro uživatele node
RUN echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

#-------------------------------------------------------------------------------
# 4. Firewall script
#-------------------------------------------------------------------------------
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" >> /etc/sudoers.d/node

#-------------------------------------------------------------------------------
# 5. Startup script (firewall + validace)
#-------------------------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

#-------------------------------------------------------------------------------
# 6. Globální npm nástroje
#-------------------------------------------------------------------------------
RUN mkdir -p /home/node/.npm-global && \
    chown -R node:node /home/node/.npm-global

ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=/home/node/.npm-global/bin:$PATH

#-------------------------------------------------------------------------------
# 7. Claude config adresář (bude volume)
#-------------------------------------------------------------------------------
RUN mkdir -p /home/node/.claude && \
    chown -R node:node /home/node/.claude

#-------------------------------------------------------------------------------
# 8. Přepnutí na uživatele
#-------------------------------------------------------------------------------
USER node
WORKDIR /home/node

#-------------------------------------------------------------------------------
# 9. Příprava adresářů pro uživatele node
#-------------------------------------------------------------------------------
# Vytvoř .config a .local adresáře před instalací nástrojů
USER root
RUN mkdir -p /home/node/.config /home/node/.local/bin && \
    chown -R node:node /home/node/.config /home/node/.local
USER node

#-------------------------------------------------------------------------------
# 10. Instalace Claude Code (nativní binárka)
#-------------------------------------------------------------------------------
# NPM metoda je deprecated, používáme nativní instalaci
# https://code.claude.com/docs/en/setup
RUN curl -fsSL https://claude.ai/install.sh | bash -s latest

#-------------------------------------------------------------------------------
# 11. Instalace uv (rychlý Python package manager)
#-------------------------------------------------------------------------------
# https://docs.astral.sh/uv/
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Přidej do PATH (.local/bin pro Claude Code i uv)
ENV PATH=/home/node/.local/bin:$PATH

# Instalace specify-cli (GitHub spec-kit)
# https://github.com/github/spec-kit
RUN uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

#-------------------------------------------------------------------------------
# 12. Instalace devtui (all-in-one terminal toolkit)
#-------------------------------------------------------------------------------
# https://github.com/skatkov/devtui
USER root
RUN DEVTUI_VERSION="0.34.0" && \
    curl -fsSL "https://github.com/skatkov/devtui/releases/download/v${DEVTUI_VERSION}/devtui_Linux_arm64.tar.gz" -o /tmp/devtui.tar.gz && \
    tar -xzf /tmp/devtui.tar.gz -C /tmp && \
    mv /tmp/devtui /usr/local/bin/devtui && \
    chmod +x /usr/local/bin/devtui && \
    rm -rf /tmp/devtui.tar.gz /tmp/LICENSE /tmp/README.md
USER node

#-------------------------------------------------------------------------------
# 13. Instalace Playwright (globálně + prohlížeče)
#-------------------------------------------------------------------------------
USER root
RUN mkdir -p /opt/playwright-browsers && chown -R node:node /opt/playwright-browsers
USER node

RUN npm install -g playwright && \
    npx playwright install chromium

#-------------------------------------------------------------------------------
# 14. Instalace Gemini CLI (Google AI agent pro terminál)
#-------------------------------------------------------------------------------
# https://github.com/google-gemini/gemini-cli
RUN npm install -g @google/gemini-cli

#-------------------------------------------------------------------------------
# 15. Konfigurace Gitu
#-------------------------------------------------------------------------------
RUN git config --global init.defaultBranch main && \
    git config --global core.editor "vim" && \
    git config --global pull.rebase false

#-------------------------------------------------------------------------------
# 16. Pracovní adresář pro projekty
#-------------------------------------------------------------------------------
WORKDIR /workspace

#-------------------------------------------------------------------------------
# 17. Výchozí příkaz - entrypoint s firewall inicializací
#-------------------------------------------------------------------------------
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
