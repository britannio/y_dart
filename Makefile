# Directories
RUST_DIR := rust
OUTPUT_DIR := rust

# Files
RUST_LIB := $(RUST_DIR)/src/lib.rs
OUTPUT_HEADER := $(OUTPUT_DIR)/libyrs.h

# Command
CBINDGEN_CMD := cd $(RUST_DIR) && cbindgen --config cbindgen.toml --crate y_dart --output ../$(OUTPUT_HEADER) --lang C

# Default target
all: $(OUTPUT_HEADER)

# Generate header file when rust/src/lib.rs changes
$(OUTPUT_HEADER): $(RUST_LIB)
	@echo "Generating header file..."
	@$(CBINDGEN_CMD)
	@echo "Header file generated: $(OUTPUT_HEADER)"

# Clean target
clean:
	@rm -f $(OUTPUT_HEADER)

.PHONY: all clean