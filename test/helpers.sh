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

put_uri_with_cert_info() {
  jq -n "{
    source: {
      server: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      app: \"fake-app\",
      tls: {
        key: \"-----BEGIN PRIVATE KEY-----\nMIIJQgIBADANBgkqhkiG9w0BAQEFAASCCSwwggkoAgEAAoICAQCyZW2UtqV6IyRW\nV2PiloM0xpUXl/QgC/fF+A1si2RPSjOGOqBlzPF01GlwCug+AH60bKDtK2MgtRUd\nxoFuGP2677gdWsrJYTnB60LlZtUfE0c9XS3Lcf/9AvoCnV/XEiRC+SnZwVIlXJ0z\n8wbb8bAu0tsSk9fB0Rh5KzwNSxursKDeIR20e96Fc73a56CaxBw30HHXN2PqOqhP\nvrq/6wDA8YE9KkkenhNJzi90rtTZV4DPfzWEWt7aDzuolMl437qH5fuT7Gr8AWu1\nexrV+tOsBatniXvUWmeqN7bcC5tyZvk6hCfNslVS5vQ38KkkoQN4UO6Bi4AQo/6l\nx6LIl+5F26mVuSGsM/BIoALwcyqHQEV9N1HF09DkM61hLvT20CVbV1jhjInkR2Jk\niWYT1iEe5PfDFetht1b93DA60ai0usN15Pis1x1VZbh+80Ie5MUeZwvVZpuqBRQm\nf8SqCfn9S0CRpVRNS496T4EhdbvNtQUq+pQ93cb/T2lyt2ru5Lm8nLFzR+Vjihbk\nHCJhVr8GIMiGTr/9PdG5Sgb8oBm3Z446o4FMFQeLgRi3vKyilacrIdMjf+X2F4IS\n+/S48H/vme7CQGxr0/nGpSC4CTWI6RVzJotQBKnNw9WtfF0ejD2VFRGUmhk/Dkbx\nBooRZxolowqZk0Y1VaH+mNP8qrW5JwIDAQABAoICAA+1hMfCqaGutIVx3pbWYClm\njzxrohCsXR4usKftQmEFDLJ2OSedu2lpRvuZykejbYTfx+/6kRkRORHNKBqU0ssC\nTvkuxIqlKBveZp6ixoOdA/nwWZb/q+YQvAk86HKc41qObFQDhQNLO4CWlvUJPFVz\nNd1V7XrgucH5v6kAAyjEPfYxflclTTv9LCu5l9fpCv8TOOMVupOmpKmZBwLdY8yZ\nt6K2NYgfrV0jbeRdfNrCrNIYxpKoGdWj38IBkBg3w0oyQ0wMVoNocJ6jf4J2Out7\n+FL+tUvGxjgj/dM0pnSVgr7XYlXnrUHGmpzOcWaLUy3mGoqHyTgt6L+aa8g0MMQK\nZ6lELhd/YrNTlqoyTvhHCjC0KL3tHqs2nvfmZs+Kad6wvbJUO9pLQzwDswft7ix5\nhEz9vAaL0oDAR3MuJvV++7iDvq43fpcIdFfN9Owk/XtN1CVOivZP2G81ulHYYhLa\ndYJSEfPGpHPm1eBl8i52QY2dqC9ozWYvZBzs8+4J27UOhY1N0K0RQE3hhwcI3CNu\nLMSvlavPO3kcUWPtuW0A9cOiv+3h3wU3ZHHw8p9TFdGNLG/q4SYX4+w+/GbZvvHg\nKst3uLkyZib1acE3d+lY95UZMm+l0Mj+vTGjWYBdPkZSqGVD3G4E8cPiGXj54iUa\nJeWu3esUb2+tKvhPL3EhAoIBAQDWpc3XfZrgKP3a9YUl7AnUzXxL62cl0XmLf4wz\ndG5P5ER9ZMDKfT1MVgcH0IEAQmnS/K+fDIQKdOEK36RMiEeA3xHiPWqSHH6TZj4w\nvYGLD0Gz3Zm24eY2d00SeiUZF2AlogMMYOXp++P5ZumdslWNkyGjy+X4fd5MLkEy\nu4tvnMj4ypw9SPMMKNEk4N4Y/0XI+Xd+skcGBmr2dlVDGHbVhbN4ZP/HAuCcjaWx\nfiFIlQ/JqCDJXEqkDTxQg7/JWgvtahvE848Qeu+xTYn9Kr0lBHLEFKkZ361dH+M2\nf6f01bX7ldOJXLExb8y3C3AbM9KKkX289qDALYsTYrdzeQoRAoIBAQDUw71raATX\nS9oJ8YbC96pxypzfcoVHXgVqSgWKOFzL9UYcm/AN2iXBciiWhSHxDtHUPfKuUcoe\nkzctTtZqanqJYAsjMbN3wmbPr/k9GJgeryaW50vCKtgh4xzYtPUNGgI4Ge5jh5J4\n8aZtFzD525VSyMPzeFDBGLuo8inL+kSjCWSR6LX6J46G1G2lBFwqT9GhIGt260Vq\nWgpVDRJl8yhr8Ef6M3hc4hAlz7l79qTj+ecLbRpBBqHeGLKFQ2DyuVBC9OWJ+CJQ\ndIhHDnX9FlZwlaJaDkfMeQBC8qKL/dvJjFq7rNHHEY19viFu4rPHWPNmDutGEhml\ntkaw7kFCyBe3AoIBAQC1Efd8AjxFPq8vJ5CjteNxPcrN7I397CChWf52ZZCtGn3g\nXb740f+Exsl1gSFhi6Tj1D9+Zzt36rLwzko2OXxALW1TscWV7i2kwEpUKXj/SuZ9\nCcIi8ZuXdLpyjNGAwiRcerghmBg7cz8UZAlM+2SKYoStPVMJdXyyPQ7I8kak59jt\nb1WvqTtGlaQgfQU+hxFigXeZTGD3pzBSKu6wBBIy+2+zb1gJlNbPmfodqa4AIabI\n0WifFJjunS+1J/8Ap1KKe8ljMqcMGvjaU/PEumoGsSLzYA5qgjMn7L9qePPBaQr0\naaaiKKxdbNd/zklK2UORmzw7zL08gO7icpMY+RFRAoIBAENDiqvdG8Kw8UK5f+A9\nij4lTwj5XJdeaxnaQvwaq4OzjDHZPsAyWkNZAunrNvrNs5qE5ycjJmIaKpSBWxoT\nhZ/OpFbBDLrs07IPMR2Wm+j/eJS2lOXSw7ea5HDCbMJymYcA87O1laH0y6ercEld\nmUytuf1L6UPSvOlBfeNFwNNGUewrBPUL8mw/1lYYFccuqthktnTHFo/z3VZcJpfi\nksHlGexIv2Gl+nLpw/sj06dbRyb+nBE4to3PgwjMb2btHSm94J+Iudhzru2/7Z9Q\no40+UTBlWV+UVXfU23ykigqi+8Bfd4aWzwOUy18R/sIkJfb6+niRmlggUyL2f91M\nAusCggEAMlm09W0KHhPXcAhtahIPz2H/4hsegu0NmuYKW8UF370pTT9D9LmLtCEy\nkdMsxSjvx/nVpgagNhXhU327BpoGraMc9xchB+AMkf3sMTfCl+aoXti+Ro05yXNM\nBzqLGWVNly25opSVXHPlRA5G/ssphDSGZ5o6QTaWidwjd2vnLCuHxTG0IbxH3aeG\nClsnUw15ukzJ2VuiVbbE+9MWfmg/4m3e20fwbbQx0h4lRfK0K/VJPtLhIAuUEng5\nfnP1EOAJzcVShS6o0YKuONBMPEUTXYdlD+4GggOly9kvAo7AGCDAvdu7u2tjYWq+\nCipyaI9zLPHg3u0JU7/T21CTwBuw4g==\n-----END PRIVATE KEY-----\",
        cert: \"-----BEGIN CERTIFICATE-----\nMIIEsDCCApgCCQD/WGKVDrJSNjANBgkqhkiG9w0BAQsFADAaMQswCQYDVQQGEwJV\nUzELMAkGA1UECAwCVFgwHhcNMjMwMzA3MjA1MTM3WhcNMjQwMzA2MjA1MTM3WjAa\nMQswCQYDVQQGEwJVUzELMAkGA1UECAwCVFgwggIiMA0GCSqGSIb3DQEBAQUAA4IC\nDwAwggIKAoICAQCyZW2UtqV6IyRWV2PiloM0xpUXl/QgC/fF+A1si2RPSjOGOqBl\nzPF01GlwCug+AH60bKDtK2MgtRUdxoFuGP2677gdWsrJYTnB60LlZtUfE0c9XS3L\ncf/9AvoCnV/XEiRC+SnZwVIlXJ0z8wbb8bAu0tsSk9fB0Rh5KzwNSxursKDeIR20\ne96Fc73a56CaxBw30HHXN2PqOqhPvrq/6wDA8YE9KkkenhNJzi90rtTZV4DPfzWE\nWt7aDzuolMl437qH5fuT7Gr8AWu1exrV+tOsBatniXvUWmeqN7bcC5tyZvk6hCfN\nslVS5vQ38KkkoQN4UO6Bi4AQo/6lx6LIl+5F26mVuSGsM/BIoALwcyqHQEV9N1HF\n09DkM61hLvT20CVbV1jhjInkR2JkiWYT1iEe5PfDFetht1b93DA60ai0usN15Pis\n1x1VZbh+80Ie5MUeZwvVZpuqBRQmf8SqCfn9S0CRpVRNS496T4EhdbvNtQUq+pQ9\n3cb/T2lyt2ru5Lm8nLFzR+VjihbkHCJhVr8GIMiGTr/9PdG5Sgb8oBm3Z446o4FM\nFQeLgRi3vKyilacrIdMjf+X2F4IS+/S48H/vme7CQGxr0/nGpSC4CTWI6RVzJotQ\nBKnNw9WtfF0ejD2VFRGUmhk/DkbxBooRZxolowqZk0Y1VaH+mNP8qrW5JwIDAQAB\nMA0GCSqGSIb3DQEBCwUAA4ICAQAw9zJQpAEdMCCdu9EPp0AGjhvU+5cebkroEkrm\nXF/8igYSeiXMQgyLaitVkaClAkz2rzHybYmFGXar/XaFepg4JRGzjmw4rEyVjz8/\nR+YwGrhv+Sp068U9ahKzBiWqXxTegYJyygjnxHgBfFFgq1z07SRErFeJVBy9Lsnj\nv+cWzDabdl61QvHn9gO+Lcy0hx5NyytvdNyzk1wMckt0LpU22EFeDa6CEua2qRN0\neWPOcKPdbtho9U0f1ViRksZxgi93A2M+OIZepuyYKcg6u2vyi/FXVqYSJnEHZHIT\nto2UlTrs0/zL0c8rbxO4qgxHgKcIuvhvdoSGYH/XLLIRxWzA2KwqSqY8+1L56MdI\nwmeLM3TTT/fiU4t9mYlFtklkPjjO7VrelIM3e9z3Q/qoujXFp7c/7/+Lxnj3Abrs\nBd+kNUZ5g4twOeDCtx4n+1hhRYXs6hzYRNVhSUboNRh3aAERfzbw1Cu5X9Y4n23W\nyGdcw1FA/lX02rBb0FFcmk0aeCQdytFGsve/mtsBk3gwRbBLUKIaDZnRSG1UJswo\n2zq1M+a3mVd/pQ3CGOEvmh9n1FIuDQ+4RXYx3U5ETDc8GgkurMGHN5kRaUoLY0dj\nnMudZkbR+6Jo6yIg4A815blqegHy3ubmjUrniCur86lNlC4tkz0OmmtHdS0nwWy/\nn1W3NQ==\n-----END CERTIFICATE-----\"
      },
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
