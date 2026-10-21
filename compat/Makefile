# liblegacyfox_compat.a: the libc and system calls iOS 4-7 lack.
include ../make/config.mk

BUILD ?= build
LIB   := $(BUILD)/liblegacyfox_compat.a
OBJ   := $(BUILD)/legacyfox_compat.o $(BUILD)/legacyfox_compat_apple.o

.PHONY: all clean
all: $(LIB)

$(BUILD)/%.o: %.c legacyfox_compat.h
	@mkdir -p $(BUILD)
	@echo "  c     $<"
	@$(LF_CC) $(LF_ARCH) $(LF_SYSROOT) -O2 -g0 -Wall -Wextra -Wno-unused-parameter -std=gnu99 -c $< -o $@

$(LIB): $(OBJ)
	@rm -f $@
	@$(LF_TC)/ar rcs $@ $^

clean:
	rm -rf $(BUILD)
