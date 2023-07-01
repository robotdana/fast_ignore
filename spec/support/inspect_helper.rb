# frozen_string_literal: true

module InspectHelper
  def default_inspect_value(object)
    Object.instance_method(:inspect).bind(object).call
  end

  def debug_match(matcher, candidate)
    unless candidate.is_a?(PathList::Candidate)
      candidate = PathList::Candidate.new(PathList::PathExpander.expand_path_pwd(candidate), nil, nil)
    end

    puts "#{matcher.inspect}\n => #{matcher.match(candidate).inspect}\n---" if matcher.respond_to?(:match)

    if matcher.respond_to?(:matchers)
      matcher.matchers.each do |sub_matcher|
        debug_match(sub_matcher, candidate)
      end
    elsif matcher.instance_variable_get(:@matcher)
      debug_match(matcher.instance_variable_get(:@matcher), candidate)
    end
  end
end

RSpec.configure do |config|
  config.include InspectHelper
end
