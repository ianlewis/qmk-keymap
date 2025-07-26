# `qmk-keymap`

[![tests](https://github.com/ianlewis/qmk-keymap/actions/workflows/pull_request.tests.yml/badge.svg)](https://github.com/ianlewis/qmk-keymap/actions/workflows/pull_request.tests.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/ianlewis/qmk-keymap/badge)](https://securityscorecards.dev/viewer/?uri=github.com%2Fianlewis%2Fqmk-keymap)

This repository contains my [Quantum Mechanical Keyboard](https://qmk.fm/)
keymaps for [ZSA ErgoDox EZ](keyboards/ergodox_ez/keymaps/ianlewis_dvorak) and
[ZSA Moonlander](keyboards/zsa/moonlander/keymaps/ianlewis_dvorak).

## Keymap

This is a visualization of the keymap. No special QMK features are used
currently.

### Base Layer

The base layer is based on a Dvorak keyboard layout which corresponds to a U.S.
English keyboard map in software. Modifiers are located on the edge of the
keyboard and accessed with the right and left little finger.

![Base Layer](keyboards/zsa/moonlander/keymaps/ianlewis_dvorak/doc/base.png)

### Navigation/Media Layer

The media layer includes media keys and navigation keys. It is used by holding
down the layer key with the right little finger.

![Media Layer](keyboards/zsa/moonlander/keymaps/ianlewis_dvorak/doc/media.png)

## Installation

The keymap can be installed in two ways. You can either download pre-built
binaries or build the keymap from source.

### Pre-built binaries

The pre-built binaries are available on GitHub Releases. Download the respective
binary and flash it to the keyboard using QMK CLI, or [ZSA
Keymapp](https://www.zsa.io/flash).

1. Download the pre-built binaries and SLSA provenance from the [latest
   release](https://github.com/ianlewis/qmk-keymap/releases).

    ```shell
    # ZSA ErgoDox EZ
    curl -sSLO https://github.com/ianlewis/qmk-keymap/releases/latest/download/ergodox_ez_base_ianlewis_dvorak.hex
    # ZSA Moonlander
    curl -sSLO https://github.com/ianlewis/qmk-keymap/releases/latest/download/zsa_moonlander_ianlewis_dvorak.bin
    # SLSA provenance
    curl -sSLO https://github.com/ianlewis/qmk-keymap/releases/latest/download/multiple.intoto.jsonl
    ```

2. Verify the binaries using
   [`slsa-verifier`](https://github.com/slsa-framework/slsa-verifier).

    ```shell
    slsa-verifier verify-artifact \
        ergodox_ez_base_ianlewis_dvorak.hex \
        zsa_moonlander_ianlewis_dvorak.bin \
        --provenance-path multiple.intoto.jsonl \
        --source-uri github.com/ianlewis/qmk-keymap \
        --source-tag v1.0.0
    ```

3. Using QMK CLI, you can flash the binary with the following command. You will
   need to set up Linux [udev rules] before this will work.

    ```shell
    # ZSA ErgoDox EZ
    qmk flash \
        --keyboard ergodox_ez \
        --keymap ianlewis_dvorak \
        --mcu TEENSY2 \
        ergodox_ez_base_ianlewis_dvorak.hex

    # ZSA Moonlander
    qmk flash
        --keyboard zsa/moonlander \
        --keymap ianlewis_dvorak \
        zsa_moonlander_ianlewis_dvorak.bin
    ```

### Build from source

This repository is structured as an [External QMK
Userspace](https://docs.qmk.fm/newbs_external_userspace). The repository
requires the Python runtime to be installed. All dependencies including QMK is
installed locally to the repository in a
[venv](https://docs.python.org/3/library/venv.html).

The [Makefile](./Makefile) defines various build targets under the "Build"
subheading.

```shell
$ make
qmk-keymap Makefile
Usage: make [COMMAND]

  help                      Print all Makefile targets (this message).
Build
  ergodox_ez-compile        Compile ErgoDox EZ firmware
  ergodox_ez-flash          Flash ErgoDox EZ firmware
  moonlander-compile        Compile ZSA Moonlander firmware
  moonlander-flash          Flash ZSA Moonlander firmware
Tools
  license-headers           Update license headers.
Formatting
  format                    Format all files
  clang-format              Format C files.
  json-format               Format JSON files.
  md-format                 Format Markdown files.
  yaml-format               Format YAML files.
Linting
  lint                      Run all linters.
  actionlint                Runs the actionlint linter.
  commitlint                Run commitlint linter.
  fixme                     Check for outstanding FIXMEs.
  markdownlint              Runs the markdownlint linter.
  renovate-config-validator Validate Renovate configuration.
  textlint                  Runs the textlint linter.
  yamllint                  Runs the yamllint linter.
  zizmor                    Runs the zizmor linter.
Maintenance
  todos                     Print outstanding TODOs.
  clean                     Delete temporary files.
```

The keymaps can be compiled and flashed with the following commands. You will
need to set up Linux [udev rules] before this will work.

```shell
# ZSA ErgoDox EZ
make ergodox_ez-flash

# ZSA Moonlander
make moonlander-flash
```

[udev rules]: https://docs.qmk.fm/faq_build#linux-udev-rules
