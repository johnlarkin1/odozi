PROJECT = Odyssey.xcodeproj
SCHEME = Odyssey
CONFIG_DEBUG = Debug
CONFIG_RELEASE = Release

# Default destination — override with: make build DESTINATION='platform=iOS,name=MyiPhone'
DESTINATION ?= platform=iOS Simulator,name=iPhone 16

.PHONY: help setup-simulator run build build-release test test-unit test-ui clean resolve lint

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

run: ## Build and run on iOS Simulator
	xcrun simctl boot "iPhone 16" 2>/dev/null || true
	open -a Simulator
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) -destination '$(DESTINATION)' -derivedDataPath build build
	xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Odyssey.app
	xcrun simctl launch booted com.johnlarkin.Odyssey

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

clean: ## Clean build artifacts
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf DerivedData build

resolve: ## Resolve Swift package dependencies
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -resolvePackageDependencies
