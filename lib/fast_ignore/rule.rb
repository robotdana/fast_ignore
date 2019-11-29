# frozen_string_literal: true

class FastIgnore
  class Rule
    unless ::RUBY_VERSION >= '2.5'
      require_relative 'backports/delete_prefix_suffix'
      using ::FastIgnore::Backports::DeletePrefixSuffix
    end

    unless ::RUBY_VERSION >= '2.4'
      require_relative 'backports/match'
      using ::FastIgnore::Backports::Match
    end

    FNMATCH_OPTIONS = (::File::FNM_DOTMATCH | ::File::FNM_PATHNAME | ::File::FNM_CASEFOLD).freeze

    attr_reader :rule, :glob_prefix

    def initialize(rule, root:, expand_path: false)
      @rule = rule
      strip!
      extract_dir_only
      expand_path(root) if expand_path
      return if skip?

      extract_negation

      @rule = "#{root}#{prefix}#{@rule}"
    end

    def negation?
      @negation
    end

    def glob_pattern
      @glob_pattern ||= if @dir_only
        "#{@rule}/**/*"
      else
        [@rule, "#{@rule}/**/*"]
      end
    end

    def globbable?
      !@negation && !@rule.match?(%r{/\*\*/.*[^*/]})
    end

    def dir_only?
      @dir_only
    end

    def match?(path)
      ::File.fnmatch?(@rule, path, ::FastIgnore::Rule::FNMATCH_OPTIONS)
    end

    def skip?
      empty? || comment?
    end

    private

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

    def empty?
      return @empty if defined?(@empty)

      @empty ||= @rule.empty?
    end

    def comment?
      return @comment if defined?(@comment)

      @comment ||= @rule.start_with?('#')
    end

    def expand_path(root)
      @rule = ::File.expand_path(@rule).delete_prefix(root) if @rule.match?(%r{^(?:[~/]|\.{1,2}/)})
    end

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
