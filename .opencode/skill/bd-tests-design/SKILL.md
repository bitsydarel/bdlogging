---
name: bd-tests-design
description: Designs and implements validation logic. Use when writing, updating, refactoring, or fixing single test cases or full suites, including unit, integration, E2E, and UI automation.
---

# Test Design

This skill guides the design and implementation of comprehensive, well-structured tests. Apply these principles when writing new tests, improving coverage, or designing test strategies across any platform.

The user provides code to test or a feature requiring tests. They may specify the test type needed (unit, integration, E2E) or ask for test strategy recommendations.

---

## Test Thinking

Before writing tests, understand what you're testing and why:

- **Purpose**: What behavior are you verifying? What could go wrong?
- **Scope**: Is this a unit test, integration test, or end-to-end test?
- **Inputs**: What are all the possible input categories?
- **Outputs**: What are the expected outcomes for each input category?

**CRITICAL**: Write tests that verify behavior, not implementation. Tests should survive refactoring if the behavior remains the same.

### When This Applies

Use this skill when:
- Writing tests for new features
- Improving test coverage for existing code
- Designing test strategies for a module/feature
- Identifying what edge cases to test
- Reviewing tests for completeness

---

## Test Design Criteria

### Equivalence Partitioning (EP)

**Applies to**: All input validation, data processing, business logic

**Guidance**:
- Divide inputs into classes where all values in a class are treated the same
- Test at least one value from each equivalence class
- Include valid classes and invalid classes

**Example Application**:
```
Function: calculateDiscount(age: int)
Classes:
  - Invalid: age < 0 (negative)
  - Child: 0-12 (50% discount)
  - Teen: 13-19 (25% discount)
  - Adult: 20-64 (no discount)
  - Senior: 65+ (30% discount)
Test one value from each: -1, 5, 15, 35, 70
```

### Boundary Value Analysis (BVA)

**Applies to**: Numeric ranges, string lengths, collection sizes, date ranges

**Guidance**:
- Test at exact boundaries and one step before/after
- Boundaries are where bugs most often occur
- Combine with equivalence partitioning

**Example Application**:
```
Range: 0-12 (child), 13-19 (teen)
Boundary tests: 0, 12, 13, 19, 20
Also test: -1 (below min), edge of max range
```

### CORRECT Heuristic

**Applies to**: All test design, especially edge cases

**Guidance**:
| Letter | Meaning | What to Test |
|--------|---------|--------------|
| C | Conformance | Does it match the expected format/structure? |
| O | Ordering | Does order matter? Test different orderings |
| R | Range | Test min, max, and values just outside |
| R | Reference | Test null, empty, circular references |
| E | Existence | What if it doesn't exist? Empty? Null? |
| C | Cardinality | Test 0, 1, many (especially at boundaries) |
| T | Time | Timing issues, timeouts, ordering of events |

### Right-BICEP

**Applies to**: Verifying test completeness

**Guidance**:
| Letter | Meaning | What to Verify |
|--------|---------|---------------|
| Right | Right results | Does it produce correct output for valid input? |
| B | Boundary | Are all boundaries tested? |
| I | Inverse | Can you verify by reversing the operation? |
| C | Cross-check | Can you verify using a different method? |
| E | Error conditions | Does it handle errors correctly? |
| P | Performance | Does it meet performance requirements? |

### Zero-One-Many

**Applies to**: Collections, loops, recursive operations

**Guidance**:
- Test with 0 items (empty case)
- Test with 1 item (single case)
- Test with many items (multiple case)
- Test at collection size boundaries if applicable

**Example Application**:
```
Function: processOrders(orders: List<Order>)
Tests:
  - Empty list: []
  - Single order: [order1]
  - Multiple orders: [order1, order2, order3]
  - Many orders: boundary of pagination/batch size
```

---

## Property-Based Testing

**Applies to**: Pure functions, data transformations, serialization, algorithms, invariants

### What is Property-Based Testing?

Instead of writing individual test cases with specific inputs and outputs, define **properties** (invariants) that should hold true for *all* valid inputs. The testing framework generates hundreds of random inputs to verify the property.

### When to Use Property-Based Testing

| Use Case | Property Example |
|----------|------------------|
| Serialization | `deserialize(serialize(x)) == x` (round-trip) |
| Sorting | Output is ordered, same length, same elements |
| Encoding | `decode(encode(x)) == x` |
| Math operations | Associativity, commutativity, identity |
| Data structures | Invariants always hold after operations |
| Parsers | Valid input produces valid output |

### Common Property Patterns

**Applies to**: Identifying what properties to test

| Pattern | Description | Example |
|---------|-------------|---------|
| Round-trip | Encode then decode returns original | JSON serialize/deserialize |
| Idempotence | Applying twice equals applying once | `sort(sort(x)) == sort(x)` |
| Invariant | Property always holds | List length never negative |
| Commutativity | Order doesn't matter | `a + b == b + a` |
| Associativity | Grouping doesn't matter | `(a + b) + c == a + (b + c)` |
| Identity | Neutral element exists | `x + 0 == x` |
| Inverse | Operations cancel out | `x - x == 0` |
| Oracle | Compare with known-correct implementation | New sort vs standard library sort |

### Property-Based Testing Tools

| Platform | Library | Example |
|----------|---------|---------|
| Python | Hypothesis | `@given(st.lists(st.integers()))` |
| TypeScript/JS | fast-check | `fc.assert(fc.property(fc.array(fc.integer()), ...))` |
| Swift | SwiftCheck | `property("...") <- forAll { (x: Int) in ... }` |
| Kotlin | Kotest | `forAll<Int, Int> { a, b -> ... }` |
| Dart | glados | `Glados(any.int).test(...)` |
| Go | gopter | `properties.Property(...)` |
| Rust | proptest | `proptest! { fn test(x in 0..100) { ... } }` |

