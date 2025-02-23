# frozen_string_literal: true

require 'open3'
require 'json'
require 'base64'
require 'securerandom'

bot_account, *group_ids = ARGV

puts "Using #{bot_account} as bot account"

$signal_stdin, stdout, wait_thr = Open3.popen2("signal-cli -a #{bot_account} jsonRpc")

def write_reply(data, params)
  timestamp = data.dig("params", "envelope", "timestamp")
  message = data.dig("params", "envelope", "dataMessage", "message")
  author = data.dig("params", "envelope", "source")
  quote_params = {quoteTimestamp: timestamp, quoteMessage: message, quoteAuthor: author}
  reply_json = JSON.generate(jsonrpc: '2.0', id: SecureRandom.uuid, method: "send", params: quote_params.merge(params))
  puts reply_json
  $signal_stdin.puts reply_json
end

Signal.trap("TERM") {
  $signal_stdin.close
}

stdout.each_line do |line|
  puts line
  data = JSON.parse(line)

  message = data.dig("params", "envelope", "dataMessage", "message")

  case message
  when /^\/pic (.*)/
    if group_info = data.dig("params", "envelope", "dataMessage", "groupInfo")
      group_id = group_info['groupId']

      if group_ids.include?(group_id)
        $signal_stdin.puts JSON.generate(jsonrpc: '2.0', id: SecureRandom.uuid, method: "sendTyping", params: {groupId: group_id})

        pic_stdout, pic_stderr, pic_status = Open3.capture3("python3", "source/generate_pic.py", $1)

        $signal_stdin.puts JSON.generate(jsonrpc: '2.0', id: SecureRandom.uuid, method: "sendTyping", params: {groupId: group_id, stop: true})

        if pic_status.success?
          base64 = Base64.strict_encode64 pic_stdout

          write_reply(data, groupId: group_id, attachments: ["data:image/png;base64,#{base64}"])
        else
          write_reply(data, groupId: group_id, message: "Could not generate picture")
        end
      else
        puts "GROUP ID DID NOT MATCH"
      end
    else
      puts "NOT POSTED TO GROUP"
    end
  end
end
