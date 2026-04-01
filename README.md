# OCI Object Storage Explorer for macOS

OCI Object Storage Explorer is a native macOS desktop app built with Swift and SwiftUI for browsing Oracle Cloud Infrastructure Object Storage. It helps you connect to OCI, list buckets, inspect objects, manage uploads and downloads, and work with Pre-Authenticated Requests from a macOS-native interface.

This repository is useful if you are searching for:

- OCI Object Storage macOS app
- Oracle Cloud Object Storage browser
- SwiftUI macOS file explorer for OCI
- native Oracle Cloud desktop client for macOS
- macOS bucket and object browser built with Swift

## Quick Links

- Repository: [GitHub repository](https://github.com/psartori76/OCI-Object-Storage-Explorer)
- Website: [Project website](https://psartori76.github.io/OCI-Object-Storage-Explorer/)
- Latest release: [Download latest release](https://github.com/psartori76/OCI-Object-Storage-Explorer/releases/latest)
- License: [PolyForm Noncommercial 1.0.0](LICENSE)

## Why This Project Exists

OCI Object Storage is powerful, but many workflows still happen in browser consoles or generic API tooling. This project focuses on a native macOS experience for Oracle Cloud users who want a cleaner desktop workflow for browsing buckets, checking metadata, transferring files, and generating secure shared links.

## Highlights

- Native macOS UI built with `NavigationSplitView`, toolbar, sheets, inspector, and light/dark mode support
- SwiftUI app architecture with clear separation between UI, view models, services, and shared core utilities
- Real OCI Object Storage integration through signed REST requests
- Secure secret storage in the macOS Keychain
- Multilingual UI support with Portuguese (Brazil), English, and Spanish
- Locale-aware formatting for dates, times, counts, and byte sizes
- Release packaging into a macOS `.app` bundle
- Source-available licensing for noncommercial use under PolyForm Noncommercial 1.0.0

## Features

### OCI authentication

- Saved profiles with create, edit, duplicate, and remove flows
- API Key as the primary authentication method
- Namespace auto-detection
- Connection testing
- Secure Keychain persistence
- Region loading from tenancy subscriptions

### Bucket and object browsing

- Bucket list in the sidebar
- Bucket creation and deletion
- Bucket details and inspector
- Prefix navigation with breadcrumb
- Local incremental search
- Object and folder browsing
- Context actions for common operations
- Object versions viewer

### Transfers

- Multi-file upload via native file picker
- Multi-object download to a local folder
- Conflict resolution for downloads
- Progress tracking
- Cancellation and retry
- Dedicated transfer queue view

### Pre-Authenticated Requests

- Create Pre-Authenticated Requests
- List PARs for the current bucket
- Remove PARs
- Copy generated URLs

### Diagnostics

- In-memory logging
- Diagnostics screen with close action
- Sensitive-data redaction in logs

## License and Usage

This repository is source-available under [PolyForm Noncommercial 1.0.0](LICENSE).

- Noncommercial use is permitted under the license terms
- Commercial use is not granted by this repository license
- If you want to evaluate commercial use, redistribution in a commercial product, or another commercial arrangement, contact the author for separate permission

Important positioning:

- This project is source-available
- It is not presented as OSI-approved open source

## Localization

The app currently ships with:

- Portuguese (Brazil)
- English
- Spanish

The UI follows the macOS system language automatically. GitHub-facing documentation, changelog entries, and release notes are now maintained in English by default.

## Architecture

### Modules

- `OCIExplorerApp`
  - SwiftUI presentation layer
  - Views, view models, app shell, and native interaction utilities
- `OCIExplorerCore`
  - Typed models, shared errors, formatting, localization, validation, and logging
- `OCIExplorerServices`
  - OCI integration, request signing, HTTP client, profile persistence, Keychain handling, and transfer orchestration

### Stack

- UI: SwiftUI
- Architecture: MVVM
- Concurrency: `async/await`
- Dependency injection: lightweight container in `AppContainer`
- Persistence: JSON for profiles and Keychain for secrets
- OCI integration: signed REST API with RSA SHA-256

## Project Structure

```text
Sources/
  OCIExplorerApp/
    App/
    Components/
    Features/
      Authentication/
      Diagnostics/
      Explorer/
      PAR/
      Transfers/
    Utilities/
  OCIExplorerCore/
    Errors/
    Logging/
    Models/
    Resources/
    Utilities/
  OCIExplorerServices/
    Authentication/
    Networking/
    ObjectStorage/
    Transfers/

Tests/
  OCIExplorerAppTests/
  OCIExplorerServicesTests/
```

## Key Technical Decisions

### 1. Signed OCI REST integration

The app uses a dedicated REST layer instead of depending on a heavy external SDK:

- `OCIRequestSigner`
- `OCIHTTPClient`
- `OCIObjectStorageService`

Benefits:

- Fine-grained control over authentication and signed headers
- Fewer external dependencies
- Better predictability for OCI-specific product evolution

### 2. Secure profile handling

Saved profiles only persist non-sensitive metadata:

- profile name
- tenancy OCID
- user OCID
- fingerprint
- region
- namespace
- default compartment
- private key path hint

Sensitive values stay in the macOS Keychain:

- private PEM key
- passphrase

### 3. Virtual folder navigation

OCI Object Storage is flat. The app creates a folder-like UX based on:

- `prefix`
- `delimiter=/`

This enables breadcrumbs, virtual folders, and a more familiar browsing experience.

### 4. Central transfer queue

Uploads and downloads run through `TransferCoordinator` with:

- per-item progress
- cancellation
- retry
- queued, running, completed, and failed states

### 5. Native localization architecture

The app uses Apple-native localization resources with a centralized helper:

- Base localization: `pt-BR`
- Additional locales: `en`, `es`
- Shared strings in `Localizable.strings`
- Pluralization in `Localizable.stringsdict`
- Locale-aware formatting for dates, times, and byte counts

## Requirements

- macOS 13 or later
- Xcode with Swift 6.3 support
- Swift 6.3
- OCI permissions and policies appropriate for Object Storage access

## Open in Xcode

Because the project is organized as an executable Swift Package with SwiftUI:

1. Run `./scripts/xcode_doctor.sh` to validate your environment.
2. If your terminal still points to Command Line Tools, run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
3. Open the package with `./scripts/open_in_xcode.sh`.
4. Wait for indexing to finish.
5. In Xcode, select the executable product `OCIObjectStorageExplorer`.
6. Run the app.

### Important note

If `xcodebuild` or `xed` fails with a message similar to:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

that indicates your system is still using Command Line Tools instead of `Xcode.app` as the active developer directory.

## Build

### From Xcode

Build the app using the executable scheme.

### From the terminal

```bash
swift build
```

If your local environment is pointing to an incompatible developer directory or SDK, switch the active Xcode path first.

## Run

```bash
swift run OCIObjectStorageExplorer
```

## Package the `.app`

Generate a release build and package the macOS app bundle with:

```bash
swift build -c release
./scripts/package_app.sh
```

Expected output:

```text
dist/OCI Object Storage Explorer.app
```

You can drag the generated `.app` into `Applications`.

## OCI Authentication Setup

1. Generate or reuse an OCI API key associated with your OCI user.
2. Upload the public key to the OCI user.
3. Provide the app with:
   - Tenancy OCID
   - User OCID
   - Fingerprint
   - Region
   - Namespace, if you want to set it manually
4. Import the private PEM file in the app.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history and product improvements.
