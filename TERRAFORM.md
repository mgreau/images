# Chainguard Images-as-Code

This file describes the broad strokes of the Terraform layout we use for
defining Chainguard "Images-as-Code" using Terraform.  There are roughly three
layers to this structure:
1. The top-level "mega module" (largely defined in `main.tf`),
2. The per-image modules (defined in `images/{foo}/*.tf`), and
3. The per-image test modules (defined in `images/{foo}/tests/main.tf`).

## Goals (`tl;dr`)

One of the goals of this work has been to structure things so that folks can
pretty quickly and easily iterate on one of the above scopes by entering the
appropriate directory and running the following to execute things locally:

```shell
terraform init
terraform apply
```

This is half true, since we need to define some variables, which may vary from
image to image, but thus far we've managed to keep things **extremely** regular
(more on this below).


## A quick note on state (or lack thereof)

One of the most fundamental aspects of Terraform (and one of its most
fundamental stumbling blocks) is state.  The way we use "state" in our terraform
is a lot like a build system cache: if it is present then we can do things
incrementally, but we should always be able to do a "clean" build.

We don't plan to rely on terraform state at this time, and plan to see how long
we can get away with really only doing "clean" builds in our CI/CD, but this
will be a bit exploratory.


## Invoking modules

Let's walk through each of the above layers.

### Building ALL Images

We define a "mega module" in the root of the repository, which can be used to
build ALL of our images in one go.  This module exposes a single variable:
`target_repository`, which can be defined using `TF_VAR_target_repository=...`.

For example, I can build everything with:
```shell
# Upgrade is useful in case there's prior state, or
# run "git clean -fxd" first.
terraform init -upgrade

# This should have the form:
#   ghcr.io/mattmoor
# Individual image names will be appended to the above (e.g ko, crane, ...)
# Bear in mind the visibility of the repository you are publishing to!
TF_VAR_target_repository=... terraform apply
```

### Building a single Image module

Every image defines a module in `images/{foo}` that can be used to build, sign,
attest, test, and tag all of its variants.  Generally these modules expose a
single input variable: `target_repository`, but because we define important
`provider` settings at our top-level we invoke this slightly differently.
Instead of invoking these modules directly, we invoke them as the `-target` of
a "mega module" apply.

For example, I can build just the "ko" image module with:

```shell
TF_VAR_target_repository=... terraform apply -target=module.ko
```

This flag may be supplied multiple times to build multiple image directories,
for example ko, crane and consul:

```shell
TF_VAR_target_repository=... terraform apply \
    -target=module.ko \
    -target=module.crane \
    -target=module.consul
```

### Building for certain architectures

By default all Wolfi-based images are built for `x86_64` (`amd64`) and `aarch64` (`arm64`),
and Alpine-based images are built for all architectures supported by Alpine.

During testing it can be useful to only build for certain architectures, such as the host architecture.

To achieve this, set the `archs` variable, for example `-var='archs=["x86_64"]'` or `TF_VAR_archs='["x86_64"]'`.

See [Assigning Values to Root Module Variables](https://developer.hashicorp.com/terraform/language/values/variables#assigning-values-to-root-module-variables).

The `[]`s are important here; omitting them results in an error saying `Variables may not be used here.`

### Building from local packages

During testing it can be useful to build images from packages you've built and signed locally.

To achieve this, set the `extra_repositories` and `extra_keyring` variables.

During testing it can be useful to only build for certain architectures, such as the host architecture, for example:

```
terraform apply \
    -var='extra_repositories=["/path/to/packages"]' \
    -var='extra_keyring=["/path/to/local-signing.rsa.pub"]'
```

See [Assigning Values to Root Module Variables](https://developer.hashicorp.com/terraform/language/values/variables#assigning-values-to-root-module-variables).

The `[]`s are important here; omitting them results in an error saying `Variables may not be used here.`

### Running Tests

Every image defines a module in `images/{foo}/tests` that can be used to run the
tests for a particular image.  Generally these modules expose a single input
variable: `digest`, which can be defined using `TF_VAR_digest=...`.

For example, I can run the tests for a ko image with:
```shell
cd images/ko/tests

# Upgrade is useful in case there's prior state, or
# run "git clean -fxd" first.
terraform init -upgrade

# This should have the form:
#   ghcr.io/mattmoor/ko@sha256:deadbeef
# Yes, it currently requires a digest.
TF_VAR_digest=... terraform apply
```

Virtually all tests require Docker installed locally to run.

Many tests require access to a Kubernetes cluster, such as a local [KinD cluster](https://kind.sigs.k8s.io/).
These tests may install a Helm chart and/or issue `kubectl` commands against the cluster.
The tests use the config file at `$HOME/.kube/config` to connect to the cluster.

### Building with `apko` directly

Images in this repo are designed to be built with Terraform as described above, but they can also be built directly with `apko`:

To build a Wolfi-based image:

```shell
make cfg=images/static/configs/wolfi.apko.yaml apko-build
```

To build an Alpine-based image (i.e., `static:latest`, `busybox:latest`, `git:latest`)

```shell
make cfg=images/static/configs/alpine.apko.yaml apko-build-alpine
```

These will build the image into a tarball in the local directory, which can be loaded into Docker with `docker load < image.tar`.
