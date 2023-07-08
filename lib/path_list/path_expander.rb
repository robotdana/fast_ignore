# frozen_string_literal: true

class PathList
  # @api private
  module PathExpander
    # @param path [String] path to expand
    # @param dir [String, nil] path relative to, Dir.pwd when nil
    # @return [String] full path
    def self.expand_path(path, dir)
      ::File.expand_path(path.to_s, dir || '.')
    rescue ::ArgumentError
      ::File.expand_path("./#{path}", dir || '.')
    end

    # @param path [String] path to expand relative to Dir.pwd
    # @return [String] full path
    def self.expand_path_pwd(path)
      ::File.expand_path(path.to_s)
    rescue ::ArgumentError
      ::File.expand_path("./#{path}")
    end
  end
end
