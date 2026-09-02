# ReSize

แอป macOS สำหรับเตรียมภาพ Screenshot ก่อนส่งขึ้น App Store เปิดรูป จัดกรอบ ดูผลลัพธ์ และ Export ผ่าน GUI ทั้งหมด ประมวลผลในเครื่อง

## เปิดใช้งาน

เปิด `ReSize.xcodeproj` ใน Xcode เลือก scheme **ReSize** และกด Run

หรือ build ด้วย `./scripts/build.sh` แล้วเปิด `build/DerivedData/Build/Products/Debug/ReSize.app` ได้จาก Finder โดยตรง หลังจาก build แล้ว การใช้แอปไม่ต้องเปิด Terminal

- Deployment target: macOS 14 ขึ้นไป
- Xcode 16 ขึ้นไปสำหรับเปิดโครงสร้างโปรเจกต์ (ตรวจ build ด้วย Xcode 26.6)
- ไม่มี dependency ภายนอก
- แอปนี้เป็น local development build ใช้ ad-hoc signing ยังไม่ได้ notarize สำหรับแจกจ่าย

## วิธีใช้

1. กด **Open Images…** (`⌘O`) หรือลาก PNG/JPEG ลงหน้าต่าง
2. เลือก Mac preset หรือ **Custom** เพื่อกรอกขนาดและล็อกสัดส่วนเอง
3. เลือกวิธีจัดภาพ แล้วเลื่อนกรอบบนภาพต้นฉบับ
4. สลับ **Source / Output** เพื่อตรวจผลลัพธ์ เลือก **100%** สำหรับดูหนึ่งพิกเซลภาพต่อหนึ่งพิกเซลจอ
5. กด **Export…** (`⌘E`) เพื่อบันทึกสำเนาใหม่ หรือ **Export All** (`⌘⇧E`) สำหรับทุกภาพ

| โหมด | การทำงาน |
| --- | --- |
| Crop Only — ค่าเริ่มต้น | กรอบขนาดพิกเซลคงที่ ตัดอย่างเดียว ไม่มีการย่อหรือขยาย |
| Crop & Resize | ลากมุมกรอบหรือใช้ slider เพื่อเลือกพื้นที่ แล้วปรับให้ตรงขนาดปลายทาง |
| Fit | เก็บภาพครบ รักษาสัดส่วน และเติมพื้นที่ว่างด้วยสีพื้นหลัง |

คลิกในกรอบก่อนใช้ปุ่มลูกศรเพื่อขยับครั้งละ 1 px หรือกด Shift ค้างเพื่อขยับ 10 px ปุ่ม **Center** จัดกึ่งกลาง ส่วน **Reset** คืนตำแหน่งและพื้นที่ crop การซูมดูภาพไม่เปลี่ยนกรอบหรือไฟล์ที่จะส่งออก

ใช้ `⌘`/`Shift` เลือกหลายภาพในรายการด้านซ้าย แล้ว **Apply Settings to Selected** เพื่อใช้ค่าร่วมกัน แอปเก็บตำแหน่งและขนาดกรอบของแต่ละภาพไว้ จึงควรตรวจกรอบทีละภาพก่อน Export

## ไฟล์และคุณภาพ

- รับ PNG/JPEG; อ่านทิศทาง EXIF ก่อนคำนวณขนาดและตำแหน่ง
- Export PNG หรือ JPEG; JPEG มีตัวเลือกคุณภาพ 10–100%
- Output เป็น **8-bit sRGB ไม่มี alpha channel**; สีพื้นหลังใช้ทั้งกับ Fit และบริเวณโปร่งใส
- Crop Only + PNG ไม่ resample และใช้การบีบอัดแบบ lossless แต่การแปลง color profile, bit depth และการเติมพื้นหลังยังอาจเปลี่ยนค่าสีได้ จึงไม่ได้รับประกันว่าไฟล์จะเหมือนต้นฉบับทุกไบต์
- Output Preview อ่านกลับจากข้อมูลที่ encode แล้ว จึงแสดงผลการบีบอัด JPEG ด้วย
- จำกัดภาพและ output ไม่เกิน 60 megapixels และ 16,384 px ต่อด้าน
- ถ้า Crop Only ใส่กรอบไม่ครบ แอปแจ้งให้เลือกขนาดเล็กลงหรือเปลี่ยนโหมด
- ชื่อไฟล์ซ้ำจะเพิ่มเลขต่อท้าย แอปไม่เขียนทับไฟล์เดิม
- หากต้นฉบับถูกแก้หลังเปิด แอปจะให้เปิดไฟล์นั้นใหม่ก่อน Export
- การยกเลิก Export เก็บไฟล์ที่ทำเสร็จแล้ว และข้ามภาพที่เหลือ

Mac preset: 1280 × 800, 1440 × 900, 2560 × 1600, 2880 × 1800 (16:10)

อ้างอิง [Screenshot specifications ของ Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) ตรวจเมื่อ 2 กันยายน 2026 การตรวจ preset เป็นการตรวจเงื่อนไขไฟล์ ไม่ใช่การรับรองผ่าน App Review

## ตรวจงาน

```sh
./scripts/test.sh
swiftlint lint --no-cache
git diff --check
```

ชุดทดสอบครอบคลุมพิกเซลที่ crop, สัดส่วน, Fit, EXIF, alpha, PNG/JPEG, ต้นฉบับที่เปลี่ยนบนดิสก์, ชื่อซ้ำ, cancellation และการบันทึกไฟล์จริง

สร้างภาพตัวอย่างสำหรับลอง GUI ด้วย `swift scripts/make-fixtures.swift` ไฟล์จะอยู่ใน `/private/tmp/resize-fixtures` รายการตรวจด้วยตนเองอยู่ที่ [docs/QA.md](docs/QA.md)

อ่านโครงสร้างและเหตุผลของการประมวลผลได้ที่ [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) และขอบเขตรุ่นแรกที่ [docs/PLAN.md](docs/PLAN.md)

รุ่นนี้ยังไม่บันทึก session ข้ามการปิดแอป ยังไม่รองรับวิดีโอ App Preview, HEIC/TIFF/WebP, preset iPhone/iPad หรือการใส่ข้อความและกรอบอุปกรณ์
