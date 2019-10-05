# v0.4.0
- include_rules support
- to make room for this, `:rules` and `:files` keyword arguments are deprecated.
  Please use `:ignore_rules` and `:ignore_files` instead.

# v0.3.3
- some performance improvements. maybe

# v0.3.2
- handle soft links to nowhere

# v0.3.1
- upgrade rubocop version requirement to avoid github security warning

# v0.3.0
- Supports 2.3 - 2.6

# v0.2.0
- Considers rules relative to the location of the gitignore file instead of just relative to PWD
- Can override the path to the gitignore file, using `FastIgnore.new(gitignore: path)`
- Mention FastIgnore#allowed? in the documentation.

# v0.1.0
Initial Release
