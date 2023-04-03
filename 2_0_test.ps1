<# Code by MSP-Greg
Runs Ruby tests with STDOUT & STDERR sent to two files, allows setting a max
time, so if a test freezes, it can be stopped.
#>

$exit_code = 0

$enc_input  = [Console]::InputEncoding
$enc_output = [Console]::OutputEncoding

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
      Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
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

  EchoC "$($dash * 35) $Title" yel

  if ($TimeLimit -eq $null -or $TimeLimit -eq 0 ) {
    echo "Need TimeLimit!"
    exit
  }
  $msg = "Time Limit {0,8:n1} s       {1}" -f @($TimeLimit, $(Get-Date -Format mm:ss))
  echo $msg

  $start = Get-Date
  $status = ''

  if ($is_actions) {
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding('IBM437')
    [Console]::InputEncoding  = [System.Text.Encoding]::GetEncoding('IBM437')
  }

  $proc = Start-Process $exe -ArgumentList $e_args `
    -RedirectStandardOutput $d_logs/$StdOut `
    -RedirectStandardError  $d_logs/$StdErr `
    -WorkingDirectory $Dir `
    -NoNewWindow -PassThru

  $handle = $proc.Handle

  Wait-Process -Id $proc.id -Timeout $TimeLimit -ea 0 -ev froze
  if ($froze) {
    EchoC "Exceeded time limit..." yel
    $handle = $null
    Kill-Proc $proc
    $status = " (frozen)"
  }
  $diff = New-TimeSpan -Start $start -End $(Get-Date)
  $msg = "Test Time  {0,8:n1}" -f @($diff.TotalSeconds)

  if ($is_actions) {
    [Console]::OutputEncoding = $enc_output
    [Console]::InputEncoding  = $enc_input
  }

  Write-Host $msg -NoNewLine
  if ($proc.ExitCode -eq 0) {
    EchoC " passed" grn
  } else {
    EchoC " failed" red
    $status = " (failed)"
  }
  $script:time_info += ("{0:mm}:{0:ss} {1}`n" -f @($diff, "$Title$status"))
  $handle = $null
  $proc   = $null
  Stop-Process -Name ruby -Force -ErrorAction SilentlyContinue
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
  foreach ($file in $zero_length_files) {
    Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
  }

  $env:PATH = "$d_install/bin;$d_repo/git/cmd;$base_path"

  # AppVeyor seems to be needed for proper dash encoding in 2_1_test_script.rb
  [Console]::OutputEncoding = New-Object -typename System.Text.UTF8Encoding

  # used in 2_1_test_script.rb
  $env:PS_ENC = [Console]::OutputEncoding.WebName.toUpper()

  EchoC "$dash_hdr Test Results" yel

  cd $d_repo
  # script checks test results, determines whether build is good or not,
  # saves artifacts and adds messages to build
  ruby.exe 2_1_test_script.rb $exit_code
  $exit += ($LastExitCode -and $LastExitCode -ne 0)
  ruby.exe -v -ropenssl -e "puts 'Build    ' + OpenSSL::OPENSSL_VERSION, 'Runtime  ' + OpenSSL::OPENSSL_LIBRARY_VERSION"
  if ($is_actions) {
    echo "Actions ImageVersion: $env:ImageVersion"
  } elseif ($is_av) {
    echo "Build worker image: $env:APPVEYOR_BUILD_WORKER_IMAGE"
  }
  $env:Path = $orig_path
  if ($exit -ne 0) { exit 1 }
}

#————————————————————————————————————————————————————————————————————— BasicTest
function BasicTest {
  $env:PATH = "$d_install/bin;$base_path"
  Run-Proc `
    -exe    "ruby.exe" `
    -e_args "--disable=gems ruby_runner.rb -r -v --tty=no" `
    -StdOut "test_basic.log" `
    -StdErr "test_basic_err.log" `
    -Title  "test-basic   (basictest)" `
    -Dir    "$d_ruby/basictest" `
    -TimeLimit 20
}

#————————————————————————————————————————————————————————————————— BootStrapTest
function BootStrapTest {
  $env:PATH = "$d_install/bin;$base_path"

  Run-Proc `
    -exe    $ruby_exe `
    -e_args "--disable=gems runner.rb --ruby=`"$ruby_exe --disable=gems`" -v" `
    -StdOut "test_bootstrap.log" `
    -StdErr "test_bootstrap_err.log" `
    -Title  "btest        (bootstraptest)" `
    -Dir    "$d_ruby/bootstraptest" `
    -TimeLimit 200
}

