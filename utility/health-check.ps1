# Config
$VpsIp       = [System.Environment]::GetEnvironmentVariable("UTILITY_SERVER_IP", "User")
$Service     = [System.Environment]::GetEnvironmentVariable("OVH_SERVICE", "User")
$Endpoint    = "ca.api.ovh.com"

# OVH Creds
$AppKey      = [System.Environment]::GetEnvironmentVariable("OVH_APP_KEY", "User")
$AppSecret   = [System.Environment]::GetEnvironmentVariable("OVH_APP_SECRET", "User")
$ConsumerKey = [System.Environment]::GetEnvironmentVariable("OVH_CONSUMER_KEY", "User")

# Timeout duration for the notification balloon (in milliseconds)
$ToastTimeoutMs = 6000

# Helper function: Native system tray balloon tip with automatic timeout
function Send-Toast {
    param([string]$Title, [string]$Message)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $global:balloon = New-Object System.Windows.Forms.NotifyIcon
        $global:balloon.Icon = [System.Drawing.SystemIcons]::Information
        $global:balloon.Visible = $true
        $global:balloon.ShowBalloonTip($ToastTimeoutMs, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)

        # Keep process alive and pump messages until the timeout expires, then automatically dismiss
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt $ToastTimeoutMs) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 50
        }
        $global:balloon.Visible = $false
        $global:balloon.Dispose()
    } catch {
        Write-Host "Notification failed: $_"
    }
}

# --- Step 1: Ping VPS ---
Write-Host "Pinging $VpsIp..."
$PingResult = Test-Connection -ComputerName $VpsIp -Count 3 -Quiet

if ($PingResult){
    Write-Host "[$((Get-Date))] VPS is online and responding normally." -ForegroundColor Green
    Send-Toast -Title "Utility Server" -Message "VPS is online and responding normally."
    exit 0
} else {
    Write-Host "[$((Get-Date))] WARNING: VPS failed to respond! Initiating restart..." -ForegroundColor Yellow

    $Timestamp = [int][datetimeoffset]::UtcNow.ToUnixTimeSeconds()
    $Method    = "POST"
    $TargetUrl = "https://$Endpoint/1.0/vps/$Service/reboot"
    $Body      = ""

    $StringToSign = "$AppSecret+$ConsumerKey+$Method+$TargetUrl+$Body+$Timestamp"
    $Sha1 = [System.Security.Cryptography.SHA1]::Create()
    $HashBytes = $Sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($StringToSign))
    $Signature = '$1$' + [BitConverter]::ToString($HashBytes).Replace("-","").ToLower()

    $Headers = @{
        "X-Ovh-Application" = $AppKey
        "X-Ovh-Consumer"    = $ConsumerKey
        "X-Ovh-Signature"   = $Signature
        "X-Ovh-Timestamp"   = $Timestamp
    }

    try{
        $Response = Invoke-RestMethod -Uri $TargetUrl -Method Post -Headers $Headers
        Write-Host "[$((Get-Date))] Restart command sent successfully! Task ID: $($Response.Id) Please wait 2 min." -ForegroundColor Green
        Send-Toast -Title "Utility Server - Restart Triggered" -Message "VPS offline. OVH reboot command sent successfully."
    } catch{
        Write-Host "[$((Get-Date))] ERROR: Failed to trigger OVH API restart. Details: $_" -ForegroundColor Red
        Send-Toast -Title "Utility Server - ERROR" -Message "VPS offline, but failed to trigger OVH restart."
    }
}