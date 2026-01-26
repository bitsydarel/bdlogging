---
name: bd-quality-assurance
description: Enforces code standards and validates release readiness. Use when finalizing features or refactors, preparing pull requests, or performing pre-commit checks.
---

# Quality Assurance

This skill guides the execution of quality checks and enforcement of code standards. Apply these practices before committing code, when preparing pull requests, or after completing features.

The user has code ready to commit or submit for review. They need guidance on what checks to run, what standards to enforce, or how to prepare code for production.

---

## Quality Thinking

Before committing, verify the code meets all quality standards:

- **Completeness**: Is the feature/fix fully implemented?
- **Correctness**: Does it work as intended? Are tests passing?
- **Cleanliness**: Is the code formatted, typed, and linted?
- **Coverage**: Are new code paths tested?

**CRITICAL**: All quality checks must pass before committing. No exceptions. Broken builds waste everyone's time.

### When This Applies

Use this skill when:
- Preparing to commit code
- Creating a pull request
- Completing a feature or fix
- Running CI checks locally
- Reviewing code quality

---

## Pre-Commit Checklist

**Applies to**: All code changes before committing

### Execution Order

Run checks in this order (each step depends on the previous):

```
1. Format   → Consistent code style
2. Lint     → Code quality and patterns
3. Type     → Type safety verification
4. Test     → Behavior verification
5. Build    → Compilation/bundling success
```

### Platform-Specific Commands

#### Python

**Applies to**: Python projects

| Step | Command | Purpose |
|------|---------|---------|
| Format | `black .` or `ruff format .` | Code formatting |
| Lint | `ruff check . --fix` | Linting with auto-fix |
| Type | `mypy src/` | Static type checking |
| Test | `pytest -v --cov` | Tests with coverage |
| Build | `pip install -e .` | Verify package builds |

#### TypeScript/JavaScript

**Applies to**: Node.js, React, Vue, Angular projects

| Step | Command | Purpose |
|------|---------|---------|
| Format | `prettier --write .` | Code formatting |
| Lint | `eslint . --fix` | Linting with auto-fix |
| Type | `tsc --noEmit` | Type checking (TS only) |
| Test | `npm test` or `vitest run` | Run test suite |
| Build | `npm run build` | Verify production build |

#### Swift (iOS)

**Applies to**: iOS, macOS applications

| Step | Command | Purpose |
|------|---------|---------|
| Format | `swiftformat .` | Code formatting |
| Lint | `swiftlint --fix` | Linting with auto-fix |
| Type | Built into compiler | (Automatic) |
| Test | `xcodebuild test` | Run test suite |
| Build | `xcodebuild build` | Verify build |

#### Kotlin (Android)

**Applies to**: Android, JVM applications

| Step | Command | Purpose |
|------|---------|---------|
| Format | `ktfmt --format .` | Code formatting |
| Lint | `./gradlew ktlintCheck` | Linting |
| Type | Built into compiler | (Automatic) |
| Test | `./gradlew test` | Run test suite |
| Build | `./gradlew assembleDebug` | Verify build |

#### Dart/Flutter

**Applies to**: Flutter applications

| Step | Command | Purpose |
|------|---------|---------|
| Format | `dart format .` | Code formatting |
| Lint | `flutter analyze` | Static analysis |
| Type | Built into analyzer | (Automatic) |
| Test | `flutter test --coverage` | Run tests with coverage |
| Build | `flutter build` | Verify build |

#### Go

**Applies to**: Go applications

| Step | Command | Purpose |
|------|---------|---------|
| Format | `gofmt -w .` | Code formatting |
| Lint | `golangci-lint run` | Comprehensive linting |
| Type | Built into compiler | (Automatic) |
| Test | `go test -v -cover ./...` | Tests with coverage |
| Build | `go build ./...` | Verify compilation |

#### Rust

**Applies to**: Rust applications

| Step | Command | Purpose |
|------|---------|---------|
| Format | `cargo fmt` | Code formatting |
| Lint | `cargo clippy` | Linting |
| Type | Built into compiler | (Automatic) |
| Test | `cargo test` | Run test suite |
| Build | `cargo build` | Verify compilation |

---

## Quality Gates

**Applies to**: All projects, CI/CD pipelines

