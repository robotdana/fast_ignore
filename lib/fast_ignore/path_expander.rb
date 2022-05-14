# frozen_string_literal: true

class FastIgnore
  module PathExpander
    def self.expand_path(path, dir = Dir.pwd)
      ::File.expand_path(path.to_s, dir)
    rescue ::ArgumentError
      ::File.expand_path("./#{path}", dir)
    end

    def self.expand_dir(path, dir = Dir.pwd)
      path = expand_path(path, dir)
      path += '/' unless path.end_with?('/')
      path
    end
  end
end
