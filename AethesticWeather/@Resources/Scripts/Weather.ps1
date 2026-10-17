param(
    [Parameter(Mandatory = $true)][string]$SettingsPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Format-Value($Value) {
    if ($null -eq $Value) { return '--' }
    if ($Value -is [string]) { return $Value }
    return ([double]$Value).ToString('0.#', [Globalization.CultureInfo]::InvariantCulture)
}

function Select-Icon([string]$Condition) {
    if ($Condition -match 'thunder|storm|lightning') { return 'storm' }
    if ($Condition -match 'snow|sleet|ice|freezing') { return 'snow' }
    if ($Condition -match 'rain|shower|drizzle') { return 'rain' }
    if ($Condition -match 'cloud|fog|mist|overcast') { return 'cloudy' }
    return 'clear'
}

function Save-Result([hashtable]$Values) {
    $directory = Split-Path -Parent $OutputPath
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $lines = foreach ($key in $Values.Keys) {
        $value = [string]$Values[$key]
        $value = $value -replace '[\r\n=]', ' '
        '{0}={1}' -f $key, $value
    }
    $lines += 'UpdatedAt=' + [DateTime]::UtcNow.ToString('o')
    $temporary = $OutputPath + '.tmp'
    [IO.File]::WriteAllLines($temporary, [string[]]$lines, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $OutputPath -Force
}

function Get-NwsForecast($Settings) {
    $headers = @{ 'User-Agent' = [string]$Settings.nws_user_agent; 'Accept' = 'application/geo+json' }
    $forecastUrl = [string]$Settings.nws_forecast_url
    if (-not $forecastUrl) {
        $latitude = [double]::Parse([string]$Settings.latitude, [Globalization.CultureInfo]::InvariantCulture)
        $longitude = [double]::Parse([string]$Settings.longitude, [Globalization.CultureInfo]::InvariantCulture)
        if ($latitude -lt -90 -or $latitude -gt 90 -or $longitude -lt -180 -or $longitude -gt 180) {
            throw 'Latitude must be -90 to 90 and longitude must be -180 to 180.'
        }
        $latText = $latitude.ToString([Globalization.CultureInfo]::InvariantCulture)
        $lonText = $longitude.ToString([Globalization.CultureInfo]::InvariantCulture)
        $point = Invoke-RestMethod -Uri ('https://api.weather.gov/points/{0},{1}' -f $latText, $lonText) -Headers $headers -TimeoutSec 20
        $forecastUrl = [string]$point.properties.forecast
        if (-not $forecastUrl) { throw 'The NWS could not resolve a forecast for these coordinates.' }
        $gridLocation = '{0} {1},{2}' -f $point.properties.gridId, $point.properties.gridX, $point.properties.gridY
        $Settings | Add-Member -MemberType NoteProperty -Name nws_forecast_url -Value $forecastUrl -Force
        $Settings | Add-Member -MemberType NoteProperty -Name nws_grid_location -Value $gridLocation -Force
        $Settings | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
    }

    $forecast = Invoke-RestMethod -Uri $forecastUrl -Headers $headers -TimeoutSec 20
    $period = @($forecast.properties.periods)[0]
    if (-not $period) { throw 'The NWS returned no forecast periods for this location.' }
    $humidity = '--'
    if ($null -ne $period.relativeHumidity.value) { $humidity = Format-Value $period.relativeHumidity.value }
    $wind = [string]$period.windSpeed
    if ($period.windDirection) { $wind = '{0} {1}' -f $wind, $period.windDirection }

    return @{
        Location = if ($Settings.city) { [string]$Settings.city } else { [string]$period.name }
        Temperature = Format-Value $period.temperature
        Condition = [string]$period.shortForecast
        FeelsLike = '--'
        Humidity = $humidity + '%'
        Wind = $wind
    }
}

function Get-TempestWeather($Settings) {
    $token = [uri]::EscapeDataString([string]$Settings.api_key)
    $device = [uri]::EscapeDataString([string]$Settings.device_id)
    $station = [uri]::EscapeDataString([string]$Settings.station_id)
    if (-not $token -or -not $device -or -not $station) {
        throw 'Tempest requires an API key, device ID, and station ID. Add them in Settings.'
    }

    $observation = Invoke-RestMethod -Uri "https://swd.weatherflow.com/swd/rest/observations/device/$device?token=$token&units_temp=f&units_wind=mph" -TimeoutSec 20
    $reading = @($observation.obs)[0]
    if (-not $reading -or $reading.Count -lt 20) { throw 'Tempest returned an incomplete device observation.' }

    $condition = 'Current conditions'
    try {
        $forecast = Invoke-RestMethod -Uri "https://swd.weatherflow.com/swd/rest/better_forecast?station_id=$station&token=$token&units_temp=f&units_wind=mph" -TimeoutSec 20
        if ($forecast.current_conditions.conditions) {
            $condition = [string]$forecast.current_conditions.conditions
        }
        $temperature = $forecast.current_conditions.air_temperature
        $feelsLike = $forecast.current_conditions.feels_like
        $humidity = $forecast.current_conditions.relative_humidity
        $wind = $forecast.current_conditions.wind_avg
        if ($null -eq $temperature) { $temperature = $reading[18] }
        if ($null -eq $feelsLike) { $feelsLike = $reading[26] }
        if ($null -eq $humidity) { $humidity = $reading[19] }
        if ($null -eq $wind) { $wind = $reading[2] }
    }
    catch {
        $temperature = $reading[18]
        $feelsLike = $reading[26]
        $humidity = $reading[19]
        $wind = $reading[2]
    }

    if ([double]$reading[8] -gt 0 -and $condition -eq 'Current conditions') { $condition = 'Rain' }
    return @{
        Location = [string]$Settings.city
        Temperature = Format-Value $temperature
        Condition = $condition
        FeelsLike = Format-Value $feelsLike
        Humidity = (Format-Value $humidity) + '%'
        Wind = (Format-Value $wind) + ' mph'
    }
}

try {
    if (-not (Test-Path -LiteralPath $SettingsPath)) {
        throw 'Open Settings and configure a weather source to get started.'
    }
    $settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
    if ($settings.provider -eq 'Tempest') {
        $weather = Get-TempestWeather $settings
        $icon = Select-Icon $weather.Condition
    }
    elseif ($settings.provider -eq 'NWS') {
        if (-not $settings.nws_user_agent) { throw 'Enter a contact email or URL in the NWS User-Agent field in Settings.' }
        $weather = Get-NwsForecast $settings
        $icon = Select-Icon $weather.Condition
    }
    else {
        throw 'Select Tempest or NWS in Settings.'
    }
    $weather.WeatherIcon = $icon
    $weather.WeatherStatus = 'Updated ' + (Get-Date -Format 'h:mm tt')
    $weather.Status = 'OK'
    Save-Result $weather
}
catch {
    Save-Result @{
        Location = 'AethesticWeather'
        Temperature = '--'
        Condition = 'Weather unavailable'
        FeelsLike = '--'
        Humidity = '--'
        Wind = '--'
        WeatherIcon = 'cloudy'
        WeatherStatus = $_.Exception.Message
        Status = 'ERROR'
    }
}
