# Logging best practices

Best practices for effective logging with SwiftLog.

## Overview

This collection of best practices helps library authors and application
developers create effective, maintainable logging that works well across diverse
environments. Each practice is designed to ensure your logs are useful for
debugging while being respectful of system resources and operational
requirements.

### Who Should Use These Practices

- **Library Authors**: Creating reusable components that log appropriately.
- **Application Developers**: Implementing logging strategies in applications.

### Philosophy

Good logging strikes a balance between providing useful information and avoiding
system overhead. These practices are based on real-world experience with
production systems and emphasize:

- **Predictable behavior** across different environments.
- **Performance consciousness** to avoid impacting application speed.
- **Operational awareness** to support production debugging and monitoring.
- **Developer experience** to make debugging efficient and pleasant.

### Contributing to these practices

These best practices evolve based on community experience and are maintained by
the Swift Server Working Group ([SSWG](https://www.swift.org/sswg/)). Each
practice includes:

- **Clear motivation** explaining why the practice matters
- **Concrete examples** showing good and bad patterns
- **Alternatives considered** documenting trade-offs and rejected approaches

## Topics

- <doc:001-ChoosingLogLevels>
- <doc:002-StructuredLogging>
- <doc:003-AcceptingLoggers>
