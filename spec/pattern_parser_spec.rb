# frozen_string_literal: true

RSpec.describe PathList::PatternParser do
  subject(:matchers) do
    described_class.build(
      patterns: patterns_arg,
      patterns_from_file: patterns_from_file,
      format: format_arg,
      root: root,
      polarity: polarity
    )
  end

  let(:patterns) { [] }
  let(:patterns_arg) { patterns_from_file ? [] : Array(patterns) }
  let(:patterns_from_file) { nil }
  let(:format_arg) { nil }
  let(:root) { nil }
  let(:polarity) { :ignore }

  before do
    allow(PathList::CanonicalPath).to receive(:case_insensitive?).and_return(false)
    stub_file patterns.join("\n"), patterns_from_file if patterns_from_file
  end

  around do |e|
    if patterns_from_file
      within_temp_dir { e.run }
    else
      e.run
    end
  end

  describe 'with blank patterns' do
    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'matches everything' do
        expect(matchers).to be_like PathList::Matcher::Allow
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'matches everything' do
        expect(matchers).to be_like PathList::Matcher::Allow
      end
    end
  end

  context 'with patterns: "a", root: "/"' do
    let(:patterns) { 'a' }
    let(:root) { '/' }

    if windows?
      context 'when ignore' do
        let(:polarity) { :ignore }

        it 'ignores a' do
          expect(matchers).to be_like PathList::Matcher::LastMatch::Two.new([
            PathList::Matcher::Allow,
            PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}(?:.*/)?a\z}o, :ignore)
          ])
        end
      end

      context 'when allow' do
        let(:polarity) { :allow }

        it 'allows a, and implicitly any parents and children of a' do
          expect(matchers).to be_like PathList::Matcher::LastMatch.new([
            PathList::Matcher::Ignore,
            PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}(?:.*/)?a(?:\z|/)}o, :allow),
            PathList::Matcher::MatchIfDir.new(
              PathList::Matcher::Any::Two.new([
                PathList::Matcher::ExactString.new(FSROOT, :allow),
                PathList::Matcher::PathRegexp.new(/\A#{FSROOT}/o, :allow)
              ])
            )
          ])
        end
      end
    else
      context 'when ignore' do
        let(:polarity) { :ignore }

        it 'ignores a' do
          expect(matchers).to be_like PathList::Matcher::LastMatch::Two.new([
            PathList::Matcher::Allow,
            PathList::Matcher::PathRegexp.new(%r{/a\z}, :ignore)
          ])
        end
      end

      context 'when allow' do
        let(:polarity) { :allow }

        it 'allows a, and implicitly any parents and children of a' do
          expect(matchers).to be_like PathList::Matcher::LastMatch.new([
            PathList::Matcher::Ignore,
            PathList::Matcher::PathRegexp.new(%r{/a(?:\z|/)}, :allow),
            PathList::Matcher::AllowAnyDir
          ])
        end
      end
    end
  end

  context 'with patterns: "a", root: "/b"' do
    let(:patterns) { 'a' }
    let(:root) { '/b' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'ignores a' do
        expect(matchers).to be_like PathList::Matcher::LastMatch::Two.new([
          PathList::Matcher::Allow,
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}b/(?:.*/)?a\z}o, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'allows a, and implicitly any children of a' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Ignore,
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}b/(?:.*/)?a(?:\z|/)}o, :allow),
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::Any::Two.new([
              PathList::Matcher::ExactString::Set.new([FSROOT, "#{FSROOT}b"], :allow),
              PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}b/}o, :allow)
            ])
          )
        ])
      end
    end
  end

  context 'with patterns: ["a[b]", "a[^c]"], root: "/"' do
    let(:patterns) { ['a[b]', 'a[^c]'] }
    let(:root) { '/' }

    if windows?
      context 'when ignore' do
        let(:polarity) { :ignore }

        it "doesn't merge the character classes" do
          expect(matchers).to be_like PathList::Matcher::LastMatch::Two.new([
            PathList::Matcher::Allow,
            PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}(?:.*/)?a(?:(?!/)[b]\z|(?!/)[^c]\z)}o, :ignore)
          ])
        end
      end

      context 'when allow' do
        let(:polarity) { :allow }

        it "doesn't merge the character classes" do
          expect(matchers).to be_like PathList::Matcher::LastMatch.new([
            PathList::Matcher::Ignore,
            PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}(?:.*/)?a(?:(?!/)[b](?:\z|/)|(?!/)[^c](?:\z|/))}o, :allow),
            PathList::Matcher::MatchIfDir.new(
              PathList::Matcher::Any::Two.new([
                PathList::Matcher::ExactString.new(FSROOT, :allow),
                PathList::Matcher::PathRegexp.new(/\A#{FSROOT}/o, :allow)
              ])
            )
          ])
        end
      end
    else
      context 'when ignore' do
        let(:polarity) { :ignore }

        it "doesn't merge the character classes" do
          expect(matchers).to be_like PathList::Matcher::LastMatch::Two.new([
            PathList::Matcher::Allow,
            PathList::Matcher::PathRegexp.new(%r{/a(?:(?!/)[b]\z|(?!/)[^c]\z)}, :ignore)
          ])
        end
      end

      context 'when allow' do
        let(:polarity) { :allow }

        it "doesn't merge the character classes" do
          expect(matchers).to be_like PathList::Matcher::LastMatch.new([
            PathList::Matcher::Ignore,
            PathList::Matcher::PathRegexp.new(%r{/a(?:(?!/)[b](?:\z|/)|(?!/)[^c](?:\z|/))}, :allow),
            PathList::Matcher::AllowAnyDir
          ])
        end
      end
    end
  end

  context 'with patterns: ["*", "!./d", "!/a/b/c/baz"], root: "/a/b/c", format: :glob_gitignore' do
    let(:patterns) { ['*', '!./foo', '!/a/b/c/baz'] }
    let(:root) { '/a/b/c' }
    let(:format_arg) { :glob_gitignore }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Allow,
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}a/b/c/}o, :ignore),
          PathList::Matcher::ExactString::Set.new([
            "#{FSROOT}a/b/c/baz",
            "#{FSROOT}a/b/c/foo"
          ], :allow)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Ignore,
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}a/b/c/}o, :allow),
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::Any::Two.new([
              PathList::Matcher::ExactString::Set.new([FSROOT, "#{FSROOT}a", "#{FSROOT}a/b", "#{FSROOT}a/b/c"], :allow),
              PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}a/b/c/}o, :allow)
            ])
          ),
          PathList::Matcher::ExactString::Set.new([
            "#{FSROOT}a/b/c/baz",
            "#{FSROOT}a/b/c/foo"
          ], :ignore)
        ])
      end
    end
  end

  context 'with patterns: ["a*", "/bb*", "ddd*", "/bbbb*", "!c/d*", "**/eeeee*", "# comment"], root: "/f/g"' do
    let(:patterns) { ['a*', '/bb*', 'ddd*', '/bbbb*', '!c/d*', '**/eeeee*', '# comment'] }
    let(:root) { '/f/g/' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Allow,
          PathList::Matcher::PathRegexp.new(
            %r{\A#{FSROOT}f/g/(?:bb[^/]*\z|bbbb[^/]*\z|(?:.*/)?(?:a[^/]*\z|ddd[^/]*\z))}o,
            :ignore
          ),
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}f/g/c/d[^\/]*\z}o, :allow),
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}f/g/(?:.*/)?eeeee[^\/]*\z}o, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Ignore,
          PathList::Matcher::PathRegexp.new(
            %r{\A#{FSROOT}f/g/(?:bb[^/]*(?:\z|/)|bbbb[^/]*(?:\z|/)|(?:.*/)?(?:a[^/]*(?:\z|/)|ddd[^/]*(?:\z|/)|eeeee[^/]*/))}o, # rubocop:disable Layout/LineLength
            :allow
          ),
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::Any::Two.new([
              PathList::Matcher::ExactString::Set.new([FSROOT, "#{FSROOT}f", "#{FSROOT}f/g"], :allow),
              PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}f/g/}o, :allow)
            ])
          ),
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}f/g/c/d[^\/]*\z}o, :ignore),
          PathList::Matcher::PathRegexp.new(%r{\A#{FSROOT}f/g/(?:.*/)?eeeee[^\/]*\z}o, :allow)
        ])
      end
    end
  end
end
