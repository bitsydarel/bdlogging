---
name: bd-problem-solving
description: Evaluates options, performs problem-solving, analyzes logic, and determines the best course of action. Use for decision-making, debugging, resolving technical issues, and exploring codebases.
---

# Problem Solving

This skill guides systematic approaches to debugging, solution design, and code comprehension. Apply these methodologies when facing technical challenges, exploring unfamiliar codebases, or making architectural decisions.

The user provides a problem to solve: a bug to fix, a feature to design, code to understand, or a technical decision to make. They may include error messages, code snippets, or context about the system.

---

## Problem-Solving Thinking

Before diving into solutions, understand the problem deeply:

- **Symptom vs. Root Cause**: What is the visible issue? What is the underlying cause?
- **Scope**: Is this a local issue or a systemic problem?
- **Constraints**: What are the technical, time, and resource constraints?
- **Success Criteria**: How will you know the problem is solved?

**CRITICAL**: Never treat symptoms. Always find and fix the root cause. A quick fix that masks the issue will resurface later with greater impact.

### When This Applies

Use this skill when:
- Debugging errors or unexpected behavior
- Designing solutions for new features
- Understanding unfamiliar codebases
- Making technical decisions with trade-offs
- Investigating performance issues
- Analyzing system failures

---

## Tree of Thoughts Problem-Solving

**Applies to**: Complex problems with multiple potential solutions, architectural decisions, debugging

### Methodology

Explore problems like a tree, branching into multiple potential solutions before committing:

```
Problem
├── Solution A
│   ├── Pro: Fast implementation
│   ├── Con: Technical debt
│   └── Risk: May not scale
├── Solution B
│   ├── Pro: Clean architecture
│   ├── Con: More time needed
│   └── Risk: Over-engineering
└── Solution C
    ├── Pro: Reuses existing code
    ├── Con: Couples to legacy system
    └── Risk: Maintenance burden
```

### Steps

1. **Define the problem clearly** - What exactly needs to be solved?
2. **Generate multiple solutions** - At least 2-3 different approaches
3. **Evaluate each branch** - Consider trade-offs for each
4. **Select and justify** - Choose based on constraints and priorities
5. **Validate the choice** - Ensure it addresses root cause

### Evaluation Criteria

| Criterion | Questions to Ask |
|-----------|-----------------|
| Correctness | Does it fully solve the problem? |
| Simplicity | Is it the simplest solution that works? |
| Maintainability | Can others understand and modify it? |
| Scalability | Will it work as load/data grows? |
| Testability | Can it be effectively tested? |
| Time-to-implement | How long will it take? |
| Risk | What could go wrong? |

---

## Graph of Thoughts Code Comprehension

**Applies to**: Understanding unfamiliar codebases, system analysis, onboarding

### Methodology

Map code relationships as a graph to understand how components interact:

```
[Controller] ──calls──> [Service] ──uses──> [Repository]
      │                     │                     │
      │                     v                     v
      │              [Domain Model] <──maps── [Entity]
      │                     │
      └──────returns───────>│
```

### Analysis Approaches

**Top-Down Analysis**:
1. Start with entry points (main, routes, handlers)
2. Follow the request/data flow downward
3. Identify major components and their responsibilities
4. Drill into details only as needed

**Bottom-Up Analysis**:
1. Start with data models and entities
2. Find what uses them
3. Build up understanding of data flow
4. Connect to entry points

**Combine Both**: Use top-down for architecture overview, bottom-up for specific feature understanding.

### What to Map

| Component | Questions to Answer |
|-----------|-------------------|
| Entry Points | Where does execution start? |
| Data Flow | How does data move through the system? |
| Dependencies | What depends on what? |
| Side Effects | Where does state change? External calls? |
| Error Handling | Where are errors caught and handled? |
| Configuration | What is configurable? Where? |

---

## Root Cause Analysis

**Applies to**: Debugging, incident response, preventing recurrence

### The 5 Whys Technique

Keep asking "why" until you reach the root cause (typically 5 levels):

```
Problem: Production server crashed
Why 1: Memory exhausted
Why 2: Memory leak in image processing
Why 3: Images not released after processing
Why 4: Exception skipped cleanup code
Why 5: No try-finally around resource allocation
Root Cause: Missing resource cleanup pattern
```

### Debugging Methodology

