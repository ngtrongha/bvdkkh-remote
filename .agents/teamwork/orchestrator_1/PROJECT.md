# Project: Bộ Hồ sơ Tài liệu Chính thức "BVĐKKH - Remote"

## Architecture
Hệ thống "BVĐKKH - Remote" là giải pháp điều khiển từ xa, hỗ trợ kỹ thuật và quản lý thiết bị On-Premise nội bộ độc quyền của Bệnh viện Đa khoa Khánh Hòa, gồm 3 phân hệ tương hỗ:
1. **Phân hệ Máy trạm (Client Workstation):**
   - Động cơ kép: Sciter Engine trên Windows 7 SP1 (32-bit & 64-bit) phục vụ máy xét nghiệm, siêu âm, CT/MRI cũ; Flutter Engine trên Windows 10/11 (x64, ARM64) phục vụ máy khám chữa bệnh, máy văn phòng.
   - Triển khai tự động 1-click `cai_dat.bat` / `install_official.ps1`, chạy ngầm qua Windows Service `BVĐKKH - Remote Service` tự phục hồi, chống trùng lặp MachineGuid trên máy Ghost/Clone.
   - Khóa an toàn giao diện (ẩn server settings, cấm sửa pass, cấm đổi ID, cấm dừng service), Wake-on-LAN (WOL), gắn tên máy lên hình nền bệnh viện.
   - Phím tắt toàn cục `Ctrl + Alt + H` (`BaoSuCoIT.exe`), form gửi phiếu `support_dialog.ps1`, trình thông báo nền `ticket_watcher.ps1`.
2. **Phân hệ Máy chủ Quản trị (RustDesk API Server Pro & Web Admin):**
   - Backend Go hiệu năng cao (Iris v12), cơ sở dữ liệu SQLite/MySQL, IP nội bộ On-Premise `172.16.3.28`, hbbs (21115, 21116), hbbr (21117), API/Web (21114/8080).
   - Flutter Web Admin (`rustdesk_admin`) chuẩn tiếng Việt (`vi-VN`), Dark/Light mode, Responsive đa thiết bị, tìm kiếm không dấu.
   - Web Remote Desktop trực tiếp trên trình duyệt bằng WebCodecs & NaCl encryption, không cần cài client.
   - Quản lý danh bạ Address Book, gán nhãn khoa/phòng, quản lý Ticket thời gian thực qua WebSocket, tích hợp Telegram Bot Topic Routing (Topics: 7 His/Lis, 8 Printer, 9 Network, 10 Slow PC, 11 Software, 12 Hardware, 37 Archived).
3. **Phân hệ Bảo mật Đa tầng & Kiểm soát Đặc quyền:**
   - VIP Device Lock 2 tầng: Tầng 1 chặn tại Web Admin & API (ẩn máy, khóa nút kết nối `is_accessible = false`), Tầng 2 máy đích từ chối `ADMIN_MASTER_SECRET` khi cờ `is-vip = true`.
   - Dẫn xuất mật khẩu khẩn cấp ngoại tuyến `HMAC-SHA256(MachineGuid, SecretSalt)`.
   - Xác thực 2FA TOTP (RFC 6238), nhật ký kiểm toán (Audit Logs) kết nối & truyền tệp, tự động cập nhật trạng thái ticket.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Thể thức văn bản hành chính y tế trang trọng | Kính gửi Ban Giám Đốc, cấu trúc tờ trình tiêu chuẩn Nghị định 30/2020/NĐ-CP | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Căn cứ pháp lý & bối cảnh an toàn thông tin | Luật ATTTM 2018, Nghị định 13/2023/NĐ-CP, Thông tư 46/2018/TT-BYT, TT 54/2017/TT-BYT, Luật KBCB 2023 | M1 | ORIGINAL_REQUEST §R1, survey_3 |
