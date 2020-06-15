# frozen_string_literal: true

module CopyBashScripts
  BIN_DIR = "#{RbConfig::TOPDIR}/bin"
  
  SRC_DIR = "#{Dir.pwd}/src/bin"

  class << self
  
    def run
      bins = Dir["#{SRC_DIR}/*"]

      bins.each do |fn|
        str = File.read(fn, mode: 'rb').sub(/\A#!\/usr\/bin\/env ruby/, '#! ruby')
        base = File.basename fn
        File.write "#{BIN_DIR}/#{base}", str, mode: 'wb'
      end

      # rake bash bin file
      fn = "#{BIN_DIR}/rake"
      str = File.read(fn, mode: 'rb').dup
      str.sub!(/.+?\n#!\/usr\/bin\/env ruby/m, "#! ruby")
      File.write fn, str, mode: 'wb'
    end
  end
end
CopyBashScripts.run
