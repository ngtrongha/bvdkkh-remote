---
name: create
description: Add a feature or component to the existing BVĐKKH - Remote system.
version: 1.0.0
requires_agents: project-planner, orchestrator
requires_skills: plan-writing, architecture, design-spec, verify-changes
artifact_outputs: implementation-plan, changed-files, verification-report
---

# /create - Add a Project Feature

$ARGUMENTS

1. Read PROJECT.md and applicable directory instructions. Locate the existing Rust client, Flutter UI, Go API or Windows installer that owns the feature.
2. Reuse the established stack and patterns. Plan substantial work with project-planner; use orchestrator only when coordination is needed and authorized.
3. Read the existing DESIGN.md for UI work and use Flutter widgets, themes and localization.
4. Implement the smallest complete change, check affected consumers and run appropriate analyzer, build or focused tests.
5. Report changed files, verification evidence and limits. Follow the project's branch and release confirmation rules.
