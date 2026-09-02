# ขอบเขตรุ่น 0.1

Native macOS utility สำหรับภาพนิ่ง PNG/JPEG ใช้งานผ่าน GUI และประมวลผลในเครื่อง Default เป็น Crop Only + PNG + Mac 2880 × 1800

## หน้าต่างหลัก

| ซ้าย | กลาง | ขวา |
| --- | --- | --- |
| รายการภาพ เลือกหลายภาพ ลบออกจาก session | Source/Output, กรอบ crop, zoom และตำแหน่งพิกเซล | Preset, Custom size, mode, background, format และ JPEG quality |

Toolbar มี Open, Export และ Export All; แถบล่างแสดงการย่อ/ขยาย ขนาดไฟล์ และความคืบหน้า

## งานที่รวมในรุ่นนี้

1. Xcode project และหน้าต่าง macOS
2. นำเข้าหลายภาพจาก Open/drag and drop/Finder และอ่าน EXIF
3. Crop Only พร้อมกรอบขนาดคงที่ ลาก ลูกศร Center และ Reset
4. Crop & Resize พร้อมปรับมุมกรอบและ slider; Fit พร้อมเติมพื้นหลัง
5. Mac preset และ Custom dimensions/ratio lock
6. Encoded output preview, zoom ระดับพิกเซล, PNG/JPEG export
7. แยก settings รายภาพ ใช้ค่าร่วมกับภาพที่เลือก ส่งออกทั้งหมดและยกเลิกได้
8. ตรวจไฟล์ก่อนบันทึกชื่อจริง ป้องกันชื่อซ้ำและเก็บต้นฉบับ
9. Core/IO tests, build checks และ GUI QA บน Mac

## งานต่อยอด

บันทึก session, undo history แบบเต็ม, HEIC/TIFF/WebP, preset อุปกรณ์อื่น, ข้อความและ device frames, วิดีโอ App Preview และ signed/notarized distribution

## Gate ก่อนใช้งานจริง

Core/IO tests ผ่าน, build ผ่าน, ไม่มี whitespace errors และทำรายการ GUI QA ใน `QA.md` พร้อมตรวจ screenshot จริงของแอปที่จะส่ง App Store โดยเฉพาะสีและความอ่านง่ายของตัวหนังสือ
