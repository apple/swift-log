ARG ubuntu_version=18.04
FROM ubuntu:$ubuntu_version
# needed to do again after FROM due to docker limitation
ARG ubuntu_version

ARG DEBIAN_FRONTEND=noninteractive
# do not start services during installation as this will fail and log a warning / error.
RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# basic dependencies
RUN apt-get update && apt-get install -y wget git build-essential software-properties-common pkg-config locales
RUN apt-get update && apt-get install -y libicu-dev libblocksruntime0 curl libcurl4-openssl-dev libz-dev

# local
RUN locale-gen en_US.UTF-8
RUN locale-gen en_US en_US.UTF-8
RUN dpkg-reconfigure locales
RUN echo 'export LANG=en_US.UTF-8' >> $HOME/.profile
RUN echo 'export LANGUAGE=en_US:en' >> $HOME/.profile
RUN echo 'export LC_ALL=en_US.UTF-8' >> $HOME/.profile

# known_hosts
RUN mkdir -p $HOME/.ssh
RUN touch $HOME/.ssh/known_hosts
RUN ssh-keyscan github.com 2> /dev/null >> $HOME/.ssh/known_hosts

# clang
RUN apt-get update && apt-get install -y clang-3.9
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-3.9 100
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-3.9 100

# ruby and jazzy for docs generation
#ARG skip_ruby_from_ppa
#RUN [ -n "$skip_ruby_from_ppa" ] || apt-add-repository -y ppa:brightbox/ruby-ng
#RUN [ -n "$skip_ruby_from_ppa" ] || { apt-get update && apt-get install -y ruby2.4 ruby2.4-dev; }
#RUN [ -z "$skip_ruby_from_ppa" ] || { apt-get update && apt-get install -y ruby ruby-dev; }
#RUN apt-get update && apt-get install -y libsqlite3-dev
RUN apt-get update && apt-get install -y ruby ruby-dev libsqlite3-dev
RUN gem install jazzy --no-ri --no-rdoc

# swift
ARG swift_version=4.2.3
ARG swift_flavour=RELEASE
ARG swift_builds_suffix=release

RUN mkdir $HOME/.swift
RUN wget -q "https://swift.org/builds/swift-${swift_version}-${swift_builds_suffix}/ubuntu$(echo $ubuntu_version | sed 's/\.//g')/swift-${swift_version}-${swift_flavour}/swift-${swift_version}-${swift_flavour}-ubuntu${ubuntu_version}.tar.gz" -O $HOME/swift.tar.gz
RUN tar xzf $HOME/swift.tar.gz --directory $HOME/.swift --strip-components=1
RUN echo 'export PATH="$HOME/.swift/usr/bin:$PATH"' >> $HOME/.profile
RUN echo 'export LINUX_SOURCEKIT_LIB_PATH="$HOME/.swift/usr/lib"' >> $HOME/.profile

# script to allow mapping framepointers on linux
RUN mkdir -p $HOME/.scripts
RUN wget -q https://raw.githubusercontent.com/apple/swift/master/utils/symbolicate-linux-fatal -O $HOME/.scripts/symbolicate-linux-fatal
RUN chmod 755 $HOME/.scripts/symbolicate-linux-fatal
RUN echo 'export PATH="$HOME/.scripts:$PATH"' >> $HOME/.profile
