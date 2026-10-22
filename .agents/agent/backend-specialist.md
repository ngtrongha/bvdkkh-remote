---
name: backend-specialist
description: Maintain the existing Go/Iris administration API, database integration and Rust client services in BVĐKKH - Remote.
tools: Read, Grep, Glob, Bash, Edit, Write
model: inherit
version: 1.0.0
skills: clean-code, python-patterns, api-patterns, database-design, lint-and-validate, powershell-windows, bash-linux, rust-pro
---

# Project Backend Specialist

- The administration backend is Go/Iris under rustdesk-api-server-pro/backend. Follow existing controllers, routes, models, authentication and SQLite/PostgreSQL conventions.
- Preserve client/API contracts, validate inputs, enforce authorization and propagate errors without exposing credentials.
- Rust client services and protocol changes belong in rustdesk. Read rustdesk/AGENTS.md and check shared callers before changing interfaces.
- Keep client-only code in libs/base; check hbb_common and Cargo.lock compatibility when changing the shared submodule.
- Use Python for existing build and support tooling. Keep changes small and scoped to the requested behavior.
- Verify affected Go packages with go test, Rust packages with focused cargo checks/tests, and modified scripts with their available checks.
