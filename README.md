# ShellSuite

[![Travis (.com) branch](https://img.shields.io/travis/com/nemchik/ShellSuite/master.svg?logo=travis)](https://travis-ci.com/nemchik/ShellSuite) [![GitHub](https://img.shields.io/github/license/nemchik/ShellSuite.svg)](https://github.com/nemchik/ShellSuite/blob/master/LICENSE.md)

This is a collection of shell script validations designed to run on git repositories. The intention of this project is to be run by CI/CD such as [Travis CI](https://travis-ci.com/) and others, but you can also run it locally/manually.

## Purpose

These tools are already available for direct use in many CI/CD environments and otherwise, but after using them I've found some inconsistencies. This project aims to solve those inconsistencies by:

- Using the same tool/version on each environment used for testing.
- Using the latest available version of each tool via Docker.
- Only scanning files that are part of the git repo using `git ls-tree` and skipping files ignored with `.gitignore`.

## Script Arguments

The following arguments are required:

`-p` or `--path` must be defined first and should be the full path to the git repo being tested.

`-v` or `--validator` accepts `bashate`, `shellcheck`, or `shfmt`.

`-f` or `--flags` must start with a blank space and will be passed to the validator for testing. This allows you to ignore certain validation rules if needed.

## Example useage

All examples show the use of all 3 validators, but you may choose to use only one or two if you'd like.

### Use in `.travis.yml`

Examples are shown with recommended defaults for `--flags`, but you may adjust to your liking.

Running from this repo:

```yaml
script:
  - curl -fsSL https://raw.githubusercontent.com/nemchik/ShellSuite/master/shellsuite.sh -o shellsuite.sh && bash shellsuite.sh -p "${PWD}" -v "bashate" -f " -i E006"
  - curl -fsSL https://raw.githubusercontent.com/nemchik/ShellSuite/master/shellsuite.sh -o shellsuite.sh && bash shellsuite.sh -p "${PWD}" -v "shellcheck" -f " -x"
  - curl -fsSL https://raw.githubusercontent.com/nemchik/ShellSuite/master/shellsuite.sh -o shellsuite.sh && bash shellsuite.sh -p "${PWD}" -v "shfmt" -f " -s -i 4 -ci -sr -d"
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
