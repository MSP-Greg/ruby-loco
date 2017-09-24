=begin
ruby E:\GitHub\ruby-loco\time_log.rb
=end

logs = Dir.glob("#{ENV['R_NAME']}-#{ENV['R_VERS']}*.log")

t_ttl = 0
ary = []
logs.each { |fn|
  diff = File.mtime(fn) - File.birthtime(fn)
  bn = File.basename(fn).sub(/\.log\Z/, '')[/(test-[^-]+|[^-]+)\Z/,1]
  ary << [bn, diff]
  t_ttl += diff  
}
sort = ['prepare', 'build', 'package']
ary.sort_by! { |i| [sort.index(i[0]) || 3, i[0]] }
file_body = String.new("#{RUBY_DESCRIPTION}\n")
ary.each { |i|
  file_body << "#{Time.at(i[1]).strftime("%M:%S")} #{i[0]}\n"
}
file_body << "#{Time.at(t_ttl).strftime("%M:%S")} Total Time"
File.binwrite(File.join(__dir__, "#{ENV['R_NAME']}-TOTAL_TIME.log"), file_body)
puts file_body
