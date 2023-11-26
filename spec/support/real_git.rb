# frozen_string_literal: true

require 'tempfile'

class RealGit
  attr_reader :path

  def initialize(path = '.', env)
    @path = ::File.expand_path(path)
    @env = env
    FileUtils.mkpath(@path)
    git('init')
    configure_excludesfile('')
  end

  def git(*subcommand, **options)
    system(
      @env.transform_keys(&:to_s),
      'git',
      '-c', "core.hooksPath=''",
      *subcommand,
      chdir: @path,
      out: File::NULL,
      err: File::NULL,
      **options
    )
  end

  def configure_excludesfile(path, **options)
    git('config', '--local', 'core.excludesfile', path, **options)
  end

  def add(*args)
    git('add', '.', *args)
  end

  def commit(*args)
    add
    git('commit', '-m', 'Commit', '--no-verify', *args)
  end

  def add_submodule(path)
    git('submodule', 'add', path)
    fetch_submodules
  end

  def fetch_submodules
    git('submodule', 'update', '--remote', '--merge', '--init', '--recursive')
  end

  def ls_files
    out = Tempfile.new('ls-fils-output')
    # unfortunately git likes to output path names with quotes and escaped backslashes.
    # we need the string without quotes and without escaped backslashes.
    git('ls-files', '--recurse-submodules', '-z', out: out)
    out.rewind
    out.read.split("\0")
      .map do |path|
        next path unless path[0] == '"' && path[-1] == '"'

        path[1..-2].gsub('\\\\', '\\')
      end
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
    RealGit.new(path, stubbed_env)
  end
end

RSpec.configure do |config|
  config.include RealGitHelper
end
