extern crate regex;

use regex::RegexBuilder;
use regex::Regex;

pub fn fnmatch_to_regex(pattern: &str) -> Regex {
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

pub fn is_match(pattern: &str, path: &str) -> bool {
    fnmatch_to_regex(pattern).is_match(path)
}

#[test]
fn fnmatch_test_stars() {
    assert!(is_match("a*b", "ab"));
    assert!(is_match("a*b", "abb"));
    assert!(is_match("a*b", "acb"));
    assert!(is_match("a*b", "aaabbbb"));
    assert!(!is_match("a*b", "a/b"));
    assert!(is_match("a*b", "aaabbbb"));
    assert!(!is_match("a*b", "a/b"));
}

#[test]
fn fnmatch_test_two_stars() {
    assert!(is_match("**/b", "b"));
    assert!(is_match("**/b", "a/b"));
    assert!(is_match("**/b", "a/c/b"));
    assert!(!is_match("**/b", "ab"));

    assert!(is_match("b/**", "b/a"));
    assert!(!is_match("b/**", "b"));
    assert!(is_match("b/**", "b/a/b"));
    assert!(!is_match("b/**", "baa"));

    assert!(is_match("a/**/b", "a/b"));
    assert!(is_match("a/**/b", "a/b/c/b"));
    assert!(is_match("a/**/b", "a/c/b"));
    assert!(is_match("a/**/**/b", "a/b"));
    assert!(!is_match("a/**/b", "ab"));
    assert!(!is_match("a/**/b", "a/ab"));
}

#[test]
fn fnmatch_to_regex_to_string() {
    assert_eq!(fnmatch_to_regex("[[]").to_string(), r"^[\[]$");
}

#[test]
fn fnmatch_test_character_group_range() {
    assert!(is_match("[a-c]", "a"));
    assert!(is_match("[a-c]", "b"));
    assert!(is_match("[a-c]", "c"));
    assert!(!is_match("[a-c]", "d"));
    assert!(!is_match("[a-c]", "-"));
}

#[test]
fn fnmatch_test_character_group_with_dash_at_end() {
    assert!(is_match("[a-]", "a"));
    assert!(is_match("[a-]", "-"));
    assert!(!is_match("[a-]", "b"));
    assert!(is_match("[-a]", "a"));
    assert!(is_match("[-a]", "-"));
    assert!(!is_match("[-a]", "b"));
}

#[test]
fn fnmatch_test_character_group() {
    assert!(is_match("[abc]", "a"));
    assert!(is_match("[abc]", "b"));
    assert!(is_match("[abc]", "c"));
    assert!(!is_match("[abc]", "d"));
    assert!(is_match("a[b/]c", "abc"));
    assert!(!is_match("a[b/]c", "a/c"));
    assert!(!is_match("a[/]c", "a/c"));
    assert!(!is_match("a[/]c", "ac"));

    assert!(is_match("a[[]c", "a[c"));
    assert!(is_match("a[b\\]]c", "abc"));
    assert!(is_match("a[b\\]]c", "a]c"));
}

#[test]
fn fnmatch_test_question_mark() {
    assert!(is_match("?", "a"));
    assert!(!is_match("a", "?"));
    assert!(is_match("a?c", "abc"));
    assert!(is_match("a?c", "aac"));
    assert!(is_match("a?c", "a.c"));
    assert!(!is_match("a?c", "a/c"));
}

#[test]
fn fnmatch_test_case_insensitivity() {
    assert!(is_match("i", "I"));
    assert!(is_match("I", "i"));
    assert!(is_match("ø", "Ø"));
    assert!(is_match("Ø", "ø"));
}

#[test]
fn fnmatch_test_exact_equality() {
    assert!(is_match("", ""));
    assert!(is_match("a", "a"));
    assert!(is_match("ABC", "ABC"));
    assert!(is_match(".a", ".a"));
    assert!(is_match("a/b/c", "a/b/c"));

    assert!(!is_match("a", ""));
    assert!(!is_match("a/b/c", "a/b"));
    assert!(!is_match("", "BC"));
}
