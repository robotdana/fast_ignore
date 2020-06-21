# frozen_string_literal: true

RSpec.describe FastIgnore do
  around { |e| within_temp_dir { e.run } }

  let(:root) { Dir.pwd }

  shared_examples 'the include documentation' do
    describe 'A blank line matches no files, so it can serve as a separator for readability.' do
      before { create_file_list 'foo', 'bar', 'baz' }

      it 'includes everything when the includes file is empty' do
        includefile ''

        expect(subject).to allow_files('foo', 'bar', 'baz')
      end

      it 'includes everything when the includes file only contains newlines' do
        includefile <<~FILE


        FILE

        expect(subject).to allow_files('foo', 'bar', 'baz')
      end

      it 'includes mentioned files when include file includes newlines' do
        includefile <<~FILE

          foo
          bar

        FILE

        expect(subject).to disallow('baz').and(allow_files('foo', 'bar'))
      end
    end

    describe 'A line starting with # serves as a comment.' do
      before { create_file_list '#foo', 'foo' }

      it "doesn't include files whose names look like a comment" do
        includefile <<~FILE
          #foo
          foo
        FILE

        expect(subject).to disallow('#foo').and(allow_files('foo'))
      end

      describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
        it 'includes files whose names look like a comment when prefixed with a backslash' do
          includefile <<~FILE
            \\#foo
          FILE

          expect(subject).to disallow('foo').and(allow_files('#foo'))
        end
      end
    end

    describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
      before { create_file_list 'foo', 'foo ', 'foo  ' }

      it 'ignores trailing spaces in the includes file' do
        includefile 'foo  '

        expect(subject).to disallow('foo  ', 'foo ').and(allow_files('foo'))
      end

      it "doesn't ignore trailing spaces if there's a backslash" do
        includefile "foo \\ \n"

        expect(subject).to disallow('foo', 'foo ').and(allow_files('foo  '))
      end

      it "doesn't ignore trailing spaces if there's a backslash before every space" do
        includefile "foo\\ \\ \n"

        expect(subject).to disallow('foo', 'foo ').and(allow_files('foo  '))
      end
    end

    describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
      describe 'but it would only find a match with a directory' do
        # In other words, foo/ will match a directory foo and paths underneath it,
        # but will not match a regular file or a symbolic link foo
        # (this is consistent with the way how pathspec works in general in Git).

        before { create_file_list 'bar/foo', 'foo/bar' }

        it 'includes directories but not files that match patterns ending with /' do
          includefile <<~FILE
            foo/
          FILE

          expect(subject).to disallow('bar/foo').and(allow_files('foo/bar'))
        end
      end
    end

    describe 'An optional prefix "!" which negates the pattern' do
      describe 'any matching file excluded by a previous pattern will become ignored again.' do
        before { create_file_list 'foo', 'foe' }

        it 'ignore previously included files' do
          includefile <<~FILE
            fo*
            !foo
          FILE

          expect(subject).to disallow('foo').and(allow_files('foe'))
        end

        it 'is read in order' do
          includefile <<~FILE
            !foo
            fo*
          FILE

          expect(subject).to allow_files('foe', 'foo')
        end

        it 'has no effect if not negating anything' do
          includefile <<~FILE
            !foo
          FILE
          expect(subject).to disallow('foe', 'foo')
        end
      end

      describe 'It is possible to re-ignore a file if a parent directory of that file is included' do
        before { create_file_list 'foo/bar', 'foo/foo', 'bar/bar' }

        it 'ignores files inside previously included directories' do
          includefile <<~FILE
            foo
            !foo/bar
          FILE

          expect(subject).to disallow('bar/bar', 'foo/bar').and(allow_files('foo/foo'))
        end
      end

      describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
        # for example, "\!important!.txt".'

        before { create_file_list '!important!.txt', 'important!.txt' }

        it 'matches files starting with a literal ! if its preceded by a backslash' do
          includefile <<~FILE
            \\!important!.txt
          FILE

          expect(subject).to disallow('important!.txt').and(allow_files('!important!.txt'))
        end
      end
    end

    describe 'Otherwise, Git treats the pattern as a shell glob' do
      describe '"*" matches anything except "/"' do
        before { create_file_list 'f/our', 'few', 'four', 'fewer', 'favour' }

        it "matches any number of characters at the beginning if there's a star" do
          includefile <<~FILE
            *our
          FILE

          expect(subject).to disallow('few', 'fewer').and(allow_files('f/our', 'four', 'favour'))
        end

        it "doesn't match a slash" do
          includefile <<~FILE
            f*our
          FILE

          expect(subject).to disallow('few', 'fewer', 'f/our').and(allow_files('four', 'favour'))
        end

        it "matches any number of characters at the beginning if there's a star followed by a slash" do
          includefile <<~FILE
            */our
          FILE

          expect(subject).to disallow('few', 'fewer', 'four', 'favour').and(allow_files('f/our'))
        end

        it "matches any number of characters in the middle if there's a star" do
          includefile <<~FILE
            f*r
          FILE

          expect(subject).to disallow('f/our', 'few').and(allow_files('four', 'fewer', 'favour'))
        end

        it "matches any number of characters at the end if there's a star" do
          includefile <<~FILE
            few*
          FILE

          expect(subject).to disallow('f/our', 'four', 'favour').and(allow_files('few', 'fewer'))
        end
      end

      describe '"?" matches any one character except "/"' do
        before { create_file_list 'four', 'fouled', 'fear', 'tour', 'flour', 'favour', 'fa/our', 'foul' }

        it "matches any number of characters at the beginning if there's a star" do
          includefile <<~FILE
            ?our
          FILE

          expect(subject).to disallow('fouled', 'fear', 'favour', 'fa/our', 'foul').and(allow_files('tour', 'four'))
        end

        it "doesn't match a slash" do
          includefile <<~FILE
            fa?our
          FILE

          expect(subject).to disallow('fouled', 'fear', 'tour', 'four', 'fa/our', 'foul').and(allow_files('favour'))
        end

        it "matches any number of characters in the middle if there's a star" do
          includefile <<~FILE
            f??r
          FILE

          expect(subject).to disallow('fouled', 'tour', 'favour', 'fa/our', 'foul').and(allow_files('four', 'fear'))
        end

        it "matches a single number of characters at the end if there's a ?" do
          includefile <<~FILE
            fou?
          FILE

          expect(subject).to disallow('fouled', 'fear', 'tour', 'favour', 'fa/our').and(allow_files('foul', 'four'))
        end
      end

      describe '"[]" matches one character in a selected range' do
        before { create_file_list 'aa', 'ab', 'ac', 'ad', 'bib', 'b/b', 'bab', 'a[', 'bb', 'a^', 'a[bc' }

        it 'matches a single character in a character class' do
          includefile <<~FILE
            a[ab]
          FILE

          expect(subject).to disallow('ac').and(allow_files('ab', 'aa'))
        end

        it 'matches a single character in a character class range' do
          includefile <<~FILE
            a[a-c]
          FILE

          expect(subject).to disallow('ad').and(allow_files('ab', 'aa', 'ac'))
        end

        it '^ is not' do
          includefile <<~FILE
            a[^a-c]
          FILE

          expect(subject).to allow_files('ad').and(disallow('ab', 'aa', 'ac'))
        end

        it '[^/] matches everything' do
          includefile <<~FILE
            a[^/]
          FILE

          expect(subject).to allow_files('aa', 'ab', 'ac', 'ad', 'a^')
        end

        it '[^^] matches everything except literal ^' do
          includefile <<~FILE
            a[^^]
          FILE

          expect(subject).to allow_files('aa', 'ab', 'ac', 'ad').and(disallow('a^'))
        end

        it '[^/a] matches everything except a' do
          includefile <<~FILE
            a[^/a]
          FILE

          expect(subject).to allow_files('ab', 'ac', 'ad', 'a^').and(disallow('aa'))
        end

        it '[/^a] matches literal ^ and a' do
          includefile <<~FILE
            a[/^a]
          FILE

          expect(subject).to disallow('ab', 'ac', 'ad').and(allow_files('aa', 'a^'))
        end

        it '[/^] matches literal ^' do
          includefile <<~FILE
            a[/^]
          FILE

          expect(subject).to allow_files('a^').and(disallow('aa', 'ab', 'ac', 'ad'))
        end

        it 'later ^ is literal' do
          includefile <<~FILE
            a[a-c^]
          FILE

          expect(subject).to disallow('ad').and(allow_files('ab', 'aa', 'ac', 'a^'))
        end

        it "doesn't match a slash even if you specify it last" do
          includefile <<~FILE
            b[i/]b
          FILE

          expect(subject).to disallow('b/b').and(allow_files('bib'))
        end

        it "doesn't match a slash even if you specify it alone" do
          includefile <<~FILE
            b[/]b
          FILE

          expect(subject).to disallow('b/b', 'bb')
        end

        it 'empty class matches nothing' do
          includefile <<~FILE
            b[]b
          FILE

          expect(subject).to disallow('b/b', 'bb')
        end

        it "doesn't match a slash even if you specify it middle" do
          includefile <<~FILE
            b[i/a]b
          FILE

          expect(subject).to disallow('b/b').and(allow_files('bib', 'bab'))
        end

        it "doesn't match a slash even if you specify it start" do
          includefile <<~FILE
            b[/ai]b
          FILE

          expect(subject).to disallow('b/b').and(allow_files('bib', 'bab'))
        end

        it 'assumes an unfinished [ matches nothing' do
          includefile <<~FILE
            a[
          FILE

          expect(subject).to disallow('aa', 'ab', 'ac', 'bib', 'b/b', 'bab', 'a[')
        end

        it 'assumes an unfinished [bc matches nothing' do
          includefile <<~FILE
            a[bc
          FILE

          expect(subject).to disallow('aa', 'ab', 'ac', 'bib', 'b/b', 'bab', 'a[', 'a[bc')
        end
      end

      # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
    end

    describe 'A leading slash matches the beginning of the pathname.' do
      # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
      before { create_file_list 'cat-file.c', 'mozilla-sha1/sha1.c' }

      it 'matches only at the beginning of everything' do
        includefile <<~FILE
          /*.c
        FILE

        expect(subject).to disallow('mozilla-sha1/sha1.c').and(allow_files('cat-file.c'))
      end

      it 'matches only at the beginning of everything **' do
        includefile <<~FILE
          /**.c
        FILE

        expect(subject).to disallow('mozilla-sha1/sha1.c').and(allow_files('cat-file.c'))
      end
    end

    describe 'Two consecutive asterisks ("**") in patterns matched against full pathname may have special meaning:' do
      describe 'A leading "**" followed by a slash means match in all directories.' do
        # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
        # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'
        before { create_file_list 'foo', 'bar/foo', 'bar/bar/bar', 'bar/bar/foo/in_dir' }

        it 'matches files or directories in all directories' do
          includefile <<~FILE
            **/foo
          FILE

          expect(subject).to disallow('bar/bar/bar').and(allow_files('foo', 'bar/foo', 'bar/bar/foo/in_dir'))
        end

        it 'matches files or directories in all directories ***' do
          includefile <<~FILE
            ***/foo
          FILE

          expect(subject).to disallow('bar/bar/bar').and(allow_files('foo', 'bar/foo', 'bar/bar/foo/in_dir'))
        end
      end

      describe 'A trailing "/**" matches everything inside relative to the location of the .includes file.' do
        # For example, "abc/**" matches all files inside directory "abc",
        before { create_file_list 'abc/bar', 'abc/foo/bar', 'bar/abc/foo', 'bar/bar/foo' }

        it 'matches files or directories inside the mentioned directory' do
          includefile <<~FILE
            abc/**
          FILE

          expect(subject).to disallow('bar/bar/foo', 'bar/abc/foo').and(allow_files('abc/bar', 'abc/foo/bar'))
        end

        it 'matches files or directories inside the mentioned directory ***' do
          includefile <<~FILE
            abc/***
          FILE

          expect(subject).to disallow('bar/bar/foo', 'bar/abc/foo').and(allow_files('abc/bar', 'abc/foo/bar'))
        end

        context 'when the include file root is down a level from the pwd' do
          let(:include_rules) { '' }

          let(:args) { { include_files: File.join(root, 'bar', '.include') } }

          it 'matches files relative to the include file' do
            create_file 'bar/.include', <<~FILE
              abc/**
            FILE

            expect(subject).to disallow('bar/bar/foo', 'abc/bar', 'abc/foo/bar').and(allow_files('bar/abc/foo'))
          end

          it 'matches files relative to the include file ***' do
            create_file 'bar/.include', <<~FILE
              abc/***
            FILE

            expect(subject).to disallow('bar/bar/foo', 'abc/bar', 'abc/foo/bar').and(allow_files('bar/abc/foo'))
          end
        end
      end

      describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
        # For example, "a/**/b" matches "a/b", "a/x/b", "a/x/y/b" and so on.'
        before { create_file_list 'a/b', 'a/x/b', 'a/x/y/b', 'z/a/b', 'z/a/x/b', 'z/y' }

        it do
          includefile <<~FILE
            a/**/b
          FILE

          expect(subject).to disallow('z/y', 'z/a/b', 'z/a/x/b').and(allow_files('a/b', 'a/x/b', 'a/x/y/b'))
        end

        it '***' do
          includefile <<~FILE
            a/***/b
          FILE

          expect(subject).to disallow('z/y', 'z/a/b', 'z/a/x/b').and(allow_files('a/b', 'a/x/b', 'a/x/y/b'))
        end
      end

      describe 'Other consecutive asterisks are considered regular asterisks' do
        describe 'and will match according to the previous rules' do
          context 'with two stars' do
            before { create_file_list 'f/our', 'few', 'four', 'fewer', 'favour' }

            it 'matches any number of characters at the beginning' do
              includefile <<~FILE
                **our
              FILE

              expect(subject).to disallow('few', 'fewer').and(allow_files('f/our', 'four', 'favour'))
            end

            it "doesn't match a slash" do
              includefile <<~FILE
                f**our
              FILE

              expect(subject).to disallow('few', 'fewer', 'f/our').and(allow_files('four', 'favour'))
            end

            it 'matches any number of characters in the middle' do
              includefile <<~FILE
                f**r
              FILE

              expect(subject).to disallow('f/our', 'few').and(allow_files('four', 'fewer', 'favour'))
            end

            it 'matches any number of characters at the end' do
              includefile <<~FILE
                few**
              FILE

              expect(subject).to disallow('f/our', 'four', 'favour').and(allow_files('few', 'fewer'))
            end

            # not sure if this is a bug but this is git behaviour
            it 'matches any number of directories including none, when following a character' do
              includefile <<~FILE
                f**/our
              FILE

              expect(subject).to disallow('few', 'fewer', 'favour').and(allow_files('four', 'f/our'))
            end
          end
        end
      end

      it 'matches uppercase paths to lowercase patterns' do
        create_file_list 'FOO'
        includefile <<~FILE
          foo
        FILE

        expect(subject).to allow_files('FOO')
      end

      it 'matches lowercase paths to uppercase patterns' do
        create_file_list 'foo'
        includefile <<~FILE
          FOO
        FILE

        expect(subject).to allow_files('foo')
      end
    end
  end

  describe 'with include file' do
    subject do
      described_class.new(
        relative: true,
        gitignore: false,
        include_files: include_files,
        **args
      )
    end

    let(:include_files) { include_path }

    let(:args) { {} }
    let(:include_path) { File.join(root, '.include') }

    it_behaves_like 'the include documentation'

    describe 'with array argument' do
      let(:include_files) { [include_path, include_path] }

      it_behaves_like 'the include documentation'
    end

    describe 'with a root set' do
      subject do
        Dir.chdir File.join(root, '..') do
          described_class.new(
            relative: true,
            root: root,
            gitignore: false,
            include_files: include_path,
            **args
          )
        end
      end

      around do |example|
        Dir.mkdir 'sublevel'
        Dir.chdir 'sublevel' do
          example.run
        end
      end

      let(:root) { Dir.pwd }

      it_behaves_like 'the include documentation'
    end

    describe 'include_rules:' do
      subject do
        described_class.new(
          relative: true,
          gitignore: false,
          include_rules: include_rules,
          **args
        )
      end

      let(:include_read) { File.exist?(include_path) ? File.read(include_path) : '' }

      describe 'with string argument' do
        let(:include_rules) { include_read }

        it_behaves_like 'the include documentation'
      end

      describe 'with array argument' do
        let(:include_rules) { include_read.each_line.to_a }

        it_behaves_like 'the include documentation'
      end
    end
  end
end
