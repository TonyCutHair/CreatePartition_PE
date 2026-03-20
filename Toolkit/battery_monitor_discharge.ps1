param(
    [int]$HighThreshold = 78,
    [int]$LowThreshold = 50,
    [int]$IntervalSeconds = 60,
    [int]$StatusRefreshSeconds = 2,
    [int]$WorkerCount = 0,
    [int]$MaxCycles = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if ($WorkerCount -le 0) {
    $WorkerCount = [Math]::Max(1, [Environment]::ProcessorCount - 1)
}

$jobs = @()

function Write-Log {
    param([string]$Message)
    # Intentionally silent.
}

function Get-BatteryInfo {
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if (-not $battery) {
        return [PSCustomObject]@{
            Exists   = $false
            Percent  = $null
            OnAC     = $null
            Raw      = $null
        }
    }

    $status = [int]$battery.BatteryStatus
    $onAC = $false
    if ($status -in 2, 6, 7, 8, 9, 11) {
        $onAC = $true
    }

    return [PSCustomObject]@{
        Exists   = $true
        Percent  = [int]$battery.EstimatedChargeRemaining
        OnAC     = $onAC
        Raw      = $battery
    }
}

function Start-DischargeLoad {
    param([int]$Count)

    if ($script:jobs.Count -gt 0) {
        return
    }

    Write-Log ("Start discharge load. Workers={0}" -f $Count)

    for ($i = 1; $i -le $Count; $i++) {
        $job = Start-Job -ScriptBlock {
            # Pure CPU + memory math loop. No file I/O.
            $rng = [System.Random]::new()
            $arr = New-Object double[] 400000
            while ($true) {
                for ($j = 0; $j -lt $arr.Length; $j++) {
                    $x = $rng.NextDouble() * 100000
                    $arr[$j] = [Math]::Sqrt($x) * [Math]::Sin($x)
                }
            }
        }
        $script:jobs += $job
    }
}

function Stop-DischargeLoad {
    if ($script:jobs.Count -eq 0) {
        return
    }

    Write-Log "Stop discharge load."
    foreach ($job in $script:jobs) {
        try {
            Stop-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
        }
        catch {
            # Ignore cleanup errors.
        }
    }
    $script:jobs = @()
}

try {
    Write-Log "Battery monitor started."
    Write-Log ("Config: High>{0}%, Low<{1}%, Interval={2}s, StatusRefresh={3}s, Workers={4}, MaxCycles={5}" -f $HighThreshold, $LowThreshold, $IntervalSeconds, $StatusRefreshSeconds, $WorkerCount, $MaxCycles)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Battery Monitor'
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.Location = New-Object System.Drawing.Point(0, 0)
    $form.Size = New-Object System.Drawing.Size(600, 320)
    $form.TopMost = $true
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $false
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(570, 78)
    $label.Font = New-Object System.Drawing.Font('Consolas', 24, [System.Drawing.FontStyle]::Bold)
    $label.Text = 'Initializing...'
    $form.Controls.Add($label)

    $rangeLabel = New-Object System.Windows.Forms.Label
    $rangeLabel.AutoSize = $true
    $rangeLabel.Location = New-Object System.Drawing.Point(12, 90)
    $rangeLabel.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $rangeLabel.ForeColor = [System.Drawing.Color]::OrangeRed
    $rangeLabel.Text = ('Target Range: {0}% - {1}%' -f $LowThreshold, $HighThreshold)
    $form.Controls.Add($rangeLabel)

    $hint = New-Object System.Windows.Forms.Label
    $hint.AutoSize = $true
    $hint.Location = New-Object System.Drawing.Point(10, 138)
    $hint.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $hint.Text = 'Close window to stop monitor.'
    $form.Controls.Add($hint)

    $shutdownButton = New-Object System.Windows.Forms.Button
    $shutdownButton.Text = 'Shutdown'
    $shutdownButton.Size = New-Object System.Drawing.Size(165, 45)
    $shutdownButton.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $buttonX = [int](($form.ClientSize.Width - $shutdownButton.Width) / 2)
    $shutdownButton.Location = New-Object System.Drawing.Point($buttonX, 185)
    $shutdownButton.BackColor = [System.Drawing.Color]::Tomato
    $shutdownButton.ForeColor = [System.Drawing.Color]::White
    $shutdownButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Standard
    $shutdownButton.add_Click({
        Stop-Computer -Force
    })
    $form.Controls.Add($shutdownButton)

    $cycle = 0
    $lastControlAt = [DateTime]::MinValue
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = [Math]::Max(1, $StatusRefreshSeconds) * 1000

    $tickHandler = {
        $script:cycle++
        $info = Get-BatteryInfo

        if (-not $info.Exists) {
            $label.ForeColor = [System.Drawing.Color]::Red
            $label.Text = 'No battery detected'
            Write-Log 'No battery detected (desktop or driver unavailable). Monitoring only.'
            Stop-DischargeLoad
        }
        else {
            $acText = if ($info.OnAC) { 'AC' } else { 'BAT' }
            $inRange = ($info.Percent -ge $LowThreshold -and $info.Percent -le $HighThreshold)

            if ($inRange) {
                $label.ForeColor = [System.Drawing.Color]::Green
            }
            else {
                $label.ForeColor = [System.Drawing.Color]::Red
            }

            $label.Text = ('Battery: {0}%  {1}' -f $info.Percent, $acText)

            $elapsed = ((Get-Date) - $script:lastControlAt).TotalSeconds
            if ($elapsed -ge [Math]::Max(1, $IntervalSeconds) -or $script:lastControlAt -eq [DateTime]::MinValue) {
                $script:lastControlAt = Get-Date
                Write-Log ("Battery: {0}% | {1}" -f $info.Percent, $acText)

                if ($info.Percent -gt $HighThreshold) {
                    Start-DischargeLoad -Count $WorkerCount
                }
                elseif ($info.Percent -lt $LowThreshold) {
                    Stop-DischargeLoad
                }
                else {
                    Write-Log 'Battery in target range.'
                }
            }
        }

        if ($MaxCycles -gt 0 -and $script:cycle -ge $MaxCycles) {
            Write-Log ("MaxCycles reached ({0}). Exit loop for debug run." -f $MaxCycles)
            $timer.Stop()
            $form.Close()
        }
    }

    $timer.add_Tick($tickHandler)
    $form.add_Shown({
        & $tickHandler
        $timer.Start()
    })
    $form.add_FormClosing({
        $timer.Stop()
    })

    [void][System.Windows.Forms.Application]::Run($form)
}
finally {
    Stop-DischargeLoad
    Write-Log "Battery monitor exited."
}
