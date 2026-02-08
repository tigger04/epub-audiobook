# ABOUTME: Build, test, and release automation for epub-audiobook
# ABOUTME: Wraps xcodebuild for standard make targets

SCHEME := epub-audiobook
PROJECT := epub-audiobook.xcodeproj
DESTINATION := platform=iOS Simulator,arch=arm64,name=iPhone 15 Pro,OS=17.5

.PHONY: build test test-ui test-all clean release sync help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the project
	xcodebuild build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-quiet

test: ## Run unit and integration tests
	xcodebuild test \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-quiet

test-ui: ## Run UI/E2E tests
	xcodebuild test \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-only-testing:epub-audiobook-uitests \
		-quiet

test-all: test test-ui ## Run all tests

clean: ## Clean build artefacts
	xcodebuild clean \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-quiet
	rm -rf DerivedData build

release: ## Create a release (usage: make release VERSION=x.y)
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make release VERSION=x.y"; \
		exit 1; \
	fi
	@echo "Tagging release v$(VERSION)..."
	git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	git push origin "v$(VERSION)"
	gh release create "v$(VERSION)" --title "v$(VERSION)" --generate-notes

sync: ## Sync local repo with remote
	git add --all
	@read -p "Commit message: " msg; \
	git commit -m "$$msg"
	git pull --rebase
	git push
