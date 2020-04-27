# frozen_string_literal: true

class FastIgnore
  class ShebangRule
    attr_reader :negation
    alias_method :negation?, :negation
    undef :negation

    attr_reader :rule
    alias_method :shebang, :rule

    attr_reader :type

    def initialize(rule, negation)
      @rule = rule
      @negation = negation

      @type = 2
      @type += 1 if negation

      freeze
    end

    def file_only?
      true
    end

    def dir_only?
      false
    end

    def unanchored?
      true
    end

    # :nocov:
    def inspect
      "#<ShebangRule #{'allow ' if @negation}#!:#{@rule.to_s[15..-4]}>"
    end
    # :nocov:

    def match?(_, full_path, filename)
      return false if filename.include?('.')

      first_line(full_path)&.match?(@rule)
    end

    private

    def first_line(path)
      file = ::File.new(path)
      first_line = file.sysread(25)
      first_line += file.sysread(50) until first_line.include?("\n")
      file.close
      first_line
    rescue ::EOFError, ::SystemCallError
      # :nocov:
      file&.close
      # :nocov:
      first_line
    end
  end
end
