# frozen_string_literal: true

# rubocop:disable Style/RedundantRegexpEscape

RSpec.describe PathList::PatternParser::GlobGitignore do
  let(:method_name) { :matcher }
  let(:polarity) { :ignore }
  let(:root) { nil }

  def build(pattern)
    described_class
      .new(+pattern, polarity, root)
      .send(method_name)
  end

  describe '#build' do
    describe 'polarity: :ignore, root: "/a/path"' do
      let(:polarity) { :ignore }
      let(:root) { '/a/path' }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to be_like PathList::Matcher::Blank }
          it { expect(build(' ')).to be_like PathList::Matcher::Blank }
          it { expect(build("\t")).to be_like PathList::Matcher::Blank }
        end

        describe 'The simple case' do
          it { expect(build('foo')).to be_like PathList::Matcher::ExactString.new('/a/path/foo', :ignore) }
        end

        describe 'leading ./ means current directory based on the root' do
          it { expect(build('./foo')).to be_like PathList::Matcher::ExactString.new('/a/path/foo', :ignore) }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to be_like PathList::Matcher::Blank }
          it { expect(build('# foo')).to be_like PathList::Matcher::Blank }
          it { expect(build('#')).to be_like PathList::Matcher::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matcher::ExactString.new('/a/path/ #foo', :ignore)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matcher::ExactString.new('/a/path/#foo', :ignore)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matcher::ExactString.new('/a/path/foo\\', :ignore)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to be_like PathList::Matcher::Blank
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matcher::ExactString.new('/a/path/\\foo', :ignore)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matcher::ExactString.new('/a/path/foo', :ignore)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matcher::ExactString.new('/a/path/foo', :ignore)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matcher::ExactString.new('/a/path/foo  ', :ignore)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to be_like PathList::Matcher::Blank
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matcher::ExactString.new('/a/path/foo  ', :ignore)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matcher::ExactString.new('/a/path/foo ', :ignore)
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::ExactString.new('/a/path/foo', :ignore)
                )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::ExactString.new('/a/path/ȋ', :ignore)
                )
            end
          end
        end

        # The slash / is used as the directory separator.
        # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
        describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
          describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
            # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
            # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
            # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
            it 'includes files relative to the git dir with a middle slash' do
              expect(build('doc/frotz'))
                .to be_like PathList::Matcher::ExactString.new('/a/path/doc/frotz', :ignore)
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to be_like PathList::Matcher::Blank
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::ExactString.new('/a/path/frotz', :ignore)
                )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::ExactString.new('/a/path/frotz', :ignore)
                )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matcher::ExactString.new('/a/path/foo', :allow)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matcher::ExactString.new('/a/path/!important!.txt', :ignore)
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*our\z}, :ignore)
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]*/our\z}, :ignore)
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/f[^/]*our\z}, :ignore)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/f[^/]*r\z}, :ignore)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/few[^/]*\z}, :ignore)
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*/c\z}, :ignore)
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/b[^/]*/c\z}, :ignore)
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*b/c\z}, :ignore)
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*/[^/]*\z}, :ignore)
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]*/[^/]*/c\z}, :ignore)
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/}, :ignore)
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a}, :ignore)
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*/c\z}, :ignore)
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*c\z}, :ignore)
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]our\z}, :ignore)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/fa[^/]our\z}, :ignore)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/f[^/][^/]r\z}, :ignore)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/fou[^/]\z}, :ignore)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[ab]\z}, :ignore)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[a-c]\z}, :ignore)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[d]\z}, :ignore)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^d]\z}, :ignore)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[\]]\z}, :ignore)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^\]]\z}, :ignore)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[\[-\]]\z}, :ignore)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^\[-\]]\z}, :ignore)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[a-c]\z}, :ignore)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^a-c]\z}, :ignore)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[da]\z}, :ignore)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^da]\z}, :ignore)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[ad]\z}, :ignore)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^ad]\z}, :ignore)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[d]\z}, :ignore)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^d]\z}, :ignore)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[a-c/]\z}, :ignore)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[/a-c]\z}, :ignore)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[\+/-c]\z}, :ignore)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)["-/c]\z}, :ignore)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[/-c]\z}, :ignore)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)["-/]\z}, :ignore)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[\--c]\z}, :ignore)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)["-\-]\z}, :ignore)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[\-]\z}, :ignore)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matcher::PathRegexp.new(
                    Regexp.new('\\A/a/path/a(?!\/)["-\\-\\-]\\z'), :ignore
                  )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[\-c]\z}, :ignore)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)["-\-c]\z}, :ignore)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^a-c]\z}, :ignore)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^a-c]\z}, :ignore)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^/]\z}, :ignore)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^\^]\z}, :ignore)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[^/a]\z}, :ignore)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[/\^a]\z}, :ignore)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[/\^]\z}, :ignore)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[\^]\z}, :ignore)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[a-c\^]\z}, :ignore)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/b(?!/)[i/]b\z}, :ignore)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/b(?!/)[/]b\z}, :ignore)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to be_like PathList::Matcher::Blank
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matcher::PathRegexp.new(
                  %r{\A/a/path/b(?!/)[i/a]b\z}, :ignore
                )
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/b(?!/)[/ai]b\z}, :ignore)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to be_like PathList::Matcher::Blank
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to be_like PathList::Matcher::Blank
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matcher::ExactString.new('/a/path/a[', :ignore)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a(?!/)[\[]\z}, :ignore)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to be_like PathList::Matcher::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to be_like PathList::Matcher::Blank
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the root of the filesystem.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/[^/]*\.c\z}, :ignore)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*\/)?foo\z}, :ignore)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to be_like PathList::Matcher::Blank
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :ignore)
                )
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*\/)?foo\z}, :ignore)
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :ignore)
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*foo\z}, :ignore)
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*\/)?f[^/]*o\z}, :ignore)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*\/)?fo[^/]*\z}, :ignore)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*\/)?foo\z}, :ignore)
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/}, :ignore)
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/}, :ignore)
                )
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/}, :ignore)
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b\z}, :ignore)
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b\z}, :ignore)
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*our\z}, :ignore)
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/f[^/]*our\z}, :ignore)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/f[^/]*r\z}, :ignore)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/few[^/]*\z}, :ignore)
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/f(?:.*/)?our\z}, :ignore)
                end
              end
            end
          end
        end
      end
    end
  end
end

# rubocop:enable Style/RedundantRegexpEscape
