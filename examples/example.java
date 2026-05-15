import com.betterkhmer.BetterKhmer;

public class example {
    public static void main(String[] args) {
        String text = "ខ្មែរ";
        String result = BetterKhmer.normalize(text);
        System.out.println(result);
    }
}
