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
- **Lỗi 08: Client báo "Chưa sẵn sàng" / "Máy chủ: Chưa kết nối" và Icon trắng**:
  - *Nguyên nhân*: Thiếu file cấu hình `RustDesk2.toml` trong `systemprofile` và `ProgramData` khiến dịch vụ chạy ngầm không trỏ tới máy chủ nội bộ `172.16.3.28:21116` với `key=""`; vòng lặp quét Desktop văng lỗi quyền khi duyệt `C:\Users`.
  - *Giải pháp*: Thêm hàm `WriteServerConfig()` ghi đồng loạt TOML nội bộ cho mọi profile hệ thống; quét thư mục `C:\Users` an toàn với per-directory try/catch; tạo bộ công cụ `Fix-BVDKKH-Remote.bat` sửa chữa tức thì.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-08).
- **Lỗi 09: Trùng lặp 2 thư mục Program Files (BVDKKH và BVĐKKH) và 2 file .exe trong thư mục**:
  - *Nguyên nhân*: Thư mục cài đặt bị phân mảnh giữa `BVDKKH - Remote` (ASCII) và `BVĐKKH - Remote` (Unicode `get_app_name()`); script sao chép đồng thời cả `BVDKKH - Remote.exe` và `BVĐKKH - Remote.exe` để phòng hờ gãy link dẫn đến xuất hiện cả 2 thư mục và 2 file thực thi.
  - *Giải pháp*: Chuẩn hóa duy nhất 1 thư mục `C:\Program Files\BVĐKKH - Remote` và 1 file thương hiệu `BVĐKKH - Remote.exe`; tự động chuyển dữ liệu (migration) và xóa sạch thư mục cũ `BVDKKH - Remote` cũng như xóa file `BVDKKH - Remote.exe` trong `Program.cs`, `Fix-BVDKKH-Remote.bat`, `cai_dat.bat` và `install_official.ps1`.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-09).

- **Lỗi 10: Auto Installer báo lỗi "The specified executable is not a valid application for this OS platform"**:
  - *Nguyên nhân*: Nhận diện nhầm Windows 10/11 32-bit (x86) thành 64-bit do CPU là x64; hoặc mạng chặn tải file `.exe` trả về file HTML/0KB; gọi `Process.Start` sinh lỗi Win32 mã 193 `ERROR_BAD_EXE_FORMAT`.
  - *Giải pháp*: Buộc `info.Arch = "x86"` khi `!Environment.Is64BitOperatingSystem`; thêm hàm `IsValidExecutable()` xác thực dung lượng >= 2MB và header `MZ`; bổ sung `ResolveLocalInstallerFile()` ưu tiên lấy gói cục bộ trong thư mục hoặc `src/`.
  - *Quy tắc*: Chi tiết tại [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md#lỗi-10).
