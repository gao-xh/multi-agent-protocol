#!/usr/bin/env ruby
# Ask the installed Codex runtime to read this local plugin without installing it.
require 'json'
require 'open3'
require 'timeout'

plugin_root = File.expand_path('..', __dir__)
marketplace_path = File.join(plugin_root, '.agents/plugins/marketplace.json')

def receive_response(output, request_id)
  Timeout.timeout(30) do
    while (line = output.gets)
      event = JSON.parse(line)
      next unless event['id'] == request_id
      raise event['error'].inspect if event['error']
      return event.fetch('result')
    end
    raise 'Codex app-server closed before responding'
  end
end

Open3.popen3('codex', 'app-server', '--listen', 'stdio://') do |input, output, error, process|
  error_reader = Thread.new { error.read }
  begin
    input.puts JSON.generate(
      id: 1, method: 'initialize', params: {
        clientInfo: { name: 'map-plugin-check', version: '1' },
        capabilities: { experimentalApi: true }
      }
    )
    input.flush
    receive_response(output, 1)
    input.puts JSON.generate(method: 'initialized')
    input.puts JSON.generate(id: 2, method: 'plugin/read', params: {
                              marketplacePath: marketplace_path,
                              pluginName: 'multi-agent-protocol'
                            })
    input.flush
    plugin = receive_response(output, 2).fetch('plugin')
    names = plugin.fetch('skills').map { |skill| skill.fetch('name') }.sort
    expected = %w[map-coordinate map-lead map-liaison map-line map-relay map-release]
               .map { |name| "multi-agent-protocol:#{name}" }.sort
    raise "Unexpected skills: #{names.inspect}" unless names == expected
    events = plugin.fetch('hooks').map { |hook| hook.fetch('eventName') }
    raise "Missing native SessionStart hook: #{events.inspect}" unless events.include?('sessionStart')
    summary = plugin.fetch('summary')
    raise 'Unexpected marketplace' unless plugin.fetch('marketplaceName') == 'gao-xh-map-codex'
    raise 'Expected an uninstalled local plugin' if summary.fetch('installed')
    puts JSON.pretty_generate(
      name: summary.fetch('name'), version: summary['version'],
      marketplace: plugin.fetch('marketplaceName'), installed: summary.fetch('installed'),
      skills: names, hooks: events, note: 'Read only: no install or hook trust requested'
    )
  ensure
    input.close
    unless process.join(5)
      Process.kill('TERM', process.pid)
      process.join
    end
    error_reader.join
  end
end
