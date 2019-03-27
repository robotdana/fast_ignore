# frozen_string_literal: true

class FindIgnore
  class Rule
    LAST_TWO = (-2..-1).freeze

    def initialize(rule)
      @rule = rule
      strip!
      return if skip?

      @rule = @rule.delete_prefix('!') if negation?
      @rule = @rule.delete_suffix('/') if dir_only?
    end

    def pattern
      @rule
    end

    def negation?
      @negation ||= @rule[0] == '!'
    end

    def dir_only?
      @dir_only ||= @rule[-1] == '/'
    end

    def match?(path, dir)
      return false if !dir && dir_only?

      File.fnmatch?("#{prefix}#{@rule}", path, File::FNM_DOTMATCH | File::FNM_PATHNAME)
    end

    def empty?
      @empty ||= @rule.empty?
    end

    def comment?
      @comment ||= @rule[0] == '#'
    end

    def skip?
      empty? || comment?
    end

    private

    def prefix
      return '' if @rule[0] == '/'

      '**/'
    end

    def strip!
      @rule = @rule.chomp
      @rule = @rule.rstrip unless @rule[LAST_TWO] == '\\ '
    end
  end
end