| 3 | Thực trạng & Nguy cơ phần mềm thương mại | Rủi ro TeamViewer/UltraViewer (server Internet nước ngoài, chi phí bản quyền định kỳ, đứt cáp quang) | M1, M4 | ORIGINAL_REQUEST §R1, R4 |
| 4 | Hiệu quả kinh tế & Tiết kiệm ngân sách | Tiết kiệm 100% chi phí bản quyền hàng năm cho hàng trăm máy trạm, tận dụng hạ tầng LAN | M1, M4 | ORIGINAL_REQUEST §R1, R4 |
| 5 | Quy trình dành cho Nhân viên Y tế / Khoa Phòng | Phím tắt `Ctrl + Alt + H`, gửi phiếu qua `BaoSuCoIT.exe`, đọc tên máy trên hình nền, nhận thông báo Toast/âm thanh | M2 | ORIGINAL_REQUEST §R2, survey_1 |
| 6 | Quy trình dành cho Kỹ thuật viên IT | Tiếp nhận Telegram Bot theo Topic chuyên trách, Web Admin, Unattended Access, đóng ticket | M2 | ORIGINAL_REQUEST §R2, survey_2 |
| 7 | Quy trình bảo vệ đặc biệt VIP Device Lock | Phê duyệt Super Admin, whitelist truy cập, khóa 2 tầng cho máy BGĐ, Kế toán, Server | M2, M3 | ORIGINAL_REQUEST §R2, R3, survey_3 |
| 8 | Lưu đồ quy trình chuẩn Mermaid SOP | Lưu đồ dạng `flowchart TD` / `flowchart LR` cho luồng báo sự cố, luồng xử lý IT, luồng VIP | M2 | ORIGINAL_REQUEST §R2 |
| 9 | Động cơ kép Sciter (Win7) & Flutter (Win10/11) | Win7 SP1 x86/x64 cho máy xét nghiệm/CĐHA cũ vs Win10/11 x64/arm64 cho máy khám | M3 | ORIGINAL_REQUEST §R3, survey_1 |
| 10 | Triển khai tự động 1-click `cai_dat.bat` | Nhận diện kiến trúc, OS, tạo alias binary, đăng ký service, mở tường lửa, cấu hình silent | M3 | ORIGINAL_REQUEST §R3, survey_1 |
| 11 | Khóa an toàn giao diện Client | Khóa cứng IP `172.16.3.28`, ẩn cài đặt server/network, cấm sửa pass, cấm đổi ID, cấm dừng service | M3 | ORIGINAL_REQUEST §R3, survey_1 |
| 12 | Windows Service tự phục hồi & Chống trùng GUID | Dịch vụ `BVĐKKH - Remote Service`, watchdog restart, phát hiện và tái tạo MachineGuid bản Ghost | M3 | ORIGINAL_REQUEST §R3, survey_1 |
| 13 | Wake-on-LAN & Hình nền nhận diện | Tắt Fast Startup, mở UDP 7/9, vẽ tên máy `#296AC4` lên hình nền bệnh viện | M3 | ORIGINAL_REQUEST §R3, survey_1 |
| 14 | RustDesk API Server Pro & Cổng Web Admin | Backend Go Iris v12, SQLite/MySQL, IP `172.16.3.28`, Web Admin Flutter tiếng Việt, Dark/Light mode | M3 | ORIGINAL_REQUEST §R3, survey_2 |
| 15 | Web Remote Desktop trên trình duyệt | WebCodecs, NaCl Curve25519/ChaCha20-Poly1305, không cài app, đa cửa sổ floating | M3 | ORIGINAL_REQUEST §R3, survey_2 |
| 16 | Quản lý Ticket & Telegram Topic Routing | WebSocket broadcast, Telegram Topics (7: HIS/LIS, 8: Máy in, 9: Mạng, 10: Máy chậm, 11: Cài phần mềm, 12: Khác) | M3 | ORIGINAL_REQUEST §R3, survey_2 |
| 17 | Cơ chế Bảo mật VIP Device Lock & HMAC-SHA256 | Phân quyền 2 tầng, thuật toán `HMAC-SHA256(MachineGuid, Salt)`, 2FA TOTP RFC 6238, Audit Logs | M3 | ORIGINAL_REQUEST §R3, survey_2 |
| 18 | Ma trận so sánh 6 trụ cột chi tiết | So sánh định lượng & định tính với TeamViewer, UltraViewer, AnyDesk trên 6 trụ cột y tế | M4 | ORIGINAL_REQUEST §R4, survey_3 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Tờ trình Ban Giám Đốc | Biên soạn `docs/01_to_trinh_ban_giam_doc.md` chuẩn thể thức y tế | None | DONE |
| M2 | Quy trình Vận hành & Sự cố IT | Biên soạn `docs/02_quy_trinh_van_hanh_su_co_it.md` kèm Mermaid SOP | None | DONE |
| M3 | Đặc tả Tính năng Kỹ thuật | Biên soạn `docs/03_dac_ta_tinh_nang_he_thong.md` chuẩn xác 100% mã nguồn | None | DONE |
| M4 | Báo cáo Điểm mạnh & Lợi thế | Biên soạn `docs/04_diem_manh_va_loi_the_giai_phap.md` ma trận 6 trụ cột | None | DONE |
| M5 | Kiểm toán & Nghiệm thu Toàn diện | Rà soát cross-doc, kiểm tra thể thức, kiểm toán tính nguyên bản & chất lượng | M1, M2, M3, M4 | DONE |

## Interface Contracts & Document Standards
- Thư mục đầu ra bắt buộc: `docs/` tại thư mục gốc dự án `c:/Work/bvdkkh-remote/docs/`.
- Định dạng: Markdown chuẩn (`.md`), tiêu đề phân cấp logic, bảng biểu chi tiết, trích dẫn văn bản quy phạm pháp luật và thông số kỹ thuật chính xác.
- Tính nhất quán giữa các tài liệu:
  - Tên hệ thống: **"BVĐKKH - Remote"**
  - Công cụ một chạm: **"BaoSuCoIT"** (phím tắt `Ctrl + Alt + H`)
  - Máy chủ On-Premise: `172.16.3.28` (các cổng 21114, 21115, 21116, 21117, 21118, 21119)
  - Phân quyền VIP: **VIP Device Lock**
  - Khung pháp lý: Luật ATTTM 2018, Nghị định 13/2023/NĐ-CP, Thông tư 46/2018/TT-BYT, Thông tư 54/2017/TT-BYT, Luật Khám bệnh chữa bệnh 2023.

## Code & Document Layout
```
docs/
├── 01_to_trinh_ban_giam_doc.md        # M1: Tờ trình Ban Giám Đốc Phê duyệt Triển khai (Hoàn thành)
├── 02_quy_trinh_van_hanh_su_co_it.md   # M2: Quy trình Vận hành & Tiếp nhận Xử lý Sự cố IT (Hoàn thành)
├── 03_dac_ta_tinh_nang_he_thong.md     # M3: Bản Đặc tả Chi tiết Tính năng Hệ thống (Hoàn thành)
└── 04_diem_manh_va_loi_the_giai_phap.md # M4: Báo cáo Điểm mạnh, Giá trị & Lợi thế Cạnh tranh (Hoàn thành)
```
