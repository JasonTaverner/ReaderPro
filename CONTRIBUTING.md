# Contributing to ReaderPro

Thanks for your interest in contributing! Here's how to get started.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ReaderPro.git
   cd ReaderPro
   ```
3. Open in Xcode:
   ```bash
   open ReaderPro.xcodeproj
   ```
4. Build and run (`Cmd+R`)

## Development Workflow

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature
   ```
2. **Write tests first** (TDD) — see [README_DEV.md](README_DEV.md) for conventions
3. Implement the minimum code to pass
4. Refactor while tests stay green
5. Open a Pull Request

## Architecture Rules

These are non-negotiable:

- **Domain layer** must have zero framework imports (no Foundation, no AppKit, only Swift stdlib)
- **Application layer** depends only on Domain
- **Infrastructure** implements Domain ports — never the reverse
- **UI views** contain no business logic

## Code Style

- Follow existing naming conventions (see [README_DEV.md](README_DEV.md#coding-conventions))
- Test names: `test_method_condition_expected()`
- Use Arrange-Act-Assert pattern in tests
- Keep PRs focused — one feature or fix per PR

## What to Contribute

Great areas for contribution:

- **Translation adapters** — `TranslationPort` is defined but has no implementations yet
- **New voice models** — Additional TTS adapter integrations
- **Bug fixes** — Check [open issues](https://github.com/JasonTaverner/ReaderPro/issues)
- **Tests** — More coverage is always welcome
- **Documentation** — Typos, clarifications, examples

## Reporting Bugs

Open an issue with:
- macOS version
- Apple Silicon or Intel
- Steps to reproduce
- Expected vs actual behavior

## Questions?

Open a [Discussion](https://github.com/JasonTaverner/ReaderPro/discussions) — we're happy to help.
