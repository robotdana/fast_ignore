# frozen_string_literal: true

module Fuzz
  class << self
    def determine(iteration)
      srand ::RSpec.configuration.seed + iteration
    end

    def gitignore(iteration)
      determine(iteration)

      build_entry + maybe_newline
    end

    private

    def maybe_newline
      coinflip ? "\n" : ''
    end

    def build_entry
      ::Array.new(rand(100)) { build_character }.join
    end

    CHARACTERS = ['/', '*', '?', '[', '-', ']', '!', '\\', '^', '#', ':', '~', '.', ' ', "\n"].freeze
    private_constant :CHARACTERS

    def build_character
      coinflip ? CHARACTERS.sample : random_utf8_char
    end

    def random_utf8_char
      rand(0x1000).chr('UTF-8').match(/\A[[:print:]]\z/)&.[](0) || ''
    end

    def coinflip
      rand(2) >= 1
    end
  end
end
