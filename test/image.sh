#!/bin/bash

set -e

. "$(dirname "$0")/helpers.sh"

it_has_installed_proxytunnel() {
  test -x /usr/bin/proxytunnel
}

it_cleans_up_installation_artifacts() {
  test ! -d /root/proxytunnel
}

run it_has_installed_proxytunnel
run it_cleans_up_installation_artifacts
