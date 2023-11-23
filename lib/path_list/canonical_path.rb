# frozen_string_literal: true

class PathList
  # @api private
  module CanonicalPath
    class << self
      # @!method case_insensitive?
      # @return [Boolean] is the file system case insensitive
      # (at the current directory, when this class is loaded)
      class_eval <<~RUBY, __FILE__, __LINE__ + 1 # rubocop:disable Style/DocumentDynamicEvalDefinition
        def case_insensitive?
          #{
            test_dir = ::Dir.pwd
            test_dir_swapcase = test_dir.swapcase

            if test_dir == test_dir_swapcase
              # :nocov:
              # this is copied into the canonical_path_spec to be tested there.
              # if the current directory has no casing differences
              # (maybe because it's at /)
              # then:
              require 'tmpdir'
              test_file = ::Dir.mktmpdir + '/case_test'
              ::File.write(test_file, '')
              ::File.exist?(test_file.swapcase)
              # :nocov:
            else
              ::File.identical?(test_dir, test_dir_swapcase)
            end
          }
        end
      RUBY

      # @param path [String] path to expand
      # @param dir [String, nil] path relative to, Dir.pwd when nil
      # @return [String] full path
      def full_path_from(path, dir)
        ::File.expand_path(path.to_s, dir || '.')
      rescue ::ArgumentError
        ::File.expand_path("./#{path}", dir || '.')
      end

      # @param path [String] path to expand relative to Dir.pwd
      # @return [String] full path
      def full_path(path)
        ::File.expand_path(path.to_s)
      rescue ::ArgumentError
        ::File.expand_path("./#{path}")
      end
    end
  end
end
