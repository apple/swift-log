# ``Logging/Logger``

## Topics

### Creating Loggers

- ``init(label:)``
- ``init(label:metadataProvider:)``
- ``init(label:factory:)-9uiy2``
- ``init(label:factory:)-6iktu``
- ``MetadataProvider``

### Sending trace log messages

- ``trace(_:metadata:file:function:line:)``
- ``trace(_:metadata:source:file:function:line:)``

### Sending debug log messages
- ``debug(_:metadata:file:function:line:)``
- ``debug(_:metadata:source:file:function:line:)``

### Sending info log messages
- ``info(_:metadata:file:function:line:)``
- ``info(_:metadata:source:file:function:line:)``

### Sending notice log messages
- ``notice(_:metadata:file:function:line:)``
- ``notice(_:metadata:source:file:function:line:)``

### Sending warning log messages
- ``warning(_:metadata:file:function:line:)``
- ``warning(_:metadata:source:file:function:line:)``

### Sending error log messages
- ``error(_:metadata:file:function:line:)``
- ``error(_:metadata:source:file:function:line:)``

### Sending critical log messages
- ``critical(_:metadata:file:function:line:)``
- ``critical(_:metadata:source:file:function:line:)``

### Sending general log messages

- ``log(level:_:metadata:file:function:line:)``
- ``log(level:_:metadata:source:file:function:line:)``
- ``Level``
- ``Message``
- ``Metadata``

### Adjusting logger metadata

- ``subscript(metadataKey:)``
- ``MetadataValue``

### Inspecting a logger

- ``label``
- ``logLevel``
- ``handler``
- ``metadataProvider``
