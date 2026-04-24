# Nix

An AI-native desktop layer for Linux. openSUSE Tumbleweed + KDE Plasma + Claude Code, configured with intent.

This is mine. I publish it in case any of it is useful to you. None of it is general-purpose.

## What it is

A set of configs, scripts, and assets that turn a clean openSUSE Tumbleweed install into the desktop I want to work in. Aesthetic, tooling, voice integration, and an opinionated relationship with Claude Code. The aesthetic philosophy lives in [`identity.md`](identity.md) — read that first if you want to understand the choices.

## What's in here

| Path | What it is |
|---|---|
| `bootstrap.sh` | Initial install — run on a clean openSUSE box to get the rest |
| `nix-shell.sh` | The wrapper script that ties everything together |
| `identity.md` | Aesthetic constitution — the reason behind every decision |
| `bash/` | Shell config, aliases, prompt |
| `bin/` | User-space binaries the layer depends on |
| `docs/tools.md` | What tools I run and why |
| `voice/` | Voice integration (mic → text → action) |
| `wallpapers/` | Curated set, not a dump |
| `man/` | Man pages for local binaries |
| `git-hooks/` | Hooks worth installing globally |
| `external/` | Pinned third-party dependencies |

## Install

Targets openSUSE Tumbleweed + KDE Plasma. Won't work on Ubuntu or Fedora without surgery.

```bash
git clone https://github.com/adamjboyce/nixtop-public.git
cd nixtop-public
./bootstrap.sh
```
