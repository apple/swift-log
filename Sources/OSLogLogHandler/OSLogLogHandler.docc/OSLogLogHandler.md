# ``OSLogLogHandler``

A privacy-aware log handler that uses Apple's unified logging system (os.Logger).

## Overview

`OSLogLogHandler` integrates swift-log with Apple's unified logging system, providing native OSLog privacy support for metadata values. The handler automatically redacts private metadata in production logs while maintaining full visibility during development.

## Output Format

The handler formats log messages with metadata followed by a suffix indicating which keys contain private values:

### Production Logs

In production environments (Console.app, non-debug builds), private metadata is completely redacted:

```
Login successful action=password timestamp=2025-01-21 <private> (key user.id is marked private)
```

The `<private>` marker replaces all private metadata. The suffix tells you which keys were redacted.

### Debug Builds

In debug builds, all values are visible for troubleshooting:

```
Login successful action=password timestamp=2025-01-21 user.id=12345 (key user.id is marked private)
```

### Multiple Private Keys

When multiple keys are marked private, the suffix uses plural form:

```
User action action=login <private> (keys session.token, user.id are marked private)
```

In debug: `User action action=login session.token=secret user.id=12345 (keys session.token, user.id are marked private)`

## Usage

Create an `OSLogHandler` with your app's subsystem and category:

```swift
import Logging
import OSLogLogHandler

let handler = OSLogHandler(subsystem: "com.example.myapp", category: "authentication")
let logger = Logger(label: "auth") { _ in handler }

let userId = "12345"
logger.info("Login successful", attributedMetadata: [
    "user.id": "\(userId, privacy: .private)",
    "action": "\("password", privacy: .public)"
])
```

## Privacy Behavior

- **`.private` metadata**: Redacted as `<private>` in production logs
- **`.public` metadata**: Always visible
- **Plain metadata**: Treated as `.public` by default

The `(keys ... are marked private)` suffix makes it easy to identify which data is sensitive at a glance, even when values are redacted in production.

## Topics

### Creating a Handler

- ``OSLogHandler/init(subsystem:category:)``

### Privacy Configuration

- ``OSLogHandler/PrivacyBehavior``
