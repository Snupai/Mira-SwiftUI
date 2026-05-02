# Contributing to Mira

Thanks for your interest in contributing to Mira! 🎉

## Getting Started

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9+

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/Snupai/Mira-SwiftUI.git
   cd Mira-SwiftUI
   ```

2. Build with Swift Package Manager:
   ```bash
   swift build
   ```

3. Or open in Xcode:
   ```bash
   open Package.swift
   ```

4. Create the app bundle (for running):
   ```bash
   ./bundle.sh
   open Mira.app
   ```

## Development Workflow

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

### Commit Messages

We use conventional-ish commit messages:

- `feat: add new feature`
- `fix: resolve bug`
- `docs: update readme`
- `refactor: restructure code`
- `style: format code`
- `chore: update dependencies`

### Releasing

Releases are automated via GitHub Actions. To trigger a release:

1. Update your changes
2. Commit with message containing `[release X.Y.Z]`:
   ```bash
   git commit -m "[release 0.3.0] Add awesome new feature"
   ```
3. Push to `main`

The CI will:
- Build the app
- Sign with Developer ID
- Notarize with Apple
- Create DMG and PKG
- Publish GitHub release
- Update Sparkle appcast

## Project Structure

```
Mira/
├── Sources/Mira/
│   ├── App/              # App entry point
│   ├── Models/           # Data models
│   │   └── SwiftData/    # SwiftData models
│   ├── Views/            # SwiftUI views
│   │   ├── Dashboard/
│   │   ├── Invoices/
│   │   ├── Clients/
│   │   ├── Settings/
│   │   └── Onboarding/
│   └── Services/         # Business logic
├── Resources/            # Assets, fonts
└── Tests/               # Unit tests
```

## Code Style

- Use SwiftUI and SwiftData patterns
- Follow Apple's Swift API Design Guidelines
- Keep views small and composable
- Use `@Query` for SwiftData fetches
- Handle errors gracefully — log via `Log.<area>` (see `Sources/Mira/Utils/Log.swift`) instead of `print()`

### Tooling

Install the toolchain locally (one-time):

```bash
brew install swiftlint swiftformat
```

Then before committing:

```bash
swiftformat .
swiftlint
```

Both run as warnings — they won't block your build, but they're enforced in CI.

### Pre-commit hook (optional)

To run `swiftformat --lint` and `swiftlint` automatically on staged files:

```bash
ln -s ../../installer/git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Testing

Run tests with:

```bash
swift test
```

Tests live in `Tests/MiraTests/`. Highest-payoff areas (where bugs are silent and
expensive) are covered first: migration, encryption, PDF generation, invoice math.

## Questions?

- Open a [Discussion](https://github.com/Snupai/Mira-SwiftUI/discussions)
- Check existing [Issues](https://github.com/Snupai/Mira-SwiftUI/issues)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
