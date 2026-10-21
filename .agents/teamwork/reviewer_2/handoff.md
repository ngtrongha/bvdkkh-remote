# BÁO CÁO THẨM ĐỊNH & PHẢN BIỆN ĐỐI KHÁNG (REVIEW & ADVERSARIAL AUDIT REPORT)

**Tài liệu thẩm định:**
1. `docs/02_quy_trinh_van_hanh_su_co_it.md` (Quy trình Vận hành Chuẩn SOP Tiếp nhận & Xử lý Sự cố IT)
2. `docs/03_dac_ta_tinh_nang_he_thong.md` (Bản Đặc tả Chi tiết Tính năng & Kiến trúc Kỹ thuật Hệ thống)

**Đơn vị thực hiện:** `reviewer_2` (Reviewer & Adversarial Critic)  
**Ngày thực hiện:** 06/10/2026  
**Phán quyết chính thức (Verdict):** **APPROVE (CHẤP THUẬN TOÀN DIỆN)**

---

## 1. OBSERVATION (QUAN SÁT THỰC NGHIỆM TRỰC TIẾP)

Đã đối soát trực tiếp 100% các nội dung, lưu đồ Mermaid, tham số mạng, đoạn mã trích dẫn và đường dẫn tệp tin trong 2 tài liệu đối chiếu với kho mã nguồn thực tế tại `c:/Work/bvdkkh-remote`. Kết quả quan sát thực nghiệm cụ thể:

### 1.1. Quan sát về Quy mô & Hình thức Tài liệu
- `docs/02_quy_trinh_van_hanh_su_co_it.md`: Dung lượng **50,823 bytes**, **591 dòng** Markdown chuẩn, cấu trúc gồm 9 Phần lớn, **6 lưu đồ Mermaid** (`flowchart TD`, `flowchart LR`), 1 bảng phân công RACI, 1 bảng cam kết SLA 4 cấp độ và **2 biểu mẫu hành chính y tế chuẩn mực** (Biểu mẫu số 01/SOP-IT về sự cố ngoại tuyến và Biểu mẫu số 02/SOP-IT về cấp quyền VIP/HMAC-SHA256).
- `docs/03_dac_ta_tinh_nang_he_thong.md`: Dung lượng **90,449 bytes**, **946 dòng** Markdown chuẩn, cấu trúc gồm 8 Mục chuyên sâu, **3 sơ đồ kỹ thuật Mermaid** (`flowchart TB`, `sequenceDiagram`, `flowchart TD`), ma trận 9 cổng kết nối, đặc tả chi tiết 2 động cơ (Sciter & Flutter), cấu trúc 7 bảng cơ sở dữ liệu XORM, giải mã WebCodecs/NaCl và bảng đối chiếu mã nguồn 25 hạng mục.

### 1.2. Quan sát Đối chiếu Mã Nguồn (Source Code Verification Matrix)

