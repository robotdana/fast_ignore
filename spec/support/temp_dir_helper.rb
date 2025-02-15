# frozen_string_literal: true

require 'pathname'
require 'tmpdir'

module TempDirHelper
  module ClassMethods
    def within_temp_dir
      around { |e| within_temp_dir { e.run } }
      before { stub_blank_global_config }
    end
  end

  module WithinTempDir
    def create_file(*lines, path:, force: false)
      path = Pathname.pwd.join(path)
      path.parent.mkpath

      if lines.empty?
        path.write('') unless path.exist?
      else
        if !force && path.exist?
          raise Errno::EEXIST unless path.read.chomp == lines.join("\n").chomp
        else
          path.write(lines.join("\n"))
        end
      end

      path
    end

    def create_dir(path)
      Pathname.pwd.join(path).mkpath
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

    def gitignore(*lines, path: '.gitignore', force: false)
      create_file(*lines, path: path, force: force)
    end

    def within_temp_dir
      yield
    end
  end

  def within_temp_dir
    clear_pattern_cache_now_and_after

    dir = Pathname.new(Dir.mktmpdir)
    original_dir = Dir.pwd
    Dir.chdir(dir)

    extend WithinTempDir

    yield
  ensure
    Dir.chdir(original_dir)
    ::FileUtils.remove_dir(dir.to_s, true) if dir
  end
end

RSpec.configure do |config|
  config.include TempDirHelper
  config.extend TempDirHelper::ClassMethods
end
