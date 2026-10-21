# BÁO CÁO KHẢO SÁT HỆ THỐNG MÁY TRẠM & BỘ CÔNG CỤ TRIỂN KHAI
## DỰ ÁN "BVĐKKH - REMOTE" — BỆNH VIỆN ĐA KHOA TỈNH KHÁNH HÒA

> **Người thực hiện:** explorer_survey_1  
> **Thời gian khảo sát:** 2026-10-06  
> **Phạm vi khảo sát:** Toàn bộ phân hệ Client Workstation, kịch bản triển khai tự động (`cai_dat.bat`), động cơ kép (Sciter Win7 vs Flutter Win10/11), Windows Service, cơ chế xử lý máy Ghost/Clone MachineGuid, Wake-on-LAN, nhận diện thương hiệu hình nền bệnh viện, module phím tắt gọi hỗ trợ 1-chạm `Ctrl + Alt + H` (`BaoSuCoIT.exe`) và trình giám sát nền `ticket_watcher.ps1`.

---

## 1. TỔNG QUAN HỆ SINH THÁI MÁY TRẠM (CLIENT WORKSTATION ECOSYSTEM)

Phân hệ máy trạm của giải pháp điều khiển từ xa nội bộ **BVĐKKH - Remote** được thiết kế nhằm đáp ứng tính đặc thù cao trong môi trường bệnh viện:
1. **Phổ thiết bị đa dạng và phân mảnh:** Tồn tại song song các máy tính y tế đời cũ (Windows 7 SP1 32-bit & 64-bit đi kèm máy xét nghiệm huyết học, sinh hóa, máy siêu âm, X-quang, CT/MRI) và các máy trạm hiện đại (Windows 10/11 x64, ARM64 tại các phòng khám, khối hành chính, phòng mổ, ban giám đốc).
2. **Yêu cầu ổn định tuyệt đối (High Availability):** Hoạt động liên tục dưới dạng dịch vụ hệ thống nền (Windows Service), tự phục hồi tức thì sau sự cố treo hoặc lỗi mạng mà không làm gián đoạn công tác khám chữa bệnh.
3. **An toàn bảo mật nội bộ 100%:** Tự động khóa toàn diện giao diện client (ngăn chặn nhân viên y tế tự ý sửa ID, đổi mật khẩu, ngắt dịch vụ, hay đổi IP máy chủ).
4. **Hỗ trợ kỹ thuật 1-chạm (One-Touch Helpdesk):** Tích hợp công cụ tiếp nhận sự cố kỹ thuật thông qua phím tắt toàn cục `Ctrl + Alt + H`, tự động nhận diện ID máy, phân loại sự cố, đính kèm ảnh lỗi/nhật ký và đẩy trực tiếp về máy chủ quản trị nội bộ `172.16.3.28`.

---

## 2. KIẾN TRÚC ĐỘNG CƠ KÉP (DOUBLE ENGINE ARCHITECTURE)

Dự án triển khai chiến lược **Dual Engine** chuyên biệt theo từng nhóm hệ điều hành:

```
                      ┌──────────────────────────────────────────────┐
                      │    HỆ ĐIỀU HÀNH MÁY TRẠM (cai_dat.bat)       │
                      └──────────────────────┬───────────────────────┘
                                             │
                    Phát hiện CurrentMajorVersionNumber trong Registry
                                             │
                    ┌────────────────────────┴────────────────────────┐
                    ▼                                                 ▼
       [Legacy OS: Win 7 / 8 / 8.1]                       [Modern OS: Win 10 / 11]
                    │                                                 │
        ĐỘNG CƠ SCITER (TIScript/GDI+)                     ĐỘNG CƠ FLUTTER (GPU DirectWrite)
  ┌─────────────────┴─────────────────┐             ┌─────────────────┴─────────────────┐
  ▼                                   ▼             ▼                                   ▼
Win7 x86 (32-bit)              Win7 x64 (64-bit)   Win10/11 x64                      Win11 ARM64
rustdesk-*-x86-sciter.exe      rustdesk-*-win7.exe rustdesk-*-x86_64.exe             rustdesk-*-aarch64.exe
(Máy xét nghiệm, siêu âm cũ)   (Máy chẩn đoán)     (PC phòng khám, văn phòng)        (Laptop thế hệ mới Copilot+)
```

### 2.1. Động cơ Sciter cho Windows 7 SP1 (32-bit & 64-bit)
- **Tập tin phân phối:**
  - `CaiDat/src/rustdesk-1.5.12-win7-x86_64.exe` (26,860,544 bytes) — Dành cho Windows 7 64-bit.
  - `CaiDat/src/rustdesk-1.5.12-x86-sciter.exe` (13,682,688 bytes) — Dành cho Windows 7 32-bit (x86).
