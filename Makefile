.PHONY: setup audit lint test sync-abbr help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Run full setup (install deps, create symlinks)
	@bash setup.sh

audit: ## Audit abbreviations against shell history (requires atuin)
	@bash scripts/audit-abbreviations.sh

lint: ## Lint shell scripts with shellcheck + shfmt
	@bash scripts/lint-shell

test: ## Run the test suite
	@bash scripts/run-tests

sync-abbr: ## Regenerate Fish and Zsh abbreviation files from YAML
	@cd shared && bash generate-fish-abbr.sh && bash generate-zsh-abbr.sh
	@echo "Abbreviation files regenerated."

validate: ## Run configuration validators
	@bash scripts/validate-config.sh
