local resources
local settingsPath
local outputPath
local weatherRunning = false
local lastWeatherOutput = nil
local lastWeatherStarted = 0
local nextWeatherRefresh = 0
local nextUpdateCheck = 0

local function launch(scriptPath, arguments)
    local command = 'start "" /B powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' ..
        scriptPath .. '"' .. arguments
    os.execute(command)
end

local function setVariable(name, value)
    SKIN:Bang("!SetVariable", name, value)
end

local function readOutput(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local contents = file:read("*a")
    file:close()
    return contents
end

local function applyOutput(contents)
    if not contents or contents == lastWeatherOutput then
        return false
    end
    lastWeatherOutput = contents
    for line in contents:gmatch("[^\r\n]+") do
        local key, value = line:match("^([%w_]+)=(.*)$")
        if key and key ~= "UpdatedAt" then
            setVariable(key, value)
        end
    end
    SKIN:Bang("!UpdateMeterGroup", "Weather")
    SKIN:Bang("!Redraw")
    return true
end

function Initialize()
    resources = SKIN:GetVariable("@")
    local appData = os.getenv("APPDATA") or "."
    local localData = os.getenv("LOCALAPPDATA") or appData
    settingsPath = appData .. "\\AethesticWeather\\settings.json"
    outputPath = localData .. "\\AethesticWeather\\weather.txt"
    lastWeatherOutput = readOutput(outputPath)
    RefreshWeather()
    CheckForUpdates()
    nextWeatherRefresh = os.time() + 900
    nextUpdateCheck = os.time() + 86400
end

function RefreshWeather()
    if weatherRunning then
        return
    end
    local scriptPath = resources .. "Scripts\\Weather.ps1"
    local arguments = ' -SettingsPath "' .. settingsPath .. '" -OutputPath "' .. outputPath .. '"'
    weatherRunning = true
    lastWeatherStarted = os.time()
    launch(scriptPath, arguments)
    setVariable("WeatherStatus", "Updating weather...")
    SKIN:Bang("!UpdateMeter", "MeterStatus")
    SKIN:Bang("!Redraw")
end

function CheckForUpdates()
    local scriptPath = resources .. "Scripts\\UpdateCheck.ps1"
    local settingsDirectory = settingsPath:match("^(.*)\\[^\\]+$")
    local arguments = ' -SettingsDirectory "' .. (settingsDirectory or ".") .. '"'
    launch(scriptPath, arguments)
end

function OpenSettings()
    local scriptPath = resources .. "Scripts\\Settings.ps1"
    local arguments = ' -SettingsPath "' .. settingsPath .. '"'
    launch(scriptPath, arguments)
end

function Update()
    local contents = readOutput(outputPath)
    if applyOutput(contents) then
        weatherRunning = false
    elseif weatherRunning and os.time() - lastWeatherStarted > 60 then
        weatherRunning = false
        setVariable("WeatherStatus", "Weather request timed out. Try Refresh Weather.")
    end

    local now = os.time()
    if now >= nextWeatherRefresh then
        RefreshWeather()
        nextWeatherRefresh = now + 900
    end
    if now >= nextUpdateCheck then
        CheckForUpdates()
        nextUpdateCheck = now + 86400
    end
end
