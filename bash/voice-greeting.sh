# nix voice greeting — fires `welcome-home` on the first interactive shell
# of each calendar day. Sourced from .bashrc.
#
# Race-tolerant: state file holds the date of last fire. Multiple terminals
# opening simultaneously may both check before either writes, but the worst
# case is firing twice — harmless. State at ~/.nix/voice/.last-shell-day.

__nix_first_shell_check() {
    [[ "$-" != *i* ]] && return  # interactive shells only

    local state="$HOME/.nix/voice/.last-shell-day"
    local today
    today=$(date +%Y-%m-%d)
    local last=""
    [[ -f "$state" ]] && last=$(cat "$state" 2>/dev/null || true)

    if [[ "$last" != "$today" ]]; then
        echo "$today" > "$state"
        ( "$HOME/.nix/bin/nix-voice" welcome-home 2>/dev/null & disown ) 2>/dev/null
    fi
}

__nix_first_shell_check
unset -f __nix_first_shell_check
