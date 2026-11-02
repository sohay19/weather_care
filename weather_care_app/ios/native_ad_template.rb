require 'fileutils'

# 플러그인 캐시 원본을 보존하고 이번 앱 빌드에만 템플릿을 보정한다.
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

  # Flutter가 확보한 영역을 채운다. layoutSubviews마다 제약이 중복되지
  # 않도록 한 번만 연결하고 미디어 비율은 기존 XIB 제약에 맡긴다.
  wrapper = target.source_build_phase.files.find do |file|
    file.file_ref&.path&.end_with?('FLTNativeTemplateStyle.m')
  end
  raise '광고 템플릿 래퍼를 찾지 못했습니다.' unless wrapper

  original_wrapper = File.read(wrapper.file_ref.real_path, encoding: 'UTF-8')
  implementation = /@implementation FLTNativeTemplateViewWrapper\b.*?@end/m
  raise '광고 템플릿 래퍼 구현이 변경되었습니다.' unless original_wrapper.scan(implementation).length == 1

  layout = <<~OBJC
    @implementation FLTNativeTemplateViewWrapper

    - (void)setTemplateView:(GADTTemplateView *)templateView {
      if (_templateView == templateView) return;
      [_templateView removeFromSuperview];
      _templateView = templateView;
      if (!templateView) return;
      templateView.translatesAutoresizingMaskIntoConstraints = NO;
      [self addSubview:templateView];
      [NSLayoutConstraint activateConstraints:@[
        [templateView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [templateView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [templateView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [templateView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
      ]];
    }

    @end
  OBJC
  wrapper_path = File.join(directory, 'FLTNativeTemplateStyle.m')
  File.write(wrapper_path, original_wrapper.sub(implementation, layout.strip), encoding: 'UTF-8')
  wrapper.file_ref = target.project.main_group.new_file(wrapper_path)

  # 이미지 왼쪽에도 오른쪽과 같은 10pt를 두고, 제목 두 줄의 높이를 확보한다.
  resource = target.project.native_targets.flat_map { |pod| pod.resources_build_phase.files }.find do |file|
    file.file_ref&.path&.end_with?('GADTSmallTemplateView.xib')
  end
  raise '소형 광고 템플릿 리소스를 찾지 못했습니다.' unless resource

  original_xib = File.read(resource.file_ref.real_path, encoding: 'UTF-8')
  replacements = {
    'secondAttribute="leading" id="ISF-wz-Ozg"' => 'secondAttribute="leading" constant="10" id="ISF-wz-Ozg"',
    'firstAttribute="width" relation="lessThanOrEqual" secondItem="h2X-7h-r2O"' => 'firstAttribute="width" secondItem="h2X-7h-r2O"',
    'multiplier="1.3" id="Hdt-VV-9Kw"' => 'multiplier="1.8" id="Hdt-VV-9Kw"',
    'text="Headline" textAlignment="natural"' => 'text="Headline" textAlignment="natural" numberOfLines="2"'
  }
  replacements.each do |before, after|
    unless original_xib.scan(before).length + original_xib.scan(after).length == 1
      raise '소형 광고 템플릿 제약이 변경되었습니다. 레이아웃을 확인하세요.'
    end
    original_xib = original_xib.sub(before, after)
  end
  resource_path = File.join(directory, 'GADTSmallTemplateView.xib')
  File.write(resource_path, original_xib, encoding: 'UTF-8')
  resource.file_ref = target.project.main_group.new_file(resource_path)
end
