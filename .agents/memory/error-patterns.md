---
type: error-patterns
created: 2026-10-20
updated: 2026-10-20
---

# Error Patterns & Prevention Memory

Tài liệu ghi nhớ các dạng lỗi phổ biến, triệu chứng nhận biết, nguyên nhân gốc rễ và bài học kinh nghiệm để phòng ngừa lỗi tái diễn.

## 1. Kết nối Mạng & Server Nội bộ (Networking & Rendezvous)
- **Lỗi 01: Client bị treo "Đang kết nối..." khi dùng server nội bộ key-less (`172.16.3.28`)**:
  - *Nguyên nhân*: Upstream ép handshake `key_exchange` 18s và fallback nhầm `RS_PUB_KEY` công cộng.
  - *Giải pháp*: Trong `src/common.rs` và `src/client.rs`, chỉ fallback `RS_PUB_KEY` khi host là public (`is_public`); cho phép key rỗng kết nối 0ms và giảm timeout thăm dò còn 1.5s không ném exception làm ngắt kết nối.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-01).

## 2. Trình Cài đặt Tự động & Dịch vụ Windows (Installer & Services)
- **Lỗi 02: Auto Installer không thay thế file đang chạy, service không tự chạy ngầm**:
  - *Nguyên nhân*: Thiếu `requireAdministrator`, tiến trình và service cũ đang khóa file thực thi trong Program Files, thiếu lệnh đăng ký Run key registry.
  - *Giải pháp*: Manifest đòi quyền Admin; dừng service và `taskkill /F /IM rustdesk.exe`, chờ nhả file handle trước khi overwrite; đăng ký `sc config start= auto`, `net start` và registry Run.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-02).

## 3. Quản lý Dependencies & Build Release (Submodules & Cargo)
- **Lỗi 03: Build `--locked` thất bại do submodule `libs/hbb_common` bị lệch dependencies**:
  - *Nguyên nhân*: Upstream thay đổi dependencies nhưng fork `ngtrongha/hbb_common` chưa đồng bộ.
  - *Giải pháp*: Bắt buộc sync fork `hbb_common` trước, bảo toàn IP `172.16.3.28`, update pointer submodule.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-03).
- **Lỗi 04: Build Rust thất bại do nhầm kiểu tham số trong hàm `hbb_common::timeout`**:
  - *Nguyên nhân*: Truyền `std::time::Duration` thay vì `u64` (ms) vào hàm `timeout()` của `hbb_common`.
  - *Giải pháp*: Dùng `timeout(1500, future)` (hoặc `tokio::time::timeout` nếu dùng `Duration`).
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-04).
- **Lỗi 05: Build Android/iOS thất bại do thiếu type annotation `Vec<Value>` với `#[cfg]`**:
  - *Nguyên nhân*: Biến `let mut disks_info = Vec::new()` không được push phần tử trên mobile do `#[cfg]`, khiến macro `json!` không suy diễn được kiểu `T`.
  - *Giải pháp*: Khai báo tường minh: `let mut disks_info: Vec<Value> = Vec::new();`.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-05).

## 4. Giao diện & Shortcut Màn hình (Branding & Desktop Shortcuts)
- **Lỗi 06: Màn hình Desktop xuất hiện 2 shortcut trùng tên và 1 shortcut bị trắng (Icon gãy link)**:
  - *Nguyên nhân*: Desktop Windows hiển thị gộp `Public\Desktop` và `User\Desktop`. Bản cài cũ trỏ vào thư mục cũ bị xóa để lại shortcut gãy link trong profile user; typo `Remoter` trong `Cargo.toml`.
  - *Giải pháp*: `CleanOldShortcuts()` quét dọn sạch shortcut trên mọi profile Desktop trước khi tạo mới; gán tường minh `IconLocation = targetExe + ",0"`; gọi `SHChangeNotify` làm mới icon cache; chuẩn hóa tên hiển thị `BVĐKKH - Remote` và sửa sạch typo `Remoter`.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-06).

## 5. An toàn Bảo mật & Tránh False Positive (Antivirus & Defender Evasion)
- **Lỗi 07: Windows Defender cảnh báo `Behavior:Win32/DefenseEvasion.A!ml`**:
  - *Nguyên nhân*: Bộ cài gọi tiến trình con `powershell.exe -Command New-NetFirewallRule ...` hoặc `netsh advfirewall` để mở port và bật EdgeTraversal. Defender AMSI và Machine Learning nhận diện việc gọi PowerShell ẩn để sửa tường lửa là hành vi mã độc né tránh phòng thủ.
  - *Giải pháp*: Loại bỏ triệt để việc spawn `powershell.exe`/`netsh.exe`; chuyển 100% sang sử dụng **Windows Firewall COM API (`HNetCfg.FwPolicy2`)** nội bộ trong tiến trình; không sinh tiến trình lạ, không bị AMSI quét lệnh.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-07).
