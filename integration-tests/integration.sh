#!/bin/bash

set -e

basedir="$(dirname "$0")"
. "$basedir/../test/helpers.sh"
. "$basedir/helpers.sh"

it_can_put() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2
  put_app "$(dirname "$0")/ssh/test_key" "$src" "$repo2" "$@"
}

it_can_put_with_tls_cert() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2
  put_app_with_tls_cert_tar "$(dirname "$0")/ssh/test_key" "$src" "$repo2" "$@"
}

it_can_put_through_a_tunnel() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2
  put_app_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" "$src" "$repo2" "$@"
}

it_can_put_through_a_tunnel_with_auth() {
  it_can_put_through_a_tunnel "$basedir/tunnel/auth"
}

it_cant_put_through_a_tunnel_without_auth() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  set +e
  test_auth_failure "$(put_app_with_private_key_and_tunnel_info "$(dirname "$0")/ssh/test_key" "$src" "$repo2" "$@" 2>&1)"
}


init_integration_tests $basedir
run it_can_put
run it_can_put_with_tls_cert
run_with_unauthenticated_proxy "$basedir" it_can_put_through_a_tunnel
run_with_unauthenticated_proxy "$basedir" it_can_put_through_a_tunnel_with_auth
run_with_authenticated_proxy "$basedir" it_can_put_through_a_tunnel_with_auth
run_with_authenticated_proxy "$basedir" it_cant_put_through_a_tunnel_without_auth
