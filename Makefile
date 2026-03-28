PROJECT = Odyssey.xcodeproj
SCHEME = Odyssey
CONFIG_DEBUG = Debug
CONFIG_RELEASE = Release

# Default destination — override with: make build DESTINATION='platform=iOS,name=MyiPhone'
DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

# Backend server
SERVER_DIR = odyssey-server
SERVER_PORT ?= 8080

.PHONY: help setup-simulator run run-app preview run-server stop-server build build-release build-mac build-watch test test-unit test-ui build-widget clean resolve lint format fmt update-secret-template tag beta beta-local beta-local-no-screen release release-local release-local-no-screen match-appstore match-development match-force-local website-dev website-build website-install screenshots loadtest-keys loadtest loadtest-headless demo demo-pr widget-screenshots widget-screenshots-pr

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

run: ## Build and run iOS app + Rust backend (Ctrl+C stops both)
	@trap 'echo "\nStopping backend..."; kill $$SERVER_PID 2>/dev/null; exit 0' INT TERM; \
	lsof -ti :$(SERVER_PORT) | xargs kill 2>/dev/null; sleep 0.5; \
	xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true; \
	open -a Simulator; \
	echo "Starting backend server on port $(SERVER_PORT)..."; \
	(cd $(SERVER_DIR) && cargo run) & \
	SERVER_PID=$$!; \
	echo "Waiting for backend (PID $$SERVER_PID)..."; \
	for i in $$(seq 1 30); do \
		if curl -sf http://localhost:$(SERVER_PORT)/healthz > /dev/null 2>&1; then \
			echo "Backend ready on http://localhost:$(SERVER_PORT)"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "ERROR: Backend failed to start within 30s"; \
			kill $$SERVER_PID 2>/dev/null; \
			exit 1; \
		fi; \
		sleep 1; \
	done; \
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) \
		-destination '$(DESTINATION)' -derivedDataPath build \
		ODYSSEY_API_BASE_URL='http://localhost:$(SERVER_PORT)' build; \
	xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Odyssey.app; \
	xcrun simctl launch booted com.johnlarkin.Odyssey; \
	echo "App launched. Backend running (PID $$SERVER_PID). Ctrl+C to stop."; \
	wait $$SERVER_PID

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

run-server: ## Start the Rust backend server
	cd $(SERVER_DIR) && cargo run

stop-server: ## Stop any running backend server on SERVER_PORT
	@lsof -ti :$(SERVER_PORT) | xargs kill 2>/dev/null && echo "Stopped server on port $(SERVER_PORT)" || echo "No server running on port $(SERVER_PORT)"

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

lint: ## Lint Swift source files with SwiftLint
	swiftlint lint --strict

format: ## Format Swift source files with SwiftFormat
	swiftformat .

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

# --- Load Testing ---

LOADTEST_DIR = $(SERVER_DIR)/loadtests
LOADTEST_KEYS_DIR = $(LOADTEST_DIR)/keys
LOADTEST_PRIVATE_KEY = $(LOADTEST_KEYS_DIR)/test_private.pem
LOADTEST_PUBLIC_KEY = $(LOADTEST_KEYS_DIR)/test_public.pem

loadtest-keys: ## Generate RSA keypair for load testing
	cd $(LOADTEST_DIR) && python -m common.auth generate-keys

loadtest: ## Run Locust load test with web UI (auto-starts server if needed)
	@STARTED_SERVER=0; \
	if ! curl -sf http://localhost:$(SERVER_PORT)/healthz > /dev/null 2>&1; then \
		echo "Starting backend in load test mode on port $(SERVER_PORT)..."; \
		(cd $(SERVER_DIR) && \
			ODYSSEY_LOADTEST_PUBLIC_KEY_PATH=loadtests/keys/test_public.pem \
			ODYSSEY_LOADTEST_DISABLE_RATELIMIT=1 \
			cargo run) & \
		SERVER_PID=$$!; \
		STARTED_SERVER=1; \
		echo "Waiting for backend (PID $$SERVER_PID)..."; \
		for i in $$(seq 1 30); do \
			if curl -sf http://localhost:$(SERVER_PORT)/healthz > /dev/null 2>&1; then \
				echo "Backend ready on http://localhost:$(SERVER_PORT)"; \
				break; \
			fi; \
			if [ $$i -eq 30 ]; then \
				echo "ERROR: Backend failed to start within 30s"; \
				kill $$SERVER_PID 2>/dev/null; \
				exit 1; \
			fi; \
			sleep 1; \
		done; \
	else \
		echo "Backend already running on port $(SERVER_PORT)"; \
	fi; \
	trap 'echo "\nStopping..."; if [ $$STARTED_SERVER -eq 1 ]; then kill $$SERVER_PID 2>/dev/null; echo "Stopped backend"; fi; exit 0' INT TERM; \
	echo "Starting Locust web UI at http://localhost:8089 ..."; \
	cd $(LOADTEST_DIR) && locust -f locustfile.py --host http://localhost:$(SERVER_PORT); \
	if [ $$STARTED_SERVER -eq 1 ]; then kill $$SERVER_PID 2>/dev/null; fi

loadtest-headless: ## Run headless Locust load test (100 users, 10/s spawn, 60s)
	@STARTED_SERVER=0; \
	if ! curl -sf http://localhost:$(SERVER_PORT)/healthz > /dev/null 2>&1; then \
		echo "Starting backend in load test mode on port $(SERVER_PORT)..."; \
		(cd $(SERVER_DIR) && \
			ODYSSEY_LOADTEST_PUBLIC_KEY_PATH=loadtests/keys/test_public.pem \
			ODYSSEY_LOADTEST_DISABLE_RATELIMIT=1 \
			cargo run) & \
		SERVER_PID=$$!; \
		STARTED_SERVER=1; \
		echo "Waiting for backend (PID $$SERVER_PID)..."; \
		for i in $$(seq 1 30); do \
			if curl -sf http://localhost:$(SERVER_PORT)/healthz > /dev/null 2>&1; then \
				echo "Backend ready on http://localhost:$(SERVER_PORT)"; \
				break; \
			fi; \
			if [ $$i -eq 30 ]; then \
				echo "ERROR: Backend failed to start within 30s"; \
				kill $$SERVER_PID 2>/dev/null; \
				exit 1; \
			fi; \
			sleep 1; \
		done; \
	else \
		echo "Backend already running on port $(SERVER_PORT)"; \
	fi; \
	trap 'if [ $$STARTED_SERVER -eq 1 ]; then kill $$SERVER_PID 2>/dev/null; fi; exit 0' INT TERM; \
	cd $(LOADTEST_DIR) && locust -f locustfile.py \
		--host http://localhost:$(SERVER_PORT) \
		--headless -u 100 -r 10 -t 60s; \
	if [ $$STARTED_SERVER -eq 1 ]; then kill $$SERVER_PID 2>/dev/null; echo "Stopped backend"; fi

# --- Widget Screenshots ---

widget-screenshots: ## Render widget screenshots to build/widget-screenshots/
	./scripts/widget-screenshots.sh

widget-screenshots-pr: ## Render widget screenshots and post to a PR (usage: make widget-screenshots-pr PR=42)
	@if [ -z "$(PR)" ]; then echo "Usage: make widget-screenshots-pr PR=<number>"; exit 1; fi
	./scripts/widget-screenshots.sh --dropbox --pr $(PR)
