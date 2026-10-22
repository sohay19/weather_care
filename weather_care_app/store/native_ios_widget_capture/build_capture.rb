# 현재 WidgetKit 소스와 자산을 그대로 컴파일하는 독립 촬영 프로젝트.
require 'xcodeproj'
require 'fileutils'
require 'json'

source = File.expand_path(__dir__)
app_root = File.expand_path('../..', source)
output = File.join(app_root, 'build/ios-native-widget-20261022/project')
FileUtils.mkdir_p(output)
widget_root = File.join(app_root, 'ios/WeatherCareWidget')
project = Xcodeproj::Project.new(File.join(output, 'WidgetCapture.xcodeproj'))
host = project.new_target(:application, 'CaptureHost', :ios, '17.0')
widget = project.new_target(:app_extension, 'WeatherCareWidget', :ios, '17.0')
tests = project.new_target(:ui_test_bundle, 'CaptureTests', :ios, '17.0')
group = project.main_group.new_group('촬영 소스')
host.source_build_phase.add_file_reference(group.new_file(File.join(source, 'Host.swift')))
tests.source_build_phase.add_file_reference(group.new_file(File.join(source, 'CaptureTests.swift')))
%w[WeatherCareWidget.swift WidgetRefreshIntent.swift].each do |name|
  widget.source_build_phase.add_file_reference(group.new_file(File.join(widget_root, name)))
end
Dir.glob(File.join(widget_root, 'Fonts/*.ttf')).each do |path|
  widget.resources_build_phase.add_file_reference(group.new_file(path))
end
icons = group.new_file(File.join(widget_root, 'Icons'))
icons.last_known_file_type = 'folder'
widget.resources_build_phase.add_file_reference(icons)
embed = host.new_copy_files_build_phase('위젯 확장 포함')
embed.dst_subfolder_spec = '13'
embed.add_file_reference(widget.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
host.add_dependency(widget)
tests.add_dependency(host)
entitlements = File.join(widget_root, 'WeatherCareWidget.entitlements')
[host, widget, tests].each do |target|
  target.build_configurations.each do |config|
    s = config.build_settings
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['CODE_SIGN_IDENTITY'] = '-'
    s['CODE_SIGN_STYLE'] = 'Manual'
    s['CODE_SIGNING_ALLOWED'] = 'YES'
    s['GENERATE_INFOPLIST_FILE'] = 'YES'
    s['MARKETING_VERSION'] = '1.0'
    s['CURRENT_PROJECT_VERSION'] = '1'
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "com.codesoha.weathercare.capture.#{target.name.downcase}"
    s['SUPPORTED_PLATFORMS'] = 'iphonesimulator'
    s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    s['INFOPLIST_KEY_CFBundleDisplayName'] = '날씨챙겨 촬영'
    if target == widget
      s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.codesoha.weathercare.capture.capturehost.widget'
      s['INFOPLIST_FILE'] = File.join(widget_root, 'Info.plist')
      s['GENERATE_INFOPLIST_FILE'] = 'NO'
      s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      s['SKIP_INSTALL'] = 'YES'
    elsif target == host
      s['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
      s['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
    else
      s['TEST_TARGET_NAME'] = host.name
    end
    s['CODE_SIGN_ENTITLEMENTS'] = entitlements unless target == tests
  end
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(host)
scheme.add_test_target(tests)
scheme.set_launch_target(host)
scheme.save_as(project.path, 'Capture', true)
puts project.path
