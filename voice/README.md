# Nix voice

A cloned-Cate-Blanchett voice with a curated phrase cache and a network of
event-driven triggers that fire phrases when meaningful things happen.

## Layout

```
~/.nix/voice/
├── manifest.json          single source of truth for phrases + metadata
├── refs/                  reference clips for cloning
│   ├── cate-source-*.wav  raw downloaded source audio
│   └── cate-v2.wav        active reference (raw, no EQ)
├── cache/                 baked output wavs (HA-friendly: 22050/mono/16-bit)
│   ├── kind/              soft default register
│   ├── sharp/             dry / snark / frustration register
│   └── warm/              celebration / sympathy / humor register
├── bake.py                phrase baker (XTTS v2 + carrier extraction)
├── iter.py                iteration sandbox for tuning
├── .venv/                 isolated python env (coqui-tts, faster-whisper)
└── .* state files         per-trigger state (see below)
```

## Trigger map

| Trigger                          | Phrase         | Mechanism                                |
| -------------------------------- | -------------- | ---------------------------------------- |
| Claude turn ends                 | `your-move`    | `~/.claude/settings.json` Stop hook      |
| Claude turn ends 1am-4am (1×/day)| `figures`      | `nix-voice-stop` time wrapper            |
| Claude session start, >4h gap    | `welcome-home` | SessionStart hook                        |
| First interactive shell of day   | `welcome-home` | `~/.nix/bash/voice-greeting.sh`          |
| Git commit                       | `shipped`      | `~/.nix/git-hooks/post-commit`           |
| Git commit, first of day         | `there-it-is`  | post-commit (date-gated)                 |
| Git push to main/master          | `there-it-is`  | `~/.nix/git-hooks/pre-push`              |
| Git push --force                 | `yikes`        | pre-push (non-ancestor detection)        |
| Failed systemd units increased   | `yikes`        | `nix-voice-system-check` (5min timer)    |
| Failed systemd unit recovered    | `clean`        | system-check                             |
| Disk / >90%                      | `yikes`        | system-check                             |
| Disk /home >90%                  | `yikes`        | system-check                             |
| Battery <10% on AC unplugged     | `oh-no`        | system-check                             |
| Load5 crosses ncpu*1.5           | `easy`         | system-check                             |
| CPU thermal zone crosses 80°C    | `yikes`        | system-check                             |
| Boot-time errors >5 (post-boot)  | `yikes`        | system-check (uptime detection)          |
| Resume from suspend              | `welcome-home` | `nix-voice-sleep-watch` (logind dbus)    |
| Shutdown/reboot signaled         | `noted`        | `nix-voice-shutdown-watch` (logind dbus) |
| Screen lock                      | `noted`        | `nix-voice-lock-watch` (ScreenSaver dbus)|
| Screen unlock                    | `mm-hm`        | lock-watch                               |
| Network connectivity → none      | `figures`      | `nix-voice-network-watch` (nmcli)        |
| Network connectivity → full      | `clean`        | network-watch                            |
| OOM kill in journal              | `oh-no`        | `nix-voice-oom-watch` (journalctl)       |
| Crit/alert/emerg journal entry   | `oh-no`        | `nix-voice-crit-watch` (debounced 30s)   |
| Display hotplug (debounced 5s)   | `mm-hm`        | `nix-voice-display-watch` (udev)         |
| `nix-rollback undo` succeeds     | `oh-no`        | nix-rollback in-process                  |
| `nix-rollback to <N>` succeeds   | `oh-no`        | nix-rollback in-process                  |

**Total: 27 fire conditions across 14 mechanisms.**

Every trigger is **edge-based** — fires only on transitions, never on
persistent state. The system-check timer runs every 5 minutes and
maintains a single state file (`.system-check-state`) keyed by signal
name; daemons hold transition state in memory and reset on restart.

## State files

| File                        | Owner                    | Purpose                              |
| --------------------------- | ------------------------ | ------------------------------------ |
| `.system-check-state`       | system-check timer       | last seen values for all polled signals |
| `.last-session`             | SessionStart hook        | last Claude session start (epoch)    |
| `.last-shell-day`           | bashrc voice-greeting    | last calendar day a shell greeted    |
| `.last-commit-day`          | post-commit hook         | last calendar day of a commit        |
| `.last-late-night`          | nix-voice-stop           | last night a 1am-4am figures fired   |
| `.last-boot-uptime`         | system-check timer       | last seen kernel uptime (boot detection) |

Daemons (network, oom, crit, display, lock, sleep, shutdown) hold
state in memory only — restart resets to neutral.

## Disabling individual triggers

Each user systemd unit can be disabled independently:

```bash
systemctl --user disable --now nix-voice-<name>.service
```

For polled signals in system-check, edit `~/.nix/bin/nix-voice-system-check`
and comment out the relevant block. For hook-based fires, edit the
hook file directly (`~/.nix/git-hooks/*` or `~/.claude/settings.json`).

## Adding new phrases

1. Add an entry to `manifest.json` with `key`, `text`, `mood`, `category`, `when`, `wav: null`.
2. For phrases ≤4 syllables, add a `carrier` field with a longer sentence
   that contains the target words — XTTS struggles with very short utterances.
3. Run `~/.nix/voice/.venv/bin/python ~/.nix/voice/bake.py --only <key>`.
4. The bake script handles carrier-extraction (via faster-whisper word
   timestamps), silence trim, and resampling to manifest target format.

Phrases with `text: null` are **harvested**, not synthesized — the wav
on disk is the authoritative source. The sigh is the canonical example
(extracted from an XTTS hallucination during round 3 baking).
