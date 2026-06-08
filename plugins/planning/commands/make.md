---
description: Create structured implementation plan in docs/plans/
argument-hint: describe the feature or task to plan
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, AskUserQuestion, Task, EnterPlanMode, TaskCreate, TaskUpdate, TaskList
---

# Implementation Plan Creation

create an implementation plan in `docs/plans/yyyymmdd-<task-name>.md` with interactive context gathering.

## custom rules loading

before starting, run this command via Bash tool to check for user-provided custom rules:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-rules.sh planning-rules.md ${CLAUDE_PLUGIN_DATA}
```

if the output is non-empty, treat it as additional instructions that supplement (not replace) the built-in rules below. apply custom rules alongside the command's own instructions throughout the planning process — they may influence plan structure, testing approach, naming conventions, or other aspects of plan creation. custom rules content is guidance for creating the plan, not content to embed verbatim in the output plan file.

### rules management

when the user asks to show/add/clear custom planning rules:

- **show**: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-rules.sh planning-rules.md ${CLAUDE_PLUGIN_DATA}` and display the output (empty → no rules configured; project-level `.claude/planning-rules.md` wins over user-level `$CLAUDE_PLUGIN_DATA/planning-rules.md`).
- **add/update**: write to `.claude/planning-rules.md` (project) or `$CLAUDE_PLUGIN_DATA/planning-rules.md` (user — requires the plugin installed from the marketplace; if `$CLAUDE_PLUGIN_DATA` is unset, offer project-level instead).
- **clear**: delete the corresponding file.

see `${CLAUDE_PLUGIN_ROOT}/references/custom-rules.md` for full documentation on the rules mechanism.

**CRITICAL: this skill must NEVER modify its own files (commands, skills, agents, scripts, references, hooks, plugin.json). the ONLY files it may create or modify for rules management are `.claude/planning-rules.md` and `$CLAUDE_PLUGIN_DATA/planning-rules.md`. if the user asks to change the skill's behavior, create a plan for it — do not edit skill files directly.**

## step 0: parse intent and gather context

before asking questions, understand what the user is working on:

1. **parse user's command arguments** to identify intent:
   - "add feature Z" / "implement W" → feature development
   - "fix bug" / "debug issue" → bug fix plan
   - "refactor X" / "improve Y" → refactoring plan
   - "migrate to Z" / "upgrade W" → migration plan
   - generic request → explore current work

2. **gather relevant context quickly** — use direct tool calls (Grep, Glob, Read), NOT an Explore agent. keep discovery under 30 seconds. prefer Grep for discovery and read at most ONE full file as a style exemplar:

   **conventions first** — consult `CLAUDE.md` and `.claude/planning-rules.md` (if present) as the primary source of code style, naming, and patterns. these are more reliable than incidental file reads.

   **for feature development:**
   - glob for files matching the feature area (e.g., `**/*auth*`, `**/*cache*`)
   - grep for names, signatures, and existing patterns in the area (use `-A/-B` context when idiom matters)
   - read at most ONE canonical file fully as a style/pattern exemplar

   **for bug fixing:**
   - grep for error messages or function names mentioned in the request
   - read the specific file(s) involved (the fix target — this is necessary, not exemplar reading)
   - check `git log --oneline -5` for recent changes

   **for refactoring/migration:**
   - glob for files matching the area being refactored
   - grep for imports/references to identify dependencies and current structure
   - read at most ONE key file fully as an exemplar

   **for generic/unclear requests:**
   - check `git status` and `git log --oneline -5`
   - read README.md or CLAUDE.md for project overview
   - `ls` the top-level directory structure

   **CRITICAL: do NOT launch an Explore agent. prefer grep for discovery; read at most ONE full file as a style exemplar (bug fixing may also read the specific buggy file). rely on CLAUDE.md / planning-rules.md for conventions. the goal is a quick scan, not exhaustive analysis — if more context is needed, ask the user in step 1.**

3. **synthesize findings** into a brief context summary (3-5 bullet points):
   - what the project is and primary language/framework
   - which files/areas are relevant to the request
   - key patterns or conventions observed

## step 1: present context and ask focused questions

show the discovered context, then gather the planning inputs:

"based on your request, i found: [context summary]"

**batch the context questions into a single AskUserQuestion call** (up to 4 questions at once) — do NOT ask them as separate turns:

1. **plan purpose** — "what is the main goal?" (multiple choice, suggested answer based on discovered intent)
2. **scope** — "which components/files are involved?" (multiple choice, suggested discovered files/areas)
3. **constraints** — "any specific requirements or limitations?" (can be open-ended)
4. **testing approach** — "TDD or regular?" (options: "TDD (tests first)" / "Regular (code first, then tests)"; store preference for implementation)

**plan title**: do NOT ask as a separate question — derive a short descriptive title from the intent/answers and show it when creating the file (step 2).

