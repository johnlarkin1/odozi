PROJECT = Odyssey.xcodeproj
SCHEME = Odyssey
CONFIG_DEBUG = Debug
CONFIG_RELEASE = Release

# Default destination — override with: make build DESTINATION='platform=iOS,name=MyiPhone'
DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: help setup-simulator run-app preview build build-release build-mac build-watch test test-unit test-ui build-widget clean resolve lint lint-ios lint-website typecheck typecheck-website format fmt update-secret-template tag beta beta-local beta-local-no-screen release release-local release-local-no-screen match-appstore match-development match-force-local website-dev website-build website-install screenshots appstore appstore-iphone appstore-watch demo demo-pr widget-screenshots widget-screenshots-pr

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup-simulator: ## Download iOS platform and create iPhone 16 simulator
	@echo "Downloading iOS platform (this may take a while)..."
	xcodebuild -downloadPlatform iOS
	@echo "Creating iPhone 16 simulator..."
	@xcrun simctl create "iPhone 16" "com.apple.CoreSimulator.SimDeviceType.iPhone-16" \
		$$(xcrun simctl list runtimes available -j | python3 -c "import sys,json; rts=[r for r in json.loads(sys.stdin.read())['runtimes'] if 'iOS' in r['name']]; print(rts[-1]['identifier'])" 2>/dev/null) \
		2>/dev/null || echo "iPhone 16 simulator already exists"
	@echo "Done! Available simulators:"
	@xcrun simctl list devices available | grep -i iphone | head -5

run-app: ## Build and run iOS app only (uses Odyssey.xcconfig URL)
	xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
	open -a Simulator
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) -destination '$(DESTINATION)' -derivedDataPath build build
	xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Odyssey.app
	xcrun simctl launch booted com.johnlarkin.Odyssey

preview: ## Launch app in simulator with 30 days of seeded sample data
	xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
	open -a Simulator
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) \
		-destination '$(DESTINATION)' -derivedDataPath build -quiet build
	xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Odyssey.app
	xcrun simctl terminate booted com.johnlarkin.Odyssey 2>/dev/null || true
	SIMCTL_CHILD_SCREENSHOT_MODE=1 xcrun simctl launch booted com.johnlarkin.Odyssey
	@echo "App launched with sample data. Use 'make run-app' for normal mode."

build: ## Build debug configuration
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) -destination '$(DESTINATION)' build

build-release: ## Build release configuration
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_RELEASE) -destination '$(DESTINATION)' build

build-mac: ## Build macOS app (debug)
	xcodebuild -project $(PROJECT) -scheme OdysseyMac -configuration $(CONFIG_DEBUG) -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

build-mac-release: ## Build macOS app (release)
	xcodebuild -project $(PROJECT) -scheme OdysseyMac -configuration $(CONFIG_RELEASE) -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

build-watch: ## Build watchOS app (debug)
	xcodebuild -project $(PROJECT) -scheme OdysseyWatch -configuration $(CONFIG_DEBUG) -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' CODE_SIGNING_ALLOWED=NO build

test: ## Run all tests (unit + UI)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' test

test-unit: ## Run unit tests only
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -only-testing:OdysseyTests test

test-ui: ## Run UI tests only
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -only-testing:OdysseyUITests test

build-widget: ## Build OdysseyWidget extension
	xcodebuild -project $(PROJECT) -scheme OdysseyWidget -configuration $(CONFIG_DEBUG) -destination '$(DESTINATION)' build

build-monitor: ## Build DeviceActivityMonitor extension
	xcodebuild -project $(PROJECT) -scheme OdysseyDeviceActivityMonitor -configuration $(CONFIG_DEBUG) -destination '$(DESTINATION)' build

build-report: ## Build DeviceActivityReport extension
	xcodebuild -project $(PROJECT) -scheme OdysseyDeviceActivityReport -configuration $(CONFIG_DEBUG) -destination '$(DESTINATION)' build

update-secret-template: ## Generate .env.example from .env with dummy values
	@sed 's/=.*/=CHANGE_ME/' .env > .env.example
	@echo "Updated .env.example:"
	@cat .env.example

clean: ## Clean build artifacts
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf DerivedData build

resolve: ## Resolve Swift package dependencies
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -resolvePackageDependencies

