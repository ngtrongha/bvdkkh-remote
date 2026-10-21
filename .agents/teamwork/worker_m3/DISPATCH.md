# DISPATCH — worker_m3

## Task
Biên soạn tài liệu: `docs/03_dac_ta_tinh_nang_he_thong.md` (Bản Đặc tả Chi tiết Tính năng & Kiến trúc Kỹ thuật Hệ thống "BVĐKKH - Remote").

## File Sở Hữu Độc Quyền
- `docs/03_dac_ta_tinh_nang_he_thong.md`

## Input Files (Bắt buộc đọc trước khi thực hiện)
- `c:/Work/bvdkkh-remote/.agents/teamwork/ORIGINAL_REQUEST.md`
- `c:/Work/bvdkkh-remote/.agents/teamwork/orchestrator_1/PROJECT.md`
- `c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_1/survey_report.md`
- `c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_2/survey_report.md`
- `c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_3/survey_report.md`

## Yêu Cầu Chi Tiết (Theo R3 của ORIGINAL_REQUEST.md)
Trích xuất và đặc tả chính xác 100% dựa trên mã nguồn thực tế của dự án `bvdkkh-remote`:
1. Phân hệ Client Máy trạm:
   - Tương thích kép (Double Engine): Động cơ Sciter trên Windows 7 SP1 (32-bit & 64-bit) từ nhánh `win7-lts` phục vụ máy xét nghiệm, siêu âm, CT/MRI cũ; Động cơ Flutter trên Windows 10/11 (x64, ARM64) từ nhánh `feat/upgrade-flutter-win10`.
   - Triển khai tự động 1-click qua `cai_dat.bat` / `install_official.ps1`: Tự nhận diện kiến trúc (`x64`, `arm64`, `x86`), OS version, tạo alias binary (`BVDKKH - Remote.exe`, `BVĐKKH - Remote.exe`, `rustdesk.exe`), cấu hình silent.
   - Khóa an toàn giao diện: Khóa cứng thông số máy chủ `172.16.3.28:21114/21116` và Public Key trong mã nguồn Rust `src/common.rs`, cấm sửa mật khẩu vĩnh viễn (`disable-change-permanent-password`), cấm đổi ID (`disable-change-id`), cấm dừng dịch vụ (`hide-stop-service`).
   - Windows Service tự phục hồi: `BVĐKKH - Remote Service`, watchdog restart `sc failure reset= 86400 actions= restart/5000/restart/15000/restart/60000`.
   - Tự động nhận diện và tái tạo MachineGuid chống trùng lặp ID khi máy trạm được Ghost/Clone hàng loạt (`cai_dat.bat` nhận diện GUID bản mẫu `6c2a494b-...` và tự sinh mới).
   - Kích hoạt Wake-on-LAN (WOL): Tắt Fast Startup, mở driver PnPCapabilities, mở tường lửa UDP port 7 & 9.
   - Gán thông tin tên máy lên hình nền nhận diện bệnh viện qua `set_wallpaper.ps1` (`#296AC4`, hỗ trợ Win7 BMP 24bpp fallback).
   - Module phím tắt toàn cục `Ctrl + Alt + H` (`BaoSuCoIT.exe`, hook `WH_KEYBOARD_LL`, `RegisterHotKey`, UIPI bypass), form `support_dialog.ps1` và trình thông báo nền `ticket_watcher.ps1`.
2. Phân hệ Máy chủ Quản trị (RustDesk API Server Pro):
   - Backend Go (Iris v12) hiệu năng cao, CSDL SQLite/MySQL, chạy On-Premise nội bộ tại IP viện `172.16.3.28`. Danh mục cổng: 21114 (API/Web), 21115 (NAT test), 21116 (ID/HB TCP/UDP), 21117 (Relay TCP), 21118 (Web hbbs), 21119 (Web hbbr).
   - Cổng quản trị Web Admin Flutter (`rustdesk_admin`) chuẩn giao diện tiếng Việt (`vi-VN`), Dark/Light mode, Responsive trên PC và Mobile, tìm kiếm tiếng Việt không dấu.
   - Web Remote Desktop: Điều khiển máy tính từ xa trực tiếp trên trình duyệt Web bằng WebCodecs & NaCl encryption không cần cài client, quản lý đa phiên nổi (Floating Session Manager).
   - Quản lý danh bạ Address Book tập trung, gán nhãn khoa/phòng, phân quyền nhóm thiết bị.
   - Hệ thống quản lý Ticket sự cố thời gian thực qua WebSocket, tích hợp Bot Telegram với Topic Routing chuyên biệt (Topics 7: HIS/LIS, 8: Máy in, 9: Mạng, 10: Máy chậm, 11: Cài phần mềm, 12: Khác, 37: Lưu trữ).
3. Cơ chế Bảo mật Nâng cao:
   - Phân quyền VIP Device Lock đa tầng: Tầng 1 (Web Admin & API `POST /devices/{id}/vip-access`, chặn nút kết nối `is_accessible = false`), Tầng 2 (Client RustDesk engine từ chối `ADMIN_MASTER_SECRET` khi cờ `is-vip = true`).
   - Thuật toán sinh mật khẩu dự phòng an toàn qua `HMAC-SHA256(MachineGuid, SecretSalt)` 16 ký tự an toàn CLI.
   - Cơ chế xác thực 2FA TOTP (RFC 6238), kiểm soát phiên và nhật ký kiểm toán (Audit Logs `model.Audit`, `model.FileTransferAudit`).

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Output
Tạo tệp: `c:/Work/bvdkkh-remote/docs/03_dac_ta_tinh_nang_he_thong.md`
Báo cáo bàn giao: `c:/Work/bvdkkh-remote/.agents/teamwork/worker_m3/handoff.md`


## 2026-10-06T02:30:58Z
You are worker_m3. Your working directory is c:/Work/bvdkkh-remote/.agents/teamwork/worker_m3.
You exclusively own and must create: c:/Work/bvdkkh-remote/docs/03_dac_ta_tinh_nang_he_thong.md.
Read c:/Work/bvdkkh-remote/.agents/teamwork/ORIGINAL_REQUEST.md, c:/Work/bvdkkh-remote/.agents/teamwork/orchestrator_1/PROJECT.md, and c:/Work/bvdkkh-remote/.agents/teamwork/worker_m3/DISPATCH.md.
Also inspect c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_1/survey_report.md, c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_2/survey_report.md, and c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_3/survey_report.md.
Author docs/03_dac_ta_tinh_nang_he_thong.md specifying 100% accurate architectural and technical specifications of bvdkkh-remote: Client Workstation Ecosystem (Sciter Win7 32/64 vs Flutter Win10/11 x64/arm64, 1-click installer, UI lockdown, Windows Service recovery, MachineGuid clone anti-collision, WOL, branded wallpaper hostname overlay, Ctrl+Alt+H BaoSuCoIT, ticket_watcher), Server System (RustDesk API Server Pro Go backend, Iris v12, SQLite/MySQL, IP 172.16.3.28, ports 21114-21119, Flutter Web Admin rustdesk_admin, Web Remote Desktop WebCodecs/NaCl, Address Book, Telegram Topic routing), and Security (Multi-tier VIP Device Lock, HMAC-SHA256 password derivation, 2FA TOTP RFC 6238, Audit Logs).
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
When complete, write your handoff report to c:/Work/bvdkkh-remote/.agents/teamwork/worker_m3/handoff.md and send a completion message to parent.
