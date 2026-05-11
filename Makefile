# Copyright 2024 Ian Lewis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set the initial shell so we can determine extra options.
SHELL := /usr/bin/env bash -ueo pipefail
DEBUG_LOGGING ?= $(shell if [[ "$${GITHUB_ACTIONS:-}" == "true" ]] && [[ -n "$${RUNNER_DEBUG:-}" || "$${ACTIONS_RUNNER_DEBUG:-}" == "true" || "$${ACTIONS_STEP_DEBUG:-}" == "true" ]]; then echo "true"; else echo ""; fi)
BASH_OPTIONS := $(shell if [ "$(DEBUG_LOGGING)" == "true" ]; then echo "-x"; else echo ""; fi)

# Add extra options for debugging.
SHELL := /usr/bin/env bash -ueo pipefail $(BASH_OPTIONS)

uname_s := $(shell uname -s)
uname_m := $(shell uname -m)
arch.x86_64 := amd64
arch.aarch64 := arm64
arch.arm64 := arm64
arch := $(arch.$(uname_m))
kernel.Linux := linux
kernel.Darwin := darwin
kernel := $(kernel.$(uname_s))

OUTPUT_FORMAT ?= $(shell if [ "${GITHUB_ACTIONS}" == "true" ]; then echo "github"; else echo ""; fi)
REPO_ROOT := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
REPO_NAME := $(shell basename "$(REPO_ROOT)")

# renovate: datasource=github-releases depName=aquaproj/aqua versioning=loose
AQUA_VERSION ?= v2.58.0
AQUA_REPO := github.com/aquaproj/aqua
AQUA_CHECKSUM.linux.amd64 := e4db66fca1cf9061d18ff1c0abc1cb68ada30e1e2500438ec8a20b72661111be
AQUA_CHECKSUM.linux.arm64 := 2e7fe48e181eb6e310653124562b5b30569f1a29b781da6ee82d902ded25c6dc
AQUA_CHECKSUM.darwin.arm64 := 2d6a5dbdfac17a9caa256f87104b9ce716dcd6eb8cbe1c248adb63d24101db21
AQUA_CHECKSUM ?= $(AQUA_CHECKSUM.$(kernel).$(arch))
AQUA_URL := https://$(AQUA_REPO)/releases/download/$(AQUA_VERSION)/aqua_$(kernel)_$(arch).tar.gz
export AQUA_ROOT_DIR = $(REPO_ROOT)/.aqua

# Ensure that aqua and aqua installed tools are in the PATH.
export PATH := $(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION):$(AQUA_ROOT_DIR)/bin:$(PATH)

# We want GNU versions of tools so prefer them if present.
GREP := $(shell command -v ggrep 2>/dev/null || command -v grep 2>/dev/null)
AWK := $(shell command -v gawk 2>/dev/null || command -v awk 2>/dev/null)
MKTEMP := $(shell command -v gmktemp 2>/dev/null || command -v mktemp 2>/dev/null)

QMK_FIRMWARE_VERSION := 0.28.0

rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

# The help command prints targets in groups. Help documentation in the Makefile
# uses comments with double hash marks (##). Documentation is printed by the
# help target in the order in appears in the Makefile.
#
# Make targets can be documented with double hash marks as follows:
#
#	target-name: ## target documentation.
#
# Groups can be added with the following style:
#
#	## Group name

.PHONY: help
help: ## Print all Makefile targets (this message).
	@# bash \
	echo "$(REPO_NAME) Makefile"; \
	echo "Usage: $(MAKE) [COMMAND]"; \
	echo ""; \
	normal=""; \
	cyan=""; \
	if command -v tput >/dev/null 2>&1; then \
		if [ -t 1 ]; then \
			normal=$$(tput sgr0); \
			cyan=$$(tput setaf 6); \
		fi; \
	fi; \
	$(GREP) --no-filename -E '^([/a-z.A-Z0-9_%-]+:.*?|)##' $(MAKEFILE_LIST) | \
		$(AWK) \
			--assign=normal="$${normal}" \
			--assign=cyan="$${cyan}" \
			'BEGIN {FS = "(:.*?|)## ?"}; { \
				if (length($$1) > 0) { \
					printf("  " cyan "%-25s" normal " %s\n", $$1, $$2); \
				} else { \
					if (length($$2) > 0) { \
						printf("%s\n", $$2); \
					} \
				} \
			}'

