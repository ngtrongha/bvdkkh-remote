---
name: release-workflow
version: 2.0.0
priority: P0
trigger: model_decision
description: Quy trình phát triển trên nhánh main, hỏi xác nhận người dùng trước khi merge sang nhánh win7-lts và feat/upgrade-flutter-win10, và tự động kích hoạt build sau khi merge.
---

# Quy trình Phát triển & Release Đa nhánh (Dual-Branch Release Workflow)

> **QUY TẮC CỐT LÕI**: 
> 1. Mọi tác vụ code/sửa lỗi phải thực hiện trực tiếp trên nhánh `main`.
> 2. Sau khi hoàn thành trên `main`, **BẮT BUỘC PHẢI HỎI XÁC NHẬN NGƯỜI DÙNG** trước khi merge sang các nhánh build.
> 3. Khi người dùng xác nhận, tự động merge sang `win7-lts` (chỉ build Win7) và `feat/upgrade-flutter-win10` (build Win10, Android, iOS), sau đó tự động kích hoạt GitHub Actions build cho cả 2 nhánh.

---

## 🏛️ 1. Phân vai các nhánh

| Nhánh | Vai trò | Mục tiêu build |
|---|---|---|
| **`main`** | **Nhánh làm việc chính** | Code, sửa lỗi, review, commit trực tiếp tại đây. Luôn là nhánh làm việc mặc định. |
| **`win7-lts`** | **Nhánh build Windows 7** | Chỉ build Windows 7 (`i686` Sciter) tương thích mọi phiên bản Windows 7 (32-bit & 64-bit). Bỏ qua Flutter Win10, Android, iOS, macOS. |
| **`feat/upgrade-flutter-win10`** | **Nhánh build Win10+, Mobile** | Build Windows 10/11 (x64, arm64), Android (apk, universal), và iOS (ipa) dùng Flutter 3.44+/3.47+. |

---

## 🔄 2. Quy tắc Đồng bộ Upstream (Upstream Sync Rule)

> ⚠️ **BẮT BUỘC KIỂM TRA SUBMODULE `hbb_common`**:
> Mỗi khi đồng bộ hoặc merge từ Upstream (RustDesk upstream/master hoặc tag mới):
> 1. **Kiểm tra submodule `libs/hbb_common`**: Luôn kiểm tra xem Upstream commit có cập nhật submodule `libs/hbb_common` hay không.
> 2. **Đồng bộ fork `ngtrongha/hbb_common`**: Nếu upstream thay đổi `hbb_common`, phải rebase/merge commit upstream đó vào `ngtrongha/hbb_common`.
> 3. **Tương thích dependencies & Cargo.lock**: Đảm bảo các dependency và patch trong `hbb_common/Cargo.toml` (ví dụ `tokio-tungstenite`, `tungstenite`, `webrtc`, ...) khớp chính xác với root `Cargo.toml` và `Cargo.lock` để tránh lỗi build `--locked`.
> 4. **Bảo toàn cấu hình BVĐKKH**: Luôn giữ vững cấu hình máy chủ nội bộ trong `libs/hbb_common/src/config.rs`:
>    - `pub const RENDEZVOUS_SERVERS: &[&str] = &["172.16.3.28"];`
>    - `pub const RS_PUB_KEY: &str = "0RtoIptoH30Glx75q0DuScwdUgLVwf5oqZ0hgCnInNI=";`
>    - Các keys: `OPTION_ALLOW_AUTO_UPDATE`, `OPTION_ALLOW_REMOTE_CONFIG_MODIFICATION`.
> 5. **Cập nhật pointer**: Đẩy thay đổi lên repository `ngtrongha/hbb_common` và cập nhật submodule commit trong root repo trên nhánh `main`.

---

## 📌 3. Quy trình thực thi từng bước (WORKFLOW STEPS)

### BƯỚC 1: Phát triển & kiểm tra trên nhánh `main`
1. Đảm bảo nhánh hiện tại là `main`:
   ```bash
   git checkout main
   ```
