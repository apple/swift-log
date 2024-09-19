# Security

This document specifies the security process for the SwiftLog project.

## Disclosures

### Private Disclosure Process

The SwiftLog maintainers ask that known and suspected vulnerabilities be
privately and responsibly disclosed by emailing
[sswg-security-reports@forums.swift.org](mailto:sswg-security-reports@forums.swift.org)
with the all the required detail.
**Do not file a public issue.**

#### When to report a vulnerability

* You think you have discovered a potential security vulnerability in SwiftLog.
* You are unsure how a vulnerability affects SwiftLog.

#### What happens next?

* A member of the team will acknowledge receipt of the report within 3
  working days (United States). This may include a request for additional
  information about reproducing the vulnerability.
* We will privately inform the Swift Server Work Group ([SSWG][sswg]) of the
  vulnerability within 10 days of the report as per their [security
  guidelines][sswg-security].
* Once we have identified a fix we may ask you to validate it. We aim to do this
  within 30 days. In some cases this may not be possible, for example when the
  vulnerability exists at the protocol level and the industry must coordinate on
  the disclosure process.
* If a CVE number is required, one will be requested from [MITRE][mitre]
  providing you with full credit for the discovery.
* We will decide on a planned release date and let you know when it is.
* Prior to release, we will inform major dependents that a security-related
  patch is impending.
* Once the fix has been released we will publish a security advisory on GitHub
  and in the Server → Security Updates category on the [Swift forums][swift-forums-sec].

[sswg]: https://github.com/swift-server/sswg
[sswg-security]: https://www.swift.org/sswg/security/
[swift-forums-sec]: https://forums.swift.org/c/server/security-updates/
[mitre]: https://cveform.mitre.org/
