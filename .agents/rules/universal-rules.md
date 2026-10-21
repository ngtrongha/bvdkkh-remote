---
name: universal-rules
version: 1.0.0
priority: P0
trigger: always_on
---

# Universal Rules (TIER 0) - AG Kit

> Always-active rules that apply to every request, regardless of domain.

---

## 🌐 Language Handling

When user's prompt is NOT in English:

1. **Internally translate** for better comprehension
2. **Respond in user's language** - match their communication
3. **Code comments/variables** remain in English

---

## 🧹 Clean Code (Global Mandatory)

**ALL code MUST follow `@[skills/clean-code]` rules. No exceptions.**

- **Code**: Concise, direct, no over-engineering. Self-documenting.
- **Testing**: Mandatory. Pyramid (Unit > Int > E2E) + AAA Pattern.
- **Performance**: Measure first. Adhere to current Core Web Vitals standards.
- **Infra/Safety**: 5-Phase Deployment. Verify secrets security.

---

## 🛡️ Error Prevention & Knowledge Retention (Global Mandatory)

**MỖI KHI GẶP LỖI HOẶC SỰ CỐ CÓ XU HƯỚNG LẶP LẠI, BẮT BUỘC PHẢI LƯU LẠI VÀO RULES & MEMORY:**

1. **Ghi nhận ngay lập tức**: Khi phân tích hoặc sửa xong một lỗi/vấn đề lặp lại, Agent BẮT BUỘC phải cập nhật ngay vào:
   - Quy tắc dự phòng & giải pháp: [`.agents/rules/error-prevention.md`](file:///c:/Work/bvdkkh-remote/.agents/rules/error-prevention.md)
   - Bộ nhớ bài học kinh nghiệm: [`.agents/memory/error-patterns.md`](file:///c:/Work/bvdkkh-remote/.agents/memory/error-patterns.md)
2. **Cấu trúc lưu trữ chuẩn (bắt buộc đủ 4 mục)**:
   - **Triệu chứng (Symptom)**: Hiện tượng người dùng gặp phải, thông báo lỗi, log cụ thể.
   - **Nguyên nhân gốc rễ (Root Cause)**: Phân tích nguyên nhân kỹ thuật sâu xa tại sao lỗi xảy ra.
   - **Giải pháp triệt để (Resolution)**: Code/thao tác xử lý cụ thể đã kiểm chứng.
   - **Quy tắc phòng ngừa (Prevention Rule)**: Ràng buộc kỹ thuật bắt buộc tuân theo để lỗi không bao giờ tái diễn.
3. **Tra cứu trước khi làm**: Trước khi sửa lỗi kết nối, auto-installer, sync upstream hoặc build release, Agent BẮT BUỘC phải đối chiếu danh mục này để tránh lặp lại lỗi cũ.


---
