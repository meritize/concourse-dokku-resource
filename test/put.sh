#!/usr/bin/osh

set -e

shopt -s parse_bracket parse_func parse_brace parse_paren

export TEST_MOCK_EXT=1
source $(dirname $0)/helpers.sh

func lookup_metadata(m, name) {
  for i, el in (m) {
    if (el["name"] === name) {
      return (el["value"])
    }
  }
  return (null)
}

proc check_mocked_commands(;expected) {
  echo "Expected at least:"
  for c in (expected) {
    echo ' ' @c
  }
  < $TMPDIR/extcommand.json json read (&run_commands)
  var not_run = []
  for e in (expected) {
    var found = false
    for r in (run_commands) {
      if (e === r) {
        setvar found = true
      }
    }
    if (not found) {
      call not_run->append(e)
    }
  }

  echo "Commands run:"
  for c in (run_commands) {
    echo ' ' $[join(c, '   ')]
  }

  echo "Commands not run?:"
  for c in (not_run) {
    echo ' ' $[join(c, '   ')]
  }
  return $[1 if len(not_run) > 0 else 0]

}

it_can_put_to_url() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo)
  run-out (cfg, TMPDIR) | json read
  assert [{"ref": ref} === _reply.version]

  check_mocked_commands ([
    :|git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master|
  ])
}

it_can_put_to_url_with_environment() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  (
    cd "$repo"
    echo -n "111" > file_with_env_value
    echo -n "222" > another_file_with_env_value
  )

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo)
  call cfg->setParam('environment_variables', {
    a: 'test_a',
    b: 'test_b',
  })
  call cfg->setParam('environment_from_files', {
    c: 'file_with_env_value',
    D: 'another_file_with_env_value',
  })

  run-out (cfg, TMPDIR) | json read
  assert [{"ref": ref} === _reply.version]

  check_mocked_commands ([
    :|ssh dokku@fakeserver.dokku -p 22 config:unset --no-restart fake-app _CONCOURSE_EXISTING_VARS_|,
    :|ssh dokku@fakeserver.dokku -p 22 config:set --encoded --no-restart fake-app a=dGVzdF9h b=dGVzdF9i c=MTEx D=MjIy _CONCOURSE_EXISTING_VARS_=YSBiIGMgRA==|,
    :|git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master|,
  ])

  truncate --size 0 $TMPDIR/extcommand.log

  var cfg2 = newPutConfig(server='fakeserver.dokku', repository=repo)
  call cfg2->setParam('environment_variables', {
    a: 'test_a',
    b: 'test_b',
  })
  call cfg2->setParam('environment_from_files', {
    c: 'file_with_env_value',
    D: 'another_file_with_env_value',
  })
  run-out (cfg2, TMPDIR) | json read

  assert [{"ref": ref} === _reply.version]
}

it_can_put_to_url_and_set_app_json_path() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo)
  call cfg->setParam('app_json_path', 'somepath/app2.json')

  run-out (cfg, TMPDIR) | json read
  assert [{"ref": ref} === _reply.version]

  check_mocked_commands ([
    :|ssh dokku@fakeserver.dokku -p 22 app-json:set fake-app appjson-path somepath/app2.json|,
    :|git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master|,
  ])
}

it_can_put_to_url_and_set_dockerfile_path() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo)
  call cfg->setParam('dockerfile_path', 'unusual.dockerfile')

  run-out (cfg, TMPDIR) | json read

  assert [{"ref": ref} === _reply.version]

  check_mocked_commands ([
    :|ssh dokku@fakeserver.dokku -p 22 builder-dockerfile:set fake-app dockerfile-path unusual.dockerfile|,
    :|git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master|,
  ])
}

