ARG base_image=ubuntu:noble

FROM ${base_image} AS resource

RUN apt update && apt upgrade -y -o Dpkg::Options::="--force-confdef"
RUN apt install -y --no-install-recommends \
    curl \
    git \
    git-lfs \
    gnupg \
    gzip \
    jq \
    openssl \
    libssl-dev \
    make \
    g++ \
    openssh-client \
    libstdc++6 \
    software-properties-common \
    net-tools

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
RUN git config --global protocol.file.allow "always"

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

WORKDIR         /usr/share
RUN             rm -rf \
                    gitweb \
                    locale \
                    perl

WORKDIR         /usr/lib
RUN             rm -rf \
                    perl

FROM resource AS tests
ADD test/ /tests
RUN /tests/all.sh

FROM resource AS integrationtests
RUN apt update && apt install -y squid
ADD test/ /tests/test
ADD integration-tests /tests/integration-tests
RUN /tests/integration-tests/integration.sh

FROM resource