### Writing Good Properties

**Guidance**:
- Start with the simplest property that could fail
- Properties should be easier to verify than implement
- Use shrinking to find minimal failing cases
- Combine with example-based tests for known edge cases

**Example Application**:
```python
# Property: Sorting preserves elements
@given(lists(integers()))
def test_sort_preserves_elements(xs):
    sorted_xs = my_sort(xs)
    assert sorted(xs) == sorted(sorted_xs)  # Same elements
    assert len(xs) == len(sorted_xs)         # Same length

# Property: Sorted output is ordered
@given(lists(integers()))
def test_sort_orders_elements(xs):
    sorted_xs = my_sort(xs)
    for i in range(len(sorted_xs) - 1):
        assert sorted_xs[i] <= sorted_xs[i + 1]
```

---

## Test Structure

### Arrange-Act-Assert (AAA)

**Applies to**: All test methods

**Guidance**:
```
# Arrange - Set up the test conditions
given_user = User(name="Alice", age=25)
given_product = Product(price=100)

# Act - Execute the behavior being tested
result = checkout_service.process(user=given_user, product=given_product)

# Assert - Verify the expected outcome
assert result.total == 100
assert result.discount == 0
```

### Test Isolation

**Applies to**: All unit tests

**Guidance**:
- Each test must be independent (no shared mutable state)
- Tests should run in any order
- Use fresh fixtures for each test
- Mock/stub external dependencies

### Naming Conventions

**Applies to**: Test methods and classes

**Guidance**:
- Name should describe the scenario and expected outcome
- Format: `test_[scenario]_[expected_outcome]` or `should_[outcome]_when_[scenario]`

**Example Application**:
```
test_calculateDiscount_returnsZero_whenUserIsAdult()
test_calculateDiscount_returns50Percent_whenUserIsChild()
should_throwException_when_ageIsNegative()
```

---

## Edge Case Coverage

**Applies to**: All test suites

### Required Edge Cases

| Category | What to Test |
|----------|--------------|
| Empty/Null | Empty strings, empty collections, null values |
| Invalid Types | Wrong data types, malformed data |
| Boundary Values | Min, max, off-by-one |
| Large Inputs | Performance, memory limits |
| Concurrent Access | Race conditions, deadlocks |
| Network Failures | Timeouts, connection errors |
| Special Characters | Unicode, emojis, escape sequences |
| Time Zones | UTC, DST transitions, different zones |

### Happy/Sad/Ugly Paths

| Path | Description | Examples |
|------|-------------|----------|
| Happy | Normal expected flow | Valid user logs in successfully |
| Sad | Expected error conditions | Wrong password shows error |
| Ugly | Unexpected edge cases | Database down during login |

---

## Platform-Specific Testing

### Mobile (iOS/Android/Flutter)

**Applies to**: Mobile applications

| Test Type | Tools | What to Test |
|-----------|-------|--------------|
| Unit | XCTest, JUnit, flutter_test | Business logic, view models |
| Widget/UI | XCUITest, Espresso, flutter_test | Component rendering, interactions |
| Integration | XCTest, JUnit | Service integration, data flow |
| Snapshot | swift-snapshot-testing, golden | Visual regression |
| Property | SwiftCheck, Kotest, glados | Data transformations, invariants |

**Mobile-Specific Cases**:
- Device rotation
- Background/foreground transitions
- Memory pressure
- Network changes (offline/online)
- Permission denials

### Web (React/Vue/Angular)

**Applies to**: Web applications

| Test Type | Tools | What to Test |
|-----------|-------|--------------|
| Unit | Jest, Vitest | Functions, hooks, utilities |
| Component | Testing Library, Vue Test Utils | Component rendering, events |
| Integration | Testing Library | Component interactions |
| E2E | Playwright, Cypress | Full user flows |
| Visual | Chromatic, Percy | Visual regression |
| Property | fast-check | State machines, reducers |

**Web-Specific Cases**:
- Browser compatibility
- Responsive breakpoints
- Accessibility (a11y)
- SEO requirements

### Backend (APIs/Services)

**Applies to**: Backend services

| Test Type | Tools | What to Test |
|-----------|-------|--------------|
| Unit | pytest, JUnit, go test | Business logic, utilities |
| Integration | pytest, testcontainers | Database, external services |
| Contract | Pact, dredd | API contracts |
| Load | k6, locust | Performance, scalability |
| Property | Hypothesis, gopter | Serialization, algorithms |

**Backend-Specific Cases**:
- Authentication/authorization
- Rate limiting
- Database transactions
- Concurrent requests
- Idempotency

### AI/ML (Models/Pipelines)

**Applies to**: Machine learning systems

| Test Type | What to Test |
|-----------|--------------|
| Data Validation | Schema, distributions, missing values |
| Model Accuracy | Metrics on holdout sets |
| Inference | Latency, memory usage |
| Drift Detection | Feature drift, prediction drift |
| Property | Model invariants, input/output relationships |

---

## Anti-Patterns (NEVER use)

- **Test interdependence**: Tests that rely on other tests running first
- **Shared mutable state**: State that bleeds between tests
- **Implementation coupling**: Tests that break when refactoring internals
- **Flaky tests**: Non-deterministic tests (fix or delete)
- **Slow unit tests**: Unit tests should be milliseconds, not seconds
- **Testing private methods**: Test behavior through public interface
- **Excessive mocking**: Mock boundaries, not everything
- **Insufficient shrinking**: Not using property-based test shrinking to find minimal cases

---

## Core Philosophy

> "Tests are specifications. They document what the code should do, not how it does it. A good test suite is a safety net that enables fearless refactoring."

Write tests that future developers will thank you for—clear, comprehensive, and maintainable.