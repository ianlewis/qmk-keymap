# `qmk-keymap`

[![tests](https://github.com/ianlewis/qmk-keymap/actions/workflows/pre-submit.units.yml/badge.svg)](https://github.com/ianlewis/qmk-keymap/actions/workflows/pre-submit.units.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/ianlewis/qmk-keymap/badge)](https://securityscorecards.dev/viewer/?uri=github.com%2Fianlewis%2Fqmk-keymap)

This repository contains my [Quantum Mechanical Keyboard](https://docs.qmk.fm/)
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

The repository requires the Python runtime to be installed. The
[Makefile](./Makefile) defines various targets.

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
  zizmor                    Runs the zizmor linter.
  markdownlint              Runs the markdownlint linter.
  renovate-config-validator Validate Renovate configuration.
  textlint                  Runs the textlint linter.
  todos                     Check for outstanding TODOs.
  yamllint                  Runs the yamllint linter.
Maintenance
  clean                     Delete temporary files.
```

The keymaps can be compiled and flashed with the following commands. You will
need to set up Linux [udev
rules](https://docs.qmk.fm/faq_build#linux-udev-rules) before this will work.

```shell
# ZSA ErgoDox EZ
make ergodox_ez-flash

# ZSA Moonlander
make moonlander-flash
```
