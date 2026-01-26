# AGENTS.md - bdlogging

This document provides AI agents with the context needed to work effectively on this Dart logging library.

---

## Project Overview

| Field | Value |
|-------|-------|
| **Name** | bdlogging (BD Logging) |
| **Repository** | https://github.com/bitsydarel/bdlogging |
| **Purpose** | Dart/Flutter logging package with pluggable handlers |

For version, SDK constraints, and dependencies, reference `pubspec.yaml`.

---

## Product Overview

### Target Platforms
- Dart backend applications
- CLI applications
- Flutter mobile (iOS, Android)
- Flutter desktop (macOS, Windows, Linux)

### NOT Supported
- **Web is NOT supported** - This package uses `dart:io` which is unavailable in browsers

### Core Value Proposition
Flexible, performant logging with multiple output destinations.

---

## Architecture Overview

### Core Components

| Class | Description |
|-------|-------------|
| `BDLogger` | Singleton logger with queue-based batch processing |
| `BDLogHandler` | Abstract handler interface |
| `BDCleanableLogHandler` | Extended handler with resource cleanup (`clean()`) |
| `BDLogRecord` | Immutable log record data class |
| `BDLevel` | Enum: debug, info, warning, success, error |

### Built-in Handlers

| Handler | Description |
|---------|-------------|
| `ConsoleLogHandler` | Outputs to stdout with ANSI colors |
| `FileLogHandler` | Synchronous file logging with rotation |
| `IsolateFileLogHandler` | Async file logging via isolates (non-blocking) |

### Design Patterns

| Pattern | Usage |
|---------|-------|
| **Singleton** | `BDLogger` - single instance across app |
| **Producer-Consumer** | Queue-based log batching |
| **Actor Model** | `IsolateFileLogHandler` uses isolates for async I/O |
| **Strategy** | Handler implementations are interchangeable |

---

## Agent Skills

Agent skills are available in your context. For each task, use them as frequently as necessary.

---

## Quality Standards

### Pre-commit Checklist
Execute in order:

1. `dart format .`
2. `flutter analyze`
3. `flutter test --coverage`

### Complexity Limits

| Metric | Limit |
|--------|-------|
| Cognitive complexity | ≤15 per function |
| Function length | ≤30 lines |
| Nesting depth | ≤3 levels |
| Parameters | ≤4 per function |

### Coverage Requirements
- Overall: ≥80%
- Critical paths: ≥90%

---

## Testing Guidelines

### Test Structure
Tests mirror the `lib/src/` directory structure.

### Mock Framework
Uses `mocktail` for mocking.

### Regression Suite
The `regression_test.dart` file documents and tests fixes for historical bugs.
