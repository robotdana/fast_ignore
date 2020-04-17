SimpleCov.start do
  add_filter '/backports'
  add_filter '/spec/'
  enable_coverage(:branch)
  minimum_coverage 100
end
