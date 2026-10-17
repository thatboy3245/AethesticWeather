$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$imageDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'AethesticWeather\@Resources\Images'
[IO.Directory]::CreateDirectory($imageDirectory) | Out-Null

function New-Brush([int]$R, [int]$G, [int]$B) {
    return [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($R, $G, $B))
}

function Save-Icon([string]$Name, [string]$Kind) {
    $bitmap = [System.Drawing.Bitmap]::new(128, 128)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $gold = New-Brush 255 209 102
    $cloud = New-Brush 185 167 198
    $snow = New-Brush 98 169 209
    $outline = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(142, 125, 156), 4)
    $blue = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(98, 169, 209), 6)
    $blue.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $blue.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    if ($Kind -eq 'clear' -or $Kind -eq 'cloudy') {
        $graphics.FillEllipse($gold, 24, 22, 50, 50)
        $sunPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(244, 169, 79), 5)
        for ($angle = 0; $angle -lt 360; $angle += 45) {
            $radians = $angle * [Math]::PI / 180
            $x1 = 49 + [Math]::Cos($radians) * 33
            $y1 = 47 + [Math]::Sin($radians) * 33
            $x2 = 49 + [Math]::Cos($radians) * 43
            $y2 = 47 + [Math]::Sin($radians) * 43
            $graphics.DrawLine($sunPen, [single]$x1, [single]$y1, [single]$x2, [single]$y2)
        }
        $sunPen.Dispose()
    }

    if ($Kind -ne 'clear') {
        $graphics.FillEllipse($cloud, 19, 52, 48, 42)
        $graphics.FillEllipse($cloud, 41, 34, 49, 56)
        $graphics.FillEllipse($cloud, 66, 53, 40, 40)
        $graphics.FillRectangle($cloud, 37, 61, 50, 29)
        $graphics.DrawArc($outline, 14, 52, 48, 42, 100, 205)
        $graphics.DrawArc($outline, 38, 34, 54, 56, 180, 180)
        $graphics.DrawArc($outline, 62, 51, 45, 42, 205, 155)
        $graphics.DrawLine($outline, 28, 93, 89, 93)
    }

    if ($Kind -eq 'rain') {
        $graphics.DrawLine($blue, 37, 99, 30, 113)
        $graphics.DrawLine($blue, 64, 99, 57, 113)
        $graphics.DrawLine($blue, 88, 99, 81, 113)
    }
    elseif ($Kind -eq 'snow') {
        foreach ($x in @(34, 63, 91)) { $graphics.FillEllipse($snow, $x - 4, 101, 9, 9) }
    }
    elseif ($Kind -eq 'storm') {
        $bolt = [System.Drawing.Point[]]@(
            [System.Drawing.Point]::new(62, 83), [System.Drawing.Point]::new(44, 108),
            [System.Drawing.Point]::new(58, 108), [System.Drawing.Point]::new(53, 125),
            [System.Drawing.Point]::new(79, 93), [System.Drawing.Point]::new(64, 93)
        )
        $graphics.FillPolygon($gold, $bolt)
    }

    $bitmap.Save((Join-Path $imageDirectory ($Name + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $blue.Dispose()
    $outline.Dispose()
    $gold.Dispose()
    $cloud.Dispose()
    $snow.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

foreach ($name in @('clear', 'cloudy', 'rain', 'snow', 'storm')) {
    Save-Icon $name $name
}
