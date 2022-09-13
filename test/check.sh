#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

it_is_a_noop() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  check_uri $repo | jq -e "
    . == []
  "
}

run it_is_a_noop
