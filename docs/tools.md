# Nix Tools Reference

Detailed reference for the tools wired into this machine. CLAUDE.md has the behavioral triggers; this file has the flags, verbs, and implementation details. Read it when you need the specifics, not every session.

---

## Ambient Context — `~/.nix/ctx/latest/`

When Adam hits F12, `nix-capture-context` freezes his screen into `~/.nix/ctx/latest/`:

| File | What |
|------|------|
| `screen.png` | Full-screen screenshot |
| `clipboard.txt` | Ctrl+C clipboard |
| `selection.txt` | Primary selection (highlighted text) |
| `window.txt` | Active window title, class, geometry |
| `meta.txt` | Timestamp, host, cwd, shell pid |
| `INDEX.md` | Human-readable index |

**Precedence:** `selection.txt` (most specific) → `clipboard.txt` → `screen.png` → `window.txt`. Fall through if empty or irrelevant.

**Staleness:** Check `meta.txt` timestamp. If >5 minutes old during an active conversation, ask Adam to re-summon rather than answering from stale context.

---

## Notifications — `~/.nix/bin/nix-notifications`

Background service (`nix-notify-watcher`, systemd user unit) observes freedesktop notifications via `dbus-monitor`, appends JSONL to `~/.nix/ctx/notifications.jsonl`. Format: `{ts, app, icon, summary, body}`. Plasma popups unaffected.

**CLI:**
- `nix-notifications 50` — last 50, palette-formatted
- `nix-notifications --app discord` — filter by app (substring, case-insensitive)
- `nix-notifications --since 1h` — time window (s|m|h|d)
- Direct `Read` of `~/.nix/ctx/notifications.jsonl` for structured access

**Shell:** `nix :notif [N]` / `nix :notifications [flags]`

---

## Semantic Memory — `~/.nix/bin/nix-memory`

Sentence embeddings (all-MiniLM-L6-v2, 384-dim) in SQLite + sqlite-vec. Markdown stays source of truth; DB at `~/.nix/memory/nix-memory.db` is a rebuildable index.

**Venv:** `~/.nix/memory/.venv/`

**Commands:**
| Command | What |
|---------|------|
| `nix-memory index` | Rebuild index from markdown files |
| `nix-memory recall [query]` | Semantic search (or index summary if no query) |
| `nix-memory recall --recent [N]` | Last N entries by timestamp |
| `nix-memory recall --file learnings "query"` | Search scoped to one file |
| `nix-memory ingest <text> [--file X]` | Add entry + embed (default: learnings.md) |
| `nix-memory clusters [--threshold N] [--min N]` | Detect similar-memory groups |
| `nix-memory curate` | Dump cluster data as JSON |
| `nix-memory archive <id> [id...]` | Archive: mark in DB + strip from markdown + save to archive/ |
| `nix-memory rebuild` | Drop DB, re-index from scratch (~2s) |
| `nix-memory stats` | Index statistics |

**Shell shortcuts:** `nix :recall`, `nix :clusters`, `nix :curate`, `nix :memory <cmd>`

**`:note` auto-indexes** — background `ingest` fires on every `:note` write.

**Archive flow:** `archive` marks entries in DB (hidden from recall), strips them from the source markdown file, and appends the full text to `~/.nix/memory/archive/archived-YYYY-MM-DD.md` with provenance. Nothing is lost.

---

## Window Management — `~/.nix/bin/nix-kwin`

Bash wrapper over KWin's `org.kde.kwin.Scripting` DBus interface. Generates KWin JS snippets, loads via DBus, runs, unloads.

**Verbs:**
| Verb | What |
|------|------|
| `nix-kwin list [--full]` | All windows: class, caption, desktop (+ geometry) |
| `nix-kwin desktops` | List virtual desktops |
| `nix-kwin active` | Current active window |
| `nix-kwin focus <class-regex>` | Activate window by class |
| `nix-kwin close <class-regex>` | Close window(s) by class |
| `nix-kwin move <class-regex> <N>` | Move to desktop N |
| `nix-kwin move-active <N>` | Move active window to desktop N |
| `nix-kwin desktop <N>` | Switch to desktop N |
| `nix-kwin next-desktop` / `prev-desktop` | Cycle workspaces |
| `nix-kwin max [--class <rx>]` / `min` | Maximize/minimize |
| `nix-kwin tile <class> <side>` | Half-tile (left/right/top/bottom) |

**Matching:** case-insensitive regex against `resourceClass`/`resourceName`. Common classes on this machine: `firefox`, `konsole`, `plasmashell`, `TelegramDesktop`, `discord`, `yakuake`. When in doubt, `list` first.

---

## Shell Dispatcher — `nix`

Defined in `~/.nix/nix-shell.sh`, sourced from `.bashrc`.

| Command | What |
|---------|------|
| `nix` | Start a claude session (with welcome banner) |
| `nix <prompt>` | Pass prompt to claude |
| `nix :status` | Machine pulse (host/kernel/uptime/load/mem/disk/snaps) |
| `nix :where` | cwd + git branch/recent/dirty |
| `nix :snap [list]` | List recent snapshots |
| `nix :snap now [desc]` | Manual snapper snapshot |
| `nix :note "..." [category]` | Append to memory (+ git sync + embed) |
| `nix :recall [query]` | Semantic memory search |
| `nix :clusters` | Similar-memory clusters |
| `nix :curate` | Cluster data JSON |
| `nix :git [cmd]` | Cloud-synced persistence |
| `nix :notif [N]` | Recent notifications |
| `nix :help` | Command list |

`:note` categories: `learn`, `pref`, `project`, `feedback`, `system` (default: notes.md)
