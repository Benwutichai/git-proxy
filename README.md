# Git Proxy Toggle

โปรแกรมเล็ก ๆ บน System Tray (ข้างนาฬิกา Windows) สำหรับเปิด/ปิด git proxy ด้วยคลิกเดียว
แทนการพิมพ์ `git config --global http.proxy ...` / `--unset` เอง

## ติดตั้ง (ครั้งเดียว)

```bash
powershell -ExecutionPolicy Bypass -File E:\plugin-proxy\install.ps1
```

สคริปต์จะ:
- สร้าง shortcut ใน **Start Menu** (ค้นหา "Git Proxy Toggle")
- สร้าง shortcut ใน **Startup** ให้เปิดเองทุกครั้งที่เข้า Windows
- เปิดโปรแกรมทันที

เปิดครั้งแรกจะมีหน้าตั้งค่าขึ้นมาให้กรอก Host / Port / Username / Password

## วิธีใช้

| ไอคอน | สถานะ |
|---|---|
| 🟢 วงกลมเขียว ตัว P | Proxy **เปิด** |
| ⚪ วงกลมเทา ตัว P | Proxy **ปิด** |

- **คลิกซ้าย**: สลับเปิด/ปิด (มีข้อความเด้งบอกสถานะ)
- **คลิกขวา**: เมนู เปิด Proxy / ปิด Proxy / ตั้งค่า... / ออก

### ใช้จาก command line

```bash
powershell -File E:\plugin-proxy\GitProxyToggle.ps1 -On
```
```bash
powershell -File E:\plugin-proxy\GitProxyToggle.ps1 -Off
```
```bash
powershell -File E:\plugin-proxy\GitProxyToggle.ps1 -Status
```

## สิ่งที่โปรแกรมทำ

เปิด proxy:
```
git config --global http.proxy  http://<user>:<password>@<host>:<port>
git config --global https.proxy http://<user>:<password>@<host>:<port>
```

ปิด proxy:
```
git config --global --unset http.proxy
git config --global --unset https.proxy
```

## หมายเหตุ

- **รหัสผ่านที่มีอักขระพิเศษ** เช่น `@` `:` `#` จะถูก URL-encode ให้อัตโนมัติ (เช่น `@` → `%40`)
  ถ้าใส่ `@` ตรง ๆ ใน URL git จะอ่านผิดและต่อ proxy ไม่ได้
- **รหัสผ่านถูกเก็บแบบเข้ารหัส** (Windows DPAPI) ที่ `%APPDATA%\GitProxyToggle\config.json`
  ถอดรหัสได้เฉพาะ user นี้บนเครื่องนี้ ไม่มีรหัสผ่านอยู่ในโค้ด
  (แต่ตอนเปิด proxy git จะเก็บค่าใน `~/.gitconfig` เป็นข้อความธรรมดา ซึ่งเป็นพฤติกรรมปกติของ git)
- ค่า proxy อยู่ใน `.gitconfig` ถึงจะปิดโปรแกรมไป proxy ก็ยังคงสถานะเดิม
- โปรแกรมเปิดได้ทีละตัวเท่านั้น
- Windows 11 มักซ่อนไอคอนใหม่ไว้ใต้ลูกศร `^` โปรแกรมจะตั้งให้แสดงบน taskbar เอง
  ถ้ายังไม่เห็น: Settings → Personalization → Taskbar → Other system tray icons → เปิด **Windows PowerShell**

## ไฟล์

| ไฟล์ | หน้าที่ |
|---|---|
| `GitProxyToggle.ps1` | ตัวโปรแกรมหลัก (tray + CLI) — ต้องบันทึกเป็น UTF-8 **with BOM** เพราะมีภาษาไทยและรันบน PowerShell 5.1 |
| `GitProxyToggle.vbs` | ตัวเปิดโปรแกรมแบบไม่มีหน้าต่าง console |
| `install.ps1` | สร้าง shortcut ใน Start Menu และ Startup |

## ถอนการติดตั้ง

1. คลิกขวาไอคอน → **ออก**
2. ลบ shortcut:
   - `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Git Proxy Toggle.lnk`
   - `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Git Proxy Toggle.lnk`
3. ลบค่าที่บันทึกไว้: `%APPDATA%\GitProxyToggle\`
4. (ถ้าต้องการ) ปิด proxy ใน git: `git config --global --unset http.proxy` และ `--unset https.proxy`
