# ``Logging/Logger``

## Topics

### Creating Loggers

- ``init(label:)``
- ``init(label:metadataProvider:)``
- ``init(label:factory:)-9uiy2``
- ``init(label:factory:)-6iktu``
- ``MetadataProvider``

### Task-local logger

- ``current``
- ``withLogger(_:_:)-(_,(Logger)->Result)``
- ``withLogger(mergingMetadata:_:)-(_,(Logger)->Result)``
- ``withLogger(_:_:)-(_,)``
- ``withLogger(mergingMetadata:_:)-(_,)``
- ``withLogger(logLevel:handler:metadata:_:)-(_,_,_,(Logger)->Result)``
- ``withLogger(logLevel:handler:metadata:_:)-(_,_,_,)``

### Sending trace log messages

- ``trace(_:metadata:file:function:line:)``
- ``trace(_:metadata:source:file:function:line:)``
- ``trace(_:error:metadata:source:file:function:line:)``

### Sending debug log messages

- ``debug(_:metadata:file:function:line:)``
- ``debug(_:metadata:source:file:function:line:)``
- ``debug(_:error:metadata:source:file:function:line:)``

### Sending info log messages

- ``info(_:metadata:file:function:line:)``
- ``info(_:metadata:source:file:function:line:)``
- ``info(_:error:metadata:source:file:function:line:)``

### Sending notice log messages

- ``notice(_:metadata:file:function:line:)``
- ``notice(_:metadata:source:file:function:line:)``
- ``notice(_:error:metadata:source:file:function:line:)``

### Sending warning log messages

- ``warning(_:metadata:file:function:line:)``
- ``warning(_:metadata:source:file:function:line:)``
- ``warning(_:error:metadata:source:file:function:line:)``

### Sending error log messages

- ``error(_:metadata:file:function:line:)``
- ``error(_:metadata:source:file:function:line:)``
- ``error(_:error:metadata:source:file:function:line:)``

### Sending critical log messages

- ``critical(_:metadata:file:function:line:)``
- ``critical(_:metadata:source:file:function:line:)``
- ``critical(_:error:metadata:source:file:function:line:)``

### Sending general log messages

- ``log(level:_:metadata:file:function:line:)``
- ``log(level:_:metadata:source:file:function:line:)``
- ``log(level:_:error:metadata:source:file:function:line:)``
- ``Level``
- ``Message``
- ``Metadata``

### Adjusting logger metadata

- ``subscript(metadataKey:)``
- ``MetadataValue``

### Metadata attribute types

- ``MetadataValueAttributes``

### Inspecting a logger

- ``label``
- ``logLevel``
- ``handler``
- ``metadataProvider``
