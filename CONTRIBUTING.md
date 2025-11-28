## Legal

By submitting a pull request, you represent that you have the right to license
your contribution to Apple and the community, and agree by submitting the patch
that your contributions are licensed under the Apache 2.0 license (see
`LICENSE.txt`).

## How to submit a bug report

Please ensure to specify the following:

* SwiftLog commit hash
* Contextual information (e.g. what you were trying to achieve with SwiftLog)
* Simplest possible steps to reproduce
  * More complex the steps are, lower the priority will be.
  * A pull request with failing test case is preferred, but it's just fine to paste the test case into the issue description.
* Anything that might be relevant in your opinion, such as:
  * Swift version or the output of `swift --version`
  * OS version and the output of `uname -a`
  * Network configuration

### Example

```
SwiftLog commit hash: 4fe877816ad82627602377f415b6a66850214824

Context:
While testing my application that uses with SwiftLog, I noticed that ...

Steps to reproduce:
1. ...
2. ...
3. ...
4. ...

$ swift --version
Swift version 4.0.2 (swift-4.0.2-RELEASE)
Target: x86_64-unknown-linux-gnu

Operating system: Ubuntu Linux 16.04 64-bit

$ uname -a
Linux beefy.machine 4.4.0-101-generic #124-Ubuntu SMP Fri Nov 10 18:29:59 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux

My system has IPv6 disabled.
```

## Writing a Patch

For non-trivial changes that affect the public API, it is good practice to have a discussion phase before writing code. Please follow the [proposal process](Sources/Logging/Docs.docc/Proposals/Proposals.md) to gather feedback and align on the approach with other contributors.

A good SwiftLog patch is:

1. Concise, and contains as few changes as needed to achieve the end result.
2. Tested, ensuring that any tests provided failed before the patch and pass after it.
3. Documented, adding API documentation as needed to cover new functions and properties.
4. Accompanied by a great commit message, using our commit message template.

### Commit Message Template

We require that your commit messages match our template. The easiest way to do that is to get git to help you by explicitly using the template. To do that, `cd` to the root of our repository and run:

    git config commit.template dev/git.commit.template

### Make sure Tests work on Linux

SwiftLog uses Swift Testing to run tests on all supported platforms.

### Run CI checks locally

You can run the Github Actions workflows locally using
[act](https://github.com/nektos/act). To run all the jobs that run on a pull
request, use the following command:

```
% act pull_request
```

To run just a single job, use `workflow_call -j <job>`, and specify the inputs
the job expects. For example, to run just shellcheck:

```
% act workflow_call -j soundness --input shell_check_enabled=true
```

To bind-mount the working directory to the container, rather than a copy, use
`--bind`. For example, to run just the formatting, and have the results
reflected in your working directory:

```
% act --bind workflow_call -j soundness --input format_check_enabled=true
```

If you'd like `act` to always run with certain flags, these can be be placed in
an `.actrc` file either in the current working directory or your home
directory, for example:

```
--container-architecture=linux/amd64
--remote-name upstream
--action-offline-mode
```

## Benchmarks

Benchmarks for `swift-log` are in a separate Swift Package in the `Benchmarks` subfolder of this repository.
They use the [`package-benchmark`](https://github.com/ordo-one/package-benchmark) plugin.
Benchmarks depends on the [`jemalloc`](https://jemalloc.net) memory allocation library, which is used by `package-benchmark` to capture memory allocation statistics.
An installation guide can be found in the [Getting Started article](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark/gettingstarted#Installing-Prerequisites-and-Platform-Support) of `package-benchmark`.
Afterwards you can run the benchmarks from CLI by going to the `Benchmarks` subfolder (e.g. `cd Benchmarks`) and invoking:
```
swift package benchmark
```

For more information please refer to `swift package benchmark --help` or the [documentation of `package-benchmark`](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark).


## How to contribute your work

Please open a pull request at https://github.com/apple/swift-log. Make sure the CI passes, and then wait for code review.
