param([Parameter(Mandatory = $true)][string]$SettingsDirectory)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$currentVersion = [version]'1.0.0'
$repository = 'thatboy3245/AethesticWeather'
$marker = Join-Path $SettingsDirectory 'last-notified-version.txt'

function Show-WeatherToast([string]$Title, [string]$Message) {
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02
        $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($template)
        $textNodes = $xml.GetElementsByTagName('text')
        $textNodes.Item(0).AppendChild($xml.CreateTextNode($Title)) | Out-Null
        $textNodes.Item(1).AppendChild($xml.CreateTextNode($Message)) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Microsoft.Windows.PowerShell').Show($toast)
    }
    catch {
        Add-Type -AssemblyName System.Windows.Forms
        $icon = New-Object System.Windows.Forms.NotifyIcon
        $icon.Icon = [System.Drawing.SystemIcons]::Information
        $icon.Visible = $true
        $icon.BalloonTipTitle = $Title
        $icon.BalloonTipText = $Message
        $icon.ShowBalloonTip(10000)
        Start-Sleep -Seconds 3
        $icon.Dispose()
    }
}

try {
    [IO.Directory]::CreateDirectory($SettingsDirectory) | Out-Null
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repository/releases/latest" -Headers @{ 'User-Agent' = 'AethesticWeather'; 'Accept' = 'application/vnd.github+json' } -TimeoutSec 20
    $latestTag = [string]$release.tag_name -replace '^[vV]', ''
    $latestVersion = [version]$latestTag
    $lastNotified = ''
    if (Test-Path -LiteralPath $marker) { $lastNotified = (Get-Content -LiteralPath $marker -Raw).Trim() }
    if ($latestVersion -gt $currentVersion -and $latestTag -ne $lastNotified) {
        Show-WeatherToast 'AethesticWeather update available' "Version $latestTag is ready to download."
        Set-Content -LiteralPath $marker -Value $latestTag -Encoding ASCII
    }
}
catch {
    Add-Content -LiteralPath (Join-Path $SettingsDirectory 'update-check.log') -Value ('{0} {1}' -f (Get-Date -Format o), $_.Exception.Message)
}
