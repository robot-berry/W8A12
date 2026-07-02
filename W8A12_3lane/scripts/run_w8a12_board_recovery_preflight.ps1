param(
  [string]$OutputDir = "board_runs\w8a12_board_recovery_preflight",
  [string]$PreconditionOutDir = "W8A12_3lane\evidence\board_probe\jtag_precondition_current",
  [switch]$ForceVivadoProbe,
  [switch]$SkipVivadoProbe,
  [switch]$RunStageHashAcceptance,
  [switch]$FailOnBlocked
)

$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

Push-Location $Repo
try {
  $args = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", "scripts\run_w8a12_board_recovery_preflight.ps1",
    "-OutputDir", $OutputDir,
    "-PreconditionOutDir", $PreconditionOutDir
  )
  if ($ForceVivadoProbe) { $args += "-ForceVivadoProbe" }
  if ($SkipVivadoProbe) { $args += "-SkipVivadoProbe" }
  if ($RunStageHashAcceptance) { $args += "-RunStageHashAcceptance" }
  if ($FailOnBlocked) { $args += "-FailOnBlocked" }
  & powershell @args
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} finally {
  Pop-Location
}
