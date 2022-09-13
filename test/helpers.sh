#!/bin/bash

set -e -u

set -o pipefail

export TMPDIR_ROOT=$(mktemp -d /tmp/git-tests.XXXXXX)
trap "rm -rf $TMPDIR_ROOT" EXIT

if [ -d /opt/resource ]; then
  resource_dir=/opt/resource
else
  resource_dir=$(cd $(dirname $0)/../assets && pwd)
fi
test_dir=$(cd $(dirname $0) && pwd)
keygrip=276D99F5B65388AF85DF54B16B08EF0A44C617AC
fingerprint=A3E20CD6371D49E244B0730D1CDD25AEB0F5F8EF

run() {
  export TMPDIR=$(mktemp -d ${TMPDIR_ROOT}/git-tests.XXXXXX)

  echo -e 'running \e[33m'"$@"$'\e[0m...'
  eval "$@" 2>&1 | sed -e 's/^/  /g'
  echo ""
}

init_repo() {
  (
    set -e

    cd $(mktemp -d $TMPDIR/repo.XXXXXX)

    git init -q

    touch requirements.txt
    echo "web:python3 -m http.server" > Procfile
    git add requirements.txt Procfile

    # start with an initial commit
    git \
      -c user.name='test' \
      -c user.email='test@example.com' \
      commit -q -m "init"

    # print resulting repo
    pwd
  )
}

init_repo_with_submodule() {
  local submodule=$(init_repo)
  make_commit $submodule >/dev/null
  make_commit $submodule >/dev/null

  local project=$(init_repo)
  git -C $project submodule add "file://$submodule" >/dev/null
  git -C $project commit -m "Adding Submodule" >/dev/null
  echo $project,$submodule
}

init_repo_with_named_submodule() {
  local name=$1
  local path=$2

  local submodule=$(init_repo)
  make_commit $submodule >/dev/null
  make_commit $submodule >/dev/null

  local project=$(init_repo)
  git -C $project submodule add --name $1 "file://$submodule" $2 >/dev/null
  git -C $project commit -m "Adding Submodule" >/dev/null
  echo $project,$submodule
}

make_commit_to_file_on_branch() {
  local repo=$1
  local file=$2
  local branch=$3
  local msg=${4-}

  # ensure branch exists
  if ! git -C $repo rev-parse --verify $branch >/dev/null; then
    git -C $repo branch $branch master
  fi

  # switch to branch
  git -C $repo checkout -q $branch

  # modify file and commit
  echo x >> $repo/$file
  git -C $repo add $file

  if [ "$file" = "future-file" ]; then
    # if future-file, create a commit with date in the future
    # Usefull to veryfy if git rev-list return the real latest commit
    GIT_COMMITTER_DATE="$(date -R -d '1 year')" git -C $repo \
        -c user.name='test' \
        -c user.email='test@example.com' \
        commit -q -m "commit $(wc -l $repo/$file) $msg" \
        --date "$(date -R -d '1 year')"
  else
    git -C $repo \
      -c user.name='test' \
      -c user.email='test@example.com' \
      commit -q -m "commit $(wc -l $repo/$file) $msg"
  fi

  # output resulting sha
  git -C $repo rev-parse HEAD
}

make_commit_to_file_on_branch_with_path() {
  local repo=$1
  local path=$2
  local file=$3
  local branch=$4
  local msg=${5-}

  # ensure branch exists
  if ! git -C $repo rev-parse --verify $branch >/dev/null; then
    git -C $repo branch $branch master
  fi

  # switch to branch
  git -C $repo checkout -q $branch

  # modify file and commit
  mkdir -p $repo/$path
  echo x >> $repo/$path/$file
  git -C $repo add $path/$file
  git -C $repo \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -q -m "commit $(wc -l $repo/$path/$file) $msg"

  # output resulting sha
  git -C $repo rev-parse HEAD
}

make_commit_to_file() {
  make_commit_to_file_on_branch $1 $2 master "${3-}"
}

make_commit_to_branch() {
  make_commit_to_file_on_branch $1 some-file $2
}

make_commit() {
  make_commit_to_file $1 some-file "${2:-}"
}

make_commit_to_future() {
  make_commit_to_file $1 future-file "${2:-}"
}

make_commit_to_be_skipped() {
  make_commit_to_file $1 some-file "[ci skip]"
}

make_commit_to_be_skipped2() {
  make_commit_to_file $1 some-file "[skip ci]"
}

check_uri() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .)
    }
  }" | ${resource_dir}/check | tee /dev/stderr
}

put_uri() {
  jq -n "{
    source: {
      server: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      app: \"fake-app\",
      repository: $(echo $3 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_branch() {
  jq -n "{
    source: {
      server: $(echo $1 | jq -R .)
    },
    params: {
      app: \"fake-app\",
      repository: $(echo $3 | jq -R .),
      branch: $(echo $4 | jq -R .),
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_config() {
  jq -n "{
    source: {
      server: $(echo $1 | jq -R .),
      branch: \"master\",
      git_config: [
        {
          name: \"core.pager\",
          value: \"true\"
        },
        {
          name: \"credential.helper\",
          value: \"!true long command with variables \$@\"
        }
      ]
    },
    params: {
      repository: $(echo $3 | jq -R .),
      app: \"fake-app\"
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}
