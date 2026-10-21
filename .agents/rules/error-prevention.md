---
name: error-prevention
version: 1.0.0
priority: P0
trigger: always_on
description: Quy tắc phòng ngừa lỗi, lưu trữ sự cố kỹ thuật và bài học kinh nghiệm để ngăn chặn lỗi tái diễn trong tương lai.
---

# Quy tắc Phòng ngừa Lỗi & Lưu trữ Sự cố (Error Prevention & Knowledge Retention)

> **QUY TẮC BẮT BUỘC (P0)**:
> 1. Mỗi khi phát hiện, chẩn đoán hoặc sửa xong một lỗi (đặc biệt là các lỗi có xu hướng tái diễn, lỗi do cập nhật upstream, lỗi kết nối mạng, lỗi cài đặt Windows), **BẮT BUỘC PHẢI GHI NHẬN LẠI VÀO TÀI LIỆU NÀY** và đồng bộ sang `.agents/memory/error-patterns.md`.
> 2. Trước khi sửa lỗi hoặc đồng bộ mã nguồn, AI **BẮT BUỘC PHẢI TRA CỨU** danh mục này để không lặp lại lỗi cũ.

---

## 📋 Cấu trúc tiêu chuẩn của một bản ghi lỗi

Mỗi sự cố phải được ghi chép đầy đủ 4 trường thông tin:
1. **Triệu chứng (Symptom)**: Dấu hiệu nhận biết, biểu hiện từ người dùng, log lỗi, thông báo lỗi.
2. **Nguyên nhân gốc rễ (Root Cause)**: Phân tích kỹ thuật chi tiết tại sao xảy ra lỗi ở tầng mã nguồn, kiến trúc hoặc môi trường.
3. **Giải pháp triệt để (Resolution)**: File, hàm, lệnh hoặc cách sửa đổi cụ thể đã giải quyết sự cố.
4. **Quy tắc phòng ngừa (Prevention Rule)**: Quy tắc bất di bất dịch cần tuân thủ khi viết code mới hoặc sửa code để không bao giờ tái phạm.

---

## 📚 Danh mục sự cố đã ghi nhận (Error Registry)

### 🔴 LỖI 01: Client bị treo "Đang kết nối..." khi dùng Server nội bộ (Intranet / Key-less Server)

- **Ngày ghi nhận**: 2026-10-20
- **Phạm vi ảnh hưởng**: Windows Client, Mobile Client kết nối qua máy chủ nội bộ BVĐKKH (`172.16.3.28`).
- **Triệu chứng (Symptom)**:
  - Web Client (`http://172.16.3.28:21114`) kết nối và điều khiển từ xa mượt mà.
  - Native Client mới build khi bấm kết nối thì bị treo ở thông báo *"Đang kết nối..."* suốt 18 - 36 giây.
  - Log file `BVĐKKH - Remote_rCURRENT.log` ghi nhận:
    `Connection closed: Failed to secure tcp: deadline has elapsed: Please try later(0)`
    `Handshake failed: invalid public key from rendezvous server`
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. Upstream RustDesk thêm cơ chế mã hóa kênh WebRTC rendezvous (`key_exchange`) với thời gian chờ 18 giây (`READ_TIMEOUT`).
  2. Server `hbbs` nội bộ của bệnh viện (`172.16.3.28`) hoạt động ở chế độ private không dùng khóa mã hóa công cộng (`key` rỗng).
  3. Hàm `get_key()` trong `src/common.rs` khi thấy `key.is_empty()` đã tự động fallback lấy `config::RS_PUB_KEY` của RustDesk công cộng.
  4. Client cố bắt tay rendezvous với server nội bộ bằng public key công cộng. Do `hbbs` nội bộ không gửi gói `KeyExchange`, `conn.next()` bị timeout 18 giây, văng lỗi `?` làm hủy kết nối WebRTC.
  5. Khi fallback sang TCP, hàm `secure_tcp` tiếp tục gọi `key_exchange` và lại bị treo thêm 18 giây nữa trước khi đứt kết nối hoàn toàn.
