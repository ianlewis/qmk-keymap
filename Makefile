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

SHELL := /usr/bin/env bash

uname_s := $(shell uname -s)
uname_m := $(shell uname -m)
arch.x86_64 := amd64
arch = $(arch.$(uname_m))
kernel.Linux := linux
kernel = $(kernel.$(uname_s))

OUTPUT_FORMAT ?= $(shell if [ "${GITHUB_ACTIONS}" == "true" ]; then echo "github"; else echo ""; fi)
REPO_ROOT = $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
REPO_NAME = $(shell basename "$(REPO_ROOT)")

# renovate: datasource=github-releases depName=aquaproj/aqua versioning=loose
AQUA_VERSION ?= v2.55.0
AQUA_REPO ?= github.com/aquaproj/aqua
AQUA_CHECKSUM.Linux.x86_64 = 697d8e69bda13f30bb8d9f76ee5eeb67004cba93022148a20e7ffff8f7edee29
AQUA_CHECKSUM ?= $(AQUA_CHECKSUM.$(uname_s).$(uname_m))
AQUA_URL = https://$(AQUA_REPO)/releases/download/$(AQUA_VERSION)/aqua_$(kernel)_$(arch).tar.gz
AQUA_ROOT_DIR = $(REPO_ROOT)/.aqua

QMK_FIRMWARE_VERSION=0.28.0

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
	@echo "$(REPO_NAME) Makefile"
	@echo "Usage: make [COMMAND]"
	@echo ""
	@set -euo pipefail; \
		normal=""; \
		cyan=""; \
		if [ -t 1 ]; then \
			normal=$$(tput sgr0); \
			cyan=$$(tput setaf 6); \
		fi; \
		grep --no-filename -E '^([/a-z.A-Z0-9_%-]+:.*?|)##' $(MAKEFILE_LIST) | \
			awk \
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

package-lock.json: package.json
	@npm install --package-lock-only --no-audit --no-fund

node_modules/.installed: package-lock.json
	@npm clean-install
	@npm audit signatures
	@touch $@

.venv/bin/activate:
	@python -m venv .venv

.venv/.installed: requirements-dev.txt .venv/bin/activate
	@./.venv/bin/pip install -r $< --require-hashes
	@touch $@

.bin/aqua-$(AQUA_VERSION)/aqua:
	@set -euo pipefail; \
		mkdir -p .bin/aqua-$(AQUA_VERSION); \
		tempfile=$$(mktemp --suffix=".aqua-$(AQUA_VERSION).tar.gz"); \
		curl -sSLo "$${tempfile}" "$(AQUA_URL)"; \
		echo "$(AQUA_CHECKSUM)  $${tempfile}" | sha256sum -c; \
		tar -x -C .bin/aqua-$(AQUA_VERSION) -f "$${tempfile}"

$(AQUA_ROOT_DIR)/.installed: .aqua.yaml .bin/aqua-$(AQUA_VERSION)/aqua
	@AQUA_ROOT_DIR="$(AQUA_ROOT_DIR)" ./.bin/aqua-$(AQUA_VERSION)/aqua \
		--config .aqua.yaml \
		install
	@touch $@

## Build
#####################################################################

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

## Tools
#####################################################################

.PHONY: license-headers
license-headers: ## Update license headers.
	@set -euo pipefail; \
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
				'*.toml' \
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
		fi; \
		for filename in $${files}; do \
			if ! ( head "$${filename}" | grep -iL "Copyright" > /dev/null ); then \
				./third_party/mbrukman/autogen/autogen.sh \
					--in-place \
					--no-code \
					--no-tlc \
					--copyright "$${name}" \
					--license apache \
					"$${filename}"; \
			fi; \
		done

## Formatting
#####################################################################

.PHONY: format
format: clang-format json-format md-format yaml-format ## Format all files

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
	@set -euo pipefail; \
		files=$$( \
			git ls-files --deduplicate \
				'*.json' \
				'*.json5' \
				| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
		); \
		if [ "$${files}" == "" ]; then \
			exit 0; \
		fi; \
		./node_modules/.bin/prettier \
			--write \
			--no-error-on-unmatched-pattern \
			$${files}

.PHONY: md-format
md-format: node_modules/.installed ## Format Markdown files.
	@set -euo pipefail; \
		files=$$( \
			git ls-files --deduplicate \
				'*.md' \
				| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
		); \
		if [ "$${files}" == "" ]; then \
			exit 0; \
		fi; \
		# NOTE: prettier uses .editorconfig for tab-width. \
		./node_modules/.bin/prettier \
			--write \
			--no-error-on-unmatched-pattern \
			$${files}

