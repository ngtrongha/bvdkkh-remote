# BÁO CÁO KIỂM THỬ THÁCH THỨC ĐỘC LẬP (EMPIRICAL CHALLENGER REPORT)

**Tác vụ:** Kiểm định đối kháng (Adversarial Verification) cú pháp Mermaid, định dạng Markdown và tính nhất quán liên tài liệu (Cross-document consistency) qua toàn bộ 4 tài liệu trong `docs/`.
**Người thực hiện:** `challenger_2` (Empirical Challenger - critic, specialist)
**Thời gian:** 2026-10-06T03:00:00Z
**Phán quyết chính thức (Verdict):** ⚠️ **`REQUEST_CHANGES`**

---

## 1. Observation (Quan sát trực tiếp & Dữ liệu thực nghiệm)

Quá trình kiểm thử thực nghiệm bằng mã nguồn và parser độc lập ghi nhận các kết quả cụ thể như sau:

### 1.1. Kiểm định cú pháp Mermaid (13/13 sơ đồ qua Parser chính thức `mermaid@11.4` + `jsdom`)
Công cụ thực thi: `node test_mermaid_runner.mjs` (sử dụng thư viện `mermaid` chính thức để parse AST).
Tổng số sơ đồ Mermaid: 13 khối qua 4 tài liệu.
- `docs/01_to_trinh_ban_giam_doc.md`: 0 khối Mermaid (thể thức văn bản hành chính dùng bảng biểu tiêu chuẩn).
- `docs/02_quy_trinh_van_hanh_su_co_it.md`: 6 khối Mermaid.
  - Khối 1 (Dòng 49-79, `flowchart TD`): **PASS** (`flowchart-v2`)
  - Khối 2 (Dòng 87-93, `flowchart LR`): **PASS** (`flowchart-v2`)
  - Khối 3 (Dòng 228-242, `flowchart TD`): **PASS** (`flowchart-v2`)
  - Khối 4 (Dòng 331-358, `flowchart TD`): **PASS** (`flowchart-v2`)
  - Khối 5 (Dòng 414-422, `flowchart LR`): **PASS** (`flowchart-v2`)
  - **Khối 6 (Dòng 471-477, `flowchart LR`): ❌ FAIL (PARSER SYNTAX ERROR)**
    - **Lỗi Verbatim từ Mermaid Parser:**
      ```
      Error: Parse error on line 2:
      ...Phản hồi: <= 3 phút | Xử lý: <= 15 phút]
      -----------------------^
      Expecting 'SQE', 'TAGEND', 'UNICODE_TEXT', 'TEXT', 'TAGSTART', got 'PIPE'
      ```
    - **Đoạn mã gốc gây lỗi trong `docs/02_quy_trinh_van_hanh_su_co_it.md` (dòng 471-477):**
      ```mermaid
      flowchart LR
          P1[Mức P1: KHẨN CẤP<br/>Cấp cứu, Phòng mổ, Sập mạng<br/>Phản hồi: <= 3 phút | Xử lý: <= 15 phút]
          P2[Mức P2: MỨC CAO<br/>Phòng khám đông, Máy in xét nghiệm<br/>Phản hồi: <= 10 phút | Xử lý: <= 45 phút]
          P3[Mức P3: TRUNG BÌNH<br/>Máy hành chính, Máy chạy chậm<br/>Phản hồi: <= 30 phút | Xử lý: <= 2 giờ]
          P4[Mức P4: YÊU CẦU THẤP<br/>Cài phần mềm mới, Đặt máy<br/>Phản hồi: <= 2 giờ | Xử lý: <= 24 giờ]
      ```
- `docs/03_dac_ta_tinh_nang_he_thong.md`: 3 khối Mermaid.
  - Khối 1 (Dòng 129-168, `flowchart TB`): **PASS** (`flowchart-v2`)
  - Khối 2 (Dòng 641-659, `sequenceDiagram`): **PASS** (`sequence`)
  - Khối 3 (Dòng 746-763, `flowchart TD`): **PASS** (`flowchart-v2`)
- `docs/04_diem_manh_va_loi_the_giai_phap.md`: 4 khối Mermaid.
  - Khối 1 (Dòng 142-165, `flowchart TD`): **PASS** (`flowchart-v2`)
  - Khối 2 (Dòng 331-341, `flowchart TD`): **PASS** (`flowchart-v2`)
  - Khối 3 (Dòng 346-366, `flowchart TD`): **PASS** (`flowchart-v2`)
  - Khối 4 (Dòng 403-425, `flowchart TD`): **PASS** (`flowchart-v2`)

### 1.2. Kiểm định tính nhất quán liên tài liệu (Cross-document Consistency)
Công cụ thực thi: `python test_cross_document_consistency.py`.

