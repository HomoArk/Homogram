param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $ArgsForHarness
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptDir "homogram_ui_harness.py"

if (Get-Command uv -ErrorAction SilentlyContinue) {
  & uv run python $PythonScript @ArgsForHarness
  exit $LASTEXITCODE
}

& python $PythonScript @ArgsForHarness
exit $LASTEXITCODE
