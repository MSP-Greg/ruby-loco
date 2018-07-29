# frozen_string_literal: true
# encoding: UTF-8

module TestScript

  YELLOW = "\e[33m"
  RESET = "\e[0m"

  @@stripe_len = 65
  @@puts_len   = 79
  @@failures   = 0
  @@is_av      = ( ENV['AV_BUILD'] == 'true' )     # Appveyor build vs local
  
  class << self
  
  def run
    logs = Dir["#{ENV['R_NAME']}-[^0-9]*.log"]

    # build did not start
    t = logs.grep(/build\.log\Z/)
    return if t.empty?

    warnings_str = ''.dup
    warnings_str << log_warnings(t)

    # package did not start
    t = logs.grep(/package\.log\Z/)
    return if t.empty?

    results_str = ''.dup
    t1, sum_test_all = log_test_all( logs.grep(/test-all\.log\Z/)   )
    results_str << t1
    results_str << log_spec(     logs.grep(/test-spec\.log\Z/)  )
    results_str << log_mspec(    logs.grep(/test-mspec\.log\Z/) )
    results_str << log_basic(    logs.grep(/test-basic\.log\Z/) )
    results_str << log_btest(    logs.grep(/btest\.log\Z/)      )

    sp = ' ' * @@failures.to_s.length
    results_str = "#{@@failures} Total Failures/Errors                           " \
                  "Build No #{ENV['APPVEYOR_BUILD_NUMBER']}    Job Id #{ENV['APPVEYOR_JOB_ID']}\n" \
                  "#{sp} #{RUBY_DESCRIPTION}\n" \
                  "#{sp} #{Time.now.getutc}\n\n" \
                  "#{results_str}\n" \
                  "#{command_line()}\n"

    puts "#{YELLOW}#{'—' * @@puts_len} Test Results#{RESET}"
    puts results_str

    File.binwrite(File.join(__dir__, "#{ENV['R_NAME']}-Summary - Test Results.log"), results_str)

    unless sum_test_all.empty?
      puts "\n#{YELLOW}#{'—' * @@puts_len} Summary test-all#{RESET}"
      puts sum_test_all
      File.binwrite(File.join(__dir__, "#{ENV['R_NAME']}-Summary - test-all.log"), sum_test_all)
    end
    unless warnings_str.empty?
      File.binwrite(File.join(__dir__, "#{ENV['R_NAME']}-Summary - Build Warnings.log"), sum_test_all)
    end

    zip_save
  
    if @@is_av
      `appveyor AddMessage -Message \"Summary - All Tests\" -Details \"#{results_str}\"`

      unless sum_test_all.empty?
        `appveyor AddMessage -Message \"Summary - test-all\" -Details \"#{sum_test_all}\"`
      end

      unless warnings_str.empty?
      `appveyor AddMessage -Message \"Build Warnings\" -Details \"#{warnings_str}\"`
      end
    end

    exit @@failures
  end

  private

  def log_warnings(log)
    str = +''
    if !log.empty? && (s = File.binread(log[0]))
      s.gsub!(/\r/, '')
      s.scan(/^\.\.[^\n]+\n[^\n].+?:\d+:\d+: warning: .+?\^\n/m) { |w|
        str << "#{w}\n"
      }
    end
    str
  end

  def log_test_all(log)
    # 16538 tests, 2190218 assertions, 1 failures, 0 errors, 234 skips
    if log.length == 1
      if (s = File.binread(log[0]).gsub("\r", '')).length >= 256
        temp = s[-256,256][/^\d{5,} tests[^\r\n]+/]
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
    else
      @@failures += 1
      ["test-all   log not found\n\n", '']
    end
  end

  def log_spec(log)
    # 3551 files, 26041 examples, 203539 expectations, 0 failures, 0 errors, 0 tagged
    if log.length == 1
      if (s = File.binread(log[0])).length >= 144
        results = s[-144,144][/^\d{4,} files, \d{4,} examples,[^\r\n]+/]
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
    else
      @@failures += 1
      "test-spec  log not found\n"
    end
  end

  def log_mspec(log)
    # 3551 files, 26041 examples, 203539 expectations, 0 failures, 0 errors, 0 tagged
    if log.length == 1
      if (s = File.binread(log[0])).length >= 144
        results = s[-144,144][/^\d{4,} files, \d{4,} examples,[^\r\n]+/]
        if results
          @@failures += results[/expectations, (\d+) failures?/,1].to_i
          # results[/failures?, (\d+) errors?/,1].to_i
          "mspec      #{results}\n\n"
        else
          @@failures += 1
          "mspec      Crashed? see log\n\n"
        end
      else
        @@failures += 1
        "mspec      UNKNOWN see log\n\n"
      end
    else
      @@failures += 1
      "mspec      log not found\n\n"
    end
  end

  def log_basic(log)
    # test succeeded
    if log.length == 1
      if (s = File.binread(log[0])).length >= 192
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
    else
      @@failures += 1
      "test-basic log not found\n"
    end
  end

  def log_btest(log)
    # PASS all 1194 tests
    if log.length == 1
      if (s = File.binread(log[0])).length >= 192
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
    else
      @@failures += 1
      "btest      log not found\n"
    end
  end

  def command_line
    begin
      bundle_v = "bundle version  #{`bundle version`}"
    rescue
      bundle_v = "bundle version  NOT FOUND!"
      @@failures += 1
    end

    begin
      rake_v   = "rake -V         #{`rake -V`}"
    rescue
      rake_v   = "rake -V         NOT FOUND!"
      @@failures += 1
    end
    bundle_v + rake_v
  end

  def generate_test_all(s, results)
    str = +''

    # Find and log parallel failures ands errors
    str << errors_faults_parallel(s, 'Failure', 'F')
    str << errors_faults_parallel(s, 'Error'  , 'E')

    # Find and log final failures ands errors
    str << faults_final(s)
    str << errors_final(s)
    str.empty? ? str : "#{RUBY_DESCRIPTION}\n#{results}\n\n#{str}"
  end

  def errors_faults_parallel(log, type, abbrev)
    str = +''
    faults = []
    faults = log.scan(/^( *\d+ )([A-Z][^#\n]+#test_[^\n]+? = #{abbrev})/)
    unless  faults.empty?
      t1 = faults.length
      msg = t1 == 1 ? "#{type}" : "#{type}s"
      str << "#{YELLOW}#{'—' * @@stripe_len} Parallel Tests - #{t1} #{msg}#{RESET}\n\n"
      str << faults.sort_by { |f| f[1] }.map { |f| "#{f[0]}#{f[1]}" }.join("\n")
      str << "\n\n"
    end
    str
  end

  def errors_final(log)
    str = ''.dup
    errors = []
    log.scan(/^ *\d+\) Error:\n([^\n:]+):\n(.+?)\n([^\n]+?):(\d+):/m) { |test, msg, file, line|
      file.sub!(/[\S]+?\/test\//, '')
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
        wid = @@stripe_len + t1.to_s.length
        str << "#{YELLOW}#{'—' * @@stripe_len} #{msg}#{RESET}\n#{' ' * wid}  #{file}\n\n"
        errors.each { |test, file, line, msg|
          str << "#{test.ljust wid+1} Line: #{line.to_s.ljust(5)}\n#{msg}\n\n"
        }
      }
    end
    str
  end
  
  def faults_final(log)
    str = +''
    faults = []
    log.scan(/^ *\d+\) Failure:\n([^\n]+?) \[([^\n]+?):(\d+)\]:\n(.+?)\n\n/m) { |test, file, line, msg|
      file.sub!(/[\S]+?\/test\//, '')
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
        wid = @@stripe_len + t1.to_s.length
        str << "#{YELLOW}#{'—' * @@stripe_len} #{msg}#{RESET}\n#{' ' * wid}  #{file}\n\n"
        faults.each { |test, file, line, msg|
          str << "#{test.ljust wid+1} Line: #{line.to_s.ljust(5)}\n#{msg}\n\n"
        }
      }
    end
    str
  end
  
  def zip_save
    puts "#{YELLOW}#{'—' * @@puts_len} Saving Artifacts#{RESET}"
    
    push_artifacts if @@is_av
    
    fn_log = "zlogs_#{ENV['R_BRANCH']}_#{ENV['R_DATE']}_#{ENV['R_SVN']}.7z"

    `attrib +r #{ENV['R_NAME']}-*.log`
    `#{ENV['7zip']} a #{fn_log} .\\*.log`
    puts "Saved #{fn_log}"
    puts
    if @@is_av
      `appveyor PushArtifact #{fn_log} -DeploymentName \"Build and test logs\"`
    end
  end
  
  def push_artifacts
    z_files = "#{ENV['PKG_RUBY']}\\* " \
              ".\\pkg\\#{ENV['R_NAME']}\\.BUILDINFO " \
              ".\\pkg\\#{ENV['R_NAME']}\\.PKGINFO " \
              ".\\av_install\\#{ENV['R_BRANCH']}_install.cmd " \
              ".\\av_install\\#{ENV['R_BRANCH']}_pkgs.cmd " \
              ".\\av_install\\#{ENV['R_BRANCH']}_msys2.cmd"

    if @@failures == 0
      `#{ENV['7zip']} a ruby_%R_BRANCH%.7z     #{z_files}`
      puts "Saved ruby_#{ENV['R_BRANCH']}.7z\n"
      `appveyor PushArtifact ruby_#{ENV['R_BRANCH']}.7z -DeploymentName \"Ruby Trunk Build\"`
    else
      `#{ENV['7zip']} a ruby_%R_BRANCH%_bad.7z #{z_files}`
      puts "Saved ruby_#{ENV['R_BRANCH']}_bad.7z\n"
      `appveyor PushArtifact ruby_#{ENV['R_BRANCH']}_bad.7z -DeploymentName \"Ruby Trunk Build (bad)\"`
    end
  end
  
  end #  class << self
end

TestScript.run