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

## 🔄 Quy trình tự động cập nhật khi gặp lỗi mới

Khi gặp bất kỳ lỗi mới nào trong quá trình phát triển:
1. **Sau khi tìm ra nguyên nhân & cách sửa**: Thêm một mục `### 🔴 LỖI [XX]` mới vào cuối file này.
2. **Cập nhật bộ nhớ**: Thêm tóm tắt vào `.agents/memory/error-patterns.md`.
3. **Commit kèm thay đổi**: Đưa việc ghi chép này vào cùng commit sửa lỗi để lưu vết lịch sử trong Git.