after answers are collected, synthesize them into plan context.

## step 1.5: explore approaches

once the problem is understood, propose implementation approaches:

1. **propose 2-3 different approaches** with trade-offs for each
2. **lead with recommended option** and explain reasoning
3. **present conversationally** - not a formal document yet

example format:
```
i see three approaches:

**Option A: [name]** (recommended)
- how it works: ...
- pros: ...
- cons: ...

**Option B: [name]**
- how it works: ...
- pros: ...
- cons: ...

which direction appeals to you?
```

use AskUserQuestion tool to let user select preferred approach before creating the plan.

**skip this step** if:
- the implementation approach is obvious (single clear path)
- user explicitly specified how they want it done
- it's a bug fix with clear solution

## step 2: create plan file

check `docs/plans/` for existing files, then create `docs/plans/yyyymmdd-<task-name>.md` (use current date):

### plan structure

```markdown
# [Plan Title]

## Overview
- clear description of the feature/change being implemented
- problem it solves and key benefits
- how it integrates with existing system

## Context (from discovery)
- files/components involved: [list from step 0]
- related patterns found: [patterns discovered]
- dependencies identified: [dependencies]

## Development Approach
- **testing approach**: [TDD / Regular - from user preference in planning]
- complete each task fully before moving to the next
- make small, focused changes
- **CRITICAL: every task MUST include new/updated tests** for code changes in that task
  - tests are not optional - they are a required part of the checklist
  - write unit tests for new functions/methods
  - write unit tests for modified functions/methods
  - add new test cases for new code paths
  - update existing test cases if behavior changes
  - tests cover both success and error scenarios
- **CRITICAL: all tests must pass before starting next task** - no exceptions
- **CRITICAL: update this plan file when scope changes during implementation**
- run tests after each change
- maintain backward compatibility

## Testing Strategy
- **unit tests**: required for every task (see Development Approach above)
- **e2e tests**: if project has UI-based e2e tests (Playwright, Cypress, etc.):
  - UI changes → add/update e2e tests in same task as UI code
  - backend changes supporting UI → add/update e2e tests in same task
  - treat e2e tests with same rigor as unit tests (must pass before next task)
  - store e2e tests alongside unit tests (or in designated e2e directory)
  - example: if task implements new form field, add e2e test checking form submission

## Progress Tracking
- mark completed items with `[x]` immediately when done
- add newly discovered tasks with ➕ prefix
- document issues/blockers with ⚠️ prefix
- update plan if implementation deviates from original scope
- keep plan in sync with actual work done

## Solution Overview
- high-level approach and architecture chosen
- key design decisions and rationale
- how it fits into the existing system

## Technical Details
- data structures and changes
- parameters and formats
- processing flow

## What Goes Where
- **Implementation Steps** (`[ ]` checkboxes): tasks achievable within this codebase - code changes, tests, documentation updates
- **Post-Completion** (no checkboxes): items requiring external action - manual testing, changes in consuming projects, deployment configs, third-party verifications

## Implementation Steps

<!--
Task structure guidelines:
- Each task = ONE logical unit (one function, one endpoint, one component)
- Use specific descriptive names, not generic "[Core Logic]" or "[Implementation]"
- Each task MUST have a **Files:** block listing files to Create/Modify (before checkboxes)
- Aim for ~5 checkboxes per task (more is OK if logically atomic)
- Tests are a required deliverable of every task — list them as SEPARATE checklist items (see Development Approach for the full rule)

Example (Files block + tests as separate checklist items):

### Task 1: Add password hashing utility

**Files:**
- Create: `src/auth/hash`
- Create: `src/auth/hash_test`

- [ ] create `src/auth/hash` with HashPassword and VerifyPassword functions
- [ ] implement bcrypt-based hashing with configurable cost
- [ ] write tests for HashPassword (success + error cases)
- [ ] write tests for VerifyPassword (success + error cases)
- [ ] run tests - must pass before next task
-->

### Task 1: [specific name - what this task accomplishes]

**Files:**
- Create: `exact/path/to/new_file`
- Modify: `exact/path/to/existing`

- [ ] [specific action with file reference - code implementation]
- [ ] [specific action with file reference - code implementation]
- [ ] write tests for new/changed functionality (success cases)
- [ ] write tests for error/edge cases
- [ ] run tests - must pass before next task

### Task N-1: Verify acceptance criteria
- [ ] verify all requirements from Overview are implemented
- [ ] verify edge cases are handled
- [ ] run full test suite: `<project test command>`
- [ ] run e2e tests if project has them: `<project e2e test command>`
- [ ] verify test coverage meets project standard

### Task N: [Final] Update documentation
- [ ] update README.md if needed
- [ ] update CLAUDE.md if new patterns discovered
- [ ] move this plan to `docs/plans/completed/`

## Post-Completion
*Items requiring manual intervention or external systems - no checkboxes, informational only*

**Manual verification** (if applicable):
- manual UI/UX testing scenarios
- performance testing under load
- security review considerations

**External system updates** (if applicable):
- consuming projects that need updates after this library change
- configuration changes in deployment systems
- third-party service integrations to verify
```

