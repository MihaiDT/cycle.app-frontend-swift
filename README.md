# CycleApp iOS

Modern iOS application built with SwiftUI and The Composable Architecture (TCA).

## Requirements

- Xcode 16.0+
- iOS 17.0+
- Swift 6.0
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

1. Install XcodeGen if you haven't already:

```bash
brew install xcodegen
```

2. Generate the Xcode project:

```bash
xcodegen generate
```

3. Open the project:

```bash
open CycleApp.xcodeproj
```

## Architecture

This project uses **The Composable Architecture (TCA)** by Point-Free for state management.

### Project Structure

```
CycleApp/
├── CycleApp/                 # Main app target
│   ├── App/                  # App entry point
│   └── Resources/            # Assets, Info.plist
├── Packages/
│   ├── Core/                 # Core framework
│   │   ├── Models/           # Data models
│   │   ├── Networking/       # API client
│   │   ├── Persistence/      # SwiftData
│   │   └── Utilities/        # Extensions, helpers
│   └── Features/             # Features framework
│       ├── App/              # Root feature
│       ├── Authentication/   # Auth feature
│       └── Home/             # Home feature
└── CycleAppTests/            # Unit tests
```

### Key Dependencies

- [ComposableArchitecture](https://github.com/pointfreeco/swift-composable-architecture) - State management
- [Dependencies](https://github.com/pointfreeco/swift-dependencies) - Dependency injection
- [Tagged](https://github.com/pointfreeco/swift-tagged) - Type-safe identifiers

## Development

### Code Style

This project uses:

- **SwiftLint** for linting
- **swift-format** for formatting

### Running Tests

```bash
cmd+U in Xcode
# or
xcodebuild test -scheme CycleApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

## License

Copyright © 2026 Cycle. All rights reserved.
