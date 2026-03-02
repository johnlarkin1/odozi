PROJECT = Odyssey.xcodeproj
SCHEME = Odyssey
CONFIG_DEBUG = Debug
CONFIG_RELEASE = Release

# Default destination — override with: make build DESTINATION='platform=iOS,name=MyiPhone'
DESTINATION ?= platform=iOS Simulator,name=iPhone 16

# Backend server
SERVER_DIR = odyssey-server
SERVER_PORT ?= 8080

.PHONY: help setup-simulator run run-app run-server stop-server build build-release test test-unit test-ui clean resolve lint update-secret-template beta release match-appstore match-development

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
	xcrun simctl boot "iPhone 16" 2>/dev/null || true; \
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
	xcrun simctl boot "iPhone 16" 2>/dev/null || true
	open -a Simulator
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) -destination '$(DESTINATION)' -derivedDataPath build build
	xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Odyssey.app
	xcrun simctl launch booted com.johnlarkin.Odyssey

run-server: ## Start the Rust backend server
	cd $(SERVER_DIR) && cargo run

stop-server: ## Stop any running backend server on SERVER_PORT
	@lsof -ti :$(SERVER_PORT) | xargs kill 2>/dev/null && echo "Stopped server on port $(SERVER_PORT)" || echo "No server running on port $(SERVER_PORT)"

build: ## Build debug configuration
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) -destination '$(DESTINATION)' build

build-release: ## Build release configuration
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_RELEASE) -destination '$(DESTINATION)' build

test: ## Run all tests (unit + UI)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' test

test-unit: ## Run unit tests only
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -only-testing:OdysseyTests test

test-ui: ## Run UI tests only
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -only-testing:OdysseyUITests test

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

beta: ## Build and upload to TestFlight via Fastlane
	bundle exec fastlane beta

release: ## Build and submit to App Store via Fastlane
	bundle exec fastlane release

match-appstore: ## Sync App Store signing certificates
	bundle exec fastlane match appstore

match-development: ## Sync development signing certificates
	bundle exec fastlane match development
