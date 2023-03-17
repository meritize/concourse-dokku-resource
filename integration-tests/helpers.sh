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

put_app_with_tls_cert_tar() {
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
      tls: {
        key: \"-----BEGIN PRIVATE KEY-----\n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\nCipyaI9zLPHg3u0JU7/T21CTwBuw4g==\n-----END PRIVATE KEY-----\",
        cert: \"-----BEGIN CERTIFICATE-----\nMIIEsDCCApgCCQD/WGKVDrJSNjANBgkqhkiG9w0BAQsFADAaMQswCQYDVQQGEwJV\nUzELMAkGA1UECAwCVFgwHhcNMjMwMzA3MjA1MTM3WhcNMjQwMzA2MjA1MTM3WjAa\nMQswCQYDVQQGEwJVUzELMAkGA1UECAwCVFgwggIiMA0GCSqGSIb3DQEBAQUAA4IC\nDwAwggIKAoICAQCyZW2UtqV6IyRWV2PiloM0xpUXl/QgC/fF+A1si2RPSjOGOqBl\nzPF01GlwCug+AH60bKDtK2MgtRUdxoFuGP2677gdWsrJYTnB60LlZtUfE0c9XS3L\ncf/9AvoCnV/XEiRC+SnZwVIlXJ0z8wbb8bAu0tsSk9fB0Rh5KzwNSxursKDeIR20\ne96Fc73a56CaxBw30HHXN2PqOqhPvrq/6wDA8YE9KkkenhNJzi90rtTZV4DPfzWE\nWt7aDzuolMl437qH5fuT7Gr8AWu1exrV+tOsBatniXvUWmeqN7bcC5tyZvk6hCfN\nslVS5vQ38KkkoQN4UO6Bi4AQo/6lx6LIl+5F26mVuSGsM/BIoALwcyqHQEV9N1HF\n09DkM61hLvT20CVbV1jhjInkR2JkiWYT1iEe5PfDFetht1b93DA60ai0usN15Pis\n1x1VZbh+80Ie5MUeZwvVZpuqBRQmf8SqCfn9S0CRpVRNS496T4EhdbvNtQUq+pQ9\n3cb/T2lyt2ru5Lm8nLFzR+VjihbkHCJhVr8GIMiGTr/9PdG5Sgb8oBm3Z446o4FM\nFQeLgRi3vKyilacrIdMjf+X2F4IS+/S48H/vme7CQGxr0/nGpSC4CTWI6RVzJotQ\nBKnNw9WtfF0ejD2VFRGUmhk/DkbxBooRZxolowqZk0Y1VaH+mNP8qrW5JwIDAQAB\nMA0GCSqGSIb3DQEBCwUAA4ICAQAw9zJQpAEdMCCdu9EPp0AGjhvU+5cebkroEkrm\nXF/8igYSeiXMQgyLaitVkaClAkz2rzHybYmFGXar/XaFepg4JRGzjmw4rEyVjz8/\nR+YwGrhv+Sp068U9ahKzBiWqXxTegYJyygjnxHgBfFFgq1z07SRErFeJVBy9Lsnj\nv+cWzDabdl61QvHn9gO+Lcy0hx5NyytvdNyzk1wMckt0LpU22EFeDa6CEua2qRN0\neWPOcKPdbtho9U0f1ViRksZxgi93A2M+OIZepuyYKcg6u2vyi/FXVqYSJnEHZHIT\nto2UlTrs0/zL0c8rbxO4qgxHgKcIuvhvdoSGYH/XLLIRxWzA2KwqSqY8+1L56MdI\nwmeLM3TTT/fiU4t9mYlFtklkPjjO7VrelIM3e9z3Q/qoujXFp7c/7/+Lxnj3Abrs\nBd+kNUZ5g4twOeDCtx4n+1hhRYXs6hzYRNVhSUboNRh3aAERfzbw1Cu5X9Y4n23W\nyGdcw1FA/lX02rBb0FFcmk0aeCQdytFGsve/mtsBk3gwRbBLUKIaDZnRSG1UJswo\n2zq1M+a3mVd/pQ3CGOEvmh9n1FIuDQ+4RXYx3U5ETDc8GgkurMGHN5kRaUoLY0dj\nnMudZkbR+6Jo6yIg4A815blqegHy3ubmjUrniCur86lNlC4tkz0OmmtHdS0nwWy/\nn1W3NQ==\n-----END CERTIFICATE-----\"
      },
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
