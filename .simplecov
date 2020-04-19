SimpleCov.start do
  add_filter '/backports'
  add_filter '/spec/'
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5')
    enable_coverage(:branch)
    minimum_coverage line: 100, branch: 100
  else
    minimum_coverage 100
  end
end
