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

  def dup
    d = self.class.new
    d.matcher = matcher
    d
  end

  protected

  attr_accessor :matcher
end
