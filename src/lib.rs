#[macro_use]

extern crate helix;
extern crate regex;

use regex::RegexBuilder;
use regex::Regex;

fn fnmatch_to_regex(pattern: &str) -> Regex {
    let mut re: String = "^".to_string();
    let mut in_character_group: bool = false;
    let mut has_characters_in_group: bool = false;
    let mut escape_next_character: bool = false;
    let mut stars: u8 = 0;
    for char in pattern.chars() {
        if escape_next_character {
            re.push_str(&regex::escape(&char.to_string().to_owned()));
            escape_next_character = false;
        } else if char == '\\' {
            escape_next_character = true;
        } else if in_character_group {
            if char == '/' {
                // do nothing
            } else if char == ']' {
                if !has_characters_in_group {
                    re.push('\u{07}');
                }
                re.push(']');
                in_character_group = false;
                has_characters_in_group = false;
            } else if char == '-' {
                has_characters_in_group = true;
                re.push('-')
            } else {
                has_characters_in_group = true;
                re.push_str(&regex::escape(&char.to_string().to_owned()));
            }
        } else if char == '*' {
            stars += 1;
        } else if char == '/' {
            if stars == 2 {
                re.push_str("(?:.*/)?");
            } else if stars > 0 {
                re.push_str("[^/]*/");
            } else {
                re.push(char);
            }
            stars = 0;
        } else {
            if stars > 0 {
                re.push_str("[^/]*");
                stars = 0;
            }
            if char == '?' {
                re.push_str("[^/]")
            } else if char == '[' {
                re.push('[');
                in_character_group = true;
            } else {
                re.push_str(&regex::escape(&char.to_string().to_owned()));
            }
        }
    }
    if stars == 2 {
        re.push_str(".*")
    } else if stars > 0 {
        re.push_str("[^/]*")
    }
    re.push('$');
    RegexBuilder::new(&re.to_owned()).case_insensitive(true).build().unwrap()
}

fn fnmatch(pattern: &str, path: &str) -> bool {
    fnmatch_to_regex(pattern).is_match(path)
}

#[test]
fn fnmatch_test_stars() {
    assert!(fnmatch("a*b", "ab"));
    assert!(fnmatch("a*b", "abb"));
    assert!(fnmatch("a*b", "acb"));
    assert!(fnmatch("a*b", "aaabbbb"));
    assert!(!fnmatch("a*b", "a/b"));
    assert!(fnmatch("a*b", "aaabbbb"));
    assert!(!fnmatch("a*b", "a/b"));
}

#[test]
fn fnmatch_test_two_stars() {
    assert!(fnmatch("**/b", "b"));
    assert!(fnmatch("**/b", "a/b"));
    assert!(fnmatch("**/b", "a/c/b"));
    assert!(!fnmatch("**/b", "ab"));

    assert!(fnmatch("b/**", "b/a"));
    assert!(!fnmatch("b/**", "b"));
    assert!(fnmatch("b/**", "b/a/b"));
    assert!(!fnmatch("b/**", "baa"));

    assert!(fnmatch("a/**/b", "a/b"));
    assert!(fnmatch("a/**/b", "a/b/c/b"));
    assert!(fnmatch("a/**/b", "a/c/b"));
    assert!(fnmatch("a/**/**/b", "a/b"));
    assert!(!fnmatch("a/**/b", "ab"));
    assert!(!fnmatch("a/**/b", "a/ab"));
}

#[test]
fn fnmatch_to_regex_to_string() {
    assert_eq!(fnmatch_to_regex("[[]").to_string(), r"^[\[]$");
}

#[test]
fn fnmatch_test_character_group_range() {
    assert!(fnmatch("[a-c]", "a"));
    assert!(fnmatch("[a-c]", "b"));
    assert!(fnmatch("[a-c]", "c"));
    assert!(!fnmatch("[a-c]", "d"));
    assert!(!fnmatch("[a-c]", "-"));
}

#[test]
fn fnmatch_test_character_group_with_dash_at_end() {
    assert!(fnmatch("[a-]", "a"));
    assert!(fnmatch("[a-]", "-"));
    assert!(!fnmatch("[a-]", "b"));
    assert!(fnmatch("[-a]", "a"));
    assert!(fnmatch("[-a]", "-"));
    assert!(!fnmatch("[-a]", "b"));
}

#[test]
fn fnmatch_test_character_group() {
    assert!(fnmatch("[abc]", "a"));
    assert!(fnmatch("[abc]", "b"));
    assert!(fnmatch("[abc]", "c"));
    assert!(!fnmatch("[abc]", "d"));
    assert!(fnmatch("a[b/]c", "abc"));
    assert!(!fnmatch("a[b/]c", "a/c"));
    assert!(!fnmatch("a[/]c", "a/c"));
    assert!(!fnmatch("a[/]c", "ac"));

    assert!(fnmatch("a[[]c", "a[c"));
}

#[test]
fn fnmatch_test_question_mark() {
    assert!(fnmatch("?", "a"));
    assert!(!fnmatch("a", "?"));
    assert!(fnmatch("a?c", "abc"));
    assert!(fnmatch("a?c", "aac"));
    assert!(fnmatch("a?c", "a.c"));
    assert!(!fnmatch("a?c", "a/c"));
}

#[test]
fn fnmatch_test_case_insensitivity() {
    assert!(fnmatch("i", "I"));
    assert!(fnmatch("I", "i"));
    assert!(fnmatch("ø", "Ø"));
    assert!(fnmatch("Ø", "ø"));
}

#[test]
fn fnmatch_test_exact_equality() {
    assert!(fnmatch("", ""));
    assert!(fnmatch("a", "a"));
    assert!(fnmatch("ABC", "ABC"));
    assert!(fnmatch(".a", ".a"));
    assert!(fnmatch("a/b/c", "a/b/c"));

    assert!(!fnmatch("a", ""));
    assert!(!fnmatch("a/b/c", "a/b"));
    assert!(!fnmatch("", "BC"));
}

ruby! {
    class FastIgnoreRule {
        struct {
            rule: String,
            dir_only: bool,
            negation: bool
        }

        def initialize(helix, rule: String, dir_only: bool, negation: bool) {
            FastIgnoreRule { helix, rule, dir_only, negation }
        }

        def negation(&self) -> bool {
            self.negation
        }

        def dir_only(&self) -> bool {
            self.dir_only
        }

        def fnmatch(&self, path: String) -> bool {
            fnmatch(&self.rule.to_owned(), &path.to_owned())
        }
    }
}
