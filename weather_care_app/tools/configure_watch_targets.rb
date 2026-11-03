require 'xcodeproj'
require 'fileutils'
require 'json'

# 기존 Runner/위젯 설정을 유지하면서 watchOS 타깃과 리소스만 추가한다.
ios = File.expand_path('../ios', __dir__)
project = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' }
watch = project.targets.find { |t| t.name == 'WeatherCareWatch' } || project.new_target(:application, 'WeatherCareWatch', :watchos, '10.0')
widgets = project.targets.find { |t| t.name == 'WeatherCareWatchWidgets' } || project.new_target(:app_extension, 'WeatherCareWatchWidgets', :watchos, '10.0')

def group(project, name)
  project.main_group.find_subpath(name, true).tap { |g| g.path = name }
end
def source(target, group, file)
  ref = group.files.find { |f| f.path == file } || group.new_file(file)
  target.source_build_phase.add_file_reference(ref, true)
end
def resource(target, group, file)
  ref = group.files.find { |f| f.path == file } || group.new_file(file)
  target.resources_build_phase.add_file_reference(ref, true)
end

shared = group(project, 'WatchShared')
watch_group = group(project, 'WeatherCareWatch')
widget_group = group(project, 'WeatherCareWatchWidgets')
source(runner, project.main_group.find_subpath('Runner'), 'WatchPhoneBridge.swift')
%w[WatchSnapshot.swift WatchWeatherIcon.swift].each { |f| [watch, widgets].each { |t| source(t, shared, f) } }
%w[WeatherCareWatchApp.swift WatchStore.swift].each { |f| source(watch, watch_group, f) }
source(widgets, widget_group, 'WeatherCareWatchWidgets.swift')
[watch, widgets].each do |target|
  resource(target, shared, 'Assets.xcassets')
  resource(target, shared, 'SUITE-OFL.txt')
  fonts = project.main_group.find_subpath('WeatherCareWidget/Fonts', true)
  fonts.path = 'Fonts'
  %w[SUITE-Regular.ttf SUITE-ExtraBold.ttf].each { |f| resource(target, fonts, f) }
  target.build_configurations.each do |configuration|
    s = configuration.build_settings
    s['SDKROOT'] = 'watchos'
    s['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
    s['TARGETED_DEVICE_FAMILY'] = '4'
    s['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
    s['SWIFT_VERSION'] = '5.0'
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['DEVELOPMENT_TEAM'] = 'M7QY569K4A'
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['INFOPLIST_FILE'] = target.name + '/Info.plist'
    s['CODE_SIGN_ENTITLEMENTS'] = target.name + '/' + target.name + '.entitlements'
    s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.codesoha.weathercare.watchkitapp' + (target == widgets ? '.widgets' : '')
    s['PRODUCT_NAME'] = target.name
    s['PRODUCT_MODULE_NAME'] = target.name
    s['SKIP_INSTALL'] = 'YES'
    phone_settings = runner.build_configurations.find { |c| c.name == configuration.name }.build_settings
    s['MARKETING_VERSION'] = phone_settings['MARKETING_VERSION']
    s['CURRENT_PROJECT_VERSION'] = phone_settings['CURRENT_PROJECT_VERSION']
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) DEBUG' if configuration.name == 'Debug'
    s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon' if target == watch
    s['APPLICATION_EXTENSION_API_ONLY'] = 'YES' if target == widgets
  end
end

runner.add_dependency(watch) unless runner.dependencies.any? { |d| d.target == watch }
watch.add_dependency(widgets) unless watch.dependencies.any? { |d| d.target == widgets }
embed_watch = runner.copy_files_build_phases.find { |p| p.name == 'Embed Watch Content' } || runner.new_copy_files_build_phase('Embed Watch Content')
embed_watch.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
embed_watch.dst_subfolder_spec = '16'
embed_watch.add_file_reference(watch.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# Flutter의 Thin Binary가 완성된 앱 번들을 입력으로 읽으므로 먼저 삽입한다.
runner.build_phases.delete(embed_watch)
thin = runner.build_phases.find { |phase| phase.display_name == 'Thin Binary' }
runner.build_phases.insert(thin ? runner.build_phases.index(thin) : runner.build_phases.length, embed_watch)
embed_widget = watch.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' } || watch.new_copy_files_build_phase('Embed App Extensions')
embed_widget.dst_subfolder_spec = '13'
embed_widget.add_file_reference(widgets.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(watch)
scheme.set_launch_target(watch)
scheme.save_as(File.join(ios, 'Runner.xcodeproj'), 'WeatherCareWatch', true)
puts 'watchOS 앱·WidgetKit 타깃 추가 완료'
