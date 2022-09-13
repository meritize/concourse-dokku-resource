#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

get_uri() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    },
    params: {
      short_ref_format: \"test-%s\"
    }
  }" | ${resource_dir}/in "$2" | tee /dev/stderr
}


it_returns_empty_version() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)

  get_uri $repo $TMPDIR/destination | jq -e "
    .version == {}
  "
}

run it_returns_empty_version
