import UIKit
import XCTest
import google_mobile_ads

@MainActor
final class NativeAdLayoutTests: XCTestCase {
  private func template(_ type: Int32, width: CGFloat, height: CGFloat) -> FLTNativeTemplateViewWrapper {
    let view = FLTNativeTemplateType(int: type).templateView()
    view.styles = [.primaryFont: UIFont.boldSystemFont(ofSize: 14)]
    (view.headlineView as? UILabel)?.text = "한글과 English가 함께 있는 두 줄 광고 제목을 확인합니다"
    (view.advertiserView as? UILabel)?.text = "광고주"
    view.storeView?.isHidden = true
    view.starRatingView?.isHidden = true
    (view.bodyView as? UILabel)?.text = "광고 설명"
    view.mediaView?.backgroundColor = .systemGray5
    (view.callToActionView as? UIButton)?.setTitle("설치", for: .normal)
    let wrapper = FLTNativeTemplateViewWrapper(frame: CGRect(x: 0, y: 0, width: width, height: height))
    wrapper.templateView = view
    wrapper.setNeedsLayout()
    wrapper.layoutIfNeeded()
    return wrapper
  }

  private func attachPreview(_ wrapper: UIView, name: String) {
    let image = UIGraphicsImageRenderer(bounds: wrapper.bounds).image {
      wrapper.layer.render(in: $0.cgContext)
    }
    let attachment = XCTAttachment(image: image)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testSmallTemplateFillsCardAndCentersAssetsAtNarrowAndScaledSizes() throws {
    for width: CGFloat in [304, 344, 384] {
      for height: CGFloat in [120, 180] {
        let wrapper = template(0, width: width, height: height)
        let view = try XCTUnwrap(wrapper.templateView)
        XCTAssertEqual(view.frame, wrapper.bounds)
        let media = try XCTUnwrap(view.mediaView)
        let button = try XCTUnwrap(view.callToActionView)
        let mediaFrame = media.convert(media.bounds, to: wrapper)
        let buttonFrame = button.convert(button.bounds, to: wrapper)
        XCTAssertEqual(mediaFrame.minX, 10, accuracy: 0.5)
        XCTAssertEqual(mediaFrame.width, width * 0.25, accuracy: 0.5)
        XCTAssertEqual(width - buttonFrame.maxX, 10, accuracy: 0.5)
        XCTAssertEqual(mediaFrame.midY, height / 2, accuracy: 0.5)
        let headline = try XCTUnwrap(view.headlineView as? UILabel)
        let headlineFrame = headline.convert(headline.bounds, to: wrapper)
        XCTAssertEqual(headlineFrame.minY, 10, accuracy: 0.5)
        XCTAssertEqual(height - buttonFrame.maxY, 10, accuracy: 0.5)
        XCTAssertEqual(headline.numberOfLines, 2)
        XCTAssertGreaterThanOrEqual(headline.bounds.height + 0.5, headline.font.lineHeight * 2)
        XCTAssertGreaterThanOrEqual(button.bounds.height, 30)
        if width == 344 && height == 120 {
          attachPreview(wrapper, name: "소형 광고 한글 두 줄 배치")
        }
        let count = wrapper.constraints.count
        wrapper.frame.size.width += 8
        for _ in 0..<5 {
          wrapper.setNeedsLayout()
          wrapper.layoutIfNeeded()
        }
        XCTAssertEqual(wrapper.constraints.count, count)
        XCTAssertEqual(view.frame, wrapper.bounds)
        XCTAssertFalse(view.hasAmbiguousLayout)
      }
    }
  }

  func testMediumTemplateFillsCardAndPreservesMediaAspectRatio() throws {
    let wrapper = template(1, width: 336, height: 336)
    let view = try XCTUnwrap(wrapper.templateView)
    XCTAssertEqual(view.frame, wrapper.bounds)
    let media = try XCTUnwrap(view.mediaView)
    XCTAssertEqual(media.bounds.width / media.bounds.height, 16 / 9, accuracy: 0.01)
    XCTAssertFalse(view.hasAmbiguousLayout)
    attachPreview(wrapper, name: "중형 광고 배치")
  }
}
