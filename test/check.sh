#!/bin/bash

set -e

shopt -s parse_paren parse_brace parse_bracket

source $(dirname $0)/helpers.sh

it_is_a_noop() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  var config = {
    source: {
      uri: repo,
    }
  }

  json write (config) | ${resource_dir}/check | json read
  assert [_reply === []]
}

run it_is_a_noop
