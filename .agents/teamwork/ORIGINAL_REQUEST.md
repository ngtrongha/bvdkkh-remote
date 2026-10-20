# Original User Request

## Initial Request — 2026-10-06T02:14:30Z

Biên soạn bộ 4 tài liệu chuyên nghiệp (Tờ trình Ban Giám đốc, Quy trình vận hành & xử lý sự cố IT, Bản đặc tả chi tiết tính năng kỹ thuật, Báo cáo phân tích điểm mạnh & lợi thế giải pháp) cho hệ thống "BVĐKKH - Remote" phục vụ phê duyệt và ban hành chính thức tại Bệnh viện Đa khoa Khánh Hòa.

Working directory: c:/Work/bvdkkh-remote
Integrity mode: development

## Requirements

### R1. Tờ trình Ban Giám Đốc Phê duyệt Triển khai (docs/01_to_trinh_ban_giam_doc.md)
- Soạn thảo đúng thể thức văn bản hành chính y tế trang trọng (Kính gửi Ban Giám Đốc Bệnh viện Đa khoa Khánh Hòa).
- Nêu rõ:
  1. Căn cứ pháp lý và bối cảnh (Chuyển đổi số y tế, an toàn thông tin theo quy định Bộ Y tế, bảo mật dữ liệu hồ sơ bệnh án).
  2. Sự cần thiết & Hạn chế khi dùng phần mềm thương mại bên ngoài (Nguy cơ rò rỉ dữ liệu qua server trung gian Internet của TeamViewer/UltraViewer/AnyDesk, chi phí bản quyền hàng năm đắt đỏ, phụ thuộc đường truyền Internet khi mất mạng diện rộng).
  3. Mục tiêu xây dựng và phạm vi triển khai toàn viện (tất cả khoa, phòng, trung tâm).
  4. Nội dung giải pháp tự chủ: Hệ thống điều khiển từ xa nội bộ "BVĐKKH - Remote" và Cổng tiếp nhận sự cố IT một chạm "BaoSuCoIT".
  5. Đánh giá hiệu quả kinh tế (tiết kiệm ngân sách) và an toàn an ninh mạng.
  6. Kiến nghị Ban Giám Đốc phê duyệt đưa vào sử dụng chính thức.

### R2. Quy trình Vận hành & Tiếp nhận Xử lý Sự cố IT (docs/02_quy_trinh_van_hanh_su_co_it.md)
- Xây dựng quy trình chuẩn (SOP) với các lưu đồ dạng Mermaid và bảng phân công rõ ràng:
  1. Quy trình dành cho Nhân viên Y tế / Khoa Phòng: Thao tác gọi hỗ trợ 1-chạm qua phím tắt toàn cục `Ctrl + Alt + H`, gửi phiếu báo sự cố tự động nhận diện thông tin máy qua `BaoSuCoIT.exe`, cách đọc nhanh thông tin máy từ hình nền chuẩn bệnh viện, theo dõi thông báo Toast/âm thanh khi IT xử lý qua `ticket_watcher`.
  2. Quy trình dành cho Kỹ thuật viên Phòng CNTT: Tiếp nhận thông báo tức thời qua Telegram Bot theo từng Topic chuyên trách, truy cập Cổng quản trị Web Admin hoặc app client, thực hiện điều khiển Unattended Access (1-chạm không gián đoạn công việc bác sĩ), phân loại và đóng ticket.
  3. Quy trình bảo vệ đặc biệt (VIP Device Lock): Cơ chế kiểm soát nghiêm ngặt đối với máy Ban Giám Đốc, Kế toán - Tài chính, máy chủ hệ thống (chỉ Super Admin hoặc kỹ thuật viên được cấp quyền đích danh mới được truy cập).