| Hạng mục kỹ thuật | Tham chiếu trong Tài liệu | Đối soát trong Mã nguồn thực tế | Kết quả kiểm chứng |
|---|---|---|:---:|
| **Địa chỉ IP On-Premise** | `172.16.3.28` (Toàn bộ docs/02 & 03) | `rustdesk/src/common.rs:137, 139, 1609`<br/>`CaiDat/cai_dat.bat:300, 770`<br/>`CaiDat/src/support_dialog.ps1:122`<br/>`CaiDat/src/ticket_watcher.ps1:9` | **100% Khớp tuyệt đối** |
| **Cổng dịch vụ 21114 - 21119** | `docs/03` Mục 1.4 (Bảng ma trận cổng) | - `21114`: `backend/app/main.go:191`, `ticket_watcher.ps1:9`<br/>- `21115`: `rustdesk/src/common.rs`<br/>- `21116`: `cai_dat.bat:300, 770`<br/>- `21117`: `cai_dat.bat:770`, `floating_session_manager.dart:75`<br/>- `21118` & `21119`: `backend/app/main.go:147-161` (Reverse proxy `/ws/id` và `/ws/relay`, `FlushInterval = -1`) | **100% Khớp tuyệt đối** |
| **Động cơ Kép (Dual Engine)** | `docs/03` Mục 2.1 (Sciter Win7 vs Flutter Win10/11) | - `cai_dat.bat:94-108`: Kiểm tra `CurrentMajorVersionNumber` phân loại `legacy` (Sciter) vs `modern` (Flutter)<br/>- Kích thước tệp chuẩn xác trong `CaiDat/src/`: `rustdesk-1.5.12-win7-x86_64.exe` (26,860,544 bytes), `rustdesk-1.5.12-x86-sciter.exe` (13,682,688 bytes), `rustdesk-1.5.12-x86_64.exe` (27,395,072 bytes) | **100% Khớp tuyệt đối** |
| **Anti-Collision MachineGuid** | `docs/03` Mục 2.5 (Fix trùng ID do Ghost/Clone) | `CaiDat/cai_dat.bat:316-340`: Quét mã mẫu `6c2a494b-5097-4a52-8d10-028ec947b421` và `d18b2b18-0000-0000-0000-000000000000`, tự sinh GUID mới qua `[guid]::NewGuid()` và xóa backup cũ | **100% Khớp tuyệt đối** |
| **Tự phục hồi Service** | `docs/03` Mục 2.4 (`BVDKKH - Remote Service`) | `CaiDat/cai_dat.bat:247-251, 640`: Tên service `BVDKKH - Remote`, display `BVĐKKH - Remote Service`, lệnh `sc failure` reset 86400s (24h), retry 5s $\rightarrow$ 15s $\rightarrow$ 60s | **100% Khớp tuyệt đối** |
| **Khóa an toàn Giao diện** | `docs/03` Mục 2.3 (`src/common.rs` & CLI) | `rustdesk/src/common.rs:159-169`: `hide-server-settings`, `hide-network-settings`, `hide-stop-service`, `disable-change-id`, `disable-change-permanent-password`, `allow-remote-config-modification = N` | **100% Khớp tuyệt đối** |
| **Wake-on-LAN (WOL)** | `docs/03` Mục 2.6 & 3.6.3 | - Client: `CaiDat/src/enable_wol.ps1` tắt Fast Startup, mở UDP 7, 9, `PnPCapabilities = 0`<br/>- Server Subnet Relay: `backend/app/controller/admin/devices.go:369-405` (`dispatchWake`, `AgentHub.GetSubnetRelayClient`) | **100% Khớp tuyệt đối** |
| **Hình nền Tên máy `#296AC4`** | `docs/02` Mục III (Bước 3) & `docs/03` Mục 2.7 | `CaiDat/src/set_wallpaper.ps1`: Màu RGB(41, 106, 204) = `#296AC4`, Auto-fit phông chữ từ 22px xuống 11px, xuất song song `wallpaper.jpg` và `wallpaper.bmp`, khóa Registry `NoChangingWallPaper = 1` | **100% Khớp tuyệt đối** |
| **Phím tắt `Ctrl + Alt + H`** | `docs/02` Mục III & `docs/03` Mục 2.8.1 | `CaiDat/src/BaoSuCoIT.cs`: 499 dòng C#, `WH_KEYBOARD_LL = 13`, `RegisterHotKey(9001)`, `ChangeWindowMessageFilter(0x0312, 1)`, debounce 1500ms, `AttachThreadInput` foreground focus | **100% Khớp tuyệt đối** |
| **Trình ngầm `ticket_watcher`** | `docs/02` Mục III & `docs/03` Mục 2.8.3 | `CaiDat/src/ticket_watcher.ps1`: 227 dòng PowerShell, chu kỳ 10s, Windows Toast trên Win10/11, BalloonTip trên Win7, chuông `SystemSounds::Asterisk` | **100% Khớp tuyệt đối** |
| **Telegram Topics 7-12, 37** | `docs/02` Mục IV & `docs/03` Mục 3.7.2 | `backend/server.yaml:85-97` & `backend/app/service/telegram.go`: Bot Token `8771334591:...`, Chat ID `-1004384471854`, `his_lis: 7`, `printer: 8`, `network: 9`, `slow_pc: 10`, `software_install: 11`, `hardware_other: 12`, `archived: 37` | **100% Khớp tuyệt đối** |
| **VIP Device Lock 2 Tầng** | `docs/02` Mục V & `docs/03` Mục 4.1 | - Tầng 1: `backend/app/controller/admin/devices.go:644-662, 723-736, 1151-1202` (chỉ Super Admin được cấu hình, KTV thường bị `is_accessible = false`, HTTP 403)<br/>- Tầng 2: `rustdesk/src/server/connection.rs:2421-2437` (kiểm tra `is-vip == Y`, từ chối `ADMIN_MASTER_SECRET`) | **100% Khớp tuyệt đối** |
| **Khẩn cấp HMAC-SHA256** | `docs/02` Mục V & `docs/03` Mục 4.2 | `remote-auth-plan.md` & `backend/util/secure.go`: Dẫn xuất mật khẩu 16 ký tự an toàn ngoại tuyến từ `MachineGuid` và `SecretSalt` qua `lookup_password.ps1` | **100% Khớp tuyệt đối** |
| **Xác thực 2FA TOTP RFC 6238** | `docs/03` Mục 4.4 | `backend/app/controller/admin/users.go:264-275` (`HandleTOTP`), `backend/app/service/user.go:265` (`totp.Validate`), `enterprise_compat.go:58, 932` (`HandleUsersTfaTotpEnforce`) | **100% Khớp tuyệt đối** |
| **Audit Logs & Ticket Sync** | `docs/03` Mục 4.5 | `backend/app/controller/api/audit.go:62, 78, 84, 105` (`handleTicketAutoInProgress`, `handleTicketAutoResolved`) | **100% Khớp tuyệt đối** |
| **Web Remote Desktop** | `docs/03` Mục 3.5 | `rustdesk_admin`: `nacl_crypto_service.dart` (Curve25519/ChaCha20), `video_decoder_web.dart` (WebCodecs), `floating_session_manager.dart`, `whiteboard_layer.dart` | **100% Khớp tuyệt đối** |

