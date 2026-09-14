## Orientation

@ARCHITECTURE.md

Use the map above to find where things live before searching the codebase. If a task doesn't fit anywhere described there, ask or make a reasonable judgment call — don't assume the map is wrong without checking.

## Keep README.md current

Whenever you add, remove, or change a feature, CLI flag, config option, or public function/API, update README.md in the same turn — don't wait to be asked. Add new features under the Features/Usage section, update outdated examples, and bump the changelog section if one exists.

## Write tests for bug fixes and features

Whenever you fix a bug, write a regression test that reproduces the bug first (it should fail before your fix and pass after). Whenever you add a feature, write tests covering the new behavior including edge cases. Never mark a task complete without corresponding tests, unless the user explicitly says to skip them.

## Test conventions

Place tests in tests/ mirroring the src/ structure, named test_<module>.py (or your stack's equivalent — __tests__/*.test.ts, *_test.go, etc). Reuse existing fixtures/mocks where they exist rather than duplicating setup.

## Verify before finishing

After writing or modifying tests, run the test suite (or at least the affected file's tests) and confirm they pass before considering the task done. If a test fails, fix the code or the test — don't leave a broken or skipped test.

## Include these in your plan

For any task that fixes a bug, adds a feature, or changes a public API/CLI/config option, your plan must explicitly include steps for: writing/updating tests, running them, and updating README.md. Don't leave these as implicit follow-ups — list them as plan steps up front so they aren't skipped on longer or multi-part tasks.

## Keep the architecture map updated

If ARCHITECTURE.md no longer reflects the current folder structure or entry points after your changes, update it as part of the task. This keeps future tasks from needing to re-explore the codebase from scratch.