- **Giải pháp triệt để (Resolution)**:
  - `src/common.rs`:
    - `get_key()`: Chỉ fallback sang `RS_PUB_KEY` khi `is_public(&host)` là `true` (`rustdesk.com`). Với host nội bộ / IP riêng, giữ nguyên `""`.
    - `secure_tcp_required()`: Trả về `Ok(())` ngay lập tức nếu `key.is_empty()`.
    - `key_exchange()`: Trả về `Ok(false)` ngay nếu `key.is_empty()`. Nếu có key, giảm timeout thăm dò còn 1500ms và bọc bằng `.unwrap_or(None)` để không văng lỗi sập luồng.
  - `src/client.rs`:
    - `secure_connection()`: Nếu `key.is_empty()`, gán `rs_pk = None` (không lấy `RS_PUB_KEY`), kích hoạt cơ chế fallback nội bộ key-less an toàn của RustDesk.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - **KHÔNG BAO GIỜ** gán cứng public key ngoài internet cho các IP nội bộ hoặc máy chủ private.
  - Luôn đảm bảo cơ chế fail-open / graceful fallback tức thì (0ms) cho các máy chủ nội bộ không kích hoạt tính năng trao đổi khóa.

---

### 🔴 LỖI 02: Auto Installer không ghi đè bản mới, service cũ vẫn chạy, service không tự chạy ngầm

- **Ngày ghi nhận**: 2026-10-20
- **Phạm vi ảnh hưởng**: Trình cài đặt tự động `BVDKKH-Remote-AutoInstall.exe` trên Windows 7 / Windows 10.
- **Triệu chứng (Symptom)**:
  - Chạy installer xong nhưng mở ứng dụng lên vẫn là phiên bản cũ (ví dụ 1.5.16 thay vì 1.5.17).
  - Service Windows không chạy ngầm hoặc không tự khởi động lại sau khi cài.
  - Hình nền máy tính có thể đã đổi nhưng ứng dụng cốt lõi không thay đổi.
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. Tiến trình `rustdesk.exe` và Windows Service cũ đang chạy ngầm, giữ file lock đối với file thực thi trong thư mục cài đặt (`Program Files`).
  2. Installer không yêu cầu quyền Administrator mức cao nhất trong manifest (`app.manifest`), dẫn đến không đủ quyền dừng service hoặc ghi đè file hệ thống.
  3. Thiếu lệnh dừng triệt để tiến trình (`taskkill /F`, `sc stop`) và không có vòng lặp chờ giải phóng file lock trước khi copy đè file mới.
  4. Thiếu lệnh cấu hình tự khởi động (`sc config ... start= auto`) và thiếu ghi Registry Run key cho khay hệ thống (tray icon).
- **Giải pháp triệt để (Resolution)**:
  - `tools/auto-installer/app.manifest`: Đặt `requestedExecutionLevel level="requireAdministrator"`.
  - `tools/auto-installer/Program.cs`:
    - Trước khi cài: Dừng service bằng `net stop "RustDesk"`, ép đóng tiến trình bằng `taskkill /F /IM rustdesk.exe`.
    - Đợi 1-2 giây để Windows giải phóng file handle.
    - Copy ghi đè binary mới.
    - Sau khi copy: Chạy `sc config "RustDesk" start= auto`, `net start "RustDesk"`, và ghi Registry `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` để tự chạy tray khi đăng nhập Windows.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - Mọi script hoặc installer cài đặt/cập nhật trên Windows bắt buộc phải:
    1. Yêu cầu quyền Administrator ngay từ đầu (`requireAdministrator`).
    2. Dừng triệt để service và kill sạch tiến trình cũ trước khi thao tác file.
    3. Đảm bảo file unlock hoàn toàn trước khi copy đè.
    4. Cấu hình tự khởi động cho cả Windows Service (`LocalSystem`) và Tray Application (`User Session`).

---

### 🔴 LỖI 03: Build `--locked` thất bại do không đồng bộ Submodule `hbb_common`