.aqua-checksums.json: $(REPO_ROOT)/.aqua.yaml $(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION)/aqua
	@# bash \
	loglevel="info"; \
	if [ -n "$(DEBUG_LOGGING)" ]; then \
		loglevel="debug"; \
	fi; \
	$(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION)/aqua \
		--config "$(REPO_ROOT)/.aqua.yaml" \
		--log-level "$${loglevel}" \
		update-checksum

package-lock.json: package.json $(AQUA_ROOT_DIR)/.installed
	@# bash \
	loglevel="notice"; \
	if [ -n "$(DEBUG_LOGGING)" ]; then \
		loglevel="verbose"; \
	fi; \
	# NOTE: npm install will happily ignore the fact that integrity hashes are \
	# missing in the package-lock.json. We need to check for missing integrity \
	# fields ourselves. If any are missing, then we need to regenerate the \
	# package-lock.json from scratch. \
	nointegrity=""; \
	noresolved=""; \
	if [ -f "$@" ]; then \
		nointegrity=$$(jq '.packages | del(."") | .[] | select(has("integrity") | not)' < $@); \
		noresolved=$$(jq '.packages | del(."") | .[] | select(has("resolved") | not)' < $@); \
	fi; \
	if [ ! -f "$@" ] || [ -n "$${nointegrity}" ] || [ -n "$${noresolved}" ]; then \
		# NOTE: package-lock.json is removed to ensure that npm includes the \
		# integrity field. npm install will not restore this field if \
		# missing in an existing package-lock.json file. \
		rm -f $@; \
		npm --loglevel="$${loglevel}" install \
			--no-audit \
			--no-fund; \
	else \
		npm --loglevel="$${loglevel}" install \
			--package-lock-only \
			--no-audit \
			--no-fund; \
	fi

node_modules/.installed: package.json | package-lock.json
	@# bash \
	loglevel="silent"; \
	if [ -n "$(DEBUG_LOGGING)" ]; then \
		loglevel="verbose"; \
	fi; \
	npm --loglevel="$${loglevel}" clean-install; \
	npm --loglevel="$${loglevel}" audit signatures; \
	touch $@

.venv/bin/activate:
	@# bash \
	python -m venv .venv

.venv/.installed: requirements-dev.txt .venv/bin/activate
	@# bash \
	$(REPO_ROOT)/.venv/bin/pip install -r $< --require-hashes; \
	touch $@

.bin/aqua-$(AQUA_VERSION)/aqua:
	@# bash \
	mkdir -p .bin/aqua-$(AQUA_VERSION); \
	tempfile=$$($(MKTEMP) --suffix=".aqua-$(AQUA_VERSION).tar.gz"); \
	curl -sSLo "$${tempfile}" "$(AQUA_URL)"; \
	echo "$(AQUA_CHECKSUM)  $${tempfile}" | shasum -a 256 -c; \
	tar -x -C .bin/aqua-$(AQUA_VERSION) -f "$${tempfile}"

$(AQUA_ROOT_DIR)/.installed: .aqua.yaml .bin/aqua-$(AQUA_VERSION)/aqua | .aqua-checksums.json
	@# bash \
	loglevel="info"; \
	if [ -n "$(DEBUG_LOGGING)" ]; then \
		loglevel="debug"; \
	fi; \
	$(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION)/aqua \
		--config "$(REPO_ROOT)/.aqua.yaml" \
		--log-level "$${loglevel}" \
		install; \
	touch $@

## Build
#####################################################################

.PHONY: all
all: test ergodox_ez-compile moonlander-compile ## Build everything.

qmk.ini third_party/qmk_firmware: .venv/.installed
	@set -euo pipefail; \
		mkdir -p third_party; \
		$(REPO_ROOT)/.venv/bin/qmk \
			--config-file qmk.ini \
			setup \
				--yes \
				--branch $(QMK_FIRMWARE_VERSION) \
				--home $(REPO_ROOT)/third_party/qmk_firmware; \
		$(REPO_ROOT)/.venv/bin/qmk \
			--config-file qmk.ini \
			config \
				user.overlay_dir="$(REPO_ROOT)"

ergodox_ez_base_ianlewis_dvorak.hex: qmk.ini third_party/qmk_firmware $(call rwildcard,keyboards/zsa/ergodox_ez,*.*)
	@$(REPO_ROOT)/.venv/bin/qmk \
		--config-file qmk.ini \
		compile \
			--keyboard ergodox_ez \
			--keymap ianlewis_dvorak

