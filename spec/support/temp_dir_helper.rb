# frozen_string_literal: true

require 'pathname'
require 'tmpdir'

module TempDirHelper
  module WithinTempDir
    def create_file(*lines, path:)
      path = Pathname.pwd.join(path)
      path.parent.mkpath
      if lines.empty?
        path.write('')
      else
        path.write(lines.join("\n"))
      end
      path
    end

    def create_symlink(arg)
      link, target = arg.to_a.first

      link_path = Pathname.pwd.join(link)
      link_path.parent.mkpath

      FileUtils.ln_s(Pathname.pwd.join(target), link_path.to_s)
    end

    def create_file_list(*filenames)
      filenames.each do |filename|
        create_file(path: filename)
      end
    end

    def gitignore(*lines, path: '.gitignore')
      create_file(*lines, path: path)
    end
  end

  def within_temp_dir
    dir = Pathname.new(Dir.mktmpdir)
    original_dir = Dir.pwd
    Dir.chdir(dir)

    extend WithinTempDir
    yield
  ensure
    Dir.chdir(original_dir)
    dir&.rmtree
  end
end

RSpec.configure do |config|
  config.include TempDirHelper
end
