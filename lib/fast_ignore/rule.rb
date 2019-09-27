# frozen_string_literal: true

class FastIgnore
  class Rule
    using DeletePrefixSuffix unless RUBY_VERSION >= '2.5'

    def initialize(rule, root:)
      @rule = rule
      strip!
      return if skip?

      extract_negation
      extract_dir_only

      @rule = "#{root}#{prefix}#{@rule}"
    end

    def negation?
      @negation
    end

    def extract_negation
      @negation = false
      return unless @rule.start_with?('!')

      @rule = @rule[1..-1]
      @negation = true
    end

    def extract_dir_only
      @dir_only = false
      return unless @rule.end_with?('/')

      @rule = @rule[0..-2]
      @dir_only = true
    end

    def match?(path, dir: File.directory?(path))
      return false if !dir && @dir_only

      File.fnmatch?(@rule, path, File::FNM_DOTMATCH | File::FNM_PATHNAME)
    end

    def empty?
      return @empty if defined?(@empty)

      @empty ||= @rule.empty?
    end

    def comment?
      return @comment if defined?(@comment)

      @comment ||= @rule.start_with?('#')
    end

    def skip?
      empty? || comment?
    end

    private

    attr_reader :root

    def prefix
      @prefix ||= if @rule.start_with?('/')
        ''
      elsif @rule.end_with?('/**') || @rule.include?('/**/')
        '/'
      else
        '/**/'
      end
    end

    def strip!
      @rule = @rule.chomp
      @rule = @rule.rstrip unless @rule.end_with?('\\ ')
    end
  end
end