- **Ngày ghi nhận**: 2026-10-18
- **Phạm vi ảnh hưởng**: GitHub Actions workflow (`flutter-tag.yml`, `bridge.yml`, Windows / Mobile build).
- **Triệu chứng (Symptom)**:
  - Quy trình build CI/CD báo lỗi đỏ ở bước `cargo build` với cờ `--locked`:
    `error: the lock file /.../Cargo.lock needs to be updated but --locked was passed to prevent this`
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. RustDesk upstream cập nhật các dependencies trong `libs/hbb_common/Cargo.toml` (ví dụ `tokio-tungstenite`, `tungstenite`, `webrtc`).
  2. Submodule `libs/hbb_common` trong repo trỏ tới commit cũ hoặc fork `ngtrongha/hbb_common` chưa được cập nhật tương ứng.
  3. Khi root `Cargo.lock` được cập nhật mà submodule không khớp dependencies thì cờ `--locked` của Cargo sẽ từ chối build.
- **Giải pháp triệt để (Resolution)**:
  - Bắt buộc kiểm tra commit của submodule `libs/hbb_common` từ upstream.
  - Rebase hoặc merge upstream vào fork `ngtrongha/hbb_common`.
  - Đảm bảo giữ cấu hình BVĐKKH trong `libs/hbb_common/src/config.rs`:
    `pub const RENDEZVOUS_SERVERS: &[&str] = &["172.16.3.28"];`
  - Đẩy lên GitHub và cập nhật submodule pointer trong root repository.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - Mỗi lần sync code từ RustDesk upstream, **BẮT BUỘC** thực hiện đồng bộ song song `hbb_common` trước khi trigger build. Tuân thủ mục 2 trong `release-workflow.md`.

---

### 🔴 LỖI 04: Build Rust thất bại do nhầm lẫn kiểu dữ liệu của hàm `timeout()` trong `hbb_common`

- **Ngày ghi nhận**: 2026-10-20
- **Phạm vi ảnh hưởng**: CI/CD GitHub Actions (`flutter-tag.yml`, build Windows MSVC, Android, iOS).
- **Triệu chứng (Symptom)**:
  - Quy trình build `cargo build` thất bại với mã lỗi exit code 101:
    `error[E0308]: mismatched types: expected u64, found Duration`
    `match timeout(std::time::Duration::from_millis(1500), conn.next()).await`
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. Trong Rust standard / Tokio, hàm `tokio::time::timeout(duration, future)` nhận tham số đầu tiên là `std::time::Duration`.
  2. Tuy nhiên, trong codebase RustDesk, file `src/common.rs` import hàm `timeout` từ `hbb_common::timeout`.
  3. Hàm `hbb_common::timeout<T>(ms: u64, future: T)` được định nghĩa trong `libs/hbb_common/src/lib.rs` nhận số mili-giây dạng `u64`, không phải `Duration`.
  4. Việc truyền `Duration::from_millis(1500)` làm sai kiểu dữ liệu dẫn đến trình biên dịch từ chối build.
- **Giải pháp triệt để (Resolution)**:
  - Sửa lại lệnh gọi: `timeout(1500, conn.next()).await.unwrap_or(None)`.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - Khi sử dụng hàm `timeout(...)` trong `src/common.rs` hoặc bất kỳ module nào import từ `hbb_common`, luôn truyền số nguyên mili-giây `u64` (ví dụ `1500`, `READ_TIMEOUT`, `CONNECT_TIMEOUT`). Nếu muốn dùng `Duration`, phải chỉ định rõ `tokio::time::timeout(...)`.

---

### 🔴 LỖI 05: Build Android / iOS thất bại do thiếu type annotation `Vec<Value>` khi biên dịch có điều kiện `#[cfg]`

