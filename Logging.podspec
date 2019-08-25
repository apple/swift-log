Pod::Spec.new do |spec|
  spec.name         = "Logging"
  spec.version      = "0.0.1"
  spec.summary      = "A Logging API package for Swift 5."

  spec.description  = <<-DESC
  First things first: This is the beginning of a community-driven open-source project actively seeking contributions, be it code, documentation, or ideas. Apart from contributing to `swift-log` itself, there's another huge gap at the moment: `swift-log` is an _API package_ which tries to establish a common API the ecosystem can use. But to make logging really work for real-world workloads, we need `swift-log`-compatible _logging backends_ which then either persist the log messages in files, render them in nicer colors on the terminal, or send them over to Splunk or ELK.
  DESC

  spec.homepage     = "https://apple.github.io/swift-log/"

  spec.license      = "Apache 2.0"

  spec.author       = "Apple"
  spec.source       = { :git => "https://github.com/apple/swift-log.git", :tag => "#{spec.version}" }

  spec.swift_version = '5.0'

  spec.osx.deployment_target     = '10.9'
  spec.ios.deployment_target     = '8.0'
  spec.tvos.deployment_target    = '8.0'
  spec.watchos.deployment_target = '2.0'

  spec.source_files = "Sources/**/*.swift"
  spec.test_spec do |test_spec|
    test_spec.osx.deployment_target  = '10.9'
    test_spec.ios.deployment_target  = '8.0'
    test_spec.tvos.deployment_target = '8.0'

    test_spec.source_files = "Tests/**/*.swift"
    test_spec.exclude_files = "Tests/LinuxMain.swift"
  end
end
