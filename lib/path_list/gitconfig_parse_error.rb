# frozen_string_literal: true

class PathList
  class GitconfigParseError < Error
    def initialize(message, scanner: nil, path: nil)
      @path = path
      @scanner = scanner

      super(message)
    end

    def message # rubocop:disable Metrics/AbcSize
      return super unless @scanner && @path

      lineno = @scanner.string[0...@scanner.pos].count("\n") + 1
      chars_before_our_line = @scanner.string.match(/\A(?:.*\n){#{lineno - 1}}/)[0].length
      col = @scanner.pos - chars_before_our_line
      @scanner.pos = chars_before_our_line
      line = @scanner.scan(/^[^\n]*/)
      @scanner.pos = chars_before_our_line + col

      <<~MESSAGE
        #{super}
        #{@path}:#{lineno}:#{col}
        #{line}
        #{(' ' * col) + '^'}
      MESSAGE
    end
  end
end
