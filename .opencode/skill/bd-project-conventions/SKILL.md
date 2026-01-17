---
name: bd-project-conventions
description: Ensures code compliance with project conventions and structure. Use when scaffolding new files, refactoring code, configuring environments, or troubleshooting import/build issues.
---

# Project Conventions

This skill guides project structure, environment setup, and development conventions. Apply these standards when starting new projects, onboarding to existing codebases, or troubleshooting setup issues.

The user needs help with project setup, environment configuration, import issues, or understanding project structure. They may be starting fresh or debugging existing configuration.

---

## Project Thinking

Before setting up or modifying project structure, understand the goals:

- **Consistency**: Does this follow platform conventions others will recognize?
- **Separation**: Are concerns properly separated (source, tests, config)?
- **Reproducibility**: Can another developer set up identically?
- **Security**: Are secrets and credentials properly handled?

**CRITICAL**: Follow platform conventions. Custom structures create friction for every new team member.

### When This Applies

Use this skill when:
- Creating a new project
- Setting up a development environment
- Troubleshooting import/module errors
- Configuring environment variables
- Understanding project structure
- Onboarding to a new codebase

---

## Root-Level Structure

**Applies to**: All software — Mobile, Web, Backend, Desktop, CLI, Libraries

At the root of the application, code is organized **by feature**. This ensures related code lives together and features remain modular and independently maintainable. The exact folder/module shape differs per platform, but the same feature boundaries apply.

### Flutter (Dart)

```
/lib
  /common              # Shared foundations
  /authentication      # Feature
  /settings            # Feature
  /orders              # Feature
  ...
```

### Android (Kotlin)

**Guidance**: Use Gradle modules or folders to represent feature boundaries.

```
/ (repo root)
  /app                 # Android application
  /common              # Shared foundations
  /authentication      # Feature module
  /settings            # Feature module
  ...
```

### iOS (Swift)

**Guidance**: Represent feature boundaries using Swift packages (preferred) or Xcode modules/targets.

```
/ (repo root)
  /App                 # iOS application target
  /Common              # Shared foundations
  /Authentication      # Feature package/target
  /Settings            # Feature package/target
  ...
```

### Python Backend

**Guidance**: Use packages/modules for feature boundaries.

```
/src
  /common              # Shared foundations
  /authentication      # Feature
  /orders              # Feature
  /payments            # Feature
  ...
/tests
  /authentication
  /orders
  ...
```

### Node.js/TypeScript Backend

**Guidance**: Use folders or npm workspaces for feature boundaries.

```
/src
  /common              # Shared foundations
  /authentication      # Feature
  /orders              # Feature
  /payments            # Feature
  ...
```

### Go Backend

**Guidance**: Use packages within internal/ for feature boundaries.

```
/cmd
  /server              # Entry point
/internal
  /common              # Shared foundations
  /authentication      # Feature
  /orders              # Feature
  /payments            # Feature
  ...
```

### React/Vue/Angular Web

**Guidance**: Use feature folders within src.

```
/src
  /common              # Shared foundations
  /authentication      # Feature
  /dashboard           # Feature
  /settings            # Feature
  ...
```

---

## The Common Module

**Applies to**: All platforms and software types

`Common` contains shared foundations used broadly across the app:
- Design tokens and theming (UI apps)
- Core utilities and helpers
- Shared platform adapters
- Shared business types/models
- Cross-cutting concerns (logging, error handling)

**CRITICAL**: Keep Common small and stable. If something is feature-specific, it belongs in that feature.

---

## Environment Configuration

**Applies to**: All projects with environment-specific settings

### Environment File Pattern

**Guidance**:

1. **Create template**: `.env.example` (committed to git)
   ```
   # Database
   DATABASE_URL=postgres://user:pass@localhost:5432/db

   # API Keys (get from team lead)
   API_KEY=your-api-key-here

   # Feature Flags
   FEATURE_NEW_UI=false
   ```

2. **Create local config**: `.env` (never committed)
   ```bash
   cp .env.example .env
   # Edit .env with real values
   ```

3. **Add to .gitignore**:
   ```
   .env
   .env.local
   .env.*.local
   ```

### What Belongs in Environment Files

| Include | Exclude |
|---------|---------|
| Database URLs | Hardcoded in source |
| API keys | Committed to git |
| Feature flags | Production secrets in dev files |
| Service endpoints | Anything that doesn't vary |
| Debug flags | |

### Loading Environment Variables

| Platform | Method |
|----------|--------|
| Python | `python-dotenv` or `environs` |
| Node.js | `dotenv` package |
| Flutter | `flutter_dotenv` or `envied` |
| Go | `godotenv` or `viper` |

---

## Dependency Management

**Applies to**: All projects

### Lock Files

**Guidance**: Always commit lock files for reproducible builds.

| Platform | Lock File | Command to Update |
|----------|-----------|-------------------|
| Python | `requirements.lock` or `poetry.lock` | `pip-compile` or `poetry lock` |
| Node.js | `package-lock.json` | `npm install` |
| Flutter | `pubspec.lock` | `flutter pub get` |
| Go | `go.sum` | `go mod tidy` |
| Swift | `Package.resolved` | `swift package resolve` |
| Rust | `Cargo.lock` | `cargo update` |

### Dependency Organization

| Category | Description |
|----------|-------------|
| Production | Required at runtime |
| Development | Testing, linting, building |
| Optional | Feature-specific extras |

---

## Import Conventions

**Applies to**: All projects with modules

### General Rules

| Rule | Rationale |
|------|-----------|
| Relative within package | Cleaner, refactor-friendly |
| Absolute in tests | Tests import the package, not siblings |
| No path manipulation | Never modify sys.path, import path, etc. |
| Barrel exports | Clean public API (index.ts, __init__.py) |

### Import Order

**Guidance**: Group imports in this order:

```
1. Standard library / built-ins
2. Third-party packages
3. Local application imports
   - Absolute imports
   - Relative imports
```

---

## Common Setup Issues

**Applies to**: Troubleshooting

### Import/Module Errors

| Error | Likely Cause | Solution |
|-------|--------------|----------|
| Module not found | Package not installed in editable mode | `pip install -e .` |
| Cannot resolve | Missing __init__.py | Add empty __init__.py files |
| Circular import | Modules importing each other | Restructure or use lazy imports |
| No module named X | Wrong environment | Activate correct venv/node_modules |

### Build Errors

| Error | Likely Cause | Solution |
|-------|--------------|----------|
| Version mismatch | Lock file out of sync | Delete lock, reinstall |
| Missing dependency | Not in requirements | Add and reinstall |
| Platform-specific | OS-specific package | Use conditional dependencies |

---

## Anti-Patterns (NEVER use)

- **sys.path hacks**: Never modify import paths programmatically
- **Hardcoded paths**: Use relative paths or configuration
- **Secrets in code**: Use environment variables
- **Missing lock files**: Always commit lock files
- **Mixing test/prod**: Keep test utilities out of production code
- **Custom project layouts**: Follow platform conventions
