# DISPATCH — worker_m2

## Task
Biên soạn tài liệu: `docs/02_quy_trinh_van_hanh_su_co_it.md` (Quy trình Vận hành Chuẩn SOP Tiếp nhận & Xử lý Sự cố CNTT qua Hệ thống "BVĐKKH - Remote").

## File Sở Hữu Độc Quyền
- `docs/02_quy_trinh_van_hanh_su_co_it.md`

## Input Files (Bắt buộc đọc trước khi thực hiện)
- `c:/Work/bvdkkh-remote/.agents/teamwork/ORIGINAL_REQUEST.md`
- `c:/Work/bvdkkh-remote/.agents/teamwork/orchestrator_1/PROJECT.md`
- `c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_1/survey_report.md`
- `c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_2/survey_report.md`
- `c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_3/survey_report.md`

## Yêu Cầu Chi Tiết (Theo R2 của ORIGINAL_REQUEST.md)
1. Xây dựng Quy trình Chuẩn (SOP) với các lưu đồ trực quan bằng cú pháp Mermaid `flowchart TD` / `flowchart LR`.
2. Quy trình dành cho Nhân viên Y tế / Khoa Phòng (Bác sĩ, Điều dưỡng, Dược sĩ, Nhân viên hành chính):
   - Thao tác gọi hỗ trợ 1-chạm qua phím tắt toàn cục `Ctrl + Alt + H` do `BaoSuCoIT.exe` xử lý.
   - Giao diện hộp thoại báo sự cố `support_dialog.ps1`: Tự động nhận diện Máy tính, IP, Khoa/Phòng, chọn 6 danh mục sự cố (HIS/LIS, Máy in, Mạng, Máy chậm, Cài phần mềm, Khác), đính kèm tối đa 5 file ảnh chụp màn hình/nhật ký.
   - Cách nhận diện và đọc thông tin máy từ hình nền bệnh viện chuẩn (tên máy chữ to `#296AC4` được vẽ tự động qua `set_wallpaper.ps1`).
   - Theo dõi thông báo xử lý: Trình chạy ngầm `ticket_watcher.ps1` tự động bắn Windows Toast / BalloonTip và phát âm thanh chuông khi kỹ thuật viên tiếp nhận và hoàn tất xử lý.
3. Quy trình dành cho Kỹ thuật viên Phòng CNTT:
   - Tiếp nhận thông báo tức thời qua Telegram Bot theo Topic chuyên trách (Topic 7: his_lis, 8: printer, 9: network, 10: slow_pc, 11: software_install, 12: hardware_other).
   - Truy cập Cổng quản trị Web Admin (`http://172.16.3.28:21114`) hoặc app client: Xem danh sách ticket thời gian thực qua WebSocket, nhận xử lý (Claim), chuyển trạng thái `in_progress`.
   - Thực hiện điều khiển Unattended Access (1-chạm kết nối không gián đoạn công việc bác sĩ qua Master Secret hoặc Web Remote Desktop).
   - Nghiệm thu, phân loại và đóng ticket (tự động chuyển trạng thái `resolved`, cập nhật Telegram Topic và bắn Toast cho bác sĩ).
4. Quy trình Bảo vệ Đặc biệt (VIP Device Lock SOP):
   - Cơ chế kiểm soát nghiêm ngặt đối với máy Ban Giám Đốc, Kế toán - Tài chính, Máy chủ HIS/PACS/LIS.
   - Chỉ Super Admin hoặc kỹ thuật viên được cấp quyền đích danh qua whitelist (`device_admin_access`) mới được nhìn thấy và kết nối.
   - Thao tác phê duyệt và cấp quyền tạm thời/vĩnh viễn qua Web Admin (`HandleSetVipAccess`).
   - Xử lý tình huống khẩn cấp ngoại tuyến qua thuật toán dẫn xuất mật khẩu HMAC-SHA256.
5. Bảng phân công trách nhiệm (RACI matrix), thời gian cam kết dịch vụ (SLA) theo mức độ nghiêm trọng (P1 khẩn cấp, P2 cao, P3 trung bình, P4 thấp), và biểu mẫu biên bản sự cố.

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Output
Tạo tệp: `c:/Work/bvdkkh-remote/docs/02_quy_trinh_van_hanh_su_co_it.md`
Báo cáo bàn giao: `c:/Work/bvdkkh-remote/.agents/teamwork/worker_m2/handoff.md`


## 2026-10-06T02:30:58Z
Caller: b4a8df29-36b8-435a-b413-c1831c23f60f (parent)
Priority: MESSAGE_PRIORITY_HIGH
Content:
You are worker_m2. Your working directory is c:/Work/bvdkkh-remote/.agents/teamwork/worker_m2.
You exclusively own and must create: c:/Work/bvdkkh-remote/docs/02_quy_trinh_van_hanh_su_co_it.md.
Read c:/Work/bvdkkh-remote/.agents/teamwork/ORIGINAL_REQUEST.md, c:/Work/bvdkkh-remote/.agents/teamwork/orchestrator_1/PROJECT.md, and c:/Work/bvdkkh-remote/.agents/teamwork/worker_m2/DISPATCH.md.
Also inspect c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_1/survey_report.md, c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_2/survey_report.md, and c:/Work/bvdkkh-remote/.agents/teamwork/explorer_survey_3/survey_report.md.
Author docs/02_quy_trinh_van_hanh_su_co_it.md with comprehensive SOP, visual Mermaid flowcharts (flowchart TD/LR), detailed procedures for Medical Staff (Ctrl+Alt+H BaoSuCoIT, wallpaper computer name, ticket_watcher notifications), IT Technicians (Telegram Bot Topic routing, Web Admin ticket queue, Unattended Access, closing tickets), and VIP Device Lock SOP (Directorate, Finance, Core Servers access rules), along with RACI matrix and SLAs.
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
When complete, write your handoff report to c:/Work/bvdkkh-remote/.agents/teamwork/worker_m2/handoff.md and send a completion message to parent.
