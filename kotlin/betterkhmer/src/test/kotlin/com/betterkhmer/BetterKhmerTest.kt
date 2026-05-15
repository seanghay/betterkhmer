package com.betterkhmer

import java.nio.file.Files
import java.nio.file.Paths

fun main() {
    val fixturesDir = System.getProperty("fixtures.dir",
        System.getProperty("user.dir") + "/../../fixtures")

    val got = BetterKhmer.normalize("ខ្មែរ")
    check(got == "ខ្មែរ") { "basic FAILED: got $got" }
    println("basic: ok")

    val inputs   = Files.readAllLines(Paths.get(fixturesDir, "input.txt"))
    val expected = Files.readAllLines(Paths.get(fixturesDir, "expected.txt"))
    check(inputs.size == expected.size) { "length mismatch" }

    var failures = 0
    for (i in inputs.indices) {
        val result = BetterKhmer.normalize(inputs[i])
        if (result != expected[i]) {
            failures++
            if (failures <= 10) System.err.println("[$i] got $result, want ${expected[i]}")
        }
    }
    check(failures == 0) { "$failures/${inputs.size} fixture failures" }
    println("fixtures: ${inputs.size} ok")
}
