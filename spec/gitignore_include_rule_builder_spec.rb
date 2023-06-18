# frozen_string_literal: true

# rubocop:disable Style/RedundantRegexpEscape, Style/RedundantRegexpCharacterClass

RSpec.describe PathList::GitignoreIncludeRuleBuilder do
  describe '#build' do
    describe 'from the gitignore documentation' do
      describe 'A blank line matches no files, so it can serve as a separator for readability.' do
        it { expect(described_class.new('').build).to eq PathList::Matchers::Blank }
        it { expect(described_class.new(' ').build).to eq PathList::Matchers::Blank }
        it { expect(described_class.new("\t").build).to eq PathList::Matchers::Blank }
      end

      describe 'A line starting with # serves as a comment.' do
        it { expect(described_class.new('#foo').build).to eq PathList::Matchers::Blank }
        it { expect(described_class.new('# foo').build).to eq PathList::Matchers::Blank }
        it { expect(described_class.new('#').build).to eq PathList::Matchers::Blank }

        it 'must be the first character' do
          expect(described_class.new(' #foo').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\ \#foo\z}i, true)
        end

        describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
          it do
            expect(described_class.new('\\#foo').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\#foo\z}i, true)
          end
        end
      end

      describe 'literal backslashes in filenames' do
        it 'matches an escaped backslash at the end of the pattern' do
          expect(described_class.new('foo\\\\').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\\\z}i, true)
        end

        it 'never matches a literal backslash at the end of the pattern' do
          expect(described_class.new('foo\\').build)
            .to eq PathList::Matchers::Invalid
        end

        it 'matches an escaped backslash at the start of the pattern' do
          expect(described_class.new('\\\\foo').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\\foo\z}i, true)
        end

        it 'matches a literal escaped f at the start of the pattern' do
          expect(described_class.new('\\foo').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
        end
      end

      describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
        it 'ignores trailing spaces in the gitignore file' do
          expect(described_class.new('foo  ').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
        end

        it "doesn't ignore trailing spaces if there's a backslash" do
          expect(described_class.new('foo \\ ').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ \z}i, true)
        end

        it 'considers trailing backslashes to never be matched' do
          expect(described_class.new('foo\\').build)
            .to eq PathList::Matchers::Invalid
        end

        it "doesn't ignore trailing spaces if there's a backslash before every space" do
          expect(described_class.new('foo\\ \\ ').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ \z}i, true)
        end

        it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
          expect(described_class.new('foo\\  ').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \z}i, true)
        end
      end

      describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
        describe 'but it would only find a match with a directory' do
          # In other words, foo/ will match a directory foo and paths underneath it,
          # but will not match a regular file or a symbolic link foo
          # (this is consistent with the way how pathspec works in general in Git).

          it 'ignores directories but not files or symbolic links that match patterns ending with /' do
            expect(described_class.new('foo/').build)
              .to eq PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
              )
          end

          it 'handles this specific edge case i stumbled across' do
            expect(described_class.new('Ȋ/').build)
              .to eq PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)Ȋ\z}i, true)
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
            expect(described_class.new('doc/frotz').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{\Adoc/frotz\z}i, true)
          end

          it 'treats a double slash as matching nothing' do
            expect(described_class.new('doc//frotz').build)
              .to eq PathList::Matchers::Invalid
          end
        end

        describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
          # frotz/ matches frotz and a/frotz that is a directory

          it 'includes files relative to anywhere with only an end slash' do
            expect(described_class.new('frotz/').build)
              .to eq PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz\z}i, true)
              )
          end

          it 'strips trailing space before deciding a rule is dir_only' do
            expect(described_class.new('frotz/ ').build)
              .to eq PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz\z}i, true)
              )
          end
        end
      end

      describe 'An optional prefix "!" which negates the pattern' do
        describe 'any matching file excluded by a previous pattern will become included again.' do
          it 'includes previously excluded files' do
            expect(described_class.new('!foo').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false)
          end
        end

        describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
          # for example, "\!important!.txt".'

          it 'matches files starting with a literal ! if its preceded by a backslash' do
            expect(described_class.new('\!important!.txt').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)!important!\.txt\z}i, true)
          end
        end
      end

      describe 'Otherwise, Git treats the pattern as a shell glob' do
        describe '"*" matches anything except "/"' do
          describe 'single level' do
            it "matches any number of characters at the beginning if there's a star" do
              expect(described_class.new('*our').build)
                .to eq PathList::Matchers::PathRegexp.new(/our\z/i, true)
            end

            it "matches any number of characters at the beginning if there's a star followed by a slash" do
              expect(described_class.new('*/our').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{\A[^/]*/our\z}i, true)
            end

            it "doesn't match a slash" do
              expect(described_class.new('f*our').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our\z}i, true)
            end

            it "matches any number of characters in the middle if there's a star" do
              expect(described_class.new('f*r').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r\z}i, true)
            end

            it "matches any number of characters at the end if there's a star" do
              expect(described_class.new('few*').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few[^\/]*\z}i, true)
            end
          end

          describe 'multi level' do
            it 'matches a whole directory' do
              expect(described_class.new('a/*/c').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/c\z}i, true)
            end

            it 'matches an exact partial match at start' do
              expect(described_class.new('a/b*/c').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{\Aa/b[^/]*/c\z}i, true)
            end

            it 'matches an exact partial match at end' do
              expect(described_class.new('a/*b/c').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*b/c\z}i, true)
            end

            it 'matches multiple directories when sequential /*/' do
              expect(described_class.new('a/*/*').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/[^/]*[^/]\z}i, true)
            end

            it 'matches multiple directories when beginning sequential /*/' do
              expect(described_class.new('*/*/c').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{\A[^/]*/[^/]*/c\z}i, true)
            end

            it 'matches multiple directories when ending with /**/*' do
              expect(described_class.new('a/**/*').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?[^/]*[^/]\z}i, true)
            end

            it 'matches multiple directories when ending with **/*' do
              expect(described_class.new('a**/*').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{\Aa(?:.*/)?[^/]*[^/]\z}i, true)
            end

            it 'matches multiple directories when beginning with **/*/' do
              expect(described_class.new('**/*/c').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{/c\z}i, true)
            end

            it 'matches multiple directories when beginning with **/*' do
              expect(described_class.new('**/*c').build)
                .to eq PathList::Matchers::PathRegexp.new(/c\z/i, true)
            end
          end
        end

        describe '"?" matches any one character except "/"' do
          it "matches one character at the beginning if there's a ?" do
            expect(described_class.new('?our').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)[^/]our\z}i, true)
          end

          it "doesn't match a slash" do
            expect(described_class.new('fa?our').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fa[^/]our\z}i, true)
          end

          it 'matches per ?' do
            expect(described_class.new('f??r').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/][^/]r\z}i, true)
          end

          it "matches a single character at the end if there's a ?" do
            expect(described_class.new('fou?').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fou[^/]\z}i, true)
          end
        end

        describe '"[]" matches one character in a selected range' do
          it 'matches a single character in a character class' do
            expect(described_class.new('a[ab]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ab]\z}i, true)
          end

          it 'matches a single character in a character class range' do
            expect(described_class.new('a[a-c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]\z}i, true)
          end

          it 'treats a backward character class range as only the first character of the range' do
            expect(described_class.new('a[d-a]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]\z}i, true)
          end

          it 'treats a negated backward character class range as only the first character of the range' do
            expect(described_class.new('a[^d-a]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]\z}i, true)
          end

          it 'treats a escaped backward character class range as only the first character of the range' do
            expect(described_class.new('a[\\]-\\[]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\]]\z}i, true)
          end

          it 'treats a negated escaped backward character class range as only the first character of the range' do
            expect(described_class.new('a[^\\]-\\[]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\]]\z}i, true)
          end

          it 'treats a escaped character class range as as a range' do
            expect(described_class.new('a[\\[-\\]]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[-\]]\z}i, true)
          end

          it 'treats a negated escaped character class range as a range' do
            expect(described_class.new('a[^\\[-\\]]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\[-\]]\z}i, true)
          end

          it 'treats an unnecessarily escaped character class range as a range' do
            expect(described_class.new('a[\\a-\\c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]\z}i, true)
          end

          it 'treats a negated unnecessarily escaped character class range as a range' do
            expect(described_class.new('a[^\\a-\\c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, true)
          end

          it 'treats a backward character class range with other options as only the first character of the range' do
            expect(described_class.new('a[d-ba]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[da]\z}i, true)
          end

          it 'treats a negated backward character class range with other options as the first character of the range' do
            expect(described_class.new('a[^d-ba]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^da]\z}i, true)
          end

          it 'treats a backward char class range with other initial options as the first char of the range' do
            expect(described_class.new('a[ad-b]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ad]\z}i, true)
          end

          it 'treats a negated backward char class range with other initial options as the first char of the range' do
            expect(described_class.new('a[^ad-b]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^ad]\z}i, true)
          end

          it 'treats a equal character class range as only the first character of the range' do
            expect(described_class.new('a[d-d]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]\z}i, true)
          end

          it 'treats a negated equal character class range as only the first character of the range' do
            expect(described_class.new('a[^d-d]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]\z}i, true)
          end

          it 'interprets a / after a character class range as not there' do
            expect(described_class.new('a[a-c/]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c/]\z}i, true)
          end

          it 'interprets a / before a character class range as not there' do
            expect(described_class.new('a[/a-c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/a-c]\z}i, true)
          end

          # TODO: confirm if that matches a slash character
          it 'interprets a / before the dash in a character class range as any character from / to c' do
            expect(described_class.new('a[+/-c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\+/-c]\z}i, true)
          end

          it 'interprets a / after the dash in a character class range as any character from start to /' do
            expect(described_class.new('a["-/c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/c]\z}i, true)
          end

          it 'interprets a slash then dash then character to be a character range' do
            expect(described_class.new('a[/-c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/-c]\z}i, true)
          end

          it 'interprets a character then dash then slash to be a character range' do
            expect(described_class.new('a["-/]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/]\z}i, true)
          end

          context 'without raising warnings' do
            # these edge cases raise warnings
            # they're edge-casey enough if you hit them you deserve warnings.
            before { allow(Warning).to receive(:warn) }

            it 'interprets dash dash character as a character range beginning with -' do
              expect(described_class.new('a[--c]').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\--c]\z}i, true)
            end

            it 'interprets character dash dash as a character range ending with -' do
              expect(described_class.new('a["--]').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-]\z}i, true)
            end

            it 'interprets dash dash dash as a character range of only with -' do
              expect(described_class.new('a[---]').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-]\z}i, true)
            end

            it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
              # for some reason this as a regexp literal triggers the warning raise
              expect(described_class.new('a["---]').build).to eq PathList::Matchers::PathRegexp.new(
                Regexp.new('(?:\\A|\\/)a(?!\\/)["-\\-\\-]\\z', 1), true
              )
            end

            it 'interprets dash dash dash character as a character range of only - with literal c' do
              expect(described_class.new('a[---c]').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-c]\z}i, true)
            end

            it 'interprets character dash dash character as a character range ending with - and a literal c' do
              # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
              # but ruby regex and git seem to treat this edge case the same
              expect(described_class.new('a["--c]').build)
                .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-c]\z}i, true)
            end
          end

          it '^ is not' do
            expect(described_class.new('a[^a-c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, true)
          end

          # this doesn't appear to be documented anywhere i just stumbled onto it
          it '! is also not' do
            expect(described_class.new('a[!a-c]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, true)
          end

          it '[^/] matches everything' do
            expect(described_class.new('a[^/]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/]\z}i, true)
          end

          it '[^^] matches everything except literal ^' do
            expect(described_class.new('a[^^]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\^]\z}i, true)
          end

          it '[^/a] matches everything except a' do
            expect(described_class.new('a[^/a]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/a]\z}i, true)
          end

          it '[/^a] matches literal ^ and a' do
            expect(described_class.new('a[/^a]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^a]\z}i, true)
          end

          it '[/^] matches literal ^' do
            expect(described_class.new('a[/^]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^]\z}i, true)
          end

          it '[\\^] matches literal ^' do
            expect(described_class.new('a[\^]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\^]\z}i, true)
          end

          it 'later ^ is literal' do
            expect(described_class.new('a[a-c^]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c\^]\z}i, true)
          end

          it "doesn't match a slash even if you specify it last" do
            expect(described_class.new('b[i/]b').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/]b\z}i, true)
          end

          it "doesn't match a slash even if you specify it alone" do
            expect(described_class.new('b[/]b').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/]b\z}i, true)
          end

          it 'empty class matches nothing' do
            expect(described_class.new('b[]b').build)
              .to eq PathList::Matchers::Invalid
          end

          it "doesn't match a slash even if you specify it middle" do
            expect(described_class.new('b[i/a]b').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/a]b\z}i, true)
          end

          it "doesn't match a slash even if you specify it start" do
            expect(described_class.new('b[/ai]b').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/ai]b\z}i, true)
          end

          it 'assumes an unfinished [ matches nothing' do
            expect(described_class.new('a[').build)
              .to eq PathList::Matchers::Invalid
          end

          it 'assumes an unfinished [ followed by \ matches nothing' do
            expect(described_class.new('a[\\').build)
              .to eq PathList::Matchers::Invalid
          end

          it 'assumes an escaped [ is literal' do
            expect(described_class.new('a\\[').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\[\z}i, true)
          end

          it 'assumes an escaped [ is literal inside a group' do
            expect(described_class.new('a[\\[]').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[]\z}i, true)
          end

          it 'assumes an unfinished [ matches nothing when negated' do
            expect(described_class.new('!a[').build)
              .to eq PathList::Matchers::Invalid
          end

          it 'assumes an unfinished [bc matches nothing' do
            expect(described_class.new('a[bc').build)
              .to eq PathList::Matchers::Invalid
          end
        end

        # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
      end

      describe 'A leading slash matches the beginning of the pathname.' do
        # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
        it 'matches only at the beginning of everything' do
          expect(described_class.new('/*.c').build)
            .to eq PathList::Matchers::PathRegexp.new(%r{\A[^/]*\.c\z}i, true)
        end
      end

      describe 'Two consecutive asterisks ("**") in patterns matched against full pathname may have special meaning:' do
        describe 'A leading "**" followed by a slash means match in all directories.' do
          # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
          # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

          it 'matches files or directories in all directories' do
            expect(described_class.new('**/foo').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
          end

          it 'matches nothing with double slash' do
            expect(described_class.new('**//foo').build)
              .to eq PathList::Matchers::Invalid
          end

          it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
            expect(described_class.new('**/').build)
              .to eq PathList::Matchers::MatchIfDir.new(PathList::Matchers::Allow)
          end

          it 'matches files or directories in all directories when repeated' do
            expect(described_class.new('**/**/foo').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
          end

          it 'matches files or directories in all directories with **/*' do
            expect(described_class.new('**/*').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{[^/]\z}i, true)
          end

          it 'matches files or directories in all directories when also followed by a star before text' do
            expect(described_class.new('**/*foo').build)
              .to eq PathList::Matchers::PathRegexp.new(/foo\z/i, true)
          end

          it 'matches files or directories in all directories when also followed by a star within text' do
            expect(described_class.new('**/f*o').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*o\z}i, true)
          end

          it 'matches files or directories in all directories when also followed by a star after text' do
            expect(described_class.new('**/fo*').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fo[^\/]*\z}i, true)
          end

          it 'matches files or directories in all directories when three stars' do
            expect(described_class.new('***/foo').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
          end
        end

        describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
          it 'matches files or directories inside the mentioned directory' do
            expect(described_class.new('abc/**').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true)
          end

          it 'matches all directories inside the mentioned directory' do
            expect(described_class.new('abc/**/').build)
              .to eq PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true))
          end

          it 'matches files or directories inside the mentioned directory when ***' do
            expect(described_class.new('abc/***').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true)
          end
        end

        describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
          it 'matches multiple intermediate dirs' do
            expect(described_class.new('a/**/b').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b\z}i, true)
          end

          it 'matches multiple intermediate dirs when ***' do
            expect(described_class.new('a/***/b').build)
              .to eq PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b\z}i, true)
          end
        end

        describe 'Other consecutive asterisks are considered regular asterisks' do
          describe 'and will match according to the previous rules' do
            context 'with two stars' do
              it 'matches any number of characters at the beginning' do
                expect(described_class.new('**our').build)
                  .to eq PathList::Matchers::PathRegexp.new(/our\z/i, true)
              end

              it "doesn't match a slash" do
                expect(described_class.new('f**our').build)
                  .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our\z}i, true)
              end

              it 'matches any number of characters in the middle' do
                expect(described_class.new('f**r').build)
                  .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r\z}i, true)
              end

              it 'matches any number of characters at the end' do
                expect(described_class.new('few**').build)
                  .to eq PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few}i, true)
              end

              # not sure if this is a bug but this is git behaviour
              it 'matches any number of directories including none, when following a character, and anchors' do
                expect(described_class.new('f**/our').build)
                  .to eq PathList::Matchers::PathRegexp.new(%r{\Af(?:.*/)?our\z}i, true)
              end
            end
          end
        end
      end
    end
  end

  describe '#build_implicit' do
    describe 'from the gitignore documentation' do
      describe 'A blank line matches no files, so it can serve as a separator for readability.' do
        it { expect(described_class.new('').build_implicit).to eq PathList::Matchers::Blank }
        it { expect(described_class.new(' ').build_implicit).to eq PathList::Matchers::Blank }
        it { expect(described_class.new("\t").build_implicit).to eq PathList::Matchers::Blank }
      end

      describe 'A line starting with # serves as a comment.' do
        it { expect(described_class.new('#foo').build_implicit).to eq PathList::Matchers::Blank }
        it { expect(described_class.new('# foo').build_implicit).to eq PathList::Matchers::Blank }
        it { expect(described_class.new('#').build_implicit).to eq PathList::Matchers::Blank }

        it 'must be the first character' do
          expect(described_class.new(' #foo').build_implicit)
            .to eq PathList::Matchers::Any.new(
              [
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\ \#foo\/}i, true)
              ]
            )
        end

        describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
          it do
            expect(described_class.new('\\#foo').build_implicit)
              .to eq PathList::Matchers::Any.new(
                [
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\#foo\/}i, true)
                ]
              )
          end
        end
      end

      describe 'literal backslashes in filenames' do
        it 'matches an escaped backslash at the end of the pattern' do
          expect(described_class.new('foo\\\\').build_implicit)
            .to eq PathList::Matchers::Any.new([
              PathList::Matchers::AllowAnyDir,
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\\\/}i, true)
            ])
        end

        it 'never matches a literal backslash at the end of the pattern' do
          expect(described_class.new('foo\\').build_implicit)
            .to eq PathList::Matchers::Invalid
        end

        it 'matches an escaped backslash at the start of the pattern' do
          expect(described_class.new('\\\\foo').build_implicit)
            .to eq PathList::Matchers::Any.new([
              PathList::Matchers::AllowAnyDir,
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\\foo\/}i, true)
            ])
        end

        it 'matches a literal escaped f at the start of the pattern' do
          expect(described_class.new('\\foo').build_implicit)
            .to eq PathList::Matchers::Any.new([
              PathList::Matchers::AllowAnyDir,
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\/}i, true)
            ])
        end
      end

      describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
        it 'ignores trailing spaces in the gitignore file' do
          expect(described_class.new('foo  ').build_implicit)
            .to eq PathList::Matchers::Any.new([
              PathList::Matchers::AllowAnyDir,
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\/}i, true)
            ])
        end

        it "doesn't ignore trailing spaces if there's a backslash" do
          expect(described_class.new('foo \\ ').build_implicit)
            .to eq PathList::Matchers::Any.new([
              PathList::Matchers::AllowAnyDir,
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ \/}i, true)
            ])
        end

        it 'considers trailing backslashes to never be matched' do
          expect(described_class.new('foo\\').build_implicit)
            .to eq PathList::Matchers::Invalid
        end

        it "doesn't ignore trailing spaces if there's a backslash before every space" do
          expect(described_class.new('foo\\ \\ ').build_implicit)
            .to eq PathList::Matchers::Any.new([
              PathList::Matchers::AllowAnyDir,
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ \/}i, true)
            ])
        end

        it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
          expect(described_class.new('foo\\  ').build_implicit)
            .to eq PathList::Matchers::Any.new([
              PathList::Matchers::AllowAnyDir,
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \/}i, true)
            ])
        end
      end

      describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
        describe 'but it would only find a match with a directory' do
          # In other words, foo/ will match a directory foo and paths underneath it,
          # but will not match a regular file or a symbolic link foo
          # (this is consistent with the way how pathspec works in general in Git).

          it 'ignores directories but not files or symbolic links that match patterns ending with /' do
            expect(described_class.new('foo/').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\/}i, true)
              ])
          end

          it 'handles this specific edge case i stumbled across' do
            expect(described_class.new('Ȋ/').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)Ȋ\/}i, true)
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
            expect(described_class.new('doc/frotz').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(/\Adoc\z/i, true)),
                PathList::Matchers::PathRegexp.new(%r{\Adoc/frotz/}i, true)
              ])
          end

          it 'treats a double slash as matching nothing' do
            expect(described_class.new('doc//frotz').build_implicit)
              .to eq PathList::Matchers::Invalid
          end
        end

        describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
          # frotz/ matches frotz and a/frotz that is a directory

          it 'includes files relative to anywhere with only an end slash' do
            expect(described_class.new('frotz/').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz\/}i, true)
              ])
          end

          it 'strips trailing space before deciding a rule is dir_only' do
            expect(described_class.new('frotz/ ').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz\/}i, true)
              ])
          end
        end
      end

      describe 'An optional prefix "!" which negates the pattern' do
        describe 'any matching file excluded by a previous pattern will become included again.' do
          it 'includes previously excluded files' do
            expect(described_class.new('!foo').build_implicit)
              .to eq PathList::Matchers::Blank
          end
        end

        describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
          # for example, "\!important!.txt".'

          it 'matches files starting with a literal ! if its preceded by a backslash' do
            expect(described_class.new('\!important!.txt').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)!important!\.txt\/}i, true)
              ])
          end
        end
      end

      describe 'Otherwise, Git treats the pattern as a shell glob' do
        describe '"*" matches anything except "/"' do
          describe 'single level' do
            it "matches any number of characters at the beginning if there's a star" do
              expect(described_class.new('*our').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{our/}i, true)
                ])
            end

            it "matches any number of characters at the beginning if there's a star followed by a slash" do
              expect(described_class.new('*/our').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\A[^/]*\z}i, true)),
                  PathList::Matchers::PathRegexp.new(%r{\A[^/]*/our\/}i, true)
                ])
            end

            it "doesn't match a slash" do
              expect(described_class.new('f*our').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our\/}i, true)
                ])
            end

            it "matches any number of characters in the middle if there's a star" do
              expect(described_class.new('f*r').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r\/}i, true)
                ])
            end

            it "matches any number of characters at the end if there's a star" do
              expect(described_class.new('few*').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few[^\/]*\/}i, true)
                ])
            end
          end

          describe 'multi level' do
            it 'matches a whole directory' do
              expect(described_class.new('a/*/c').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/[^/]*[^/]\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/c\/}i, true)
                ])
            end

            it 'matches an exact partial match at start' do
              expect(described_class.new('a/b*/c').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/b[^/]*\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aa/b[^/]*/c\/}i, true)
                ])
            end

            it 'matches an exact partial match at end' do
              expect(described_class.new('a/*b/c').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/[^/]*b\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*b/c\/}i, true)
                ])
            end

            it 'matches multiple directories when sequential /*/' do
              expect(described_class.new('a/*/*').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/[^/]*[^/]\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/[^/]*[^/]\/}i, true)
                ])
            end

            it 'matches multiple directories when beginning sequential /*/' do
              expect(described_class.new('*/*/c').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A[^/]*(?:\z|/[^/]*[^/]\z)}i, true)
                  ), PathList::Matchers::PathRegexp.new(%r{\A[^/]*/[^/]*/c\/}i, true)
                ])
            end

            it 'matches multiple directories when ending with /**/*' do
              expect(described_class.new('a/**/*').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:/|\z)}i, true)
                  ), PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?[^/]*[^/]\/}i, true)
                ])
            end

            it 'matches multiple directories when ending with **/*' do
              expect(described_class.new('a**/*').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa[^/]*\z}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aa(?:.*/)?[^/]*[^/]\/}i, true)
                ])
            end

            it 'matches multiple directories when beginning with **/*/' do
              expect(described_class.new('**/*/c').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{/c\/}i, true)
                ])
            end

            it 'matches multiple directories when beginning with **/*' do
              expect(described_class.new('**/*c').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{c/}i, true)
                ])
            end
          end
        end

        describe '"?" matches any one character except "/"' do
          it "matches one character at the beginning if there's a ?" do
            expect(described_class.new('?our').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)[^/]our\/}i, true)
              ])
          end

          it "doesn't match a slash" do
            expect(described_class.new('fa?our').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fa[^/]our\/}i, true)
              ])
          end

          it 'matches per ?' do
            expect(described_class.new('f??r').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/][^/]r\/}i, true)
              ])
          end

          it "matches a single character at the end if there's a ?" do
            expect(described_class.new('fou?').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fou[^/]\/}i, true)
              ])
          end
        end

        describe '"[]" matches one character in a selected range' do
          it 'matches a single character in a character class' do
            expect(described_class.new('a[ab]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ab]\/}i, true)
              ])
          end

          it 'matches a single character in a character class range' do
            expect(described_class.new('a[a-c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]\/}i, true)
              ])
          end

          it 'treats a backward character class range as only the first character of the range' do
            expect(described_class.new('a[d-a]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]\/}i, true)
              ])
          end

          it 'treats a negated backward character class range as only the first character of the range' do
            expect(described_class.new('a[^d-a]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]\/}i, true)
              ])
          end

          it 'treats a escaped backward character class range as only the first character of the range' do
            expect(described_class.new('a[\\]-\\[]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\]]\/}i, true)
              ])
          end

          it 'treats a negated escaped backward character class range as only the first character of the range' do
            expect(described_class.new('a[^\\]-\\[]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\]]\/}i, true)
              ])
          end

          it 'treats a escaped character class range as as a range' do
            expect(described_class.new('a[\\[-\\]]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[-\]]\/}i, true)
              ])
          end

          it 'treats a negated escaped character class range as a range' do
            expect(described_class.new('a[^\\[-\\]]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\[-\]]\/}i, true)
              ])
          end

          it 'treats an unnecessarily escaped character class range as a range' do
            expect(described_class.new('a[\\a-\\c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]\/}i, true)
              ])
          end

          it 'treats a negated unnecessarily escaped character class range as a range' do
            expect(described_class.new('a[^\\a-\\c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\/}i, true)
              ])
          end

          it 'treats a backward character class range with other options as only the first character of the range' do
            expect(described_class.new('a[d-ba]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[da]\/}i, true)
              ])
          end

          it 'treats a negated backward character class range with other options as the first character of the range' do
            expect(described_class.new('a[^d-ba]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^da]\/}i, true)
              ])
          end

          it 'treats a backward char class range with other initial options as the first char of the range' do
            expect(described_class.new('a[ad-b]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ad]\/}i, true)
              ])
          end

          it 'treats a negated backward char class range with other initial options as the first char of the range' do
            expect(described_class.new('a[^ad-b]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^ad]\/}i, true)
              ])
          end

          it 'treats a equal character class range as only the first character of the range' do
            expect(described_class.new('a[d-d]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]\/}i, true)
              ])
          end

          it 'treats a negated equal character class range as only the first character of the range' do
            expect(described_class.new('a[^d-d]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]\/}i, true)
              ])
          end

          it 'interprets a / after a character class range as not there' do
            expect(described_class.new('a[a-c/]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c/]\/}i, true)
              ])
          end

          it 'interprets a / before a character class range as not there' do
            expect(described_class.new('a[/a-c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/a-c]\/}i, true)
              ])
          end

          # TODO: confirm if that matches a slash character
          it 'interprets a / before the dash in a character class range as any character from / to c' do
            expect(described_class.new('a[+/-c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\+/-c]\/}i, true)
              ])
          end

          it 'interprets a / after the dash in a character class range as any character from start to /' do
            expect(described_class.new('a["-/c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/c]\/}i, true)
              ])
          end

          it 'interprets a slash then dash then character to be a character range' do
            expect(described_class.new('a[/-c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/-c]\/}i, true)
              ])
          end

          it 'interprets a character then dash then slash to be a character range' do
            expect(described_class.new('a["-/]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/]\/}i, true)
              ])
          end

          context 'without raising warnings' do
            # these edge cases raise warnings
            # they're edge-casey enough if you hit them you deserve warnings.
            before { allow(Warning).to receive(:warn) }

            it 'interprets dash dash character as a character range beginning with -' do
              expect(described_class.new('a[--c]').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\--c]\/}i, true)
                ])
            end

            it 'interprets character dash dash as a character range ending with -' do
              expect(described_class.new('a["--]').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-]\/}i, true)
                ])
            end

            it 'interprets dash dash dash as a character range of only with -' do
              expect(described_class.new('a[---]').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-]\/}i, true)
                ])
            end

            it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
              expect(described_class.new('a["---]').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(
                    Regexp.new('(?:\\A|\\/)a(?!\\/)["-\\-\\-]\\/', 1), true
                  )
                ])
            end

            it 'interprets dash dash dash character as a character range of only - with literal c' do
              expect(described_class.new('a[---c]').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-c]\/}i, true)
                ])
            end

            it 'interprets character dash dash character as a character range ending with - and a literal c' do
              # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
              # but ruby regex and git seem to treat this edge case the same
              expect(described_class.new('a["--c]').build_implicit)
                .to eq PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-c]\/}i, true)
                ])
            end
          end

          it '^ is not' do
            expect(described_class.new('a[^a-c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\/}i, true)
              ])
          end

          # this doesn't appear to be documented anywhere i just stumbled onto it
          it '! is also not' do
            expect(described_class.new('a[!a-c]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\/}i, true)
              ])
          end

          it '[^/] matches everything' do
            expect(described_class.new('a[^/]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/]\/}i, true)
              ])
          end

          it '[^^] matches everything except literal ^' do
            expect(described_class.new('a[^^]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\^]\/}i, true)
              ])
          end

          it '[^/a] matches everything except a' do
            expect(described_class.new('a[^/a]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/a]\/}i, true)
              ])
          end

          it '[/^a] matches literal ^ and a' do
            expect(described_class.new('a[/^a]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^a]\/}i, true)
              ])
          end

          it '[/^] matches literal ^' do
            expect(described_class.new('a[/^]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^]\/}i, true)
              ])
          end

          it '[\\^] matches literal ^' do
            expect(described_class.new('a[\^]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\^]\/}i, true)
              ])
          end

          it 'later ^ is literal' do
            expect(described_class.new('a[a-c^]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c\^]\/}i, true)
              ])
          end

          it "doesn't match a slash even if you specify it last" do
            expect(described_class.new('b[i/]b').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/]b\/}i, true)
              ])
          end

          it "doesn't match a slash even if you specify it alone" do
            expect(described_class.new('b[/]b').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/]b\/}i, true)
              ])
          end

          it 'empty class matches nothing' do
            expect(described_class.new('b[]b').build_implicit)
              .to eq PathList::Matchers::Invalid
          end

          it "doesn't match a slash even if you specify it middle" do
            expect(described_class.new('b[i/a]b').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/a]b\/}i, true)
              ])
          end

          it "doesn't match a slash even if you specify it start" do
            expect(described_class.new('b[/ai]b').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/ai]b\/}i, true)
              ])
          end

          it 'assumes an unfinished [ matches nothing' do
            expect(described_class.new('a[').build_implicit)
              .to eq PathList::Matchers::Invalid
          end

          it 'assumes an unfinished [ followed by \ matches nothing' do
            expect(described_class.new('a[\\').build_implicit)
              .to eq PathList::Matchers::Invalid
          end

          it 'assumes an escaped [ is literal' do
            expect(described_class.new('a\\[').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\[\/}i, true)
              ])
          end

          it 'assumes an escaped [ is literal inside a group' do
            expect(described_class.new('a[\\[]').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[]\/}i, true)
              ])
          end

          it 'assumes an unfinished [ matches nothing when negated' do
            expect(described_class.new('!a[').build_implicit)
              .to eq PathList::Matchers::Invalid
          end

          it 'assumes an unfinished [bc matches nothing' do
            expect(described_class.new('a[bc').build_implicit)
              .to eq PathList::Matchers::Invalid
          end
        end

        # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
      end

      describe 'A leading slash matches the beginning of the pathname.' do
        # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
        it 'matches only at the beginning of everything' do
          expect(described_class.new('/*.c').build_implicit)
            .to eq PathList::Matchers::PathRegexp.new(%r{\A[^/]*\.c\/}i, true)
        end
      end

      describe 'Two consecutive asterisks ("**") in patterns matched against full pathname may have special meaning:' do
        describe 'A leading "**" followed by a slash means match in all directories.' do
          # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
          # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

          it 'matches files or directories in all directories' do
            expect(described_class.new('**/foo').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\/}i, true)
              ])
          end

          it 'matches nothing with double slash' do
            expect(described_class.new('**//foo').build_implicit)
              .to eq PathList::Matchers::Invalid
          end

          it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
            expect(described_class.new('**/').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{/}i, true)
              ])
          end

          it 'matches files or directories in all directories when repeated' do
            expect(described_class.new('**/**/foo').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\/}i, true)
              ])
          end

          it 'matches files or directories in all directories with **/*' do
            expect(described_class.new('**/*').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{[^/]\/}i, true)
              ])
          end

          it 'matches files or directories in all directories when also followed by a star before text' do
            expect(described_class.new('**/*foo').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{foo/}i, true)
              ])
          end

          it 'matches files or directories in all directories when also followed by a star within text' do
            expect(described_class.new('**/f*o').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*o\/}i, true)
              ])
          end

          it 'matches files or directories in all directories when also followed by a star after text' do
            expect(described_class.new('**/fo*').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fo[^\/]*\/}i, true)
              ])
          end

          it 'matches files or directories in all directories when three stars' do
            expect(described_class.new('***/foo').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\/}i, true)
              ])
          end
        end

        describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
          it 'matches files or directories inside the mentioned directory' do
            expect(described_class.new('abc/**').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(/\Aabc\z/i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true)
              ])
          end

          it 'matches all directories inside the mentioned directory' do
            expect(described_class.new('abc/**/').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(/\Aabc\z/i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\Aabc\/[^\/]*[^\/]\/}i, true)
              ])
          end

          it 'matches files or directories inside the mentioned directory when ***' do
            expect(described_class.new('abc/***').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(/\Aabc\z/i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true)
              ])
          end
        end

        describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
          it 'matches multiple intermediate dirs' do
            expect(described_class.new('a/**/b').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\Aa(?:/|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b\/}i, true)
              ])
          end

          it 'matches multiple intermediate dirs when ***' do
            expect(described_class.new('a/***/b').build_implicit)
              .to eq PathList::Matchers::Any.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\Aa(?:/|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b\/}i, true)
              ])
          end
        end

        describe 'Other consecutive asterisks are considered regular asterisks' do
          describe 'and will match according to the previous rules' do
            context 'with two stars' do
              it 'matches any number of characters at the beginning' do
                expect(described_class.new('**our').build_implicit)
                  .to eq PathList::Matchers::Any.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{our/}i, true)
                  ])
              end

              it "doesn't match a slash" do
                expect(described_class.new('f**our').build_implicit)
                  .to eq PathList::Matchers::Any.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our\/}i, true)
                  ])
              end

              it 'matches any number of characters in the middle' do
                expect(described_class.new('f**r').build_implicit)
                  .to eq PathList::Matchers::Any.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r\/}i, true)
                  ])
              end

              it 'matches any number of characters at the end' do
                # TODO: the child pattern for this is is incorrect
                expect(described_class.new('few**').build_implicit)
                  .to eq PathList::Matchers::Any.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few\/}i, true)
                  ])
              end

              # not sure if this is a bug but this is git behaviour
              it 'matches any number of directories including none, when following a character, and anchors' do
                # TODO: the parent pattern for this is incorrect
                expect(described_class.new('f**/our').build_implicit)
                  .to eq PathList::Matchers::Any.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\Af[^/]*\z}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\Af(?:.*/)?our\/}i, true)
                  ])
              end
            end
          end
        end
      end
    end
  end
end

# rubocop:enable Style/RedundantRegexpEscape, Style/RedundantRegexpCharacterClass