.PHONY: yaml-format
yaml-format: node_modules/.installed ## Format YAML files.
	@set -euo pipefail; \
		files=$$( \
			git ls-files --deduplicate \
				'*.yml' \
				'*.yaml' \
		); \
		if [ "$${files}" == "" ]; then \
			exit 0; \
		fi; \
		./node_modules/.bin/prettier \
			--write \
			--no-error-on-unmatched-pattern \
			$${files}

## Linting
#####################################################################

.PHONY: lint
lint: actionlint commitlint fixme markdownlint renovate-config-validator textlint yamllint zizmor ## Run all linters.

.PHONY: actionlint
actionlint: $(AQUA_ROOT_DIR)/.installed ## Runs the actionlint linter.
	@# NOTE: We need to ignore config files used in tests.
	@set -euo pipefail;\
		files=$$( \
			git ls-files --deduplicate \
				'.github/workflows/*.yml' \
				'.github/workflows/*.yaml' \
				| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
		); \
		if [ "$${files}" == "" ]; then \
			exit 0; \
		fi; \
		PATH="$(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION):$(AQUA_ROOT_DIR)/bin:$${PATH}"; \
		AQUA_ROOT_DIR="$(AQUA_ROOT_DIR)"; \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			actionlint \
				-format '{{range $$err := .}}::error file={{$$err.Filepath}},line={{$$err.Line}},col={{$$err.Column}}::{{$$err.Message}}%0A```%0A{{replace $$err.Snippet "\\n" "%0A"}}%0A```\n{{end}}' \
				-ignore 'SC2016:' \
				$${files}; \
		else \
			actionlint $${files}; \
		fi

.PHONY: commitlint
commitlint: node_modules/.installed ## Run commitlint linter.
	@set -euo pipefail;\
		commitlint_from=$(COMMITLINT_FROM_REF); \
		commitlint_to=$(COMMITLINT_TO_REF); \
		if [ "$${commitlint_from}" == "" ]; then \
			commitlint_from=$$(git remote show origin | grep 'HEAD branch' | awk '{print $$NF}'); \
		fi; \
		if [ "$${commitlint_to}" == "" ]; then \
			# if head is on the commitlint_from branch, then we will lint the \
			# last commit by default. \
			current_branch=$$(git rev-parse --abbrev-ref HEAD); \
			if [ "$${commitlint_from}" == "$${current_branch}" ]; then \
				commintlint_from="HEAD~1"; \
			fi; \
			commitlint_to="HEAD"; \
		fi; \
		./node_modules/.bin/commitlint \
			--config .commitlint.config.mjs \
			--from "$${commitlint_from}" \
			--to "$${commitlint_to}" \
			--verbose \
			--strict

.PHONY: fixme
fixme: $(AQUA_ROOT_DIR)/.installed ## Check for outstanding FIXMEs.
	@set -euo pipefail;\
		PATH="$(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION):$(AQUA_ROOT_DIR)/bin:$${PATH}"; \
		AQUA_ROOT_DIR="$(AQUA_ROOT_DIR)"; \
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

