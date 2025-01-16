NAME := randomart

C3C := c3c
C3FLAGS := -O5

CC := gcc
CFLAGS := -ggdb

BUILD_DIR := build
BIN_DIR := $(BUILD_DIR)/bin
SRC_DIR := src

SOURCES := randomart.c3 ppm.c3 profiler.c3 program.c3 node/node.c3 node/jit.c3 node/bytecode.c3 args.c3 test.c3
SOURCES := $(SOURCES:%=$(SRC_DIR)/%)

C_SOURCES := node/jit_helper.c
C_OBJECTS := $(C_SOURCES:%.c=$(BUILD_DIR)/%.o)
C_SOURCES := $(C_SOURCES:%=$(SRC_DIR)/%)

$(BIN_DIR)/$(NAME): $(SOURCES) $(ASM_OBJECTS) $(C_OBJECTS)
	$(C3C) compile $(C3FLAGS) -o $@ $^

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c -o $@ $^