1. **Địa chỉ IP máy chủ On-Premise (`172.16.3.28`):**
   - `docs/01_to_trinh_ban_giam_doc.md`: 6 lần xuất hiện (`172.16.3.28`).
   - `docs/02_quy_trinh_van_hanh_su_co_it.md`: 8 lần xuất hiện (`172.16.3.28`).
   - `docs/03_dac_ta_tinh_nang_he_thong.md`: 16 lần xuất hiện (`172.16.3.28`).
   - `docs/04_diem_manh_va_loi_the_giai_phap.md`: 8 lần xuất hiện (`172.16.3.28`).
   - Dải mạng nội bộ viện: `172.16.0.0/16` (thống nhất). Các IP máy trạm minh họa: `172.16.12.45` (Khoa Cấp Cứu), `172.16.3.102` (Phòng CNTT). Không có bất kỳ IP máy chủ nào khác bị sai lệch hay gõ nhầm.
   - **Đánh giá: 100% NHẤT QUÁN.**

2. **Cổng kết nối mạng (Port Numbers):**
   - Cổng 21114 (API RESTful, Web Admin UI, Reverse Proxy WebSocket): Nhất quán trên cả 4 tài liệu.
   - Cổng 21115 (hbbs NAT test TCP): Nhất quán trên docs/01, docs/03, docs/04.
   - Cổng 21116 (hbbs ID / Rendezvous / Heartbeat TCP & UDP): Nhất quán trên docs/01, docs/03, docs/04.
   - Cổng 21117 (hbbr LAN Gigabit Relay TCP): Nhất quán trên cả 4 tài liệu.
   - Cổng 21118 (hbbs WebSocket `/ws/id` TCP): Nhất quán trên docs/01, docs/03.
   - Cổng 21119 (hbbr WebSocket `/ws/relay` TCP): Nhất quán trên docs/01, docs/03.
   - Các cổng phụ trợ: 8080 (backend Go port), 3478/443 (Coturn STUN/TURN), UDP 7/9 (Wake-on-LAN): Khớp chính xác với mã nguồn tại docs/03.
   - **Đánh giá: 100% NHẤT QUÁN.**

3. **Phím tắt toàn cục gọi hỗ trợ (`Ctrl + Alt + H`):**
   - `docs/01`: 6 lần xuất hiện đúng dạng `Ctrl + Alt + H`.
   - `docs/02`: 5 lần xuất hiện đúng dạng `Ctrl + Alt + H` (và 1 công thức LaTeX `$$\mathbf{Ctrl} + \mathbf{Alt} + \mathbf{H}$$`).
   - `docs/03`: 8 lần xuất hiện đúng dạng `Ctrl + Alt + H`.
   - `docs/04`: 4 lần xuất hiện đúng dạng `Ctrl + Alt + H`, tuy nhiên tại dòng 482 xuất hiện 1 lần viết liền không dấu cách:
     - `docs/04_diem_manh_va_loi_the_giai_phap.md:482`:
       `| 6 | **Tốc độ tiếp nhận sự cố (HelpDesk SLA)**| 4/10 | 3/10 | 3/10 | **9.5/10** | 1-chạm `Ctrl+Alt+H`, giảm 80% thời gian chờ của bác sĩ. |`
   - **Đánh giá: 95% NHẤT QUÁN (Cần chuẩn hóa dấu cách tại dòng 482 docs/04).**

4. **Tên tệp tiến trình và Scripts:**
   - `BaoSuCoIT.exe`: Khớp 100% cả 4 tài liệu.
   - `ticket_watcher.ps1`: Khớp 100% (docs/02, docs/03, docs/04).
   - `set_wallpaper.ps1`: Khớp 100% (docs/02, docs/03).
   - `cai_dat.bat`: Khớp 100% (docs/01, docs/03, docs/04).
   - `install_official.ps1`: Khớp 100% (docs/03).
   - `support_dialog.ps1`: Khớp 100% (docs/01, docs/02, docs/03, docs/04).
   - `support_launcher.vbs`: Khớp 100% (docs/03).
   - `lookup_password.ps1`: Khớp 100% (docs/02, docs/03, docs/04).
   - Tên dịch vụ: `BVĐKKH - Remote Service` (tên hiển thị) và `BVDKKH - Remote` (tên service nội bộ Windows Registry / sc.exe).
   - **Đánh giá: 100% NHẤT QUÁN.**

