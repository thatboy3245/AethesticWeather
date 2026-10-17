# AethesticWeather

A cozy, pink Rainmeter weather widget for Windows. It supports personal weather stations through Tempest and public forecasts from the National Weather Service (NWS).

## Features

- Tempest observations and NWS forecasts, with location and source configured in a small settings window.
- A compact widget showing temperature, conditions, humidity, wind, and feels-like temperature when available.
- Original weather icons, with SVG source artwork and bundled PNGs for Rainmeter's native image meter.
- A daily GitHub release check with a Windows notification when a newer release is available.
- Settings and API credentials stored locally in `%APPDATA%\AethesticWeather\settings.json`.

The settings file is not encrypted. Keep it private if it contains a Tempest API key.

## Requirements

- Windows 10 or later.
- Rainmeter 4.5 or later.
- Windows PowerShell 5.1 (included with Windows).

## Install

Download the latest `.rmskin` from [GitHub Releases](https://github.com/thatboy3245/AethesticWeather/releases), open it, and install the skin. In Rainmeter, load `AethesticWeather\AethesticWeather`. Right-click the widget and choose **Open Settings** to configure it.

To build an installer from a source checkout, run this from the repository root in PowerShell:

```powershell
.\build\Build-Rmskin.ps1
```

The installer is written to `dist\AethesticWeather-1.0.0.rmskin`. The build regenerates the bundled PNG icons with Windows' built-in drawing libraries; the original SVG artwork is also included. It writes Rainmeter's required package metadata and footer so the Skin Installer recognizes the file.

## Configure a weather source

Open **Settings** from the widget's right-click menu.

### NWS

1. Select **NWS**.
2. Enter a city name and decimal latitude and longitude.
3. Enter a contact email address or URL in **NWS User-Agent**. The NWS API requires clients to identify themselves.
4. Click **Find** to resolve and save the permanent NWS forecast URL and grid location.
5. Click **Save**. The widget fetches the current NWS forecast period and refreshes every 15 minutes.

### Tempest

1. Select **Tempest**.
2. Enter a city name, Tempest API key, device ID, and station ID from your WeatherFlow/Tempest account.
3. Click **Save**. The widget fetches station observations and refreshes every 15 minutes.

If a request fails, its error is shown in the widget's status line. Use **Refresh Weather** from the right-click menu to retry.

## Updates and development

The skin checks the GitHub Releases API once a day. Notifications appear only after a newer stable release has been published. Network access is needed for weather requests and update checks.

Source files are in `AethesticWeather\`; the `.rmskin` build script is in `build\`. The SVG icons are original project artwork. Rainmeter's native image meter does not support SVG, so the installed skin uses the bundled PNG icons.

## License

The project is distributed under the MIT License. See [LICENSE](LICENSE).
