# ``Logging/SwiftLogNoOpLogHandler``

## Topics

### Creating a Swift Log no-op log handler

- ``init()``
- ``init(_:)``

### Sending log messages

- ``log(event:)``
- ``log(level:message:metadata:source:file:function:line:)``
- ``log(level:message:metadata:file:function:line:)``

### Updating metadata

- ``subscript(metadataKey:)``

### Inspecting a log handler

- ``logLevel``
- ``metadata``
- ``metadataProvider``
