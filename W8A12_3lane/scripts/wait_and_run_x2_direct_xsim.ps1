param(
    [double]$MinFreeMemoryGb = 4.0,
    [int]$MaxWaitMinutes = 60,
    [int]$PollSeconds = 30,
    [switch]$RequireNoActiveVivado
)

$ErrorActionPreference = "Stop"

if ($MaxWaitMinutes -lt 0) {
    throw "MaxWaitMinutes must be >= 0"
}
if ($PollSeconds -lt 1) {
    throw "PollSeconds must be >= 1"
}

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$DirectXsim = Join-Path $Repo "W8A12_3lane\scripts\run_xsim_direct_w8a12_packed2d_x2_720p20_perf_scheduler.ps1"
if (-not (Test-Path $DirectXsim)) {
    throw "Direct xsim script not found: $DirectXsim"
}

function Get-FreeMemoryGb {
    $Os = Get-CimInstance Win32_OperatingSystem
    [math]::Round($Os.FreePhysicalMemory / 1MB, 2)
}

function Get-ActiveSimSummary {
    $ActiveSim = @(Get-Process -Name xsim,xelab,xvlog,xvhdl -ErrorAction SilentlyContinue)
    if ($ActiveSim.Count -eq 0) {
        return ""
    }
    ($ActiveSim | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ","
}

function Get-ActiveVivadoSummary {
    $ActiveVivado = @(Get-CimInstance Win32_Process -Filter "name='vivado.exe'" -ErrorAction SilentlyContinue)
    if ($ActiveVivado.Count -eq 0) {
        return ""
    }
    ($ActiveVivado | ForEach-Object { "vivado:$($_.ProcessId)" }) -join ","
}

$Deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
$Attempt = 0

while ($true) {
    $Attempt += 1
    $FreeGb = Get-FreeMemoryGb
    $ActiveSimSummary = Get-ActiveSimSummary
    $NoActiveSim = [string]::IsNullOrWhiteSpace($ActiveSimSummary)
    $ActiveVivadoSummary = ""
    $NoActiveVivado = $true
    if ($RequireNoActiveVivado) {
        $ActiveVivadoSummary = Get-ActiveVivadoSummary
        $NoActiveVivado = [string]::IsNullOrWhiteSpace($ActiveVivadoSummary)
    }
    Write-Host "WAIT_X2_XSIM_CHECK attempt=$Attempt free_gb=$FreeGb min_free_gb=$MinFreeMemoryGb no_active_sim=$NoActiveSim no_active_vivado=$NoActiveVivado"
    if (-not $NoActiveSim) {
        Write-Host "WAIT_X2_XSIM_ACTIVE_SIM processes=$ActiveSimSummary"
    }
    if (-not $NoActiveVivado) {
        Write-Host "WAIT_X2_XSIM_ACTIVE_VIVADO processes=$ActiveVivadoSummary"
    }

    if (($FreeGb -ge $MinFreeMemoryGb) -and $NoActiveSim -and $NoActiveVivado) {
        Write-Host "WAIT_X2_XSIM_STATUS=RUNNING"
        $DirectArgs = @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $DirectXsim,
            "-MinFreeMemoryGb",
            $MinFreeMemoryGb,
            "-RequireNoActiveSim"
        )
        if ($RequireNoActiveVivado) {
            $DirectArgs += "-RequireNoActiveVivado"
        }
        & powershell @DirectArgs
        exit $LASTEXITCODE
    }

    if ((Get-Date) -ge $Deadline) {
        Write-Host "WAIT_X2_XSIM_TIMEOUT=1"
        Write-Host "WAIT_X2_XSIM_STATUS=DEFERRED"
        exit 2
    }

    Start-Sleep -Seconds $PollSeconds
}
