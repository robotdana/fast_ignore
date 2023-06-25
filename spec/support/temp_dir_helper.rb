# frozen_string_literal: true

require 'pathname'
require 'tmpdir'

module TempDirHelper
  module WithinGitTempDir
    def git_add_files(*files)
      system('git', 'add', *files)
    end
  end

  module WithinTempDir
    def create_file(*lines, path:, git_add: false)
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

    def create_file_list(*filenames, git_add: false)
      filenames.each do |filename|
        create_file(path: filename, git_add: false)
      end
      git_add_files(*filenames) if git_add
    end

    def gitignore(*lines, path: '.gitignore')
      create_file(*lines, path: path)
    end
  end

  def within_temp_dir(git_init: false)
    dir = Pathname.new(Dir.mktmpdir)
    original_dir = Dir.pwd
    Dir.chdir(dir)

    extend WithinTempDir
    extend WithinGitTempDir if git_init
    yield
  ensure
    Dir.chdir(original_dir)
    dir&.rmtree
  end
end

RSpec.configure do |config|
  config.include TempDirHelper
end
