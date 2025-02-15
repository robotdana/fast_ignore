# frozen_string_literal: true

require 'open3'
require 'tempfile'
require 'shellwords'

class RealGit
  attr_reader :path
  attr_accessor :excludesfile

  def initialize(path = '.', env) # rubocop:disable Style/OptionalArguments
    @path = ::File.expand_path(path)
    @env = env
    FileUtils.mkpath(@path)
    git('init')
  end

  def execute(*subcommand, **options)
    puts "> #{Shellwords.join([*@env.map { |k, v| "#{k}=#{v}" }, *subcommand])}" if ENV['TRACE']
    status = system(
      @env.transform_keys(&:to_s),
      *subcommand,
      chdir: @path,
      out: ENV['TRACE'] ? $stdout : File::NULL,
      err: ENV['TRACE'] ? $stderr : File::NULL,
      **options
    )
    raise unless status
  end

  def git(*subcommand, **options)
    execute(
      'git',
      '-c', 'init.defaultbranch=main',
      '-c', 'core.hookspath=""',
      '-c', 'user.email=git@example.com',
      '-c', 'user.name=User Name',
      *subcommand,
      **options
    )
  end

  def add(*args, **options)
    git('add', '.', *args, **options)
    submodule('foreach', '--recursive', Shellwords.join(['git', 'add', '.', *args]), **options)
    git('status') if ENV['TRACE']
  end

  def commit(*args, **options)
    add(**options)
    git('commit', '-m', 'Commit', '--no-verify', *args, **options)
  end

  def submodule(*args, **options)
    git('-c', 'protocol.file.allow=always', 'submodule', *args, **options)
  end

  def add_submodule(*args, **options)
    submodule('add', *args, **options)
    fetch_submodules(**options)
  end

  def fetch_submodules(**options)
    submodule('update', '--remote', '--merge', '--init', '--recursive', **options)
  end

  def ls_files
    out = Tempfile.new('ls-files-output')
    # unfortunately git likes to output path names with quotes and escaped backslashes.
    # we need the string without quotes and without escaped backslashes.
    git('ls-files', '--recurse-submodules', '-z', out: out)
    out.rewind
    files = out.read.split("\0")
      .map do |path|
        next path unless path[0] == '"' && path[-1] == '"'

        path[1..-2].gsub('\\\\', '\\')
      end
    puts files.join("\n") if ENV['TRACE']
    files
  ensure
    out.close
    out.unlink
  end

  def to_a
    add('-N')
    ls_files
  end
end

module RealGitHelper
  def real_git(path = '.')
    RealGit.new(path, { GIT_CONFIG_GLOBAL: File.join(__dir__, 'git_config') }.merge(stubbed_env))
  end
end

RSpec.configure do |config|
  config.include RealGitHelper
end
