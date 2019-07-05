# ShellSuite

[![Travis (.com) branch](https://img.shields.io/travis/com/nemchik/ShellSuite/master.svg?logo=travis)](https://travis-ci.com/nemchik/ShellSuite) [![GitHub](https://img.shields.io/github/license/nemchik/ShellSuite.svg)](https://github.com/nemchik/ShellSuite/blob/master/LICENSE.md)

This is a collection of shell script validation tools designed to run on git repositories. The intention of this project is to be run by CI/CD such as [Travis CI](https://travis-ci.com/) and others, but you can also run it locally/manually.

## Purpose

These tools are available for direct use in many CI/CD environments and locally, but ShellSuite aims to solve a few common problems.

> Issue: Not all environments have all of the tools.
>
> Our Resolution: ShellSuite uses Docker to run the tools so they can be used in any environment with Docker installed.

<!-- -->

> Issue: Multiple devs on a project may not keep their local validation tools up to date.
>
> Our Resolution: Running ShellSuite on a repository will keep the version of the tools used consistent.

<!-- -->

> Issue: CI/CD environment does not have an up to date version of a tool.
>
> Our Resolution: ShellSuite offers the latest officially released version of all validation tools whenever possible. When an official release is not available the best available 3rd party option is used. Devs of validation tools will be contacted to request official releases as necessary.

<!-- -->

> Issue: The validation tools update too often! New rules are added that break things!
>
> Our Resolution: You may specify a version to be used with each tool as long as they have a tag for that version on their Docker image. Devs of validation tools will be contacted to request version tags as necessary.

<!-- -->

> Issue: After cloning a git repository that needs to be validated, other shell scripts are sometimes added to the repository folder and ignored by `.gitignore` and do not need to be validated.
>
> Our Resolution: ShellSuite only scans shell files that are a part of the git repo using `git ls-tree`.

<!-- -->

## Script Arguments

The following arguments are required:

`-p` or `--path` must be defined first and should be the full path to the git repo being tested. `${PWD}` can be used when the current directory is the root of the git repo.

`-v` or `--validator` accepts [bashate](https://github.com/openstack-dev/bashate), [shellcheck](https://github.com/koalaman/shellcheck), or [shfmt](https://github.com/mvdan/sh).

`-f` or `--flags` must start with a blank space and will be passed to the validator for testing. This allows you to ignore certain validation rules if needed.

---

The following argument is optional:

`-t` or `--tag` can be defined to use a specific version of a particular validator. Ex: `v0.6.0` with shellcheck or `v2.6.2` with shfmt. If this argument is not specified `latest` will be used.

## Example useage

All examples show the use of all 3 validators, but you may choose to use only one or two if you'd like.

### Use in `.travis.yml`

Examples are shown with recommended defaults for `--flags`, but you may adjust to your liking.

Running from this repo:

```yaml
script:
  - curl -fsSL https://raw.githubusercontent.com/nemchik/ShellSuite/master/shellsuite.sh -o shellsuite-${TRAVIS_COMMIT}.sh && bash shellsuite-${TRAVIS_COMMIT}.sh -p "${PWD}" -v "bashate" -f " -i E006"
  - curl -fsSL https://raw.githubusercontent.com/nemchik/ShellSuite/master/shellsuite.sh -o shellsuite-${TRAVIS_COMMIT}.sh && bash shellsuite-${TRAVIS_COMMIT}.sh -p "${PWD}" -v "shellcheck" -f " -x"
  - curl -fsSL https://raw.githubusercontent.com/nemchik/ShellSuite/master/shellsuite.sh -o shellsuite-${TRAVIS_COMMIT}.sh && bash shellsuite-${TRAVIS_COMMIT}.sh -p "${PWD}" -v "shfmt" -f " -s -i 4 -ci -sr -d"
```

Running from your own repo:

This example assumes you have added `shellsuite.sh` to the root of your repo. If you add `shellsuite.sh` to a subfolder in your repo you will need to adjust `-p "${PWD}"` to `-p "${TRAVIS_BUILD_DIR}"` or `-p "/full/repo/path"`.

```yaml
script:
  - bash shellsuite.sh -p "${PWD}" -v "bashate" -f " -i E006"
  - bash shellsuite.sh -p "${PWD}" -v "shellcheck" -f " -x"
  - bash shellsuite.sh -p "${PWD}" -v "shfmt" -f " -s -i 4 -ci -sr -d"
```

### Use locally/manually

Requires Docker

```bash
curl -fsSL https://raw.githubusercontent.com/nemchik/ShellSuite/master/shellsuite.sh -o shellsuite.sh
bash shellsuite.sh -p "/full/repo/path" -v "bashate" -f " -i E006"
bash shellsuite.sh -p "/full/repo/path" -v "shellcheck" -f " -x"
bash shellsuite.sh -p "/full/repo/path" -v "shfmt" -f " -s -i 4 -ci -sr -d"
```

## Special Thanks

- [christronyxyocum](https://github.com/christronyxyocum/) helping drive the motivation for this project's creation.
- [caarlos0](https://github.com/caarlos0/) for the amazing [caarlos0/shell-ci-build](https://github.com/caarlos0/shell-ci-build) repo on which the primary function of this project is based.
