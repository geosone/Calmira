# Repository Guidelines

## Project Structure & Module Organization

This repository is currently an empty project scaffold: no source, test, asset, or build files have been committed. Keep the root uncluttered as the project takes shape. Place implementation code under `src/`, automated tests under `tests/`, documentation under `docs/`, and static resources under `assets/`. Mirror source paths in the test tree where practical; for example, tests for `src/parser/reader.*` should live in `tests/parser/`.

Do not commit editor settings, generated build output, dependency caches, credentials, or local environment files. Add appropriate entries to `.gitignore` when introducing tools that produce such files.

## Build, Test, and Development Commands

No build system or package manager is configured yet. When adding one, provide a small, discoverable command surface and update this section in the same change. Prefer conventional entry points such as:

- `make build` — create production artifacts.
- `make test` — run the complete automated test suite.
- `make lint` — run formatting and static checks.
- `make run` — start the project locally.

Commands documented here must work from the repository root and should fail with a nonzero status when checks fail.

## Coding Style & Naming Conventions

Follow the formatter and linter standard for the language introduced; commit their configuration so results are reproducible. Until language-specific rules exist, use spaces rather than tabs, UTF-8 text, and LF line endings. Choose descriptive names: `snake_case` for files and functions where the language permits it, `PascalCase` for types, and `UPPER_SNAKE_CASE` for constants. Keep modules focused and avoid unrelated cleanup in feature changes.

## Testing Guidelines

Add tests with every behavior change or bug fix. Name tests after the behavior they verify, such as `test_rejects_empty_input`. Keep tests deterministic and independent of network access or developer-specific paths. Document any required fixtures in `tests/README.md`.

## Commit & Pull Request Guidelines

There is no accessible Git history from which to infer an established convention. Use short, imperative commit subjects (for example, `Add parser error handling`) and keep each commit logically focused. Pull requests should explain the purpose, summarize key changes, list verification commands and results, and link relevant issues. Include screenshots or sample output for user-visible changes, and call out configuration changes or follow-up work explicitly.
