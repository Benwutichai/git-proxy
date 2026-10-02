' เปิด Git Proxy Toggle แบบไม่มีหน้าต่าง console
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\GitProxyToggle.ps1""", 0, False
