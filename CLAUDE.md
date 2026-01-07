# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker-based isolated development environment for running Claude Code on Raspberry Pi 5 with firewall whitelisting for security.

See `README.md` for setup instructions and `DOCKER-GUIDE.md` for detailed Docker operations.

## Architecture

```
Host (RPI 5)
├── ~/projects/              → Mounted as /workspace in container
└── ~/claude-code-docker/    → This repo (Docker config)

Container (claude-code-dev)         ← Main instance (firewall ON)
├── Node.js 20, Claude Code, Playwright
├── iptables firewall (whitelist-only outbound)
└── Volumes: claude-config, npm-cache, playwright-cache

Container (claude-code-research)    ← Research instance (firewall OFF)
├── Same setup, no firewall
└── Shares volumes with main instance
```

## Quick Reference

```bash
# Build/start
docker compose up -d --build

# Connect to container
docker compose exec dev bash

# Inside container - run Claude
claude
claude --dangerously-skip-permissions  # autonomous mode (firewall-protected)

# Reset (preserves credentials)
docker compose down && docker compose up -d

# Hard reset (clears everything)
docker compose down -v && docker compose up -d --build

# Research instance (no firewall, unrestricted internet)
docker compose -f docker-compose.research.yml up -d
docker compose -f docker-compose.research.yml exec research bash
docker compose -f docker-compose.research.yml down
```

## File Purposes

| File | Purpose |
|------|---------|
| `Dockerfile` | Container image definition |
| `docker-compose.yml` | Service config, volumes, ports, env vars |
| `docker-compose.research.yml` | Research instance without firewall |
| `init-firewall.sh` | Whitelist rules - edit `ALLOWED_DOMAINS` to add domains |
| `entrypoint.sh` | Startup script (firewall init + validation) |
| `setup-host.sh` | One-time RPI host preparation |

## Firewall

Outbound traffic is restricted to whitelisted domains only (Anthropic API, npm, GitHub, Playwright). LAN traffic is unrestricted.

To add a domain: edit `ALLOWED_DOMAINS` in `init-firewall.sh`, then rebuild container.

## Repo
Store project here: https://github.com/jakubbican/claude-code-docker

commit often, do not hesitate to push changes to github repo

ask to label before/after major improvements or changes
