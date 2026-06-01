# Prompt Library

## How to use
วาง prompt ด้านล่างใน Claude Code ได้เลย
ก่อนวางทุกครั้งให้บอกว่า "อ่าน CLAUDE.md ก่อน"

---

## 🔄 Session Start (ใช้ทุกครั้งที่เปิด Claude Code ใหม่)
```
อ่าน CLAUDE.md และ docs/PROGRESS.md
สรุปให้ฟังว่าทำไปถึงไหนแล้ว และ next step คืออะไร
```

---

## 🏗️ สร้าง Feature ใหม่
```
อ่าน CLAUDE.md ก่อน
สร้าง [ชื่อไฟล์] ตาม spec ใน CLAUDE.md
เมื่อเสร็จให้อัปเดต docs/PROGRESS.md ด้วย
```

---

## 🐛 Debug
```
อ่าน CLAUDE.md ก่อน
มี error นี้: [วาง error]
ไฟล์ที่เกี่ยวข้อง: [ชื่อไฟล์]
ช่วย fix และอธิบายสาเหตุ
```

---

## 🎨 ปรับ Effect
```
อ่าน CLAUDE.md ก่อน
แก้ [ชื่อ effect] ให้:
- สีเปลี่ยนเป็น [สี]
- ความเร็วเพิ่มเป็น [ค่า]
- particle จำนวน [จำนวน]
```

---

## 🔌 WebSocket Test
```
อ่าน CLAUDE.md ก่อน
จำลอง event นี้เข้า GameManager โดยตรง (bypass WebSocket):
[วาง JSON event]
แล้ว print ผลลัพธ์ออก console
```

---

## 📦 ย้ายไฟล์ไป Subfolder
```
อ่าน CLAUDE.md และ docs/PROGRESS.md ก่อน
ย้ายไฟล์ตาม intended structure ใน CLAUDE.md:
- อัปเดต path ใน Arena.tscn และ project.godot ด้วย
- อัปเดต docs/PROGRESS.md เมื่อเสร็จ
```

---

## ✅ อัปเดต PROGRESS หลังทำเสร็จ
```
อัปเดต docs/PROGRESS.md:
- ย้าย [feature] จาก Todo ไป Done
- เพิ่มวันที่ [วันนี้]
- เพิ่ม Known Issues ถ้ามี
```

---

## ♻️ Context เต็ม
```
/compact
```
หรือ
```
/clear
```
แล้ว prompt แรกคือ:
```
อ่าน CLAUDE.md และ docs/PROGRESS.md สรุปสถานะ project
```
