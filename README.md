# SSWG Logger Proposal

This is SSWG proposal about a logger API that intends to support a number programming models:

- explicit logger passing (see `ExplicitLoggerPassingExample.swift`)
- one global logger (see `OneGlobalLoggerExample.swift`)
- one logger per sub-system (see `LoggerPerSubsystem.swift`)

The file `RandomExample.swift` contains demoes of some other things that you may want to do.

## Feedback Wishes

Feedback that would really be great is:

- if anything, what does this proposal *not cover* that you will definitely need
- if anything, what could we remove from this and still be happy?
- API-wise: what do you like, what don't you like?

Feel free to post this as message on the SSWG forum and/or github issues in this repo.

## Open Questions

Very many. But here a couple that come to my mind:

- currently attaching metadata to a logger is done through `subscript(metadataKey metadataKey: String) -> String? { get set }`
  clearly setting and deleting extra metadata is necessary. But reading it is really not. Should we make it `addContext(key: String, value: String)` and `removeContext(key:String)` instead?  
- should the logging metadata values be `String`?
- should this library include an [MDC](https://logback.qos.ch/manual/mdc.html) API? should it be a seperate module? or a seperate library? [SLF4J](https://www.slf4j.org/manual.html#mdc) which is the moral equivilant of this API in the JVM ecosystem does include one
