CC      = clang
CFLAGS  = -fobjc-arc -Wall -O2 -Isrc
LDFLAGS = -framework Foundation

BUILD   = build
TARGET  = $(BUILD)/test_normalize
SRC     = src/BetterKhmer.m test/test_normalize.m

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(SRC) src/BetterKhmer.h | $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(TARGET) $(SRC)

$(BUILD):
	mkdir -p $(BUILD)

test: $(TARGET)
	./$(TARGET) ../../fixtures

clean:
	rm -rf $(BUILD)
