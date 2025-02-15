# frozen_string_literal: true

class PathList
  # @api private
  module CanonicalPath
    class << self
      private

      # :nocov:
      def recurse_case_sensitivity(dir)
        children = ::Dir.children(dir)
        children.each do |child|
          result = case_sensitivity_at_path("#{dir}/#{child}")
          return result if result
        end

        children.each do |child| # rubocop:disable Style/CombinableLoops
          next unless ::File.directory?(child)

          result = recurse_case_sensitivity("#{dir}/#{child}")
          return result if result
        rescue ::IOError, ::SystemCallError
          nil
        end
      end

      def case_sensitivity_at_path(path)
        path_swapcase = path.swapcase

        return if path == path_swapcase

        ::File.identical?(path, path_swapcase) ? :insensitive : :sensitive
      rescue ::IOError, ::SystemCallError
        nil
      end
      # :nocov:

      def case_insensitive_dynamic?(path)
        (case_sensitivity_at_path(path) || recurse_case_sensitivity(path)) == :insensitive
      end
    end

    # @!method case_insensitive?
    # @return [Boolean] is the file system case insensitive
    # (at the current directory, when this class is loaded)
    module_eval <<~RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
      def self.case_insensitive?
        #{case_insensitive_dynamic?(::Dir.pwd)}
      end
    RUBY

    # @param path [String] path to expand
    # @param dir [String, nil] path relative to, Dir.pwd when nil
    # @return [String] full path
    def self.full_path_from(path, dir)
      ::File.expand_path(path.to_s, dir || '.')
    rescue ::StandardError
      ::File.expand_path("./#{path}", dir || '.')
    end

    # @param path [String] path to expand relative to Dir.pwd
    # @return [String] full path
    def self.full_path(path)
      ::File.expand_path(path.to_s)
    rescue ::StandardError
      ::File.expand_path("./#{path}")
    end

    def self.full_path_ignore_empty(path)
      if !path || path.empty?
        ''
      else
        full_path(path)
      end
    end
  end
end
