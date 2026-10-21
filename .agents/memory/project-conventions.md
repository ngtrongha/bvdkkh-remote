---
type: project
created: 2026-05-25
updated: 2026-07-12
---

# Project Conventions

## Git & Release Workflow
- Mọi tác vụ code/sửa lỗi phải thực hiện trực tiếp trên nhánh `main`. Nhánh làm việc mặc định là `main`.
- **Đồng bộ Upstream & Submodule `hbb_common`**: Khi đồng bộ từ RustDesk upstream, bắt buộc kiểm tra và đồng bộ cả fork `ngtrongha/hbb_common` (đảm bảo dependencies trong `hbb_common/Cargo.toml` khớp với root `Cargo.lock` để tránh lỗi build `--locked`), đồng thời bảo toàn cấu hình BVĐKKH (server `172.16.3.28`, keys).
- **Cổng xác nhận bắt buộc (Confirmation Gate)**: Khi hoàn thành tính năng trên `main`, AI **bắt buộc phải hỏi xác nhận người dùng** trước khi merge.
- Khi người dùng xác nhận:
  1. Merge sang nhánh Windows 7 (`win7-lts`): Chỉ build Windows 7 (x86 & x64), bảo toàn cấu hình build riêng của Win7.
  2. Merge sang nhánh Win10+ & Mobile (`feat/upgrade-flutter-win10`): Build cho Windows 10/11, Android, và iOS.
  3. Tự động kích hoạt GitHub Actions build (`flutter-tag.yml`) cho cả 2 nhánh qua `rustdesk/trigger_build.ps1` hoặc `gh workflow run`.
  4. Chuyển nhánh làm việc quay trở lại `main`.

## Supported AI platforms (AG Kit)
- AG Kit **only supports Gemini CLI and Google Antigravity**.
- Do not claim compatibility with Claude Code, Cursor, Copilot, Windsurf, or other assistants unless the user explicitly expands scope.
- Copy on the website, docs, FAQ, README, and marketing should describe AG Kit as a toolkit for Gemini CLI / Antigravity-style agent setups.
