#!/usr/bin/env ruby
# Integration tests use only local bare remotes and disposable files.
require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'yaml'

class CodexPluginTest < Minitest::Test
  PLUGIN_ROOT = File.expand_path('..', __dir__)

  def setup
    @test_root = Dir.mktmpdir('map-codex-plugin-')
    @project = File.join(@test_root, 'project with spaces')
    @env = {
      'GIT_AUTHOR_NAME' => 'Test',
      'GIT_AUTHOR_EMAIL' => 'test@example.invalid',
      'GIT_COMMITTER_NAME' => 'Test',
      'GIT_COMMITTER_EMAIL' => 'test@example.invalid',
      'GIT_CONFIG_GLOBAL' => File::NULL,
      'GIT_CONFIG_NOSYSTEM' => '1',
      'MAP_UPDATE_CHECK' => '0',
      'MAP_FETCH_SECONDS' => '1',
      'MAP_REMOTE' => 'origin',
      'MAP_BRANCH' => 'coordination',
      'MAP_LINE' => nil,
      'TMPDIR' => @test_root
    }
    FileUtils.mkdir_p(@project)
    run_command('git', 'init', '--quiet', '--bare', '--initial-branch=main',
                File.join(@test_root, 'remote.git'))
    run_command('git', 'init', '--quiet', '--initial-branch=main', @project)
    run_command('git', 'remote', 'add', 'origin', File.join(@test_root, 'remote.git'))
    File.write(File.join(@project, 'README.md'), "# Codex plugin test\n")
    run_command('git', 'add', 'README.md')
    run_command('git', 'commit', '--quiet', '-m', 'test: initialize fixture')
    run_command('git', 'push', '--quiet', 'origin', 'main')
  end

  def teardown
    FileUtils.remove_entry(@test_root) if @test_root && File.directory?(@test_root)
  end

  def capture(*arguments, directory: @project, env: {}, input: '')
    Open3.capture3(@env.merge(env), *arguments, chdir: directory, stdin_data: input)
  end

  def run_command(*arguments, **options)
    output, error, status = capture(*arguments, **options)
    assert status.success?, "#{arguments.inspect}: #{error}\n#{output}"
    output
  end

  def bridge(*arguments, **options)
    run_command('sh', File.join(PLUGIN_ROOT, 'codex/map.sh'), *arguments, **options)
  end

  def hook(**options)
    output = run_command('sh', File.join(PLUGIN_ROOT, 'codex/session-start.sh'), **options)
    output.empty? ? nil : JSON.parse(output).fetch('hookSpecificOutput')
  end

  def seed_inbox(line = 'codex-test')
    bridge('init-coordination')
    bridge('set-line', line)
    message_file = File.join(@test_root, 'message with spaces.md')
    File.write(message_file, "type: heads-up\nfrom: setup\nto: #{line}\n\n- Change: synthetic inbox test\n")
    bridge('send', message_file).strip
  end

  def test_native_entry_points_and_skill_frontmatter
    manifest = JSON.parse(File.read(File.join(PLUGIN_ROOT, '.codex-plugin/plugin.json'), encoding: 'UTF-8'))
    marketplace = JSON.parse(File.read(File.join(PLUGIN_ROOT, '.agents/plugins/marketplace.json'), encoding: 'UTF-8'))
    assert_equal 'multi-agent-protocol', marketplace.fetch('plugins').first.fetch('name')
    assert_equal './', marketplace.fetch('plugins').first.fetch('source').fetch('path')
    assert_equal 'AVAILABLE', marketplace.fetch('plugins').first.fetch('policy').fetch('installation')
    assert_equal JSON.parse(File.read(File.join(PLUGIN_ROOT, '.claude-plugin/plugin.json'), encoding: 'UTF-8')).fetch('version'),
                 manifest.fetch('version')
    skill_files = Dir.glob(File.join(PLUGIN_ROOT, manifest.fetch('skills'), '*/SKILL.md'))
    assert_equal 6, skill_files.length
    skill_files.each do |skill_file|
      text = File.read(skill_file, encoding: 'UTF-8')
      frontmatter = YAML.safe_load(text.match(/\A---\n(.*?)\n---/m)[1])
      assert_equal File.basename(File.dirname(skill_file)), frontmatter.fetch('name')
      assert_kind_of String, frontmatter.fetch('description')
      refute_match(/CLAUDE_PLUGIN_ROOT|\$ARGUMENTS|allowed-tools:/, text)
      text.scan(/\]\(([^)]+\.md)\)/).flatten.each do |reference|
        assert File.file?(File.expand_path(reference, File.dirname(skill_file))), reference
      end
    end
    hook_config = JSON.parse(File.read(File.join(PLUGIN_ROOT, manifest.fetch('hooks')), encoding: 'UTF-8'))
    handler = hook_config.fetch('hooks').fetch('SessionStart').first.fetch('hooks').first
    assert_operator handler.fetch('timeout'), :<=, 15
  end

  def test_unknown_operation_cannot_inject_a_shell_command
    output, error, status = capture('sh', File.join(PLUGIN_ROOT, 'codex/map.sh'),
                                    'inbox; touch injected')
    assert_equal 2, status.exitstatus
    assert_empty output
    assert_match 'unknown operation', error
    refute File.exist?(File.join(@project, 'injected'))
  end

  def test_empty_inbox_exit_status_is_preserved
    bridge('init-coordination')
    output, _error, status = capture('sh', File.join(PLUGIN_ROOT, 'codex/map.sh'),
                                     'inbox', 'codex-test')
    assert_equal 1, status.exitstatus
    assert_empty output
  end

  def test_unassigned_and_non_repository_hooks_are_silent
    assert_nil hook
    assert_nil hook(directory: @test_root, env: { 'MAP_LINE' => 'codex-test' })
    assert_nil hook(env: { 'MAP_LINE' => 'invalid line' })
  end

  def test_hook_reports_the_actual_inbox_without_marking_it_read
    message = seed_inbox
    context = hook
    assert_equal 'SessionStart', context.fetch('hookEventName')
    assert_includes context.fetch('additionalContext'), 'line "codex-test"'
    assert_includes context.fetch('additionalContext'), message
    assert_includes bridge('inbox', 'codex-test'), message
    refute File.exist?(File.join(@project, '.git/map-watch-codex-test.lock'))
    assert_equal '', run_command('git', 'status', '--porcelain')
  end

  def test_hook_can_use_the_cached_inbox_when_the_remote_disappears
    message = seed_inbox
    run_command('git', 'remote', 'set-url', 'origin', File.join(@test_root, 'missing.git'))
    context = hook
    assert_includes context.fetch('additionalContext'), message
  end

  def test_worktrees_use_distinct_line_bindings
    seed_inbox('first-line')
    worktree = File.join(@test_root, 'second worktree')
    run_command('git', 'worktree', 'add', '--quiet', '--detach', worktree, 'HEAD')
    bridge('set-line', 'second-line', directory: worktree)
    assert_includes hook.fetch('additionalContext'), 'line "first-line"'
    assert_includes hook(directory: worktree).fetch('additionalContext'), 'line "second-line"'
  end

  def test_hook_command_works_from_an_installed_path_with_spaces
    seed_inbox
    installed_root = File.join(@test_root, 'plugin cache with spaces')
    FileUtils.mkdir_p(installed_root)
    %w[codex scripts].each { |folder| FileUtils.cp_r(File.join(PLUGIN_ROOT, folder), installed_root) }
    config = JSON.parse(File.read(File.join(installed_root, 'codex/hooks.json'), encoding: 'UTF-8'))
    command = config.fetch('hooks').fetch('SessionStart').first.fetch('hooks').first.fetch('command')
    output = run_command('sh', '-c', command, env: { 'PLUGIN_ROOT' => installed_root })
    assert_includes JSON.parse(output).fetch('hookSpecificOutput').fetch('additionalContext'),
                    'line "codex-test"'
  end
end