- **Ngày ghi nhận**: 2026-10-20
- **Phạm vi ảnh hưởng**: CI/CD GitHub Actions (`flutter-tag.yml`, build Android APK, iOS IPA).
- **Triệu chứng (Symptom)**:
  - Windows và Linux build thành công, nhưng Android và iOS đồng loạt báo lỗi `exit code 101`:
    `error[E0282]: type annotations needed for Vec<T>`
    `--> src/common.rs:1748:9`
    `let mut disks_info = Vec::new();`
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. Khối code thu thập ổ đĩa `sysinfo::Disks` được bọc bởi `#[cfg(not(any(target_os = "android", target_os = "ios")))]` (để tránh treo `statvfs` trên Android FUSE storage).
  2. Trên Windows và Desktop OS, lệnh `disks_info.push(json!({...}))` được biên dịch nên trình biên dịch Rust tự động suy diễn kiểu `Vec<Value>`.
  3. Trên Android và iOS, khối `push` bị bỏ qua bởi preprocessor, trong khi biến `disks_info` vẫn được truyền vào macro `json!({"disks": disks_info})`. Do `disks_info` là `Vec::new()` rỗng không có phần tử nào được push, Rust không thể suy diễn kiểu `T` của vector.
- **Giải pháp triệt để (Resolution)**:
  - Khai báo rõ ràng kiểu dữ liệu cho vector: `let mut disks_info: Vec<Value> = Vec::new();`.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - Mọi biến `Vec::new()` rỗng dùng chung qua nhiều nền tảng với các nhánh `#[cfg]` khác nhau BẮT BUỘC phải khai báo tường minh kiểu dữ liệu (ví dụ `: Vec<Value>`, `: Vec<String>`) để tránh lỗi type inference khi biên dịch chéo cho mobile.

---

### 🔴 LỖI 06: Màn hình Desktop xuất hiện 2 shortcut trùng tên và 1 shortcut bị trắng (Icon gãy link) do phân mảnh User/Public Desktop

- **Ngày ghi nhận**: 2026-10-20
- **Phạm vi ảnh hưởng**: Windows 7 / 10 / 11, Auto Installer (`BVDKKH-Remote-AutoInstall.exe`), `create_shortcut.ps1`.
- **Triệu chứng (Symptom)**:
  - Trên màn hình Desktop xuất hiện 2 shortcut trùng tên `BVĐKKH - Remote`.
  - Một icon hiển thị logo bệnh viện bình thường, một icon hiển thị tờ giấy trắng (broken shortcut).
  - Tên hiển thị bị phân mảnh giữa `BVĐKKH` và `BVDKKH`, kèm lỗi typo `BVĐKKH - Remoter` trong `Cargo.toml` và một số file giao diện.
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. Desktop của người dùng hiển thị gộp từ cả 2 thư mục: `C:\Users\Public\Desktop` và `C:\Users\<User>\Desktop`.
  2. Các bản cài cũ từng tạo shortcut trong thư mục Desktop cá nhân của User trỏ vào đường dẫn cũ (`Program Files\RustDesk` hoặc `Program Files\BVĐKKH - Remote`). Khi bản mới cài đặt vào `Program Files\BVDKKH - Remote` và tạo shortcut trong `Public\Desktop`, shortcut cũ trong User Desktop không bị xóa, bị gãy đường dẫn TargetPath dẫn tới hiển thị icon trắng.
  3. Thiếu cơ chế dọn dẹp (`CleanOldShortcuts`) quét toàn bộ profile người dùng trước khi tạo shortcut mới.
  4. Shortcut không được gán tường minh `IconLocation = targetExe + ",0"`.
  5. Typo `Remoter` trong `ProductName` của Cargo.toml và các file cấu hình giao diện.
- **Giải pháp triệt để (Resolution)**:
  - Bổ sung hàm `CleanOldShortcuts()` trong `Program.cs` quét sạch các shortcut cũ (`BVĐKKH*`, `BVDKKH*`, `RustDesk*`) trên cả Public Desktop và User Desktop của tất cả profile.
  - Gán tường minh `shortcut.IconLocation = targetExe + ",0"` trong `CreateLnk`.
  - Gọi `SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero)` để refresh ngay lập tức icon cache của Windows Explorer.
  - Chuẩn hóa tên shortcut & giao diện là `BVĐKKH - Remote`, tên thư mục cài đặt `BVDKKH - Remote` (ASCII), sao chép đủ cả 3 file thực thi (`BVĐKKH - Remote.exe`, `BVDKKH - Remote.exe`, `rustdesk.exe`).
  - Sửa toàn bộ lỗi typo `Remoter` -> `Remote` trong `Cargo.toml`, Dart, Tis, CSS.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - Luôn xóa sạch shortcut cũ ở Desktop cá nhân người dùng trước khi ghi shortcut mới vào Public Desktop để tránh trùng lặp icon.
  - Luôn gán `IconLocation` tường minh trỏ vào file `.exe` đích.

