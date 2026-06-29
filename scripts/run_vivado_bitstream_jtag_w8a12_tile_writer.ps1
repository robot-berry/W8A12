param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [ValidateRange(1, 128)]
  [int]$ImgW = 32,
  [ValidateRange(1, 128)]
  [int]$TileW = 32,
  [ValidateRange(1, 128)]
  [int]$TileH = 32,
  [ValidateRange(0, 64)]
  [int]$Halo = 21,
  [ValidateRange(1, 300)]
  [int]$PlFreqMhz = 100,
  [ValidateRange(1, 64)]
  [int]$OutLanes = 8,
  [ValidateRange(1, 128)]
  [int]$TapLanes = 16,
  [ValidateRange(1, 16)]
  [int]$ScaleLanes = 2,
  [ValidateRange(0, 3)]
  [int]$DebugExportLevel = 2,
  [int]$MinAvailablePageFileMb = 0,
  [switch]$RequireVivadoIdle,
  [int]$WaitForVivadoIdleSeconds = 0,
  [int]$StableVivadoIdleSeconds = 0,
  [ValidateRange(1, 16)]
  [int]$VivadoMaxThreads = 1,
  [ValidateSet("Default", "RuntimeOptimized", "AreaOptimized_high", "AreaOptimized_medium", "AlternateRoutability")]
  [string]$SynthDirective = "RuntimeOptimized",
  [string]$AttemptLabel = ""
)

$ErrorActionPreference = "Stop"

function Get-ReportValue {
  param([string]$Text, [string]$Pattern)
  $m = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($m.Success) { return $m.Groups[1].Value }
  return ""
}

