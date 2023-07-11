# frozen_string_literal: true

class PathList
  module Gitconfig
    # @api private
    class ParseError < Error
      # @param message [String]
      # @param scanner [StringScanner]
      # @param path [String]
      def initialize(message, scanner: nil, path: nil)
        @path = path
        @scanner = scanner

        super(message)
      end

      # @return [String]
      def message
        return super unless @scanner && @path

        lineno = @scanner.string[0...@scanner.pos].count("\n") + 1
        chars_before_our_line = @scanner.string.match(/\A(?:.*\n){#{lineno - 1}}/)[0].length
        col = @scanner.pos - chars_before_our_line
        @scanner.pos = chars_before_our_line
        line = @scanner.scan(/^[^\r\n]*/)
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
end
