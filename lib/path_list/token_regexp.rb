# frozen_string_literal: true

class PathList
  # @api private
  class TokenRegexp
    # A string that won't need to be escaped again
    class EscapedString < ::String; end

    Autoloader.autoload(self)

    # @return [Array<Symbol, String, EscapedString>]
    attr_accessor :parts

    # @param parts [Array<Symbol, String, EscapedString>]
    def initialize(parts = [])
      @parts = parts
    end

    # @return [Boolean]
    def empty?
      @parts.empty?
    end

    # @return [TokenRegexp]
    def dup
      d = super
      d.parts = @parts.dup
      d
    end

    # @return [Integer]
    def length
      @parts.length
    end

    # @return [String] this token regexp as a literal string, assuming all its parts can be literal
    def to_s
      Build.build_literal_s(@parts)
    end

    # @param part [Symbol, String, EscapedString]
    # @return [void]
    def replace_end(part)
      @parts[-1] = part
    end

    # @param position [Integer]
    # @return [Symbol, String, EscapedString, nil]
    def delete_at(position)
      @parts.delete_at(position)
    end

    # @param part [Symbol, String, EscapedString]
    # @return [Array<Symbol, String, EscapedString>]
    def append_part(part)
      @parts << part
    end

    # @param part [Symbol, String, EscapedString]
    # @return [Array<Symbol, String, EscapedString>, nil]
    def append_string(value)
      return unless value

      append_part(value)
    end

    # @param value [Array<Symbol, String, EscapedString>]
  end
end
