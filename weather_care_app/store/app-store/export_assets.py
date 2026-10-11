"""생성 원본을 App Store 등록 크기의 불투명 PNG로 내보낸다."""

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image


ROOT = Path(__file__).resolve().parent
ASSETS = (
    ("header.png", "header-3840x1646.png", (3840, 1646)),
    ("search-results.png", "search-results-1920x1280.png", (1920, 1280)),
)


def main() -> None:
    for source, filename, size in ASSETS:
        with Image.open(ROOT / "source" / source) as image:
            # 구성·문구는 생성 도구에서 완성했으며 여기서는 크기만 정규화한다.
            image = image.convert("RGB").resize(size, Image.Resampling.LANCZOS)
            image.save(ROOT / filename, format="PNG", optimize=True)
        with Image.open(ROOT / filename) as exported:
            if exported.size != size or exported.mode != "RGB":
                raise ValueError(f"등록 규격 불일치: {filename}")
            exported.verify()
        print(f"검증 완료: {filename} / {size[0]}×{size[1]} / RGB PNG")

    archive_path = ROOT / "weather-care-app-store-creative-assets.zip"
    with ZipFile(archive_path, "w", compression=ZIP_DEFLATED) as archive:
        for _, filename, _ in ASSETS:
            archive.write(ROOT / filename, filename)
        archive.write(ROOT / "README.md", "등록안내.md")
    with ZipFile(archive_path) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP 파일 검증 실패")
    print(f"묶음 파일 검증 완료: {archive_path.name}")


if __name__ == "__main__":
    main()
