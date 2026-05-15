use std::fs;
use std::path::Path;

fn load_lines(path: &Path) -> Vec<String> {
    fs::read_to_string(path)
        .expect("cannot read file")
        .lines()
        .map(|l| l.to_string())
        .collect()
}

#[test]
fn test_basic() {
    assert_eq!(betterkhmer::normalize("ខ្មែរ"), "ខ្មែរ");
}

#[test]
fn test_fixtures() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent().unwrap()
        .parent().unwrap()
        .join("fixtures");

    let inputs   = load_lines(&root.join("input.txt"));
    let expected = load_lines(&root.join("expected.txt"));
    assert_eq!(inputs.len(), expected.len());

    let mut failures = 0usize;
    for (i, (inp, exp)) in inputs.iter().zip(expected.iter()).enumerate() {
        let got = betterkhmer::normalize(inp);
        if &got != exp {
            failures += 1;
            if failures <= 10 {
                eprintln!("[{i}] got {got:?}, want {exp:?} (input {inp:?})");
            }
        }
    }
    assert_eq!(failures, 0, "{failures}/{} fixture failures", inputs.len());
}
