require 'open3'
require 'json'

stdin, stdout, wait_thr = Open3.popen2('signal-cli jsonRpc')

stdout.each_line do |line|
  data = JSON.parse(line)
  p data
end
