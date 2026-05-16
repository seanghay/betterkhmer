defmodule BetterKhmerTest do
  use ExUnit.Case

  @fixtures Path.expand(Path.join([__DIR__, "..", "..", "..", "fixtures"]))

  defp load(name) do
    lines =
      @fixtures
      |> Path.join(name)
      |> File.read!()
      |> String.split("\n")

    # drop the trailing "" produced by the file's final newline
    case List.last(lines) do
      "" -> Enum.drop(lines, -1)
      _ -> lines
    end
  end

  test "basic" do
    assert BetterKhmer.normalize("ខ្មែរ") == "ខ្មែរ"
  end

  test "fixtures" do
    inputs = load("input.txt")
    expected = load("expected.txt")
    assert length(inputs) == length(expected)

    failures =
      inputs
      |> Enum.zip(expected)
      |> Enum.with_index()
      |> Enum.reduce(0, fn {{inp, exp}, i}, f ->
        got = BetterKhmer.normalize(inp)

        if got == exp do
          f
        else
          if f < 10, do: IO.puts("[#{i}] got #{inspect(got)}, want #{inspect(exp)}")
          f + 1
        end
      end)

    assert failures == 0, "#{failures}/#{length(inputs)} fixture failures"
  end
end
