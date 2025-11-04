# 003: Accepting loggers in libraries

Accept loggers through method parameters to ensure proper metadata propagation.

## Overview

Libraries should accept logger instances through method parameters rather than
storing them as instance variables. This practice ensures metadata (such as
correlation IDs) is properly propagated down the call stack, while giving
applications control over logging configuration.

### Motivation

When libraries accept loggers as method parameters, they enable automatic
propagation of contextual metadata attached to the logger instance. This is
especially important for distributed systems where correlation IDs must flow
through the entire request processing pipeline.

### Example

#### Recommended: Accept logger through method parameters

```swift
// ✅ Good: Pass the logger through method parameters.
struct RequestProcessor {
    func processRequest(_ request: HTTPRequest, logger: Logger) async throws -> HTTPResponse {
        // Add structured metadata that every log statement should contain.
        var logger = logger
        logger[metadataKey: "request.method"] = "\(request.method)"
        logger[metadataKey: "request.path"] = "\(request.path)"
        logger[metadataKey: "request.id"] = "\(request.id)"

        logger.debug("Processing request")
        
        // Pass the logger down to maintain metadata context.
        let validatedData = try validateRequest(request, logger: logger)
        let result = try await executeBusinessLogic(validatedData, logger: logger)
        
        logger.debug("Request processed successfully")
        return result
    }
    
    private func validateRequest(_ request: HTTPRequest, logger: Logger) throws -> ValidatedRequest {
        logger.debug("Validating request parameters")
        // Include validation logic that uses the same logger context.
        return ValidatedRequest(request)
    }
    
    private func executeBusinessLogic(_ data: ValidatedRequest, logger: Logger) async throws -> HTTPResponse {
        logger.debug("Executing business logic")
        
        // Further propagate the logger to other services.
        let dbResult = try await databaseService.query(data.query, logger: logger)
        
        logger.debug("Business logic completed")
        return HTTPResponse(data: dbResult)
    }
}
```

#### Alternative: Accept logger through initializer when appropriate

```swift
// ✅ Acceptable: Logger through initializer for long-lived components
final class BackgroundJobProcessor {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func run() async {
        // Execute some long running work
        logger.debug("Update about long running work")
        // Execute some more long running work
    }
}
```

#### Avoid: Libraries creating their own loggers

Libraries might create their own loggers; however, this leads to two problems.
First, users of the library can't inject their own loggers which means they have
no control in customizing the log level or log handler. Secondly, it breaks the
metadata propagation since users can't pass in a logger with already attached
metadata.

```swift
// ❌ Bad: Library creates its own logger
final class MyLibrary {
    private let logger = Logger(label: "MyLibrary")  // Loses all context
}

// ✅ Good: Library accepts logger from caller
final class MyLibrary {
    func operation(logger: Logger) {
        // Maintains caller's context and metadata
    }
}
```