---

### 🔴 LỖI 07: Windows Defender kích hoạt cảnh báo `Behavior:Win32/DefenseEvasion.A!ml` khi cài đặt

- **Ngày ghi nhận**: 2026-10-20
- **Phạm vi ảnh hưởng**: Windows 10 / 11, Auto Installer (`BVDKKH-Remote-AutoInstall.exe`).
- **Triệu chứng (Symptom)**:
  - Khi chạy file `BVDKKH-Remote-AutoInstall.exe` trên Desktop, Windows Defender bật popup cảnh báo mức Severe:
    `Behavior:Win32/DefenseEvasion.A!ml`
    `Category: Suspicious Behavior`
    `Details: This program is dangerous and executes commands from an attacker.`
    File cài đặt bị cô lập hoặc chặn thực thi.
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. Trong bản cập nhật trước, hàm `ConfigureFirewallRules` gọi tiến trình con `powershell.exe -NoProfile -Command "New-NetFirewallRule ... -EdgeTraversalPolicy Allow ..."` và chuỗi lệnh `netsh advfirewall` để tự động mở cổng tường lửa.
  2. Windows Defender tích hợp Antimalware Scan Interface (AMSI) và cơ chế phân tích hành vi thời gian thực dựa trên Machine Learning (`!ml`).
  3. Khi một file thực thi mới trong thư mục cá nhân (`Desktop`, `Downloads`) kích hoạt tiến trình PowerShell ẩn để thay đổi chính sách tường lửa / NAT traversal, Defender nhận định đây là hành vi đặc trưng của mã độc lẩn tránh phòng thủ (Defense Evasion - MITRE ATT&CK TA0005) và lập tức gắn cờ.
- **Giải pháp triệt để (Resolution)**:
  - Loại bỏ hoàn toàn các lệnh gọi tiến trình ngoài `powershell.exe` và `netsh.exe`.
  - Chuyển sang sử dụng trực tiếp **Windows Firewall COM API (`HNetCfg.FwPolicy2` và `HNetCfg.FWRule`)** nội bộ trong tiến trình C#.
  - Thiết lập đầy đủ các quy tắc tường lửa (Application, Service, TCP 21115-21119, UDP 21116 EdgeTraversal, WOL) qua COM interface.
  - Vì chạy in-process trực tiếp qua API chính thức của Microsoft, không sinh ra tiến trình command-line con, AMSI không bị kích hoạt và loại trừ 100% cảnh báo `DefenseEvasion.A!ml`.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - **TUYỆT ĐỐI KHÔNG** gọi `powershell.exe -Command` hay các tiện ích dòng lệnh để sửa đổi cấu hình bảo mật/tường lửa từ bên trong các công cụ thực thi `.exe`. Luôn sử dụng Win32/COM API chính quy để thực hiện cấu hình in-process.

---

### 🔴 LỖI 08: Client báo "Chưa sẵn sàng" / "Máy chủ: Chưa kết nối" do thiếu TOML nội bộ và Icon trắng do lỗi quét User Profile

