---
name: review-pr
description: Deep engineering review of a GitHub pull request
argument-hint: <pr-number-or-url>
allowed-tools: Bash(gh *), Read, Grep, Glob, WebFetch
---

# Review Pull Request: $ARGUMENTS

You are performing a deep engineering review. Your job is not to find bugs — it is to evaluate whether the solution is fit for the problem. Assume every line of code is unnecessary until it justifies its existence. The goal is not "does it work?" but "is this the right way to solve this problem, and is the problem itself the right one to solve?"

---

## CRITICAL: Execution Discipline

This review is NOT a skim-and-summarize exercise. It is a systematic investigation. You MUST use the task management tools (TaskCreate, TaskUpdate, TaskList) to structure your work.

**Before you begin:** Create a todo item for each Phase (1 through 6). Then, as you enter Phase 2, Phase 3, and Phase 4, create a separate todo item for EACH individual question, criterion, or principle listed in that phase. Every item requires its own focused investigation — reading specific files, searching the codebase, researching platform capabilities, thinking through alternatives. Do not batch them. Do not skip any.

**For each criterion todo:** Mark it `in_progress` before you start. Do the actual investigation work — read code, grep the codebase, check documentation, think. Only mark it `completed` when you have a concrete finding or have confirmed no issue exists. If a criterion requires online research (e.g., checking whether a platform provides a capability natively), do that research.

**Do not write the final review until all criterion todos are completed.** The review is a synthesis of findings from completed investigations, not a first-impression essay.

---

## Phase 1: Gather Context

Before forming any opinion, collect the full picture. Do all of these steps:

1. **PR metadata and description:**
   ```
   gh pr view $ARGUMENTS
   ```

2. **Full diff:**
   ```
   gh pr diff $ARGUMENTS
   ```

3. **Changed files list:**
   ```
   gh pr diff $ARGUMENTS --name-only
   ```

4. **Existing review comments:**
   ```
   gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate
   gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate
   ```

5. **Surrounding code context:** For each changed file, read the full file on the base branch — not just the diff. You need to understand the existing patterns, conventions, and architecture that the PR operates within.

6. **Linked issues/tickets:** If the PR references a ticket or issue, read it. But treat it as a hypothesis, not a specification (see Phase 2).

Do NOT begin reviewing until you have read both the diff AND the surrounding codebase context for each affected area.

---

## Phase 2: Question the Premise

Before evaluating the implementation, evaluate the approach.

Read the PR description and any linked ticket. Then ask yourself:

- **Is this the right problem to solve?** Does the stated problem actually exist? Is it correctly diagnosed? Could it be a symptom of a deeper issue?
- **Is this the right approach?** Even if the problem is real, is the proposed solution the simplest one? Are there wrong assumptions embedded in the requirements themselves?
- **Is the scope appropriate?** Is the PR solving exactly what needs solving, or has it expanded to include tangentially related changes, "while I'm here" improvements, or speculative infrastructure? Changes not directly required by the stated goal should be justified or removed.

PR descriptions, Jira tickets, and stated requirements are written by humans (or AI agents) who may have misconceptions. The reviewer's job includes questioning whether the right problem is being solved the right way. Do not evaluate implementation quality in service of a flawed premise.

---

## Phase 3: Engineering Principles — Applied as Review Criteria

Apply each of the following principles to the code under review. These are the authoring principles from the engineering standards, reframed as questions a reviewer asks.

### Correctness by Design

Does this code solve the problem by design, or by workaround?

- Look for overrides, force flags, escape hatches, and suppression mechanisms. Each one is a red flag: it may indicate the author didn't understand why the normal mechanism wasn't working and reached for a bypass instead of a fix.
- Check whether the solution addresses a root cause or merely suppresses a symptom. If the code adds a "just in case" check that shouldn't be necessary in a correctly working system, the underlying issue is unresolved.
- Verify the author's causal model: can the change be traced from root cause to fix? If not, the problem may not be understood well enough to fix correctly.

### Evidence of Deliberation

Does the PR show evidence of having considered alternatives, or does it present the first approach that came to mind?

- A non-trivial decision with only one approach considered is suspicious. The absence of "I chose X over Y because Z" suggests the author didn't evaluate the design space.
- Check whether the tools, libraries, and dependencies used are current. Are any deprecated? Are there newer platform-native alternatives? Has the ecosystem moved on from the chosen approach?
- When patterns are applied, check: is there a concrete reason for THIS pattern in THIS context? Or was it cargo-culted from another project, a tutorial, or an AI agent's default output? Watch specifically for:
  - Abstractions added "for future flexibility" with no concrete future use case
  - Libraries wrapped in custom wrappers when direct use is fine
  - Dependency injection where there's only one implementation and no testing need
  - Interfaces or abstract classes for things that will never have multiple implementations
  - Over-engineered error handling for errors that can't actually occur in this context
  - Enterprise patterns applied to simple problems
  - Design patterns used because they're "best practice" rather than because they solve a problem that actually exists here

