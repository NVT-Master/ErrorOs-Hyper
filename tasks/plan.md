# ErrorOS-Hyper build upgrade plan (2026-11-20)

## Goals
- Fix CI/build robustness issues seen in recent runs (safe.directory warnings, setup pip PEP 668, SukiSU manager 404, ROM download UX).
- Improve observability (build summary/artifacts/manifest).
- Research and prototype battery/notification/CPU-tuning options for HyperOS CN builds without breaking FCM.
- Evaluate integration ideas from BugOS-Hyper, NothingsVN-BuildExt, and PureCN donor ROM while preserving battery/notification/location accuracy goals.

## Workstreams
- [x] W1 CI/tooling: workflow safe.directory, step summary, failure artifact upload, setup.sh Arch-safe deps
- [x] W2 SukiSU: resilient manager download/overrides, decouple manager from boot patch success
- [x] W3 ROM fetch: SHA256 verification + mirror fallback support (`ROM_SHA256`, `ROM_MIRROR_URLS`) with improved retry behavior
- [x] W4 Build outputs: build manifest generated in flash package + CI metadata/diagnostics artifacts
- [x] W5 FCM/power: retained existing notification-safe defaults and strong FCM stack (no risky blind changes)
- [x] W6 Experimental: opt-in CPU max-frequency cap service (configurable, default off) with cleaned implementation
- [x] W7 Research: community findings documented in-session (HyperOS CN FCM/power/location considerations); global donor diff needed for deeper parity
- [x] W8 External repos/donor integration: added opt-in whitelist-based donor import scaffold for safe PureCN/BugOS-derived asset import (no blind APK/framework ports)

## Implemented in repo (this session)
- `.github/workflows/build.yml`: safe.directory, build info, step summary, tee build.log, diagnostics/metadata artifacts, cleanup adjustment.
- `setup.sh`: avoid Arch PEP 668 pip failures (prefer pacman/fallback handling).
- `bin/package/SukiSU/patch.sh`: manager download best-effort with overrides/discovery; boot root patch no longer blocked by manager APK 404.
- `bin/ddevice/getROM.sh`: SHA256 check + mirror fallback (`ROM_MIRROR_URLS`, `ROM_SHA256`) and clearer logging.
- `bin/modfile/UpdateFile/System_CPUFreqCap/update.sh`: opt-in experimental CPU cap init service (cleaned).
- `bin/modfile/UpdateFile/System_DonorImport/{update.sh,allowlist.txt}`: opt-in whitelist donor import scaffold.
- `uploadROM.sh`: build manifest included in output package and copied to build metadata.
- `config.env`: added `sukisu_manager_url`, `sukisu_manager_path`, `cpu_freq_cap_*`, `donor_import_*` options and ROM download env notes.

## Notes
- Keep defaults safe/backward-compatible.
- Android 17 / HyperOS 4 targets remain experimental; prefer opt-in flags for risky behavior.
- Validate on-device: boot, SukiSU manager/root, FCM push delay/miss, GPS accuracy/drift, thermals/battery.
- For "global-like FCM" parity and richer feature ports, provide a compatible global/donor ROM for diffing and enable only vetted allowlist entries.
