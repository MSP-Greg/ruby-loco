# frozen_string_literal: true

failures = 0

puts "---------------------------------------------------------------------- Test Results"

logs = Dir.glob("#{ENV['R_NAME']}-*.log")

results_str = String.new

log = logs.grep(/test-all\.log\Z/)
# 16538 tests, 2190218 assertions, 1 failures, 0 errors, 234 skips
if log.length == 1
  s = File.binread(log[0])
  results = String.new(s[-256,256][/^\d{5,} tests[^\r\n]+/])
  failures += results[/assertions, (\d+) failures?/,1].to_i + results[/failures?, (\d+) errors?/,1].to_i
  
  # find last skipped
  if s.length > 2048
    skips_str = s[-2048,2048]
    skips_shown = ''
    skips_str.scan(/^ +(\d+)\) Skipped:/) { |m| skips_shown = m[0] }
    results << ", #{skips_shown} skips shown" unless skips_shown.empty?
  end

  results_str << "test-all   #{results}\n\n"
end

log = logs.grep(/test-spec\.log\Z/)
# 3551 files, 26041 examples, 203539 expectations, 0 failures, 0 errors, 0 tagged
if log.length == 1
  s = File.binread(log[0])
  results = s[-192,192][/^\d{4,} files, \d{4,} examples,[^\r\n]+/]
  failures += results[/expectations?, (\d+) failures?/,1].to_i + results[/failures?, (\d+) errors?/,1].to_i
  results_str << "test-spec  #{results}\n"
end

log = logs.grep(/test-mspec\.log\Z/)
# 3551 files, 26041 examples, 203539 expectations, 0 failures, 0 errors, 0 tagged
if log.length == 1
  s = File.binread(log[0])
  results = s[-192,192][/^\d{4,} files, \d{4,} examples,[^\r\n]+/]
  failures += results[/expectations, (\d+) failures?/,1].to_i + results[/failures?, (\d+) errors?/,1].to_i
  results_str << "mspec      #{results}\n\n"
end

log = logs.grep(/test-basic\.log\Z/)
# test succeeded
if log.length == 1
  s = File.binread(log[0])
  if /^test succeeded/ =~ s[-256,256]
  results_str << "test-basic test succeeded\n"
  else
    results_str << "test-basic test failed\n"
    failures += 1
  end
end

log = logs.grep(/btest\.log\Z/)
# PASS all 1194 tests
if log.length == 1
  s = File.binread(log[0])
  results = s[-256,256][/^PASS all \d+ tests/]
  if results
    results_str << "btest      #{results}\n"
  else
    results_str << "btest      FAILED\n"
    failures += 1
  end
end

results_str = "#{failures} Total Failures/Errors\n" \
              "#{RUBY_DESCRIPTION}\n" \
              "#{Time.now.getutc}\n\n" \
              "#{results_str}"

puts results_str

File.binwrite(File.join(__dir__, "#{ENV['R_NAME']}-TEST_RESULTS.log"), results_str)

puts "---------------------------------------------------------------------- Saving Artifacts"
fn_log = "zlogs_#{ENV['R_BRANCH']}_#{ENV['R_DATE']}_#{ENV['R_SVN']}.7z"

`attrib +r #{ENV['R_NAME']}-*.log`
`#{ENV['7zip']} a #{fn_log} .\\*.log`
puts "Saved #{fn_log}"

z_files = "#{ENV['PKG_RUBY']}\\* " \
          ".\\pkg\\#{ENV['R_NAME']}\\.BUILDINFO " \
          ".\\pkg\\#{ENV['R_NAME']}\\.PKGINFO " \
          ".\\av_install\\#{ENV['R_BRANCH']}_install.cmd " \
          ".\\av_install\\#{ENV['R_BRANCH']}_pkgs.cmd " \
          ".\\av_install\\#{ENV['R_BRANCH']}_msys2.cmd"

if failures == 0
  `#{ENV['7zip']} a ruby_%R_BRANCH%.7z     #{z_files}`
  puts "Saved ruby_#{ENV['R_BRANCH']}.7z\n"
else
  `#{ENV['7zip']} a ruby_%R_BRANCH%_bad.7z #{z_files}`
  puts "Saved ruby_#{ENV['R_BRANCH']}_bad.7z\n"
end

if ENV['AV_BUILD'] == "true"
  `appveyor PushArtifact #{fn_log} -DeploymentName \"Build and test logs\"`
  if failures == 0
    `appveyor PushArtifact ruby_#{ENV['R_BRANCH']}.7z -DeploymentName \"Ruby Trunk Build\"`
  else
    `appveyor PushArtifact ruby_#{ENV['R_BRANCH']}_bad.7z -DeploymentName \"Ruby Trunk Build (bad)\"`
  end
  `appveyor AddMessage -Message \"#{RUBY_DESCRIPTION}\" -Details \"#{results_str}\"`
end
exit failures
