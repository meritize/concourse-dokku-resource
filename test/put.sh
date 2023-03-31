#!/bin/bash

set -e

export TEST_MOCK_EXT=1
source $(dirname $0)/helpers.sh

check_mocked_commands() {
  cat <&0 > $TMPDIR/expected_output

  echo "Expected at least:"
  < $TMPDIR/expected_output awk '{ print "  " $0 }' >&2

  echo "Commands run:"
  < $TMPDIR/extcommand.log awk '{ print "  " $0 }' >&2

  echo "Commands not run?:"
  ! grep -Fxv -f $TMPDIR/extcommand.log $TMPDIR/expected_output

}


it_can_put_to_url() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  put_uri fakeserver.dokku $TMPDIR $repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  cat <<EOF | check_mocked_commands
ssh dokku@fakeserver.dokku -p 22 config:clear --no-restart fake-app
ssh dokku@fakeserver.dokku -p 22 config:set --encoded --no-restart fake-app
git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master
EOF
}

it_can_put_to_url_and_set_app_json_path() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  put_uri_with_app_json fakeserver.dokku $TMPDIR $repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  cat <<EOF | check_mocked_commands
ssh dokku@fakeserver.dokku -p 22 config:clear --no-restart fake-app
ssh dokku@fakeserver.dokku -p 22 config:set --encoded --no-restart fake-app
ssh dokku@fakeserver.dokku -p 22 app-json:set fake-app appjson-path somepath/app2.json
git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master
EOF
}

it_can_put_to_url_with_cert_info() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  put_uri_with_cert_info fakeserver.dokku $TMPDIR $repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  cat <<EOF | check_mocked_commands
ssh dokku@fakeserver.dokku -p 22 config:clear --no-restart fake-app
ssh dokku@fakeserver.dokku -p 22 config:set --encoded --no-restart fake-app
git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master
ssh dokku@fakeserver.dokku -p 22 certs:add fake-app
EOF
}

it_can_put_to_url_with_branch() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local branch="branch-a"
  local ref=$(make_commit_to_branch $repo2 $branch)

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri_with_branch fakeserver.dokku $src repo $branch | jq -e "
    .version == {branch: $(echo $branch | jq -R .), ref: $(echo $ref | jq -R .)}
  "

  cat <<EOF | check_mocked_commands
ssh dokku@fakeserver.dokku -p 22 config:clear --no-restart fake-app
ssh dokku@fakeserver.dokku -p 22 config:set --encoded --no-restart fake-app
git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/branch-a
EOF
}

it_returns_branch_in_metadata() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  # create a tag to push
  git -C $repo2 tag some-tag

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  put_uri fakeserver.dokku $src repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
    and
	(.metadata | .[] | select(.name == \"branch\") | .value == $(echo master | jq -R .))
  "
}

it_can_put_and_set_git_config() {
  local repo1=$(init_repo)

  local src=$(mktemp -d $TMPDIR/put-src.XXXXXX)
  local repo2=$src/repo
  git clone $repo1 $repo2

  local ref=$(make_commit $repo2)

  # create a tag to push
  git -C $repo2 tag some-tag

  # cannot push to repo while it's checked out to a branch
  git -C $repo1 checkout refs/heads/master

  cp ~/.gitconfig ~/.gitconfig.orig

  put_uri_with_config $repo1 $src repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  # switch back to master
  git -C $repo1 checkout master

  test "$(git config --global core.pager)" == 'true'
  test "$(git config --global credential.helper)" == '!true long command with variables $@'

  mv ~/.gitconfig.orig ~/.gitconfig
}

run it_can_put_to_url
run it_can_put_to_url_and_set_app_json_path
run it_can_put_to_url_with_cert_info
run it_can_put_to_url_with_branch
run it_returns_branch_in_metadata
run it_can_put_and_set_git_config
