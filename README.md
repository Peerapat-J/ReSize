# ReSize

macOS app for Screenshot resize for App Store via GUI.

- Deployment target: macOS 14+
- Xcode 16+ support (build with Xcode 26.6)
- No external dependency.
- Local development build use ad-hoc signing as personal tool.

## Manual

1. Click **Open Images…** (`⌘O`) or drag your PNG/JPEG into main window.
2. Select Mac preset or **Custom**.
3. Drag crop window.
4. Switch view mode, **Source / Output** to check the result before export.
5. Click **Export…** (`⌘E`) / **Export All** (`⌘⇧E`), done.

| Mode | Description |
| --- | --- |
| Crop Only — Default | pixel size stay the same, your pic only cropped, no zoom in or out |
| Crop & Resize | Drag or use slider to select crop area and resize as set |
| Fit | Everything still the same but it will get exported to the size you set. |

Click at crop window and use arrow key to move 1px per key Stroke or press and hold Shift key + arrow key to move 10px. 

Use `⌘`/`Shift` to select multiple pics then **Apply Settings to Selected** to apply setting to selected pictures.

## File

- Support PNG/JPEG; 
- Export PNG/JPEG; only JPEG have 10–100%.
- Output are **8-bit sRGB no alpha channel**; Background color use both Fit and transparency area.
- Crop Only + PNG not resample and use lossless compress but converting color profile, bit depth and filling background may change color value, so can't comfirm the file will be the same as original every byte.
- Output Preview read back from encoded data then show compress result with JPEG.
- Limit output at 60 megapixels and 16,384 px per side.
- Duplicate file name, number will be added at the end, the exit file will not be replaced.
- If source file is change during or after opened, re-open source file is needed before export.
- Cancling export will save the finished file and skip the rest.

Mac preset: 1280 × 800, 1440 × 900, 2560 × 1600, 2880 × 1800 (16:10)


## note to myself

[Screenshot specifications from Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)


```sh
./scripts/test.sh
swiftlint lint --no-cache
git diff --check
```

สร้างภาพตัวอย่างสำหรับลอง GUI ด้วย `swift scripts/make-fixtures.swift` ไฟล์จะอยู่ใน `/private/tmp/resize-fixtures` รายการตรวจด้วยตนเองอยู่ที่ [docs/QA.md](docs/QA.md)

อ่านโครงสร้างและเหตุผลของการประมวลผลได้ที่ [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) และขอบเขตรุ่นแรกที่ [docs/PLAN.md](docs/PLAN.md)

รุ่นนี้ยังไม่บันทึก session ข้ามการปิดแอป ยังไม่รองรับวิดีโอ App Preview, HEIC/TIFF/WebP, preset iPhone/iPad หรือการใส่ข้อความและกรอบอุปกรณ์
