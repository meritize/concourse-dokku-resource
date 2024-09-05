ARG base_image=alpine:latest

FROM ${base_image} AS resource

RUN apk update && apk upgrade
RUN apk --no-cache add \
  bash \
  curl \
  git \
  git-daemon \
  gnupg \
  gzip \
  jq \
  openssl-dev \
  make \
  g++ \
  openssh \
  perl \
  tar \
  libstdc++ \
  coreutils

WORKDIR /root
RUN git clone https://github.com/proxytunnel/proxytunnel.git && \
    cd proxytunnel && \
    make -j4 && \
    install -c proxytunnel /usr/bin/proxytunnel && \
    cd .. && \
    rm -rf proxytunnel

RUN git config --global user.email "git@localhost"
RUN git config --global user.name "git"
RUN git config --global pull.rebase "false"

WORKDIR         /usr/share
RUN             rm -rf \
                    gitweb \
                    locale \
                    perl \
                    perl5

WORKDIR         /usr/lib
RUN             rm -rf \
                    perl \
                    perl5

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

FROM resource AS tests
ADD test/ /tests
RUN /tests/all.sh

FROM resource AS integrationtests
RUN apk --no-cache add squid
ADD test/ /tests/test
ADD integration-tests /tests/integration-tests
RUN /tests/integration-tests/integration.sh

FROM resource
