PROJECT = Odyssey.xcodeproj
SCHEME = Odyssey
CONFIG_DEBUG = Debug
CONFIG_RELEASE = Release

# Default destination — override with: make build DESTINATION='platform=iOS,name=MyiPhone'
DESTINATION ?= platform=iOS Simulator,name=iPhone 16

.PHONY: help build build-release test test-unit test-ui clean resolve lint

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

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
