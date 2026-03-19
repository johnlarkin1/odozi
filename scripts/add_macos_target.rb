#!/usr/bin/env ruby
# Adds the OdysseyMac macOS target to the Xcode project.
# Shares relevant source files with the iOS target.

require 'xcodeproj'
require 'set'

PROJECT_PATH = File.join(__dir__, '..', 'Odyssey.xcodeproj')
project = Xcodeproj::Project.open(PROJECT_PATH)

# ── 1. Create macOS target ──────────────────────────────────────────
mac_target = project.new_target(:application, 'OdysseyMac', :osx, '14.0')
mac_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.johnlarkin.OdysseyMac'
  config.build_settings['PRODUCT_NAME'] = 'Odyssey'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'OdysseyMac/OdysseyMac.entitlements'
  config.build_settings['INFOPLIST_FILE'] = ''
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['COMBINE_HIDPI_IMAGES'] = 'YES'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  # Ensure it uses new Swift concurrency
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
end

puts "Created OdysseyMac target"

# ── 2. Create OdysseyMac group and add macOS-only files ─────────────
mac_group = project.main_group.find_subpath('OdysseyMac') || project.main_group.new_group('OdysseyMac', 'OdysseyMac')

mac_only_files = [
  'OdysseyMac/OdysseyMacApp.swift',
  'OdysseyMac/MacMainView.swift',
]

mac_only_files.each do |path|
  file_ref = mac_group.new_file(File.basename(path))
  mac_target.source_build_phase.add_file_reference(file_ref)
end

# Add entitlements as resource (not compiled)
ent_ref = mac_group.new_file('OdysseyMac.entitlements')

puts "Added macOS-only files to project"

# ── 3. Define files to EXCLUDE from macOS target ────────────────────
# These are iOS-only files that should NOT be added to the macOS target.
excluded_files = Set.new([
  # iOS app entry point & delegate
  'OdysseyApp.swift',
  'OdysseyAppDelegate.swift',
  'ContentView.swift',         # iOS entry → MainTabView
  'MainTabView.swift',         # iOS TabView navigation

  # iOS-only services
  'HealthKitService.swift',
  'BackgroundSnapshotService.swift',
  'SnapshotScheduler.swift',
  'SharedDefaults.swift',
  'PhotoLibraryService.swift',
  'SingleLocationDelegate.swift',

  # Screen Time / DeviceActivity
  'ScreenTimeDataExtractor.swift',
  'ScreenTimeSelectAppsContentView.swift',
  'ScreenTimeSelectAppsModel.swift',
  'ScreenTimeReportView.swift',

  # Onboarding (iOS-specific permissions flow)
  'OnboardingFlowView.swift',
  'WelcomeCard.swift',
  'LocationPermissionCard.swift',
  'HealthPermissionCard.swift',
  'ScreenTimePermissionCard.swift',
  'NotificationPermissionCard.swift',
  'AccountCard.swift',
  'OnboardingCompletionCard.swift',
  'OnboardingNavigationBar.swift',

  # Widget-related
  'OdysseyWidgetBundle.swift',
  'MoodCheckInWidget.swift',
  'WidgetDataAccess.swift',
  'SmallMoodWidgetView.swift',
  'MediumMoodWidgetView.swift',
  'AccessoryMoodWidgetView.swift',
  'LogMoodIntent.swift',
])

# ── 4. Find iOS target to discover shared source files ──────────────
ios_target = project.targets.find { |t| t.name == 'Odyssey' }
abort("Cannot find iOS 'Odyssey' target") unless ios_target

# ── 5. Add shared files to macOS target ─────────────────────────────
shared_count = 0
ios_target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  next unless file_ref.respond_to?(:path)

  filename = File.basename(file_ref.path || '')
  next if excluded_files.include?(filename)
  next unless filename.end_with?('.swift')

  # Skip files already in the macOS target
  already_added = mac_target.source_build_phase.files.any? { |bf|
    bf.file_ref && bf.file_ref.path == file_ref.path
  }
  next if already_added

  mac_target.source_build_phase.add_file_reference(file_ref)
  shared_count += 1
end

puts "Added #{shared_count} shared Swift files to OdysseyMac target"

# ── 6. Add resource files (assets, Lottie JSON, etc.) ───────────────
resource_count = 0
ios_target.resources_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref

  filename = File.basename(file_ref.path || '')

  # Skip iOS-specific resources
  next if filename.include?('LaunchScreen')

  mac_target.resources_build_phase.add_file_reference(file_ref)
  resource_count += 1
end

puts "Added #{resource_count} resource files to OdysseyMac target"

# ── 7. Add SPM package dependencies to macOS target ─────────────────
# Find existing package product dependencies from iOS target
ios_target.package_product_dependencies.each do |dep|
  # Only add Lottie and ClerkKit (needed for auth)
  name = dep.product_name
  next unless ['Lottie', 'ClerkKit'].include?(name)

  new_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  new_dep.product_name = dep.product_name
  new_dep.package = dep.package
  mac_target.package_product_dependencies << new_dep

  puts "Added SPM dependency: #{name}"
end

# ── 8. Add a scheme for OdysseyMac ──────────────────────────────────
scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(mac_target, nil)
scheme.save_as(project.path, 'OdysseyMac')
puts "Created OdysseyMac scheme"

# ── 9. Save project ────────────────────────────────────────────────
project.save
puts "\nDone! OdysseyMac target added to #{PROJECT_PATH}"
puts "Run 'make build-mac' to build the macOS app."