- **Ngày ghi nhận**: 2026-10-20
- **Phạm vi ảnh hưởng**: Windows 7 / 10 / 11, Auto Installer (`BVDKKH-Remote-AutoInstall.exe`), Script sửa lỗi nhanh (`Fix-BVDKKH-Remote.bat`).
- **Triệu chứng (Symptom)**:
  - Bản Sciter/Portable khi chạy thủ công thì hiện "Ready" (chấm xanh), nhưng bản cài đặt chính thức (Flutter) mở lên luôn báo:
    - `Máy chủ: Chưa kết nối` (chấm đỏ)
    - `Dịch vụ: Chưa sẵn sàng` (chấm đỏ)
    - `Not ready. Please check your connection`
  - Trên màn hình Desktop xuất hiện shortcut `BVDKKH - Remote` (hoặc `BVĐKKH - Remote`) với biểu tượng tờ giấy trắng (icon gãy).
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. **Thiếu file cấu hình server nội bộ (TOML)**: Dịch vụ Windows chạy dưới quyền `LocalSystem` hoặc `LocalService`. Khi không tìm thấy file `RustDesk2.toml` / `BVĐKKH - Remote2.toml` trong `System32\config\systemprofile\AppData\Roaming\...` và `ProgramData`, tiến trình background `--server` không tải được thiết lập `custom-rendezvous-server = '172.16.3.28'` và `key = ''`. Kết quả là trạng thái trực tuyến trả về `<= 0`, client Flutter đọc qua IPC nhận `status_num = -1` (Chưa sẵn sàng).
  2. **Icon trắng do lỗi quét User Profile**: Khi `CleanOldShortcuts()` duyệt `C:\Users`, lệnh `Directory.GetDirectories(@"C:\Users")` gặp junction/thư mục hạn chế quyền (như `All Users`, `Default User`) văng ngoại lệ `UnauthorizedAccessException`. Do không bọc `try/catch` từng thư mục, toàn bộ vòng lặp bị hủy sớm, khiến shortcut cũ trên Desktop cá nhân của người dùng không bị xóa.
  3. **Race condition khi unpack**: Bộ cài tự động kill tiến trình sau 1.5s trong khi gói nén 70MB chưa kịp giải nén xong trên các máy ổ cứng HDD/cấu hình yếu.
- **Giải pháp triệt để (Resolution)**:
  - Trong `Program.cs`:
    - Thêm hàm `WriteServerConfig()`: Ghi đồng loạt file cấu hình `RustDesk2.toml`, `BVĐKKH - Remote2.toml`, `BVDKKH - Remote2.toml` chứa `custom-rendezvous-server = '172.16.3.28'`, `relay-server = '172.16.3.28'`, `key = ''`, `api-server = 'http://172.16.3.28:21114'` vào: `ProgramData`, `systemprofile`, `SysWOW64\systemprofile`, `LocalService`, User `APPDATA`, và tất cả user profiles trong `C:\Users`.
    - Chờ unpack tối đa 10s (`File.Exists`) trước khi dừng tiến trình.
    - Duyệt an toàn từng thư mục người dùng với `try/catch` độc lập và quét thêm cả `OneDrive\Desktop`.
    - Tạo song song shortcut tại cả `CommonDesktopDirectory` và `Desktop` cá nhân với `IconLocation = mainExe + ",0"`.
  - Tạo công cụ sửa chữa tức thì `Fix-BVDKKH-Remote.bat` cho IT chạy 1-click tại máy trạm.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - Khi triển khai môi trường máy chủ nội bộ, **BẮT BUỘC PHẢI GHI FILE CẤU HÌNH SERVER NỘI BỘ (TOML)** vào cả phạm vi System Service (`systemprofile`, `ProgramData`) và User GUI (`APPDATA`) trước khi kích hoạt dịch vụ.
  - Vòng lặp quét profile người dùng trên Windows bắt buộc phải dùng per-directory `try/catch` để tránh bị dừng sớm bởi các junction link.

---

### 🔴 LỖI 09: Xuất hiện 2 thư mục trùng lặp trong Program Files (BVDKKH và BVĐKKH) và 2 file .exe trong thư mục cài đặt

