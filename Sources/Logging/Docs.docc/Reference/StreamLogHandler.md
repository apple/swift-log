# ``Logging/StreamLogHandler``

## Topics

### Creating a stream log handler

- ``standardOutput(label:)``
- ``standardOutput(label:metadataProvider:)``
- ``standardError(label:)``
- ``standardError(label:metadataProvider:)``

### Sending log messages

- ``log(event:)``
- ``log(level:message:metadata:source:file:function:line:)``

### Updating metadata

- ``subscript(metadataKey:)``

### Inspecting a log handler

- ``logLevel``
- ``metadata``
- ``metadataProvider``