- **Thư viện đính kèm:** `sciter.dll`.
- **Nhánh mã nguồn & Build:** Nhánh `win7-lts`. Sử dụng Rust toolchain `1.75` (cố định để tương thích ABI layout và crate `sciter-rs` nhánh `dyn`).
- **Giao diện người dùng:** Được dựng bằng HTML/CSS và TIScript (`src/ui/*.tis`: `index.tis`, `remote.tis`, `cm.tis`, `ab.tis`, `common.tis`).
- **Lý do lựa chọn Sciter cho y tế:**
  - Các hệ thống máy y tế như máy sinh hóa tự động (Hitachi/Roche), máy huyết học (Sysmex), máy X-quang kỹ thuật số thường chạy hệ điều hành Windows 7 Embedded/SP1 nhúng sâu vào phần cứng máy xét nghiệm, RAM chỉ 2GB - 4GB, không có card đồ họa rời và không hỗ trợ DirectX 11/DirectWrite mới.
  - Sciter kết xuất trực tiếp qua GDI+/Direct2D truyền thống, tiêu tốn cực ít bộ nhớ RAM (< 40MB), khởi động gần như tức thì, hoạt động ổn định và không phụ thuộc vào các runtime WinRT/DirectX hiện đại.

### 2.2. Động cơ Flutter cho Windows 10/11 (x64 & ARM64)
- **Tập tin phân phối:**
  - `CaiDat/src/rustdesk-1.5.12-x86_64.exe` (27,395,072 bytes) — Dành cho Windows 10/11 64-bit.
  - `rustdesk-1.5.11-aarch64.exe` — Dành cho Windows 11 nền tảng kiến trúc ARM64 (Snapdragon X Elite, Surface Pro ARM).
- **Nhánh mã nguồn & Build:** Nhánh `feat/upgrade-flutter-win10`.
- **Môi trường biên dịch (CI/CD GitHub Actions):**
  - Flutter SDK `3.47.4` với engine Windows gốc (Stock native Windows engine).
  - Cầu nối FFI: `flutter_rust_bridge = "=1.80"`.
  - Compiler: LLVM/Clang `15.0.6`, MSVC, vcpkg triplets `x64-windows-static` và `arm64-windows-static`.
  - Flags biên dịch: `--portable --flutter --skip-portable-pack --hwcodec --vram` (bản x64 kích hoạt thêm VRAM hardware codec NVENC/Intel/AMD).
- **Đặc tính kỹ thuật:** Giao diện đồ họa phẳng Fluent hiện đại, tăng tốc phần cứng GPU, hỗ trợ màn hình độ phân giải cao 2K/4K/HiDPI tại các phòng đọc kết quả PACS, quản lý đa phiên kết nối dạng tab (Multi-tab remote sessions).

---

## 3. KỊCH BẢN TRIỂN KHAI TỰ ĐỘNG 1-CLICK (`cai_dat.bat`)

Tệp thực thi cài đặt trung tâm đặt tại: `CaiDat\cai_dat.bat` (kích thước 46,497 bytes, 891 dòng mã).

### 3.1. Cơ chế nâng quyền Administrator tự động (UAC Auto-Elevation)
Script hỗ trợ tương thích từ Windows 7 đến Windows 11 với thuật toán kiểm tra quyền quản trị 5 lớp an toàn:
```bat
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
reg query "HKU\S-1-5-19" >nul 2>&1
fsutil dirty query %systemdrive% >nul 2>&1
fltmc >nul 2>&1
net session >nul 2>&1
```
Nếu chưa có quyền Admin, script tự gọi PowerShell để kích hoạt hộp thoại UAC yêu cầu cấp quyền mà không cần người dùng phải bấm chuột phải chọn "Run as administrator":
```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList @('/k', [char]34 + $env:ELEVATE_TARGET + [char]34 + ' ' + $env:ELEVATE_ARGS) -Verb RunAs"
```

### 3.2. Thuật toán nhận diện Hệ điều hành & Kiến trúc phần cứng
1. **Kiểm tra kiến trúc CPU thực tế:**
   - Đọc trực tiếp từ Registry `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\PROCESSOR_ARCHITECTURE` (giúp nhận diện chuẩn xác máy ARM64 kể cả khi script chạy dưới tiến trình WoW64 mô phỏng).
   - Phân loại: `x64`, `arm64`, `x86`.
2. **Kiểm tra phiên bản Windows:**
   - Truy vấn giá trị `CurrentMajorVersionNumber` tại `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion`.
   - Nếu tồn tại giá trị: Xác định là `OS_MODE=modern` (Windows 10/11).
   - Nếu không tồn tại: Xác định là `OS_MODE=legacy` (Windows 7, 8, 8.1).
3. **Khớp gói cài đặt tự động:**
   - `modern` + `arm64` -> Chọn `rustdesk-*-aarch64.exe`
   - `modern` + `x64`   -> Chọn `rustdesk-1.5.12-x86_64.exe`
   - `legacy` + `x64`   -> Chọn `rustdesk-1.5.12-win7-x86_64.exe`
   - `legacy` + `x86`   -> Chọn `rustdesk-1.5.12-x86-sciter.exe`

