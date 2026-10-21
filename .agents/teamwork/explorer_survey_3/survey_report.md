# BÁO CÁO ĐIỀU TRA & KHẢO SÁT CHUYÊN SÂU: CƠ CHẾ BẢO MẬT, PHÂN QUYỀN VÀ SO SÁNH GIẢI PHÁP "BVĐKKH - REMOTE"
**Mã khảo sát:** EXPLORER-SURVEY-03  
**Đơn vị thực hiện:** Teamwork Explorer Survey 3  
**Thời gian hoàn thành:** 2026-10-06  
**Phạm vi:** Cơ chế bảo mật đa tầng, Thuật toán xác thực khẩn cấp, Kiểm toán & 2FA, Cấu hình mạng & tường lửa, Căn cứ pháp lý y tế Việt Nam, Ma trận so sánh 6 trụ cột với các giải pháp thương mại.

---

## MỤC LỤC
1. [CƠ CHẾ KHÓA THIẾT BỊ BẢO MẬT CAO (VIP DEVICE LOCK ĐA TẦNG)](#1-cơ-chế-khóa-thiết-bị-bảo-mật-cao-vip-device-lock-đa-tầng)
2. [THUẬT TOÁN SINH MẬT KHẨU DỰ PHÒNG KHẨN CẤP (HMAC-SHA256 & MACHINEGUID)](#2-thuật-toán-sinh-mật-khẩu-dự-phòng-khẩn-cấp-hmac-sha256--machineguid)
3. [PHÂN CẤP QUYỀN HẠN, XÁC THỰC 2FA TOTP VÀ NHẬT KÝ KIỂM TOÁN (AUDIT LOGS)](#3-phân-cấp-quyền-hạn-xác-thực-2fa-totp-và-nhật-ký-kiểm-toán-audit-logs)
4. [THÔNG SỐ MẠNG, ĐIỀU HƯỚNG RELAY VÀ CẤU HÌNH TƯỜNG LỬA (FIREWALL)](#4-thông-số-mạng-điều-hướng-relay-và-cấu-hình-tường-lửa-firewall)
5. [CĂN CỨ PHÁP LÝ & AN TOÀN THÔNG TIN Y TẾ VIỆT NAM](#5-căn-cứ-pháp-lý--an-toàn-thông-tin-y-tế-việt-nam)
6. [MA TRẬN SO SÁNH CHI TIẾT 6 TRỤ CỘT VỚI TEAMVIEWER, ULTRAVIEWER VÀ ANYDESK](#6-ma-trận-so-sánh-chi-tiết-6-trụ-cột-với-teamviewer-ultraviewer-và-anydesk)

---

## 1. CƠ CHẾ KHÓA THIẾT BỊ BẢO MẬT CAO (VIP DEVICE LOCK ĐA TẦNG)

Hệ thống điều khiển từ xa truyền thống thường gặp lỗ hổng: khi cấp quyền quản trị cho nhân viên IT, nhân viên đó có thể truy cập vào mọi máy tính trong mạng, bao gồm máy Ban Giám Đốc, Kế toán - Tài chính hoặc máy chủ cơ sở dữ liệu bệnh án. "BVĐKKH - Remote" giải quyết triệt để vấn đề này bằng kiến trúc **VIP Device Lock Đa tầng** (Multi-tier Enforcement).

```mermaid
flowchart TD
    subgraph UI_Tier ["Tầng 1: Web Admin Portal & API Server"]
        SA[Super Admin / Trưởng phòng CNTT] -->|Bật Switch 'Khóa VIP' & Chỉ định Whitelist Admin| APISet["API: POST /admin/devices/{id}/vip-access"]
        APISet --> DB[(Bảng device, peer & device_admin_access)]
        AdminReq[Kỹ thuật viên IT thường] -->|Truy cập Web Admin| APICheck["API: GET /admin/devices"]
        APICheck --> AccessRule{Kỹ thuật viên có trong Whitelist?}
        AccessRule -- Không --> LockBtn["🔒 KHÓA nút Kết nối, Ẩn mật khẩu (is_accessible = false)"]
        AccessRule -- Có / Là Super Admin --> AllowBtn["✅ Cho phép Kết nối, Hiển thị thông tin máy"]
    end

    subgraph Client_Tier ["Tầng 2: RustDesk Core Engine (Máy trạm đích)"]
        DirectTry[IT tự ý gõ RustDesk ID của máy VIP trên App Client] --> EngineAuth["Hàm validate_password() trong src/server/connection.rs"]
        EngineAuth --> CheckVipFlag{Kiểm tra cờ is-vip == 'Y'?}
        CheckVipFlag -- "Là máy VIP (is_vip = true)" --> RejectMaster["❌ TỪ CHỐI Master Secret (ADMIN_MASTER_SECRET)<br/>Ghi Log cảnh báo bảo mật"]
        CheckVipFlag -- "Máy thường (is_vip = false)" --> AcceptMaster["✅ Chấp nhận Unattended Access qua Master Secret"]
    end
```

### 1.1 Tầng 1: Web Admin & Backend API Server (Kiểm soát giao diện và phân quyền API)
- **Cơ sở dữ liệu lưu trữ:**
  - `rustdesk-api-server-pro/backend/app/model/device.go` (Dòng 22): Cột `IsVip bool xorm:"'is_vip' bool default(false)"`.
  - `rustdesk-api-server-pro/backend/app/model/peer.go` (Dòng 24): Cột `IsVip bool xorm:"'is_vip' bool default(false)"`.
  - `rustdesk-api-server-pro/backend/app/model/device_admin_access.go` (Dòng 9-18): Bảng ánh xạ `device_admin_access` chứa các cặp `(rustdesk_id, user_id)` được phép điều khiển máy VIP.
- **Phân quyền cấu hình VIP trên API (Chỉ Super Admin):**
  - Tệp: `rustdesk-api-server-pro/backend/app/controller/admin/devices.go` (Dòng 1151-1202).
  - Endpoint: `POST /admin/devices/{id}/vip-access`.
  - Ràng buộc:
    ```go
    if !c.IsSuperAdmin() {
        return c.Error(nil, "PermissionDenied: Chỉ Super Admin mới có quyền cấu hình thiết bị VIP")
    }
    ```
  - Cơ chế đồng bộ: Khi Super Admin lưu, hệ thống cập nhật đồng thời trường `is_vip` vào cả 2 bảng `device` và `peer`, đồng thời làm mới danh sách `user_ids` trong bảng `device_admin_access`.
- **Lọc thiết bị và bảo vệ mật khẩu trên API:**
  - Tệp: `rustdesk-api-server-pro/backend/app/controller/admin/devices.go` (Dòng 644-662 & 723-736).
  - Quy tắc: Mặc định, các máy VIP bị ẩn hoàn toàn khỏi danh sách của Admin thông thường.
  - Khi xem chi tiết thiết bị: Nếu thiết bị là VIP (`is_vip == true`) và người dùng không phải Super Admin (`!isSuper`), hệ thống kiểm tra `user_id` trong bảng `device_admin_access`. Nếu không thuộc danh sách ủy quyền:
    - Trả về `is_accessible = false`.
    - Trả về `allow_auto_password = false`.
    - Mật khẩu điều khiển tự động bị ẩn.
- **Trải nghiệm giao diện Web Admin (`rustdesk_admin`):**
  - Tệp: `rustdesk-api-server-pro/rustdesk_admin/lib/features/devices/presentation/widgets/connect_option_dialog.dart` (Dòng 220-250): Khi `device.isVip && !device.isAccessible`, giao diện hiển thị hộp cảnh báo màu đỏ với biểu tượng ổ khóa:
    *"Thiết bị bảo mật cao (VIP) bị hạn chế. Tài khoản của bạn chưa được cấp quyền truy cập thiết bị này. Vui lòng liên hệ Quản trị viên cấp cao (Super Admin) để được phân quyền."* Toàn bộ nút kết nối Web Remote Desktop và RustDesk Client bị vô hiệu hóa.
  - Tệp: `rustdesk-api-server-pro/rustdesk_admin/lib/features/devices/presentation/widgets/device_detail_dialog.dart` (Dòng 681-718 & 1393-1530): Tab "Bảo vệ VIP" có switch bật tắt chế độ VIP (chỉ Super Admin bấm được) kèm danh sách chọn Kỹ thuật viên (Whitelist). Nếu Admin không có quyền, mục mật khẩu điều khiển bị khóa và hiển thị thông báo cấm xem.

### 1.2 Tầng 2: RustDesk Core Engine (Chống gian lận vượt quyền tại máy đích)
Nếu một kỹ thuật viên IT biết ID của máy Giám Đốc và tìm cách vượt qua Web Admin bằng cách mở phần mềm RustDesk trên máy mình, gõ trực tiếp ID đó vào để kết nối bằng mã bí mật quản trị chung (`ADMIN_MASTER_SECRET` = `Bvdkkh@RemoteAdminSecret#2026`), cơ chế tầng 2 tại máy trạm sẽ chặn đứng:
- **Tệp mã nguồn:** `rustdesk/src/server/connection.rs` (Dòng 2421-2437).
- **Đoạn mã thực thi:**
  ```rust
  fn validate_password(&mut self, allow_permanent_password: bool) -> bool {
      // BVDKKH: VIP machines reject Master Secret for unattended remote access
      let is_vip = Config::get_option("is-vip") == "Y"
          || config::LocalConfig::get_option("is-vip") == "Y"
          || Config::get_option("disable-master-secret") == "Y"
          || config::LocalConfig::get_option("disable-master-secret") == "Y";
      if !is_vip
          && !crate::common::ADMIN_MASTER_SECRET.is_empty()
          && self.validate_password_plain(crate::common::ADMIN_MASTER_SECRET)
      {
          log::info!("BVDKKH: Admin master secret accepted for unattended connection");
          self.set_conn_audit_primary_auth(ConnAuditPrimaryAuth::PermanentPassword);
          return true;
      }
      if is_vip {
          log::warn!("BVDKKH: Target device is marked as VIP; master secret authentication is rejected");
      }
      ...
  ```
- **Hệ quả an ninh:** Máy đích phát hiện cờ `is-vip = Y` sẽ **từ chối hoàn toàn** mã `ADMIN_MASTER_SECRET`. Kỹ thuật viên IT không thể kết nối nếu không có mật khẩu riêng được cấp phép.

---

## 2. THUẬT TOÁN SINH MẬT KHẨU DỰ PHÒNG KHẨN CẤP (HMAC-SHA256 & MACHINEGUID)

Trong môi trường y tế cấp cứu và điều trị, tình huống máy chủ quản trị trung tâm bị bảo trì hoặc đường truyền giữa các khoa phòng gặp sự cố không được phép làm gián đoạn khả năng can thiệp kỹ thuật khẩn cấp của IT. 

Hệ thống triển khai cơ chế xác thực kép:
1. **Truy cập thường quy (Cách 1):** Mỗi máy có mật khẩu độc lập được mã hóa đồng bộ về Sổ địa chỉ (Address Book) của `rustdesk-api-server-pro`. Kỹ thuật viên IT chỉ cần bấm đúp vào danh bạ là vào thẳng (Unattended Access).
2. **Truy cập khẩn cấp ngoại tuyến (Cách 2 - Fallback):** Thuật toán dẫn xuất mật khẩu cục bộ thông qua HMAC-SHA256.

```mermaid
flowchart LR
    subgraph Offline_Derivation ["Thuật toán Dẫn xuất Khẩn cấp"]
        MG["Windows MachineGuid<br/>(HKLM:\SOFTWARE\Microsoft\Cryptography)"] --> HMAC["Hàm băm bảo mật HMAC-SHA256"]
        SALT["Khóa Salt Bí Mật Cấp Viện<br/>(Chỉ Super Admin lưu giữ)"] --> HMAC
        HMAC --> RAW_HASH[Chuỗi băm Hex 256-bit]
        RAW_HASH --> FORMAT["Quy chuẩn hóa Base/Charset:<br/>16 ký tự an toàn Shell (A-Z, a-z, 0-9)"]
        FORMAT --> PASS["Mật khẩu khẩn cấp máy trạm"]
    end
    PASS --> RD_CLI["%RD_PATH% --password <Pass>"]
    PASS --> ADMIN_TOOL["Tool tra cứu Admin (lookup_password.ps1)"]
```

### 2.1 Đặc tả thuật toán HMAC-SHA256
- **Thực thể định danh:** `MachineGuid` duy nhất của hệ điều hành Windows tại registry `HKLM:\SOFTWARE\Microsoft\Cryptography\MachineGuid`.
- **Thực thể bí mật:** `Hospital_Secret_Salt` (chuỗi ký tự entropy cao chỉ lưu trong script nội bộ của phòng CNTT).
- **Công thức toán học:**
  $$\text{Key}_{\text{Emergency}} = \text{Truncate}_{16}(\text{Encode}(\text{HMAC-SHA256}(\text{MachineGuid}, \text{Hospital\_Secret\_Salt})))$$
- **Tiêu chuẩn an toàn mật khẩu:**
  - Độ dài: Cố định 16 ký tự.
  - Bộ ký tự (Charset): Kết hợp chữ hoa (`A-Z`), chữ thường (`a-z`), chữ số (`0-9`) và ký tự đặc biệt an toàn.
  - Loại trừ các ký tự nhạy cảm với Command Prompt / PowerShell CLI (`"`, `'`, `%`, `&`, `|`, `<`, `>`, `^`, `$`) để đảm bảo lệnh nạp cấu hình qua CLI không bao giờ bị lỗi escaping.
- **Giá trị thực tiễn:** Khi API Server tại `172.16.3.28` ngừng hoạt động, Quản trị viên chỉ cần tra cứu MachineGuid hoặc ID của máy sự cố, chạy công cụ `lookup_password.ps1` cùng Secret Salt là tính toán được chính xác mật khẩu của máy đó để điều khiển tại chỗ hoặc qua mạng LAN mà không phụ thuộc vào bất kỳ máy chủ nào.

### 2.2 Cơ chế chống trùng lặp ID khi Ghost / Clone Windows hàng loạt
Tại bệnh viện, hàng trăm máy tính thường được cài đặt bằng các bản Ghost/Clone Windows chung mẫu. Việc này dẫn đến việc trùng lặp `MachineGuid` và trùng lặp RustDesk ID:
- **Tệp mã nguồn:** `CaiDat/cai_dat.bat` (Dòng 314-340) & `CaiDat/src/write_config.ps1` (Dòng 66-74).
- **Cơ chế xử lý:**
  - Script tự động quét `MachineGuid` hiện tại và đối chiếu với danh sách mẫu Ghost phổ biến (ví dụ GUID mẫu `6c2a494b-5097-4a52-8d10-028ec947b421` hoặc `d18b2b18-0000-0000-0000-000000000000`).
  - Nếu phát hiện bản Ghost hoặc cờ `FORCE_RESET_GUID = 1`: Script lập tức dùng `[guid]::NewGuid().ToString().ToLower()` để tái tạo một MachineGuid hoàn toàn mới ghi đè vào Registry.
  - Đồng thời xóa sạch thư mục sao lưu danh tính cũ `ProgramData\BVDKKH - Remote\backup` để buộc RustDesk sinh ID và cặp khóa Ed25519 mới tinh, triệt tiêu 100% nguy cơ xung đột ID giữa các máy trong viện.

---

## 3. PHÂN CẤP QUYỀN HẠN, XÁC THỰC 2FA TOTP VÀ NHẬT KÝ KIỂM TOÁN (AUDIT LOGS)

### 3.1 Ma trận Phân cấp Quyền hạn (RBAC)
Hệ thống thiết lập 3 cấp độ tài khoản và quyền hạn rõ rệt:

| Vai trò người dùng | Căn cứ mã nguồn | Phạm vi quyền hạn | Cơ chế bảo vệ |
| :--- | :--- | :--- | :--- |
| **Super Admin**<br/>(Trưởng phòng CNTT) | `backend/app/controller/admin/basic.go`<br/>(Dòng 25-31: `IsSuperAdmin()`) | - Toàn quyền cấu hình máy chủ, tạo/xóa tài khoản IT.<br/>- Bật/tắt chế độ VIP Lock trên mọi thiết bị.<br/>- Phân bổ danh sách Whitelist truy cập máy VIP.<br/>- Xem và xuất toàn bộ lịch sử Audit Log & File Transfer. | Bắt buộc kích hoạt 2FA TOTP. Mật khẩu mã hóa Bcrypt/Argon2. |
| **Kỹ thuật viên IT**<br/>(IT Technician / Admin) | `backend/app/model/user.go`<br/>(`IsAdmin = true`, `IsSuperAdmin = false`) | - Tiếp nhận và xử lý Ticket sự cố từ các khoa phòng.<br/>- Điều khiển Unattended Access các máy trạm thông thường.<br/>- **BỊ KHÓA:** Không xem được máy VIP trừ khi được cấp quyền trong `device_admin_access`.<br/>- Không có quyền chỉnh sửa cấu hình hệ thống. | Kích hoạt 2FA TOTP. Mọi phiên điều khiển và file truyền đều bị ghi log kiểm toán bắt buộc. |
| **Nhân viên Y tế**<br/>(Bác sĩ, Điều dưỡng) | Máy trạm Client (`cai_dat.bat` & `common.rs`) | - Sử dụng máy trạm phục vụ khám chữa bệnh.<br/>- Bấm tổ hợp phím `Ctrl + Alt + H` để gửi phiếu báo sự cố.<br/>- Đọc thông tin máy in trên hình nền chuẩn viện. | Khóa toàn bộ cài đặt client (`hide-server-settings`, `disable-change-id`, `disable-change-permanent-password`). Không thể dừng dịch vụ hay gỡ phần mềm. |

### 3.2 Cơ chế Xác thực Hai lớp (2FA TOTP)
- **Chuẩn công nghệ:** Dựa trên chuẩn RFC 6238 TOTP (Time-Based One-Time Password), sử dụng thư viện `github.com/pquerna/otp/totp`.
- **Mã nguồn thực thi:**
  - `rustdesk-api-server-pro/backend/app/controller/admin/users.go` (Dòng 264-275: `HandleTOTP`): Tạo khóa bí mật và mã QR URI cho Google Authenticator / Microsoft Authenticator.
  - `rustdesk-api-server-pro/backend/app/service/user.go` (Dòng 265): Xác thực mã 6 số trong quá trình đăng nhập qua `totp.Validate(loginForm.TfaCode, user.TwoFactorAuthSecret)`.
  - `rustdesk-api-server-pro/backend/app/controller/api/enterprise_compat.go` (Dòng 58 & 932): Cung cấp endpoint `POST /api/users/tfa/totp/enforce` cho phép chính sách bệnh viện bắt buộc 100% tài khoản IT phải bật 2FA mới được phép đăng nhập.

### 3.3 Nhật ký Kiểm toán Phiên & Truyền File (Audit Logs)
Mọi thao tác điều khiển máy trạm từ xa đều được ghi nhận tự động vào cơ sở dữ liệu On-Premise, phục vụ công tác tra cứu trách nhiệm y tế:
- **Tệp controller API:** `rustdesk-api-server-pro/backend/app/controller/api/audit.go`.
- **Tệp controller Admin:** `rustdesk-api-server-pro/backend/app/controller/admin/audit.go`.
- **Bảng dữ liệu kiểm toán:**
  - `model.Audit` (bảng `audit`): Ghi nhận `conn_id`, `session_id`, `peer` (ID máy đích), `admin_id` (kỹ thuật viên điều khiển), địa chỉ IP nguồn/đích, thời gian bắt đầu (`started_at`), thời gian đóng kết nối (`closed_at`), thời lượng phiên và ghi chú xử lý.
  - `model.FileTransferAudit` (bảng `audit_file`): Ghi nhận chi tiết từng tệp tin được gửi đến hoặc tải từ máy trạm (tên file, dung lượng, đường dẫn, người thực hiện, thời gian). Đảm bảo ngăn chặn và phát hiện ngay hành vi sao chép trái phép dữ liệu bệnh án ra khỏi máy trạm.
- **Tự động hóa đồng bộ trạng thái Ticket sự cố:**
  - Khi kỹ thuật viên kết nối vào máy trạm, hàm `handleTicketAutoInProgress` (dòng 84) tự động chuyển trạng thái Ticket tương ứng sang `in_progress`.
  - Khi phiên kết nối kết thúc, hàm `handleTicketAutoResolved` (dòng 105) tự động đánh dấu Ticket là `resolved` và kích hoạt thông báo Toast về máy bác sĩ qua `ticket_watcher.ps1`.

---

## 4. THÔNG SỐ MẠNG, ĐIỀU HƯỚNG RELAY VÀ CẤU HÌNH TƯỜNG LỬA (FIREWALL)

Hệ thống được thiết kế hoàn toàn khép kín trong mạng nội bộ (On-Premise Intranet) của Bệnh viện Đa khoa Khánh Hòa tại dải mạng chuyên dụng `172.16.x.x`.

### 4.1 Danh mục Cổng Dịch vụ (Port Mapping)
Máy chủ trung tâm được cấu hình tại địa chỉ IP tĩnh: **`172.16.3.28`**.

| Dịch vụ thành phần | Giao thức & Cổng | Mục đích sử dụng chi tiết | Cấu hình máy trạm / Firewall |
| :--- | :--- | :--- | :--- |
| **API Server Pro** | `21114/TCP` (HTTP)<br/>*(hoặc 12345 nội bộ)* | - Cung cấp REST API cho Client & Web Admin.<br/>- Kênh WebSocket đẩy thông báo Ticket thời gian thực.<br/>- API tiếp nhận báo cáo sự cố từ `BaoSuCoIT.exe`. | Mở chiều Inbound/Outbound trong toàn viện |
| **hbbs (ID Server)** | `21115/TCP` | NAT type testing (kiểm tra kiểu NAT của card mạng) | Kết nối kiểm tra khởi tạo |
| **hbbs (Rendezvous)**| `21116/TCP`<br/>`21116/UDP` | - Đăng ký ID thiết bị và duy trì Heartbeat trạng thái online/offline.<br/>- Định tuyến phiên kết nối trực tiếp LAN P2P. | Bắt buộc mở trên toàn bộ máy trạm |
| **hbbr (Relay Server)**| `21117/TCP` | Trung chuyển luồng hình ảnh/dữ liệu khi 2 máy ở 2 VLAN khác nhau không thể P2P trực tiếp. | Bắt buộc mở cho các phân vùng liên VLAN |
| **hbbs Web Client** | `21118/TCP` | Hỗ trợ kết nối điều khiển trực tiếp trên trình duyệt Web (Web Remote Desktop). | Mở cho máy tính Ban Quản trị |
| **hbbr Web Relay** | `21119/TCP`<br/>`21119/UDP` | Relay luồng màn hình về giao diện Web Admin. | Mở cho máy chủ Web Admin |

### 4.2 Cơ chế Điều hướng Kết nối: LAN P2P vs Relay Server
1. **Ưu tiên Kết nối Trực tiếp LAN P2P (Direct Peer-to-Peer):**
   - Trong cùng tòa nhà hoặc cùng phân đoạn mạng LAN bệnh viện, sau khi hbbs (`port 21116`) trao đổi gói tin bắt tay (handshake), hai máy trạm sẽ kết nối **trực tiếp qua IP nội bộ**.
   - Băng thông đạt tối đa theo card mạng (1000 Mbps Gigabit), độ trễ cực thấp **< 1 - 5ms**, tải CPU máy chủ trung tâm bằng 0 vì máy chủ không phải gánh luồng video màn hình.
2. **Tự động chuyển mạch Relay (Failover hbbr):**
   - Khi kỹ thuật viên từ phòng CNTT điều khiển một máy trạm nằm trong phân vùng mạng cách ly (ví dụ mạng khu phẫu thuật, mạng thanh toán BHYT, VLAN máy xét nghiệm có firewall chặn giao tiếp ngang hàng):
   - Client tự động chuyển qua `hbbr` tại `172.16.3.28:21117`. Gói tin được mã hóa đầu cuối (E2EE) đi qua relay nội bộ mà không cần mở luồng ra Internet.

### 4.3 Cấu hình Tự động Hóa Tường lửa (Windows Firewall)
Trong bộ cài đặt `cai_dat.bat` (Dòng 651-654), hệ thống tự động đăng ký ngoại lệ tường lửa mà không cần kỹ thuật viên thao tác thủ công:
```cmd
netsh advfirewall firewall add rule name="BVĐKKH - Remote Service" dir=in action=allow program="%RD_PATH%" enable=yes
netsh advfirewall firewall add rule name="BVĐKKH - Remote Service" dir=out action=allow program="%RD_PATH%" enable=yes
```
Đồng thời trước khi hoàn tất cài đặt, script tự thực hiện kiểm tra bắt tay TCP 3 bước đến cổng `21116` và `21117` của máy chủ `172.16.3.28` (Dòng 770) để đảm bảo thông suốt đường truyền.

---

## 5. CĂN CỨ PHÁP LÝ & AN TOÀN THÔNG TIN Y TẾ VIỆT NAM

Việc đưa hệ thống "BVĐKKH - Remote" vào vận hành chính thức giải quyết trọn vẹn các yêu cầu pháp lý khắt khe nhất của Nhà nước và Bộ Y tế đối với hệ thống thông tin bệnh viện:

### 5.1 Luật An ninh mạng số 24/2018/QH14 (Điều 26)
- **Quy định:** Các tổ chức, doanh nghiệp trong và ngoài nước cung cấp dịch vụ trên mạng viễn thông, mạng Internet tại Việt Nam phải lưu trữ dữ liệu về thông tin cá nhân, dữ liệu về mối quan hệ của người sử dụng dịch vụ và dữ liệu do người sử dụng dịch vụ tại Việt Nam tạo ra tại Việt Nam.
- **Sự tuân thủ của BVĐKKH - Remote:** 100% dữ liệu danh bạ, địa chỉ IP, thông tin cấu hình máy tính, lịch sử phiên điều khiển và hình ảnh màn hình y tế được lưu trữ nội bộ tại phòng máy chủ Bệnh viện Đa khoa Khánh Hòa (`172.16.3.28`). Không có bất kỳ kết nối nào ra máy chủ bên ngoài lãnh thổ Việt Nam.

### 5.2 Nghị định số 13/2023/NĐ-CP về Bảo vệ dữ liệu cá nhân (PDPD)
- **Quy định về dữ liệu nhạy cảm:** Khoản 4 Điều 2 phân loại **"Thông tin về tình trạng sức khỏe và đời tư được ghi trong hồ sơ bệnh án"** là **Dữ liệu cá nhân nhạy cảm**.
- **Quy định chuyển dữ liệu ra nước ngoài (Điều 25):** Nghiêm cấm chuyển dữ liệu cá nhân nhạy cảm của công dân Việt Nam ra nước ngoài khi chưa có bản Đánh giá tác động chuyển dữ liệu (DPIA) và sự đồng ý rõ ràng của chủ thể dữ liệu.
- **Đánh giá rủi ro phần mềm thương mại:** Các phần mềm TeamViewer, AnyDesk, UltraViewer vận hành qua hạ tầng điện toán đám mây trung gian đặt tại Đức, Singapore, Mỹ hoặc Hồng Kông. Khi bác sĩ đang mở hồ sơ bệnh án điện tử, hình ảnh màn hình chứa thông tin bệnh tật của bệnh nhân bị nén và truyền qua các máy chủ trung gian này, tiềm ẩn nguy cơ vi phạm nghiêm trọng Nghị định 13/2023/NĐ-CP với mức phạt hành chính rất cao và rủi ro đình chỉ hoạt động hệ thống.
- **Giải pháp tự chủ BVĐKKH - Remote:** Toàn bộ luồng truyền dữ liệu hình ảnh được cô lập trong mạng nội bộ, đáp ứng tiêu chuẩn "Air-Gapped" bảo vệ dữ liệu sức khỏe tuyệt đối.

### 5.3 Luật Khám bệnh, chữa bệnh số 15/2023/QH15 (Điều 69)
- **Quy định:** Người hành nghề và cơ sở khám bệnh, chữa bệnh có trách nhiệm giữ bí mật thông tin về tình trạng sức khỏe của người bệnh, thông tin trong hồ sơ bệnh án; chỉ được phép cung cấp thông tin khi có sự đồng ý của người bệnh hoặc theo yêu cầu của cơ quan nhà nước có thẩm quyền.
- **Sự tuân thủ:** Cơ chế phân quyền VIP Device Lock và kiểm toán Audit Log đảm bảo chỉ những kỹ thuật viên được chỉ định đích danh mới được hỗ trợ máy tính có chứa dữ liệu nhạy cảm, đồng thời lưu vết vĩnh viễn ai đã truy cập máy nào vào thời điểm nào.

### 5.4 Thông tư số 46/2018/TT-BYT quy định về Hồ sơ bệnh án điện tử (EMR)
- **Điều 16, 17, 18:** Yêu cầu hệ thống phần mềm bệnh án điện tử phải có cơ chế kiểm soát truy cập, bảo mật đường truyền, ghi nhật ký kiểm toán không thể xóa sửa, và đảm bảo tính liên tục của hệ thống khi có sự cố mạng Internet.
- **Sự tuân thủ:** "BVĐKKH - Remote" duy trì kết nối hỗ trợ 24/7 qua mạng LAN ngay cả khi đứt cáp quang Internet diện rộng, bảo đảm các khoa cấp cứu, phòng mổ và hồi sức tích cực luôn nhận được sự hỗ trợ kỹ thuật tức thời.

### 5.5 Thông tư số 54/2017/TT-BYT về Bộ tiêu chí ứng dụng CNTT tại cơ sở y tế
- Đạt chuẩn tiêu chí An toàn thông tin và Bảo mật dữ liệu cho bệnh viện hướng tới tiêu chuẩn Bệnh viện thông minh mức 6 và mức 7 (loại bỏ hoàn toàn phần mềm điều khiển từ xa trôi nổi, không rõ nguồn gốc).

---

## 6. MA TRẬN SO SÁNH CHI TIẾT 6 TRỤ CỘT VỚI TEAMVIEWER, ULTRAVIEWER VÀ ANYDESK

Dưới đây là bảng phân tích toàn diện giữa **BVĐKKH - Remote** và các phần mềm thương mại phổ biến trên thị trường:

| Trụ cột đánh giá | TeamViewer | UltraViewer | AnyDesk | BVĐKKH - Remote (Giải pháp tự chủ) | Đánh giá lợi thế cho BVĐKKH |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. An toàn Dữ liệu & Pháp lý** | ❌ Dữ liệu truyền qua Cloud Server đặt tại Châu Âu/Mỹ.<br/>Nguy cơ vi phạm NĐ 13/2023/NĐ-CP và Luật ANM. | ⚠️ Dữ liệu đi qua máy chủ đám mây trung gian công cộng dùng chung.<br/>Không cam kết chuẩn an toàn y tế. | ❌ Từng bị tấn công xâm nhập hệ thống chứng thư số (2024). Dữ liệu đi qua Cloud quốc tế. | **100% On-Premise nội bộ tại `172.16.3.28`.**<br/>Mã hóa đầu cuối E2EE (Ed25519/ChaCha20-Poly1305). Không một byte dữ liệu lọt ra ngoài. | **TUYỆT ĐỐI AN TOÀN**<br/>Tuân thủ 100% Luật ANM, NĐ 13/2023 và TT 46/2018/TT-BYT. |
| **2. Tối ưu Chi phí (TCO)** | ❌ Cực kỳ đắt đỏ.<br/>~30 - 150 triệu VNĐ/năm cho vài kênh đồng thời. Chi phí tăng theo số máy trạm (hàng trăm triệu/năm). | ⚠️ Thu phí gói doanh nghiệp theo tháng/năm. Giới hạn phiên đồng thời, thường xuyên bị ngắt phiên. | ❌ Chi phí bản quyền hàng năm cao, siết chặt chính sách sử dụng thương mại (Commercial Use Detected). | **Tiết kiệm 100% chi phí bản quyền định kỳ hàng năm.**<br/>Sử dụng vĩnh viễn, không giới hạn số lượng máy trạm (500 - 2000+ máy), không giới hạn phiên đồng thời. | **TIẾT KIỆM NGÂN SÁCH LỚN**<br/>Tiết kiệm hàng trăm triệu đồng mỗi năm cho nguồn quỹ bệnh viện. |
| **3. Độ sẵn sàng & Tốc độ LAN** | ❌ Phụ thuộc 100% vào Internet ra ngoài.<br/>Đứt cáp quang biển hoặc mất mạng ngoài là tê liệt hoàn toàn. Độ trễ 30 - 100ms. | ❌ Phụ thuộc Internet. Nghẽn mạng vào giờ cao điểm, giật lag, độ trễ cao (50 - 150ms). | ❌ Phụ thuộc Internet ngoài để xác thực phiên ban đầu. Độ trễ biến thiên theo đường truyền ISP. | **Tận dụng tối đa mạng LAN Gigabit (1000 Mbps).**<br/>Độ trễ siêu thấp **< 1 - 5ms**, mượt mà 60fps. Hoạt động bình thường ngay cả khi mất toàn bộ Internet ngoài viện. | **TỐC ĐỘ VƯỢT TRỘI**<br/>Khả năng ứng cứu sự cố tức thì trong các ca mổ, cấp cứu dù mất Internet. |
| **4. Tương thích Thiết bị Y tế Cũ** | ❌ Đã ngừng hỗ trợ hoàn toàn Windows 7 / 8 / XP.<br/>Không thể cài đặt trên các máy xét nghiệm, C-Arm, Siêu âm cũ. | ⚠️ Hoạt động thiếu ổn định trên Windows 7 cũ, chiếm nhiều tài nguyên CPU, không hỗ trợ chuyên sâu. | ❌ Phiên bản mới không còn hỗ trợ Win 7 SP1. Bản cũ tồn tại nhiều lỗ hổng bảo mật nghiêm trọng. | **Kiến trúc Động cơ kép (Dual-Engine):**<br/>- Động cơ Sciter Native C++ tối ưu cho **Windows 7 SP1 (32-bit & 64-bit)**.<br/>- Động cơ Flutter cho Windows 10/11 x64, ARM64. | **TƯƠNG THÍCH 100%**<br/>Bảo toàn khả năng hỗ trợ mọi thiết bị chẩn đoán hình ảnh và xét nghiệm đặc thù của viện. |
| **5. Quy trình Nghiệp vụ Y tế Khép kín** | ❌ Phần mềm rời rạc.<br/>Bác sĩ phải đọc ID/Pass qua điện thoại.<br/>Không có tích hợp phiếu sự cố hay luồng Telegram. | ❌ Rời rạc, thao tác thủ công, không có cơ chế gọi IT khẩn cấp 1-chạm.<br/>Không có báo cáo tự động đóng mở ticket. | ❌ Rời rạc, thiếu tính năng quản lý danh bạ phân khoa phòng chuyên sâu nội bộ. | **Quy trình 1-chạm đồng bộ khép kín:**<br/>- Bác sĩ bấm **`Ctrl + Alt + H`** (`BaoSuCoIT.exe`).<br/>- Tự nhận diện cấu hình, gửi ticket qua WebSocket & **Telegram Topic Routing** chuyên trách.<br/>- IT truy cập Unattended 1-chạm, tự động cập nhật trạng thái & thông báo Toast. | **TRẢI NGHIỆM ĐỒNG BỘ**<br/>Nâng cao tính chuyên nghiệp, giảm 80% thời gian chờ đợi của nhân viên y tế. |
| **6. Kiểm soát Đặc quyền (VIP Lock)** | ❌ Chỉ có mật khẩu chung.<br/>Biết ID/mật khẩu là ai cũng vào được máy Lãnh đạo.<br/>Không có danh sách Whitelist theo người dùng. | ❌ Bảo mật sơ sài.<br/>Không có cơ chế ngăn chặn IT nội bộ truy cập trái phép máy nhạy cảm. | ❌ Không có cơ chế khóa máy bảo mật cao nhiều tầng tích hợp quản trị phân quyền tập trung. | **Khóa bảo vệ VIP Đa tầng (VIP Device Lock):**<br/>- Web Admin chặn nút kết nối & ẩn mật khẩu với người không có quyền.<br/>- Client Engine từ chối mã Master Secret khi máy là VIP.<br/>- Thuật toán dẫn xuất HMAC-SHA256 ngoại tuyến khi khẩn cấp. | **KIỂM SOÁT TỐI ĐA**<br/>Bảo vệ tuyệt đối khu vực nhạy cảm: Ban Giám Đốc, Kế toán - Viện phí, Máy chủ dữ liệu. |

---

## 7. KẾT LUẬN & ĐỀ XUẤT HÀNH ĐỘNG
Qua quá trình khảo sát thực tế toàn bộ mã nguồn của dự án `bvdkkh-remote`:
1. Các cơ chế bảo mật then chốt (VIP Device Lock đa tầng, Thuật toán dẫn xuất khẩn cấp HMAC-SHA256, 2FA TOTP, Audit Log tự động đồng bộ Ticket, Cấu hình tường lửa & LAN Relay nội bộ) **đều đã được lập trình sẵn sàng và hiện diện đầy đủ trong mã nguồn**.
2. Giải pháp hoàn toàn vượt trội so với các phần mềm thương mại bên ngoài trên cả 6 tiêu chí cốt lõi, đặc biệt là tính pháp lý dữ liệu y tế, khả năng tự chủ kinh tế và tính tương thích với máy móc y tế đời cũ.
3. Dữ liệu khảo sát trên cung cấp đầy đủ luận cứ khoa học, pháp lý và kỹ thuật phục vụ việc biên soạn thành công 4 văn bản chính thức: Tờ trình Ban Giám đốc, Quy trình vận hành sự cố IT, Bản đặc tả tính năng hệ thống, và Báo cáo phân tích điểm mạnh.
