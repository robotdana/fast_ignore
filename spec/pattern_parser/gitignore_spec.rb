# frozen_string_literal: true

# rubocop:disable Style/RedundantRegexpEscape

RSpec.describe PathList::PatternParser::Gitignore do
  before do
    allow(PathList::CanonicalPath).to receive(:case_insensitive?).and_return(false)
  end

  let(:method_name) { :matcher }
  let(:polarity) { :ignore }
  let(:root) { nil }

  def build(pattern)
    described_class
      .new(pattern, polarity, root)
      .send(method_name)
  end

  describe '#build' do
    describe 'polarity: :ignore, root: "/a/path"' do
      let(:polarity) { :ignore }
      let(:root) { '/a/path' }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to eq PathList::Matcher::Blank }
          it { expect(build(' ')).to eq PathList::Matcher::Blank }
          it { expect(build("\t")).to eq PathList::Matcher::Blank }
        end

        describe 'The simple case' do
          it {
            expect(build('foo')).to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}, :ignore)
          }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to eq PathList::Matcher::Blank }
          it { expect(build('# foo')).to eq PathList::Matcher::Blank }
          it { expect(build('#')).to eq PathList::Matcher::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?\ \#foo\z}, :ignore)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?\#foo\z}, :ignore)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\\\z}, :ignore)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Blank
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?\\foo\z}, :ignore)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}, :ignore)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}, :ignore)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\ \ \z}, :ignore)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Blank
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\ \ \z}, :ignore)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\ \z}, :ignore)
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
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}, :ignore)
                )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?Ȋ\z}, :ignore)
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
                .to eq PathList::Matcher::Blank
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?frotz\z}, :ignore)
                )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?frotz\z}, :ignore)
                )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}, :allow)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?!important!\.txt\z}, :ignore)
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
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*our\z}, :ignore)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*r\z}, :ignore)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?few[^/]*\z}, :ignore)
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
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?[^/]our\z}, :ignore)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?fa[^/]our\z}, :ignore)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/][^/]r\z}, :ignore)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?fou[^/]\z}, :ignore)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[ab]\z}, :ignore)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[a-c]\z}, :ignore)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[d]\z}, :ignore)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^d]\z}, :ignore)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\]]\z}, :ignore)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^\]]\z}, :ignore)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\[-\]]\z}, :ignore)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^\[-\]]\z}, :ignore)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[a-c]\z}, :ignore)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^a-c]\z}, :ignore)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[da]\z}, :ignore)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^da]\z}, :ignore)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[ad]\z}, :ignore)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^ad]\z}, :ignore)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[d]\z}, :ignore)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^d]\z}, :ignore)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[a-c/]\z}, :ignore)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[/a-c]\z}, :ignore)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\+/-c]\z}, :ignore)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)["-/c]\z}, :ignore)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[/-c]\z}, :ignore)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)["-/]\z}, :ignore)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\--c]\z}, :ignore)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)["-\-]\z}, :ignore)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\-]\z}, :ignore)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matcher::PathRegexp.new(
                    Regexp.new('\\A/a/path/(?:.*/)?a(?!\/)["-\\-\\-]\\z'), :ignore
                  )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\-c]\z}, :ignore)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)["-\-c]\z}, :ignore)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^a-c]\z}, :ignore)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^a-c]\z}, :ignore)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^/]\z}, :ignore)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^\^]\z}, :ignore)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^/a]\z}, :ignore)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[/\^a]\z}, :ignore)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[/\^]\z}, :ignore)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\^]\z}, :ignore)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[a-c\^]\z}, :ignore)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?b(?!/)[i/]b\z}, :ignore)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?b(?!/)[/]b\z}, :ignore)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to eq PathList::Matcher::Blank
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matcher::PathRegexp.new(
                  %r{\A/a/path/(?:.*/)?b(?!/)[i/a]b\z}, :ignore
                )
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?b(?!/)[/ai]b\z}, :ignore)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to eq PathList::Matcher::Blank
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to eq PathList::Matcher::Blank
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a\[\z}, :ignore)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\[]\z}, :ignore)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to eq PathList::Matcher::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to eq PathList::Matcher::Blank
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]*\.c\z}, :ignore)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}, :ignore)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to eq PathList::Matcher::Blank
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :ignore)
                )
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}, :ignore)
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
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*o\z}, :ignore)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?fo[^/]*\z}, :ignore)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}, :ignore)
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
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*our\z}, :ignore)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*r\z}, :ignore)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/path/(?:.*/)?few[^/]*\z}, :ignore)
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

    describe 'polarity: :ignore, root: "/"' do
      let(:polarity) { :ignore }
      let(:root) { '/' }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to eq PathList::Matcher::Blank }
          it { expect(build(' ')).to eq PathList::Matcher::Blank }
          it { expect(build("\t")).to eq PathList::Matcher::Blank }
        end

        describe 'The simple case' do
          it { expect(build('foo')).to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :ignore) }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to eq PathList::Matcher::Blank }
          it { expect(build('# foo')).to eq PathList::Matcher::Blank }
          it { expect(build('#')).to eq PathList::Matcher::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/\ \#foo\z}, :ignore)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/\#foo\z}, :ignore)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\\\z}, :ignore)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Blank
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/\\foo\z}, :ignore)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :ignore)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :ignore)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\ \ \z}, :ignore)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Blank
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\ \ \z}, :ignore)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\ \z}, :ignore)
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
                  PathList::Matcher::PathRegexp.new(%r{/foo\z}, :ignore)
                )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{/Ȋ\z}, :ignore)
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
                .to be_like PathList::Matcher::ExactString.new('/doc/frotz', :ignore)
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to eq PathList::Matcher::Blank
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{/frotz\z}, :ignore)
                )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{/frotz\z}, :ignore)
                )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :allow)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/!important!\.txt\z}, :ignore)
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matcher::PathRegexp.new(/our\z/, :ignore)
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/[^/]*/our\z}, :ignore)
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*our\z}, :ignore)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*r\z}, :ignore)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/few[^/]*\z}, :ignore)
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*/c\z}, :ignore)
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/b[^/]*/c\z}, :ignore)
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*b/c\z}, :ignore)
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*/[^/]*\z}, :ignore)
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/[^/]*/[^/]*/c\z}, :ignore)
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/}, :ignore)
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a}, :ignore)
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/c\z}, :ignore)
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matcher::PathRegexp.new(/c\z/, :ignore)
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/[^/]our\z}, :ignore)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/fa[^/]our\z}, :ignore)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/][^/]r\z}, :ignore)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/fou[^/]\z}, :ignore)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[ab]\z}, :ignore)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c]\z}, :ignore)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[d]\z}, :ignore)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^d]\z}, :ignore)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\]]\z}, :ignore)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\]]\z}, :ignore)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\[-\]]\z}, :ignore)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\[-\]]\z}, :ignore)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c]\z}, :ignore)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]\z}, :ignore)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[da]\z}, :ignore)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^da]\z}, :ignore)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[ad]\z}, :ignore)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^ad]\z}, :ignore)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[d]\z}, :ignore)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^d]\z}, :ignore)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c/]\z}, :ignore)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/a-c]\z}, :ignore)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\+/-c]\z}, :ignore)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-/c]\z}, :ignore)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/-c]\z}, :ignore)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-/]\z}, :ignore)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\--c]\z}, :ignore)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-\-]\z}, :ignore)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\-]\z}, :ignore)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matcher::PathRegexp.new(
                    Regexp.new('/a(?!\/)["-\\-\\-]\\z'), :ignore
                  )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\-c]\z}, :ignore)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-\-c]\z}, :ignore)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]\z}, :ignore)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]\z}, :ignore)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^/]\z}, :ignore)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\^]\z}, :ignore)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^/a]\z}, :ignore)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/\^a]\z}, :ignore)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/\^]\z}, :ignore)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\^]\z}, :ignore)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c\^]\z}, :ignore)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/b(?!/)[i/]b\z}, :ignore)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/b(?!/)[/]b\z}, :ignore)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to eq PathList::Matcher::Blank
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matcher::PathRegexp.new(
                  %r{/b(?!/)[i/a]b\z}, :ignore
                )
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/b(?!/)[/ai]b\z}, :ignore)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to eq PathList::Matcher::Blank
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to eq PathList::Matcher::Blank
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a\[\z}, :ignore)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\[]\z}, :ignore)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to eq PathList::Matcher::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to eq PathList::Matcher::Blank
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
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
                .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :ignore)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to eq PathList::Matcher::Blank
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Ignore
                )
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :ignore)
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matcher::Ignore
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matcher::PathRegexp.new(/foo\z/, :ignore)
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*o\z}, :ignore)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/fo[^/]*\z}, :ignore)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :ignore)
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :ignore)
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :ignore)
                )
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :ignore)
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/(?:.*/)?b\z}, :ignore)
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/(?:.*/)?b\z}, :ignore)
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matcher::PathRegexp.new(/our\z/, :ignore)
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*our\z}, :ignore)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*r\z}, :ignore)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{/few[^\/]*\z}, :ignore)
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/f(?:.*/)?our\z}, :ignore)
                end
              end
            end
          end
        end
      end
    end

    describe 'polarity: :allow, root: "/"' do
      let(:polarity) { :allow }
      let(:root) { '/' }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to eq PathList::Matcher::Blank }
          it { expect(build(' ')).to eq PathList::Matcher::Blank }
          it { expect(build("\t")).to eq PathList::Matcher::Blank }
        end

        describe 'The simple case' do
          it { expect(build('foo')).to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :allow) }
        end

        describe 'Everything' do
          it { expect(build('*')).to be_like PathList::Matcher::Allow }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to eq PathList::Matcher::Blank }
          it { expect(build('# foo')).to eq PathList::Matcher::Blank }
          it { expect(build('#')).to eq PathList::Matcher::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/\ \#foo\z}, :allow)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/\#foo\z}, :allow)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\\\z}, :allow)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Invalid
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/\\foo\z}, :allow)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :allow)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :allow)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\ \ \z}, :allow)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Invalid
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\ \ \z}, :allow)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\ \z}, :allow)
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
                  PathList::Matcher::PathRegexp.new(%r{/foo\z}, :allow)
                )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{/Ȋ\z}, :allow)
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
                .to be_like PathList::Matcher::ExactString.new('/doc/frotz', :allow)
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to eq PathList::Matcher::Invalid
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{/frotz\z}, :allow)
                )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{/frotz\z}, :allow)
                )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :ignore)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/!important!\.txt\z}, :allow)
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matcher::PathRegexp.new(/our\z/, :allow)
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/[^/]*/our\z}, :allow)
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*our\z}, :allow)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*r\z}, :allow)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/few[^/]*\z}, :allow)
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*/c\z}, :allow)
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/b[^/]*/c\z}, :allow)
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*b/c\z}, :allow)
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*/[^/]*\z}, :allow)
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/[^/]*/[^/]*/c\z}, :allow)
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/}, :allow)
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a}, :allow)
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/c\z}, :allow)
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matcher::PathRegexp.new(/c\z/, :allow)
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/[^/]our\z}, :allow)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/fa[^/]our\z}, :allow)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/][^/]r\z}, :allow)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/fou[^/]\z}, :allow)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[ab]\z}, :allow)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c]\z}, :allow)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[d]\z}, :allow)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^d]\z}, :allow)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\]]\z}, :allow)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\]]\z}, :allow)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\[-\]]\z}, :allow)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\[-\]]\z}, :allow)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c]\z}, :allow)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]\z}, :allow)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[da]\z}, :allow)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^da]\z}, :allow)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[ad]\z}, :allow)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^ad]\z}, :allow)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[d]\z}, :allow)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^d]\z}, :allow)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c/]\z}, :allow)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/a-c]\z}, :allow)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\+/-c]\z}, :allow)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-/c]\z}, :allow)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/-c]\z}, :allow)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-/]\z}, :allow)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\--c]\z}, :allow)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-\-]\z}, :allow)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\-]\z}, :allow)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matcher::PathRegexp.new(
                    Regexp.new('/a(?!\/)["-\\-\\-]\\z'), :allow
                  )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\-c]\z}, :allow)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-\-c]\z}, :allow)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]\z}, :allow)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]\z}, :allow)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^/]\z}, :allow)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\^]\z}, :allow)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^/a]\z}, :allow)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/\^a]\z}, :allow)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/\^]\z}, :allow)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\^]\z}, :allow)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c\^]\z}, :allow)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/b(?!/)[i/]b\z}, :allow)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/b(?!/)[/]b\z}, :allow)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to eq PathList::Matcher::Invalid
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matcher::PathRegexp.new(
                  %r{/b(?!/)[i/a]b\z}, :allow
                )
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/b(?!/)[/ai]b\z}, :allow)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to eq PathList::Matcher::Invalid
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to eq PathList::Matcher::Invalid
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a\[\z}, :allow)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\[]\z}, :allow)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to eq PathList::Matcher::Invalid
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to eq PathList::Matcher::Invalid
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matcher::PathRegexp.new(%r{\A/[^/]*\.c\z}, :allow)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :allow)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to eq PathList::Matcher::Invalid
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matcher::AllowAnyDir
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :allow)
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matcher::Allow
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matcher::PathRegexp.new(/foo\z/, :allow)
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*o\z}, :allow)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/fo[^/]*\z}, :allow)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{/foo\z}, :allow)
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :allow)
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :allow)
                )
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :allow)
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/(?:.*/)?b\z}, :allow)
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matcher::PathRegexp.new(%r{\A/a/(?:.*/)?b\z}, :allow)
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matcher::PathRegexp.new(/our\z/, :allow)
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*our\z}, :allow)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{/f[^/]*r\z}, :allow)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{/few[^\/]*\z}, :allow)
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matcher::PathRegexp.new(%r{\A/f(?:.*/)?our\z}, :allow)
                end
              end
            end
          end
        end
      end
    end
  end

  describe '#implicit_matcher' do
    let(:method_name) { :implicit_matcher }

    describe 'polarity: :allow, root: "/a/path"' do
      let(:polarity) { :allow }
      let(:root) { '/a/path' }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to eq PathList::Matcher::Blank }
          it { expect(build(' ')).to eq PathList::Matcher::Blank }
          it { expect(build("\t")).to eq PathList::Matcher::Blank }
        end

        describe 'The simple case' do
          it 'matches that filename at every level' do
            expect(build('foo')).to be_like PathList::Matcher::Any::Two.new([
              PathList::Matcher::MatchIfDir.new(
                PathList::Matcher::Any::Two.new([
                  PathList::Matcher::ExactString::Set.new([
                    '/',
                    '/a',
                    '/a/path'
                  ], :allow),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                ])
              ),
              PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}, :allow)
            ])
          end
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to eq PathList::Matcher::Blank }
          it { expect(build('# foo')).to eq PathList::Matcher::Blank }
          it { expect(build('#')).to eq PathList::Matcher::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Any::Two.new([
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                  ])
                ),
                PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?\ \#foo/}, :allow)
              ])
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?\#foo/}, :allow)
                ])
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Any::Two.new([
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                  ])
                ),
                PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo\\/}, :allow)
              ])
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Invalid
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Any::Two.new([
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                  ])
                ),
                PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?\\foo/}, :allow)
              ])
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Any::Two.new([
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                  ])
                ),
                PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}, :allow)
              ])
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Any::Two.new([
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                  ])
                ),
                PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}, :allow)
              ])
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Any::Two.new([
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                  ])
                ),
                PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo\ \ /}, :allow)
              ])
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Invalid
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Any::Two.new([
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                  ])
                ),
                PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo\ \ /}, :allow)
              ])
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::Any::Two.new([
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                  ])
                ),
                PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo\ /}, :allow)
              ])
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}, :allow)
                ])
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?Ȋ/}, :allow)
                ])
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
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/doc'], :allow)
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/doc/frotz/}, :allow)
                ])
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to eq PathList::Matcher::Invalid
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?frotz/}, :allow)
                ])
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?frotz/}, :allow)
                ])
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to eq PathList::Matcher::Blank
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?!important!\.txt/}, :allow)
                ])
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/.*our/}, :allow)
                  ])
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]*\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]*/our/}, :allow)
                  ])
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*our/}, :allow)
                  ])
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*r/}, :allow)
                  ])
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?few[^/]*/}, :allow)
                  ])
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*/c/}, :allow)
                  ])
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/b[^/]*\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/b[^/]*/c/}, :allow)
                  ])
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*b\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*b/c/}, :allow)
                  ])
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/[^/]*/[^/]*/}, :allow)
                  ])
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]*(?:\z|/[^/]*\z)}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]*/[^/]*/c/}, :allow)
                  ])
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/}, :allow)
                      ])
                    ), PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/.*/}, :allow)
                  ])
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/a}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/a.*/}, :allow)
                  ])
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*/c/}, :allow)
                  ])
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*c/}, :allow)
                  ])
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?[^/]our/}, :allow)
                ])
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?fa[^/]our/}, :allow)
                ])
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/][^/]r/}, :allow)
                ])
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?fou[^/]/}, :allow)
                ])
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[ab]/}, :allow)
                ])
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[a-c]/}, :allow)
                ])
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[d]/}, :allow)
                ])
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^d]/}, :allow)
                ])
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\]]/}, :allow)
                ])
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^\]]/}, :allow)
                ])
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\[-\]]/}, :allow)
                ])
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^\[-\]]/}, :allow)
                ])
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[a-c]/}, :allow)
                ])
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^a-c]/}, :allow)
                ])
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[da]/}, :allow)
                ])
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^da]/}, :allow)
                ])
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[ad]/}, :allow)
                ])
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^ad]/}, :allow)
                ])
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[d]/}, :allow)
                ])
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^d]/}, :allow)
                ])
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[a-c/]/}, :allow)
                ])
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[/a-c]/}, :allow)
                ])
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\+/-c]/}, :allow)
                ])
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)["-/c]/}, :allow)
                ])
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[/-c]/}, :allow)
                ])
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)["-/]/}, :allow)
                ])
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\--c]/}, :allow)
                  ])
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)["-\-]/}, :allow)
                  ])
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\-]/}, :allow)
                  ])
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                expect(build('a["---]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(
                      Regexp.new('\\A/a/path/(?:.*/)?a(?!/)["-\\-\\-]/'), :allow
                    )
                  ])
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\-c]/}, :allow)
                  ])
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)["-\-c]/}, :allow)
                  ])
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^a-c]/}, :allow)
                ])
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^a-c]/}, :allow)
                ])
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^/]/}, :allow)
                ])
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^\^]/}, :allow)
                ])
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^/a]/}, :allow)
                ])
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[/\^a]/}, :allow)
                ])
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[/\^]/}, :allow)
                ])
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\^]/}, :allow)
                ])
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[a-c\^]/}, :allow)
                ])
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?b(?!/)[i/]b/}, :allow)
                ])
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?b(?!/)[/]b/}, :allow)
                ])
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to eq PathList::Matcher::Invalid
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?b(?!/)[i/a]b/}, :allow)
                ])
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?b(?!/)[/ai]b/}, :allow)
                ])
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to eq PathList::Matcher::Invalid
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to eq PathList::Matcher::Invalid
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a\[/}, :allow)
                ])
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\[]/}, :allow)
                ])
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              # nothing matches anything for implicit when negated.
              expect(build('!a['))
                .to eq PathList::Matcher::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to eq PathList::Matcher::Invalid
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow)
                ),
                PathList::Matcher::PathRegexp.new(%r{\A/a/path/[^/]*\.c/}, :allow)
              ])
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has a special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}, :allow)
                ])
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to eq PathList::Matcher::Invalid
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*/}, :allow)
                ])
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}, :allow)
                ])
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*/}, :allow)
                ])
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*foo/}, :allow)
                ])
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*o/}, :allow)
                ])
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?fo[^/]*/}, :allow)
                ])
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}, :allow)
                ])
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/abc'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/.*/}, :allow)
                ])
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/abc'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/.*/}, :allow)
                ])
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/abc'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/abc/.*/}, :allow)
                ])
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/a'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b/}, :allow)
                ])
            end

            it 'matches multiple intermediate dirs with multiple consecutive-asterisk-slashes' do
              expect(build('a/**/b/**/c/**/d'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/a'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b/(?:.*/)?c/(?:.*/)?d/}, :allow)
                ])
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path', '/a/path/a'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b/}, :allow)
                ])
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::MatchIfDir.new(
                        PathList::Matcher::Any::Two.new([
                          PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                          PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                        ])
                      ),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/.*our/}, :allow)
                    ])
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::MatchIfDir.new(
                        PathList::Matcher::Any::Two.new([
                          PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                          PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                        ])
                      ),
                      PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*our/}, :allow)
                    ])
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::MatchIfDir.new(
                        PathList::Matcher::Any::Two.new([
                          PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                          PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                        ])
                      ),
                      PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*r/}, :allow)
                    ])
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::MatchIfDir.new(
                        PathList::Matcher::Any::Two.new([
                          PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                          PathList::Matcher::PathRegexp.new(%r{\A/a/path/}, :allow)
                        ])
                      ),
                      PathList::Matcher::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?few[^/]*/}, :allow)
                    ])
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::MatchIfDir.new(
                        PathList::Matcher::Any::Two.new([
                          PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/path'], :allow),
                          PathList::Matcher::PathRegexp.new(%r{\A/a/path/f}, :allow)
                        ])
                      ),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/path/f(?:.*/)?our/}, :allow)
                    ])
                end
              end
            end
          end
        end
      end
    end

    describe 'polarity: :allow, root: "/"' do
      let(:polarity) { :allow }
      let(:root) { '/' }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to eq PathList::Matcher::Blank }
          it { expect(build(' ')).to eq PathList::Matcher::Blank }
          it { expect(build("\t")).to eq PathList::Matcher::Blank }
        end

        describe 'The simple case' do
          it do
            expect(build('foo')).to be_like PathList::Matcher::Any::Two.new([
              PathList::Matcher::AllowAnyDir,
              PathList::Matcher::PathRegexp.new(%r{/foo/}, :allow)
            ])
          end
        end

        describe 'Everything' do
          it { expect(build('*')).to be_like PathList::Matcher::Allow }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to eq PathList::Matcher::Blank }
          it { expect(build('# foo')).to eq PathList::Matcher::Blank }
          it { expect(build('#')).to eq PathList::Matcher::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::AllowAnyDir,
                PathList::Matcher::PathRegexp.new(%r{/\ \#foo/}, :allow)
              ])
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/\#foo/}, :allow)
                ])
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::AllowAnyDir,
                PathList::Matcher::PathRegexp.new(%r{/foo\\/}, :allow)
              ])
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Invalid
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::AllowAnyDir,
                PathList::Matcher::PathRegexp.new(%r{/\\foo/}, :allow)
              ])
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::AllowAnyDir,
                PathList::Matcher::PathRegexp.new(%r{/foo/}, :allow)
              ])
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::AllowAnyDir,
                PathList::Matcher::PathRegexp.new(%r{/foo/}, :allow)
              ])
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::AllowAnyDir,
                PathList::Matcher::PathRegexp.new(%r{/foo\ \ /}, :allow)
              ])
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to eq PathList::Matcher::Invalid
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::AllowAnyDir,
                PathList::Matcher::PathRegexp.new(%r{/foo\ \ /}, :allow)
              ])
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::AllowAnyDir,
                PathList::Matcher::PathRegexp.new(%r{/foo\ /}, :allow)
              ])
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/foo/}, :allow)
                ])
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/Ȋ/}, :allow)
                ])
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
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::ExactString::Set.new(['/', '/doc'], :allow)
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/doc/frotz/}, :allow)
                ])
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to eq PathList::Matcher::Invalid
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/frotz/}, :allow)
                ])
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/frotz/}, :allow)
                ])
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to eq PathList::Matcher::Blank
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/!important!\.txt/}, :allow)
                ])
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir,
                    PathList::Matcher::PathRegexp.new(%r{our/}, :allow)
                  ])
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString.new('/', :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/[^/]*\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/[^/]*/our/}, :allow)
                  ])
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir,
                    PathList::Matcher::PathRegexp.new(%r{/f[^/]*our/}, :allow)
                  ])
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir,
                    PathList::Matcher::PathRegexp.new(%r{/f[^/]*r/}, :allow)
                  ])
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir,
                    PathList::Matcher::PathRegexp.new(%r{/few[^/]*/}, :allow)
                  ])
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*/c/}, :allow)
                  ])
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/b[^/]*\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/b[^/]*/c/}, :allow)
                  ])
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*b\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*b/c/}, :allow)
                  ])
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*\z}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/[^/]*/[^/]*/}, :allow)
                  ])
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString.new('/', :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/[^/]*(?:\z|/[^/]*\z)}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/[^/]*/[^/]*/c/}, :allow)
                  ])
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString::Set.new(['/', '/a'], :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a/}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a/.*/}, :allow)
                  ])
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::MatchIfDir.new(
                      PathList::Matcher::Any::Two.new([
                        PathList::Matcher::ExactString.new('/', :allow),
                        PathList::Matcher::PathRegexp.new(%r{\A/a}, :allow)
                      ])
                    ),
                    PathList::Matcher::PathRegexp.new(%r{\A/a.*/}, :allow)
                  ])
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir,
                    PathList::Matcher::PathRegexp.new(%r{/c/}, :allow)
                  ])
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir,
                    PathList::Matcher::PathRegexp.new(%r{c/}, :allow)
                  ])
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/[^/]our/}, :allow)
                ])
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/fa[^/]our/}, :allow)
                ])
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/f[^/][^/]r/}, :allow)
                ])
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/fou[^/]/}, :allow)
                ])
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[ab]/}, :allow)
                ])
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c]/}, :allow)
                ])
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[d]/}, :allow)
                ])
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^d]/}, :allow)
                ])
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\]]/}, :allow)
                ])
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\]]/}, :allow)
                ])
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\[-\]]/}, :allow)
                ])
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\[-\]]/}, :allow)
                ])
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c]/}, :allow)
                ])
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]/}, :allow)
                ])
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[da]/}, :allow)
                ])
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^da]/}, :allow)
                ])
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[ad]/}, :allow)
                ])
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^ad]/}, :allow)
                ])
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[d]/}, :allow)
                ])
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^d]/}, :allow)
                ])
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c/]/}, :allow)
                ])
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/a-c]/}, :allow)
                ])
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\+/-c]/}, :allow)
                ])
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-/c]/}, :allow)
                ])
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/-c]/}, :allow)
                ])
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-/]/}, :allow)
                ])
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\--c]/}, :allow)
                  ])
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-\-]/}, :allow)
                  ])
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\-]/}, :allow)
                  ])
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(
                      Regexp.new('/a(?!\/)["-\\-\\-]/'), :allow
                    )
                  ])
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\-c]/}, :allow)
                  ])
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matcher::Any::Two.new([
                    PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)["-\-c]/}, :allow)
                  ])
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]/}, :allow)
                ])
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^a-c]/}, :allow)
                ])
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^/]/}, :allow)
                ])
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^\^]/}, :allow)
                ])
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[^/a]/}, :allow)
                ])
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/\^a]/}, :allow)
                ])
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[/\^]/}, :allow)
                ])
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\^]/}, :allow)
                ])
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[a-c\^]/}, :allow)
                ])
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/b(?!/)[i/]b/}, :allow)
                ])
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/b(?!/)[/]b/}, :allow)
                ])
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to eq PathList::Matcher::Invalid
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(
                    %r{/b(?!/)[i/a]b\/}, :allow
                  )
                ])
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/b(?!/)[/ai]b/}, :allow)
                ])
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to eq PathList::Matcher::Invalid
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to eq PathList::Matcher::Invalid
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a\[/}, :allow)
                ])
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/a(?!/)[\[]/}, :allow)
                ])
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to eq PathList::Matcher::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to eq PathList::Matcher::Invalid
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matcher::Any::Two.new([
                PathList::Matcher::MatchIfDir.new(
                  PathList::Matcher::ExactString.new('/', :allow)
                ), PathList::Matcher::PathRegexp.new(%r{\A/[^/]*\.c/}, :allow)
              ])
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir, PathList::Matcher::PathRegexp.new(%r{/foo/}, :allow)
                ])
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to eq PathList::Matcher::Invalid
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matcher::Allow
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/foo/}, :allow)
                ])
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matcher::Allow
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{foo/}, :allow)
                ])
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/f[^/]*o/}, :allow)
                ])
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/fo[^/]*/}, :allow)
                ])
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::AllowAnyDir,
                  PathList::Matcher::PathRegexp.new(%r{/foo/}, :allow)
                ])
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/abc'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/abc/.*/}, :allow)
                ])
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/abc'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/abc/.*/}, :allow)
                ])
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/abc'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/abc/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/abc/.*/}, :allow)
                ])
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/(?:.*/)?b/}, :allow)
                ])
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matcher::Any::Two.new([
                  PathList::Matcher::MatchIfDir.new(
                    PathList::Matcher::Any::Two.new([
                      PathList::Matcher::ExactString::Set.new(['/', '/a'], :allow),
                      PathList::Matcher::PathRegexp.new(%r{\A/a/}, :allow)
                    ])
                  ),
                  PathList::Matcher::PathRegexp.new(%r{\A/a/(?:.*/)?b/}, :allow)
                ])
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::AllowAnyDir,
                      PathList::Matcher::PathRegexp.new(%r{our/}, :allow)
                    ])
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::AllowAnyDir,
                      PathList::Matcher::PathRegexp.new(%r{/f[^/]*our/}, :allow)
                    ])
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::AllowAnyDir,
                      PathList::Matcher::PathRegexp.new(%r{/f[^/]*r/}, :allow)
                    ])
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::AllowAnyDir,
                      PathList::Matcher::PathRegexp.new(%r{/few[^/]*/}, :allow)
                    ])
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matcher::Any::Two.new([
                      PathList::Matcher::MatchIfDir.new(
                        PathList::Matcher::Any::Two.new([
                          PathList::Matcher::ExactString.new('/', :allow),
                          PathList::Matcher::PathRegexp.new(%r{\A/f}, :allow)
                        ])
                      ),
                      PathList::Matcher::PathRegexp.new(%r{\A/f(?:.*/)?our/}, :allow)
                    ])
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