### 3.3. Các tham số dòng lệnh hỗ trợ (CLI Flags)
| Cờ lệnh (Flag) | Mục đích sử dụng |
|---|---|
| `--check` | Kiểm tra trạng thái hệ thống hiện tại (trạng thái Service, file toml, kết nối relay port 21116, RustDesk ID hiện có) mà không cài đặt đè. |
| `--silent` / `-s` | Chế độ cài đặt âm thầm (Unattended mode), không hiển thị `pause`, tự động thoát với exit code 0 khi thành công. |
| `--new` | Buộc cài đặt phiên bản thương hiệu mới `BVĐKKH - Remote` (Mặc định). |
| `--old` | Cài đặt chế độ tương thích phiên bản RustDesk gốc. |
| `--reset-guid` / `--reset-id` / `--fix-clone` | Buộc sinh lại `MachineGuid` mới và xóa danh tính cũ để tạo ID độc lập (Dành cho máy Ghost). |
| `--clean-old` / `--clean` / `--migrate` | Chỉ thực hiện dọn dẹp toàn diện dịch vụ cũ, shortcut cũ, registry cũ mà không cài mới. |

### 3.4. Quá trình giải nén Portable & Đồng bộ thư mục cài đặt
- Do tất cả bộ cài đặt RustDesk Windows là gói nén tự giải nén (Portable Packer), script chủ động kích hoạt lệnh trích xuất:
  `"%RUSTDESK_FILE%" --version`
- Tự động lấy các tệp binary và phụ thuộc từ thư mục tạm `%LOCALAPPDATA%\rustdesk\` hoặc `%USERPROFILE%\AppData\Local\rustdesk\`.
- Sử dụng `xcopy` đồng bộ toàn bộ vào thư mục đích chính thức:
  `C:\Program Files\BVDKKH - Remote\` (hoặc `Program Files (x86)` trên máy 32-bit).
- Khởi tạo đồng thời 3 tệp alias để đảm bảo tương thích tuyệt đối cho cả lệnh dòng lệnh và lời gọi nội bộ:
  - `BVDKKH - Remote.exe`
  - `BVĐKKH - Remote.exe`
  - `rustdesk.exe`
- Sao chép toàn bộ bộ công cụ tiện ích đi kèm: `BaoSuCoIT.exe`, `support_dialog.ps1`, `ticket_watcher.ps1`, `support_launcher.vbs`, `icon.ico`.

### 3.5. Đăng ký Cài đặt Chính thức (`install_official.ps1`)
RustDesk có cơ chế kiểm tra `is_installed()` bằng cách đọc Registry:
- `HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\BVDKKH - Remote`
- `HKLM:\Software\BVDKKH - Remote\InstallState\BVDKKH - Remote`

Nếu không đăng ký 2 khóa này, ứng dụng sẽ luôn coi mình là bản **Portable** chạy tạm thời và bật cảnh báo UAC hoặc thanh nhắc nhở cài đặt khó chịu.  
Script `install_official.ps1` thực hiện:
1. Đăng ký đầy đủ thông tin gỡ cài đặt (DisplayName: `BVĐKKH - Remote`, Publisher: `Bệnh viện Đa khoa Khánh Hòa`, DisplayIcon, Version `1.5.11`, BuildDate tự động trích xuất bằng `--build-date`, NoModify=1, NoRepair=1).
2. Đăng ký `InstallLocation` và `BuildDate` trong `InstallState`.
3. Đăng ký phần mở rộng tệp `.rustdesk`, `.bvdkkh` và giao thức URL Protocol `rustdesk://`, `bvdkkh://`.
4. Bật chính sách Windows Remote Session SAS:
   `HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\SoftwareSASGeneration = 1`
   (Cho phép điều khiển gửi tổ hợp phím `Ctrl + Alt + Del` vào màn hình khóa máy trạm từ xa).
5. Đăng ký tự khởi động khay hệ thống (Tray):
   `HKLM:\Software\Microsoft\Windows\CurrentVersion\Run\BVDKKH - Remote = "\"%rdExe%\" --tray"`

---

## 4. KHÓA AN TOÀN GIAO DIỆN & CẤU HÌNH BẢO MẬT (UI LOCKDOWN)

Để ngăn ngừa nhân viên y tế hoặc người dùng tại khoa phòng vô tình hoặc cố ý can thiệp làm gián đoạn kênh hỗ trợ từ xa của phòng CNTT, hệ thống áp dụng cơ chế khóa an toàn đa tầng:

```
                  ┌─────────────────────────────────────────────────────────┐
                  │          CƠ CHẾ KHÓA BẢO MẬT ĐA TẦNG                    │
                  └────────────────────────────┬────────────────────────────┘
                                               │
               ┌───────────────────────────────┴───────────────────────────────┐
               ▼                                                               ▼
    [TẦNG 1: NGUỒN CỨNG BINARY]                                    [TẦNG 2: CLI OPTIONS TẠI CÀI ĐẶT]
    (Mã nguồn Rust: src/common.rs)                                 (cai_dat.bat & write_config.ps1)
    - Hardcoded IP: 172.16.3.28                                    - Đặt mật khẩu vĩnh viễn: Bvdkkh@2026
    - Hardcoded PubKey: 0RtoIpto...                                - Đặt Unlock PIN bảo vệ: Bvdkkh@2026
    - Hardcoded Api: http://172.16.3.28:21114                      - verification-method use-permanent-password
    - BUILTIN_SETTINGS:                                            - approve-mode password
        hide-server-settings = Y                                   - allow-remote-config-modification N
        hide-network-settings = Y                                  - hide-server-settings Y
        hide-proxy-settings = Y                                    - hide-security-settings Y
        hide-websocket-settings = Y                                - hide-proxy-settings Y
        hide-stop-service = Y                                      - hide-websocket-settings Y
        disable-change-id = Y                                      - hide-stop-service Y
        disable-change-permanent-password = Y                      - disable-change-permanent-password Y
        allow-remote-config-modification = N                       - disable-change-id Y
        app-name = "BVĐKKH - Remote"                               - allow-remove-wallpaper N
```

### 4.1. Chi tiết các chính sách khóa được áp dụng:
1. **Khóa máy chủ cố định:** Ẩn toàn bộ mục cài đặt mạng (Server/ID/Relay/API Settings). Toàn bộ kết nối hướng thẳng về IP nội bộ viện `172.16.3.28` (Port 21116/21117) và Public Key `0RtoIptoH30Glx75q0DuScwdUgLVwf5oqZ0hgCnInNI=`.
2. **Cấm sửa ID (`disable-change-id Y`):** Nút chỉnh sửa ID trên giao diện bị khóa/ẩn, đảm bảo ID thiết bị luôn gắn liền với mã định danh máy tính trong sổ địa chỉ quản lý.
3. **Cấm sửa mật khẩu vĩnh viễn (`disable-change-permanent-password Y`):** Người dùng khoa phòng không thể tự ý đổi mật khẩu truy cập của IT.
4. **Cấm dừng dịch vụ (`hide-stop-service Y`):** Ẩn nút "Dừng dịch vụ" (Stop Service) trên giao diện Client.
5. **Cấm can thiệp cấu hình từ xa (`allow-remote-config-modification N`):** Ngăn ngừa việc ghi đè cấu hình bảo mật bất hợp pháp qua kết nối ngoài.
6. **Cấm tắt hình nền bệnh viện (`allow-remove-wallpaper N`):** Ngăn client xóa hoặc làm mất hình nền định danh trong phiên điều khiển.

---

## 5. DỊCH VỤ HỆ THỐNG NỀN & TỰ PHỤC HỒI (WINDOWS SERVICE & WATCHDOG)

- **Tên dịch vụ hệ thống (Service Name):** `BVDKKH - Remote`
- **Tên hiển thị (Display Name):** `BVĐKKH - Remote Service`
- **Đường dẫn thực thi:** `"%ProgramFiles%\BVDKKH - Remote\BVDKKH - Remote.exe" --service`
- **Kiểu khởi động:** Tự động theo hệ thống (`start= auto`).

### 5.1. Cấu hình tự động phục hồi lỗi (Watchdog Failure Recovery)
Được thiết lập chuẩn xác qua lệnh `sc.exe failure`:
```bat
sc.exe failure "BVDKKH - Remote" reset= 86400 actions= restart/5000/restart/15000/restart/60000
```
- **Lần gặp sự cố thứ nhất:** Tự động khởi động lại sau 5 giây (5,000 ms).
- **Lần gặp sự cố thứ hai:** Tự động khởi động lại sau 15 giây (15,000 ms).
- **Lần gặp sự cố thứ ba trở đi:** Tự động khởi động lại sau 60 giây (60,000 ms).
- **Chu kỳ reset bộ đếm sự cố:** Sau 24 giờ liên tục hoạt động bình thường (`reset= 86400` giây).

### 5.2. Hàm giám sát chuyển trạng thái thông minh (`:WAIT_SERVICE_STATUS`)
- Trong `cai_dat.bat`, hàm `:WAIT_SERVICE_STATUS` không chỉ đợi thông thường mà tích hợp cơ chế tự giải phóng tiến trình treo:
  - Nếu yêu cầu `Stopped` mà sau 3 giây service vẫn chưa dừng (thường do Windows Service bị deadlock port hoặc driver kẹt): hàm sử dụng WMI `Win32_Service` tìm Process ID và gọi `Stop-Process -Force` để tiêu diệt ngay tiến trình bị treo.
  - Nếu yêu cầu `Running` mà sau 3 giây service chưa chạy: tự động thử lại (Retry) tối đa 3 lần.

---

