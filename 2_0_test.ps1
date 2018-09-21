<# Code by MSP-Greg
Runs Ruby tests with STDOUT & STDERR sent to two files, allows setting a max
time, so if a test freezes, it can be stopped.
#>

#————————————————————————————————————————————————————————————————————— Kill-Proc
# Kills a process by first looping thru child & grandchild processes and
# stopping them, then stops passed process
function Kill-Proc($proc) {
  $processes = @()
  $p_pid = $proc.id
  $temp = $(Get-CimInstance -ClassName Win32_Process | where {$_.ProcessId -eq $p_pid} )

  $parents = @($temp)

  while ($parents -and $parents.length -gt 0) {
    $processes += $parents
    $children = @()
    foreach ($parent in $parents) {
      [int32]$p_pid = $parent.ProcessId
      $children += $(Get-CimInstance -ClassName Win32_Process |
        where {$_.ParentProcessId -eq $p_pid} )
    }
    $parents = $children
  }
  $t = -1 * ($processes.length)
  $r_processes = $processes[-1..$t]

  Write-Host "Process           pid   parent" -ForegroundColor $fc
  foreach ($process in $r_processes) {
    $t = "{0,-14}  {1,5}    {2,5}" -f @($process.Name, $process.ProcessId, $process.ParentProcessId)
    Write-Host $t
  }
  foreach ($process in $r_processes) {
    $id = $process.ProcessId
    if (!$process.HasExited) {
      Stop-Process -Id $id -Force
      sleep (0.1)
    }
  }
  Write-Host "Processes Killed!" -ForegroundColor $fc
}

#—————————————————————————————————————————————————————————————————————— Run-Proc
# Runs a process with a timeout setting, sets STDOUT & STDERR to files
# Outputs running dots to console
function Run-Proc {
  Param( [string]$StdOut , [string]$exe    , [string]$Title ,
         [string]$StdErr , [string]$e_args , [string]$Dir   , [int]$TimeLimit
  )

  Write-Host "$($dash * 35) $Title" -ForegroundColor $fc

  if ($TimeLimit -eq $null -or $TimeLimit -eq 0 ) {
    Write-Host "Need TimeLimit!"
    exit
  }
  $msg = "Time Limit {0,8:n1} s       {1}" -f @($TimeLimit, $(Get-Date -Format mm:ss))
  Write-Host $msg

  $start = Get-Date
  $status = ''

  $proc = Start-Process $exe -ArgumentList $e_args `
    -RedirectStandardOutput $d_logs/$StdOut `
    -RedirectStandardError  $d_logs/$StdErr `
    -WorkingDirectory $Dir `
    -NoNewWindow -PassThru

  $handle = $proc.Handle

  Wait-Process -Id $proc.id -Timeout $TimeLimit -ea 0 -ev froze
  if ($froze) {
    Write-Host "Exceeded time limit..." -ForegroundColor $fc
    $handle = $null
    Kill-Proc $proc
    $status = " (frozen)"
  }
  $diff = New-TimeSpan -Start $start -End $(Get-Date)
  $msg = "Test Time  {0,8:n1}" -f @($diff.TotalSeconds)
  Write-Host $msg -NoNewLine
  if ($proc.ExitCode -eq 0) {
    Write-Host " passed" -ForegroundColor Green
  } else {
    Write-Host " failed" -ForegroundColor Red
    $status = " (failed)"
  }
  $script:time_info += ("{0:mm}:{0:ss} {1}`n" -f @($diff, "$Title$status"))
  $handle = $null
  $proc   = $null
}

#———————————————————————————————————————————————————————————————————————— Finish
# cleanup, save artifacts, etc
function Finish {
  # test time info message and file
  $diff = New-TimeSpan -Start $m_start -End $(Get-Date)
  $script:time_info += ("{0:mm}:{0:ss} {1}`n" -f @($diff, "Total"))
  $fn = "$d_logs/time_log_tests.log"
  [IO.File]::WriteAllText($fn, $script:time_info, $UTF8)
  if ($is_av) {
    Add-AppveyorMessage -Message "Time Log Test" -Details $script:time_info
  }

  # remove zero length log files, typically stderr files
  $zero_length_files = Get-ChildItem -Path $d_logs -Include *.log -Recurse |
    where {$_.length -eq 0}
  foreach ($file in $zero_length_files) { Remove-Item -Path $file -Force }

  $env:path = "$d_install/bin;$d_repo/git/cmd;$base_path"

  # seems to be needed for proper dash encoding in 2_1_test_script.rb
  [Console]::OutputEncoding = New-Object -typename System.Text.UTF8Encoding

  # used in 2_1_test_script.rb
  $env:PS_ENC = [Console]::OutputEncoding.HeaderName

  cd $d_repo
  # script checks test results, determines whether build is good or not,
  # saves artifacts and adds messages to build
  ruby 2_1_test_script.rb $bits $install
  $exit = ($LastExitCode -and $LastExitCode -ne 0)

  if ($exit) { exit 1 }
}

