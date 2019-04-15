#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Logging API open source project
##
## Copyright (c) 2019 Apple Inc. and the Swift Logging API project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift Logging API project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftNIO open source project
##
## Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftNIO project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu

function usage() {
  echo "$0 [-u] version"
  echo
  echo "OPTIONS:"
  echo "  -u: Additionally upload the podspec"
}

upload=false
while getopts ":u" opt; do
  case $opt in
    u)
      upload=true
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))"

if [[ $# -eq 0 ]]; then
  echo "Must provide target version"
  exit 1
fi

version=$1
podspec_name="Logging"

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
tmpdir=$(mktemp -d /tmp/.build_podspecsXXXXXX)
echo "Building podspec in $tmpdir"

cat > "${tmpdir}/${podspec_name}.podspec" <<- EOF
Pod::Spec.new do |s|
  s.name = '$podspec_name'
  s.version = '$version'
  s.license = { :type => 'Apache 2.0', :file => 'LICENSE.txt' }
  s.summary = 'A Logging API for Swift.'
  s.homepage = 'https://github.com/apple/swift-log'
  s.author = 'Apple Inc.'
  s.source = { :git => 'https://github.com/apple/swift-log.git', :tag => s.version.to_s }
  s.documentation_url = 'https://apple.github.io/swift-log'
  s.module_name = 'Logging'

  s.swift_version = '5.0'
  s.cocoapods_version = '>=1.6.0'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source_files = 'Sources/Logging/**/*.swift'
end
EOF

if $upload; then
  echo "Uploading ${tmpdir}/${podspec_name}.podspec"
  pod trunk push "${tmpdir}/${podspec_name}.podspec"
else
  echo "Linting ${tmpdir}/${podspec_name}.podspec"
  pod spec lint "${tmpdir}/${podspec_name}.podspec"
fi
