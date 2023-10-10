begin
  info = %x[git log -n1 --pretty=format:"%H%n%ct%n%s"].split "\n"
  time = Time.at(info[1].to_i).utc
  out = "\nRuby Commit\n#{info[0]}\n  #{time}\n  #{info[2]}\n"
  STDOUT.syswrite out
end
