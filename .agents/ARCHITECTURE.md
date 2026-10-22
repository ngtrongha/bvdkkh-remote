# BVĐKKH - Remote Agent Toolkit

Project profile: Rust remote desktop client, Flutter client and administration UI, Go/Iris API, Windows installation, and Python/PowerShell build tooling.

Skills are loaded on demand. Respect rustdesk/AGENTS.md, project memory, existing architecture and release rules.

## Inventory

| Metric | Value |
| --- | --- |
| **Total Agents** | 18 |
| **Total Skills** | 54 |
| **Total Workflows** | 13 |
| **Total Skill Scripts** | 12 |

## Skills

| Skill | Purpose |
| --- | --- |
| [api-patterns](skills/api-patterns/SKILL.md) | API design principles and decision-making. REST vs GraphQL vs tRPC selection, response formats, versioning, pagination. |
| [architecture](skills/architecture/SKILL.md) | Architectural decision-making framework. Requirements analysis, trade-off evaluation, ADR documentation. Use when making architecture decisions or analyzing system design. |
| [bash-linux](skills/bash-linux/SKILL.md) | Bash/Linux terminal patterns. Critical commands, piping, error handling, scripting. Use when working on macOS or Linux systems. |
| [batch-operations](skills/batch-operations/SKILL.md) | Apply operations across multiple files simultaneously. Pattern-based bulk modifications, search-and-replace across codebases, consistent changes to many files at once. |
| [behavioral-modes](skills/behavioral-modes/SKILL.md) | AI operational modes (brainstorm, implement, debug, review, teach, ship, orchestrate). Use to adapt behavior based on task type. |
| [brainstorming](skills/brainstorming/SKILL.md) | Socratic questioning protocol + user communication. MANDATORY for complex requests, new features, or unclear requirements. Includes progress reporting and error handling. |
| [clean-code](skills/clean-code/SKILL.md) | Pragmatic coding standards - concise, direct, no over-engineering, no unnecessary comments |
| [code-review-checklist](skills/code-review-checklist/SKILL.md) | Code review guidelines covering code quality, security, and best practices. |
| [code-review-graph](skills/code-review-graph/SKILL.md) | Token-efficient code review using Tree-sitter AST graphs and MCP. Cuts AI token usage on large codebases by computing the blast radius of changes instead of reading entire codebases. Uses a SQLite graph database for structural analysis. |
| [context-compression](skills/context-compression/SKILL.md) | Manage and compress conversation context in long sessions. Detect when context is growing large, summarize completed work phases, archive old findings while preserving key decisions. Prevents context degradation. |
| [coordinator-mode](skills/coordinator-mode/SKILL.md) | Advanced multi-agent orchestration with parallel workers, synthesis protocols, and coordinator lifecycle. Use when complex tasks require multiple agents working in parallel with intelligent result synthesis. |
| [dart-add-unit-test](skills/dart-add-unit-test/SKILL.md) | Write and organize unit tests for functions, methods, and classes using `package:test`. Use when creating new logic or fixing bugs to ensure code remains correct and regression-free. |
| [dart-collect-coverage](skills/dart-collect-coverage/SKILL.md) | Collect coverage using the coverage packge and create an LCOV report |
| [dart-fix-runtime-errors](skills/dart-fix-runtime-errors/SKILL.md) | Uses get_runtime_errors and lsp to fetch an active stack trace, locate the failing line, apply a fix, and verify resolution via hot_reload. |
| [dart-generate-test-mocks](skills/dart-generate-test-mocks/SKILL.md) | Define and generate mock objects for external dependencies using `package:mockito` and `build_runner`. Use when unit testing classes that depend on complex external services like APIs or databases. |
| [dart-resolve-package-conflicts](skills/dart-resolve-package-conflicts/SKILL.md) | Workflow for fixing package version conflicts. Use this when `pub get` fails due to incompatible package versions. |
| [dart-run-static-analysis](skills/dart-run-static-analysis/SKILL.md) | Execute `dart analyze` to identify warnings and errors, and use `dart fix --apply` to automatically resolve mechanical lint issues. Use during development to ensure code quality and before committing changes. |
| [dart-use-doc-examples](skills/dart-use-doc-examples/SKILL.md) | How to inject external code examples into Dartdoc using the {@example} directive, and how to filter those files using #hide, #region, and #endregion tags. |
| [dart-use-path-package](skills/dart-use-path-package/SKILL.md) | >- |
| [dart-use-pattern-matching](skills/dart-use-pattern-matching/SKILL.md) | >- |
| [dart-write-documentation](skills/dart-write-documentation/SKILL.md) | Rules and formatting guidelines for writing Dart /// API documentation and doc comments. Use when documenting Dart code, writing doc comments for any Dart declaration (libraries, classes, methods, variables, etc.), or when instructed to follow the Effective Dart documentation guidelines. |
| [database-design](skills/database-design/SKILL.md) | Database design principles and decision-making. Schema design, indexing strategy, ORM selection, serverless databases. |
| [deployment-procedures](skills/deployment-procedures/SKILL.md) | Production deployment principles and decision-making. Safe deployment workflows, rollback strategies, and verification. Teaches thinking, not scripts. |
| [design-spec](skills/design-spec/SKILL.md) | How to author a DESIGN.md file — the machine-readable design-token + human-rationale format that must exist before any UI is built. YAML front-matter token schema (colors, typography, spacing, rounded, components), type system, token references, and canonical section order. |
| [documentation-templates](skills/documentation-templates/SKILL.md) | Documentation templates and structure guidelines. README, API docs, code comments, and AI-friendly documentation. |
| [flutter-add-integration-test](skills/flutter-add-integration-test/SKILL.md) | Configures Flutter Driver for app interaction and converts MCP actions into permanent integration tests. Use when adding integration testing to a project, exploring UI components via MCP, or automating user flows with the integration_test package. |
| [flutter-add-widget-test](skills/flutter-add-widget-test/SKILL.md) | Implement a component-level test using `WidgetTester` to verify UI rendering and user interactions (tapping, scrolling, entering text). Use when validating that a specific widget displays correct data and responds to events as expected. |
| [flutter-apply-architecture-best-practices](skills/flutter-apply-architecture-best-practices/SKILL.md) | Architects a Flutter application using the recommended layered approach (UI, Logic, Data). Use when structuring a new project or refactoring for scalability. |
| [flutter-build-responsive-layout](skills/flutter-build-responsive-layout/SKILL.md) | Use `LayoutBuilder`, `MediaQuery`, or `Expanded/Flexible` to create a layout that adapts to different screen sizes. Use when you need the UI to look good on both mobile and tablet/desktop form factors. |
| [flutter-fix-layout-issues](skills/flutter-fix-layout-issues/SKILL.md) | Fixes Flutter layout errors (overflows, unbounded constraints) using Dart and Flutter MCP tools. Use when addressing "RenderFlex overflowed", "Vertical viewport was given unbounded height", or similar layout issues. |
| [flutter-implement-json-serialization](skills/flutter-implement-json-serialization/SKILL.md) | Create model classes with `fromJson` and `toJson` methods using `dart:convert`. Use when manually mapping JSON keys to class properties for simple data structures. |
| [flutter-setup-declarative-routing](skills/flutter-setup-declarative-routing/SKILL.md) | Configure `MaterialApp.router` using a package like `go_router` for advanced URL-based navigation. Use when developing web applications or mobile apps that require specific deep linking and browser history support. |
| [flutter-setup-localization](skills/flutter-setup-localization/SKILL.md) | Add `flutter_localizations` and `intl` dependencies, enable "generate true" in `pubspec.yaml`, and create an `l10n.yaml` configuration file. Use when initializing localization support for a new Flutter project. |
| [flutter-use-http-package](skills/flutter-use-http-package/SKILL.md) | Use the `http` package to execute GET, POST, PUT, or DELETE requests. Use when you need to fetch from or send data to a REST API. |
| [i18n-localization](skills/i18n-localization/SKILL.md) | Internationalization and localization patterns. Detecting hardcoded strings, managing translations, locale files, RTL support. |
| [intelligent-routing](skills/intelligent-routing/SKILL.md) | Automatic agent selection and intelligent task routing. Analyzes user requests and automatically selects the best specialist agent(s) without requiring explicit user mentions. |
| [lint-and-validate](skills/lint-and-validate/SKILL.md) | Automatic quality control, linting, and static analysis procedures. Use after every code modification to ensure syntax correctness and project standards. Triggers on keywords: lint, format, check, validate, types, static analysis. |
| [memory-system](skills/memory-system/SKILL.md) | Persistent cross-session memory management. Enables agents to remember user preferences, project conventions, and past decisions across different sessions using a structured MEMORY.md index and topic files. |
| [mobile-design](skills/mobile-design/SKILL.md) | Mobile-first design thinking and decision-making for iOS and Android apps. Touch interaction, performance patterns, platform conventions. Teaches principles, not fixed values. Use when building React Native, Flutter, or native mobile apps. |
| [parallel-agents](skills/parallel-agents/SKILL.md) | Multi-agent orchestration patterns. Use when multiple independent tasks can run with different domain expertise or when comprehensive analysis requires multiple perspectives. |
| [performance-profiling](skills/performance-profiling/SKILL.md) | Performance profiling principles. Measurement, analysis, and optimization techniques. |
| [plan-writing](skills/plan-writing/SKILL.md) | Structured task planning with clear breakdowns, dependencies, and verification criteria. Use when implementing features, refactoring, or any multi-step work. |
| [powershell-windows](skills/powershell-windows/SKILL.md) | PowerShell Windows patterns. Critical pitfalls, operator syntax, error handling. |
| [python-patterns](skills/python-patterns/SKILL.md) | Python development principles and decision-making. Framework selection, async patterns, type hints, project structure. Teaches thinking, not copying. |
| [red-team-tactics](skills/red-team-tactics/SKILL.md) | Red team tactics principles based on MITRE ATT&CK. Attack phases, detection evasion, reporting. |
| [rust-pro](skills/rust-pro/SKILL.md) | Master modern Rust (2024 edition) with async patterns, advanced type system features, and production-ready systems programming. Expert in the current Rust ecosystem including Tokio, axum, and modern crates. Use PROACTIVELY for Rust development, performance optimization, or systems programming. |
| [server-management](skills/server-management/SKILL.md) | Server management principles and decision-making. Process management, monitoring strategy, and scaling decisions. Teaches thinking, not commands. |
| [simplify-code](skills/simplify-code/SKILL.md) | Reduce complexity of over-engineered code. Identify unnecessary abstractions, remove dead code, flatten deep nesting, and simplify logic while preserving behavior. |
| [systematic-debugging](skills/systematic-debugging/SKILL.md) | 4-phase systematic debugging methodology with root cause analysis and evidence-based verification. Use when debugging complex issues. |
| [tdd-workflow](skills/tdd-workflow/SKILL.md) | Test-Driven Development workflow principles. RED-GREEN-REFACTOR cycle. |
| [testing-patterns](skills/testing-patterns/SKILL.md) | Testing patterns and principles. Unit, integration, mocking strategies. |
| [verify-changes](skills/verify-changes/SKILL.md) | Prove code works by running it, not just checking it exists. Verification through execution rather than inspection. Use after writing or modifying code to ensure it actually functions correctly. |
| [vulnerability-scanner](skills/vulnerability-scanner/SKILL.md) | Advanced vulnerability analysis principles. OWASP 2025, Supply Chain Security, attack surface mapping, risk prioritization. |
| [webapp-testing](skills/webapp-testing/SKILL.md) | Web application testing principles. E2E, Playwright, deep audit strategies. |

