# SLG-0001: In memory log handler

An in-memory handler to aid testing.

## Overview

- Proposal: SLG-0001
- Author(s): [Hamzah Malik](https://github.com/hamzahrmalik)
- Status: **Awaiting Review**
- Issue: [apple/swift-log#1](https://github.com/apple/swift-log/pull/390)
- Implementation:
    - [apple/swift-log#1](https://github.com/apple/swift-log/pull/390)
- Related links:
    - [Lightweight proposals process description](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/Proposals.md)

### Introduction

Add an InMemoryLogHandler

### Motivation

Library maintainers should be able to test that their libraries log what they expect

### Proposed solution

Create a new InMemoryLogging product, which contains an InMemoryLogHandler

This log handler can be used to make a logger, pass the logger into some function, and then assert that logs were emitted.

### Detailed design

Implementation is in https://github.com/apple/swift-log/pull/390

### API stability

This is purely additive. A new product is created, with a new type within it.

### Future directions

We could in future add convenience functions. For example

- a function to assert that a particular log message was logged
- a static function to create a logger with this handler

### Alternatives considered

- Creating something specifically geared towards testing. For example, providing functions to do assertions on the logs with features such as wildcarding and predicates. However, this would complicate
  the API, and it is preferable to create the minimal feature first, and then iterate on it. Furthermore, this log handler can be useful beyond testing, for example, for buffering before actually logging.