2. Thực hiện toàn bộ code/sửa lỗi trên `main`.
3. Kiểm tra static analysis và kiểm tra mã nguồn:
   - Đảm bảo không có lỗi cú pháp hoặc runtime error.
   - Kiểm tra Copyright Header bắt buộc ở đầu các file:
     ```dart
     // Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
     // Project: BVĐKKH - Remote
     // Author: Nguyễn Trọng Hà
     ```
4. Commit thay đổi lên `main` theo chuẩn Conventional Commits (`feat(...)`, `fix(...)`, `chore(...)`) và push:
   ```bash
   git push origin main
   ```

---

### BƯỚC 2: Cổng xác nhận người dùng (MANDATORY CONFIRMATION GATE)

> ⛔ **BẮT BUỘC DỪNG LẠI & HỎI XÁC NHẬN**: 
> Tuyệt đối KHÔNG tự ý merge sang nhánh `win7-lts` và `feat/upgrade-flutter-win10` khi chưa có câu trả lời xác nhận từ người dùng.

Sau khi commit xong trên `main`, AI phải tóm tắt ngắn gọn các thay đổi và hỏi người dùng:
> *"Tôi đã hoàn thành và kiểm tra các thay đổi trên nhánh `main`. Bạn có xác nhận muốn merge sang nhánh `win7-lts` (cho Windows 7) và `feat/upgrade-flutter-win10` (cho Windows 10, Android, iOS) để tự động kích hoạt quy trình build release không?"*

---

### BƯỚC 3: Merge sang các nhánh build (Sau khi người dùng đồng ý)

Khi người dùng đã xác nhận đồng ý:

#### A. Merge sang nhánh Windows 10+ / Mobile (`feat/upgrade-flutter-win10`):
```bash
git checkout feat/upgrade-flutter-win10
git merge main -m "chore(sync): merge main into feat/upgrade-flutter-win10"
git push origin feat/upgrade-flutter-win10
```

#### B. Merge sang nhánh Windows 7 (`win7-lts`):
> ⚠️ **LƯU Ý ĐẶC BIỆT KHI MERGE SANG WIN7**:
> Nhánh `win7-lts` sử dụng Flutter 3.22.3 (Dart 3.4.4) dành riêng cho Windows 7 LTS. Khi merge từ `main`, **BẮT BUỘC BẢO TOÀN** các file sau của `win7-lts` (không để dependencies Dart 3.5+ hoặc workflow đa nền tảng từ main đè lên):
> 1. `.github/workflows/flutter-build.yml`
> 2. `.github/workflows/bridge.yml`
> 3. `flutter/pubspec.yaml`
> 4. `flutter/pubspec.lock`
> 5. `flutter/ios/`
> Và xóa file `ios.yml` nếu có.

```powershell
git checkout win7-lts
git merge main --no-commit
# Giữ nguyên cấu hình build và dependencies riêng của Win7
git checkout HEAD -- .github/workflows/flutter-build.yml .github/workflows/bridge.yml flutter/pubspec.yaml flutter/pubspec.lock flutter/ios/
if (Test-Path .github/workflows/ios.yml) { Remove-Item -Force .github/workflows/ios.yml }
git commit -m "chore(sync): merge main into win7-lts preserving win7 build workflow & pubspec"
git push origin win7-lts
```

#### C. Chuyển lại nhánh làm việc về `main`:
```bash
git checkout main
```

---

### BƯỚC 4: Tự động kích hoạt GitHub Actions Build (`Flutter Tag Build`)

Ngay sau khi push cả 2 nhánh, tự động kích hoạt build cho cả 2 nhánh:

```powershell
powershell -ExecutionPolicy Bypass -File rustdesk\trigger_build.ps1
```

Hoặc gọi trực tiếp qua GitHub CLI:
```bash
gh -R ngtrongha/bvdkkh-remote workflow run flutter-tag.yml --ref feat/upgrade-flutter-win10
gh -R ngtrongha/bvdkkh-remote workflow run flutter-tag.yml --ref win7-lts
```

Kiểm tra và xác nhận cả 2 workflow runs đã chuyển sang trạng thái `in_progress`, cung cấp đường link theo dõi cho người dùng.
