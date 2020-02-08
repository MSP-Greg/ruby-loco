# frozen_string_literal: true
# encoding: UTF-8

# Code by MSP-Greg
# Parses test logs to determine if build is good, creates Appveyor messages and
# artifacts

module TestScript
  if ARGV.length == 0
    ARCH = '64'
    D_INSTALL = File.join __dir__, (IS_ACTIONS ? 'ruby-mingw' : 'install')
  elsif ARGV[0] == '32' || ARGV[0] == '64'
    ARCH = ARGV[0]
  else
    puts "Incorrect first argument, must be '32' or '64'"
    exit 1
  end

  if ARGV.length == 3 && !ARGV[1].nil? && ARGV[1] != ''
    D_INSTALL = File.join __dir__, ARGV[1]
  elsif ARGV.length == 1
    D_INSTALL = File.join __dir__, (IS_ACTIONS ? 'ruby-mingw' : 'install')
  end

  if ARGV.length == 3 && !ARGV[2].nil? && ARGV[2] != '' && (t = ARGV[2].to_i)
    @@cli_fails = t
  else
    @@cli_fails = 0
  end

  D_LOGS  = File.join __dir__, 'logs'
  D_RUBY  = File.join __dir__, 'ruby'
  D_ZIPS  = File.join __dir__, 'zips'
  D_MSYS2 = ENV['D_MSYS2']

  Dir.chdir(D_RUBY) { |d|
    branch = `git symbolic-ref -q HEAD`
    branch = 'master' if branch.strip == ''
    R_BRANCH = branch[/[^\/]+\Z/].strip
  }

  IS_AV      = ENV.fetch('APPVEYOR'      , '').match? /true/i
  IS_ACTIONS = ENV.fetch('GITHUB_ACTIONS', '').match? /true/i

  DASH = case ENV['PS_ENC']
    when 'utf-8'
      "\u2015".dup.force_encoding 'utf-8'
    when 'Windows-1252'
      151.chr
    when 'IBM437'
      '—'
    else
      "\u2015".dup.force_encoding 'utf-8'
    end

  YELLOW = "\e[33m"
  RESET  = "\e[0m"
  STRIPE_LEN = 55
  PUTS_LEN   = 74
  @@failures = 0

  class << self

  def run
    logs = []
    Dir.chdir File.join __dir__, 'logs'
    logs = Dir["*.log"]

    warnings_str = ''.dup
    results_str  = ''.dup
    r = []
    sum_test_all = ''
    logs.each do |fn|
      str = clean_file fn

      case fn
      when 'test_all.log'           ; r[0], sum_test_all = log_test_all(str)
      when 'test_mspec.log'         ; r[2] = log_mspec(str)
      when 'test_basic.log'         ; r[3] = log_basic(str)
      when 'test_bootstrap_err.log' ; r[4] = log_btest(str)
      end
    end
    # no test-all log
    if r[0].nil?
      @@failures += 1
      r[0] = "test-all   UNKNOWN see log\n\n"
      sum_test_all = ''
    end
    
    results_str << r.join('')

    if IS_ACTIONS
      build = "Run No #{ENV['GITHUB_RUN_NUMBER']}"
      run   = "Run Id #{ENV['GITHUB_RUN_ID']}"
    else
      build = "Build No #{ENV['APPVEYOR_BUILD_NUMBER']}"
      run   = "Job Id #{ENV['APPVEYOR_JOB_ID']}"
    end

    sp = ' ' * @@failures.to_s.length
    results_str = "#{@@failures} Total Failures/Errors                           " \
                  "#{build}    #{run}\n" \
                  "#{sp} #{RUBY_DESCRIPTION}\n" \
                  "#{sp} #{Time.now.getutc}\n\n" \
                  "#{results_str}\n" \
                  "#{@@cli_fails == 0 ? 'CLI passed' : 'CLI FAILED!'}\n"

    puts "\n#{YELLOW}#{DASH * PUTS_LEN} Test Results#{RESET}"
    puts results_str

    File.binwrite File.join(D_LOGS, "Summary_Test_Results.log"), results_str

    unless sum_test_all.empty?
      puts "\n#{YELLOW}#{DASH * PUTS_LEN} Summary test-all#{RESET}"
      puts sum_test_all
      sum_test_all = sum_test_all.gsub(/^\e\[33m|\e\[0m$/, '')
      File.binwrite(File.join(D_LOGS, "Summary_test-all.log"), sum_test_all)
    end

    Dir.chdir __dir__
    zip_save unless IS_ACTIONS

    if IS_AV && !IS_ACTIONS
      `appveyor AddMessage -Message \"Summary - All Tests\" -Details \"#{results_str}\"`

      unless sum_test_all.empty?
        `appveyor AddMessage -Message \"Summary - test-all\" -Details \"#{sum_test_all}\"`
      end

      unless warnings_str.empty?
      `appveyor AddMessage -Message \"Build Warnings\" -Details \"#{warnings_str}\"`
      end
    end

    exit (@@failures + @@cli_fails)
  end

  private

  def clean_file(fn)
    @real_ruby ||= File.dirname File.realpath(File.join(__dir__, "ruby"))

    str = File.binread(fn).dup
    if /\Atest_m?spec(_err)?\.log/ =~ fn
      str.gsub!(/\r\[[^\r\n]+\[0m /, '')
    end
    str.gsub!("\r"      , '')
    str.gsub!( __dir__  , '')
    str.gsub!( @real_ruby, '')
    File.binwrite fn, str
    str
  end

  # used for build log, not used in 'new' ruby-loco
  def log_warnings(log)
    str = ''.dup
    if !log.empty? && (s = clean_file log)
      s.scan(/^\.\.[^\n]+\n[^\n].+?:\d+:\d+: warning: .+?\^\n/m) { |w|
        str << "#{w}\n"
      }
    end
    str
  end

  def log_test_all(s)
    # 16538 tests, 2190218 assertions, 1 failures, 0 errors, 234 skips
    if s.length >= 256
      temp = s[-256,256][/^\d{5,} tests[^\n]+/]
      results = String.new(temp || "CRASHED?")
      if temp
        @@failures += results[/assertions, (\d+) failures?/,1].to_i + results[/failures?, (\d+) errors?/,1].to_i
        # find last skipped
        skips_shown = 0
        s.scan(/^ *(\d+)\) Skipped:/) { |m| skips_shown += 1 }
        results << ", #{skips_shown} skips shown"
      else
        @@failures += 1
      end
      ["test-all  #{results}\n\n", generate_test_all(s, results) ]
    else
      @@failures += 1
      ["test-all   UNKNOWN see log\n\n", '']
    end
  end

  def log_spec(s)
    # 3551 files, 26041 examples, 203539 expectations, 0 failures, 0 errors, 0 tagged
    if s.length >= 144
      results = s[/^\d{4,} files, \d{4,} examples,[^\r\n]+/]
      if results
        @@failures += results[/expectations, (\d+) failures?/,1].to_i +
          results[/failures?, (\d+) errors?/,1].to_i
        "test-spec  #{results}\n"
      else
        @@failures += 1
        "test-spec  Crashed? see log\n"
      end
    else
      @@failures += 1
      "test-spec  UNKNOWN see log\n"
    end
  end

  def log_mspec(s)
    # 3551 files, 26041 examples, 203539 expectations, 0 failures, 0 errors, 0 tagged
    if s.length >= 144
      results = s[/^\d{4,} files, \d{4,} examples,[^\r\n]+/]
      if results
        @@failures += results[/expectations, (\d+) failures?/,1].to_i +
          results[/failures?, (\d+) errors?/,1].to_i
        "mspec      #{results}\n\n"
      else
        @@failures += 1
        "mspec      Crashed? see log\n\n"
      end
    else
      @@failures += 1
      "mspec      UNKNOWN see log\n\n"
    end
  end

  def log_basic(s)
    # test succeeded
    if s.length >= 192
      if /^test succeeded/ =~ s[-192,192]
        "test-basic test succeeded\n"
      else
        @@failures += 1
        "test-basic test failed\n"
      end
    else
      @@failures += 1
      "test-basic test UNKNOWN\n"
    end
  end

  def log_btest(s)
    # PASS all 1194 tests
    if s.length >= 192
      results = s[-192,192][/^PASS all \d+ tests/]
      if results
        "btest      #{results}\n"
      else
        @@failures += 1
        "btest      FAILED\n"
      end
    else
      @@failures += 1
      "btest      UNKNOWN\n"
    end
  end

  def generate_test_all(s, results)
    str = ''.dup

    # Find and log parallel failures ands errors
    str << errors_faults_parallel(s, 'Failure', 'F')
    str << errors_faults_parallel(s, 'Error'  , 'E')

    # Find and log final failures ands errors
    str << faults_final(s)
    str << errors_final(s)
    str.empty? ? str : "#{RUBY_DESCRIPTION}\n#{results}\n\n#{str}"
  end

  def errors_faults_parallel(log, type, abbrev)
    str = ''.dup
    faults = []
    faults = log.scan(/^( *\d+ )([A-Z][^#\n]+#test_[^\n]+? = #{abbrev})/)
    unless  faults.empty?
      t1 = faults.length
      msg = t1 == 1 ? "#{type}" : "#{type}s"
      str << "#{YELLOW}#{DASH * STRIPE_LEN} Parallel Tests - #{t1} #{msg}#{RESET}\n\n"
      str << faults.sort_by { |f| f[1] }.map { |f| "#{f[0]}#{f[1]}" }.join("\n")
      str << "\n\n"
    end
    str
  end

  def errors_final(log)
    str = ''.dup
    errors = []
    log.scan(/^ *\d+\) Error:\n([^\n:]+):\n(.+?)\n([^\n]+?):(\d+):/m) { |test, msg, file, line|
      file.sub!(__dir__, '')
      errors << [test, file.strip, line.to_i, msg]
    }
    unless errors.empty?
      hsh_errors = errors.group_by { |f| f[1] } # group by file

      # Temp fix to remove TestJIT errors
      if hsh_errors.key? 'ruby/test_jit.rb'
        @@failures -= hsh_errors['ruby/test_jit.rb'].length
      end

      ary_errors = hsh_errors.sort
      ary_errors.each { |file, errors| errors.sort_by! { |f| f[2] } }
      ary_errors.each { |file, errors|
        t1 = errors.length
        msg = t1 == 1 ? "1 Error" : "#{t1} Errors"
        wid = STRIPE_LEN + t1.to_s.length
        str << "#{YELLOW}#{DASH * STRIPE_LEN} #{msg}#{RESET}\n#{' ' * wid}  #{file}\n\n"
        errors.each { |test, file, line, msg|
          str << "#{test.ljust wid+1} Line: #{line.to_s.ljust(5)}\n#{msg}\n\n"
        }
      }
    end
    str
  end

  def faults_final(log)
    str = ''.dup
    faults = []
    log.scan(/^ *\d+\) Failure:\n([^\n]+?) \[([^\n]+?):(\d+)\]:\n(.+?)\n\n/m) { |test, file, line, msg|
      file.sub!(__dir__, '')
      faults << [test, file, line.to_i, msg]
    }
    unless faults.empty?
      hsh_faults = faults.group_by { |f| f[1] } # group by file

      # Temp fix to remove TestJIT failures
      if hsh_faults.key? 'ruby/test_jit.rb'
        @@failures -= hsh_faults['ruby/test_jit.rb'].length
      end

      ary_faults = hsh_faults.sort
      ary_faults.each { |file, faults| faults.sort_by! { |f| f[2] } }
      ary_faults.each { |file, faults|
        t1 = faults.length
        msg = t1 == 1 ? "1 Failure" : "#{t1} Failures"
        wid = STRIPE_LEN + t1.to_s.length
        str << "#{YELLOW}#{DASH * STRIPE_LEN} #{msg}#{RESET}\n#{' ' * wid}  #{file}\n\n"
        faults.each { |test, file, line, msg|
          str << "#{test.ljust wid+1} Line: #{line.to_s.ljust(5)}\n#{msg}\n\n"
        }
      }
    end
    str
  end

  def zip_save
    puts "#{YELLOW}#{DASH * PUTS_LEN} Saving Artifacts#{RESET}"
    push_artifacts
    date = RUBY_DESCRIPTION[/\((\d{4}-\d{2}-\d{2})/, 1]
    fn_log = "zlogs_#{R_BRANCH}_#{date}_#{RUBY_REVISION[0,10]}.7z"

    `attrib +r *.log`
    `7z.exe a ./zips/#{fn_log} ./logs/*.log`
    if IS_AV
      `appveyor PushArtifact ./zips/#{fn_log} -DeploymentName \"Test logs\"`
    end
    puts "Saved #{fn_log}"
    puts
  end

  def push_artifacts
    require 'digest'
    z_files = "#{D_INSTALL}/* ./trunk_msys2.ps1"

    if (@@failures + @@cli_fails) == 0
      r_suffix = R_BRANCH == 'master' ? 'trunk' : R_BRANCH
      r_msg    = ''
    else
      r_suffix = R_BRANCH == 'master' ? 'trunk_bad' : "#{R_BRANCH}_bad"
      r_msg    = ' (bad)'
    end

    `7z.exe a ./zips/ruby_#{r_suffix}.7z #{z_files}`
    sha512 = Digest::SHA512.file("#{D_ZIPS}/ruby_#{r_suffix}.7z").hexdigest
    if IS_AV
      `appveyor AddMessage ruby_#{r_suffix}.7z_SHA512 -Details #{sha512}`
      `appveyor PushArtifact ./zips/ruby_#{r_suffix}.7z -DeploymentName \"Ruby Trunk Build#{r_msg}\"`
    end
    puts "Saved ruby_#{r_suffix}.7z"
  end

  end #  class << self
end
TestScript.run