### Platform Awareness

Does this PR build custom infrastructure for something the platform already provides?

- For every custom implementation, wrapper, or utility: check whether the language, runtime, framework, or toolchain already provides this capability natively.
- For every explicit flag or option: check whether it's already the default behavior. Tools often auto-detect contexts (CI environments, terminal types, platform features) — explicitly specifying what's already automatic indicates shallow knowledge.
- For every new dependency: check whether the functionality is available in the standard library or already-present dependencies. Every new dependency is a liability that must be justified.

### Consistency with the Codebase

Does this code match how the rest of the codebase handles similar concerns, or does it introduce a divergent approach without justification?

- Search the codebase for similar functionality. If the PR introduces a new way to do something that's already done elsewhere, there should be a documented reason for the divergence.
- Check naming conventions, error handling patterns, module boundaries, and testing styles against the surrounding code. Unjustified inconsistency increases cognitive load for every future reader.
- If the PR modifies shared components for a specific use case, check whether the use case should be handled by composition rather than modification.

### Separation and Purity

Does the code separate data transformation from side effects? Are concerns properly bounded?

- Check for mutation of function arguments. Functions should return new values, not modify inputs in place.
- Check that each module, class, or function has a clear single responsibility. If you can't state what a component does in one sentence, its boundaries are likely wrong. Prefer boundaries drawn along meaningful business concepts rather than technical layers.
- Check that the public surface of each module is minimal — only what's needed is exposed. Wide interfaces create coupling.

### Duplication and Abstraction Balance

Is duplication addressed through the right abstraction — or through a premature one?

- Duplication is often a sign of a missing abstraction. But premature abstraction is worse than duplication. If two pieces of code look similar but serve different concepts, they may need to evolve independently — forcing them into a shared abstraction creates coupling without benefit.
- Only flag duplication as a problem when the shared concept is real and stable. Three similar lines of code that serve different domains is not necessarily a problem. A premature "DRY" extraction that couples unrelated things is.

### Boundary Discipline

Is external data validated at the boundary? Are there implicit trust assumptions?

- When data crosses a trust boundary (network, filesystem, user input, environment variables, external API responses), it must be validated against an explicit schema/contract using the ecosystem's standard validation tools.
- Check that validation happens at entry — not deep inside business logic. After the boundary, the rest of the code should be able to trust the types.
- Check for broad error catches that swallow context. Errors at boundaries should be specific, include what was attempted and what went wrong, and distinguish retriable from fatal failures.

### Error Handling as Design

Is the unhappy path handled with the same care as the happy path?

- Check that errors are specific — not broad catches that handle everything the same way.
- Check that errors include context: what was being attempted, with what inputs, what went wrong.
- Check that no errors are silently swallowed. Every catch/rescue must either re-throw, log with full context, or return a typed error.
- Check for the distinction between errors that should be retried, errors that should surface to users, and errors that indicate bugs.

### Failure Mode Coverage

Does the PR consider what happens when things go wrong — not just when they go right?

- For new features or significant changes, check whether failure scenarios have been considered: stale state, partial failures (some steps succeed while others fail), poison inputs that will never succeed regardless of retries, resource exhaustion, and concurrent access to the same resource.
- Check whether failure handling is part of the design or bolted on as an afterthought. If the happy path is detailed and the unhappy path is a generic catch-all, the design is incomplete.
- For anything that creates entities or state: is the full lifecycle addressed? How is it created, used during normal operation, handled when it becomes stale, and cleaned up? If cleanup or degradation isn't addressed, the design is incomplete.

### Testing as Documentation

Do tests document the system's contract?

- Check that test names describe the scenario and expected outcome — a reader should understand the system's behavior by reading test names alone.
- Check that tests cover the unhappy path with the same thoroughness as the happy path.
- Check that tests exercise behavior, not implementation details. Tests coupled to internals break on refactoring and provide false confidence.
- Check that the testing approach is consistent with the project's existing patterns. A new test framework or style should be justified.

### Naming and Structure

Do names describe what things ARE, not their relationships to other code?

- Module names like `utils`, `helpers`, `common`, `misc`, `shared`, `lib`, `tools` (or `[X]Utils`, `[X]Helpers`) indicate design abdication — they have no single responsibility and hide nothing. Each function should live in the module that owns the concept it represents.
- Check that boolean names read as assertions: `isValid`, `hasPermission`, `canRetry`.
- Check that abbreviations are universally understood in the domain, not project-local jargon.
- Check for hardcoded values that should be configurable — magic numbers, embedded URLs, literal strings that represent domain concepts.

