package com.betterkhmer;

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class BetterKhmerTest {
    private static final String FIXTURES = System.getProperty("fixtures.dir",
        System.getProperty("user.dir") + "/../../fixtures");

    private static List<String> loadLines(String name) throws IOException {
        Path p = Paths.get(FIXTURES, name);
        return Files.readAllLines(p);
    }

    public static void main(String[] args) throws Exception {
        // basic
        String got = BetterKhmer.normalize("ខ្មែរ");
        if (!got.equals("ខ្មែរ")) {
            throw new AssertionError("basic FAILED: got " + got);
        }
        System.out.println("basic: ok");

        List<String> inputs   = loadLines("input.txt");
        List<String> expected = loadLines("expected.txt");
        if (inputs.size() != expected.size()) throw new AssertionError("length mismatch");

        int failures = 0;
        for (int i = 0; i < inputs.size(); i++) {
            String result = BetterKhmer.normalize(inputs.get(i));
            if (!result.equals(expected.get(i))) {
                failures++;
                if (failures <= 10) {
                    System.err.println("[" + i + "] got " + result + ", want " + expected.get(i));
                }
            }
        }
        if (failures > 0) {
            throw new AssertionError(failures + "/" + inputs.size() + " fixture failures");
        }
        System.out.println("fixtures: " + inputs.size() + " ok");
    }
}
