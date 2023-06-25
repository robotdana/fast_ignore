# frozen_string_literal: true

class PathList
  module PathExpander
    def self.expand_path(path, dir)
      ::File.expand_path(path.to_s, dir || '.')
    rescue ::ArgumentError
      ::File.expand_path("./#{path}", dir || '.')
    end

    def self.expand_path_pwd(path)
      ::File.expand_path(path.to_s)
    rescue ::ArgumentError
      ::File.expand_path("./#{path}")
    end
  end
end
