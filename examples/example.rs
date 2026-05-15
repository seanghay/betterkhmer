use betterkhmer::normalize;

fn main() {
    let text = "ខ្មែរ";
    let result = normalize(text, "km");
    println!("{}", result);
}
