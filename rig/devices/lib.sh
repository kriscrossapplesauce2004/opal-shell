# Shared helpers for the rig device stand-ins. Source this file; do not run it.

RIG_RUN_DIR=${RIG_RUN_DIR:-/run/luna-rig}
RIG_DRY=0
RIG_CMD=status

rig_init() {
    # Parse "<name> <command> [--dry-run]" and set RIG_CMD and RIG_DRY.
    local name=$1
    shift
    RIG_CMD=${1:-status}
    [ $# -gt 0 ] && shift
    local arg
    for arg in "$@"; do
        case $arg in
        --dry-run) RIG_DRY=1 ;;
        -h | --help)
            sed -n '2,4p' "$RIG_SCRIPT"
            exit 0
            ;;
        *)
            echo "$name: unknown argument: $arg" >&2
            exit 2
            ;;
        esac
    done
}

rig_require_root() {
    # Refuse to change system state without root, unless this is a dry run.
    if [ "$RIG_DRY" = 0 ] && [ "$(id -u)" -ne 0 ]; then
        echo "$1: $RIG_CMD needs root. Rerun with sudo, or add --dry-run." >&2
        exit 1
    fi
}

rig_do() {
    # Run a command, or print it when dry.
    if [ "$RIG_DRY" = 1 ]; then
        printf '+ %s\n' "$*"
        return 0
    fi
    "$@"
}

rig_write() {
    # Write stdin to a file, or describe the write when dry.
    local path=$1
    if [ "$RIG_DRY" = 1 ]; then
        printf '+ write %s\n' "$path"
        cat >/dev/null
        return 0
    fi
    mkdir -p "$(dirname "$path")"
    cat >"$path"
}

rig_pid_alive() {
    # True when the pid file names a live process whose command line contains $2.
    local pidfile=$1 needle=$2 pid
    [ -r "$pidfile" ] || return 1
    pid=$(cat "$pidfile")
    [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ] &&
        tr '\0' ' ' <"/proc/$pid/cmdline" | grep -q -- "$needle"
}

rig_stop_pid() {
    # Stop the process named by a pid file, after checking its command line.
    local pidfile=$1 needle=$2
    if rig_pid_alive "$pidfile" "$needle"; then
        rig_do kill "$(cat "$pidfile")"
    fi
    if [ "$RIG_DRY" = 0 ]; then
        rm -f "$pidfile"
    fi
}

rig_bg() {
    # Start a command in the background. Args: mode (user|root) pidfile command...
    # In user mode, sudo's invoking user runs the command. Logs stay root-owned.
    local mode=$1 pidfile=$2 log
    shift 2
    log=$RIG_RUN_DIR/$(basename "$pidfile" .pid).log
    if [ "$RIG_DRY" = 1 ]; then
        printf '+ (background, %s) %s\n' "$mode" "$*"
        return 0
    fi
    mkdir -p "$RIG_RUN_DIR"
    if [ "$mode" = user ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
        local uid gid
        uid=$(id -u "$SUDO_USER")
        gid=$(id -g "$SUDO_USER")
        setpriv --reuid="$uid" --regid="$gid" --init-groups -- "$@" >>"$log" 2>&1 &
    else
        "$@" >>"$log" 2>&1 &
    fi
    echo $! >"$pidfile"
}