- **Ngày ghi nhận**: 2026-10-20
- **Phạm vi ảnh hưởng**: Windows 7 / 10 / 11, Auto Installer (`BVDKKH-Remote-AutoInstall.exe`), Script cài đặt (`cai_dat.bat`, `install_official.ps1`), Script sửa lỗi (`Fix-BVDKKH-Remote.bat`).
- **Triệu chứng (Symptom)**:
  - Trong `C:\Program Files` (hoặc `Program Files (x86)`) xuất hiện song song 2 thư mục: `BVDKKH - Remote` (không dấu ASCII) và `BVĐKKH - Remote` (có dấu Unicode).
  - Bên trong thư mục cài đặt xuất hiện đồng thời cả 2 tệp thực thi trùng lặp: `BVDKKH - Remote.exe` và `BVĐKKH - Remote.exe` (kèm `rustdesk.exe`).
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. Mã nguồn RustDesk cốt lõi (`src/common.rs`) định nghĩa `crate::get_app_name()` trả về `"BVĐKKH - Remote"`. Do đó tiến trình background và installer nội bộ của RustDesk trỏ tới `C:\Program Files\BVĐKKH - Remote`.
  2. Trong Auto Installer `Program.cs` và `cai_dat.bat`, biến `targetDir` trước đây lại được gán là `Path.Combine(pf, "BVDKKH - Remote")` (không dấu ASCII).
  3. Để "phòng ngừa gãy đường dẫn", các đoạn mã copy tệp đã sao chép `sourceExe` thành cả `BVĐKKH - Remote.exe` và `BVDKKH - Remote.exe`, đồng thời copy chéo sang cả thư mục `BVĐKKH - Remote`.
  4. Hậu quả là trên máy người dùng tồn tại đồng thời cả 2 thư mục trong `Program Files` và 2 file thực thi trùng lặp.
- **Giải pháp triệt để (Resolution)**:
  - Chuẩn hóa duy nhất 1 thư mục cài đặt chính thức: `C:\Program Files\BVĐKKH - Remote` (Unicode khớp với RustDesk core).
  - Chuẩn hóa duy nhất 1 tệp thực thi thương hiệu chính thức: `BVĐKKH - Remote.exe` (và `rustdesk.exe` cho cơ chế kỹ thuật nội bộ).
  - Trong `Program.cs`:
    - Thêm hàm `MigrateAndCleanLegacyDirectories()`: Di chuyển các file cấu hình từ thư mục cũ `BVDKKH - Remote` sang `BVĐKKH - Remote`, sau đó xóa sạch thư mục cũ `BVDKKH - Remote`.
    - Xóa tệp trùng lặp `BVDKKH - Remote.exe` nếu tồn tại trong `targetDir`.
    - Dọn dẹp subkey Registry Uninstall cũ `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\BVDKKH - Remote` và Run key cũ.
  - Đồng bộ cập nhật cơ chế xóa thư mục và tệp trùng lặp này vào `Fix-BVDKKH-Remote.bat`, `cai_dat.bat` và `install_official.ps1`.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - **TUYỆT ĐỐI KHÔNG** sao chép song song 2 file thực thi hay duy trì 2 thư mục mang cùng thương hiệu ở dạng có dấu và không dấu (ASCII và Unicode). Luôn chọn duy nhất một tên chuẩn đồng bộ với `crate::get_app_name()` (`BVĐKKH - Remote`). Mọi bản cũ khác tên phải được tự động chuyển dữ liệu (migrate) và xóa sạch thư mục cũ.

---


---

### 🔴 LỖI 10: Auto Installer báo lỗi "The specified executable is not a valid application for this OS platform" do lệch kiến trúc OS 32-bit hoặc tệp tải về bị hỏng/chặn bởi tường lửa

- **Ngày ghi nhận**: 2026-10-21
- **Phạm vi ảnh hưởng**: Windows 7 / 8 / 10 / 11 (x86 và x64), Auto Installer (`BVDKKH-Remote-AutoInstall.exe`).
- **Triệu chứng (Symptom)**:
  - Khi chạy cài đặt tự động, thanh tiến trình dừng lại ở khoảng 85% và báo lỗi đỏ:
    `✕ Quá trình cài đặt gián đoạn`
    `Lỗi: The specified executable is not a valid application for this OS platform.`