# Terminal colors
GREEN  := \033[0;32m
RED    := \033[0;31m
RESET  := \033[0m

lint: ## Lint all (iOS + website) and type-check
	@failed=0; \
	$(MAKE) lint-ios || failed=1; \
	$(MAKE) lint-website || failed=1; \
	$(MAKE) typecheck-website || failed=1; \
	if [ $$failed -eq 0 ]; then \
		printf '$(GREEN)✓ All lint and type checks passed$(RESET)\n'; \
	else \
		printf '$(RED)✗ Lint/type checks failed$(RESET)\n'; \
		exit 1; \
	fi

lint-ios: ## Lint Swift source files with SwiftLint
	@if swiftlint lint --strict; then \
		printf '$(GREEN)  ✓ lint-ios passed$(RESET)\n'; \
	else \
		printf '$(RED)  ✗ lint-ios failed$(RESET)\n'; \
		exit 1; \
	fi

lint-website: ## Lint website TypeScript/React with ESLint
	@if cd website && npm run lint --silent; then \
		printf '$(GREEN)  ✓ lint-website passed$(RESET)\n'; \
	else \
		printf '$(RED)  ✗ lint-website failed$(RESET)\n'; \
		exit 1; \
	fi

typecheck: ## Type-check all
	@failed=0; \
	$(MAKE) typecheck-website || failed=1; \
	if [ $$failed -eq 0 ]; then \
		printf '$(GREEN)✓ All type checks passed$(RESET)\n'; \
	else \
		printf '$(RED)✗ Type checks failed$(RESET)\n'; \
		exit 1; \
	fi

typecheck-website: ## Type-check website with TypeScript
	@if cd website && npm run typecheck --silent; then \
		printf '$(GREEN)  ✓ typecheck-website passed$(RESET)\n'; \
	else \
		printf '$(RED)  ✗ typecheck-website failed$(RESET)\n'; \
		exit 1; \
	fi

format: ## Format Swift source files with SwiftFormat
	@if swiftformat .; then \
		printf '$(GREEN)✓ Format complete$(RESET)\n'; \
	else \
		printf '$(RED)✗ Format failed$(RESET)\n'; \
		exit 1; \
	fi

fmt: format ## Alias for format

tag: ## Create a version tag locally (BUMP=minor|patch, default patch)
	@BUMP=$${BUMP:-patch}; \
	LATEST=$$(git tag -l 'v*' --sort=-v:refname | head -n 1); \
	if [ -z "$$LATEST" ]; then \
		NEW="v0.1.0"; \
	else \
		MAJOR=$$(echo "$${LATEST#v}" | cut -d. -f1); \
		MINOR=$$(echo "$${LATEST#v}" | cut -d. -f2); \
		PATCH=$$(echo "$${LATEST#v}" | cut -d. -f3); \
		if [ "$$BUMP" = "minor" ]; then \
			MINOR=$$((MINOR + 1)); PATCH=0; \
		else \
			PATCH=$$((PATCH + 1)); \
		fi; \
		NEW="v$${MAJOR}.$${MINOR}.$${PATCH}"; \
	fi; \
	echo "$$LATEST -> $$NEW ($$BUMP)"; \
	git tag "$$NEW" && git push origin "$$NEW"

beta: ## Build and upload to TestFlight via Fastlane
	bundle exec fastlane beta

beta-local: ## Build and upload to TestFlight with Screen Time entitlements (loads .env.local)
	@sed -i '' 's|\.NoScreenTime\.entitlements|.entitlements|g' Odyssey.xcodeproj/project.pbxproj; \
	trap 'git checkout -- Odyssey.xcodeproj/project.pbxproj' EXIT; \
	if [ -f .env.local ]; then set -a; . ./.env.local; set +a; fi; \
	bundle exec fastlane beta

beta-local-no-screen: ## Build and upload to TestFlight without Screen Time entitlements (loads .env.local)
	@if [ -f .env.local ]; then set -a; . ./.env.local; set +a; fi; \
	bundle exec fastlane beta

release: ## Build and submit to App Store via Fastlane
	bundle exec fastlane release

release-local: ## Build and submit to App Store with Screen Time entitlements (loads .env.local)
	@sed -i '' 's|\.NoScreenTime\.entitlements|.entitlements|g' Odyssey.xcodeproj/project.pbxproj; \
	trap 'git checkout -- Odyssey.xcodeproj/project.pbxproj' EXIT; \
	if [ -f .env.local ]; then set -a; . ./.env.local; set +a; fi; \
	bundle exec fastlane release

release-local-no-screen: ## Build and submit to App Store without Screen Time entitlements (loads .env.local)
	@if [ -f .env.local ]; then set -a; . ./.env.local; set +a; fi; \
	bundle exec fastlane release

match-appstore: ## Sync App Store signing certificates
	bundle exec fastlane match appstore

match-development: ## Sync development signing certificates
	bundle exec fastlane match development

match-force-local: ## Force-regenerate App Store profiles from local machine (loads .env.local)
	@if [ -f .env.local ]; then set -a; . ./.env.local; set +a; fi; \
	bundle exec fastlane match appstore --force

screenshots: ## Capture App Store screenshots via Fastlane
	bundle exec fastlane screenshots

appstore: ## Generate all App Store assets (iPhone + Watch screenshots, metadata, gallery)
	./scripts/appstore-assets.sh

appstore-iphone: ## Generate iPhone App Store screenshots only
	./scripts/appstore-assets.sh --iphone

appstore-watch: ## Generate Apple Watch App Store screenshots only
	./scripts/appstore-assets.sh --watch

# --- Demo Recording ---

demo: ## Record a demo video of the app (saved to build/demos/)
	./scripts/record-demo.sh --dropbox

demo-pr: ## Record demo video and post to a PR (usage: make demo-pr PR=42)
	@if [ -z "$(PR)" ]; then echo "Usage: make demo-pr PR=<number>"; exit 1; fi
	./scripts/record-demo.sh --dropbox --pr $(PR)

website-install: ## Install website dependencies
	cd website && npm install

website-dev: ## Start website dev server
	cd website && npm run dev

website-build: ## Build website for production (static export)
	cd website && npm run build

# --- Widget Screenshots ---

widget-screenshots: ## Render widget screenshots to build/widget-screenshots/
	./scripts/widget-screenshots.sh

widget-screenshots-pr: ## Render widget screenshots and post to a PR (usage: make widget-screenshots-pr PR=42)
	@if [ -z "$(PR)" ]; then echo "Usage: make widget-screenshots-pr PR=<number>"; exit 1; fi
	./scripts/widget-screenshots.sh --dropbox --pr $(PR)
