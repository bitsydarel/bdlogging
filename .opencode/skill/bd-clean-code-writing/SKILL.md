---
name: bd-clean-code-writing
description: Generates, refactors, and modifies code. Use when writing functions, classes, modules, scripts or refactoring existing code.
---

# Clean Code Writing

This skill guides creation of clean, maintainable, and well-structured code that follows SOLID principles. Apply these guidelines when writing new code or refactoring existing code across any platform.

The user provides code to write or refactor: a function, class, module, or component. They may include context about the purpose, constraints, or existing patterns in the codebase.

---

## Design Thinking

Before coding, understand the context and commit to a **clean design direction**:

- **Purpose**: What problem does this code solve? What is its single responsibility?
- **Boundaries**: Where does this code fit in the architecture? What are its dependencies?
- **Abstraction Level**: Is this presentation, domain logic, or data layer code?
- **Consumers**: Who will use this code? What interface do they need?

**CRITICAL**: Identify the single responsibility before writing. If you cannot describe the purpose in one sentence without "and", the scope is too broad.

### When This Applies

Use this skill when:
- Writing new functions, classes, or modules
- Refactoring existing code for clarity
- Reviewing code for design issues
- Splitting large components into smaller ones
- Adding new features to existing code

---

## SOLID Principles Guidelines

### Single Responsibility Principle

**Applies to**: Classes, modules, functions, components

**Guidance**:
- Each unit should have exactly one reason to change
- If describing what it does requires "and", split it
- Group by reason for change, not by technical layer

**Example Application**:
```
BEFORE: UserManager handles validation, persistence, notifications, formatting
AFTER:  UserValidator, UserRepository, UserNotifier, UserFormatter (each focused)
```

### Open/Closed Principle

**Applies to**: Classes with behavior that may vary, plugin architectures, strategy patterns

**Guidance**:
- Use abstractions to allow new behavior without modifying existing code
- Prefer composition and dependency injection over inheritance
- Design extension points where requirements are likely to change

**Example Application**:
```
BEFORE: if payment_type == "stripe": ... elif payment_type == "paypal": ...
AFTER:  PaymentGateway interface with StripeGateway, PayPalGateway implementations
```

### Liskov Substitution Principle

**Applies to**: Inheritance hierarchies, interface implementations, polymorphic code

**Guidance**:
- Subtypes must honor the contracts of their base types
- Don't override methods to do nothing or throw unexpected exceptions
- If a subtype cannot fulfill the base contract, use composition instead

**Example Application**:
```
VIOLATION: Square extends Rectangle but breaks setWidth/setHeight expectations
SOLUTION:  Both Square and Rectangle implement Shape interface independently
```

### Interface Segregation Principle

**Applies to**: Interfaces, protocols, abstract classes, API contracts

**Guidance**:
- Prefer many small, focused interfaces over one large interface
- Clients should not depend on methods they don't use
- Split interfaces by client needs, not by implementation convenience

**Example Application**:
```
BEFORE: Printer interface with print(), scan(), fax(), staple() methods
AFTER:  Printable, Scannable, Faxable interfaces (implement only what's needed)
```

### Dependency Inversion Principle

**Applies to**: Service classes, repositories, external integrations, cross-layer dependencies

**Guidance**:
- High-level modules should not depend on low-level modules
- Both should depend on abstractions (interfaces/protocols)
- Inject dependencies rather than creating them internally

**Example Application**:
```
BEFORE: OrderService creates new StripeClient() internally
AFTER:  OrderService receives PaymentGateway interface via constructor
```

---

## Clean Code Guidelines

### Functions and Methods

**Applies to**: All functions, methods, lambdas, closures

**Guidance**:
- Functions must be small and do one thing well
- Cognitive complexity must not exceed 15
- Prefer pure functions without side effects
- Limit arguments to 3 or fewer (use parameter objects for more)
- Use early returns to reduce nesting

**Anti-Patterns**:
- Functions longer than 20-30 lines
- More than 3 levels of nesting
- Boolean parameters that change behavior (split into two functions)
- Output parameters (return values instead)

### Naming

**Applies to**: Variables, functions, classes, modules, files

**Guidance**:
- Names should reveal intent without comments
- Use domain vocabulary consistently
- Verbs for functions (calculateTotal, validateUser)
- Nouns for classes (OrderProcessor, UserRepository)
- Booleans should read as questions (isValid, hasPermission, canExecute)

**Anti-Patterns**:
- Single-letter names (except loop counters)
- Abbreviations unless universally understood
- Generic names (data, info, manager, handler, processor) without context
- Hungarian notation or type prefixes

### Type Safety

**Applies to**: All typed languages (TypeScript, Swift, Kotlin, Dart, Python with hints, Go, Rust)

**Guidance**:
- All parameters and return types must have explicit annotations
- Use precise generics (List<User> not List<Any>)
- Handle nullability explicitly (Optional, nullable types)
- Prefer named/labeled arguments for clarity
- Use enums for bounded string values

**Platform-Specific**:
| Platform | Type System | Nullability | Named Args |
|----------|-------------|-------------|------------|
| Swift | Protocols, generics | Optional<T> | Labels required |
| Kotlin | Interfaces, generics | T? nullable | Named supported |
| Dart | Abstract classes | T? nullable | Named with {} |
| TypeScript | Interfaces, generics | T \| undefined | Object destructuring |
| Python | Type hints | Optional[T] | Keyword args |
| Go | Interfaces | Pointers | N/A |
| Rust | Traits, generics | Option<T> | N/A |

---

## Dependency Management

**Applies to**: Service layers, repositories, controllers, use cases

**Guidance**:
- Core business logic should not depend on external frameworks
- Separate concerns: presentation, domain logic, data layer
- Dependencies flow inward (UI → Domain ← Data)
- Use dependency injection to provide implementations

**Layer Responsibilities**:
| Layer | Responsibility | Dependencies |
|-------|---------------|--------------|
| Presentation | UI, controllers, views | Domain only |
| Domain | Business rules, entities | None (pure) |
| Data | Repositories, APIs, DBs | Domain interfaces |
| Infrastructure | Frameworks, libraries | Implements domain interfaces |

---

## Anti-Patterns (NEVER use)

- **Magic strings**: Use enums/constants for bounded values
- **Hidden dependencies**: Make all dependencies explicit in constructor/parameters
- **God classes**: Split by single responsibility
- **Deep inheritance**: Prefer composition over inheritance
- **Premature abstraction**: Wait for duplication before abstracting
- **Feature envy**: Methods that use another class's data more than their own
- **Primitive obsession**: Use domain types instead of primitives (Email, not String)

---

## Core Philosophy

> "Clean code is simple and direct. Clean code reads like well-written prose. Clean code never obscures the designer's intent." — Grady Booch