## 6. XỬ LÝ TRÙNG LẶP ID TRÊN MÁY GHOST / CLONE WINDOWS (MACHINEGUID CLONE FIX)

### 6.1. Thực trạng & Nguyên nhân gốc rễ
- Tại các bệnh viện lớn, hàng trăm máy tính thường được cài đặt bằng cách bung bản sao lưu hàng loạt (Ghost file `.GHO`, Acronis `.tib`, hoặc nhân bản máy ảo).
- Quá trình này dẫn đến việc tất cả các máy trạm có cùng một mã `MachineGuid` duy nhất trong Windows Registry tại:
  `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid`
- Mã Ghost mẫu điển hình được phát hiện trong mã nguồn:
  - `6c2a494b-5097-4a52-8d10-028ec947b421` (Bản Ghost Windows chuẩn phổ biến tại Việt Nam)
  - `d18b2b18-0000-0000-0000-000000000000` (Bản nhân bản máy ảo lỗi)
- Vì RustDesk sử dụng `MachineGuid` kết hợp mã băm phần cứng để sinh ra ID máy và cặp khóa mã hóa (`enc_id`, `key_pair`), nên các máy bị Clone sẽ **sinh ra cùng một RustDesk ID**, gây ra hiện tượng "tranh chấp phiên", máy nọ đá văng máy kia trên Server điều khiển.

### 6.2. Cơ chế giải quyết trong `cai_dat.bat` và `write_config.ps1`
1. **Kiểm tra phát hiện tự động:**
   Script đọc giá trị `MachineGuid` hiện tại. Nếu khớp với danh sách mã Ghost mẫu, hoặc rỗng, hoặc có cờ `--reset-guid` / `--fix-clone`:
2. **Tái tạo MachineGuid mới:**
   Tạo GUID ngẫu nhiên mới độc lập bằng .NET API:
   ```powershell
   $newG = [guid]::NewGuid().ToString().ToLower()
   Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name 'MachineGuid' -Value $newG -Force
   ```
3. **Xóa sạch danh tính cũ:**
   Xóa toàn bộ các tệp `.toml` cũ tại thư mục hệ thống và thư mục dự phòng (`%ProgramData%\BVDKKH - Remote\backup`, `RustDesk\backup`).
4. **Bảo tồn ID đối với máy chuẩn (Non-Ghost):**
   Nếu máy có `MachineGuid` hợp lệ (không phải bản Clone), tệp `write_config.ps1 -BackupOnly` sẽ chủ động trích xuất và bảo toàn các trường `enc_id`, `key_pair`, `id` cũ sang `%ProgramData%\BVDKKH - Remote\config\BVDKKH - Remote.toml`, đảm bảo quá trình nâng cấp phần mềm không làm thay đổi ID máy trạm của khoa phòng.

---

## 7. CẤU HÌNH TỰ ĐỘNG WAKE-ON-LAN (WOL)

Tệp script: `CaiDat\src\enable_wol.ps1` (173 dòng mã).

Để kỹ thuật viên phòng CNTT có thể khởi động máy trạm y tế từ xa ngoài giờ làm việc hoặc trước ca trực để bảo trì/cập nhật phần mềm, script kích hoạt Wake-on-LAN qua 5 bước:

1. **Vô hiệu hóa Fast Startup (Khởi động nhanh):**
   - Trên Windows 10/11, tính năng "Fast Startup" đưa máy về trạng thái Hybrid Shutdown (S4) làm ngắt toàn bộ nguồn nuôi card mạng (NIC).
   - Script thiết lập:
     `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power\HiberbootEnabled = 0`
     nhằm duy trì nguồn điện dự phòng cho cổng mạng Ethernet khi máy tắt (S5).
2. **Cấu hình qua module NetAdapter (Windows 8/10/11):**
   - Kích hoạt `Enable-NetAdapterPowerManagement -WakeOnMagicPacket`.
   - Bật toàn bộ các thuộc tính nâng cao của driver: `*WakeOnMagicPacket=1`, `*WakeOnPattern=1`, `WakeOnLink=1`, `EnablePME=1`, `ShutdownWake=1`, `WakeUp=1`.
3. **Cấu hình trực tiếp vào Registry Driver Class (Hỗ trợ tốt Windows 7):**
   - Can thiệp trực tiếp vào khóa Driver mạng:
     `HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}`
   - Thiết lập giá trị then chốt: `PnPCapabilities = 0` (Cho phép thiết bị phần cứng đánh thức máy tính từ trạng thái nghỉ).
4. **Kích hoạt qua WMI:**
   - Truy vấn `root\wmi:MSPower_DeviceWakeEnable` và gán thuộc tính `Enable = true`.
5. **Mở tường lửa Windows tiếp nhận Magic Packet:**
   - Tạo Firewall Rule cho phép gói tin UDP đến cổng 7 và 9:
     `netsh advfirewall firewall add rule name="RustDesk - Wake on LAN (WOL)" dir=in action=allow protocol=UDP localport=7,9 profile=any`
