# frozen_string_literal: true

require 'strscan'
class PathList
  class GitconfigParser # rubocop:disable Metrics/ClassLength
    def self.parse(file, root: Dir.pwd, nesting: 1)
      new(file, root: root, nesting: nesting).parse
    end

    def initialize(path, root: Dir.pwd, nesting: 1)
      @path = path
      @root = root
      @nesting = nesting
    end

    def parse
      raise GitconfigParseError, "Include level too deep #{path}" if nesting >= 10

      read_file(path)
      return unless value

      value
    end

    private

    attr_reader :nesting
    attr_reader :path
    attr_reader :root
    attr_accessor :value
    attr_accessor :within_quotes
    attr_accessor :section

    def read_file(path) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return unless ::File.readable?(path)

      file = StringScanner.new(::File.read(path))

      until file.eos?
        if file.skip(/(\s+|[#;].*\n)/)
          # skip
        elsif file.skip(/\[core\]/i)
          self.section = :core
        elsif file.skip(/\[include\]/i)
          self.section = :include
        elsif file.skip(/\[(?i:includeif) +"/)
          self.section = include_if(file) ? :include : :not_include
        elsif file.skip(/\[[\w.]+( "([^\0\\"]|\\(\\{2})*"|\\{2}*)+")?\]/)
          self.section = :other
        elsif section == :core && file.skip(/excludesfile\s*=(\s|\\\n)*/i)
          self.value = scan_value(file)
        elsif section == :include && file.skip(/path\s*=(\s|\\\n)*/)
          include_path = scan_value(file)

          value = GitconfigParser.parse(
            PathExpander.expand_path(include_path, ::File.dirname(path)),
            root: root,
            nesting: nesting + 1
          )
          self.value = value if value
          self.section = :include
        elsif file.skip(/[a-zA-Z0-9]\w*\s*([#;].*)?\n/)
          nil
        elsif file.skip(/[a-zA-Z0-9]\w*\s*=(\s|\\\n)*/)
          skip_value(file)
        else
          raise GitconfigParseError.new('Unexpected character', scanner: file, path: path)
        end
      end
    end

    def scan_condition_value(file)
      if file.scan(/([^\0\\\n"]|\\(\\{2})*"|\\{2}*)+(?="\])/)
        value = file.matched
        file.skip(/"\]/)
        value
      else
        raise GitconfigParseError.new('Unexpected character in condition', scanner: file, path: path)
      end
    end

    def skip_condition_value(file)
      unless file.skip(/([^\0\\\n"]|\\(\\{2})*"|\\{2}*)+"\]/)
        raise GitconfigParseError.new('Unexpected character in condition', scanner: file, path: path)
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
      current_branch = ::File.readable?("#{root}/.git/HEAD") &&
        ::File.read("#{root}/.git/HEAD").delete_prefix('ref: refs/heads/')
      return false unless current_branch

      # goddamit git what does 'a pattern with standard globbing wildcards' mean
      ::File.fnmatch(branch_pattern, current_branch, ::File::FNM_PATHNAME | ::File::FNM_DOTMATCH)
    end

    def gitdir?(gitdir, path:, case_insensitive: false)
      gitdir += '**' if gitdir.end_with?('/')
      gitdir.sub!(%r{\A~/}, Dir.home + '/')
      gitdir.sub!(/\A\./, path + '/')
      gitdir = "**/#{gitdir}" unless gitdir.start_with?('/')
      options = ::File::FNM_PATHNAME | ::File::FNM_DOTMATCH
      options |= ::File::FNM_CASEFOLD if case_insensitive
      ::File.fnmatch(gitdir, ::File.join(root, '.git'), options)
    end

    def scan_value(file) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      value = +''
      until file.eos?
        if file.skip(/\\\n/)
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
          raise GitconfigParseError.new('Unrecognized escape sequence in value', scanner: file, path: path)
        elsif within_quotes
          if file.skip(/"/)
            self.within_quotes = false
          elsif file.scan(/[^"\\\n]+/)
            value << file.matched
          else
            raise GitconfigParseError.new('Unexpected character in quoted value', scanner: file, path: path)
          end
        elsif file.skip(/"/)
          self.within_quotes = true
        elsif file.scan(/[^;#"\s\\]+/)
          value << file.matched
        elsif file.skip(/\s*[;#\n]/)
          break
        elsif file.scan(/\s+/) # rubocop:disable Lint/DuplicateBranch
          value << file.matched
        # :nocov: This shouldn't be possible
        else
          raise GitconfigParseError.new('Unexpected character in value', scanner: file, path: path)
          # :nocov: This shouldn't be possible
        end
      end

      raise GitconfigParseError.new('Unclosed quoted value', scanner: file, path: path) if within_quotes

      value
    end

    def skip_value(file) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      until file.eos?
        if file.skip(/\\(?:\n|\\|n|t|b|")/)
          nil
        elsif file.skip(/\\/)
          raise GitconfigParseError.new('Unrecognized escape sequence in value', scanner: file, path: path)
        elsif within_quotes
          if file.skip(/"/)
            self.within_quotes = false
          elsif file.skip(/[^"\\\n]+/)
            nil
          else
            raise GitconfigParseError.new('Unexpected character in quoted value', scanner: file, path: path)
          end
        elsif file.skip(/"/)
          self.within_quotes = true
        elsif file.skip(/[^;#"\s\\]+/) # rubocop:disable Lint/DuplicateBranch
          nil
        elsif file.skip(/\s*[;#\n]/)
          break
        elsif file.skip(/\s+/) # rubocop:disable Lint/DuplicateBranch
          nil
        # :nocov: This shouldn't be possible
        else
          raise GitconfigParseError.new('Unexpected character in value', scanner: file, path: path)
          # :nocov: This shouldn't be possible
        end
      end

      raise GitconfigParseError.new('Unclosed quoted value', scanner: file, path: path) if within_quotes
    end
  end
end
