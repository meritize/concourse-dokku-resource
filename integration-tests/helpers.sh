#!/bin/bash

set -e -u
set -o pipefail

init_integration_tests() {
  local test_dir=$1

  if [[ ! -f "$test_dir/ssh/test_key" || ! -f "$test_dir/ssh/test_dokku_addr" ]]; then
    echo "$test_dir/ssh/test_key and $test_dir/ssh/test_dokku_addr must BOTH exist. Skipping integration tests." 1>&2
    exit 0
  fi

  cp $test_dir/tunnel/squid-noauth.conf /etc/squid/squid.conf
  squid
  sleep 2

  export INTG_DOKKU_ADDR=$(cat $test_dir/ssh/test_dokku_addr)
}

put_app() {
  local -r pkey=$1
  local -r source=$2
  local -r repository=$3
  local -r auth=${4:-""}
  jq -n "{
    source: {
      server: $(echo $INTG_DOKKU_ADDR | jq -R .),
      private_key: $(cat $1| jq -s -R .),
      branch: \"master\"
    },
    params: {
      app: \"concourse-resource-integration-test\",
      repository: $(echo $3 | jq -R .),
      builder: \"herokuish\",
      environment_variables: {
        \"a\": \"test_a\",
        \"b\": \"test_b\"
      }
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_app_with_private_key_and_tunnel_info() {
  local -r pkey=$1
  local -r source=$2
  local -r repository=$3
  local -r auth=${4:-""}
  jq -n "{
    source: {
      server: $(echo $INTG_DOKKU_ADDR | jq -R .),
      private_key: $(cat $1| jq -s -R .),
      branch: \"master\",
      https_tunnel: {
        proxy_host: \"localhost\",
        proxy_port: 3128
        $(add_proxy_auth "$auth")
      }
    },
    params: {
      app: \"concourse-resource-integration-test\",
      repository: $(echo $3 | jq -R .),
      builder: \"herokuish\",
      environment_variables: {
        \"a\": \"test_a\",
        \"b\": \"test_b\"
      }
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_private_key_and_tunnel_info() {
  auth=${4:-""}
  jq -n "{
    source: {
      uri: $(echo $INTG_REPO | jq -R .),
      private_key: $(cat $1| jq -s -R .),
      branch: $(echo $INTG_BRANCH | jq -R .),
      https_tunnel: {
        proxy_host: \"localhost\",
        proxy_port: 3128
        $(add_proxy_auth "$auth")
      }
    },
    params: {
      repository: $(echo $3 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

add_proxy_auth() {
  local file=$1

  [[ -f "$file" ]] || exit 0

  user=$(cat $file | cut -d : -f1)
  pass=$(cat $file | cut -d : -f2)

  echo ", proxy_user: \"$user\", proxy_password: \"$pass\""
}

test_auth_failure() {
  local output=$1
  echo "$output"

  set -e

  ( echo "$output" | grep 'HTTP return code: 407 Proxy Authentication Required' >/dev/null 2>&1 )
  rc=$?

  test "$rc" -eq "0"
}

run_with_unauthenticated_proxy() {
  local basedir=$1
  shift

  cp $basedir/tunnel/squid-noauth.conf /etc/squid/squid.conf

  __run "without" "$@"
}

run_with_authenticated_proxy() {
  local basedir=$1
  shift

  cp $basedir/tunnel/squid-auth.conf /etc/squid/squid.conf

  __run "with" "$@"
}

__run() {
  export TMPDIR=$(mktemp -d ${TMPDIR_ROOT}/git-tests.XXXXXX)
  authtype=$1
  shift

  echo -e 'running \e[33m'"$1"$'\e[0m'" $authtype authentication enabled ..."
  echo 'Reconfiguring proxy...'

  squid -k reconfigure

  set +e
  attempts=10
  while (( attempts )); do
    ( netstat -an | grep LISTEN | grep 3128 )
    rc=$?

    if [[ $rc == 0 ]]; then
      break
    else
      echo "Waiting for proxy to finish reconfiguring..."
      (( attempts-- ))
      sleep 1
    fi
  done

  if [[ $attempts == 0 ]]; then
    echo "Timed out waiting for proxy to reconfigure!" 1>&2
    exit 1
  fi
  set -e


  eval "$@" 2>&1 | sed -e 's/^/  /g'
  echo ""
}
