# Dokku Resource

Deploys apps to a [Dokku](https://dokku.com) server.

Note: This code relatively immature.  It's based on [the Concourse Git Resource](https://github.com/concourse/git-resource),
with much of that code stripped out.  There are probably lingering bits of code that don't apply to dokku deployment,
that have not yet been cleaned up.

Test coverage is rather sparse, because Dokku deployment is very slow to test.

## Source Configuration

* `server`: *Required.* The address of the dokku server.  This may be just a hostname or IP address,
or it may also include a port, such as server.com:2222.  Default port is the default ssh port, 22.

* `branch`: *Required.* The default branch to push to.

* `private_key`: *Optional.* Private key to use when pushing.
    Example:

    ```yaml
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAtCS10/f7W7lkQaSgD/mVeaSOvSF9ql4hf/zfMwfVGgHWjj+W
      <Lots more text>
      DWiJL+OFeg9kawcUL6hQ8JeXPhlImG6RTUffma9+iGQyyBMCGd1l
      -----END RSA PRIVATE KEY-----
    ```

* `private_key_user`: *Optional.* Enables setting User in the ssh config.

* `private_key_passphrase`: *Optional.* To unlock `private_key` if it is protected by a passphrase.

* `forward_agent`: *Optional* Enables ForwardAgent SSH option when set to true. Useful when using proxy/jump hosts. Defaults to false.

* `submodule_credentials`: *Optional.* List of credentials for HTTP(s) auth when pushing private git submodules which are not stored in the same git server as the container repository.
    Example:

    ```
    submodule_credentials:
    - host: github.com
      username: git-user
      password: git-password
    - <another-configuration>
    ```

    Note that `host` is specified with no protocol extensions.

* `git_config`: *Optional.* If specified as (list of pairs `name` and `value`)
  it will configure git global options, setting each name with each value.

  This can be useful to set options like `credential.helper` or similar.

  See the [`git-config(1)` manual page](https://www.kernel.org/pub/software/scm/git/docs/git-config.html)
  for more information and documentation of existing git options.

* `https_tunnel`: *Optional.* Information about an HTTPS proxy that will be used to tunnel SSH-based git commands over.
  Has the following sub-properties:
  * `proxy_host`: *Required.* The host name or IP of the proxy server
  * `proxy_port`: *Required.* The proxy server's listening port
  * `proxy_user`: *Optional.* If the proxy requires authentication, use this username
  * `proxy_password`: *Optional.* If the proxy requires authenticate,
      use this password

### Example

Resource configuration for a dokku server with an HTTPS proxy:

``` yaml
resources:
- name: source-code
  type: git
  source:
    server: dokku.me
    branch: master
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAtCS10/f7W7lkQaSgD/mVeaSOvSF9ql4hf/zfMwfVGgHWjj+W
      <Lots more text>
      DWiJL+OFeg9kawcUL6hQ8JeXPhlImG6RTUffma9+iGQyyBMCGd1l
      -----END RSA PRIVATE KEY-----
    https_tunnel:
      proxy_host: proxy-server.mycorp.com
      proxy_port: 3128
      proxy_user: myuser
      proxy_password: myverysecurepassword
```

Resource configuration for a dokku server, with a submodule from a private git server:

``` yaml
resources:
- name: source-code
  type: git
  source:
    server: dokku.me
    branch: master
    submodule_credentials:
    - host: some.other.git.server
      username: user
      password: verysecurepassword
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAtCS10/f7W7lkQaSgD/mVeaSOvSF9ql4hf/zfMwfVGgHWjj+W
      <Lots more text>
      DWiJL+OFeg9kawcUL6hQ8JeXPhlImG6RTUffma9+iGQyyBMCGd1l
      -----END RSA PRIVATE KEY-----
```

Pushing a new version of the app:

``` yaml
- put: source-code
  params:
    app: the-app-name
    repository: the-app-repo
    environment_variables:
      FEATURE_FLAG_1: enabled
```

## Behavior

### `check`: No-op

### `in`: No-op

### `out`: Push an app to dokku

Push the checked-out reference to the source's URI and branch. All tags are
also pushed to the source. If a fast-forward for the branch is not possible
and the `rebase` parameter is not provided, the push will fail.

#### Parameters

* `repository`: *Required.* The path of the repository to deploy to Dokku.
* `app`: *Required.* The name of the app to deploy.
* `tls`: TLS certificate info.  It's recommended to provide these using secret variables.  Both must be provided.
  * `cert`: The TLS certificate
  * `key`: The TLS private key
* `branch`: *Optional.* The branch to push.
* `builder`: *Optional.* The dokku builder to use, such as "dockerfile" or "herokuish".
* `environment_variables`: *Optional.* An object whose key-value pairs will be set as environment variables for the app.

## Development

### Prerequisites

* docker is *required* - version 17.06.x is tested; earlier versions may also
  work.

### Running the tests

The tests have been embedded with the `Dockerfile`; ensuring that the testing
environment is consistent across any `docker` enabled platform. When the docker
image builds, the test are run inside the docker container, on failure they
will stop the build.

Run the tests with the following commands for both `alpine` and `ubuntu` images:

```sh
docker build -t dokku-resource --target tests -f dockerfiles/alpine/Dockerfile .
docker build -t dokku-resource --target tests -f dockerfiles/ubuntu/Dockerfile .
```

And the integration tests:

```sh
docker build -t dokku-resource --target integrationtests -f dockerfiles/alpine/Dockerfile .
docker build -t dokku-resource --target integrationtests -f dockerfiles/ubuntu/Dockerfile .
```

#### Note about the integration tests

If you want to run the integration tests, a bit more work is required. You will require
a Dokku service set up ([Vagrant recommended](https://dokku.com/docs/getting-started/install/vagrant/))
with an ssh key pair set up in the `integration-tests/ssh` directory (public key on the vagrant VM).

* `test_key`: This is the private key used to authenticate with the dokku server.
* `test_dokku_addr`: This file contains one line with the hostname (or IP address) and optionally the port
of the dokku server.  If both are specified, use the form hostname:port.

Example of setting up the key pair:
```
cd integration-tests/ssh
ssh-keygen -t ed25519 -f test_key -N ''
vagrant global-status # to find the machine id
vagrant ssh <MACHINE_ID> -c 'sudo dokku ssh-keys:add admin_test' < test_key.pub
```

### Contributing

Please make all pull requests to the `master` branch and ensure tests pass
locally.