6. **Đánh dấu Idempotency:**
   - Ghi khóa `HKLM:\SOFTWARE\BVDKH\WOL_Configured = 1` để các lần chạy sau tự động bỏ qua nếu hệ thống đã được cấu hình chuẩn.

---

## 8. HÌNH NỀN NHẬN DIỆN THƯƠNG HIỆU & HIỂN THỊ TÊN MÁY TRẠM

Tệp script: `CaiDat\src\set_wallpaper.ps1` (231 dòng mã) kết hợp hình ảnh gốc `CaiDat\src\hinh_nen.jpg`.

### 8.1. Thuật toán vẽ Tên máy tự động (GDI+ Auto-Fit Rendering)
- **Đọc tên máy trạm:** `$env:COMPUTERNAME` (hoặc `[System.Environment]::MachineName`).
- **Nạp thư viện đồ họa .NET `System.Drawing`:** Tương thích từ .NET 2.0/3.5 (Windows 7) đến .NET 4.x/5.x (Windows 10/11).
- **Màu sắc & Phông chữ nhận diện:**
  - Màu chữ: Xanh dương thương hiệu bệnh viện `#296AC4` (`RGB(41, 106, 204)`).
  - Phông chữ: `Segoe UI Bold` (Tự động fallback sang `Arial Bold` trên Windows 7 cũ nếu thiếu font).
  - Khử răng cưa: `TextRenderingHint::AntiAliasGridFit` và `SmoothingMode::AntiAlias`.
- **Cơ chế tự co giãn chữ (Auto-fit):**
  - Chiều rộng vùng trống trên hình nền được khống chế tối đa `maxWidth = 255px`.
  - Nếu tên máy dài (ví dụ: `KHOA-CAPCUU-MAY01`), thuật toán tự động giảm cỡ chữ từ 22px xuống dần (tối thiểu 11px) để chữ luôn nằm vừa vặn, ngay ngắn trên dòng kẻ quy định của hình nền bệnh viện.
- **Xuất file kép (Dual Format Output):**
  1. `C:\ProgramData\BVDKH\wallpaper.jpg` (JPEG chất lượng cao Quality 95) — Dùng cho Windows 10/11 và cache `TranscodedWallpaper`.
  2. `C:\ProgramData\BVDKH\wallpaper.bmp` (Bitmap 24-bit không nén) — **Yêu cầu bắt buộc trên Windows 7** vì Win32 API `SystemParametersInfo` trên Windows 7 chỉ áp dụng hình nền lập tức khi nguồn là tệp BMP.

### 8.2. Áp dụng hình nền & Khóa chính sách nhóm (Group Policy Lockdown)
- **Áp dụng tức thì không cần khởi động lại:**
  Sử dụng Win32 API qua C# P/Invoke:
  `SystemParametersInfo(0x0014, 0, path, 0x01 | 0x02)` (`SPI_SETDESKWALLPAPER`, `SPIF_UPDATEINIFILE | SPIF_SENDCHANGE`).
- **Khóa quyền đổi hình nền (Ngăn nhân viên tự đổi ảnh cá nhân):**
  - Ghi Registry Group Policy:
    `HKLM` & `HKCU` `Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop\NoChangingWallPaper = 1`
  - Khóa tệp hình nền hệ thống:
    `HKLM` & `HKCU` `Software\Microsoft\Windows\CurrentVersion\Policies\System\Wallpaper = "C:\ProgramData\BVDKH\wallpaper.bmp"`
    `WallpaperStyle = "2"` (Chế độ hiển thị vừa khít toàn màn hình - Stretched).

---

## 9. MODULE GỌI HỖ TRỢ 1-CHẠM `Ctrl + Alt + H` (`BaoSuCoIT.exe`) & TRÌNH THEO DÕI NỀN

