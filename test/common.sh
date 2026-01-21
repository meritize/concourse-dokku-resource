#!/bin/bash

set -e

source $(dirname $0)/helpers.sh
source /opt/resource/common.sh

shopt --set parse_bracket

func metadata_has(m, name) {
  for i, el in (m) {
    if (el["name"] === name) {
      return (true)
    }
  }
  return (false)
}

func lookup_metadata(m, name) {
  for i, el in (m) {
    if (el["name"] === name) {
      return (el["value"])
    }
  }
  return (null)
}

proc it_has_no_url_in_metadata_when_remote_is_not_configured {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    cd $repo

    assert [not metadata_has(git_metadata(), "url")]
}

proc it_has_no_url_in_metadata_when_remote_is_not_known {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")

    # set an unrecognized origin
    cd $repo
    git remote add origin git@whoknows.com:some/path/repo.git

    assert [not metadata_has(git_metadata(), "url")]
}

it_has_url_in_metadata_when_remote_is_github_scp() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com/myorg/myrepo/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin git@github.com:myorg/myrepo.git

    assert [metadata_has(git_metadata(), "url")]
    assert [expectedUrl === lookup_metadata(git_metadata(), "url")]
}

it_has_url_in_metadata_when_remote_is_github_ssh() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com/myorg/myrepo/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin ssh://git@github.com/myorg/myrepo.git

    assert [metadata_has(git_metadata(), "url")]
    assert [expectedUrl === lookup_metadata(git_metadata(), "url")]
}

it_has_url_in_metadata_when_remote_is_github_ssh_over_443() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com:443/myorg/myrepo/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin ssh://git@github.com:443/myorg/myrepo.git

    assert [metadata_has(git_metadata(), "url")]
    assert [expectedUrl === lookup_metadata(git_metadata(), "url")]
}

it_has_url_in_metadata_when_remote_is_github_https() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.com/myorg/myrepo/commit/$ref"

    # set a github origin
    cd $repo
    git remote add origin https://github.com/myorg/myrepo.git

    assert [metadata_has(git_metadata(), "url")]
    assert [expectedUrl === lookup_metadata(git_metadata(), "url")]
}

it_has_url_in_metadata_when_remote_is_likely_github_enterprise() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://github.company.com/myorg/myrepo/commit/$ref"

    # set a github enterprise origin
    cd $repo
    git remote add origin https://github.company.com/myorg/myrepo.git

    assert [metadata_has(git_metadata(), "url")]
    assert [expectedUrl === lookup_metadata(git_metadata(), "url")]
}

it_has_url_in_metadata_when_remote_is_gitlab() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://gitlab.com/myorg/mygroup/myrepo/commit/$ref"

    # set a gitlab origin with nested groups
    cd $repo
    git remote add origin https://gitlab.com/myorg/mygroup/myrepo.git

    assert [metadata_has(git_metadata(), "url")]
    assert [expectedUrl === lookup_metadata(git_metadata(), "url")]
}

it_has_url_in_metadata_when_remote_is_bitbucket() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedUrl="https://bitbucket.com/myteam/myrepo/commits/$ref"

    # set a bitbucket ssh origin
    cd $repo
    git remote add origin ssh://git@bitbucket.com/myteam/myrepo.git

    assert [metadata_has(git_metadata(), "url")]
    assert [expectedUrl === lookup_metadata(git_metadata(), "url")]
}

it_has_author_in_metadata() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedAuthor='test'

    cd $repo

    assert [metadata_has(git_metadata(), "author")]
    assert [expectedAuthor === lookup_metadata(git_metadata(), "author")]
}

it_has_committer_in_metadata_only_if_different_from_author() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")

    cd $repo

    assert ["test" === lookup_metadata(git_metadata(), "author")]
    assert [not metadata_has(git_metadata(), "committer")]

    git -c user.name='test' \
        -c user.email='test@example.com' \
      commit --amend --no-edit --author='othertest <othertest@example.com>'
    assert ["othertest" === lookup_metadata(git_metadata(), "author")]
    assert ["test" === lookup_metadata(git_metadata(), "committer")]
}

it_has_branch_in_metadata() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedBranch='master'

    cd $repo

    assert [expectedBranch === lookup_metadata(git_metadata(), "branch")]
}

it_has_multiple_equivalent_branches_in_metadata() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedBranch='master,other'

    cd $repo
    git -c user.name='test' \
        -c user.email='test@example.com' \
          checkout -b other

    assert [expectedBranch === lookup_metadata(git_metadata(), "branch")]
}


it_has_tags_in_metadata() {
    local repo=$(init_repo)
    local ref=$(make_commit $repo "")
    local expectedTag='TAG1,TAG2'

    cd $repo
    git -c user.name='test' -c user.email='test@example.com' tag TAG1
    git -c user.name='test' -c user.email='test@example.com' tag TAG2

    assert [expectedTag === lookup_metadata(git_metadata(), "tags")]
}


it_truncates_large_messages() {
    local repo=$(init_repo)
    # splitting the random message generation into 2 steps
    # works around bug https://github.com/oils-for-unix/oils/issues/2640
    local randchars=$(cat /dev/urandom | head -c 80000)
    local message=$(<<<"$randchars" tr -dc A-Za-z | head -c 20000 ; echo '')
    local ref=$(make_commit $repo $message)
    cd $repo

    assert [10240 === len(lookup_metadata(git_metadata(), "message"))]
}

run it_has_no_url_in_metadata_when_remote_is_not_configured
run it_has_no_url_in_metadata_when_remote_is_not_known

run it_has_url_in_metadata_when_remote_is_github_scp
run it_has_url_in_metadata_when_remote_is_github_ssh
run it_has_url_in_metadata_when_remote_is_github_ssh_over_443
run it_has_url_in_metadata_when_remote_is_github_https
run it_has_url_in_metadata_when_remote_is_likely_github_enterprise

run it_has_url_in_metadata_when_remote_is_gitlab
run it_has_url_in_metadata_when_remote_is_bitbucket

run it_has_author_in_metadata
run it_has_committer_in_metadata_only_if_different_from_author
run it_has_branch_in_metadata
run it_has_multiple_equivalent_branches_in_metadata
run it_has_tags_in_metadata
run it_truncates_large_messages