.PHONY: ergodox_ez-compile
ergodox_ez-compile: ergodox_ez_base_ianlewis_dvorak.hex ## Compile ErgoDox EZ firmware

ergodox_ez-flash: ergodox_ez_base_ianlewis_dvorak.hex ## Flash ErgoDox EZ firmware
	@$(REPO_ROOT)/.venv/bin/qmk \
		--config-file qmk.ini \
		flash \
			--keyboard ergodox_ez \
			--keymap ianlewis_dvorak \
			--mcu TEENSY2 \
			ergodox_ez_base_ianlewis_dvorak.hex

zsa_moonlander_ianlewis_dvorak.bin: qmk.ini third_party/qmk_firmware  $(call rwildcard,keyboards/zsa/moonlander,*.*)
	@$(REPO_ROOT)/.venv/bin/qmk \
		--config-file qmk.ini \
		compile \
			--keyboard zsa/moonlander \
			--keymap ianlewis_dvorak

.PHONY: moonlander-compile
moonlander-compile: zsa_moonlander_ianlewis_dvorak.bin ## Compile ZSA Moonlander firmware

moonlander-flash: zsa_moonlander_ianlewis_dvorak.bin ## Flash ZSA Moonlander firmware
	@$(REPO_ROOT)/.venv/bin/qmk \
		--config-file qmk.ini \
		flash \
			--keyboard zsa/moonlander \
			--keymap ianlewis_dvorak \
			zsa_moonlander_ianlewis_dvorak.bin

## Testing
#####################################################################

.PHONY: test
test: lint ## Run all tests.

## Formatting
#####################################################################

.PHONY: format
format: clang-format json-format license-headers md-format yaml-format ## Format all files

.PHONY: clang-format
clang-format: ## Format C files.
	@set -euo pipefail; \
		files=$$( \
			git ls-files --deduplicate \
				'*.c' \
		); \
		clang-format -i $${files}

