# 제품 앱을 변경하지 않고 설치된 앱을 조작하는 독립 XCTest 러너.
require 'xcodeproj'
require 'fileutils'

source = File.expand_path(__dir__)
output = File.expand_path('../../build/ios-live-store-20261029/project', source)
FileUtils.mkdir_p(output)
host_source = File.join(output, 'Host.swift')
File.write(host_source, "import SwiftUI\n@main struct CaptureHost: App { var body: some Scene { WindowGroup { Text(\"촬영 제어\") } } }\n")
project = Xcodeproj::Project.new(File.join(output, 'AppCapture.xcodeproj'))
host = project.new_target(:application, 'CaptureHost', :ios, '17.0')
tests = project.new_target(:ui_test_bundle, 'AppCaptureTests', :ios, '17.0')
group = project.main_group.new_group('촬영 제어')
host.source_build_phase.add_file_reference(group.new_file(host_source))
tests.source_build_phase.add_file_reference(group.new_file(File.join(source, 'CaptureTests.swift')))
tests.add_dependency(host)
[host, tests].each do |target|
  target.build_configurations.each do |configuration|
    s = configuration.build_settings
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['CODE_SIGN_IDENTITY'] = '-'
    s['CODE_SIGNING_ALLOWED'] = 'YES'
    s['CODE_SIGN_STYLE'] = 'Manual'
    s['GENERATE_INFOPLIST_FILE'] = 'YES'
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "com.codesoha.weathercare.appcapture.#{target.name.downcase}"
    s['MARKETING_VERSION'] = '1.0'
    s['CURRENT_PROJECT_VERSION'] = '1'
    s['SUPPORTED_PLATFORMS'] = 'iphonesimulator'
    if target == host
      s['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
      s['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
    else
      s['TEST_TARGET_NAME'] = host.name
    end
  end
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(host)
scheme.add_test_target(tests)
scheme.set_launch_target(host)
scheme.save_as(project.path, 'AppCapture', true)
puts project.path