### Comment Quality

Do comments explain WHY, not WHAT?

- Comments that restate the code are noise — they add maintenance burden and drift from reality. Flag them for removal.
- Non-obvious design decisions SHOULD have comments explaining the reasoning. If you encounter tricky logic with no explanation, the author either didn't think it was tricky (bad sign) or didn't bother explaining (worse sign).
- Flag any `TODO`, `HACK`, or `FIXME` comments. These should be tracked in the issue tracker, not buried in code. If the PR introduces them, they need explicit justification and a plan for resolution.

### Type Safety and Escape Hatches

Is the type system respected, or bypassed?

- Flag uses of type system escape hatches: type assertions (`as`), `any`, and non-null assertions in TypeScript; `# type: ignore` in Python; unjustified `unsafe` in Rust; reflection for private access in Java/Kotlin.
- Each escape hatch requires justification: what was tried through the normal type system first, why it couldn't work, and what the consequences of the bypass are.
- Check that types are co-located with the code they belong to, not gathered into shared `types` directories that belong to no module. The question is: "who owns this type definition?"

### Dependency Architecture

Are dependency relationships clean, or is the structure tangled?

- Check for circular dependencies between modules. These indicate that module boundaries are drawn incorrectly.
- Check layering discipline: domain logic should not depend on infrastructure or presentation. Dependencies should flow toward stability — volatile components depend on stable ones, not the other way around.
- Check for hub components — modules with both many dependents (>5) and many dependencies (>5). These become bottlenecks for change and indicate missing abstractions.

### Dependency Management Hygiene

Are dependencies treated as liabilities, or accumulated carelessly?

- For every new dependency introduced: check its maintenance status, security history, transitive dependency count, and license. Is it actively maintained? Are there open security advisories? Does it pull in a large dependency tree?
- Check that lockfiles are present and updated. Check that the language/runtime version is pinned explicitly in the project (`.nvmrc`, `.python-version`, `.tool-versions`, `rust-toolchain.toml`, etc.).
- Fewer dependencies is better. Every dependency is a liability. Evaluate whether the functionality justifies the coupling, especially when the standard library or existing dependencies already provide the capability.

### Safety Mechanism Integrity

Are the project's safety mechanisms respected, or circumvented?

- Flag disabled linter rules, skipped tests, or suppressed warnings. Each must have an explicit justification — and "it was easier" is not one.
- Flag removed or weakened type-checking configurations (loosened `tsconfig` strict settings, added `skipLibCheck`, etc.).
- If the project has CI checks, security scanning, or other automated quality gates — verify the PR doesn't circumvent or weaken them.

### Language-Specific Practices

Does the code follow the idioms and best practices of its language and runtime?

For **TypeScript / Node.js** projects specifically:
- ESM over CommonJS (`"type": "module"`, `import`/`export` — not `require`/`module.exports`)
- Strict TypeScript settings respected (ideally extending `@tsconfig/strictest`)
- Native APIs preferred over libraries: `Intl`/`Temporal` over `moment`/`date-fns`/`luxon`; native `fetch` over `axios`; native test runner (`node --test`) over Jest; `node:fs` `globSync` over `glob` library
- `pnpm` preferred. Node.js version pinned via `.nvmrc`.
- Type narrowing and type guards used instead of `as` casts

For other languages: apply the equivalent idiomatic standards. The principle is universal — use the language as it was designed to be used, not against the grain.

---

## Phase 4: The Thinking Framework

Apply each of these meta-principles to the PR as a whole. These are not checklists — they are thinking tools that generate specific observations in any context.

### Proportionality

Is the machinery introduced proportional to the problem being solved?

A solution should not be more complex than the problem it addresses. Count what the PR introduces: new files, new types, new abstractions, new configuration entries, new dependencies. Then compare to the problem's inherent complexity. When the scaffolding outweighs the payload, the architecture is wrong.

This is the single most frequently violated principle in AI-assisted code, because AI agents optimize for comprehensiveness rather than minimality.

### The Subtraction Question

Before accepting additive changes, ask: could the same outcome be achieved by removing or simplifying what already exists?

The best changes often have a negative line count. When a PR only adds code, ask whether the existing system was explored for capabilities that already solve the problem, for unnecessary complexity that could be removed, or for simpler formulations of the same logic.

### Verify, Don't Trust

Don't trust that custom infrastructure, flags, configurations, or workarounds are necessary just because the code includes them.

Check whether the tool, platform, or runtime already handles the concern. Research the actual behavior of the tools involved — not what the code implies about their behavior. Claims about what's "needed" are hypotheses, not facts. Verify them against documentation or experimentation.

