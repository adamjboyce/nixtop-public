# ─────────────────────────────────────────────────────────────
#   nix — shellside handles
#   sourced from ~/.bashrc
# ─────────────────────────────────────────────────────────────

# Catppuccin Mocha palette (truecolor)
__nix_c_pink=$'\033[38;2;245;194;231m'
__nix_c_mauve=$'\033[38;2;203;166;247m'
__nix_c_text=$'\033[38;2;205;214;244m'
__nix_c_muted=$'\033[38;2;127;132;156m'
__nix_c_red=$'\033[38;2;243;139;168m'
__nix_c_green=$'\033[38;2;166;227;161m'
__nix_c_reset=$'\033[0m'

__nix_status() {
    printf '%s❯%s %sthe machine%s\n' \
        "$__nix_c_pink" "$__nix_c_reset" "$__nix_c_mauve" "$__nix_c_reset"

    local up load mem disk snaps host kernel
    # Tumbleweed ships coreutils uptime (no -p). Parse /proc/uptime directly.
    up=$(awk '{
        s=int($1); d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60);
        out="";
        if (d) out=out d "d ";
        if (h) out=out h "h ";
        out=out m "m";
        print out;
    }' /proc/uptime)
    load=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
    mem=$(free -h | awk '/^Mem:/ {printf "%s / %s", $3, $2}')
    disk=$(df -h / | awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}')
    host=$(uname -n)
    kernel=$(uname -r)
    snaps=$(sudo -n snapper -c root list 2>/dev/null | tail -n +4 | wc -l)

    local label="  %s%-7s%s  %s\n"
    printf "$label" "$__nix_c_muted" "host"   "$__nix_c_reset" "$host"
    printf "$label" "$__nix_c_muted" "kernel" "$__nix_c_reset" "$kernel"
    printf "$label" "$__nix_c_muted" "uptime" "$__nix_c_reset" "$up"
    printf "$label" "$__nix_c_muted" "load"   "$__nix_c_reset" "$load"
    printf "$label" "$__nix_c_muted" "mem"    "$__nix_c_reset" "$mem"
    printf "$label" "$__nix_c_muted" "disk"   "$__nix_c_reset" "$disk"
    if [ "$snaps" -gt 0 ] 2>/dev/null; then
        printf "$label" "$__nix_c_muted" "snaps" "$__nix_c_reset" "$snaps on /"
    fi
}

__nix_where() {
    printf '%s%s%s\n' "$__nix_c_mauve" "$PWD" "$__nix_c_reset"
    if git rev-parse --git-dir &>/dev/null; then
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null \
              || git rev-parse --short HEAD 2>/dev/null)
        printf '  %sbranch%s  %s\n' "$__nix_c_muted" "$__nix_c_reset" "$branch"
        printf '  %srecent%s\n'     "$__nix_c_muted" "$__nix_c_reset"
        git log -3 --oneline --color=always 2>/dev/null | sed 's/^/    /'
        local dirty
        dirty=$(git status --porcelain 2>/dev/null | wc -l)
        if [ "$dirty" -gt 0 ]; then
            printf '  %sdirty%s   %s%d uncommitted%s\n' \
                "$__nix_c_muted" "$__nix_c_reset" \
                "$__nix_c_red" "$dirty" "$__nix_c_reset"
        fi
    fi
}

__nix_snap() {
    case "$1" in
        ""|list)
            sudo snapper -c root list | tail -20
            ;;
        now)
            shift
            local desc="${*:-nix: manual}"
            sudo snapper -c root create --description "$desc" --cleanup-algorithm number
            printf '%s❯%s snapshot taken: %s\n' \
                "$__nix_c_pink" "$__nix_c_reset" "$desc"
            ;;
        *)
            printf 'nix :snap — usage: :snap [list] | :snap now [description]\n' >&2
            return 1
            ;;
    esac
}

