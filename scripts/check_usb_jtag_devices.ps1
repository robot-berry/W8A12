param(
  [string]$OutputDir = "board_runs\usb_jtag_device_diag"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-OutputDirectory {
  param([string]$PathValue)
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return $PathValue
  }
  return (Join-Path $root $PathValue)
}

function Get-StringValue {
  param([object]$Value)
  if ($null -eq $Value) { return "" }
  return [string]$Value
}

$outDirAbs = Resolve-OutputDirectory $OutputDir
New-Item -ItemType Directory -Force -Path $outDirAbs | Out-Null
$txtPath = Join-Path $outDirAbs "usb_jtag_devices.txt"
$jsonPath = Join-Path $outDirAbs "usb_jtag_devices.json"

$knownVidPidPattern = "VID_03FD|VID_0403|VID_1443|VID_04B4"
$namePattern = "Digilent|Xilinx|JTAG|FTDI|USB Serial|USB Composite|UART"

$all = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue)
$matchedDevices = @(
  $all | Where-Object {
    ((Get-StringValue $_.Name) -match $namePattern) -or
    ((Get-StringValue $_.DeviceID) -match $knownVidPidPattern)
  } | Sort-Object Name,DeviceID
)
$known = @(
  $matchedDevices | Where-Object {
    ((Get-StringValue $_.Name) -match "Digilent|Xilinx|JTAG|FTDI|USB Serial|UART") -or
    ((Get-StringValue $_.DeviceID) -match $knownVidPidPattern)
  }
)

$records = @(
  $matchedDevices | ForEach-Object {
    [pscustomobject]@{
      Name = Get-StringValue $_.Name
      PNPClass = Get-StringValue $_.PNPClass
      Status = Get-StringValue $_.Status
      DeviceID = Get-StringValue $_.DeviceID
      IsKnownJtagCandidate = (
        ((Get-StringValue $_.Name) -match "Digilent|Xilinx|JTAG|FTDI|USB Serial|UART") -or
        ((Get-StringValue $_.DeviceID) -match $knownVidPidPattern)
      )
    }
  }
)

$historyRecords = @()
if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
  $historyRecords = @(
    Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
      ((Get-StringValue $_.FriendlyName) -match $namePattern) -or
      ((Get-StringValue $_.InstanceId) -match $knownVidPidPattern)
    } | Sort-Object FriendlyName,InstanceId | ForEach-Object {
      [pscustomobject]@{
        FriendlyName = Get-StringValue $_.FriendlyName
        Class = Get-StringValue $_.Class
        Status = Get-StringValue $_.Status
        InstanceId = Get-StringValue $_.InstanceId
        IsKnownJtagCandidate = (
          ((Get-StringValue $_.FriendlyName) -match "Digilent|Xilinx|JTAG|FTDI|USB Serial|UART") -or
          ((Get-StringValue $_.InstanceId) -match $knownVidPidPattern)
        )
      }
    }
  )
}
$historyKnown = @($historyRecords | Where-Object { $_.IsKnownJtagCandidate })
$historyKnownVidPid = @($historyRecords | Where-Object { (Get-StringValue $_.InstanceId) -match $knownVidPidPattern })

$summary = [pscustomobject]@{
  GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  MatchCount = $records.Count
  KnownJtagCandidateCount = $known.Count
  PnpHistoryKnownJtagCandidateCount = $historyKnown.Count
  PnpHistoryKnownVidPidCount = $historyKnownVidPid.Count
  KnownVidPidPattern = $knownVidPidPattern
  NamePattern = $namePattern
  Devices = $records
  PnpHistoryDevices = $historyRecords
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("USB_JTAG_DIAG_TIME=$($summary.GeneratedAt)")
$lines.Add("USB_JTAG_DIAG_MATCH_COUNT=$($summary.MatchCount)")
$lines.Add("USB_JTAG_DIAG_KNOWN_CANDIDATE_COUNT=$($summary.KnownJtagCandidateCount)")
$lines.Add("USB_JTAG_DIAG_PNP_HISTORY_KNOWN_CANDIDATE_COUNT=$($summary.PnpHistoryKnownJtagCandidateCount)")
$lines.Add("USB_JTAG_DIAG_PNP_HISTORY_KNOWN_VIDPID_COUNT=$($summary.PnpHistoryKnownVidPidCount)")
$lines.Add("USB_JTAG_DIAG_KNOWN_VIDPID_PATTERN=$knownVidPidPattern")
foreach ($record in $records) {
  $lines.Add(("USB_JTAG_DEVICE name=""{0}"" class=""{1}"" status=""{2}"" known={3} id=""{4}""" -f `
    $record.Name, $record.PNPClass, $record.Status, $record.IsKnownJtagCandidate, $record.DeviceID))
}
if ($records.Count -eq 0) {
  $lines.Add("USB_JTAG_DEVICE_MATCHES=NONE")
}
foreach ($record in $historyRecords) {
  $lines.Add(("USB_JTAG_HISTORY_DEVICE name=""{0}"" class=""{1}"" status=""{2}"" known={3} id=""{4}""" -f `
    $record.FriendlyName, $record.Class, $record.Status, $record.IsKnownJtagCandidate, $record.InstanceId))
}
if ($historyRecords.Count -eq 0) {
  $lines.Add("USB_JTAG_HISTORY_DEVICE_MATCHES=NONE")
}

$lines | Set-Content -Path $txtPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "USB_JTAG_DIAG_TXT=$txtPath"
Write-Host "USB_JTAG_DIAG_JSON=$jsonPath"
Write-Host "USB_JTAG_DIAG_MATCH_COUNT=$($summary.MatchCount)"
Write-Host "USB_JTAG_DIAG_KNOWN_CANDIDATE_COUNT=$($summary.KnownJtagCandidateCount)"
Write-Host "USB_JTAG_DIAG_PNP_HISTORY_KNOWN_CANDIDATE_COUNT=$($summary.PnpHistoryKnownJtagCandidateCount)"
Write-Host "USB_JTAG_DIAG_PNP_HISTORY_KNOWN_VIDPID_COUNT=$($summary.PnpHistoryKnownVidPidCount)"
