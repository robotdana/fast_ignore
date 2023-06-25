# frozen_string_literal: true

require 'pathname'
require 'tmpdir'

module TempDirHelper
  module WithinGitTempDir
    def git_add_files(*files)
      system('git', '-c', "core.excludesfile=''", 'add', *files)
    end

    def default_git_add
      true
    end
  end

  module WithinTempDir
    def default_git_add
      false
    end

    def create_file(*lines, path:, git_add: default_git_add)
      path = Pathname.pwd.join(path)
      path.parent.mkpath
      if lines.empty?
        path.write('')
      else
        path.write(lines.join("\n"))
      end
      git_add_files(path.to_s) if git_add
      path
    end

    def create_symlink(arg)
      link, target = arg.to_a.first

      link_path = Pathname.pwd.join(link)
      link_path.parent.mkpath

      FileUtils.ln_s(Pathname.pwd.join(target), link_path.to_s)
    end

    def create_file_list(*filenames, git_add: default_git_add)
      filenames.each do |filename|
        create_file(path: filename, git_add: false)
      end
      git_add_files(*filenames) if git_add
    end

    def gitignore(*lines, path: '.gitignore')
      create_file(*lines, path: path)
    end
  end

  def within_temp_dir(git_init: false) # rubocop:disable Metrics/MethodLength
    dir = Pathname.new(Dir.mktmpdir)
    original_dir = Dir.pwd
    Dir.chdir(dir)

    extend WithinTempDir
    if git_init
      `git init && git config user.email rspec@example.com && git config user.name "RSpec runner"`
      extend WithinGitTempDir
    end

    yield
  ensure
    Dir.chdir(original_dir)
    dir&.rmtree
  end
end

RSpec.configure do |config|
  config.include TempDirHelper
end
