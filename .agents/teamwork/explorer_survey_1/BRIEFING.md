# BRIEFING — 2026-10-06T02:24:30Z

## Mission
Investigate client workstation ecosystem, deployment scripts, double engine (Sciter Win7 vs Flutter Win10/11), Windows Service, MachineGuid clone handling, WOL, wallpaper branding, BaoSuCoIT.exe, ticket_watcher.ps1, and produce detailed survey and handoff reports.

## 🔒 My Identity
- Archetype: explorer
- Roles: investigator, reporter
- Working directory: c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_1
- Original parent: b4a8df29-36b8-435a-b413-c1831c23f60f
- Milestone: client_workstation_survey

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Metadata only in .agents/teamwork/
- Write reports to survey_report.md and handoff.md in working directory
- Communicate with parent via send_message

## Current Parent
- Conversation ID: b4a8df29-36b8-435a-b413-c1831c23f60f
- Updated: 2026-10-06T02:24:30Z

## Investigation State
- **Explored paths**:
  - `CaiDat/cai_dat.bat` (891 lines) — 1-click deployment, architecture/OS auto-detection, portable unpacking, service registration, failure watchdog, UI lockdown CLI flags.
  - `CaiDat/src/install_official.ps1` (555 lines) — Official installation registry registration, file associations, SAS policy, tray autostart.
  - `CaiDat/src/write_config.ps1` (161 lines) — Config setup, identity backup/restore, ghost GUID detection.
  - `CaiDat/src/set_wallpaper.ps1` (231 lines) — GDI+ text rendering, auto-fit font downsizing, 24bpp BMP for Win7, group policy lockdown.
  - `CaiDat/src/enable_wol.ps1` (173 lines) — Fast Startup disable, NetAdapter properties, driver class PnPCapabilities=0, WMI, UDP 7/9 firewall rule.
  - `CaiDat/src/create_shortcut.ps1` (341 lines) — Public vs user desktop shortcuts, hotkey Ctrl+Alt+H mapping, startup listener.
  - `CaiDat/src/BaoSuCoIT.cs` (499 lines) — C# global hotkey daemon, low-level hook WH_KEYBOARD_LL + RegisterHotKey, UIPI bypass, window restoration.
  - `CaiDat/src/support_dialog.ps1` (530 lines) — WinForms helpdesk dialog, categories, priority, attachments, log extract, POST to 172.16.3.28:21114.
  - `CaiDat/src/ticket_watcher.ps1` (227 lines) — Background monitoring, Win10/11 XML toast vs Win7 balloon tip, status transition notifications.
  - `rustdesk/src/common.rs` & `Cargo.toml` — Hardcoded IP 172.16.3.28, pubkey, API server, builtin settings, Sciter vs Flutter feature flags.
  - `rustdesk/flutter/lib/desktop/pages/desktop_home_page.dart` & `support_ticket_listener.dart` — Flutter in-app support button and ticket listener.
- **Key findings**: Full documentation of client ecosystem completed. Double engine Sciter (Win7 32/64) vs Flutter (Win10/11 x64/arm64) verified. Auto-recovery watchdog verified. MachineGuid clone fix verified.
- **Unexplored areas**: None within the client workstation scope.

## Key Decisions Made
- Completed comprehensive investigation and synthesized findings into `survey_report.md` and `handoff.md`.

## Artifact Index
- c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_1/survey_report.md — Comprehensive Survey Report
- c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_1/handoff.md — Handoff Report