it_can_put_to_url_with_cert_info() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo)

  call cfg->setParam('tls', {
    key: '''-----BEGIN PRIVATE KEY-----
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\nCipyaI9zLPHg3u0JU7/T21CTwBuw4g==
-----END PRIVATE KEY-----''',
    cert: '''-----BEGIN CERTIFICATE-----
MIIEsDCCApgCCQD/WGKVDrJSNjANBgkqhkiG9w0BAQsFADAaMQswCQYDVQQGEwJV\nUzELMAkGA1UECAwCVFgwHhcNMjMwMzA3MjA1MTM3WhcNMjQwMzA2MjA1MTM3WjAa\nMQswCQYDVQQGEwJVUzELMAkGA1UECAwCVFgwggIiMA0GCSqGSIb3DQEBAQUAA4IC\nDwAwggIKAoICAQCyZW2UtqV6IyRWV2PiloM0xpUXl/QgC/fF+A1si2RPSjOGOqBl\nzPF01GlwCug+AH60bKDtK2MgtRUdxoFuGP2677gdWsrJYTnB60LlZtUfE0c9XS3L\ncf/9AvoCnV/XEiRC+SnZwVIlXJ0z8wbb8bAu0tsSk9fB0Rh5KzwNSxursKDeIR20\ne96Fc73a56CaxBw30HHXN2PqOqhPvrq/6wDA8YE9KkkenhNJzi90rtTZV4DPfzWE\nWt7aDzuolMl437qH5fuT7Gr8AWu1exrV+tOsBatniXvUWmeqN7bcC5tyZvk6hCfN\nslVS5vQ38KkkoQN4UO6Bi4AQo/6lx6LIl+5F26mVuSGsM/BIoALwcyqHQEV9N1HF\n09DkM61hLvT20CVbV1jhjInkR2JkiWYT1iEe5PfDFetht1b93DA60ai0usN15Pis\n1x1VZbh+80Ie5MUeZwvVZpuqBRQmf8SqCfn9S0CRpVRNS496T4EhdbvNtQUq+pQ9\n3cb/T2lyt2ru5Lm8nLFzR+VjihbkHCJhVr8GIMiGTr/9PdG5Sgb8oBm3Z446o4FM\nFQeLgRi3vKyilacrIdMjf+X2F4IS+/S48H/vme7CQGxr0/nGpSC4CTWI6RVzJotQ\nBKnNw9WtfF0ejD2VFRGUmhk/DkbxBooRZxolowqZk0Y1VaH+mNP8qrW5JwIDAQAB\nMA0GCSqGSIb3DQEBCwUAA4ICAQAw9zJQpAEdMCCdu9EPp0AGjhvU+5cebkroEkrm\nXF/8igYSeiXMQgyLaitVkaClAkz2rzHybYmFGXar/XaFepg4JRGzjmw4rEyVjz8/\nR+YwGrhv+Sp068U9ahKzBiWqXxTegYJyygjnxHgBfFFgq1z07SRErFeJVBy9Lsnj\nv+cWzDabdl61QvHn9gO+Lcy0hx5NyytvdNyzk1wMckt0LpU22EFeDa6CEua2qRN0\neWPOcKPdbtho9U0f1ViRksZxgi93A2M+OIZepuyYKcg6u2vyi/FXVqYSJnEHZHIT\nto2UlTrs0/zL0c8rbxO4qgxHgKcIuvhvdoSGYH/XLLIRxWzA2KwqSqY8+1L56MdI\nwmeLM3TTT/fiU4t9mYlFtklkPjjO7VrelIM3e9z3Q/qoujXFp7c/7/+Lxnj3Abrs\nBd+kNUZ5g4twOeDCtx4n+1hhRYXs6hzYRNVhSUboNRh3aAERfzbw1Cu5X9Y4n23W\nyGdcw1FA/lX02rBb0FFcmk0aeCQdytFGsve/mtsBk3gwRbBLUKIaDZnRSG1UJswo\n2zq1M+a3mVd/pQ3CGOEvmh9n1FIuDQ+4RXYx3U5ETDc8GgkurMGHN5kRaUoLY0dj\nnMudZkbR+6Jo6yIg4A815blqegHy3ubmjUrniCur86lNlC4tkz0OmmtHdS0nwWy/\nn1W3NQ==
-----END CERTIFICATE-----''',
  })

  run-out (cfg, TMPDIR) | json read
  assert [{"ref": ref} === _reply.version]

  check_mocked_commands ([
    :|git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master|,
    :|ssh dokku@fakeserver.dokku -p 22 certs:add fake-app|,
  ])
}

it_can_put_to_url_with_domains() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo)
  call cfg->setParam('domains', [
    'test.test.com',
    'nottest.test.com',
  ])

  run-out (cfg, TMPDIR) | json read
  assert [{"ref": ref} === _reply.version]

  check_mocked_commands ([
    :|git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master|,
    :|ssh dokku@fakeserver.dokku -p 22 domains:set fake-app test.test.com nottest.test.com|,
  ])
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

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo2)
  call cfg->setParam('branch', branch)
  call cfg.source->erase('branch')

  run-out (cfg, src) | json read

  assert [{"branch": branch, "ref": ref} === _reply.version]

  check_mocked_commands ([
    :|git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/branch-a|,
  ])
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

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo2)
  run-out (cfg, TMPDIR) | json read

  assert [{"ref": ref} === _reply.version]
  assert ["master" === lookup_metadata(_reply.metadata, "branch")]
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

  var cfg = newPutConfig(server=repo1, repository=repo2)

  call cfg->addGitConfig('core.pager', 'true')
  call cfg->addGitConfig('credential.helper', '!true long command with variables $@')

  run-out (cfg, src) | json read
  assert [{"ref": ref} === _reply.version]

  # switch back to master
  git -C $repo1 checkout master

  test "$(git config --global core.pager)" == 'true'
  test "$(git config --global credential.helper)" == '!true long command with variables $@'

  mv ~/.gitconfig.orig ~/.gitconfig
}

it_can_put_to_url_and_set_nginx_config() {
  local repo=$(init_repo)
  local ref=$(cd $repo; git rev-parse HEAD)

  var cfg = newPutConfig(server='fakeserver.dokku', repository=repo)
  call cfg->setParam('nginx', {"a": true, "b": "hello", "c": null})

  run-out (cfg, TMPDIR) | json read
  assert [{"ref": ref} === _reply.version]

  check_mocked_commands ([
    :|ssh dokku@fakeserver.dokku -p 22 nginx:set fake-app a true|,
    :|ssh dokku@fakeserver.dokku -p 22 nginx:set fake-app b hello|,
    :|ssh dokku@fakeserver.dokku -p 22 nginx:set fake-app c|,
    :|ssh dokku@fakeserver.dokku -p 22 proxy:build-config fake-app|,
    :|git push --force ssh://dokku@fakeserver.dokku/fake-app HEAD:refs/heads/master|,
  ])
}

run it_can_put_to_url
run it_can_put_to_url_with_environment
run it_can_put_to_url_and_set_app_json_path
run it_can_put_to_url_and_set_dockerfile_path
run it_can_put_to_url_with_cert_info
run it_can_put_to_url_with_domains
run it_can_put_to_url_with_branch
run it_returns_branch_in_metadata
run it_can_put_and_set_git_config
run it_can_put_to_url_and_set_nginx_config
