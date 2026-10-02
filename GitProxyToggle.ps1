<#
  Git Proxy Toggle - เปิด/ปิด git proxy จาก System Tray

  ใช้งานแบบ GUI (ไอคอนข้างนาฬิกา - คลิกซ้ายเพื่อสลับ, คลิกขวาเพื่อดูเมนู):
    ดับเบิลคลิก GitProxyToggle.vbs
  ใช้งานแบบ command line:
    powershell -File GitProxyToggle.ps1 -On
    powershell -File GitProxyToggle.ps1 -Off
    powershell -File GitProxyToggle.ps1 -Status
#>
param(
    [switch]$On,
    [switch]$Off,
    [switch]$Status
)

$ErrorActionPreference = 'Stop'

$ConfigDir  = Join-Path $env:APPDATA 'GitProxyToggle'
$ConfigFile = Join-Path $ConfigDir 'config.json'

# ---------------------------------------------------------------- config

function Get-Config {
    if (-not (Test-Path $ConfigFile)) { return $null }
    return Get-Content $ConfigFile -Raw | ConvertFrom-Json
}

function Save-Config($ProxyHost, $Port, $User, [securestring]$Password) {
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir | Out-Null }
    # รหัสผ่านถูกเข้ารหัสด้วย Windows DPAPI - ถอดได้เฉพาะ user นี้บนเครื่องนี้เท่านั้น
    $cfg = [ordered]@{
        host     = $ProxyHost
        port     = $Port
        user     = $User
        password = ($Password | ConvertFrom-SecureString)
    }
    $cfg | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
}

function Get-PlainPassword($cfg) {
    if (-not $cfg.password) { return '' }
    $secure = $cfg.password | ConvertTo-SecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Get-ProxyUrl($cfg) {
    $auth = ''
    if ($cfg.user) {
        # encode อักขระพิเศษ เช่น @ : # ในรหัสผ่าน ไม่งั้น URL จะพัง
        $u = [uri]::EscapeDataString($cfg.user)
        $p = [uri]::EscapeDataString((Get-PlainPassword $cfg))
        $auth = "${u}:${p}@"
    }
    return "http://$auth$($cfg.host):$($cfg.port)"
}

# ---------------------------------------------------------------- git

function Get-ProxyState {
    $val = & git config --global --get http.proxy 2>$null
    return [bool]$val
}

function Get-ProxyDisplay {
    $val = & git config --global --get http.proxy 2>$null
    if (-not $val) { return 'ปิดอยู่ (ไม่มี proxy)' }
    # ซ่อนรหัสผ่านตอนแสดงผล
    return 'เปิดอยู่ -> ' + ($val -replace '://([^:/]+):[^/]*@', '://$1:****@')
}

function Enable-GitProxy {
    $cfg = Get-Config
    if (-not $cfg) { throw 'ยังไม่ได้ตั้งค่า proxy (เปิดหน้า Settings ก่อน)' }
    $url = Get-ProxyUrl $cfg
    & git config --global http.proxy  $url
    & git config --global https.proxy $url
}

function Disable-GitProxy {
    # exit code 5 = ไม่มีค่าอยู่แล้ว ถือว่าปกติ
    & git config --global --unset http.proxy  2>$null
    & git config --global --unset https.proxy 2>$null
    $global:LASTEXITCODE = 0
}

# ---------------------------------------------------------------- CLI mode

if ($On -or $Off -or $Status) {
    if ($On)  { Enable-GitProxy }
    if ($Off) { Disable-GitProxy }
    Write-Output "Git proxy: $(Get-ProxyDisplay)"
    exit 0
}

# ---------------------------------------------------------------- GUI mode

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ให้รันได้ตัวเดียว
$mutex = New-Object System.Threading.Mutex($false, 'Local\GitProxyToggle')
if (-not $mutex.WaitOne(0)) { exit 0 }

function New-DotIcon([System.Drawing.Color]$color) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush $color
    $g.FillEllipse($brush, 3, 3, 26, 26)
    $font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString('P', $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 1, 32, 32)), $sf)
    $g.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$IconOn  = New-DotIcon ([System.Drawing.Color]::FromArgb(34, 160, 80))
$IconOff = New-DotIcon ([System.Drawing.Color]::FromArgb(140, 140, 140))

