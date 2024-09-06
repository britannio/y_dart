# Directories
RUST_DIR := rust
OUTPUT_DIR := rust

# Files
RUST_LIB := $(RUST_DIR)/src/lib.rs
OUTPUT_HEADER := $(OUTPUT_DIR)/libyrs.h
FFI_GEN_OUTPUT := lib/ydart/ffi/y_dart_bindings_generated.dart

# Command
CBINDGEN_CMD := cd $(RUST_DIR) && cbindgen --config cbindgen.toml --crate y_dart --output ../$(OUTPUT_HEADER) --lang C
FFI_GEN_CMD := dart --enable-experiment=native-assets run ffigen --config ffigen.yaml

# Default target
all: $(OUTPUT_HEADER) $(FFI_GEN_OUTPUT)

# Generate header file when rust/src/lib.rs changes
$(OUTPUT_HEADER): $(RUST_LIB)
	@echo "Generating header file..."
	@$(CBINDGEN_CMD)
	@echo "Header file generated: $(OUTPUT_HEADER)"

# Generate FFI bindings when header file changes
$(FFI_GEN_OUTPUT): $(OUTPUT_HEADER)
	@echo "Generating FFI bindings..."
	@$(FFI_GEN_CMD)
	@echo "FFI bindings generated: $(FFI_GEN_OUTPUT)"

# Clean target
clean:
	@rm -f $(OUTPUT_HEADER)

.PHONY: all clean