5. **Telegram Topics & Nhóm điều hành:**
   - Supergroup ID: `-1004384471854` xuất hiện đồng nhất tại cả 4 tài liệu.
   - Danh sách 7 Topic chuyên trách:
     - Topic 7 (`his_lis`): Sự cố Phần mềm Bệnh viện (HIS / LIS / PACS) $\rightarrow$ Tổ Quản trị Phần mềm HIS/LIS.
     - Topic 8 (`printer`): Sự cố Máy In / Kẹt giấy / Không in được phiếu $\rightarrow$ Tổ Phần cứng & Ngoại vi.
     - Topic 9 (`network`): Sự cố Mạng nội bộ / Mất kết nối Internet $\rightarrow$ Tổ Hạ tầng Mạng.
     - Topic 10 (`slow_pc`): Máy tính chạy chậm / Treo máy $\rightarrow$ Tổ Hỗ trợ Kỹ thuật Máy trạm.
     - Topic 11 (`software_install`): Yêu cầu Cài đặt phần mềm mới $\rightarrow$ Tổ Triển khai Phần mềm.
     - Topic 12 (`hardware_other`): Sự cố Phần cứng và Thiết bị khác $\rightarrow$ Tổ Kỹ thuật Tổng hợp.
     - Topic 37 (`archived`): Lưu trữ hồ sơ sự cố đã hoàn thành $\rightarrow$ Đánh giá KPI.
   - **Đánh giá: 100% NHẤT QUÁN.**

