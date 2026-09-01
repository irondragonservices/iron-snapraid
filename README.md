# irondragonservices/iron-snapraid

Hardened image for running [SnapRAID](https://www.snapraid.it).

Forked from [ironpeakservices/iron-snapraid](https://github.com/ironpeakservices/iron-snapraid).

A statically linked `snapraid` in a `scratch` image, with an unprivileged
account and nothing else — no shell, no libc, no package manager.

```sh
docker pull ghcr.io/irondragonservices/iron-snapraid:14
```

The tag tracks the SnapRAID release.

## Using it

SnapRAID needs a config file and the arrays it protects; neither can be baked
into an image.

```sh
docker run \
  -v ./snapraid.conf:/etc/snapraid.conf:ro \
  -v /mnt/disk1:/mnt/disk1 \
  -v /mnt/disk2:/mnt/disk2 \
  -v /mnt/parity:/mnt/parity \
  ghcr.io/irondragonservices/iron-snapraid:14 \
  --conf /etc/snapraid.conf --verbose sync
```

The entrypoint is `snapraid` itself, so every subcommand works as documented.
The default command is `status`, which is the safe one to run by accident.

The container runs as uid 1000, so the mounted arrays have to be readable and
writable by that uid.

## Verifying what you pulled

```sh
cosign verify ghcr.io/irondragonservices/iron-snapraid:14 \
  --certificate-identity-regexp '^https://github\.com/irondragonservices/\.github/\.github/workflows/image-(release|refresh)\.yml@refs/heads/main$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-github-workflow-repository irondragonservices/iron-snapraid
```

Be precise about the identity. The signature is produced by the shared
reusable workflow in
[irondragonservices/.github](https://github.com/irondragonservices/.github),
not by a workflow in this repository, so the certificate names *that* path.
A looser pattern such as `^https://github.com/irondragonservices/` would
accept a signature from any workflow in any repository in the organisation,
which is a much weaker claim than it looks. The
`--certificate-github-workflow-repository` flag is what ties the signature back
to this repository.

Both `image-release` and `image-refresh` sign: the nightly rebuild republishes
when the package set has actually changed, and it signs what it pushes.

## Changes from upstream

- **SnapRAID is no longer built from a git submodule.** Upstream vendored
  `amadvance/snapraid` as a submodule pinned to whatever commit was checked in
  — no tag, no release, nothing that said which version the image contained,
  and nothing Renovate could see. It builds from a pinned release tarball now,
  fetched over HTTPS and checked against a SHA-256 before anything is unpacked.
- **The default command could not have worked.** It was
  `["--conf /snapraid.conf", "--verbose"]` — a single argv element containing a
  space, which `snapraid` reads as one malformed flag — and it pointed at
  `/snapraid.conf`, which is where the *binary* lives, not a config file.
- **The binary and the user's home directory collided**, both at `/snapraid`.
- Alpine build stage 3.13 to 3.24.1, and the build actually links statically —
  upstream set `CFLAGS="-Bstatic"`, which is not a compiler flag.
- CI rebuilt as callers into
  [irondragonservices/.github](https://github.com/irondragonservices/.github).

### About the checksum

`SNAPRAID_VERSION` and `SNAPRAID_SHA256` move together. A Renovate bump that
changes only the version fails the build at the `sha256sum -c` step, naming the
expected and actual digests. That is the direction that failure should go: a
source build that silently accepts whatever is at the URL is not pinned to
anything.

Verified on build: the compiled binary reports `SnapRAID CLI v14.9`.