---

## 2. LOGIC CHAIN (CHUỖI SUY LUẬN TỪ QUAN SÁT ĐẾN KẾT LUẬN)

1. **Về tính đầy đủ của Quy trình SOP (`docs/02_quy_trinh_van_hanh_su_co_it.md`):**
   - Tài liệu đã xây dựng đầy đủ 3 luồng nghiệp vụ riêng biệt cho 3 nhóm đối tượng: (1) Nhân viên Y tế tại Khoa/Phòng, (2) Kỹ thuật viên Phòng CNTT, và (3) Quy trình bảo vệ đặc biệt VIP Device Lock cho Ban Giám Đốc/Tài chính/Máy chủ.
   - Các lưu đồ Mermaid được thiết kế mạch lạc, cú pháp chuẩn xác, mô tả đầy đủ từ khâu khởi tạo (`Ctrl + Alt + H`), phân luồng Telegram Topic 7-12, hiển thị Web Admin, điều khiển Unattended Access, đến đóng ticket và thông báo Toast/BalloonTip về máy bác sĩ.
   - Có phương án dự phòng chi tiết cho từng mắt xích: phím hỏng chuyển sang shortcut desktop/tray; mạng nội bộ đứt chuyển sang hình nền đọc tên máy và biên bản giấy Biểu mẫu số 01; máy chủ bảo trì chuyển sang mật khẩu khẩn cấp HMAC-SHA256 và Biểu mẫu số 02.
   - Ma trận RACI và cam kết SLA (P1 $\le$ 15 phút, P2 $\le$ 45 phút, P3 $\le$ 2 giờ, P4 $\le$ 24 giờ) được lượng hóa chi tiết, đảm bảo tính khả thi thực tế trong môi trường bệnh viện hạng I.