### Non-Negotiable Standards

| Gate | Requirement | Rationale |
|------|-------------|-----------|
| All checks pass | Zero errors from all tools | Broken code shouldn't be committed |
| Tests pass | 100% of tests green | Regressions must be caught |
| Coverage maintained | No decrease in coverage | New code needs tests |
| No new warnings | Fix or explicitly suppress | Warnings become errors over time |

### Coverage Requirements

| Code Type | Minimum Coverage |
|-----------|-----------------|
| New code | 80% line coverage |
| Critical paths | 90%+ coverage |
| Bug fixes | Test must cover the fix |
| Refactors | Maintain existing coverage |

---

## Code Standards Enforcement

**Applies to**: All code

### Complexity Limits

| Metric | Limit | Action if Exceeded |
|--------|-------|-------------------|
| Cognitive complexity | ≤15 per function | Refactor into smaller units |
| Function length | ≤30 lines | Extract sub-functions |
| File length | ≤400 lines | Split into modules |
| Nesting depth | ≤3 levels | Use early returns |
| Parameters | ≤3-4 per function | Use parameter objects |

### Required Patterns

| Pattern | Requirement |
|---------|-------------|
| Type annotations | All function signatures typed |
| Named arguments | Use for all function calls |
| Enum values | For all bounded strings |
| Error handling | All errors explicitly handled |
| Resource cleanup | All resources properly released |

### Forbidden Patterns

| Pattern | Why It's Forbidden |
|---------|-------------------|
| Hardcoded secrets | Security risk |
| Magic strings | Type safety |
| Commented-out code | Version control handles history |
| TODO without issue | Orphaned intentions |
| Console logs in prod | Performance and security |
| Any/dynamic types | Type safety |

---

## Pull Request Preparation

**Applies to**: Before creating a PR

### PR Readiness Checklist

```
□ All quality checks pass locally
□ Tests cover new functionality
□ No unrelated changes included
□ Commits are logical and atomic
□ Commit messages are descriptive
□ No debugging code left behind
□ Documentation updated if needed
□ Breaking changes documented
```

### Commit Message Format

**Guidance**:
```
<type>(<scope>): <short description>

<body - what and why, not how>

<footer - breaking changes, issue references>
```

**Types**:
| Type | Use For |
|------|---------|
| feat | New feature |
| fix | Bug fix |
| refactor | Code restructuring |
| test | Adding/updating tests |
| docs | Documentation |
| style | Formatting (no logic change) |
| chore | Build/tooling changes |

---

## CI/CD Alignment

**Applies to**: Local development matching CI

### Local Should Match CI

| Principle | Implementation |
|-----------|---------------|
| Same tools | Use identical versions as CI |
| Same order | Run checks in CI order |
| Same config | Share config files |
| Same environment | Use containers/devcontainers |

### Pre-Push Verification

**Guidance**: Run the full CI check locally before pushing:

```bash
# Example combined command (adapt per platform)
format && lint && type-check && test && build
```

---

## Handling Failures

**Applies to**: When checks fail

### Failure Response

| Failure Type | Action |
|--------------|--------|
| Format | Run formatter, commit changes |
| Lint | Fix issues or suppress with justification |
| Type | Fix type errors (never use `any` escape) |
| Test | Fix code or update test (never skip) |
| Build | Resolve compilation/bundling errors |

### Suppressing Warnings

**Only suppress when**:
- The warning is a false positive
- The pattern is intentional and documented
- There's a comment explaining why

**Never suppress**:
- Without explanation
- To "make CI green"
- Security-related warnings

---

## Anti-Patterns (NEVER use)

- **Skipping checks**: "Just this once" leads to broken main branch
- **Force pushing over failures**: Fix the issue, don't hide it
- **Disabling CI**: Never disable to merge faster
- **Suppressing without reason**: Every suppression needs justification
- **Committing debug code**: Remove console.log, print statements
- **Committing generated files**: Keep artifacts out of source control
- **Large uncommitted changes**: Commit frequently in small increments

---

## Core Philosophy

> "Quality is not an act, it is a habit." — Aristotle

Quality checks are not obstacles—they are guardrails that protect the team. The few minutes spent running checks save hours of debugging and firefighting.