### 1.3. Cấu trúc Markdown & Bảng biểu
- 100% các khối code fence (```) được đóng hợp lệ.
- 100% các bảng Markdown có số lượng cột giữa hàng tiêu đề, đường phân cách và các hàng dữ liệu khớp nhau hoàn hảo (không bị xô lệch cột).
- Không có liên kết cục bộ (relative links) bị gãy.

---

## 2. Logic Chain (Chuỗi suy luận)

1. Từ **Observation 1.1**, sơ đồ Khối 6 trong `docs/02_quy_trinh_van_hanh_su_co_it.md` (dòng 471-477) chứa các nhãn node chưa được bọc trong dấu ngoặc kép (`"..."`), cụ thể:
   `P1[Mức P1: KHẨN CẤP<br/>Cấp cứu, Phòng mổ, Sập mạng<br/>Phản hồi: <= 3 phút | Xử lý: <= 15 phút]`
2. Theo đặc tả ngữ pháp Mermaid Flowchart, ký tự thanh đứng `|` trong nhãn node chưa bọc nháy kép bị lexer nhận diện nhầm là cú pháp nhãn liên kết (`-->|label|`), đồng thời ký tự `<` trong `<= 3 phút` bị lexer nhận diện là thẻ mở HTML (`TAGSTART`). Khi lexer gặp dấu `=` và ký tự `|`, nó báo lỗi cú pháp: `Expecting 'SQE', 'TAGEND', 'UNICODE_TEXT', 'TEXT', 'TAGSTART', got 'PIPE'`.
3. Lỗi cú pháp này dẫn đến việc toàn bộ sơ đồ phân cấp SLA tại Phần VII của `docs/02` **bị vỡ hoàn toàn (crash parser)** trên mọi môi trường hiển thị Markdown/Mermaid chuẩn (như GitHub, GitLab, VS Code Markdown Preview, Obsidian, mdBook).
4. Thực nghiệm kiểm chứng với bản vá (bọc nháy kép `P1["..."]`): Parser Mermaid chính thức phân tích thành công và trả về `{ diagramType: 'flowchart-v2', config: {} }`.
5. Từ **Observation 1.2**, tại `docs/04_diem_manh_va_loi_the_giai_phap.md` dòng 482, tổ hợp phím tắt bị viết thiếu khoảng trắng (`Ctrl+Alt+H`), trong khi 19 vị trí khác xuyên suốt 4 tài liệu đều sử dụng thống nhất định dạng có khoảng trắng `Ctrl + Alt + H`.
6. Kết hợp (3) và (5), tài liệu tồn tại một lỗi cú pháp nghiêm trọng làm hỏng hiển thị sơ đồ và một lỗi nhỏ về định dạng phím tắt. Theo quy chế làm việc của tác nhân kiểm định độc lập, challenger không được tự ý sửa đổi tệp mục tiêu mà phải báo cáo chi tiết và yêu cầu tác giả tài liệu (`doc_author_1` / `orchestrator_1`) thực hiện hiệu chỉnh.

---

## 3. Caveats (Phạm vi & Giả định)

1. **Hiển thị hình ảnh thực tế (Visual Rendering Dimensions):** Kiểm định này tập trung vào tính hợp lệ cú pháp (syntax validation) của Mermaid và định dạng Markdown. Độ rộng khung hiển thị (viewport width) trên các màn hình di động nhỏ có thể làm các sơ đồ Mermaid nằm ngang (`flowchart LR`) xuất hiện thanh cuộn ngang (scroll horizontal), đây là đặc tính thông thường của trình duyệt Web chứ không phải lỗi cú pháp.
2. **Quyền sửa đổi:** Tuân thủ triệt để nguyên tắc cách ly vai trò (Review-only), `challenger_2` không thực hiện ghi đè hoặc chỉnh sửa trực tiếp vào 4 tệp trong thư mục `docs/`.

---

## 4. Conclusion (Kết luận & Kiến nghị)

### Phán quyết: ⚠️ **`REQUEST_CHANGES`**

Hệ thống tài liệu đã được biên soạn rất quy mô, chuyên nghiệp, thông số kỹ thuật (IP `172.16.3.28`, các cổng 21114-21119, danh mục 7 Topic Telegram, cơ chế VIP Device Lock, các script PowerShell) khớp 100% giữa 4 tài liệu và mã nguồn.
Tuy nhiên, tài liệu **CHƯA ĐẠT ĐIỀU KIỆN PHÊ DUYỆT NGHIỆM THU (BLOCKER)** do tồn tại 1 lỗi vỡ cú pháp sơ đồ Mermaid và 1 điểm không nhất quán phím tắt:

### Các điểm bắt buộc sửa đổi (Required Actions):

1. **SỬA LỖI CÚ PHÁP MERMAID TẠI `docs/02_quy_trinh_van_hanh_su_co_it.md` (Dòng 471-477):**
   - **Hiện trạng:**
     ```mermaid
     flowchart LR
         P1[Mức P1: KHẨN CẤP<br/>Cấp cứu, Phòng mổ, Sập mạng<br/>Phản hồi: <= 3 phút | Xử lý: <= 15 phút]
         P2[Mức P2: MỨC CAO<br/>Phòng khám đông, Máy in xét nghiệm<br/>Phản hồi: <= 10 phút | Xử lý: <= 45 phút]
         P3[Mức P3: TRUNG BÌNH<br/>Máy hành chính, Máy chạy chậm<br/>Phản hồi: <= 30 phút | Xử lý: <= 2 giờ]
         P4[Mức P4: YÊU CẦU THẤP<br/>Cài phần mềm mới, Đặt máy<br/>Phản hồi: <= 2 giờ | Xử lý: <= 24 giờ]
     ```
   - **Đề xuất sửa đổi (Bọc nháy kép `"..."` và dùng ký hiệu an toàn `&le;` hoặc `<=` trong nháy kép):**
     ```mermaid
     flowchart LR
         P1["Mức P1: KHẨN CẤP<br/>Cấp cứu, Phòng mổ, Sập mạng<br/>Phản hồi: &le; 3 phút | Xử lý: &le; 15 phút"]
         P2["Mức P2: MỨC CAO<br/>Phòng khám đông, Máy in xét nghiệm<br/>Phản hồi: &le; 10 phút | Xử lý: &le; 45 phút"]
         P3["Mức P3: TRUNG BÌNH<br/>Máy hành chính, Máy chạy chậm<br/>Phản hồi: &le; 30 phút | Xử lý: &le; 2 giờ"]
         P4["Mức P4: YÊU CẦU THẤP<br/>Cài phần mềm mới, Đặt máy<br/>Phản hồi: &le; 2 giờ | Xử lý: &le; 24 giờ"]
         P1 --> P2 --> P3 --> P4
     ```

2. **CHUẨN HÓA KHOẢNG TRẮNG PHÍM TẮT TẠI `docs/04_diem_manh_va_loi_the_giai_phap.md` (Dòng 482):**
   - Đổi `1-chạm `Ctrl+Alt+H`` thành `1-chạm `Ctrl + Alt + H`` để đảm bảo 100% nhất quán trên toàn bộ bộ hồ sơ.

---

## 5. Verification Method (Phương thức tái hiện & Kiểm chứng độc lập)

Bất kỳ thành viên hoặc tác nhân nào trong nhóm đều có thể tái hiện độc lập các phát hiện trên bằng các lệnh sau tại thư mục gốc `c:/Work/bvdkkh-remote`:

1. **Tái hiện lỗi cú pháp Mermaid:**
   ```bash
   node test_mermaid_runner.mjs
   ```
   *Kết quả mong đợi:* Báo lỗi tại `docs/02_quy_trinh_van_hanh_su_co_it.md` Khối #6 với thông điệp: `Parse error on line 2: ... got 'PIPE'`.

2. **Kiểm tra tính nhất quán liên tài liệu:**
   ```bash
   python test_cross_document_consistency.py
   ```
   *Kết quả mong đợi:* Hiển thị ma trận phân bổ IP `172.16.3.28`, port 21114-21119, các script và phát hiện 1 vị trí `Ctrl+Alt+H` tại docs/04:482.

3. **Điều kiện vô hiệu hóa phát hiện (Invalidation Condition):**
   Sau khi tác giả tài liệu sửa đổi 2 vị trí trên, chạy lại `node test_mermaid_runner.mjs` đạt `13/13 PASSED` và `python test_cross_document_consistency.py` đạt 100% phím tắt `Ctrl + Alt + H`. Khi đó phán quyết sẽ được nâng lên thành `APPROVE`.
