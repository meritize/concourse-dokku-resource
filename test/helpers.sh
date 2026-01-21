#!/usr/bin/osh

set -e -u

set -o pipefail

shopt -s parse_func parse_proc parse_paren parse_brace

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

func setServer(self, server) {
  setvar self.source.server = server
}

func setBranch(self, branch) {
  setvar self.source.branch = branch
}

func setRepository(self, repo) {
  setvar self.params.repository = repo
}

func setApp(self, app) {
  setvar self.params.app = app
}

func setParam(self, key, value) {
  setvar self.params[key] = value
}

func setSourceField(self, key, value) {
  setvar self.source[key] = value
}

func addGitConfig(self, name, value) {
  if (get(self.source, 'git_config') === null) {
    setvar self.source.git_config = []
  }
  call self.source.git_config->append({
    'name': name,
    'value': value,
  })
}

func putBuilderAsJson(self) {
  return (toJson(first(self)))
}

var PutBuilder = Object(null, {
  'M/setServer': setServer,
  'M/setBranch': setBranch,
  'M/setRepository': setRepository,
  'M/setApp': setApp,
  'M/setParam': setParam,
  'M/setSourceField': setSourceField,
  'M/addGitConfig': addGitConfig,
  asJson: putBuilderAsJson,
})

func newPutConfig(; server=null, repository=null) {
  var obj = Object(PutBuilder, {
    source: {
      branch: 'master',
      server: server,
    },
    params: {
      app: 'fake-app',
      repository: repository,
    },
  })
  return (obj)
}

proc run-out(;config, directory) {
  ${resource_dir}/out $directory <<<$[config.asJson()] | tee /dev/stderr
}


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
