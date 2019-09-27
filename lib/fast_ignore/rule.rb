# frozen_string_literal: true

class FastIgnore
  class Rule
    using DeletePrefixSuffix unless RUBY_VERSION >= '2.5'

    def initialize(rule, root: Dir.pwd)
      @root = root
      @rule = rule
      strip!
      return if skip?

      @rule = @rule[1..-1] if negation?
      @rule = @rule[0..-2] if dir_only?
      @rule = "#{prefix}#{@rule}"
    end

    def negation?
      return @negation if defined?(@negation)

      @negation ||= @rule.start_with?('!')
    end

    def dir_only?
      return @dir_only if defined?(@dir_only)

      @dir_only ||= @rule.end_with?('/')
    end

    def match?(path, dir: File.directory?(path))
      return false if !dir && dir_only?

      path = path.delete_prefix(root)

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
        '**/'
      end
    end

    def strip!
      @rule = @rule.chomp
      @rule = @rule.rstrip unless @rule.end_with?('\\ ')
    end
  end
end
