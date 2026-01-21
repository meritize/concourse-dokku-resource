
shopt --set parse_at parse_brace parse_paren parse_proc parse_func


export TMPDIR=${TMPDIR:-/tmp}

load_pubkey() {
  local private_key_path=$TMPDIR/git-resource-private-key
  local private_key_user=$(jq -r '.source.private_key_user // empty' <<< "$1")
  local forward_agent=$(jq -r '.source.forward_agent // false' <<< "$1")
  local passphrase="$(jq -r '.source.private_key_passphrase // empty' <<< "$1")"

  (jq -r '.source.private_key // empty' <<< "$1") > $private_key_path

  if [ -s $private_key_path ]; then
    chmod 0600 $private_key_path

    eval $(ssh-agent) >/dev/null 2>&1
    trap "kill $SSH_AGENT_PID" EXIT
    SSH_ASKPASS_REQUIRE=force SSH_ASKPASS=$(dirname $0)/askpass.sh GIT_SSH_PRIVATE_KEY_PASS="$passphrase" DISPLAY= ssh-add $private_key_path >/dev/null

    mkdir -p ~/.ssh
    cat > ~/.ssh/config <<EOF
StrictHostKeyChecking no
LogLevel quiet
EOF
    if [ ! -z "$private_key_user" ]; then
      cat >> ~/.ssh/config <<EOF
User $private_key_user
EOF
    fi
    if [ "$forward_agent" = "true" ]; then
      cat >> ~/.ssh/config <<EOF
ForwardAgent yes
EOF
    fi
    chmod 0600 ~/.ssh/config
  fi
}

configure_https_tunnel() {
  tunnel=$(jq -r '.source.https_tunnel // empty' <<< "$1")

  if [ ! -z "$tunnel" ]; then
    host=$(echo "$tunnel" | jq -r '.proxy_host // empty')
    port=$(echo "$tunnel" | jq -r '.proxy_port // empty')
    user=$(echo "$tunnel" | jq -r '.proxy_user // empty')
    password=$(echo "$tunnel" | jq -r '.proxy_password // empty')

    pass_file=""
    if [ ! -z "$user" ]; then
      cat > ~/.ssh/tunnel_config <<EOF
proxy_user = $user
proxy_passwd = $password
EOF
      chmod 0600 ~/.ssh/tunnel_config
      pass_file="-F ~/.ssh/tunnel_config"
    fi

    if [[ ! -z $host && ! -z $port ]]; then
      echo "ProxyCommand /usr/bin/proxytunnel $pass_file -p $host:$port -d %h:%p" >> ~/.ssh/config
    fi
  fi
}

func add_git_metadata_basic(m) {
  call m->extend([
    {'name': 'commit', 'value': $(git rev-parse HEAD)},
    {'name': 'author', 'value': $(git log -1 --format=format:%an | sort)},
    {'name': 'author_date', 'value': $(git log -1 --format=format:%ai)},
  ])
}

func add_git_metadata_committer(m) {
  var author = $(git log -1 --format=format:%an)
  var author_date = $(git log -1 --format=format:%ai)
  var committer = $(git log -1 --format=format:%cn)
  var committer_date = $(git log -1 --format=format:%ci)

  if (not (author === committer and author_date === committer_date)) {
    call m->extend([
      {'name': 'committer', 'value': committer},
      {'name': 'committer_date', 'value': committer_date},
    ])
  }
}

func add_git_metadata_branch(m) {
  var branch = $(git show-ref --heads | \
    sed -n "s/^$(git rev-parse HEAD) refs\/heads\/\(.*\)/\1/p" |  \
    jq -R  ". | select(. != \"\")" | jq -r -s "map(.) | join (\",\")")

  if (len(branch) > 0) {
    call m->extend([
      {"name": "branch", "value": branch}
    ])
  }
}

func add_git_metadata_tags(m) {
  var tags = $(git tag --points-at HEAD | \
    jq -R  ". | select(. != \"\")" | \
    jq -r -s "map(.) | join(\",\")")

  if (len(tags) > 0) {
    call m->extend([
      {"name": "tags", "value": tags}
    ])
  }
}

func add_git_metadata_message(m) {
  var message=$(git log -1 --format=format:%B | head -c 10240)

  call m->extend([
    {"name": "message", "value": message, "type": "message"}
  ])
}

func add_git_metadata_url(m) {
  var commit = $(git rev-parse HEAD)
  var origin = ""
  try {
    setvar origin = $(git remote get-url --all origin 2> /dev/null)
  }

  # This is not exhaustive for remote URL formats, but does cover the
  # most common hosting scenarios for where a commit URL exists
  if [[ ! $origin =~ ^(https?://|ssh://git@|git@)([^/]+)/(.*)$ ]]; then
    return (null)
  else  
    var host = ${BASH_REMATCH[2]}
    var repo_path = ${BASH_REMATCH[3]%.git}

    # Remap scp-style names so that "github.com:concourse" + "git-resource"
    # becomes "github.com" + "concourse/git-resource"
    if [[ ${BASH_REMATCH[1]} == "git@" && $host == *:* ]]; then
      setvar repo_path="${host#*:}/${repo_path}"
      setvar host = ${host%%:*}
    fi

    var url=""
    case (host) {
      *github* | *gitlab* | *gogs* {
        setvar url="https://${host}/${repo_path}/commit/${commit}"
      }
      *bitbucket* {
        setvar url="https://${host}/${repo_path}/commits/${commit}"
      }
    }

    if (len(url) > 0) {
      call m->extend([
        {"name": "url", "value": url}
      ])
    }
  fi
}

func git_metadata() {
  var m = []
  call add_git_metadata_basic(m)
  call add_git_metadata_committer(m)
  call add_git_metadata_branch(m)
  call add_git_metadata_url(m)
  call add_git_metadata_tags(m)
  call add_git_metadata_message(m)
  return (m)
}

configure_submodule_credentials() {
  local username
  local password
  rm -f $HOME/.netrc
  if [[ "$(jq -r '.source.submodule_credentials // ""' <<< "$1")" == "" ]]; then
    return
  fi

  for k in $(jq -r '.source.submodule_credentials | keys | .[]' <<< "$1"); do
    host=$(jq -r --argjson k "$k" '.source.submodule_credentials[$k].host // ""' <<< "$1")
    username=$(jq -r --argjson k "$k" '.source.submodule_credentials[$k].username // ""' <<< "$1")
    password=$(jq -r --argjson k "$k" '.source.submodule_credentials[$k].password // ""' <<< "$1")
    if [ "$username" != "" -a "$password" != "" -a "$host" != "" ]; then
      echo "machine $host login $username password $password" >> "${HOME}/.netrc"
    fi
  done
}
