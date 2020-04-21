# frozen_string_literal: true

class FastIgnore
  class Rule
    # FNMATCH_OPTIONS = (
    #   ::File::FNM_DOTMATCH |
    #   ::File::FNM_PATHNAME |
    #   ::File::FNM_CASEFOLD
    # ).freeze # = 14

    attr_reader :negation
    alias_method :negation?, :negation
    attr_reader :dir_only
    alias_method :dir_only?, :dir_only
    attr_reader :file_only
    alias_method :file_only?, :file_only

    attr_reader :shebang
    attr_reader :rule

    def initialize(rule, dir_only, file_only, negation, shebang = nil)
      @rule = rule
      @dir_only = dir_only
      @file_only = file_only
      @negation = negation
      @shebang = shebang

      freeze
    end

    # :nocov:
    def inspect
      if shebang
        "#<Rule #{'allow ' if negation?}#!:#{shebang.to_s[15..-4]}>"
      else
        "#<Rule #{'!' if negation?}#{rule}#{'/' if dir_only?}>"
      end
    end
    # :nocov:

    def match?(path, filename)
      if @shebang
        match_shebang?(path, filename)
      else
        ::File.fnmatch?(@rule, path, 14)
      end
    end

    def match_shebang?(path, filename)
      return false if filename.include?('.')

      first_line(path)&.match?(@shebang)
    end

    def first_line(path)
      file = ::File.new(path)
      first_line = file.sysread(25)
      first_line += file.sysread(50) until first_line.include?("\n")
      file.close
      first_line
    rescue ::EOFError, ::SystemCallError
      first_line
    ensure
      file&.close
    end
  end
end