function Show-Settings {
    $cfg = Get-Config

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Git Proxy - ตั้งค่า'
    $form.Size = New-Object System.Drawing.Size(380, 260)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false; $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $fields = @(
        @{ Label = 'Proxy host'; Value = $(if ($cfg) { $cfg.host } else { 'proxyhq.cgd.go.th' }) },
        @{ Label = 'Port';       Value = $(if ($cfg) { $cfg.port } else { '8080' }) },
        @{ Label = 'Username';   Value = $(if ($cfg) { $cfg.user } else { '' }) },
        @{ Label = 'Password';   Value = $(if ($cfg) { Get-PlainPassword $cfg } else { '' }) }
    )
    $boxes = @()
    $y = 20
    foreach ($f in $fields) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $f.Label; $lbl.Location = New-Object System.Drawing.Point(20, ($y + 3)); $lbl.AutoSize = $true
        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Text = $f.Value; $tb.Location = New-Object System.Drawing.Point(120, $y); $tb.Width = 220
        if ($f.Label -eq 'Password') { $tb.UseSystemPasswordChar = $true }
        $form.Controls.AddRange(@($lbl, $tb))
        $boxes += $tb
        $y += 34
    }

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'บันทึก'; $ok.Location = New-Object System.Drawing.Point(160, ($y + 10)); $ok.Width = 85
    $ok.DialogResult = 'OK'
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'ยกเลิก'; $cancel.Location = New-Object System.Drawing.Point(255, ($y + 10)); $cancel.Width = 85
    $cancel.DialogResult = 'Cancel'
    $form.Controls.AddRange(@($ok, $cancel))
    $form.AcceptButton = $ok; $form.CancelButton = $cancel

    if ($form.ShowDialog() -ne 'OK') { return $false }

    $pw = ConvertTo-SecureString $boxes[3].Text -AsPlainText -Force
    Save-Config $boxes[0].Text.Trim() $boxes[1].Text.Trim() $boxes[2].Text.Trim() $pw
    # ถ้า proxy เปิดอยู่ อัปเดตค่าใหม่ทันที
    if (Get-ProxyState) { Enable-GitProxy }
    return $true
}

$tray = New-Object System.Windows.Forms.NotifyIcon
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miStatus   = $menu.Items.Add('')
$miStatus.Enabled = $false
[void]$menu.Items.Add('-')
$miOn       = $menu.Items.Add('เปิด Proxy')
$miOff      = $menu.Items.Add('ปิด Proxy')
[void]$menu.Items.Add('-')
$miSettings = $menu.Items.Add('ตั้งค่า...')
$miExit     = $menu.Items.Add('ออก')
$tray.ContextMenuStrip = $menu

function Update-Tray {
    $isOn = Get-ProxyState
    $tray.Icon = if ($isOn) { $IconOn } else { $IconOff }
    $text = if ($isOn) { 'Git Proxy: ON' } else { 'Git Proxy: OFF' }
    $tray.Text = $text + ' (คลิกเพื่อสลับ)'
    $miStatus.Text = $text
    $miOn.Enabled = -not $isOn
    $miOff.Enabled = $isOn
}

function Invoke-Safely([scriptblock]$action) {
    try { & $action }
    catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Git Proxy', 'OK', 'Error') | Out-Null }
    Update-Tray
}

function Set-Proxy([bool]$enable) {
    Invoke-Safely {
        if ($enable) {
            if (-not (Get-Config) -and -not (Show-Settings)) { return }
            Enable-GitProxy
        } else {
            Disable-GitProxy
        }
        $tray.ShowBalloonTip(1500, 'Git Proxy', (Get-ProxyDisplay), 'Info')
    }
}

$miOn.add_Click({ Set-Proxy $true })
$miOff.add_Click({ Set-Proxy $false })
$miSettings.add_Click({ Invoke-Safely { [void](Show-Settings) } })
$miExit.add_Click({ $tray.Visible = $false; [System.Windows.Forms.Application]::Exit() })
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq 'Left') { Set-Proxy (-not (Get-ProxyState)) }
})
$menu.add_Opening({ Update-Tray })

# Windows 11 ซ่อนไอคอนใหม่ไว้ใต้ลูกศร ^ - ตั้งให้แสดงบน taskbar เสมอ
function Set-TrayIconPinned {
    Get-ChildItem 'HKCU:\Control Panel\NotifyIconSettings' -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath
        if ($p.ExecutablePath -like '*powershell.exe' -and $p.InitialTooltip -like 'Git Proxy*' -and $p.IsPromoted -ne 1) {
            Set-ItemProperty $_.PSPath -Name IsPromoted -Value 1 -Type DWord
        }
    }
}

Update-Tray
$tray.Visible = $true

# registry entry ถูกสร้างหลังไอคอนแสดงแล้ว จึงรอสักครู่ก่อน
$pinTimer = New-Object System.Windows.Forms.Timer
$pinTimer.Interval = 3000
$pinTimer.add_Tick({ $pinTimer.Stop(); try { Set-TrayIconPinned } catch {} })
$pinTimer.Start()

# ครั้งแรกยังไม่มีค่า -> เปิดหน้าตั้งค่าให้เลย
if (-not (Get-Config)) { Invoke-Safely { [void](Show-Settings) } }

[System.Windows.Forms.Application]::Run()
$tray.Dispose()
$mutex.ReleaseMutex()