#—————————————————————————————————————————————————————————————————————
function BasicTest {
  $env:path = "$d_install/bin;$base_path"
  # needs miniruby at root (build)
  $env:RUBY = $ruby_exe
  Run-Proc `
    -exe    "ruby.exe" `
    -e_args "-rdevkit --disable-gems ../ruby/basictest/runner.rb" `
    -StdOut "test_basic.log" `
    -StdErr "test_basic_err.log" `
    -Title  "test-basic" `
    -Dir    $d_build `
    -TimeLimit 20
}

#————————————————————————————————————————————————————————————————— BootStrapTest
function BootStrapTest {
  $env:path = "$d_install/bin;$base_path"

  Run-Proc `
    -exe    $ruby_exe `
    -e_args "--disable=gems runner.rb --ruby=`"$ruby_exe --disable=gems`" -v" `
    -StdOut "test_bootstrap.log" `
    -StdErr "test_bootstrap_err.log" `
    -Title  "btest" `
    -Dir    "$d_ruby/bootstraptest" `
    -TimeLimit 100
}

#—————————————————————————————————————————————————————————————————————— Test-All
function Test-All {
  # Standard Ruby CI doesn't run this test, remove for better comparison
  # $remove_test = "$d_ruby/test/ruby/enc/test_case_comprehensive.rb"
  # if (Test-Path -Path $remove_test -PathType Leaf) { Remove-Item -Path $remove_test }

  # copy items from build folder that are needed for test-all
  $ruby_so = "$d_install/lib/ruby/$abi/$rarch"
  Copy-Item "$d_build/.ext/x64-mingw32/-test-" $ruby_so -Recurse
  New-Item  -Path "$ruby_so/-test-/win32/dln" -ItemType Directory 1> $null
  Copy-Item "$d_build/ext/-test-/win32/dln/dlntest.dll" `
                "$ruby_so/-test-/win32/dln/dlntest.dll"

  $env:path = "$d_install/bin;$d_repo/git/cmd$base_path"
  $env:RUBY_FORCE_TEST_JIT = '1'

  $args = "--disable=gems -rdevkit runner.rb -X ./excludes -n !/memory_leak/ -j $jobs" + `
    " -a --show-skip --retry --job-status=normal --subprocess-timeout-scale=1.5"

  Run-Proc `
    -exe    $ruby_exe `
    -e_args $args `
    -StdOut "test_all.log" `
    -StdErr "test_all_err.log" `
    -Title  "test-all" `
    -Dir    "$d_ruby/test" `
    -TimeLimit 1500

  Remove-Item -Path "$d_install/lib/ruby/$abi/$rarch/-test-" -Recurse
}

#————————————————————————————————————————————————————————————————————————— MSpec
function MSpec {
  $env:path = "$d_install/bin;$d_repo/git/cmd;$base_path"

  Run-Proc `
    -exe    "ruby.exe" `
    -e_args "--disable=gems -rdevkit ../mspec/bin/mspec -j -T `"--disable=gems`"" `
    -StdOut "test_mspec.log" `
    -StdErr "test_mspec_err.log" `
    -Title  "test-mspec" `
    -Dir    "$d_ruby/spec/ruby" `
    -TimeLimit 240
}

#————————————————————————————————————————————————————————————————————————— setup
# defaults to 64 bit
$bits = if ($args.length -eq 1 -and $args[0] -eq 32) { 32 } else { 64 }

cd $PSScriptRoot
. ./0_common.ps1
Set-Variables

$ruby_exe  = "$d_install/bin/ruby.exe"
$abi       = &$ruby_exe -e "print RbConfig::CONFIG['ruby_version']"
$script:time_info = ''

#————————————————————————————————————————————————————————————————— start testing
# test using readline.so, not rb-readline
ren "$d_install/lib/ruby/site_ruby/readline.rb" "readline.rb_"

# PATH is set in each test function

$m_start = Get-Date

BasicTest
sleep 2
BootStrapTest
sleep 2
Test-All
sleep 5
MSpec

ren "$d_install/lib/ruby/site_ruby/readline.rb_" "readline.rb"

Finish