- **Nguyên nhân gốc rễ (Root Cause)**:
  1. **Lệch kiến trúc Hệ điều hành (OS) và Phần cứng (CPU)**: Hàm `GetNativeSystemInfo` nhận diện kiến trúc CPU vật lý (chip Intel/AMD 64-bit trả về `PROCESSOR_ARCHITECTURE_AMD64`). Tuy nhiên, nhiều máy trạm bệnh viện cài đặt bản Windows 10 32-bit (x86) để tương thích máy móc/phần mềm cũ. Trình cài đặt nhận định nhầm hệ điều hành là 64-bit nên tải gói `rustdesk-1.5.17-x86_64.exe`. Khi `Process.Start` gọi file thực thi 64-bit trên Windows 32-bit, Windows trả về lỗi Win32 mã 193 (`ERROR_BAD_EXE_FORMAT` -> .NET dịch thành `The specified executable is not a valid application for this OS platform`).
  2. **Tập tin tải về bị hỏng hoặc tường lửa mạng chặn tải .exe**: Mạng bệnh viện (Fortinet/Sophos/proxy) hoặc Antivirus chặn tải file `.exe` từ GitHub Releases, khiến file lưu trong `%TEMP%` là trang HTML báo lỗi mạng hoặc file 0 KB. Khi thực thi, Windows cũng trả về lỗi mã 193.
  3. **Thiếu cơ chế ưu tiên gói cục bộ**: Bản cũ không kiểm tra thư mục hiện hành hoặc thư mục `src\` có sẵn gói offline mà chuyển thẳng ra mạng.
- **Giải pháp triệt để (Resolution)**:
  - Trong `tools/auto-installer/Program.cs`:
    - `DetectEnvironment()`: Bổ sung ràng buộc `if (!Environment.Is64BitOperatingSystem) info.Arch = "x86";`. Dù CPU là gì, nếu Windows là 32-bit thì bắt buộc chỉ định `Arch = "x86"`.
    - Thêm hàm `IsValidExecutable(filePath, out errorMessage)`: Kiểm tra file tồn tại, dung lượng >= 2MB (loại trừ file rỗng và trang lỗi HTML), và đọc 2 byte đầu tiên phải là chữ ký Windows PE `MZ` (`0x4D`, `0x5A`).
    - Thêm hàm `ResolveLocalInstallerFile()`: Ưu tiên tìm kiếm các gói cài đặt có sẵn trong thư mục của Auto-Installer và thư mục con `src\` trước khi kết nối mạng LAN hoặc Internet.
    - Cập nhật `ResolveMatchingAsset()`: Với `info.Arch == "x86"`, chỉ chọn gói `x86-sciter` và fallback về `rustdesk-{ver}-x86-sciter.exe`.
    - Kiểm tra `IsValidExecutable()` trước khi thực thi tại GUI, Silent và `PerformCompleteInstall()`.
    - Cập nhật `build.bat` đồng bộ sao chép sang cả `CaiDat\BVDKKH-Remote-AutoInstall.exe`.
- **Quy tắc phòng ngừa (Prevention Rule)**:
  - Luôn kiểm tra `Environment.Is64BitOperatingSystem` để xác định chính xác năng lực thực thi nhị phân của OS, không dựa thuần túy vào thông số CPU từ `GetNativeSystemInfo`.
  - Luôn kiểm tra tính toàn vẹn nhị phân (kích thước tối thiểu và header `MZ`) của mọi file tải về hoặc giải nén trước khi gọi `Process.Start`.

## 🔄 Quy trình tự động cập nhật khi gặp lỗi mới

Khi gặp bất kỳ lỗi mới nào trong quá trình phát triển:
1. **Sau khi tìm ra nguyên nhân & cách sửa**: Thêm một mục `### 🔴 LỖI [XX]` mới vào cuối file này.
2. **Cập nhật bộ nhớ**: Thêm tóm tắt vào `.agents/memory/error-patterns.md`.
3. **Commit kèm thay đổi**: Đưa việc ghi chép này vào cùng commit sửa lỗi để lưu vết lịch sử trong Git.
