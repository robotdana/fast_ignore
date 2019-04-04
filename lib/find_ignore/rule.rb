# frozen_string_literal: true

class FindIgnore
  class Rule
    def initialize(rule)
      @rule = rule
      strip!
      return if skip?

      @rule = @rule.delete_prefix('!') if negation?
      @rule = @rule.delete_suffix('/') if dir_only?
      @rule = "#{prefix}#{@rule}"
    end

    def negation?
      @negation ||= @rule.start_with?('!')
    end

    def dir_only?
      @dir_only ||= @rule.end_with?('/')
    end

    def match?(path, dir)
      return false if !dir && dir_only?

      File.fnmatch?(@rule, path, File::FNM_DOTMATCH | File::FNM_PATHNAME)
    end

    def empty?
      @empty ||= @rule.empty?
    end

    def comment?
      @comment ||= @rule.start_with?('#')
    end

    def skip?
      empty? || comment?
    end

    private

    def prefix
      @prefix ||= if @rule.start_with?('/')
        ''
      elsif @rule.end_with?('/**') || @rule.include?('/**/')
        '/'
      else
        '**/'
      end
    end

    def strip!
      @rule = @rule.chomp
      @rule = @rule.rstrip unless @rule.end_with?('\\ ')
    end
  end
end