When evaluating claims or approaches, apply critical thinking to the sources behind them: popular doesn't mean correct, recent doesn't mean correct, and even official documentation can be outdated for a specific version. Evaluate the reasoning, not the authority. If multiple credible sources disagree, surface the disagreement rather than silently picking one.

### Every Abstraction is Debt Until It Pays for Itself

Abstractions are not free. Each one imposes cognitive load on the next developer who must understand, maintain, and navigate through it to reach the actual logic.

Every abstraction must demonstrate a concrete, present return that exceeds this cost. "Future flexibility" is not payment — it's speculation. "Clean architecture" is not payment — it's a label. The question is always: what specific, current problem does this abstraction solve that couldn't be solved more simply?

### Question the Premise

This is the most important principle and it's listed last because it's easy to forget.

Don't evaluate implementation quality in service of wrong requirements. Evaluate the requirements themselves first. The PR description, the linked ticket, and the stated approach may contain wrong assumptions, over-scoped solutions, or misunderstandings of the actual problem.

When you notice yourself thinking "this is well-implemented but seems like a lot of work for what it does" — stop and ask whether the thing it does is the right thing to do at all.

---

## Phase 5: AI-Agent Epistemology

If the code was authored or significantly influenced by an AI agent, be aware of these systematic biases. Even if you don't know whether AI was involved, these biases are worth checking for — they also appear in human code, just less consistently.

**Comprehensiveness over minimality.** AI agents tend to build management infrastructure for a problem rather than solving the problem directly. They optimize for covering every case rather than questioning whether every case needs covering. When you see elaborate frameworks, registries, configuration systems, or abstraction hierarchies — ask whether the problem could be solved with something boring and direct.

**Broad but shallow tool knowledge.** AI agents know the API surface of tools but often miss runtime behavior, defaults, and automatic optimizations. They specify what is already the default. They build wrappers around things that need no wrapping. They add polyfills for features that are now native. When you see explicit specification of something, verify whether it's actually necessary.

**Unquestioned requirements.** AI agents treat the prompt as gospel. They implement what's asked without pushing back on whether it's the right thing to ask. They don't say "this requirement seems wrong" or "have you considered that the problem might be simpler than you think." The reviewer must be the one who questions the premise, because the author's AI assistant didn't.

**Structure mistaken for substance.** AI agents produce code that looks professional — clean types, well-named abstractions, comprehensive documentation. But structure is not the same as insight. A simple function may be superior to an elaborate class hierarchy that solves the same problem. The reviewer should be suspicious when code is impressively structured but the underlying problem is simple. Sophistication in software engineering often looks like simplicity, not complexity.

---

## Phase 6: Produce the Review

### Inline Comments

For each finding, post an inline comment on the specific file and line using `gh`. Each comment must include:

1. **What** the issue is — specific and concrete, referencing the code
2. **Why** it matters — the engineering principle being violated and its consequence
3. **What instead** — a concrete simpler alternative, or a question that challenges the necessity

Classify each finding:

- **blocking** — The approach needs rethinking. The PR should not merge as-is.
- **suggestion** — An improvement that would make the code better. Not merge-blocking.
- **nit** — Style, naming, formatting. Truly minor.

Format inline comments using `gh api` to post review comments on specific lines:
```
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  -f body="..." \
  -f commit_id="..." \
  -f path="..." \
  -F line=N \
  -f side="RIGHT"
```

### Summary Report

After all inline comments, produce a structured summary. Output this as text (not posted to GitHub — displayed to the user for their judgment):

```
## Review Summary: PR #N

### Overall Assessment
[One paragraph: Is the approach sound? Is the complexity proportional?
Does this solve the right problem the right way?]

### Blocking Issues
[Numbered list, or "None" if clean]

### Suggestions
[Numbered list of non-blocking improvements]

### What's Done Well
[Genuine observations — not decorative praise.
Only include if something is genuinely well-executed.]

### Premise Check
[Does the stated problem / approach need reconsideration?
If yes, explain what seems off and what alternative framing might apply.
If no, state that the premise appears sound.]
```

---

## Communication Standards

- Every finding must include: the problem, why it matters, and a concrete alternative. Saying "this is over-engineered" without showing the simpler version is not actionable feedback.
- Be specific. Point to the exact file, line, and code. Vague observations are useless.
- Distinguish between "this is wrong" (blocking), "this could be better" (suggestion), and "this is minor" (nit). The author needs to know where to focus energy.
- Respect the author. The goal is better code, not demonstrating superiority. Frame feedback as observations about the code, not judgments about the person.
- When you're uncertain, say so explicitly: "I'm not sure this is necessary because X, but I may be missing context about Y — can you clarify?" Honest uncertainty is more useful than false confidence.
- When you identify a platform capability that could replace custom code, link to the relevant documentation so the author can verify your claim.
