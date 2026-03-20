#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates the OdysseyWatch target in the Xcode project.
# Usage: ruby scripts/add-watch-target.rb
#
# This script:
# 1. Creates a watchOS app target (OdysseyWatch)
# 2. Adds all OdysseyWatch/*.swift source files
# 3. Adds shared source files from the Odyssey target
# 4. Configures the watch asset catalog
# 5. Sets build settings (entitlements, bundle ID, deployment target, etc.)
# 6. Embeds the watch app in the main Odyssey target

require 'xcodeproj'

PROJECT_PATH = 'Odyssey.xcodeproj'
WATCH_DIR = 'OdysseyWatch'
BUNDLE_ID = 'com.johnlarkin.Odyssey.watchkitapp'
DEPLOYMENT_TARGET = '10.0'
DEV_TEAM = 'P3Q6VLD666'

# Shared files from the Odyssey target that the watch needs
SHARED_FILE_NAMES = %w[
  DailyEntry.swift
  DataContainer.swift
  DailyEntryRepository.swift
  UserPreferences.swift
  Color+Extensions.swift
  UIColor+Extensions.swift
  PlatformColor.swift
  APIClient.swift
  EncryptionService.swift
  HealthKitService.swift
  SharedDefaults.swift
].freeze

proj = Xcodeproj::Project.open(PROJECT_PATH)

# Guard: don't create if it already exists
if proj.targets.any? { |t| t.name == 'OdysseyWatch' }
  puts 'OdysseyWatch target already exists — skipping.'
  exit 0
end

main_target = proj.targets.find { |t| t.name == 'Odyssey' }
abort 'Could not find main Odyssey target' unless main_target

# --- 1. Create the watch target ---
watch_target = proj.new_target(
  :application,
  'OdysseyWatch',
  :watchos,
  DEPLOYMENT_TARGET
)

puts "Created target: #{watch_target.name}"

# --- 2. Create file group for OdysseyWatch ---
watch_group = proj.main_group.new_group('OdysseyWatch', WATCH_DIR)

# Add Complications subgroup
complications_group = watch_group.new_group('Complications', 'Complications')

# Add source files
watch_swift_files = Dir.glob("#{WATCH_DIR}/*.swift").sort
complications_files = Dir.glob("#{WATCH_DIR}/Complications/*.swift").sort

watch_swift_files.each do |path|
  file_name = File.basename(path)
  ref = watch_group.new_reference(file_name)
  watch_target.source_build_phase.add_file_reference(ref)
  puts "  Added source: #{path}"
end

complications_files.each do |path|
  file_name = File.basename(path)
  ref = complications_group.new_reference(file_name)
  watch_target.source_build_phase.add_file_reference(ref)
  puts "  Added source: #{path}"
end

# --- 3. Add asset catalog ---
assets_ref = watch_group.new_reference('Assets.xcassets')
assets_ref.last_known_file_type = 'folder.assetcatalog'
watch_target.resources_build_phase.add_file_reference(assets_ref)
puts "  Added asset catalog: #{WATCH_DIR}/Assets.xcassets"

# --- 4. Add shared files from Odyssey target ---
shared_refs = []
main_target.source_build_phase.files.each do |build_file|
  ref = build_file.file_ref
  next unless ref

  name = ref.path || ref.name
  next unless name
  next unless SHARED_FILE_NAMES.any? { |s| name == s }

  shared_refs << ref
end

shared_refs.each do |ref|
  watch_target.source_build_phase.add_file_reference(ref)
  puts "  Added shared: #{ref.real_path.relative_path_from(Pathname.pwd)}"
end

# --- 5. Configure build settings ---
common_settings = {
  'PRODUCT_BUNDLE_IDENTIFIER' => BUNDLE_ID,
  'PRODUCT_NAME' => 'OdysseyWatch',
  'SDKROOT' => 'watchos',
  'WATCHOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
  'TARGETED_DEVICE_FAMILY' => '4', # Watch
  'SUPPORTED_PLATFORMS' => 'watchos watchsimulator',
  'SUPPORTS_MACCATALYST' => 'NO',
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => DEV_TEAM,
  'CODE_SIGN_ENTITLEMENTS' => "#{WATCH_DIR}/OdysseyWatch.entitlements",
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'INFOPLIST_KEY_WKCompanionAppBundleIdentifier' => 'com.johnlarkin.Odyssey',
  'INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp' => 'YES',
  'CURRENT_PROJECT_VERSION' => '1',
  'MARKETING_VERSION' => '1.0',
  'SWIFT_VERSION' => '5.0',
  'SWIFT_EMIT_LOC_STRINGS' => 'YES',
  'SWIFT_STRICT_CONCURRENCY' => 'complete',
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  'INFOPLIST_KEY_CFBundleDisplayName' => 'Odyssey',
}

watch_target.build_configurations.each do |config|
  config.build_settings.merge!(common_settings)

  # Remove iOS-specific settings that new_target may have set
  config.build_settings.delete('IPHONEOS_DEPLOYMENT_TARGET')
  config.build_settings.delete('SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD')

  if config.name == 'Debug'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = ['DEBUG']
  else
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
    config.build_settings['COPY_PHASE_STRIP'] = 'NO'
  end
end

puts '  Configured build settings'

# --- 6. Embed watch app in main Odyssey target ---
# Add dependency
main_target.add_dependency(watch_target)
puts "  Added dependency: Odyssey -> OdysseyWatch"

# Create "Embed Watch Content" copy phase
embed_phase = main_target.new_copy_files_build_phase('Embed Watch Content')
embed_phase.dst_subfolder_spec = '16' # Products Directory (watchOS apps use this)
embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'

watch_product_ref = watch_target.product_reference
build_file = embed_phase.add_file_reference(watch_product_ref)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
puts '  Added embed watch content phase'

# --- 7. Save ---
proj.save
puts "\nDone! OdysseyWatch target created successfully."
puts "Next: open Xcode and verify with 'make build-watch'"
