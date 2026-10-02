# สร้าง shortcut ใน Start Menu และให้เปิดอัตโนมัติตอนเข้า Windows
$dir = $PSScriptRoot
$vbs = Join-Path $dir 'GitProxyToggle.vbs'
$shell = New-Object -ComObject WScript.Shell

foreach ($folder in @([Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Startup'))) {
    $lnk = $shell.CreateShortcut((Join-Path $folder 'Git Proxy Toggle.lnk'))
    $lnk.TargetPath = 'wscript.exe'
    $lnk.Arguments = "`"$vbs`""
    $lnk.WorkingDirectory = $dir
    $lnk.IconLocation = 'shell32.dll,13'
    $lnk.Save()
    Write-Output "Created: $($lnk.FullName)"
}

Start-Process wscript.exe -ArgumentList "`"$vbs`""
Write-Output 'Git Proxy Toggle started (see the icon near the clock).'