.PHONY: json-format
json-format: node_modules/.installed ## Format JSON files.
	@# bash \
	loglevel="log"; \
	if [ -n "$(DEBUG_LOGGING)" ]; then \
		loglevel="debug"; \
	fi; \
	files=$$( \
		git ls-files --deduplicate \
			'*.json' \
			'*.json5' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	$(REPO_ROOT)/node_modules/.bin/prettier \
		--log-level "$${loglevel}" \
		--no-error-on-unmatched-pattern \
		--write \
		$${files}

.PHONY: license-headers
license-headers: ## Update license headers.
	@# bash \
	files=$$( \
		git ls-files --deduplicate \
			'*.c' \
			'*.cpp' \
			'*.go' \
			'*.h' \
			'*.hpp' \
			'*.js' \
			'*.lua' \
			'*.py' \
			'*.rb' \
			'*.rs' \
			'*.yaml' \
			'*.yml' \
			'Makefile' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	name=$$(git config user.name); \
	if [ "$${name}" == "" ]; then \
		>&2 echo "git user.name is required."; \
		>&2 echo "Set it up using:"; \
		>&2 echo "git config user.name \"John Doe\""; \
		exit 1; \
	fi; \
	for filename in $${files}; do \
		if ! ( head "$${filename}" | $(GREP) -iL "Copyright" > /dev/null ); then \
			$(REPO_ROOT)/third_party/mbrukman/autogen/autogen.sh \
				--in-place \
				--no-code \
				--no-tlc \
				--copyright "$${name}" \
				--license apache \
				"$${filename}"; \
		fi; \
	done


.PHONY: md-format
md-format: node_modules/.installed ## Format Markdown files.
	@# bash \
	loglevel="log"; \
	if [ -n "$(DEBUG_LOGGING)" ]; then \
		loglevel="debug"; \
	fi; \
	files=$$( \
		git ls-files --deduplicate \
			'*.md' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	# NOTE: prettier uses .editorconfig for tab-width. \
	$(REPO_ROOT)/node_modules/.bin/prettier \
		--log-level "$${loglevel}" \
		--no-error-on-unmatched-pattern \
		--write \
		$${files}

.PHONY: yaml-format
yaml-format: node_modules/.installed ## Format YAML files.
	@# bash \
	loglevel="log"; \
	if [ -n "$(DEBUG_LOGGING)" ]; then \
		loglevel="debug"; \
	fi; \
	files=$$( \
		git ls-files --deduplicate \
			'*.yml' \
			'*.yaml' \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	$(REPO_ROOT)/node_modules/.bin/prettier \
		--log-level "$${loglevel}" \
		--no-error-on-unmatched-pattern \
		--write \
		$${files}

## Linting
#####################################################################

.PHONY: lint
lint: actionlint checkmake commitlint fixme format-check markdownlint renovate-config-validator textlint yamllint zizmor ## Run all linters.

.PHONY: actionlint
actionlint: $(AQUA_ROOT_DIR)/.installed ## Runs the actionlint linter.
	@# bash \
	# NOTE: We need to ignore config files used in tests. \
	files=$$( \
		git ls-files --deduplicate \
			'.github/workflows/*.yml' \
			'.github/workflows/*.yaml' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
		actionlint \
			-format '{{range $$err := .}}::error file={{$$err.Filepath}},line={{$$err.Line}},col={{$$err.Column}}::{{$$err.Message}}%0A```%0A{{replace $$err.Snippet "\\n" "%0A"}}%0A```\n{{end}}' \
			-ignore 'SC2016:' \
			$${files}; \
	else \
		actionlint \
			-ignore 'SC2016:' \
			$${files}; \
	fi

.PHONY: checkmake
checkmake: $(AQUA_ROOT_DIR)/.installed ## Runs the checkmake linter.
	@# bash \
	# NOTE: We need to ignore config files used in tests. \
	files=$$( \
		git ls-files --deduplicate \
			'Makefile' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
		checkmake \
			--format '::error file={{.FileName}},line={{.LineNumber}}::{{.Rule}}: {{.Violation}}' \
			$${files}; \
	else \
		checkmake $${files}; \
	fi

.PHONY: commitlint
commitlint: node_modules/.installed ## Run commitlint linter.
	@# bash \
	commitlint_from=$(COMMITLINT_FROM_REF); \
	commitlint_to=$(COMMITLINT_TO_REF); \
	if [ "$${commitlint_from}" == "" ]; then \
		# Try to get the default branch without hitting the remote server \
		if git symbolic-ref --short refs/remotes/origin/HEAD >/dev/null 2>&1; then \
			commitlint_from=$$(git symbolic-ref --short refs/remotes/origin/HEAD); \
		elif git show-ref refs/remotes/origin/master >/dev/null 2>&1; then \
			commitlint_from="origin/master"; \
		else \
			commitlint_from="origin/main"; \
		fi; \
	fi; \
	if [ "$${commitlint_to}" == "" ]; then \
		# If upstream of HEAD is on the commitlint_from branch, then we will \
		# lint the last commit by default. \
		current_branch=$$(git rev-parse --abbrev-ref @{u}); \
		if [ "$${commitlint_from}" == "$${current_branch}" ]; then \
			commitlint_from="HEAD~1"; \
		fi; \
		commitlint_to="HEAD"; \
	fi; \
	$(REPO_ROOT)/node_modules/.bin/commitlint \
		--from "$${commitlint_from}" \
		--to "$${commitlint_to}" \
		--verbose \
		--strict

.PHONY: fixme
fixme: $(AQUA_ROOT_DIR)/.installed ## Check for outstanding FIXMEs.
	@# bash \
	output="default"; \
	if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
		output="github"; \
	fi; \
	# NOTE: todos does not use `git ls-files` because many files might be \
	# 		unsupported and generate an error if passed directly on the \
	# 		command line. \
	todos \
		--output "$${output}" \
		--todo-types="FIXME,Fixme,fixme,BUG,Bug,bug,XXX,COMBAK"

.PHONY: format-check
format-check: ## Check that files are properly formatted.
	@# bash \
	if [ -n "$$(git diff)" ]; then \
		>&2 echo "The working directory is dirty. Please commit, stage, or stash changes and try again."; \
		exit 1; \
	fi; \
	$(MAKE) format; \
	exit_code=0; \
	if [ -n "$$(git diff)" ]; then \
		>&2 echo "Some files need to be formatted. Please run 'make format' and try again."; \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			echo "::group::git diff"; \
		fi; \
		git --no-pager diff; \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			echo "::endgroup::"; \
		fi; \
		exit_code=1; \
	fi; \
	git restore .; \
	exit "$${exit_code}"

.PHONY: markdownlint
markdownlint: node_modules/.installed $(AQUA_ROOT_DIR)/.installed ## Runs the markdownlint linter.
	@# bash \
	# NOTE: Issue and PR templates are handled specially so we can disable \
	# MD041/first-line-heading/first-line-h1 without adding an ugly html comment \
	# at the top of the file. \
	files=$$( \
		git ls-files --deduplicate \
			'*.md' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	$(REPO_ROOT)/node_modules/.bin/markdownlint-cli2 $${files}

.PHONY: renovate-config-validator
renovate-config-validator: node_modules/.installed ## Validate Renovate configuration.
	@# bash \
	$(REPO_ROOT)/node_modules/.bin/renovate-config-validator \
		--strict

.PHONY: textlint
textlint: node_modules/.installed $(AQUA_ROOT_DIR)/.installed ## Runs the textlint linter.
	@# bash \
	files=$$( \
		git ls-files --deduplicate \
			'*.md' \
			'*.txt' \
			':!:requirements*.txt' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
		exit_code=0; \
		while IFS="" read -r p && [ -n "$$p" ]; do \
			filePath=$$(echo "$$p" | jq -cr '.filePath // empty'); \
			file=$$(realpath --relative-to="." "$${filePath}"); \
			while IFS="" read -r m && [ -n "$$m" ]; do \
				line=$$(echo "$$m" | jq -cr '.loc.start.line // empty'); \
				endline=$$(echo "$$m" | jq -cr '.loc.end.line // empty'); \
				col=$$(echo "$${m}" | jq -cr '.loc.start.column // empty'); \
				endcol=$$(echo "$${m}" | jq -cr '.loc.end.column // empty'); \
				message=$$(echo "$$m" | jq -cr '.message // empty'); \
				exit_code=1; \
				echo "::error file=$${file},line=$${line},endLine=$${endline},col=$${col},endColumn=$${endcol}::$${message}"; \
			done <<<"$$(echo "$${p}" | jq -cr '.messages[] // empty')"; \
		done <<<"$$($(REPO_ROOT)/node_modules/.bin/textlint --format json $${files} 2>&1 | jq -c '.[]')"; \
		exit "$${exit_code}"; \
	else \
		$(REPO_ROOT)/node_modules/.bin/textlint \
			$${files}; \
	fi

.PHONY: yamllint
yamllint: .venv/.installed ## Runs the yamllint linter.
	@# bash \
	files=$$( \
		git ls-files --deduplicate \
			'*.yml' \
			'*.yaml' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	format="standard"; \
	if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
		format="github"; \
	fi; \
	$(REPO_ROOT)/.venv/bin/yamllint \
		--strict \
		--format "$${format}" \
		$${files}

.PHONY: zizmor
zizmor: .venv/.installed ## Runs the zizmor linter.
	@# bash \
	# NOTE: On GitHub actions this outputs SARIF format to zizmor.sarif.json \
	#       in addition to outputting errors to the terminal. \
	files=$$( \
		git ls-files --deduplicate \
			'.github/workflows/*.yml' \
			'.github/workflows/*.yaml' \
			| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
	); \
	if [ "$${files}" == "" ]; then \
		exit 0; \
	fi; \
	if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
		$(REPO_ROOT)/.venv/bin/zizmor \
			--quiet \
			--pedantic \
			--format sarif \
			$${files} > zizmor.sarif.json; \
	fi; \
	$(REPO_ROOT)/.venv/bin/zizmor \
		--quiet \
		--pedantic \
		--format plain \
		$${files}

## Maintenance
#####################################################################

.PHONY: update-lockfiles
update-lockfiles: .aqua-checksums.json package-lock.json ## Update lockfiles.

.PHONY: todos
todos: $(AQUA_ROOT_DIR)/.installed ## Print outstanding TODOs.
	@# bash \
	output="default"; \
	if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
		output="github"; \
	fi; \
	# NOTE: todos does not use `git ls-files` because many files might be \
	# 		unsupported and generate an error if passed directly on the \
	# 		command line. \
	todos \
		--output "$${output}" \
		--todo-types="TODO,Todo,todo,FIXME,Fixme,fixme,BUG,Bug,bug,XXX,COMBAK"

.PHONY: clean
clean: ## Delete temporary files.
	@$(RM) -r .bin
	@$(RM) -r $(AQUA_ROOT_DIR)
	@$(RM) -r .venv
	@$(RM) -r node_modules
	@$(RM) *.sarif.json
	@$(RM) -r third_party/qmk_firmware
	@$(RM) *.bin
	@$(RM) *.hex
	@$(RM) qmk.ini
