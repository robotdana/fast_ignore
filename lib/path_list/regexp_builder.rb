# frozen_string_literal: true

class PathList
  class RegexpBuilder
    include Autoloader

    def self.union(builders)
      new(Merge.merge(builders.map(&:parts)))
    end

    def self.new_from_path(path, tail = { end_anchor: nil })
      rb = new
      rb.append_part(:start_anchor)
      path.delete_prefix('/').split('/').each do |part|
        rb.append_part(:dir)
        rb.append_part(Regexp.escape(part))
      end
      rb.append_tail_n(tail)
      rb
    end

    attr_reader :parts

    def initialize(parts = {})
      @parts = parts
      @unanchorable = false
      @character_class
    end

    # NO!
    # def [](index)
    #   @parts[index]
    # end

    # def []=(index, value)
    #   @parts[index] = value
    # end

    def empty?
      @parts.empty?
    end

    def start_with?(value)
      @parts.key?(value)
    end

    def end=(value)
      @tail.replace(value => nil)
    end

    def dup
      out = super

      @parts = @parts.dup
      @tail = @tail.dup if @tail

      out
    end

    def end_with?(part)
      @tail.key?(part)
    end

    def to_s(builder = Builder)
      builder.to_s(@parts)
    end

    def to_regexp(builder = Builder)
      builder.to_regexp(@parts)
    end

    def compress
      @parts = Compress.compress(@parts)

      self
    end


    # NO
    def ancestors # rubocop:disable Metrics/AbcSize
      raise 'no'

      prev_rule = []
      rules = [self.class.new([:start_anchor, :dir, :end_anchor])]

      parts = @parts

      any_dir_index = parts.index(:any) || parts.index(:any_dir)
      parts = parts[0, any_dir_index] + [:any, :dir] if any_dir_index

      parts.slice_before(:dir).to_a[0...-1].each do |chunk|
        prev_rule.concat(chunk)
        (rules << self.class.new(prev_rule + [:end_anchor])) unless prev_rule == [:start_anchor]
      end

      self.class.union(rules.each(&:compress))
    end

    def append_tail_n(new_tail)
      append_tail_1(new_tail)
      # we need to find the tail of the tail
      value = tail = new_tail
      tail = value while (key, value = tail.first) && !value.nil?

      @tail = tail
      @tail_part = key
    end

    def append_tail_1(new_tail)
      if @tail_part
        @tail[@tail_part] = new_tail
      elsif @parts.empty?
        @parts = new_tail
      else

        # find tail, ugh.
        value = tail = @parts
        tail = value while (key, value = tail.first) && !value.nil?
        tail[key] = new_tail
      end
    end

    def forget_tail
      @tail = nil
      @tail_part = nil
    end

    def append_part(part)
      new_tail = { part => nil }
      append_tail_1(new_tail)
      @tail = new_tail
      @tail_part = part
    end

    def append_string(value)
      return unless value

      append_unescaped(::Regexp.escape(value))
    end

    def append_unescaped(value)
      return unless value

      if @tail_part.is_a?(String)
        @tail_part = "#{@tail_part}#{value}"
        @tail.replace(@tail_part => nil)
      else
        append_part(value)
      end
    end
  end
end