## Agents

| Agent | Skills |
| --- | --- |
| [backend-specialist](agent/backend-specialist.md) | clean-code, python-patterns, api-patterns, database-design, lint-and-validate, powershell-windows, bash-linux, rust-pro |
| [code-archaeologist](agent/code-archaeologist.md) | clean-code, simplify-code, code-review-checklist |
| [database-architect](agent/database-architect.md) | clean-code, database-design |
| [debugger](agent/debugger.md) | clean-code, systematic-debugging |
| [devops-engineer](agent/devops-engineer.md) | clean-code, deployment-procedures, server-management, powershell-windows, bash-linux |
| [documentation-writer](agent/documentation-writer.md) | clean-code, documentation-templates |
| [explorer-agent](agent/explorer-agent.md) | clean-code, architecture, plan-writing, brainstorming, systematic-debugging |
| [frontend-specialist](agent/frontend-specialist.md) | clean-code, design-spec, mobile-design, flutter-apply-architecture-best-practices, flutter-build-responsive-layout, flutter-fix-layout-issues, flutter-setup-declarative-routing, flutter-add-widget-test, i18n-localization, lint-and-validate |
| [mobile-developer](agent/mobile-developer.md) | clean-code, design-spec, mobile-design |
| [orchestrator](agent/orchestrator.md) | clean-code, parallel-agents, behavioral-modes, plan-writing, brainstorming, architecture, lint-and-validate, powershell-windows, bash-linux, coordinator-mode, memory-system, context-compression, verify-changes |
| [penetration-tester](agent/penetration-tester.md) | clean-code, vulnerability-scanner, red-team-tactics, api-patterns |
| [performance-optimizer](agent/performance-optimizer.md) | clean-code, performance-profiling |
| [product-manager](agent/product-manager.md) | plan-writing, brainstorming, clean-code |
| [product-owner](agent/product-owner.md) | plan-writing, brainstorming, clean-code |
| [project-planner](agent/project-planner.md) | clean-code, plan-writing, brainstorming |
| [qa-automation-engineer](agent/qa-automation-engineer.md) | webapp-testing, testing-patterns, clean-code, lint-and-validate |
| [security-auditor](agent/security-auditor.md) | clean-code, vulnerability-scanner, red-team-tactics, api-patterns |
| [test-engineer](agent/test-engineer.md) | clean-code, testing-patterns, tdd-workflow, webapp-testing, code-review-checklist, lint-and-validate |

## Workflows

- [brainstorm](workflows/brainstorm.md)
- [coordinate](workflows/coordinate.md)
- [create](workflows/create.md)
- [debug](workflows/debug.md)
- [deploy](workflows/deploy.md)
- [enhance](workflows/enhance.md)
- [orchestrate](workflows/orchestrate.md)
- [plan](workflows/plan.md)
- [preview](workflows/preview.md)
- [remember](workflows/remember.md)
- [status](workflows/status.md)
- [test](workflows/test.md)
- [verify](workflows/verify.md)

## Validation

- `python .agents/scripts/generate_manifest.py --check`
- `python .agents/scripts/dependency_graph.py --check`
- `python .agents/scripts/validate_kit.py`
- `node --test .agents/hooks/tests/antigravity.test.mjs`

MCP configuration remains in mcp_config.json. No project MCP servers are currently declared.
