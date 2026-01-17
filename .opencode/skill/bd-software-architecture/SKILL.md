---
name: bd-software-architecture
description: Enforces architectural patterns, layer separation, and data flow rules. Use when designing features, refactoring legacy code, defining boundaries, or analyzing dependencies.
---

# Software Architecture

This skill guides the internal structuring of software features across ALL platforms (Mobile, Web, Backend, AI/ML, CLI, Desktop). Apply these principles to ensure features remain loosely coupled, testable, and maintainable.

The user needs help with designing a feature structure, understanding layer responsibilities, fixing dependency violations, or deciding where code belongs.

---

## Architecture Thinking

**Applies to**: All software design decisions

Before creating files or folders, map the feature's requirements to the architecture layers:

- **Boundaries**: What are the feature boundaries? Is this self-contained or shared?
- **Data Flow**: Where does data come from and go to?
- **Contracts**: What interfaces are needed? Define before implementation.
- **Dependencies**: Are dependencies pointing in the correct direction (inward)?

**CRITICAL**: Design from the inside out (Domain first, then Use Cases, then outer layers). The UI/handlers are plugins to business logic.

### When This Applies

Use this skill when:
- Designing the structure of a new feature
- Refactoring monolithic modules
- Deciding where logic belongs (Repository vs Service?)
- Fixing circular dependencies
- Reviewing PRs for architectural compliance

---

## Non-Negotiable Rules (Policy)

**Applies to**: Code review, PR enforcement, all platforms

| # | Rule |
|---|------|
| 1 | Presentation layer MUST call use cases only |
| 2 | Use cases MUST be the only entry point into business operations |
| 3 | Dependencies MUST flow one-way (inward) |
| 4 | Domain models and use cases MUST be framework-agnostic |
| 5 | DTOs MUST NOT cross architectural boundaries |
| 6 | Repositories/Services MUST consume and return domain models |
| 7 | Feature modules MUST NOT create cycles (DAG only) |
| 8 | Cross-feature imports MUST go through public API |

---

## Architecture Layers

**Applies to**: All features across all platforms

**Guidance**: Dependencies flow one-way toward high-level policies.

```
Presentation → Use Cases → Repositories/Services → Data Source Contracts ← Implementations
```

| Layer | Responsibility | Platform Examples |
|-------|----------------|-------------------|
| **Presentation** | How data is shown/received | Views, CLI, API handlers, Controllers |
| **Use Cases** | What the app does (business operations) | Application services, Command handlers |
| **Repositories** | How data is coordinated | Cache strategies, query aggregation |
| **Services** | How capabilities work | Auth, payments, notifications, analytics |
| **Data Sources** | Where data lives | APIs, DBs, files, ML models |
| **Domain Models** | What data is (pure) | Entities, value objects, enums |

---

## Dependency Matrix

**Applies to**: Import rules enforcement

| From \ To | Presentation | Use Cases | Repos/Services | DS Contracts | DS Impls |
|-----------|--------------|-----------|----------------|--------------|----------|
| Presentation | ✅ | ✅ | ❌ | ❌ | ❌ |
| Use Cases | ❌ | ✅ | ✅ | ❌ | ❌ |
| Repos/Services | ❌ | ❌ | ✅ | ✅ | ❌ |
| DS Contracts | ❌ | ❌ | ❌ | ✅ | ❌ |
| DS Impls | ❌ | ❌ | ❌ | ✅ (impl) | ✅ |

**Note**: Domain Models are dependency-free and usable by all layers.

---

## Feature Folder Structure

**Applies to**: Each feature module/package across all platforms

**Guidance**: Structure features to enforce the dependency rule physically.

