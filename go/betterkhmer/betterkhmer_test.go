package betterkhmer_test

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/betterkhmer/betterkhmer"
)

func loadLines(path string) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var lines []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		lines = append(lines, sc.Text())
	}
	return lines, sc.Err()
}

func TestBasic(t *testing.T) {
	got := betterkhmer.Normalize("ខ្មែរ")
	if got != "ខ្មែរ" {
		t.Errorf("basic: got %q", got)
	}
}

func TestFixtures(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	fixturesDir := filepath.Join(filepath.Dir(file), "..", "..", "fixtures")

	inputs, err := loadLines(filepath.Join(fixturesDir, "input.txt"))
	if err != nil {
		t.Fatal(err)
	}
	expected, err := loadLines(filepath.Join(fixturesDir, "expected.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if len(inputs) != len(expected) {
		t.Fatalf("length mismatch: %d vs %d", len(inputs), len(expected))
	}

	failures := 0
	for i, inp := range inputs {
		got := betterkhmer.Normalize(inp)
		if got != expected[i] {
			failures++
			if failures <= 10 {
				t.Errorf("[%d] got %q, want %q (input %q)", i, got, expected[i], inp)
			}
		}
	}
	if failures > 0 {
		t.Errorf("%d/%d fixtures failed", failures, len(inputs))
	} else {
		fmt.Printf("All %d fixtures passed\n", len(inputs))
	}
}