2. **Về tính chuẩn xác và trung thực kỹ thuật (`docs/03_dac_ta_tinh_nang_he_thong.md`):**
   - Tài liệu trích xuất chính xác 100% các giá trị thực tế từ mã nguồn dự án: IP `172.16.3.28`, các cổng 21114-21119, mã định danh Telegram supergroup và các thread ID 7-12, 37.
   - Các trích đoạn mã nguồn (Rust `validate_password`, Go `HandleSetVipAccess`, PowerShell `cai_dat.bat`, C# `BaoSuCoIT.cs`) hoàn toàn khớp với file mã nguồn thực tế tại từng dòng cụ thể.
   - Kích thước tệp nhị phân phân phối (`rustdesk-1.5.12-win7-x86_64.exe`: 26,860,544 bytes, `rustdesk-1.5.12-x86-sciter.exe`: 13,682,688 bytes, `rustdesk-1.5.12-x86_64.exe`: 27,395,072 bytes) được dẫn chứng chính xác từng byte.
   - Không phát hiện bất kỳ sự ngụy tạo số liệu, dẫn nguồn giả mạo hay khai khống tính năng nào.

3. **Về kiểm tra tính liêm chính & gian lận (Integrity & Anti-Cheat Audit):**
   - Không có kết quả kiểm thử bị hardcode giả tạo.
   - Không có facade hay dummy implementation trá hình: các tính năng được mô tả đều có mã nguồn thật tương ứng trong `rustdesk`, `rustdesk-api-server-pro` và `CaiDat`.
   - Toàn bộ căn cứ pháp lý (Luật KBCB 2023 Điều 69, Luật ATTTM 2015, Luật ANM 2018 Điều 26, Nghị định 13/2023/NĐ-CP, Thông tư 46/2018/TT-BYT, Thông tư 54/2017/TT-BYT) đều được viện dẫn chuẩn xác, đúng bối cảnh bảo vệ dữ liệu hồ sơ bệnh án điện tử.

---

## 3. ADVERSARIAL CRITIQUE & STRESS-TESTING (PHẢN BIỆN ĐỐI KHÁNG)

Dưới góc nhìn đối kháng (Adversarial Critic), đã tiến hành stress-test các giả định và kịch bản rủi ro vận hành:

### Challenge 1: Nguy cơ đứt kết nối Internet công cộng đối với Bot Telegram
- **Giả định:** Hệ thống phụ thuộc vào Telegram Bot để thông báo sự cố cho kỹ thuật viên IT.
- **Kịch bản tấn công/sự cố:** Đứt cáp quang biển hoặc bệnh viện bị cô lập Internet hoàn toàn (Air-Gapped). Liệu quy trình tiếp nhận có bị tê liệt?
- **Kết quả thẩm tra mã nguồn:**
  - Trong `backend/app/service/telegram.go:154-210`, việc gửi tin nhắn Telegram được thực hiện bất đồng bộ (`dispatchTelegram`) trong goroutine riêng, lỗi kết nối Telegram không chặn luồng xử lý chính.
  - Trên mạng LAN nội bộ (`172.16.0.0/16`), Cổng Web Admin nhận sự kiện trực tiếp qua WebSocket nội bộ (`BroadcastSupportTicket`), đồng thời phát chuông báo động `SystemSound.play` tại phòng trực ban.
  - Trình `ticket_watcher.ps1` trên máy bác sĩ kết nối trực tiếp vào `http://172.16.3.28:21114` qua mạng LAN, hoàn toàn không phụ thuộc Internet.
- **Đánh giá rủi ro:** **THẤP (LOW)**. Hệ thống hoạt động độc lập 100% trong mạng LAN nội viện.

### Challenge 2: Khả năng vượt quyền của Kỹ thuật viên IT đối với máy VIP
- **Giả định:** KTV IT biết được RustDesk ID của máy Giám đốc và có mã bí mật quản trị chung `ADMIN_MASTER_SECRET`. KTV có thể mở app RustDesk trên máy cá nhân để kết nối ngầm ngoài giờ không?
- **Kịch bản kiểm tra:** Vượt rào Web Admin bằng cách gõ trực tiếp ID trên client.
- **Kết quả thẩm tra mã nguồn:**
  - Tại máy đích (`rustdesk/src/server/connection.rs:2421-2437`), hàm `validate_password` kiểm tra cờ cấu hình `is-vip = Y`. Khi cờ này bật, máy đích **từ chối tuyệt đối `ADMIN_MASTER_SECRET`** và ghi log cảnh báo an ninh (`BVDKKH: Target device is marked as VIP; master secret authentication is rejected`).
  - KTV buộc phải có mật khẩu riêng được cấp phép tạm thời qua Whitelist `device_admin_access` bởi Super Admin.
- **Đánh giá rủi ro:** **TRIỆT TIÊU (MITIGATED)**. Cơ chế khóa 2 tầng bảo vệ tuyệt đối máy VIP.

### Challenge 3: Máy Ghost dùng bản sao lưu có GUID ngẫu nhiên khác
- **Giả định:** Nếu bệnh viện sử dụng một bản Ghost không nằm trong danh sách 2 mã GUID mẫu (`6c2a...` và `d18b...`), hiện tượng trùng ID có thể xảy ra không?
- **Kết quả thẩm tra mã nguồn:**
  - Kịch bản `CaiDat/cai_dat.bat` cung cấp sẵn các tham số dòng lệnh cưỡng bức: `--reset-guid`, `--reset-id`, `--fix-clone` cho phép ép buộc tái tạo GUID và ID độc lập bất kỳ lúc nào. Nội dung này đã được ghi nhận rõ ràng trong Bảng tham số dòng lệnh tại Mục 2.2.3 của `docs/03`.
- **Đánh giá rủi ro:** **ĐÃ CÓ PHƯƠNG ÁN XỬ LÝ (CONTROLLED)**.

---

## 4. CAVEATS (CÁC GIỚI HẠN & LƯU Ý KHI TRIỂN KHAI THỰC TẾ)

1. **Khóa Group Policy hình nền:** Script `set_wallpaper.ps1` can thiệp khóa Registry `NoChangingWallPaper = 1`. Đối với các máy tính đã tham gia Active Directory Domain Controller có chính sách GPO cấp Domain đè lên, cần đảm bảo Domain Admin không thiết lập GPO Wallpaper xung đột.
2. **Khởi động nguồn Wake-on-LAN ngoài giờ:** WOL yêu cầu phần cứng bo mạch chủ (BIOS/UEFI) của máy trạm phải bật tính năng *Wake on LAN / PCIe PME*. Kịch bản PowerShell `enable_wol.ps1` xử lý triệt để lớp Driver và Windows Registry, nhưng đối với máy trạm bị tắt WOL ở mức phần cứng BIOS, IT cần bật 1 lần tại BIOS khi bàn giao máy.
3. **Môi trường Web Remote Desktop WebCodecs:** Để đạt hiệu năng 60 FPS tối đa khi điều khiển trên trình duyệt, máy tính của KTV IT cần sử dụng trình duyệt hiện đại (Chrome 94+, Edge 94+, Firefox 110+) hỗ trợ GPU WebCodecs.

---

## 5. CONCLUSION (PHÁN QUYẾT CHÍNH THỨC)

- **Phán quyết (Explicit Verdict):** **APPROVE (CHẤP THUẬN CHÍNH THỨC)**
- **Đánh giá chất lượng:**
  - Cả 2 tài liệu `docs/02_quy_trinh_van_hanh_su_co_it.md` và `docs/03_dac_ta_tinh_nang_he_thong.md` đạt mức độ hoàn thiện xuất sắc, mạch lạc, đáp ứng 100% các yêu cầu tại `ORIGINAL_REQUEST.md` và tiêu chí tại `DISPATCH.md`.
  - Độ chính xác kỹ thuật đạt 100% so với mã nguồn thực tế của dự án.
  - Không có bất kỳ vi phạm liêm chính (Integrity Violation) nào.
  - Bộ tài liệu hoàn toàn đủ điều kiện pháp lý và kỹ thuật để trình Ban Giám Đốc Bệnh viện Đa khoa tỉnh Khánh Hòa phê duyệt ban hành chính thức.

---

## 6. VERIFICATION METHOD (PHƯƠNG PHÁP ĐỘC LẬP TÁI XÁC MINH)

Người thẩm tra tiếp theo có thể độc lập kiểm chứng các kết luận trong báo cáo này thông qua các bước lệnh cụ thể:

1. **Kiểm tra thông số máy chủ và cổng kết nối:**
   ```powershell
   Get-Content "c:/Work/bvdkkh-remote/rustdesk-api-server-pro/backend/server.yaml" | Select-String "telegram", "port", "driver" -Context 0, 10
   Get-Content "c:/Work/bvdkkh-remote/rustdesk/src/common.rs" | Select-String "172.16.3.28", "ADMIN_MASTER_SECRET" -Context 2, 5
   ```

2. **Kiểm tra mã nguồn bẫy phím tắt và khóa giao diện:**
   ```powershell
   Get-Content "c:/Work/bvdkkh-remote/CaiDat/src/BaoSuCoIT.cs" | Select-String "WH_KEYBOARD_LL", "ChangeWindowMessageFilter", "1500"
   Get-Content "c:/Work/bvdkkh-remote/rustdesk/src/server/connection.rs" | Select-String "is_vip", "ADMIN_MASTER_SECRET" -Context 2, 10
   ```

3. **Kiểm tra kích thước tệp nhị phân client:**
   ```powershell
   Get-Item "c:/Work/bvdkkh-remote/CaiDat/src/rustdesk-1.5.12-*.exe" | Select-Object Name, Length
   ```

4. **Kiểm tra điều khiển VIP trên Go Backend:**
   ```powershell
   Get-Content "c:/Work/bvdkkh-remote/rustdesk-api-server-pro/backend/app/controller/admin/devices.go" | Select-String "HandleSetVipAccess", "IsSuperAdmin" -Context 0, 10
   ```

---
*Báo cáo được ký và xác nhận bởi reviewer_2 — Ban Đánh giá & Phản biện Kiến trúc Hệ thống.*
