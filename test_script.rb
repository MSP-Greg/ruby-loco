# frozen_string_literal: true
# encoding: UTF-8

module TestScript

  @@stripe_len = 65
  @@puts_len   = 79
  @@failures   = 0
  
  def self.run
    logs = Dir.glob("#{ENV['R_NAME']}-*.log")

    warnings_str = +''
    warnings_str << log_warnings( logs.grep(/build\.log\Z/)   )

    results_str = +''
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

    puts "#{'—' * @@puts_len} Test Results"
    puts results_str
    File.binwrite(File.join(__dir__, "#{ENV['R_NAME']}-TEST_RESULTS.log"), results_str)
    zip_save
    if ENV['AV_BUILD'] == "true"
      `appveyor AddMessage -Message \"Summary - All Tests\" -Details \"#{results_str}\"`

      unless sum_test_all.empty?
        `appveyor AddMessage -Message \"Summary - test-all\" -Details \"#{sum_test_all}\"`
      end

      unless warnings_str.empty?
      `appveyor AddMessage -Message \"Build Warnings\" -Details \"#{warnings_str}\"`
      end
      push_artifacts
    else
      # Below is for local testing
      puts "\nappveyor AddMessage -Message \"Summary - All Tests\" -Details\n#{results_str}"

      unless sum_test_all.empty?
        puts "appveyor AddMessage -Message \"Summary - test-all\" -Details\n#{sum_test_all}"
      end
      unless warnings_str.empty?
        puts "appveyor AddMessage -Message \"Build Warnings\" -Details\n#{warnings_str}"
      end
    end

    exit @@failures
  end

  private

  def self.log_warnings(log)
    s = File.binread(log[0]).gsub(/\r/, '')
    str = +''
    s.scan(/^\.\.[^\n]+\n[^\n].+?:\d+:\d+: warning: .+?\^\n/m) { |w|
      str << "#{w}\n"
    }
    str
  end

  def self.log_test_all(log)
    # 16538 tests, 2190218 assertions, 1 failures, 0 errors, 234 skips
    if log.length == 1
      if (s = File.binread(log[0])).length >= 256
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
      ['', '']
    end
  end

  def self.log_spec(log)
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
      ''
    end
  end

  def self.log_mspec(log)
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
      ''
    end
  end

  def self.log_basic(log)
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
      ''
    end
  end

  def self.log_btest(log)
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
      ''
    end
  end

  def self.command_line
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

  def self.generate_test_all(s, results)
    s.gsub!("\r", '')
    str = +''

    # Find and log parallel failures ands errors
    str << faults_parallel(s, "Failure", "F")
    str << faults_parallel(s, "Error"  , "E")

    # Find and log final failures ands errors
    str << faults_final(s, "Failure")
    str << faults_final(s, "Error")
    unless str.empty?
      str = "#{RUBY_DESCRIPTION}\n#{results}\n\n#{str}" unless str.empty?
      File.binwrite(File.join(__dir__, "#{ENV['R_NAME']}-TEST_ALL_SUMMARY.log"), str)
    end
    str
  end

  def self.faults_parallel(log, type, abbrev)
    str = +''
    faults = []
    faults = log.scan(/^( *\d+ )([A-Z][^#\n]+#test_[^\n]+? = #{abbrev})/)
    unless  faults.empty?
      t1 = faults.length
      msg = t1 == 1 ? "#{type}" : "#{type}s"
      str << "#{'—' * @@stripe_len} Parallel Tests - #{t1} #{msg}\n\n"
      str << faults.sort_by { |f| f[1] }.map { |f| "#{f[0]}#{f[1]}" }.join("\n")
      str << "\n\n"
    end
    str
  end
  
  def self.faults_final(log, type)
    str = +''
    faults = []
    log.scan(/^ *\d+\) #{type}:\n([^\n]+?) \[([^\n]+?):(\d+)\]:\n(.+?)\n\n/m) { |test, file, line, msg|
      file.sub!(/[\S]+?\/test\//, '')
      faults << [test, file, line, msg]
    }
    unless faults.empty?
      hsh_faults = faults.group_by { |f| f[1] } # group by file
      ary_faults = hsh_faults.sort
      ary_faults.each { |file, faults| faults.sort_by! { |f| f[2] } }
      ary_faults.each { |file, faults|
        t1 = faults.length
        msg = t1 == 1 ? "1 #{type}" : "#{t1} #{type}s"
        str << "#{'—' * @@stripe_len} #{msg}\n#{' ' * (@@stripe_len + t1.to_s.length)}  #{file}\n\n"
        faults.each { |test, file, line, msg|
          str << "—————————————————————— Line: #{line.to_s.ljust(5)}  #{test}\n#{msg}\n\n"
        }
      }
    end
    str
  end
  
  def self.zip_save
    puts "#{'—' * @@puts_len} Saving Artifacts"
    fn_log = "zlogs_#{ENV['R_BRANCH']}_#{ENV['R_DATE']}_#{ENV['R_SVN']}.7z"

    `attrib +r #{ENV['R_NAME']}-*.log`
    `#{ENV['7zip']} a #{fn_log} .\\*.log`
    puts "Saved #{fn_log}"
    if ENV['AV_BUILD'] == "true"
      `appveyor PushArtifact #{fn_log} -DeploymentName \"Build and test logs\"`
    end
  end
  
  def self.push_artifacts
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
end

TestScript.run