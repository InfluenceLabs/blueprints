# Config (Pulls fresh from Windows storage on the fly)
$VpsIp       = [System.Environment]::GetEnvironmentVariable("UTILITY_SERVER_IP", "User")
$Service     = [System.Environment]::GetEnvironmentVariable("OVH_SERVICE", "User")
$Endpoint    = "ca.api.ovh.com"

# OVH Creds
$AppKey      = [System.Environment]::GetEnvironmentVariable("OVH_APP_KEY", "User")
$AppSecret   = [System.Environment]::GetEnvironmentVariable("OVH_APP_SECRET", "User")
$ConsumerKey = [System.Environment]::GetEnvironmentVariable("OVH_CONSUMER_KEY", "User")

# --- Step 1: Ping VPS ---
Write-Host "Pinging $VpsIp..."
$PingResult = Test-Connection -ComputerName $VpsIp -Count 3 -Quiet

if ($PingResult){
    # If Server live and ping succeeds, log and exit cleanly
    Write-Host "[$((Get-Date))] VPS is online and responding normally." -ForegroundColor Green
    exit 0
} else {
    # If ping fails, log a warning and prepare to trigger restart
    Write-Host "[$((Get-Date))] WARNING: VPS failed to respond! Initiating restart..." -ForegroundColor Yellow

    # Prepare for sending to OVH API (Using clean Unix timestamp)
    $Timestamp = [int][datetimeoffset]::UtcNow.ToUnixTimeSeconds()

    $Method    = "POST"
    $TargetUrl = "https://$Endpoint/1.0/vps/$Service/reboot"
    $Body      = ""

    # Create string that OVH expects
    $StringToSign = "$AppSecret+$ConsumerKey+$Method+$TargetUrl+$Body+$Timestamp"

    # Hash it using SHA1 and format it with required prefix
    $Sha1 = [System.Security.Cryptography.SHA1]::Create()
    $HashBytes = $Sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($StringToSign))
    $Signature = '$1$' + [BitConverter]::ToString($HashBytes).Replace("-","").ToLower()

    # Send to OVH API
    $Headers = @{
        "X-Ovh-Application" = $AppKey
        "X-Ovh-Consumer"    = $ConsumerKey
        "X-Ovh-Signature"   = $Signature
        "X-Ovh-Timestamp"   = $Timestamp
    }

    try{
        $Response = Invoke-RestMethod -Uri $TargetUrl -Method Post -Headers $Headers
        Write-Host "[$((Get-Date))] Restart command sent successfully! Task ID: $($Response.Id) Please wait 2 min." -ForegroundColor Green
    } catch{
        Write-Host "[$((Get-Date))] ERROR: Failed to trigger OVH API restart. Details: $_" -ForegroundColor Red
    }
}