## step 3: next steps

after creating the file, tell user: "created plan: `docs/plans/yyyymmdd-<task-name>.md`"

then use AskUserQuestion:

```json
{
  "questions": [{
    "question": "Plan created. What's next?",
    "header": "Next step",
    "options": [
      {"label": "Interactive review", "description": "Open plan in editor for manual annotation and feedback loop"},
      {"label": "Auto review", "description": "Launch AI plan-review agent for automated analysis"},
      {"label": "Implement", "description": "Commit plan and start implementing"},
      {"label": "Done", "description": "Commit plan, no further action"}
    ],
    "multiSelect": false
  }]
}
```

- **Interactive review**: check if `revdiff` is installed (`which revdiff`).
  - **if revdiff is available**: run `${CLAUDE_PLUGIN_ROOT}/scripts/launch-plan-review.sh <plan-file-path>` via Bash.
    the script opens revdiff TUI showing the plan with syntax highlighting. user adds line-level annotations.
    on quit, annotations are output to stdout in structured format:
    ```
    ## filename:line ( )
    annotation comment text
    ```
    when annotation output is present:
    1. read each annotation — the line number and comment describe what the user wants changed
    2. revise the plan file to address each annotation
    3. run `${CLAUDE_PLUGIN_ROOT}/scripts/launch-plan-review.sh <plan-file-path>` via Bash
    4. repeat until no output (user quit without annotations)
  - **if revdiff is not available**: fall back to `${CLAUDE_PLUGIN_ROOT}/scripts/plan-annotate.py <plan-file-path>` via Bash.
    the script opens a copy of the plan in $EDITOR via terminal overlay. if the user makes annotations,
    it outputs a unified diff to stdout. when diff output is present:
    1. read the diff carefully — added lines (+) are user annotations, removed lines (-) are deletions, modified lines show requested changes
    2. revise the plan file to address each annotation
    3. run `${CLAUDE_PLUGIN_ROOT}/scripts/plan-annotate.py <plan-file-path>` via Bash
    4. repeat until no diff output (user closed editor without changes)
  when the annotation loop completes, ask again with the remaining options (minus "Interactive review")
- **Auto review**: launch plan-review agent (Task tool with subagent_type=plan-review). After review completes, ask again with the same options (minus "Auto review")
- **Implement**: commit plan with message like "docs: add <topic> implementation plan", then ask implementation mode:
  ```json
  {
    "questions": [{
      "question": "Implementation mode?",
      "header": "Mode",
      "options": [
        {"label": "Interactive", "description": "Implement task by task in this session"},
        {"label": "Autonomous", "description": "Run /planning:exec for autonomous execution with reviews"}
      ],
      "multiSelect": false
    }]
  }
  ```
  - **Interactive**: begin implementing task 1 interactively in this session. Use TodoWrite tool to track progress and mark todos completed immediately (do not batch)
  - **Autonomous**: invoke `/planning:exec <plan-file-path>` for autonomous execution with multi-phase review
- **Done**: commit plan with message like "docs: add <topic> implementation plan", stop

## execution enforcement

applies when implementing in-session (the "Implement → Interactive" path); `/planning:exec` enforces its own rules.

- per task: complete code → add/update tests → run the project test command → mark items `[x]` in the plan file. do NOT move on with failing tests or skipped tests.
- only proceed to the next task when all its items are `[x]`, tests are written, and all tests pass.
- track during work: `[x]` for done, `➕` for newly discovered tasks, `⚠️` for blockers; update the plan if scope changes.
- partial implementation: if tests cannot pass until a later task, still write them now, add a TODO comment noting the dependency, and mark `[x] write tests ... (fails until Task X)`; clear the TODO and verify once the dependency lands.
- on completion: verify all checkboxes, run the full test suite, move the plan to `docs/plans/completed/` (`mkdir -p` if needed).

this ensures each task is solid before building on top of it.

## key principles

- **batch context questions, then one at a time** - gather step 1 context inputs in a single AskUserQuestion call; for approach selection (1.5) and next steps (3), ask one question at a time
- **multiple choice preferred** - easier to answer than open-ended when possible
- **DRY, YAGNI ruthlessly** - avoid unnecessary duplication and features, keep scope minimal (but prefer duplication over premature abstraction when it reduces coupling)
- **lead with recommendation** - have an opinion, explain why, but let user decide
- **explore alternatives** - always propose 2-3 approaches before settling (unless obvious)
- **duplication vs abstraction** - when code repeats, ask user: prefer duplication (simpler, no coupling) or abstraction (DRY but adds complexity)? explain trade-offs before deciding