__nix_note() {
    local memdir="$HOME/.nix/memory"
    local target="$memdir/notes.md"
    local label="note"
    case "$1" in
        learn)    target="$memdir/learnings.md";   label="learning";   shift ;;
        pref)     target="$memdir/preferences.md"; label="preference"; shift ;;
        project)  target="$memdir/projects.md";    label="project";    shift ;;
        feedback) target="$memdir/feedback.md";    label="feedback";   shift ;;
        system)   target="$memdir/system.md";      label="system";     shift ;;
        help|-h|--help)
            printf '%s❯%s nix :note — append to memory\n\n' \
                "$__nix_c_pink" "$__nix_c_reset"
            printf '  %s:note "text"%s                append to notes.md\n' \
                "$__nix_c_muted" "$__nix_c_reset"
            printf '  %s:note CATEGORY "text"%s       append to <category>.md\n' \
                "$__nix_c_muted" "$__nix_c_reset"
            printf '  %s:note [CATEGORY]%s            open target in $EDITOR\n\n' \
                "$__nix_c_muted" "$__nix_c_reset"
            printf '  categories: learn pref project feedback system\n'
            printf '  full docs:  man nix-note\n'
            return 0
            ;;
    esac

    [ -d "$memdir" ] || mkdir -p "$memdir"
    [ -f "$target" ] || : > "$target"

    if [ $# -eq 0 ]; then
        "${EDITOR:-vi}" "$target"
        return
    fi

    local stamp body subject
    stamp=$(date '+%Y-%m-%d %H:%M')
    body="$*"
    if [ ${#body} -le 60 ]; then
        subject="$body"
    else
        subject=$(printf '%s' "$body" | awk '{
            s=substr($0,1,60);
            sub(/ [^ ]*$/,"",s);
            print s"…"
        }')
    fi

    {
        printf '\n## [%s] %s\n' "$stamp" "$subject"
        [ ${#body} -gt 60 ] && printf '%s\n' "$body"
    } >> "$target"

    printf '%s❯%s %s → ~%s\n' \
        "$__nix_c_pink" "$__nix_c_reset" "$label" "${target#$HOME}"

    # Background embed into semantic index (non-blocking, fire-and-forget).
    if [ -x "$HOME/.nix/bin/nix-memory" ]; then
        setsid "$HOME/.nix/bin/nix-memory" ingest --file "$(basename "$target")" "$body" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    fi

    # Background git sync so memory lands in the cloud within seconds.
    # setsid + & detaches from the shell's process group so the sync
    # survives the parent shell exiting (matters for yakuake-hooked
    # sessions that exit immediately after claude returns).
    if [ -x "$HOME/.nix/bin/nix-git" ] && [ -d "$HOME/.nix/.git" ]; then
        setsid bash -c "timeout 30 '$HOME/.nix/bin/nix-git' sync ':note $label — $subject' >/dev/null 2>&1" </dev/null >/dev/null 2>&1 &
        disown 2>/dev/null || true
    fi
}

__nix_welcome() {
    # Set the terminal title so KDE task switcher / Konsole tab reads "nix"
    # regardless of what the child process reports.
    printf '\033]0;nix\007'
    clear
    printf '\n'
    printf '  %s❯%s %snix.%s\n'              "$__nix_c_pink"  "$__nix_c_reset" "$__nix_c_text" "$__nix_c_reset"
    printf '    %syou'\''re home. what are we doing?%s\n\n' "$__nix_c_muted" "$__nix_c_reset"
}

__nix_help() {
    cat <<EOF
${__nix_c_pink}❯${__nix_c_reset} nix — shellside handles

  ${__nix_c_muted}nix${__nix_c_reset}                    start a claude session
  ${__nix_c_muted}nix <prompt...>${__nix_c_reset}        pass arguments to claude
  ${__nix_c_muted}nix :status${__nix_c_reset}            machine pulse
  ${__nix_c_muted}nix :where${__nix_c_reset}             here and now
  ${__nix_c_muted}nix :snap${__nix_c_reset}              list recent snapshots
  ${__nix_c_muted}nix :snap now [desc]${__nix_c_reset}   take a manual snapshot
  ${__nix_c_muted}nix :note "..."${__nix_c_reset}        append to memory (see :note help)
  ${__nix_c_muted}nix :recall [query]${__nix_c_reset}    semantic memory search
  ${__nix_c_muted}nix :recall --recent${__nix_c_reset}   last entries by time
  ${__nix_c_muted}nix :clusters${__nix_c_reset}          show similar-memory clusters
  ${__nix_c_muted}nix :curate${__nix_c_reset}            cluster data for synthesis
  ${__nix_c_muted}nix :git${__nix_c_reset}               cloud-synced state (see :git help)
  ${__nix_c_muted}nix :notif [N]${__nix_c_reset}         recent notifications (see :notif help)
  ${__nix_c_muted}nix :triage${__nix_c_reset}            surface errors (see :triage help)
  ${__nix_c_muted}nix :rollback${__nix_c_reset}          snapper co-pilot (see :rollback help)
  ${__nix_c_muted}nix :health${__nix_c_reset}            system health briefing (see :health help)
  ${__nix_c_muted}nix :help${__nix_c_reset}              this
EOF
}

# Fire a synchronous `nix :git sync` with a tight timeout. Called after
# claude exits in both the yakuake hook and the manual nix() path so
# memory updates land in git without the user having to remember.
__nix_git_autosync() {
    [ -x "$HOME/.nix/bin/nix-git" ] || return 0
    [ -d "$HOME/.nix/.git" ] || return 0
    timeout 15 "$HOME/.nix/bin/nix-git" sync "session end $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || true
}

# Auto-summon nix when shell parent is yakuake (the quake-style overlay).
# Guard env var prevents recursion if nix spawns further bash children.
# If a pending query exists (from KRunner's nix plugin), consume it and
# pass it to claude as the first user turn so the session starts with
# the question already asked.
if [ -z "$__NIX_YAKUAKE_ENTERED" ] && \
   [ "$(ps -o comm= -p "$PPID" 2>/dev/null)" = "yakuake" ]; then
    export __NIX_YAKUAKE_ENTERED=1
    nix() {
        command claude --dangerously-skip-permissions --permission-mode bypassPermissions --name nix "$@"
    }
    __nix_pending="$HOME/.nix/ctx/pending-query.txt"
    if [ -f "$__nix_pending" ]; then
        __nix_q=$(cat "$__nix_pending")
        rm -f "$__nix_pending"
        __nix_welcome
        command claude --dangerously-skip-permissions --permission-mode bypassPermissions --name nix "$__nix_q"
    else
        __nix_welcome
        command claude --dangerously-skip-permissions --permission-mode bypassPermissions --name nix
    fi
    __nix_git_autosync
    exit
fi

nix() {
    # Capture summon context before every claude launch — unless the F12
    # wrapper (nix-summon) just captured (<3s old), in which case the
    # latest/ symlink is already fresh and a second capture would just
    # overwrite the clean pre-summon screenshot with a yakuake-covered one.
    # See ~/.claude/CLAUDE.md § Ambient Context.
    local __nix_latest="$HOME/.nix/ctx/latest"
    local __nix_need=1
    if [ -L "$__nix_latest" ]; then
        local __nix_mtime __nix_now
        __nix_mtime=$(stat -Lc %Y "$__nix_latest" 2>/dev/null || echo 0)
        __nix_now=$(date +%s)
        [ $(( __nix_now - __nix_mtime )) -lt 3 ] && __nix_need=0
    fi
    if [ "$__nix_need" = "1" ] && [ -x "$HOME/.nix/bin/nix-capture-context" ]; then
        "$HOME/.nix/bin/nix-capture-context" >/dev/null 2>&1
    fi

    if [ $# -eq 0 ]; then
        __nix_welcome
        command claude --dangerously-skip-permissions --permission-mode bypassPermissions --name nix
        __nix_git_autosync
        return
    fi
    if [[ $1 == :* ]]; then
        local sub=${1#:}
        shift
        case $sub in
            status) __nix_status "$@" ;;
            where)  __nix_where  "$@" ;;
            snap)   __nix_snap   "$@" ;;
            note)   __nix_note   "$@" ;;
            git)    "$HOME/.nix/bin/nix-git" "$@" ;;
            notifications|notif)
                    "$HOME/.nix/bin/nix-notifications" "$@" ;;
            recall) "$HOME/.nix/bin/nix-memory" recall "$@" ;;
            curate) "$HOME/.nix/bin/nix-memory" curate "$@" ;;
            clusters) "$HOME/.nix/bin/nix-memory" clusters "$@" ;;
            memory) "$HOME/.nix/bin/nix-memory" "$@" ;;
            triage)   "$HOME/.nix/bin/nix-triage" "$@" ;;
            rollback) "$HOME/.nix/bin/nix-rollback" "$@" ;;
            health)   "$HOME/.nix/bin/nix-health" "$@" ;;
            help)   __nix_help        ;;
            *)
                printf 'nix: unknown subcommand :%s (try :help)\n' "$sub" >&2
                return 1
                ;;
        esac
        return
    fi
    __nix_welcome
    command claude --dangerously-skip-permissions --permission-mode bypassPermissions --name nix "$@"
    __nix_git_autosync
}