function Get-VivadoPeakMemoryMb {
  param([string]$LogPath)
  if (-not (Test-Path $LogPath)) { return "" }
  $text = Get-Content -Raw -Path $LogPath
  $peaks = [regex]::Matches($text, "Memory \(MB\): peak =\s*([0-9.]+)") | ForEach-Object {
    [double]$_.Groups[1].Value
  }
  if (-not $peaks) { return "" }
  return ("{0:F3}" -f (($peaks | Measure-Object -Maximum).Maximum))
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if (-not (Test-Path $VivadoBat)) { throw "Vivado batch executable not found: $VivadoBat" }
  if ($ImgW -ne $TileW -or $ImgW -ne $TileH) {
    throw "Current board acceptance wrapper supports one full tile only: require ImgW == TileW == TileH"
  }

  if ($RequireVivadoIdle -or $WaitForVivadoIdleSeconds -gt 0) {
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_vivado_idle.ps1 -WaitSeconds $WaitForVivadoIdleSeconds -StableIdleSeconds $StableVivadoIdleSeconds
    if ($LASTEXITCODE -ne 0) { throw "Vivado idle preflight failed with exit code $LASTEXITCODE" }
  }
  if ($MinAvailablePageFileMb -gt 0) {
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_vivado_host_memory.ps1 -MinAvailablePageFileMb $MinAvailablePageFileMb
  } else {
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_vivado_host_memory.ps1
  }
  if ($LASTEXITCODE -ne 0) { throw "Vivado host memory preflight failed with exit code $LASTEXITCODE" }

  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\pack_w8a12_group_weights.ps1 -OutLanes $OutLanes -TapLanes $TapLanes
  if ($LASTEXITCODE -ne 0) { throw "pack_w8a12_group_weights.ps1 failed with exit code $LASTEXITCODE" }

  $tag = "x4_imgw{0}_tile{1}x{2}_h{3}_f{4}m_ol{5}_tl{6}_sl{7}" -f $ImgW, $TileW, $TileH, $Halo, $PlFreqMhz, $OutLanes, $TapLanes, $ScaleLanes
  $tag = "{0}_dbg{1}" -f $tag, $DebugExportLevel
  $projectLabel = $tag
  if (-not [string]::IsNullOrWhiteSpace($AttemptLabel)) {
    $safeLabel = $AttemptLabel -replace '[^A-Za-z0-9_=-]', '_'
    $tag = "{0}_{1}" -f $tag, $safeLabel
    $projectLabel = $safeLabel
  }

  $projectDir = Join-Path $root ("vivado\jwtw_{0}" -f $projectLabel)

  $attemptDir = Join-Path $root "board_runs\w8a12_tile_writer_bitstream_attempts"
  New-Item -ItemType Directory -Path $attemptDir -Force | Out-Null
  $vivadoLog = Join-Path $attemptDir ("jtag_w8a12_tile_writer_{0}.log" -f $tag)
  $vivadoJournal = Join-Path $attemptDir ("jtag_w8a12_tile_writer_{0}.jou" -f $tag)
  $tclScript = Join-Path $root "scripts\run_vivado_bitstream_jtag_w8a12_tile_writer.tcl"

  $env:JTAG_W8A12_TILE_WRITER_IMG_W = [string]$ImgW
  $env:JTAG_W8A12_TILE_WRITER_TILE_W = [string]$TileW
  $env:JTAG_W8A12_TILE_WRITER_TILE_H = [string]$TileH
  $env:JTAG_W8A12_TILE_WRITER_HALO = [string]$Halo
  $env:JTAG_W8A12_TILE_WRITER_PL_FREQ_MHZ = [string]$PlFreqMhz
  $env:JTAG_W8A12_TILE_WRITER_OUT_LANES = [string]$OutLanes
  $env:JTAG_W8A12_TILE_WRITER_TAP_LANES = [string]$TapLanes
  $env:JTAG_W8A12_TILE_WRITER_SCALE_LANES = [string]$ScaleLanes
  $env:JTAG_W8A12_TILE_WRITER_DEBUG_EXPORT_LEVEL = [string]$DebugExportLevel
  $env:JTAG_W8A12_TILE_WRITER_MAX_THREADS = [string]$VivadoMaxThreads
  $env:JTAG_W8A12_TILE_WRITER_SYNTH_DIRECTIVE = $SynthDirective
  $env:JTAG_W8A12_TILE_WRITER_PROJECT_DIR = $projectDir

  $vivadoWorkDir = Join-Path ([System.IO.Path]::GetTempPath()) "w8a12_jtag_tile_writer_vivado_work"
  New-Item -ItemType Directory -Path $vivadoWorkDir -Force | Out-Null
  $cleanAppData = Join-Path $vivadoWorkDir "appdata\roaming"
  $cleanLocalAppData = Join-Path $vivadoWorkDir "appdata\local"
  New-Item -ItemType Directory -Path $cleanAppData -Force | Out-Null
  New-Item -ItemType Directory -Path $cleanLocalAppData -Force | Out-Null
  $oldAppData = $env:APPDATA
  $oldLocalAppData = $env:LOCALAPPDATA
  Push-Location $vivadoWorkDir
  try {
    $env:APPDATA = $cleanAppData
    $env:LOCALAPPDATA = $cleanLocalAppData
    & $VivadoBat -mode batch -source $tclScript -log $vivadoLog -journal $vivadoJournal
    if ($LASTEXITCODE -ne 0) {
      $peak = Get-VivadoPeakMemoryMb $vivadoLog
      if (-not [string]::IsNullOrWhiteSpace($peak)) { Write-Host "VIVADO_PEAK_MEMORY_MB=$peak" }
      throw "Vivado JTAG W8A12 tile-writer bitstream flow failed with exit code $LASTEXITCODE"
    }
  } finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    Pop-Location
  }

  $bitDir = Join-Path $root "vivado\bitstreams"
  New-Item -ItemType Directory -Path $bitDir -Force | Out-Null
  $srcBit = Join-Path $projectDir "jwtw.runs\impl_1\jwtw_wrapper.bit"
  $dstBit = Join-Path $bitDir ("jtag_w8a12_tile_writer_{0}.bit" -f $tag)
  Copy-Item -LiteralPath $srcBit -Destination $dstBit -Force

  $reportDir = Join-Path $root "vivado\reports"
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
  $srcUtil = Join-Path $projectDir "reports\jtag_w8a12_tile_writer_utilization_impl.rpt"
  $srcTiming = Join-Path $projectDir "reports\jtag_w8a12_tile_writer_timing_impl.rpt"
  $dstUtil = Join-Path $reportDir ("jtag_w8a12_tile_writer_{0}_utilization_impl.rpt" -f $tag)
  $dstTiming = Join-Path $reportDir ("jtag_w8a12_tile_writer_{0}_timing_impl.rpt" -f $tag)
  Copy-Item -LiteralPath $srcUtil -Destination $dstUtil -Force
  Copy-Item -LiteralPath $srcTiming -Destination $dstTiming -Force

  $utilText = Get-Content -Raw -Path $dstUtil
  $timingText = Get-Content -Raw -Path $dstTiming
  $timingRow = [regex]::Match($timingText, "(?m)^\s*([-+]?\d+\.\d+)\s+[-+]?\d+\.\d+\s+\d+\s+\d+\s+([-+]?\d+\.\d+)")
  if ($timingRow.Success) {
    Write-Host "WNS_NS=$($timingRow.Groups[1].Value)"
    Write-Host "WHS_NS=$($timingRow.Groups[2].Value)"
  }
  Write-Host ("CLB_LUTS={0}" -f (Get-ReportValue $utilText "\|\s*CLB LUTs\*?\s*\|\s*([0-9]+)"))
  Write-Host ("CLB_REGISTERS={0}" -f (Get-ReportValue $utilText "\|\s*CLB Registers\s*\|\s*([0-9]+)"))
  Write-Host ("BRAM_TILE={0}" -f (Get-ReportValue $utilText "\|\s*Block RAM Tile\s*\|\s*([0-9.]+)"))
  Write-Host ("URAM={0}" -f (Get-ReportValue $utilText "\|\s*URAM\s*\|\s*([0-9.]+)"))
  Write-Host ("DSP={0}" -f (Get-ReportValue $utilText "\|\s*DSPs\s*\|\s*([0-9]+)"))
  $peakMem = Get-VivadoPeakMemoryMb $vivadoLog
  if (-not [string]::IsNullOrWhiteSpace($peakMem)) {
    Write-Host "VIVADO_PEAK_MEMORY_MB=$peakMem"
  }
  if ($timingText -match "Timing constraints are not met") {
    Write-Warning "TIMING_CHECK=FAIL; inspect $dstTiming"
  } else {
    Write-Host "TIMING_CHECK=PASS"
  }
  Write-Host "PASS run_vivado_bitstream_jtag_w8a12_tile_writer"
  Write-Host "JTAG_W8A12_TILE_WRITER_TAG=$tag"
  Write-Host "JTAG_W8A12_TILE_WRITER_BIT=$dstBit"
  Write-Host "JTAG_W8A12_TILE_WRITER_UTIL=$dstUtil"
  Write-Host "JTAG_W8A12_TILE_WRITER_TIMING=$dstTiming"
  Write-Host "JTAG_W8A12_TILE_WRITER_VIVADO_LOG=$vivadoLog"
} finally {
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_IMG_W -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_TILE_W -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_TILE_H -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_HALO -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_PL_FREQ_MHZ -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_OUT_LANES -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_TAP_LANES -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_SCALE_LANES -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_DEBUG_EXPORT_LEVEL -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_MAX_THREADS -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_SYNTH_DIRECTIVE -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_W8A12_TILE_WRITER_PROJECT_DIR -ErrorAction SilentlyContinue
  Pop-Location
}