```
/feature_name
  /ui                     # Presentation (Views, Controllers, Handlers)
                          # DEPENDS ON: Use Cases, Domain Models

  /state                  # State Management (ViewModels, Stores, Reducers)
                          # DEPENDS ON: Use Cases, Domain Models

  /use_cases              # Application Business Rules (Orchestrators)
                          # DEPENDS ON: Repositories, Services, Domain Models

  /domain                 # Enterprise Business Rules (Entities)
                          # DEPENDS ON: Nothing (Pure)

  /repositories           # Interface Adapters (Data Coordination)
                          # DEPENDS ON: Data Source Contracts, Domain Models

  /services               # Interface Adapters (Capabilities)
                          # DEPENDS ON: Data Source Contracts

  /data_sources           # Frameworks & Drivers (IO, DB, API)
    /contracts            # Interfaces (Define location + behavior)
    /impl                 # Implementations (The dirty details)
      /dtos               # Data Transfer Objects (Private to impl)

  feature_name.dart       # Public API (Barrel export)
```

---

## Component Decision Guide

**Applies to**: Deciding where logic belongs

### Repository vs Service

| Component | Focus | Example Responsibilities |
|-----------|-------|--------------------------|
| **Repository** | **Data** | CRUD operations, caching strategies, fetching, saving, queries, pagination |
| **Service** | **Capabilities** | 3rd Party APIs, device features, system events, auth, payments, analytics |

**Rule of Thumb**: If it acts like a collection of data → Repository. If it performs an action → Service.

### Data Source Architecture

**Guidance**: Data Sources are the boundary between your code and the outside world.

1. **Contract (Interface)**: Defines *what* is needed. Specifies location (local/remote) and behavior.
2. **Implementation**: Defines *how* it works. May use DTOs, external libraries.
3. Implementations map DTOs → Domain Models before returning.

```
                  Dependency Direction
Repository ─────────────────────────────────> Data Source Contract
                                                      ^
                                                      │ (implements)
                                                      │
                                              Data Source Impl
```

---

## Use Case Guidelines

**Applies to**: Use case design and composition

### Composition Rules

- Only compose when called use case represents a **standalone business intention**
- Keep composition shallow: 1-2 use cases max
- No loops allowed (A → B → A is forbidden)
- If logic is not a business intention, don't extract it as a use case

### What is NOT a Use Case (❌)

- Formatting/mapping helpers (keep in presentation or data source)
- Shared implementation details (keep private or in service)
- DTO transformations (keep in data source implementation)

### What IS a Use Case (✅)

- Business intentions: "Login", "CreateOrder", "ProcessPayment"
- Reusable guards: "EnsureAuthenticated", "ValidatePermissions"

---

## Data Flow Patterns

**Applies to**: Request/response handling

### Standard Flow

```
Presentation → State/Handler → Use Case → Repository/Service →
Data Source (contract) → Data Source (impl) → External System
```

### Error Translation Pattern

**Guidance**: Vendor errors MUST NOT leak upward through layers.

- Translate vendor errors (HTTP, DB, SDK) inside Data Source implementations
- Convert to Domain Exceptions before returning
- Use Cases catch domain exceptions, not vendor errors
- Presentation handles domain exceptions for user-facing messages

---

## Feature Public API

**Applies to**: Feature encapsulation, cross-feature imports

**Guidance**: Each feature must act like a separate library. Expose only what other features need.

### What to Export (barrel file)

- Public screens/views/handlers (navigation entry points)
- Domain models needed by other features
- DI registration function (if applicable)

### What to Keep Private

- Repositories, Services, Data Sources
- DTOs, internal helpers
- Implementation details

---

## Anti-Patterns (NEVER use)

- **Deep imports**: Importing internal paths instead of public API
- **Leaking DTOs**: Returning DTOs from repositories/services
- **Logic in presentation**: Business decisions in UI/handlers
- **God repositories**: One repository doing everything
- **Hard dependencies**: Instantiating implementations directly (use DI)
- **Use case for formatting**: Extracting non-business logic as use cases
- **Circular dependencies**: Feature A ↔ Feature B (must be DAG)
- **Framework in domain**: Domain models importing HTTP/DB/UI libraries

---

## Core Philosophy

> "The goal of software architecture is to minimize the human resources required to build and maintain the required system." — Robert C. Martin

Good architecture makes change easy. By enforcing strict layer boundaries and one-way dependencies, external systems (databases, APIs, UI frameworks) can change without breaking business logic.