| Step | Action |
|------|--------|
| 1. Reproduce | Can you reliably trigger the issue? |
| 2. Isolate | What is the minimal code that exhibits the bug? |
| 3. Hypothesize | What could cause this behavior? |
| 4. Test | Validate or eliminate each hypothesis |
| 5. Fix | Address the root cause, not just the symptom |
| 6. Verify | Confirm the fix and check for regressions |
| 7. Prevent | Add tests, monitoring, or safeguards |

### Common Root Cause Categories

| Category | Examples |
|----------|----------|
| State Management | Race conditions, stale cache, incorrect initialization |
| Resource Handling | Leaks, exhaustion, improper cleanup |
| Error Handling | Swallowed exceptions, missing cases, incorrect recovery |
| Data Integrity | Invalid input, encoding issues, type mismatches |
| Timing | Timeouts, ordering assumptions, async issues |
| Configuration | Environment differences, missing settings |

---

## Decision Framework

**Applies to**: Technical decisions, architecture choices, tool selection

### Decision Documentation

For significant decisions, document:

```
## Decision: [Title]

### Context
What is the situation? What problem are we solving?

### Options Considered
1. Option A: [Description]
   - Pros: ...
   - Cons: ...

2. Option B: [Description]
   - Pros: ...
   - Cons: ...

### Decision
We chose Option [X] because...

### Consequences
- Positive: ...
- Negative: ...
- Risks: ...
```

### Trade-off Analysis

| Dimension | Trade-off |
|-----------|-----------|
| Speed vs. Quality | Fast delivery vs. maintainable code |
| Flexibility vs. Simplicity | Configurable vs. easy to understand |
| Consistency vs. Autonomy | Standardization vs. team freedom |
| Build vs. Buy | Custom solution vs. third-party tool |
| Now vs. Later | Immediate fix vs. long-term solution |

---

## Performance Investigation

**Applies to**: Slow operations, resource issues, scalability problems

### Investigation Steps

1. **Measure** - Profile before optimizing (don't guess)
2. **Identify** - Find the actual bottleneck
3. **Analyze** - Understand why it's slow
4. **Optimize** - Fix the specific bottleneck
5. **Verify** - Measure improvement

### Common Performance Issues

| Issue | Investigation |
|-------|--------------|
| N+1 Queries | Check database query count per request |
| Memory Leaks | Monitor memory over time, check allocations |
| Blocking I/O | Look for synchronous network/disk calls |
| Inefficient Algorithms | Profile CPU hotspots, check complexity |
| Missing Indexes | Analyze query execution plans |
| Cache Misses | Check cache hit rates and invalidation |

---

## Platform-Specific Debugging

### Mobile (iOS/Android/Flutter)

**Applies to**: Mobile application issues

| Issue Type | Tools/Approach |
|------------|---------------|
| UI Issues | Layout inspector, view hierarchy debugger |
| Memory | Instruments (iOS), Memory Profiler (Android) |
| Network | Charles Proxy, network inspector |
| Crashes | Crashlytics, console logs, stack traces |
| Performance | Time Profiler, systrace |

### Web (Frontend)

**Applies to**: Web application issues

| Issue Type | Tools/Approach |
|------------|---------------|
| Rendering | React DevTools, Vue DevTools, DOM inspector |
| Network | Network tab, request/response inspection |
| Performance | Lighthouse, Performance tab, Web Vitals |
| State | Redux DevTools, state inspection |
| Memory | Memory tab, heap snapshots |

### Backend (APIs/Services)

**Applies to**: Server-side issues

| Issue Type | Tools/Approach |
|------------|---------------|
| Request Flow | Distributed tracing (Jaeger, Zipkin) |
| Logs | Structured logging, log aggregation |
| Database | Query analysis, slow query logs |
| Resources | Metrics (CPU, memory, connections) |
| Errors | Error tracking (Sentry, Bugsnag) |

---

## Anti-Patterns (NEVER use)

- **Shotgun debugging**: Making random changes hoping something works
- **Symptom fixing**: Addressing visible issues without finding root cause
- **Single-solution thinking**: Not considering alternatives
- **Premature optimization**: Optimizing without profiling first
- **Blame-first debugging**: Assuming the problem is elsewhere
- **Ignoring context**: Not understanding the system before changing it
- **Copy-paste fixing**: Applying fixes without understanding them

---

## Core Philosophy

> "Given enough eyeballs, all bugs are shallow." — Linus's Law

Approach every problem systematically. Understand before you act. Fix root causes, not symptoms. Document decisions for future reference.