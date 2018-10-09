# swift-server-logger-api

This is *pre-pitch stage* SSWG proposal about a logger API that intends to support a number programming models:

- explicit logger passing (see `ExplicitLoggerPassingExample.swift`)
- one global logger (see `OneGlobalLoggerExample.swift`)
- one logger per sub-system (see `LoggerPerSubsystem.swift`)

The file `RandomExample.swift` contains demoes of some other things that you may want to do.

## Feedback Wishes

This is really only a first pass and I will speak to the OSLog folks again to maybe get towards an API that's at least very similar between client & server.

Feedback that would really be great is:
- if anything, what does this proposal *not cover* that you will definitely need
- if anything, what could we remove from this and still be happy?
- API-wise: what do you like, what don't you like?

Feel free to post this as message on the SSWG forum and/or github issues in this repo.

## Open Questions

Very many. But here a couple that come to my mind:

- currently attaching context to a logger is done through `subscript(diagnosticKey diagnosticKey: String) -> String? { get set }`
  clearly setting and deleting extra context is necessary. But reading it is really not. Should we make it `addContext(key: String, value: String)` and `removeContext(key:String)` instead?
- should the logging context values be `String`?
- should we remove the possible customisation around log level evaluation and stick that in the API? If yes, the `_log` function would need to unconditionally log if called because the `level > self.logLevel` has already been done.