.PHONY: markdownlint
markdownlint: node_modules/.installed $(AQUA_ROOT_DIR)/.installed ## Runs the markdownlint linter.
	@# NOTE: Issue and PR templates are handled specially so we can disable
	@# MD041/first-line-heading/first-line-h1 without adding an ugly html comment
	@# at the top of the file.
	@set -euo pipefail;\
		files=$$( \
			git ls-files --deduplicate \
				'*.md' \
				':!:.github/pull_request_template.md' \
				':!:.github/ISSUE_TEMPLATE/*.md' \
				| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
		); \
		if [ "$${files}" == "" ]; then \
			exit 0; \
		fi; \
		PATH="$(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION):$(AQUA_ROOT_DIR)/bin:$${PATH}"; \
		AQUA_ROOT_DIR="$(AQUA_ROOT_DIR)"; \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			exit_code=0; \
			while IFS="" read -r p && [ -n "$$p" ]; do \
				file=$$(echo "$$p" | jq -cr '.fileName // empty'); \
				line=$$(echo "$$p" | jq -cr '.lineNumber // empty'); \
				endline=$${line}; \
				message=$$(echo "$$p" | jq -cr '.ruleNames[0] + "/" + .ruleNames[1] + " " + .ruleDescription + " [Detail: \"" + .errorDetail + "\", Context: \"" + .errorContext + "\"]"'); \
				exit_code=1; \
				echo "::error file=$${file},line=$${line},endLine=$${endline}::$${message}"; \
			done <<< "$$(./node_modules/.bin/markdownlint --config .markdownlint.yaml --dot --json $${files} 2>&1 | jq -c '.[]')"; \
			if [ "$${exit_code}" != "0" ]; then \
				exit "$${exit_code}"; \
			fi; \
		else \
			./node_modules/.bin/markdownlint \
				--config .markdownlint.yaml \
				--dot \
				$${files}; \
		fi; \
		files=$$( \
			git ls-files --deduplicate \
				'.github/pull_request_template.md' \
				'.github/ISSUE_TEMPLATE/*.md' \
				| while IFS='' read -r f; do [ -f "$${f}" ] && echo "$${f}" || true; done \
		); \
		if [ "$${files}" == "" ]; then \
			exit 0; \
		fi; \
		if [ "$(OUTPUT_FORMAT)" == "github" ]; then \
			exit_code=0; \
			while IFS="" read -r p && [ -n "$$p" ]; do \
				file=$$(echo "$$p" | jq -cr '.fileName // empty'); \
				line=$$(echo "$$p" | jq -cr '.lineNumber // empty'); \
				endline=$${line}; \
				message=$$(echo "$$p" | jq -cr '.ruleNames[0] + "/" + .ruleNames[1] + " " + .ruleDescription + " [Detail: \"" + .errorDetail + "\", Context: \"" + .errorContext + "\"]"'); \
				exit_code=1; \
				echo "::error file=$${file},line=$${line},endLine=$${endline}::$${message}"; \
			done <<< "$$(./node_modules/.bin/markdownlint --config .github/template.markdownlint.yaml --dot --json $${files} 2>&1 | jq -c '.[]')"; \
			if [ "$${exit_code}" != "0" ]; then \
				exit "$${exit_code}"; \
			fi; \
		else \
			./node_modules/.bin/markdownlint \
				--config .github/template.markdownlint.yaml \
				--dot \
				$${files}; \
		fi

.PHONY: renovate-config-validator
renovate-config-validator: node_modules/.installed ## Validate Renovate configuration.
	@./node_modules/.bin/renovate-config-validator --strict

.PHONY: textlint
textlint: node_modules/.installed $(AQUA_ROOT_DIR)/.installed ## Runs the textlint linter.
	@set -euo pipefail; \
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
		PATH="$(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION):$(AQUA_ROOT_DIR)/bin:$${PATH}"; \
		AQUA_ROOT_DIR="$(AQUA_ROOT_DIR)"; \
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
				done <<<"$$(echo "$$p" | jq -cr '.messages[] // empty')"; \
			done <<< "$$(./node_modules/.bin/textlint -c .textlintrc.yaml --format json $${files} 2>&1 | jq -c '.[]')"; \
			exit "$${exit_code}"; \
		else \
			./node_modules/.bin/textlint \
				--config .textlintrc.yaml \
				$${files}; \
		fi

.PHONY: yamllint
yamllint: .venv/.installed ## Runs the yamllint linter.
	@set -euo pipefail;\
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
		.venv/bin/yamllint \
			--strict \
			--config-file .yamllint.yaml \
			--format "$${format}" \
			$${files}

.PHONY: zizmor
zizmor: .venv/.installed ## Runs the zizmor linter.
	@# NOTE: On GitHub actions this outputs SARIF format to zizmor.sarif.json
	@#       in addition to outputting errors to the terminal.
	@set -euo pipefail;\
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
			.venv/bin/zizmor \
				--config .zizmor.yml \
				--quiet \
				--pedantic \
				--format sarif \
				$${files} > zizmor.sarif.json; \
		fi; \
		.venv/bin/zizmor \
			--config .zizmor.yml \
			--quiet \
			--pedantic \
			--format plain \
			$${files}

## Maintenance
#####################################################################

.PHONY: todos
todos: $(AQUA_ROOT_DIR)/.installed ## Print outstanding TODOs.
	@set -euo pipefail;\
		PATH="$(REPO_ROOT)/.bin/aqua-$(AQUA_VERSION):$(AQUA_ROOT_DIR)/bin:$${PATH}"; \
		AQUA_ROOT_DIR="$(AQUA_ROOT_DIR)"; \
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
	@rm -rf \
		.bin \
		$(AQUA_ROOT_DIR) \
		.venv \
		node_modules \
		*.sarif.json \
		third_party/qmk_firmware \
		*.bin \
		*.hex \
		qmk.ini
