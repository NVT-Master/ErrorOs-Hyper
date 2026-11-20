#!/bin/bash
# ErrorOS - CPU frequency cap (experimental, opt-in)
# Purpose: limit maximum CPU frequency (e.g. 90%) to reduce heat/power spikes.
# Notes:
# - On some HyperOS devices thermal/power HAL may override scaling_max_freq.
# - This can reduce peak performance; keep notifications/GPS services unrestricted.
# - Disabled by default.

work_dir=$(pwd)
source "$work_dir/functions.sh"

ENABLE=$(grep -m1 '^cpu_freq_cap_enable=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2 | tr -d '\r\n ')
PERCENT=$(grep -m1 '^cpu_freq_cap_percent=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2 | tr -d '\r\n ')
INTERVAL=$(grep -m1 '^cpu_freq_cap_interval=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2 | tr -d '\r\n ')

[ -z "$ENABLE" ] && ENABLE=false
[ -z "$PERCENT" ] && PERCENT=90
[ -z "$INTERVAL" ] && INTERVAL=0

if [ "$ENABLE" != "true" ]; then
    mods "CPUCap: skipped (cpu_freq_cap_enable!=true)"
    exit 0
fi

mods "CPUCap: experimental - may reduce peak performance and can delay push/FCM if set too low; keep fcm_boot_apply=true and test notifications"

case "$PERCENT" in
    ''|*[!0-9]*) warn "CPUCap: invalid cpu_freq_cap_percent '$PERCENT' -> using 90"; PERCENT=90 ;;
esac
if [ "$PERCENT" -lt 50 ] || [ "$PERCENT" -gt 100 ]; then
    warn "CPUCap: percent out of range 50-100 ($PERCENT) -> clamped"
    [ "$PERCENT" -lt 50 ] && PERCENT=50
    [ "$PERCENT" -gt 100 ] && PERCENT=100
fi
case "$INTERVAL" in
    ''|*[!0-9]*) warn "CPUCap: invalid cpu_freq_cap_interval '$INTERVAL' -> using 0"; INTERVAL=0 ;;
esac

MAIN_FOLDER="$work_dir/build/baserom/images"
DEST_RC="$MAIN_FOLDER/system_ext/etc/init/init.erroros.cpucap.rc"
DEST_SH="$MAIN_FOLDER/system_ext/etc/erroros_cpufreq_cap.sh"
DEST_CONF="$MAIN_FOLDER/system_ext/etc/erroros_cpufreq_cap.conf"

if [ ! -d "$MAIN_FOLDER/system_ext" ]; then
    warn "CPUCap: system_ext not found in images - skipped"
    exit 0
fi

mkdir -p "$MAIN_FOLDER/system_ext/etc/init"

cat > "$DEST_CONF" <<EOF
PERCENT=$PERCENT
INTERVAL=$INTERVAL
EOF

cat > "$DEST_SH" <<'SH'
#!/system/bin/sh
TAG="ErrorOSCPUCap"
CONF="/system_ext/etc/erroros_cpufreq_cap.conf"
PERCENT=90
INTERVAL=0
[ -f "$CONF" ] && . "$CONF"

log_msg() { log -t "$TAG" "$*" 2>/dev/null || echo "$TAG: $*" >> /dev/kmsg 2>/dev/null || true; }

apply_cap_once() {
    local p cpu max cur target changed any best f
    p="$PERCENT"
    [ -z "$p" ] && p=90
    changed=0; any=0
    for cpu in /sys/devices/system/cpu/cpufreq/policy* /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -d "$cpu" ] || continue
        [ -f "$cpu/cpuinfo_max_freq" ] || continue
        [ -f "$cpu/scaling_max_freq" ] || continue
        any=1
        max=$(cat "$cpu/cpuinfo_max_freq" 2>/dev/null)
        cur=$(cat "$cpu/scaling_max_freq" 2>/dev/null)
        case "$max" in ''|*[!0-9]*) continue ;; esac
        target=$((max * p / 100))
        # align down to nearest available freq if scaling_available_frequencies exists
        if [ -f "$cpu/scaling_available_frequencies" ]; then
            best=""
            for f in $(cat "$cpu/scaling_available_frequencies" 2>/dev/null); do
                case "$f" in ''|*[!0-9]*) continue ;; esac
                if [ "$f" -le "$target" ]; then
                    if [ -z "$best" ] || [ "$f" -gt "$best" ]; then best="$f"; fi
                fi
            done
            [ -n "$best" ] && target="$best"
        fi
        [ "$target" -le 0 ] && continue
        if [ "$cur" != "$target" ] 2>/dev/null; then
            echo "$target" > "$cpu/scaling_max_freq" 2>/dev/null && changed=$((changed+1))
        fi
    done
    [ "$any" -eq 0 ] && log_msg "no cpufreq policy nodes found" || log_msg "applied percent=${p} changed=${changed} policies=${any}"
}

if [ "$PERCENT" -lt 85 ] 2>/dev/null; then
    log_msg "warning: percent=${PERCENT} may delay background/push processing (FCM notifications)"
fi
log_msg "start percent=${PERCENT} interval=${INTERVAL}"
# wait for boot/thermal/GMS-FCM services to settle, then apply (later = safer for instant notifications)
sleep 45
apply_cap_once

case "$INTERVAL" in
    ''|*[!0-9]*) INTERVAL=0 ;;
esac
if [ "$INTERVAL" -gt 0 ]; then
    while true; do
        sleep "$INTERVAL"
        apply_cap_once
    done
else
    # interval=0: vẫn thử áp lại vài lần để tăng khả năng giữ sau khi HAL/thermal ghi đè lúc boot
    sleep 30
    apply_cap_once
    sleep 60
    apply_cap_once
fi

log_msg "done"
SH

cat > "$DEST_RC" <<'RC'
# ErrorOS - experimental CPU max frequency cap (opt-in)
# May be overridden by thermal/power HAL on some devices.
service erroros_cpufreq_cap /system/bin/sh /system_ext/etc/erroros_cpufreq_cap.sh
    class late_start
    user root
    group root system
    oneshot
    seclabel u:r:su:s0
    disabled

on property:sys.boot_completed=1
    start erroros_cpufreq_cap
RC

chmod 0644 "$DEST_RC" "$DEST_CONF"
chmod 0755 "$DEST_SH"

if grep -q 'start erroros_cpufreq_cap' "$DEST_RC" && grep -q 'apply_cap_once' "$DEST_SH"; then
    mods "CPUCap: installed (percent=${PERCENT}%, interval=${INTERVAL}s, experimental)"
    mods "CPUCap: check after boot -> adb logcat -s ErrorOSCPUCap"
else
    warn "CPUCap: installation incomplete"
fi