#—————————————————————————————————————————————————————————————————————— Test-All
function Test-All {
  # Standard Ruby CI doesn't run this test, remove for better comparison
  # $remove_test = "$d_ruby/test/ruby/enc/test_case_comprehensive.rb"
  # if (Test-Path -Path $remove_test -PathType Leaf) { Remove-Item -Path $remove_test }

  # copy items from build folder that are needed for test-all
  if (Test-Path -Path "$d_build/.ext/$rarch/-test-" -PathType Container) {
    $ruby_so = "$d_install/lib/ruby/$abi/$rarch"
    Copy-Item "$d_build/.ext/$rarch/-test-" $ruby_so -Recurse
    New-Item  -Path "$ruby_so/-test-/win32/dln" -ItemType Directory 1> $null
    Copy-Item "$d_build/ext/-test-/win32/dln/dlntest.dll" `
                  "$ruby_so/-test-/win32/dln/dlntest.dll"
  }

  $env:PATH = "$d_install/bin;$d_repo/git/cmd;$base_path"
  $env:RUBY_FORCE_TEST_JIT = '1'
  $env:RUBYGEMS_TEST_PATH  = "$d_repo/ruby/test/rubygems"
  # for rubygems/test_bundled_ca.rb
  $env:TEST_SSL = '1'

  if ($build_sys -ne 'mswin') {
    $args = "--disable=gems -rdevkit ./runner.rb -X ./excludes -n !/memory_leak/ -j $jobs" + `
      " -v --show-skip --retry --job-status=normal --timeout-scale=1.5"
  } else {
    $args = "--disable=gems ./runner.rb -X ./excludes -n !/memory_leak/ -j $jobs" + `
      " -v --show-skip --retry --job-status=normal --timeout-scale=1.5"
  }

  # find absolute path for ruby repo
  $test_dir = ((Get-Item "$d_ruby").LinkType -eq $null) ?
    "$d_ruby/test" : 
    "$(Get-Item "$d_ruby" | Select-Object -ExpandProperty Target)/test"

  Run-Proc `
    -exe    $ruby_exe `
    -e_args $args `
    -StdOut "test_all.log" `
    -StdErr "test_all_err.log" `
    -Title  "test-all" `
    -Dir    "$test_dir" `
    -TimeLimit 3000

  # comment out below to allow full testing of Appveyor artifact
  # Remove-Item -Path "$d_install/lib/ruby/$abi/$rarch/-test-" -Recurse
}

#——————————————————————————————————————————————————————————————————— Test-Reline
function Test-Reline {
  $env:PATH = "$d_install/bin;$d_repo/git/cmd;$base_path"

  $args = "--disable=gems -rrbconfig ./runner.rb -v --show-skip reline"

  Run-Proc `
    -exe    $ruby_exe `
    -e_args $args `
    -StdOut "test_reline.log" `
    -StdErr "test_reline_err.log" `
    -Title  "test-reline" `
    -Dir    "$d_ruby/test" `
    -TimeLimit 20
}

#————————————————————————————————————————————————————————————————————————— MSpec
function MSpec {
  $env:PATH = "$d_install/bin;$d_repo/git/cmd;$base_path"

  if ($build_sys -ne 'mswin') {
    $args = "-rdevkit ../mspec/bin/mspec -j -fd -I$d_ruby/tool/lib"
  } else {
    $args = "../mspec/bin/mspec -j -fd -I$d_ruby/tool/lib"
  }

  Run-Proc `
    -exe    "ruby.exe" `
    -e_args $args `
    -StdOut "test_mspec.log" `
    -StdErr "test_mspec_err.log" `
    -Title  "test-mspec" `
    -Dir    "$d_ruby/spec/ruby" `
    -TimeLimit 480
}

#————————————————————————————————————————————————————————————————————————— setup
cd $PSScriptRoot
. ./0_common.ps1 $args
Set-Variables

# apply patches for testing
Run-Patches @('patches_basic_boot', 'patches_spec', 'patches_test')

$ruby_exe  = "$d_install/bin/ruby.exe"
$abi       = &$ruby_exe -e "print RbConfig::CONFIG['ruby_version']"
$script:time_info = ''

$env:PATH = "$d_install/bin;$no_ruby_path"

if ($env:DESTDIR) { Remove-Item env:\DESTDIR }
if ($env:BUNDLER_VERSION) { Remove-Item env:\BUNDLER_VERSION }

#————————————————————————————————————————————————————————————————— start testing
# PATH is set in each test function

# assumes symlink folder exists, some tests may not be happy with a space in
# git's path
$env:GIT = "$d_repo/git/cmd/git.exe"

$m_start = Get-Date

EchoC $($dash * 92) yel
ruby -ropenssl -e "puts RUBY_DESCRIPTION, OpenSSL::OPENSSL_LIBRARY_VERSION"

EchoC "$dash_hdr Install `'tz`' gems" yel
gem install `"timezone:>=1.3.16`" `"tzinfo:>=2.0.4`" `"tzinfo-data:>=1.2022.1`" --no-document --conservative --norc --no-user-install

# CLI-Test
EchoC "$dash_hdr CLI Test" yel
echo "bundle version: $(bundle version)" ; $exit_code += [int](0 + $LastExitCode)
echo "gem  --version: $(gem --version)"  ; $exit_code += [int](0 + $LastExitCode)
echo "irb  --version: $(irb --version)"  ; $exit_code += [int](0 + $LastExitCode)
echo "racc --version: $(racc --version)" ; $exit_code += [int](0 + $LastExitCode)
echo "rake --version: $(rake --version)" ; $exit_code += [int](0 + $LastExitCode)
echo "rbs  --version: $(rbs --version)"  ; $exit_code += [int](0 + $LastExitCode)
echo "rdbg --version: $(rdbg --version)" ; $exit_code += [int](0 + $LastExitCode)
echo "rdoc --version: $(rdoc --version)" ; $exit_code += [int](0 + $LastExitCode)
if ($build_sys -ne 'mswin') {
  echo "ridk   version:"
  ridk version
}

echo ''
EchoC "$dash_hdr Run Tests" yel

BasicTest
sleep 2
BootStrapTest
sleep 2

if ($build_sys -ne 'mswin') {
  if (Test-Path -Path $d_install/lib/ruby/$abi/$rarch/readline.so -PathType Leaf ) {
    ren "$d_install/lib/ruby/$abi/$rarch/readline.so" "readline.so_"
  }
}

Test-All
sleep 5
Test-Reline
sleep 5
MSpec

if (Test-Path -Path $d_install/lib/ruby/$abi/$rarch/readline.so -PathType Leaf ) {
  ren "$d_install/lib/ruby/$abi/$rarch/readline.so" "readline.so_"
}

Finish
