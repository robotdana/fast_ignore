# FastIgnore

![travis](https://travis-ci.org/robotdana/fast_ignore.svg?branch=master)

Filter a directory using a .gitignore file. Follows all the gitignore formatting rules including `!dir` and `/dir`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fast_ignore'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fast_ignore

## Usage
```ruby
FastIgnore.new.each { |file| puts "#{file} is not ignored by the .gitignore" }
```

Like many other enumerables, FastIgnore.new.each can return an enumerator
```ruby
FastIgnore.new.each.with_index { |file, index| puts "#{file}#{index}" }
```

By default, FastIgnore will return full paths. To return paths relative to the current working directory, use:

```ruby
FastIgnore.new(relative: true).to_a
```

You can specify other gitignore-style files to ignore as well. These rules will be appended after the gitignore file in order (order matters for negations)
```ruby
FastIgnore.new(files: '/path/to/my/ignore/file').to_a
FastIgnore.new(files: ['/path/to/my/ignore/file', '/and/another']).to_a
```

You can also supply an array of rule lines. These rules will be appended after the gitignore and any other files in order (order matters for negations)
```ruby
FastIgnore.new(rules: '.DS_Store').to_a
FastIgnore.new(rules: ['.git', '.gitkeep']).to_a
```

By default, FastIgnore will look in the directory the script is run in (PWD) for a gitignore file. If it's somewhere else,
```ruby
FastIgnore.new(rules: '.git', files: '/path/to/.gitignore', gitignore: false).to_a
FastIgnore.new(rules: '.git', files: ['/path/to/.gitignore', '/path/to/other/excludesfile'], gitignore: false).to_a
```
(You need the rules: '.git' because we're excluding the normal gitignore file)

## Known issues/TODOs
- Considers rules relative to the location of the gitignore file, to always be relative to PWD instead
- Can't override path to gitignore file nicley, Ideally it would be `FastIgnore.new(gitignore: path)`
- Doesn't take into account ignored project excludes in `.git/info/exclude`
- Doesn't take into account globally ignored files in `git config core.excludesFile`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/robotdana/fast_ignore.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
