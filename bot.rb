# frozen_string_literal: true

require 'open3'
require 'json'
require 'base64'
require 'securerandom'
require 'net/http'

require 'bundler/setup'

require 'json-schema'
require 'async'

config = JSON.parse(File.read(ARGV.first))

schema_path = File.expand_path("../config_schema.json", __FILE__)

JSON::Validator.validate!(schema_path, config)

bot_account = config['bot_account']
GROUP_IDS = config['signal_groups'].freeze
ENV['GOOGLE_AI_API_KEY'] = config['google_ai_api_key']

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

def group_detect(data)
  if group_info = data.dig("params", "envelope", "dataMessage", "groupInfo")
    group_id = group_info['groupId']

    if GROUP_IDS.include?(group_id)
      yield group_id
    else
      puts "GROUP ID DID NOT MATCH"
    end
  else
    puts "NOT POSTED TO ACCEPTABLE GROUP"
  end
end

ANALYZE_QUERY_TEMPLATE = config['analyze_query']

def analyze_message(text)
  uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=#{ENV['GOOGLE_AI_API_KEY']}")
  query = ANALYZE_QUERY_TEMPLATE % text
  query_data = JSON.generate(contents: [{role: :user, parts: [{text: query}]}])
  res = Net::HTTP.post(uri, query_data, {'content-type': 'application/json'})
  json_result = JSON.parse(res.body)
  json_result.dig('candidates', 0, 'content', 'parts', 0, 'text')
end

def process(line)
  puts line
  data = JSON.parse(line)

  message = data.dig("params", "envelope", "dataMessage", "message")

  case message
  when /^\/pic (.*)/
    group_detect(data) do |group_id|
      $signal_stdin.puts JSON.generate(jsonrpc: '2.0', id: SecureRandom.uuid, method: "sendTyping", params: {groupId: group_id})

      pic_stdout, pic_stderr, pic_status = Open3.capture3("python3", "source/generate_pic.py", $1)

      $signal_stdin.puts JSON.generate(jsonrpc: '2.0', id: SecureRandom.uuid, method: "sendTyping", params: {groupId: group_id, stop: true})

      if pic_status.success?
        base64 = Base64.strict_encode64 pic_stdout

        write_reply(data, groupId: group_id, attachments: ["data:image/png;base64,#{base64}"])
      else
        write_reply(data, groupId: group_id, message: "Could not generate picture\n#{pic_stderr}")
      end
    end
  when "/analyze"
    group_detect(data) do |group_id|
      quote_text = data.dig("params", "envelope", "dataMessage", "quote", "text")
      if quote_text
        write_reply(data, groupId: group_id, message: analyze_message(quote_text))
      end
    end
  when '/ping'
    group_detect(data) do |group_id|
      write_reply(data, groupId: group_id, message: 'pong')
    end
  end
end

stdout.each_line do |line|
  Async do
    process(line)
  end
end
