<# Code by MSP-Greg
Set env when using PowerShell
May sure to set $vcvars to match you local system
#>

#————————————————————————————————————————————————————————————————— Set-VCVars_Env
# Runs MSFT vcvars.bat and changes Powershell env
function Set-VCVars-Env() {
  $vcvars = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
#  $vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

  $data = $(iex "cmd.exe /c '`"$vcvars`" && echo QWERTY && set'")

  # Output 'header', skip to ENV data
  $idx = 1
  foreach ($e in $data) {
    if ($e.trim() -eq 'QWERTY') { break }
    echo $e
    $idx += 1
  }

  # Replace current ENV data with changes from vcvars
  foreach ($e in $data[$idx .. ($data.count-1)]) {
    $key, $val = $e -split '=', 2
    $old_val = [Environment]::GetEnvironmentVariable($key)
    if ($old_val -ne $val) {
      [Environment]::SetEnvironmentVariable($key, $val)
    }
  }
}

Set-VCVars-Env
$env:MAKE = 'nmake.exe'
