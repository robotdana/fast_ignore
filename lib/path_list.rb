# frozen_string_literal: true

require 'strscan'

class PathList
  class Error < StandardError; end

  require_relative 'path_list/autoloader'
  include Autoloader
  include QueryMethods
  extend BuildMethods::ClassMethods
  include BuildMethods

  def initialize
    @matcher = Matchers::Allow
  end

  protected

  attr_reader :matcher

  private

  def prepared_matcher
    @prepared ||= begin
      @matcher = @matcher.prepare

      true
    end

    @matcher
  end

  def dir_matcher
    @dir_matcher ||= @matcher.dir_matcher.prepare
  end

  def file_matcher
    @file_matcher ||= @matcher.file_matcher.prepare
  end
end
