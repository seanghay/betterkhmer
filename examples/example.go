package main

import (
	"fmt"
	"github.com/seanghay/betterkhmer"
)

func main() {
	text := "ខ្មែរ"
	result := betterkhmer.Normalize(text)
	fmt.Println(result)
}
