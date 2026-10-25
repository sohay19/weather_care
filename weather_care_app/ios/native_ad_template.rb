require 'fileutils'

# 플러그인 캐시 원본을 보존하고 이번 앱 빌드에만 테두리 없는 템플릿을 사용한다.
def remove_native_ad_template_border(target, pods_root)
  source = target.source_build_phase.files.find do |file|
    file.file_ref&.path&.end_with?('GADTTemplateView.m')
  end
  raise '광고 템플릿 소스를 찾지 못했습니다.' unless source

  original = File.read(source.file_ref.real_path, encoding: 'UTF-8')
  border = 'self.layer.borderWidth = 1.0f;'
  borderless = 'self.layer.borderWidth = 0.0f;'
  unless original.scan(border).length + original.scan(borderless).length == 1
    raise '광고 템플릿 테두리 구현이 변경되었습니다. 적용 경로를 확인하세요.'
  end

  directory = File.join(pods_root, 'WeatherCareNativeAds')
  FileUtils.mkdir_p(directory)
  path = File.join(directory, 'GADTTemplateView.m')
  File.write(path, original.sub(border, borderless), encoding: 'UTF-8')
  # 플러그인의 기존 헤더/리소스 참조는 두고 컴파일할 소스만 교체한다.
  source.file_ref = target.project.main_group.new_file(path)
end