### 9.1. Trình lắng nghe phím tắt toàn cục `BaoSuCoIT.exe`
- **Mã nguồn:** `CaiDat\src\BaoSuCoIT.cs` (499 dòng C#, biên dịch ra `BaoSuCoIT.exe` 132 KB).
- **Cơ chế khởi động ngầm:**
  - Được script cài đặt khởi chạy với tham số: `BaoSuCoIT.exe --listen`.
  - Đăng ký tự chạy cùng Windows tại:
    `HKLM:\Software\Microsoft\Windows\CurrentVersion\Run\BaoSuCoIT = "\"C:\Program Files\BVDKKH - Remote\BaoSuCoIT.exe\" --listen"`
  - Tạo shortcut chạy nền trong Startup: `BaoSuCoIT_Listener.lnk` (Chạy ở chế độ Minimized).
- **Cơ chế bẫy phím tắt toàn cục 2 lớp (Dual-Hook):**
  1. **Lớp 1 (Ưu tiên):** Low-Level Keyboard Hook (`SetWindowsHookEx(WH_KEYBOARD_LL = 13)`). Theo dõi các thông điệp `WM_KEYDOWN` và `WM_SYSKEYDOWN`. Khi phát hiện phím `H` (`0x48`) đồng thời nhấn `Ctrl` và `Alt` (và không kèm phím Windows hay Shift), hook sẽ kích hoạt bảng báo sự cố và tiêu thụ luôn sự kiện phím (trả về 1 để hệ thống không phát tiếng kêu "beep").
  2. **Lớp 2 (Dự phòng):** Cửa sổ native ẩn (`HWND_MESSAGE`) đăng ký API `RegisterHotKey(hWnd, 9001, MOD_CONTROL | MOD_ALT, VK_H)`.
  3. **Vượt rào cách ly đặc quyền UIPI (User Interface Privilege Isolation):** Gọi API `ChangeWindowMessageFilter(0x0312, 1)` (cho phép nhận thông điệp `WM_HOTKEY` kể cả khi có ứng dụng khác đang chạy ở quyền Admin cao hơn).
- **Chống spam phím (Debounce):** Khống chế khoảng cách giữa 2 lần bấm tối thiểu 1.5 giây (1,500 ms).
- **Đưa cửa sổ lên trên cùng (Foreground Focus):** Nếu bảng báo sự cố đang mở, chương trình tự động khôi phục kích thước (`ShowWindow(SW_RESTORE)`) và sử dụng kỹ thuật `AttachThreadInput` để cưỡng ép cửa sổ hiện lên trên cùng màn hình của bác sĩ.

### 9.2. Hộp thoại Báo Sự Cố IT (`support_dialog.ps1`)
- **Mã nguồn:** `CaiDat\src\support_dialog.ps1` (530 dòng PowerShell).
- **Giao diện:** Thiết kế WinForms chuyên nghiệp, kích thước 520x660 px, nền xám sáng nhã nhặn, gắn icon bệnh viện riêng biệt trên Taskbar qua `SetCurrentProcessExplicitAppUserModelID('BVDKKH.ITSupport.HelpDesk')`.
- **Dữ liệu tự động nhận diện:**
  - Tên máy tính (`$env:COMPUTERNAME`)
  - Người dùng đăng nhập (`$env:USERNAME`)
  - Hệ điều hành (`ProductName`)
  - **RustDesk ID** (Tự động đọc từ các tệp cấu hình `.toml` hoặc gọi `--get-id`).
- **Nội dung người dùng nhập:**
  - **Phân loại sự cố (Category Enum):**
    1. Phần mềm Bệnh viện (HIS / LIS / PACS) -> `his_lis`
    2. Lỗi Máy In / Không in được phiếu -> `printer`
    3. Mất mạng / Không kết nối được Internet -> `network`
    4. Máy tính bị chậm / Treo máy -> `slow_pc`
    5. Cần cài đặt phần mềm mới -> `software_install`
    6. Sự cố phần cứng / Khác -> `hardware_other`
  - **Mức độ ưu tiên:** Checkbox "Sự cố KHẨN CẤP (Khoa Cấp Cứu / Phòng Mổ / Tiếp Đón)" -> Gán cờ `priority = "urgent"` (Mặc định: `normal`).
  - **Đính kèm tập tin:** Hỗ trợ chọn tối đa 5 tệp (ảnh chụp màn hình lỗi, file scan, log), mỗi tệp tối đa 10MB.
  - **Nhật ký tự động:** Trích xuất tự động 50 dòng log gần nhất từ tệp log của RustDesk đẩy kèm phiếu.
- **Phương thức gửi:** Đóng gói dạng `multipart/form-data`, gửi HTTP POST tới máy chủ API:
  `POST http://172.16.3.28:21114/api/support/ticket`
- **Khởi chạy Watcher:** Ngay sau khi gửi thành công và nhận về `ticket_id`, hộp thoại tự động khởi chạy tiến trình ngầm `ticket_watcher.ps1`.

### 9.3. Trình giám sát phản hồi nền (`ticket_watcher.ps1`)
- **Mã nguồn:** `CaiDat\src\ticket_watcher.ps1` (227 dòng PowerShell).
- **Cách thức hoạt động:** Chạy ngầm hoàn toàn không hiện cửa sổ (`-WindowStyle Hidden`), định kỳ mỗi 10 giây gửi request kiểm tra trạng thái ticket:
  `GET http://172.16.3.28:21114/api/support/ticket/latest?device_id=$DeviceId`
- **Phát thông báo Toast / Âm thanh:**
  1. **Khi IT tiếp nhận (`status = "assigned"` hoặc `"in_progress"`):**
     - Windows 10/11: Hiện thông báo góc màn hình (Windows Runtime Toast Notification) kèm âm thanh nhắc nhở:
       *Tiêu đề:* `[BVĐKKH IT] Tiếp nhận sự cố #ID`  
       *Nội dung:* `[Tên kỹ thuật viên] đã tiếp nhận và đang hỗ trợ xử lý sự cố của bạn.`
     - Windows 7/8: Tự động fallback sang bóng thông báo System Tray (BalloonTip) kết hợp chuông hệ thống `SystemSounds::Asterisk`.
  2. **Khi IT xử lý xong (`status = "resolved"` hoặc `"closed"`):**
     - Hiện thông báo Toast hoàn thành kèm phản hồi/hướng dẫn của kỹ thuật viên (`resolution_note`).
     - Tự động hủy tiến trình ngầm để giải phóng tài nguyên CPU/RAM.

---

## 10. TỔNG HỢP DANH MỤC THÔNG SỐ & TẬP TIN DỰ ÁN

| Hạng mục kỹ thuật | Giá trị / Đường dẫn trong dự án |
|---|---|
| **Máy chủ Điều khiển & Relay** | IP: `172.16.3.28` (Port: `21116` TCP/UDP, Port Relay: `21117`) |
| **Máy chủ API Quản trị** | `http://172.16.3.28:21114` |
| **Khóa công khai (Public Key)** | `0RtoIptoH30Glx75q0DuScwdUgLVwf5oqZ0hgCnInNI=` |
| **Thư mục cài đặt mặc định** | `C:\Program Files\BVDKKH - Remote\` |
| **Tệp thực thi chính** | `BVDKKH - Remote.exe` (Alias: `BVĐKKH - Remote.exe`, `rustdesk.exe`) |
| **Tên Dịch vụ Windows** | `BVDKKH - Remote` (Display: `BVĐKKH - Remote Service`) |
| **Mật khẩu mặc định / PIN** | `Bvdkkh@2026` (Đang chuẩn bị chuyển đổi sang HMAC-SHA256 mỗi máy 1 pass) |
| **Cổng tiếp nhận WOL** | UDP Port `7` và `9` |
| **Cổng tiếp nhận Ticket** | `POST http://172.16.3.28:21114/api/support/ticket` |
| **Tệp kịch bản cài đặt trung tâm** | `CaiDat\cai_dat.bat` |
| **Tệp đăng ký hệ thống chính thức** | `CaiDat\src\install_official.ps1` |
| **Tệp cấu hình & giữ ID** | `CaiDat\src\write_config.ps1` |
| **Tệp tạo hình nền định danh** | `CaiDat\src\set_wallpaper.ps1` & `CaiDat\src\hinh_nen.jpg` |
| **Tệp cấu hình Wake-on-LAN** | `CaiDat\src\enable_wol.ps1` |
| **Tệp tạo Shortcut & Phím tắt** | `CaiDat\src\create_shortcut.ps1` |
| **Tệp thực thi bắt phím tắt** | `CaiDat\src\BaoSuCoIT.exe` (Mã nguồn: `CaiDat\src\BaoSuCoIT.cs`) |
| **Tệp giao diện Báo Sự Cố** | `CaiDat\src\support_dialog.ps1` |
| **Tệp theo dõi thông báo Toast** | `CaiDat\src\ticket_watcher.ps1` |
| **Nhánh phát triển Windows 10/11** | `feat/upgrade-flutter-win10` |
| **Nhánh phát triển Windows 7** | `win7-lts` |
| **Quy trình Build CI/CD** | `.github/workflows/flutter-tag.yml` qua `rustdesk\trigger_build.ps1` |

---

## 11. KẾT LUẬN & ĐÁNH GIÁ CHUYÊN MÔN

Hệ sinh thái máy trạm của giải pháp **BVĐKKH - Remote** thể hiện sự đầu tư kỹ lưỡng, bài bản và am hiểu sâu sắc về thực tế vận hành CNTT y tế:
- **Tính tự chủ và đóng gói hoàn thiện:** Kịch bản `cai_dat.bat` là một giải pháp triển khai "All-in-One", chỉ với 1 cú click chuột đã giải quyết toàn bộ các bài toán hóc búa của hệ thống: phát hiện kiến trúc, chọn đúng động cơ Sciter/Flutter, xử lý triệt để lỗi trùng ID máy Ghost, khóa an toàn giao diện, cấu hình Wake-on-LAN, áp dụng hình nền thương hiệu bệnh viện và cài đặt hệ thống báo sự cố 1-chạm.
- **Tính khả thi và độ tin cậy thực tế:** Mọi thành phần đều có phương án dự phòng (Fallback) từ PowerShell 2.0 / Windows 7 SP1 đến PowerShell 5.1+ / Windows 11; từ Win32 API đến .NET GDI+; từ Low-Level Keyboard Hook đến RegisterHotKey; từ Windows Runtime Toast đến BalloonTip.
- **Sẵn sàng cho tài liệu hóa phê duyệt:** Toàn bộ bằng chứng khảo sát trên cung cấp nguồn dữ liệu kỹ thuật xác thực 100%, phục vụ biên soạn chính xác 4 tài liệu theo yêu cầu của Ban Giám Đốc.
