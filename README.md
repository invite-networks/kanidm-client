# kanidm-client

Debian packages of the [Kanidm](https://github.com/kanidm/kanidm) Unix client, built by INVITE Networks from an unmodified upstream release and published to the [INVITE Networks apt repository](https://github.com/invite-networks/apt).

| Package | Contents |
|---|---|
| `kanidm-unixd` | `kanidm_unixd`, `kanidm_unixd_tasks`, `kanidm_ssh_authorizedkeys`, `kanidm-unix`, systemd units |
| `libpam-kanidm` | PAM module |
| `libnss-kanidm` | NSS module |

Supported on Debian 13 (trixie), amd64 only. Built and install-tested on Debian 13. Other releases are not supported, even though the apt repository serves them.

## Install

Add the INVITE Networks apt repository as described in its [README](https://github.com/invite-networks/apt#use-it), then:

```sh
sudo apt install kanidm-unixd
```

`kanidm-unixd` depends on the PAM and NSS modules of the exact same version, so all three move together. Configure the client as the [Kanidm book](https://kanidm.github.io/kanidm/stable/integrations/pam_and_nsswitch.html) describes.

## Versions

The package version is the upstream version plus an INVITE revision: `1.12.0-invite1`. The revision goes up when the packaging changes without a new upstream release.

The upstream tag, its commit, and the Rust version are pinned in [upstream.env](upstream.env). The build fails if the tag does not resolve to the pinned commit.

## Build locally

```sh
docker compose run --rm build
docker compose run --rm smoke
```

Packages land in `dist/`, built for the host's architecture.

## Release

1. Update `upstream.env` (tag, commit from `git ls-remote https://github.com/kanidm/kanidm.git refs/tags/<tag>`, the tag's `rust-version`). Open a pull request. CI builds and installs the packages on Debian 13.
2. Merge, then tag `v<upstream>-invite<N>`, for example `v1.12.0-invite1`, and push the tag.
3. The release workflow builds, smoke tests, creates the GitHub Release with `SHA256SUMS` and build provenance, and commits the packages to the apt repository's `pool/main/k/kanidm/`.

Publishing needs the `APT_DEPLOY_KEY` secret: the private half of a write deploy key on `invite-networks/apt` used only by this repository.

## License

Kanidm is licensed under the [Mozilla Public License 2.0](https://github.com/kanidm/kanidm/blob/master/LICENSE.md). The packages contain unmodified upstream code, and the matching source is the upstream tag in `upstream.env`. The build scripts in this repository are under the same license.
