# frozen_string_literal: true

require 'strscan'

class PathList
  module Gitconfig
    # @api private
    # Parse git config file for the core.excludesFile
    class FileParser
      # @param file [String]
      # @param git_dir [String]
      # @param nesting [Integer]
      # @return [String]
      # @raise [ParseError]
      def self.parse(file, git_dir: nil, nesting: 1)
        new(file, git_dir: git_dir, nesting: nesting).parse
      end

      # @param file [String]
      # @param git_dir [String]
      # @param nesting [Integer]
      def initialize(path, git_dir: nil, nesting: 1)
        @path = path
        @git_dir = git_dir
        @nesting = nesting
      end

      # @return [String]
      # @raise [ParseError]
      def parse
        raise ParseError, "Include level too deep #{path}" if nesting >= 10

        read_file(path)
        self
      end

      attr_accessor :excludesfile
      attr_accessor :submodule_paths

      private

      attr_reader :nesting
      attr_reader :path
      attr_reader :git_dir
      attr_accessor :within_quotes
      attr_accessor :section

      def read_file(path)
        return unless ::File.readable?(path)

        file = ::StringScanner.new(::File.read(path))

        until file.eos?
          if file.skip(/(\s+|[#;].*\r?\n)/)
            # skip
          elsif file.skip(/\[core\]/i)
            self.section = :core
          elsif file.skip(/\[(?i:submodule) +"/)
            self.section = :submodule
            skip_condition_value(file)
          elsif file.skip(/\[include\]/i)
            self.section = :include
          elsif file.skip(/\[(?i:includeif) +"/)
            self.section = include_if(file) ? :include : :not_include
          elsif file.skip(/\[[\w.]+( "([^\0\\"]|\\(\\{2})*"|\\{2}*)+")?\]/)
            self.section = :other
          elsif section == :submodule && file.skip(/path\s*=(\s|\\\r?\n)*/i)
            self.submodule_paths ||= []
            self.submodule_paths << scan_value(file)
          elsif section == :core && file.skip(/excludesfile\s*=(\s|\\\r?\n)*/i)
            self.excludesfile = scan_value(file)
          elsif section == :include && file.skip(/path\s*=(\s|\\\r?\n)*/)
            include_path = scan_value(file)

            result = self.class.parse(
              CanonicalPath.full_path_from(include_path, ::File.dirname(path)),
              git_dir: git_dir,
              nesting: nesting + 1
            )
            self.excludesfile = result.excludesfile if result.excludesfile
            if result.submodule_paths
              self.submodule_paths ||= []
              self.submodule_paths.concat(result.submodule_paths)
            end
            self.section = :include
          elsif file.skip(/[a-zA-Z0-9-]+\s*([#;].*)?\r?\n/)
            nil
          elsif file.skip(/[a-zA-Z0-9-]+\s*=(\s|\\\r?\n)*/)
            skip_value(file)
          else
            raise ParseError.new('Unexpected character', scanner: file, path: path)
          end
        end
      end

      def scan_condition_value(file)
        if file.scan(/([^\0\\\r\n"]|\\(\\{2})*"|\\{2}*)+(?="\])/)
          value = file.matched
          file.skip(/"\]/)
          value
        else
          raise ParseError.new('Unexpected character in condition', scanner: file, path: path)
        end
      end

      def skip_condition_value(file)
        unless file.skip(/([^\0\\\r\n"]|\\(\\{2})*"|\\{2}*)+"\]/)
          raise ParseError.new('Unexpected character in condition', scanner: file, path: path)
        end
      end

      def include_if(file)
        if file.skip(/onbranch:/)
          on_branch?(scan_condition_value(file))
        elsif file.skip(/gitdir:/)
          gitdir?(scan_condition_value(file), path: path)
        elsif file.skip(%r{gitdir/i:})
          gitdir?(scan_condition_value(file), case_insensitive: true, path: path)
        else
          skip_condition_value(file)
          false
        end
      end

      def on_branch?(branch_pattern)
        branch_pattern += '**' if branch_pattern.end_with?('/')
        current_branch = ::File.readable?("#{git_dir}/HEAD") &&
          ::File.read("#{git_dir}/HEAD").delete_prefix('ref: refs/heads/')
        return false unless current_branch

        # goddamit git what does 'a pattern with standard globbing wildcards' mean
        ::File.fnmatch(branch_pattern, current_branch, ::File::FNM_PATHNAME | ::File::FNM_DOTMATCH)
      end

      def gitdir?(gitdir_value, path:, case_insensitive: false)
        return false unless git_dir

        gitdir_value += '**' if gitdir_value.end_with?('/')
        gitdir_value.sub!(%r{\A~/}, Dir.home + '/')
        gitdir_value.sub!(/\A\./, path + '/')
        gitdir_value = "**/#{gitdir_value}" unless gitdir_value.start_with?('/')
        options = ::File::FNM_PATHNAME | ::File::FNM_DOTMATCH
        options |= ::File::FNM_CASEFOLD if case_insensitive
        ::File.fnmatch(gitdir_value, git_dir, options)
      end

      def scan_value(file)
        value = +''
        until file.eos?
          if file.skip(/\\\r?\n/)
            # continue
          elsif file.skip(/\\\\/)
            value << '\\'
          elsif file.skip(/\\n/)
            value << "\n"
          elsif file.skip(/\\t/)
            value << "\t"
          elsif file.skip(/\\b/)
            value.chop!
          elsif file.skip(/\\"/)
            value << '"'
          elsif file.skip(/\\/)
            raise ParseError.new('Unrecognized escape sequence in value', scanner: file, path: path)
          elsif within_quotes
            if file.skip(/"/)
              self.within_quotes = false
            elsif file.scan(/[^"\\\n\r]+/)
              value << file.matched
            else
              raise ParseError.new('Unexpected character in quoted value', scanner: file, path: path)
            end
          elsif file.skip(/"/)
            self.within_quotes = true
          elsif file.scan(/[^;#"\s\\]+/)
            value << file.matched
          elsif file.skip(/\s*([;#].*$)?([\n\r]+|\z)/)
            break
          elsif file.scan(/\s+/) # rubocop:disable Lint/DuplicateBranch
            value << file.matched
          # :nocov: This shouldn't be possible
          else
            raise ParseError.new('Unexpected character in value', scanner: file, path: path)
            # :nocov: This shouldn't be possible
          end
        end

        raise ParseError.new('Unclosed quoted value', scanner: file, path: path) if within_quotes

        value
      end

      def skip_value(file)
        until file.eos?
          if file.skip(/\\(?:\r?\n|\\|n|t|b|")/)
            nil
          elsif file.skip(/\\/)
            raise ParseError.new('Unrecognized escape sequence in value', scanner: file, path: path)
          elsif within_quotes
            if file.skip(/"/)
              self.within_quotes = false
            elsif file.skip(/[^"\\\n\r]+/)
              nil
            else
              raise ParseError.new('Unexpected character in quoted value', scanner: file, path: path)
            end
          elsif file.skip(/"/)
            self.within_quotes = true
          elsif file.skip(/[^;#"\s\\]+/) # rubocop:disable Lint/DuplicateBranch
            nil
          elsif file.skip(/\s*([;#].*$)?([\n\r]+|\z)/)
            break
          elsif file.skip(/\s+/) # rubocop:disable Lint/DuplicateBranch
            nil
          # :nocov: This shouldn't be possible
          else
            raise ParseError.new('Unexpected character in value', scanner: file, path: path)
            # :nocov: This shouldn't be possible
          end
        end

        raise ParseError.new('Unclosed quoted value', scanner: file, path: path) if within_quotes
      end
    end
  end
end