### R3. Bản Đặc tả Chi tiết Tính năng Hệ thống (docs/03_dac_ta_tinh_nang_he_thong.md)
- Trích xuất và đặc tả chính xác 100% dựa trên mã nguồn thực tế của dự án `bvdkkh-remote`:
  1. Phân hệ Client Máy trạm:
     - Tương thích kép: Động cơ Sciter cho Windows 7 SP1 (32-bit & 64-bit) phục vụ máy xét nghiệm, chẩn đoán hình ảnh cũ; Động cơ Flutter cho Windows 10/11 (x64, ARM64).
     - Triển khai tự động 1-click qua `cai_dat.bat` tự nhận diện kiến trúc và hệ điều hành.
     - Khóa an toàn giao diện: Ẩn cấu hình máy chủ, cấm sửa mật khẩu vĩnh viễn, cấm đổi ID, cấm tùy tiện dừng dịch vụ.
     - Chạy ngầm dưới dạng Windows Service tự phục hồi liên tục (`BVĐKKH - Remote Service`).
     - Tự động nhận diện và tái tạo MachineGuid chống trùng lặp ID khi máy trạm được Ghost/Clone hàng loạt.
     - Tự động kích hoạt Wake-on-LAN (WOL) và gán thông tin tên máy lên hình nền nhận diện bệnh viện.
     - Module phím tắt toàn cục `Ctrl + Alt + H` (`BaoSuCoIT.exe`) và trình thông báo nền `ticket_watcher.ps1`.
  2. Phân hệ Máy chủ Quản trị (RustDesk API Server Pro):
     - Backend Go hiệu năng cao, cơ sở dữ liệu SQLite/MySQL, chạy On-Premise nội bộ tại IP viện `172.16.3.28`.
     - Cổng quản trị Flutter Web Admin (`rustdesk_admin`) chuẩn giao diện tiếng Việt (`vi-VN`), hỗ trợ Dark/Light mode, Responsive trên PC và Mobile.
     - Web Remote Desktop: Điều khiển máy tính từ xa trực tiếp trên trình duyệt Web không cần cài thêm phần mềm client.
     - Quản lý danh bạ Address Book tập trung, gán nhãn khoa phòng, tìm kiếm tức thì.
     - Hệ thống quản lý Ticket sự cố thời gian thực qua WebSocket, tích hợp bot Telegram với Topic Routing chuyên biệt.
  3. Cơ chế Bảo mật Nâng cao:
     - Phân quyền VIP Device Lock đa tầng (Web Admin chặn nút kết nối + Client RustDesk chặn Master Secret).
     - Thuật toán sinh mật khẩu dự phòng an toàn qua HMAC-SHA256 kết hợp MachineGuid và Salt bí mật.
     - Cơ chế xác thực 2FA TOTP, kiểm soát phiên và nhật ký kiểm toán (Audit Logs) đầy đủ.

### R4. Báo cáo Điểm mạnh, Giá trị & Lợi thế Cạnh tranh (docs/04_diem_manh_va_loi_the_giai_phap.md)
- Lập bảng ma trận so sánh chi tiết giữa "BVĐKKH - Remote" với các giải pháp thương mại (UltraViewer, TeamViewer, AnyDesk) trên 6 trụ cột chính:
  1. An toàn dữ liệu & Pháp lý: 100% máy chủ On-Premise nội bộ, dữ liệu không đi qua Internet hay máy chủ nước ngoài, tuân thủ Luật An toàn thông tin mạng và quy định quản lý dữ liệu y tế của Bộ Y tế.
  2. Tối ưu chi phí: Tiết kiệm 100% phí bản quyền định kỳ hàng năm cho hàng trăm máy trạm y tế.
  3. Độ sẵn sàng & Tốc độ: Tận dụng tối đa băng thông mạng LAN nội bộ gigabit, không phụ thuộc đường truyền Internet bên ngoài.
  4. Tương thích đặc thù y tế: Hỗ trợ trơn tru các dòng máy tính y tế đời cũ chạy Windows 7 (vốn bị nhiều phần mềm mới ngừng hỗ trợ).
  5. Quy trình nghiệp vụ y tế khép kín: Tích hợp sẵn nút báo sự cố khẩn cấp `Ctrl + Alt + H`, điều phối sự cố qua Telegram Topic, quản lý tập trung theo Khoa/Phòng.
  6. Kiểm soát đặc quyền y tế (VIP Device Lock): Bảo vệ tuyệt đối khu vực nhạy cảm (Ban Giám đốc, Kế toán viện phí, PACS/HIS).

## Acceptance Criteria

### Tính Chuẩn xác & Hoàn thiện Tài liệu
- [ ] Cả 4 tệp tài liệu được tạo đầy đủ tại thư mục `docs/` với định dạng Markdown chuyên nghiệp, cấu trúc phân mục rõ ràng, mạch lạc:
  - `docs/01_to_trinh_ban_giam_doc.md`
  - `docs/02_quy_trinh_van_hanh_su_co_it.md`
  - `docs/03_dac_ta_tinh_nang_he_thong.md`
  - `docs/04_diem_manh_va_loi_the_giai_phap.md`
- [ ] Văn phong Tờ trình chuẩn thể thức công văn y tế, thuyết phục, lập luận chặt chẽ.
- [ ] Quy trình vận hành có lưu đồ trực quan bằng cú pháp Mermaid `flowchart TD` / `flowchart LR`.
- [ ] Các thông số kỹ thuật (cổng kết nối, IP nội bộ, file script, kiến trúc Sciter/Flutter, cơ chế VIP lock, Telegram Topic) khớp 100% với mã nguồn hiện hữu của dự án.
- [ ] Bảng so sánh điểm mạnh có dẫn chứng và phân tích cụ thể, không viết chung chung sáo rỗng.
