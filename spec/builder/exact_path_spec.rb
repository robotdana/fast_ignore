# frozen_string_literal: true

RSpec.describe PathList::Builder::ExactPath do
  subject(:matcher) { described_class.new(path, polarity, nil).build }

  let(:path) { '/path/to/exact/something' }
  let(:candidate_path) { path }
  let(:candidate) { PathList::Candidate.new(candidate_path, true, nil) }
  let(:polarity) { :allow }

  describe '#build_implicit' do
    subject(:matcher) { described_class.new(path, polarity, nil).build_implicit.prepare }

    it 'builds a regex that matches parent and child somethings' do
      expect(matcher).to be_like(
        PathList::Matchers::Any::Two.new([
          PathList::Matchers::MatchIfDir.new(
            PathList::Matchers::ExactString::Include.new(['/', '/path', '/path/to', '/path/to/exact'], :allow)
          ),
          PathList::Matchers::PathRegexp.new(%r{\A/path/to/exact/something/}, :allow)
        ])
      )
    end

    describe 'with root and relative path' do
      subject(:matcher) { described_class.new('./exact/something', polarity, '/path/to').build_implicit.prepare }

      it 'builds a regex that matches parent and child somethings' do
        expect(matcher).to be_like(
          PathList::Matchers::Any::Two.new([
            PathList::Matchers::MatchIfDir.new(
              PathList::Matchers::ExactString::Include.new(['/', '/path', '/path/to', '/path/to/exact'], :allow)
            ),
            PathList::Matchers::PathRegexp.new(%r{\A/path/to/exact/something/}, :allow)
          ])
        )
      end
    end

    it "doesn't need to match exact path" do
      expect(matcher.match(PathList::Candidate.new(path, true, nil))).to be_nil
    end

    it 'matches most parent path' do
      expect(matcher.match(PathList::Candidate.new('/path', true, nil)))
        .to be :allow
    end

    it 'matches most parent path regardless of case' do
      expect(matcher.match(PathList::Candidate.new('/PATH', true, nil))).to be :allow
    end

    it 'matches parent path' do
      expect(matcher.match(PathList::Candidate.new('/path/to', true, nil)))
        .to be :allow
    end

    it 'matches child path' do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", true, nil)))
        .to be :allow
    end

    it 'matches grandchild path' do
      expect(matcher.match(PathList::Candidate.new("#{path}/child/child", true, nil)))
        .to be :allow
    end

    it "doesn't match path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new("#{path}_part_2", true, nil)))
        .to be_nil
    end

    it "doesn't match parent path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact-ish/something', true, nil)))
        .to be_nil
    end

    it "doesn't match path sibling" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact/other', true, nil)))
        .to be_nil
    end

    it "doesn't match path concatenation" do
      expect(matcher.match(PathList::Candidate.new('/pathtoexactsomething', true, nil))) # spellr:disable-line
        .to be_nil
    end
  end

  describe '#build' do
    subject(:matcher) { described_class.new(path, polarity, nil).build }

    let(:polarity) { :ignore }

    it 'builds a matcher that matches exact something' do
      expect(matcher).to be_like(
        PathList::Matchers::ExactString.new('/path/to/exact/something', :ignore)
      )
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(path, true, nil))).to be :ignore
    end

    it 'matches exact path case insensitively' do
      expect(matcher.match(PathList::Candidate.new(path.upcase, true, nil))).to be :ignore
    end

    it "doesn't match most parent path" do
      expect(matcher.match(PathList::Candidate.new('/path', true, nil)))
        .to be_nil
    end

    it "doesn't match parent path" do
      expect(matcher.match(PathList::Candidate.new('/path/to', true, nil)))
        .to be_nil
    end

    it "doesn't match child path" do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", true, nil)))
        .to be_nil
    end
  end
end
