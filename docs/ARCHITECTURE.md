# โครงสร้าง ReSize

## หน้าที่ของแต่ละส่วน

- `ReSize/App`: SwiftUI ดูแลหน้าต่าง รายการภาพ ตัวเลือก และรายงานผล; `CropCanvas` ใช้ AppKit สำหรับวาดกรอบ ลากมุม เลื่อน viewport และรับปุ่มลูกศร
- `WorkspaceStore`: เก็บรายการและ settings แยกตาม UUID ของภาพ อยู่บน main actor และเริ่มงานเบื้องหลังผ่าน `ImageWorker`
- `ReSize/Core`: geometry, อ่านภาพ, render, encode, ตรวจไฟล์, ตั้งชื่อ, cache และ export ไม่ผูกกับ UI
- `Package.swift`: เปิด Core ให้ทดสอบด้วย SwiftPM ส่วน Xcode app compile source ชุดเดียวกันโดยตรง

## พิกัดภาพและ Retina

Settings เก็บจุดกึ่งกลางแบบ normalized และขนาดกรอบเป็นสัดส่วนของกรอบใหญ่ที่สุดที่ใส่ได้ เปลี่ยน viewport หรือระดับ zoom แล้วค่าพวกนี้ไม่เปลี่ยน

พิกัด crop เริ่มที่มุมซ้ายบนของภาพหลัง normalize EXIF แล้ว Crop Only ปัด origin ให้ลงพิกเซลเต็มและใช้ขนาดปลายทางตรง ๆ ส่วน Crop & Resize เก็บสัดส่วนด้วยพิกัดทศนิยม แล้ววาดด้วย scale เดียวทั้งสองแกน จึงไม่บีบภาพเพื่อชดเชยการปัดขนาดกรอบ

100% ของ canvas ใช้ `1 / backingScaleFactor` point ต่อพิกเซลภาพ จึงเป็นหนึ่งพิกเซลภาพต่อหนึ่งพิกเซลจอจริง ไม่ใช่หนึ่ง point ของ SwiftUI ต่อพิกเซลภาพ

CoreGraphics วาดภาพจากด้านล่าง จึงต้องแปลงค่า y ของ crop ก่อนวาด Crop & Resize มี tests ตรวจพื้นที่บน/ล่างเพื่อกันภาพกลับด้าน

## ความหมายของการรักษารายละเอียด

Crop Only ใช้ `CGImage.cropping` แล้ววาดที่ขนาดเดิมด้วย interpolation `.none` ไม่มีการย่อหรือขยาย ส่วน PNG encode แบบ lossless

ไฟล์ปลายทางทุกโหมดเป็น RGB 8-bit ใน sRGB และไม่มี alpha เพื่อให้ข้อกำหนดส่งออกเหมือนกัน การแปลงจาก P3/HDR/16-bit หรือ compositing พื้นที่โปร่งใสอาจเปลี่ยนค่าสีได้ UI และ README ระบุข้อจำกัดนี้ การทดสอบรักษาพิกเซลใช้ opaque sRGB source และเปรียบเทียบพื้นที่ที่ถูกตัดทุกพิกเซล

## Preview และหน่วยความจำ

ใช้ pipeline เดียวสำหรับ Preview และ Export: render → encode → decode เพื่อตรวจและแสดงผล จึงเห็นผลของ JPEG quality จริงใน Output Preview

งาน preview รอ 180 ms หลังเปลี่ยนค่าและยกเลิกงานเก่า เก็บผลเฉพาะเมื่อ UUID และ settings ยังตรงกับภาพปัจจุบัน เมื่อ preview ยังไม่พร้อมจะไม่แสดงผลเก่าปะปนกับ settings ใหม่

รายการซ้ายเก็บ thumbnail 420 px ส่วน worker cache ภาพเต็มไว้เพียงใบล่าสุด การ decode/render/encode ทำบน actor แยกจาก main actor และ Export ทำทีละไฟล์ งาน bitmap ที่เริ่มไปแล้วอาจต้องทำจบก่อนตรวจ cancellation จุดถัดไป

## ความปลอดภัยของไฟล์

ไม่มีการแก้ต้นฉบับในที่เดิม Export ตั้งชื่อใหม่และเพิ่มเลขเมื่อชนกัน โดยกันชื่อซ้ำภายใน batch ด้วย

ก่อนประมวลผล อ่านขนาดไฟล์และเวลาแก้ไขล่าสุดจาก filesystem ใหม่ ไม่ใช้ metadata cache ของ URL ถ้าต้นฉบับเปลี่ยนจะให้ผู้ใช้เปิดใหม่ การตรวจนี้ใช้ metadata ไม่ใช่ hash ของทุกไบต์

สร้าง temporary file ในโฟลเดอร์ปลายทาง ตรวจขนาด format และ alpha จากไฟล์นั้น แล้ว move ไปชื่อจริง ถ้ามีไฟล์ชื่อเดียวกันเกิดขึ้นระหว่างรอ จะรายงานข้อผิดพลาดและไม่เขียนทับ ลบ temporary file เมื่อผิดพลาดหรือยกเลิก

Snapshot รายการและ settings ตอนเริ่ม Export จึงไม่เปลี่ยนกลาง batch และรายงานไฟล์สำเร็จ/ผิดพลาดแยกกัน

## สีของแอป

ไอคอนใช้พื้นขาว–เทาและเส้น crop สีเข้ม เรนเดอร์จาก geometry เดิมใน `scripts/make-icon.swift` ให้คมตามขนาดที่ asset catalog ต้องการ

สีของปุ่มและตัวควบคุมใช้ `NSColor.controlAccentColor` ของ macOS ส่วนสถานะและขอบ drop ใช้ `Color.accentColor` ไม่มี AccentColor asset ของแอปหรือสีเขียวที่กำหนดตายตัว จึงไม่ผูกสี UI กับไอคอน

## ข้อจำกัดของ build ปัจจุบัน

ใช้ ad-hoc signing สำหรับเปิดใช้ในเครื่อง ยังไม่มี App Sandbox/notarization/distribution setup และไม่ร้องขอ network, screen recording หรือสิทธิ์ Photos ใช้ไฟล์ที่ผู้ใช้เลือกเองเท่านั้น

กำหนด deployment target macOS 14 แต่ยังต้องทดสอบบน macOS 14 จริงก่อนอ้างว่ารองรับ runtime ครบ บนเครื่องที่ใช้พัฒนาได้ตรวจด้วย macOS 26.6.2 / Xcode 26.6
