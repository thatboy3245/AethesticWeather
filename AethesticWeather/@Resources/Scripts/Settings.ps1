param([Parameter(Mandatory = $true)][string]$SettingsPath)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$settingsDirectory = Split-Path -Parent $SettingsPath
[System.IO.Directory]::CreateDirectory($settingsDirectory) | Out-Null
$settings = [ordered]@{
    provider = 'NWS'
    city = ''
    api_key = ''
    device_id = ''
    station_id = ''
    latitude = ''
    longitude = ''
    nws_user_agent = ''
    nws_forecast_url = ''
    nws_grid_location = ''
}
if (Test-Path -LiteralPath $SettingsPath) {
    try {
        $saved = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
        foreach ($key in $settings.Keys) {
            if ($null -ne $saved.$key) { $settings[$key] = [string]$saved.$key }
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Saved settings could not be read:`r`n$($_.Exception.Message)", 'AethesticWeather', 'OK', 'Error') | Out-Null
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'AethesticWeather Settings'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = [System.Drawing.Size]::new(590, 440)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Font = [System.Drawing.Font]::new('Segoe UI', 9)

function Add-Label([string]$Text, [int]$X, [int]$Y, [int]$Width = 110) {
    $control = New-Object System.Windows.Forms.Label
    $control.Text = $Text
    $control.Location = [System.Drawing.Point]::new($X, $Y)
    $control.Size = [System.Drawing.Size]::new($Width, 24)
    $control.TextAlign = 'MiddleLeft'
    $form.Controls.Add($control)
    return $control
}

function Add-TextBox([string]$Value, [int]$X, [int]$Y, [int]$Width = 410) {
    $control = New-Object System.Windows.Forms.TextBox
    $control.Text = $Value
    $control.Location = [System.Drawing.Point]::new($X, $Y)
    $control.Size = [System.Drawing.Size]::new($Width, 24)
    $form.Controls.Add($control)
    return $control
}

Add-Label 'Weather source' 20 20
$provider = New-Object System.Windows.Forms.ComboBox
$provider.Location = [System.Drawing.Point]::new(140, 20)
$provider.Size = [System.Drawing.Size]::new(410, 24)
$provider.DropDownStyle = 'DropDownList'
[void]$provider.Items.AddRange(@('NWS', 'Tempest'))
$provider.SelectedItem = $settings.provider
$form.Controls.Add($provider)

Add-Label 'City name' 20 56
$city = Add-TextBox $settings.city 140 56
Add-Label 'Tempest API key' 20 92
$apiKey = Add-TextBox $settings.api_key 140 92
$apiKey.UseSystemPasswordChar = $true
Add-Label 'Device ID' 20 128
$deviceId = Add-TextBox $settings.device_id 140 128
Add-Label 'Station ID' 20 164
$stationId = Add-TextBox $settings.station_id 140 164
Add-Label 'Latitude' 20 200 65
$latitude = Add-TextBox $settings.latitude 85 200 155
Add-Label 'Longitude' 255 200 70
$longitude = Add-TextBox $settings.longitude 325 200 100
Add-Label 'NWS User-Agent' 20 236
$userAgent = Add-TextBox $settings.nws_user_agent 140 236
Add-Label 'NWS forecast grid' 20 272
$grid = Add-TextBox $settings.nws_grid_location 140 272 300
$grid.ReadOnly = $true
$findGrid = New-Object System.Windows.Forms.Button
$findGrid.Text = 'Find'
$findGrid.Location = [System.Drawing.Point]::new(450, 270)
$findGrid.Size = [System.Drawing.Size]::new(100, 28)
$form.Controls.Add($findGrid)

$help = Add-Label 'Use a contact email or URL in the NWS User-Agent field. Save to apply changes.' 20 310 540
$help.ForeColor = [System.Drawing.Color]::FromArgb(120, 90, 110)

$status = Add-Label '' 20 340 540
$status.ForeColor = [System.Drawing.Color]::FromArgb(180, 55, 95)

$save = New-Object System.Windows.Forms.Button
$save.Text = 'Save'
$save.Location = [System.Drawing.Point]::new(360, 382)
$save.Size = [System.Drawing.Size]::new(90, 32)
$save.DialogResult = [System.Windows.Forms.DialogResult]::None
$form.Controls.Add($save)
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancel'
$cancel.Location = [System.Drawing.Point]::new(460, 382)
$cancel.Size = [System.Drawing.Size]::new(90, 32)
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancel)
$form.CancelButton = $cancel

function Update-EnabledFields {
    $isTempest = $provider.SelectedItem -eq 'Tempest'
    $apiKey.Enabled = $isTempest
    $deviceId.Enabled = $isTempest
    $stationId.Enabled = $isTempest
    $latitude.Enabled = -not $isTempest
    $longitude.Enabled = -not $isTempest
    $userAgent.Enabled = -not $isTempest
    $findGrid.Enabled = -not $isTempest
}
$provider.add_SelectedIndexChanged({ Update-EnabledFields })
Update-EnabledFields
$script:gridResolved = [bool]$settings.nws_forecast_url
$latitude.Add_TextChanged({
    if ($settings.latitude -and $latitude.Text.Trim() -ne $settings.latitude) { $script:gridResolved = $false }
})
$longitude.Add_TextChanged({
    if ($settings.longitude -and $longitude.Text.Trim() -ne $settings.longitude) { $script:gridResolved = $false }
})

$findGrid.Add_Click({
    try {
        $lat = [double]::Parse($latitude.Text, [Globalization.CultureInfo]::InvariantCulture)
        $lon = [double]::Parse($longitude.Text, [Globalization.CultureInfo]::InvariantCulture)
        if ($lat -lt -90 -or $lat -gt 90 -or $lon -lt -180 -or $lon -gt 180) {
            throw 'Latitude must be -90 to 90 and longitude must be -180 to 180.'
        }
        if (-not $userAgent.Text) { throw 'Enter a contact email or URL in the NWS User-Agent field first.' }
        $latText = $lat.ToString([Globalization.CultureInfo]::InvariantCulture)
        $lonText = $lon.ToString([Globalization.CultureInfo]::InvariantCulture)
        $point = Invoke-RestMethod -Uri ('https://api.weather.gov/points/{0},{1}' -f $latText, $lonText) -Headers @{ 'User-Agent' = $userAgent.Text; 'Accept' = 'application/geo+json' } -TimeoutSec 20
        $grid.Text = '{0} {1},{2}' -f $point.properties.gridId, $point.properties.gridX, $point.properties.gridY
        $settings.nws_forecast_url = [string]$point.properties.forecast
        $settings.nws_grid_location = $grid.Text
        $settings.latitude = $latitude.Text.Trim()
        $settings.longitude = $longitude.Text.Trim()
        $script:gridResolved = $true
        $status.Text = 'NWS forecast grid found.'
    }
    catch {
        $status.Text = $_.Exception.Message
    }
})

$save.Add_Click({
    try {
        if (-not $city.Text.Trim()) { throw 'Enter a city name for the widget.' }
        if ($provider.SelectedItem -eq 'Tempest') {
            if (-not $apiKey.Text -or -not $deviceId.Text -or -not $stationId.Text) {
                throw 'Tempest needs an API key, device ID, and station ID.'
            }
        }
        else {
            $lat = [double]::Parse($latitude.Text, [Globalization.CultureInfo]::InvariantCulture)
            $lon = [double]::Parse($longitude.Text, [Globalization.CultureInfo]::InvariantCulture)
            if ($lat -lt -90 -or $lat -gt 90 -or $lon -lt -180 -or $lon -gt 180) {
                throw 'Latitude must be -90 to 90 and longitude must be -180 to 180.'
            }
            if (-not $userAgent.Text) { throw 'Enter a contact email or URL in the NWS User-Agent field.' }
            if (-not $script:gridResolved) { throw 'Click Find to resolve the NWS forecast for these coordinates.' }
        }
        $settings.provider = [string]$provider.SelectedItem
        $settings.city = $city.Text.Trim()
        $settings.api_key = $apiKey.Text.Trim()
        $settings.device_id = $deviceId.Text.Trim()
        $settings.station_id = $stationId.Text.Trim()
        $settings.latitude = $latitude.Text.Trim()
        $settings.longitude = $longitude.Text.Trim()
        $settings.nws_user_agent = $userAgent.Text.Trim()
        $settings.nws_grid_location = $grid.Text.Trim()
        $temporary = $SettingsPath + '.tmp'
        $settings | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $temporary -Encoding UTF8
        Move-Item -LiteralPath $temporary -Destination $SettingsPath -Force
        $rainmeter = Get-Process Rainmeter -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($rainmeter) {
            $exe = $rainmeter.Path
            if ($exe) { Start-Process -FilePath $exe -ArgumentList '!Refresh "AethesticWeather\AethesticWeather"' -WindowStyle Hidden }
        }
        $form.Close()
    }
    catch {
        $status.Text = $_.Exception.Message
    }
})

[void]$form.ShowDialog()
