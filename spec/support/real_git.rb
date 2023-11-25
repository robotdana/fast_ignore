# frozen_string_literal: true

require 'tempfile'

class RealGit
  attr_reader :path

  def initialize(path = '.')
    @path = ::File.expand_path(path)
    FileUtils.mkpath(@path)
    git('init')
  end

  def git(*subcommand, chdir: @path, out: File::NULL, err: File::NULL, **options)
    system(
      'git',
      '-c', "core.hooksPath=''",
      '-c', "core.excludesFile=''",
      *subcommand,
      out: out,
      err: err,
      chdir: chdir,
      **options
    )
  end

  def add(*args)
    git('add', '.', *args)
  end

  def commit(*args)
    add
    git('commit', '-m', 'Commit', *args)
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
