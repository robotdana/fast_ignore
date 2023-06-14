# frozen_string_literal: true

RSpec.describe ::PathList::Patterns do
  subject(:matchers) do
    described_class.new(
      *patterns_arg,
      from_file: from_file,
      format: format_arg,
      root: root,
      allow: allow_arg,
      label: label
    ).build
  end

  let(:patterns) { [] }
  let(:patterns_arg) { from_file ? [] : patterns }
  let(:from_file) { nil }
  let(:format_arg) { nil }
  let(:root) { nil }
  let(:allow_arg) { false }
  let(:label) { nil }

  around do |e|
    if from_file
      within_temp_dir { e.run }
    else
      e.run
    end
  end

  before do
    stub_file patterns.join("\n"), from_file if from_file
  end

  describe 'with blank patterns' do
    context 'when ignore' do
      let(:allow_arg) { false }

      it 'matches everything' do
        expect(matchers).to eq PathList::Matchers::Allow
      end
    end

    context 'when allow' do
      let(:allow_arg) { true }

      it 'matches everything' do
        expect(matchers).to eq PathList::Matchers::Allow
      end
    end
  end

  describe 'with some patterns' do
    let(:patterns) { 'a' }
    let(:root) { '/' }

    context 'when ignore' do
      let(:allow_arg) { false }

      it 'ignores a' do
        expect(matchers).to eq PathList::Matchers::LastMatch.new([
          PathList::Matchers::Allow,
          PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, false)
        ])
      end
    end

    context 'when allow' do
      let(:allow_arg) { true }

      it 'allows a, and implicitly any children of a' do
        expect(matchers).to eq PathList::Matchers::LastMatch.new([
          PathList::Matchers::Ignore,
          PathList::Matchers::Any.new([
            PathList::Matchers::AllowAnyDir,
            PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a/}i, false, true),
            PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, true)
          ])
        ])
      end
    end

    context 'with a root' do
      let(:root) { '/b' }

      context 'when ignore' do
        let(:allow_arg) { false }

        it 'ignores a' do
          expect(matchers).to eq PathList::Matchers::LastMatch.new([
            PathList::Matchers::Allow,
            PathList::Matchers::WithinDir.new(
              '/b/',
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, false)
            )
          ])
        end
      end

      context 'when allow' do
        let(:allow_arg) { true }

        it 'allows a, and implicitly any children of a' do
          expect(matchers).to eq PathList::Matchers::LastMatch.new([
            PathList::Matchers::Ignore,
            PathList::Matchers::Any.new([
              PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(/\Ab\z/i, true, true)
              ),
              PathList::Matchers::WithinDir.new(
                '/b/',
                PathList::Matchers::Any.new([
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, true),
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a/}i, false, true)
                ])
              )
            ])
          ])
        end
      end
    end

    # f38b597

    describe 'with glob format' do
      let(:patterns) { ['*', '!./foo', '!/a/b/c/baz'] }
      let(:root) { '/a/b/c' }
      let(:format_arg) { :glob }

      context 'when ignore' do
        let(:allow_arg) { false }

        it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
          expect(matchers).to eq PathList::Matchers::LastMatch.new([
            PathList::Matchers::Allow,
            PathList::Matchers::WithinDir.new(
              '/a/b/c/',
              PathList::Matchers::LastMatch.new([
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)[^/]*\z}i, false, false),
                PathList::Matchers::PathRegexp.new(/(?i-mx:\Afoo\z)|(?i-mx:\Abaz\z)/, true, true)
              ])
            )
          ])
        end
      end

      context 'when allow' do
        let(:allow_arg) { true }

        it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
          expect(matchers).to eq PathList::Matchers::LastMatch.new([
            PathList::Matchers::Ignore,
            PathList::Matchers::Any.new([
              PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/b(?:\z|/c\z))}i, true, true)
              ),
              PathList::Matchers::WithinDir.new(
                '/a/b/c/',
                PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)[^/]*/}i, false, true),
                  PathList::Matchers::PathRegexp.new(%r{(?i-mx:\Afoo/)|(?i-mx:\Abaz/)}, true, false)
                ])
              )
            ]),
            PathList::Matchers::WithinDir.new(
              '/a/b/c/',
              PathList::Matchers::LastMatch.new([
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)[^/]*\z}i, false, true),
                PathList::Matchers::PathRegexp.new(/(?i-mx:\Afoo\z)|(?i-mx:\Abaz\z)/, true, false)
              ])
            )
          ])
        end
      end
    end

    describe 'with more complex patterns' do
      let(:patterns) { ['a', '/b', 'd', '/bb', '!c/d', '**/e', '# comment'] }
      let(:root) { '/f/g/' }

      context 'when ignore' do
        let(:allow_arg) { false }

        it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
          expect(matchers).to eq PathList::Matchers::LastMatch.new([
            PathList::Matchers::Allow,
            PathList::Matchers::WithinDir.new(
              '/f/g/',
              PathList::Matchers::LastMatch.new([
                PathList::Matchers::Any.new([
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, false),
                  PathList::Matchers::PathRegexp.new(/(?i-mx:\Ab\z)|(?i-mx:\Abb\z)/, true, false),
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)d\z}i, false, false)
                ]),
                PathList::Matchers::PathRegexp.new(%r{\Ac/d\z}i, true, true),
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)e\z}i, false, false)
              ])
            )
          ])
        end
      end

      context 'when allow' do
        let(:allow_arg) { true }

        it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
          expect(matchers).to eq PathList::Matchers::LastMatch.new([
            PathList::Matchers::Ignore,
            PathList::Matchers::Any.new([
              PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(%r{\Af(?:\z|/g\z)}i, true, true)
              ),
              PathList::Matchers::WithinDir.new(
                '/f/g/',
                PathList::Matchers::Any.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a/}i, false, true),
                  PathList::Matchers::PathRegexp.new(%r{(?i-mx:\Ab/)|(?i-mx:\Abb/)}, true, true),
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)d/}i, false, true),
                  PathList::Matchers::PathRegexp.new(%r{\Ac/d/}i, true, false),
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)e/}i, false, true)
                ])
              )
            ]),
            PathList::Matchers::WithinDir.new(
              '/f/g/',
              PathList::Matchers::LastMatch.new([
                PathList::Matchers::Any.new([
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\z}i, false, true),
                  PathList::Matchers::PathRegexp.new(/(?i-mx:\Ab\z)|(?i-mx:\Abb\z)/, true, true),
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)d\z}i, false, true)
                ]),
                PathList::Matchers::PathRegexp.new(%r{\Ac/d\z}i, true, false),
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)e\z}i, false, true)
              ])
            )
          ])
        end
      end
    end
  end
end
