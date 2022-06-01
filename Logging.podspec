Pod::Spec.new do |s|
    s.name = 'Logging'
    s.version = '1.4.0'
    s.license = { :type => 'Apache 2.0', :file => 'LICENSE.txt' }
    s.summary = 'A Logging API for Swift.'
    s.homepage = 'https://github.com/apple/swift-log'
    s.author = 'Apple Inc.'
    s.source = { :git => 'https://github.com/apple/swift-log.git', :tag => s.version.to_s }
    s.documentation_url = 'https://github.com/apple/swift-log'
    s.module_name = 'Logging'
  
    s.swift_version = '5.0'
    s.cocoapods_version = '>=1.6.0'
    s.ios.deployment_target = '12.0'
    s.osx.deployment_target = '10.14'
    s.tvos.deployment_target = '12.0'
  
    s.source_files = 'Sources/Logging/**/*.swift'
end