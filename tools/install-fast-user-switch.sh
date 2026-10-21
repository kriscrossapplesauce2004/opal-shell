#!/usr/bin/env bash
# Fast user switching for Opal: a second greetd on the next free VT, started from the power key menu. Run with sudo; --revert removes it.
# Each running session stays on its own VT. The Opal greeter lists them, so you can go back without logging out.
set -Eeuo pipefail

config=/etc/greetd/config.toml
switch=/etc/greetd/opal-switch.toml
unit=/etc/systemd/system/opal-switch-greeter@.service
rules=/etc/polkit-1/rules.d/50-opal-fast-user-switch.rules

die() { echo "install-fast-user-switch: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run this with sudo"

if [[ ${1:-} == --revert ]]; then
    # Running switch greeters keep their sessions; they end when those sessions log out.
    rm -f -- "$unit" "$rules" "$switch"
    systemctl daemon-reload
    echo "Removed fast user switching. Open login screens stay until their sessions end."
    exit 0
fi

command -v greetd >/dev/null || die "greetd is not installed"
[[ -f $config ]] || die "$config not found"
[[ -d /etc/polkit-1/rules.d ]] || die "polkit rules folder not found"

# The same greeter as the main login screen, on the next free VT.
python3 - "$config" "$switch" <<'EOF'
import re, sys
source, target = sys.argv[1], sys.argv[2]
text = open(source).read()
section = re.search(r'(?ms)^\[default_session\]\s*$(.*?)(?=^\[|\Z)', text)
if not section: sys.exit('no [default_session] section in ' + source)
command = re.search(r'(?m)^command\s*=.*$', section.group(1))
user = re.search(r'(?m)^user\s*=.*$', section.group(1))
if not command: sys.exit('no greeter command in ' + source)
open(target, 'w').write('# Written by Opal tools/install-fast-user-switch.sh. A second login screen for fast user switching.\n'
                        '[terminal]\nvt = "next"\nswitch = true\n\n[default_session]\n' + command.group(0) + '\n' + (user.group(0) if user else 'user = "greeter"') + '\n')
EOF
chmod 0644 "$switch"

cat > "$unit" <<'EOF'
# Written by Opal tools/install-fast-user-switch.sh.
[Unit]
Description=Opal login screen for fast user switching (%i)
After=systemd-user-sessions.service

[Service]
Type=simple
ExecStart=/usr/bin/env greetd --config /etc/greetd/opal-switch.toml
# Stopping this unit would end the session it started, so it never restarts on its own and is never stopped by Opal.
Restart=no
IgnoreSIGPIPE=no
KeyringMode=shared
EOF

# Active local users may start these login screens; the greeter and active local users may switch to a running session.
cat > "$rules" <<'EOF'
// Written by Opal tools/install-fast-user-switch.sh.
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" && subject.local && subject.active &&
        action.lookup("verb") == "start" && /^opal-switch-greeter@[1-6]\.service$/.test(action.lookup("unit") || ""))
        return polkit.Result.YES;
    if (action.id == "org.freedesktop.login1.chvt" && (subject.user == "greeter" || (subject.local && subject.active)))
        return polkit.Result.YES;
});
EOF
chmod 0644 "$rules"
systemctl daemon-reload
echo "Fast user switching is ready. Pick Switch user in the power key menu."
echo "To remove it: sudo $0 --revert"
echo "The greeter's 'Back to …' list comes with the greeter files: run sudo tools/install-greeter.sh again to update them."
