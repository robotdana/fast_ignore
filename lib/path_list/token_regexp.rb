# frozen_string_literal: true

class PathList
  class TokenRegexp
    class EscapedString < ::String; end

    include Autoloader

    attr_reader :parts

    def initialize(parts = [])
      @parts = parts
    end

    def empty?
      @parts.empty?
    end

    def start_with?(value)
      @parts[0] == value
    end

    def dup
      d = super
      d.parts = @parts.dup
      d
    end

    def concat(array)
      @parts.concat(array)

      self
    end

    def end_with?(part)
      @parts[-1] == part
    end

    def length
      @parts.length
    end

    def to_s
      Build.build_literal_s(@parts)
    end

    def replace_end(part)
      @parts[-1] = part
    end

    def delete_at(position)
      @parts.delete_at(position)
    end

    def append_part(part)
      @parts << part
    end

    def append_string(value)
      return unless value

      append_part(value)
    end

    protected

    attr_writer :parts
  end
end
