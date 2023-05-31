# Template Makefile for STM8 projects
# This makefile uses SDCC and additionally performs dead code elimination

# Targets:
# Note: Target dependencies have been simplified for better readability

# Firmware related targets
# ------------------------

# all: Runs build target

# build: Builds the firmware and generates a binary file (elf and hex)
# 	↳ build_make_param_check
# 	↳ clean
# 	↳ toolchain_check
# 	↳ hex
# 		↳ elf
# 			↳ asm
# 			↳ dce
#			↳ all_obj
# 	↳ size_check

# upload: Flashes the firmware to the target device
# 	↳ upload_make_param_check
# 	↳ toolchain_check
# 	↳ hex
# 	↳ size_check

# Toolchain related targets
# -------------------------

# ubuntu_deps : Installs the necessary dependencies on an Ubuntu system for building the toolchain

# toolchain : Compiles and builds the toolchain
# 	↳ toolchain_start 
# 	↳ toolchain_sdcc
# 		↳ toolchain_autoconf
#		↳ toolchain_gputils
# 	↳ toolchain_stm8-binutils-gdb
#	↳ toolchain_stm8flash
#	↳ toolchain_sdccrm


# Meta

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR := $(realpath -s $(dir $(mkfile_path)))

# Toolchain build vars
TOOLCHAIN_DIR        := $(MKFILE_DIR)/stm8-toolchain
TOOLCHAIN_BUILD_DIR  := $(TOOLCHAIN_DIR)/build
TOOLCHAIN_BIN_DIR    := $(TOOLCHAIN_DIR)/bin

# Toolchain definitions
CC         := $(TOOLCHAIN_BIN_DIR)/sdcc
LD         := $(TOOLCHAIN_BIN_DIR)/sdcc
AS         := $(TOOLCHAIN_BIN_DIR)/sdasstm8
OBJCOPY    := $(TOOLCHAIN_BIN_DIR)/stm8-objcopy
FLASH      := $(TOOLCHAIN_BIN_DIR)/stm8flash
DCE        := $(TOOLCHAIN_BIN_DIR)/sdccrm
SIZE       := $(TOOLCHAIN_BIN_DIR)/stm8-size
FLASH_TOOL := $(TOOLCHAIN_BIN_DIR)/stm8flash

MKDIR      := mkdir
CP         := cp

# Build flags
BUILD_TARGET_DEVICE   := # STM8S103                # Specify the target device here! (See stm8s.h for available devices)
DEFINES               := -D$(BUILD_TARGET_DEVICE)  # -DEXAMPLE_DEFINE -DANOTHER_DEFINE

# Object files directory and extension
OBJ       := ./build
OBJ_EXT   := rel

# Firmware related definitions
FW_INCLUDE := $(addprefix -I, include/)
FW_INCLUDE += $(addprefix -I, src/)
FW_SRC     := ./src
FW_SRCS    := $(wildcard $(FW_SRC)/*.c)
FW_OBJ     := $(OBJ)/firmware
FW_OBJS    := $(patsubst $(FW_SRC)/%.c,$(FW_OBJ)/%.$(OBJ_EXT),$(FW_SRCS))
FW_MM      := $(OBJ)/firmware
FW_MMS     := $(patsubst $(FW_SRC)/%.c,$(FW_MM)/%.d,$(FW_SRCS))
FW_ASM     := $(OBJ)/firmware
FW_ASMS    := $(patsubst $(FW_SRC)/%.c,$(FW_ASM)/%.asm,$(FW_SRCS))

# SPL related definitions
SPL_INCLUDE     := $(addprefix -I, lib/STM8S_StdPeriph_Driver/inc)
SPL_SRC         := ./lib/STM8S_StdPeriph_Driver/src
SPL_SRCS        := $(SPL_SRC)/stm8s_clk.c \
                   $(SPL_SRC)/stm8s_exti.c \
                   $(SPL_SRC)/stm8s_flash.c \
                   $(SPL_SRC)/stm8s_gpio.c \
                   $(SPL_SRC)/stm8s_uart1.c
SPL_OBJ         := $(OBJ)/lib/STM8S_StdPeriph_Driver
SPL_OBJS        := $(patsubst $(SPL_SRC)/%.c,$(SPL_OBJ)/%.$(OBJ_EXT),$(SPL_SRCS))
SPL_MM          := $(OBJ)/lib/STM8S_StdPeriph_Driver
SPL_MMS         := $(patsubst $(SPL_SRC)/%.c,$(SPL_MM)/%.d,$(SPL_SRCS))
SPL_ASM         := $(OBJ)/lib/STM8S_StdPeriph_Driver
SPL_ASMS        := $(patsubst $(SPL_SRC)/%.c,$(SPL_ASM)/%.asm,$(SPL_SRCS))

# Library related definitions
# Include and adjust to your needs if you intend to compile a library
# EXAMPLELIB_INCLUDE := $(addprefix -I, lib/EXAMPLELIB/include) # Specify the include directory of the library
# EXAMPLELIB_SRC     := ./lib/EXAMPLELIB/src                  # Specify the source directory of the library
# These shouldn't require any changes
# EXAMPLELIB_SRCS    := $(wildcard $(EXAMPLELIB_SRC)/*.c)
# EXAMPLELIB_OBJ     := $(OBJ)/lib/EXAMPLELIB
# EXAMPLELIB_OBJS    := $(patsubst $(EXAMPLELIB_SRC)/%.c,$(EXAMPLELIB_OBJ)/%.$(OBJ_EXT),$(EXAMPLELIB_SRCS))
# EXAMPLELIB_MM      := $(OBJ)/lib/EXAMPLELIB
# EXAMPLELIB_MMS     := $(patsubst $(EXAMPLELIB_SRC)/%.c,$(EXAMPLELIB_MM)/%.d,$(EXAMPLELIB_SRCS))
# EXAMPLELIB_ASM     := $(OBJ)/lib/EXAMPLELIB
# EXAMPLELIB_ASMS    := $(patsubst $(EXAMPLELIB_SRC)/%.c,$(EXAMPLELIB_ASM)/%.asm,$(EXAMPLELIB_SRCS))

# All sources, objects and assembler files
SRCS            := $(FW_SRCS) $(SPL_SRCS) # $(EXAMPLELIB_SRCS)
OBJS            := $(FW_OBJS) $(SPL_OBJS) # $(EXAMPLELIB_OBJS)
ASMS            := $(FW_ASMS) $(SPL_ASMS) # $(EXAMPLELIB_ASMS)

# Linker related definitions
FW_BIN          := firmware
LD_FLAGS        := -mstm8 --nostdlib --code-size 8192 --iram-size 1024 --out-fmt-elf
LIB_DIRS        := $(addprefix -L, $(TOOLCHAIN_DIR)/share/sdcc/lib/stm8)
LIBS            := $(addprefix -l, stm8)

# Assembler flags
AS_FLAGS = -plosg -ff

# Dead Code Elimination related definitions

# Unfortunately, the DCE tool is not very smart and will sometimes mistakenly exclude
# code that is actually used (e.g. function pointers and interrupts, as these are
# not executed with a simple call instruction). As a workaround, the DCE_EXCLUDE_SYMBOLS
# variable can be used to specify symbols that should not be excluded from the
# final binary.

# If the linker complains about missing symbols after enabling DCE, try to add them
# to the DCE_EXCLUDE_SYMBOLS variable.

# If you wish to exclude a whole file from DCE, you can do so by adding it to the
# DCE_EXCLUDE_ASM variable, where the exact path to the generated assembly file
# must be specified.

DCE_EXCLUDE_SYMBOLS := #-x _example_symbol1 \
                       #-x _example_symbol2 \
                       #-x _example_symbol3

DCE_EXCLUDE_ASM := $(FW_ASM)/stm8s_it.asm

DCE_FLAGS       := -r $(DCE_EXCLUDE_SYMBOLS)
DCE_ASMS        :=  $(filter-out $(DCE_EXCLUDE_ASM), $(ASMS))

# Compiler flags
INCLUDE         := $(STM8S_CFG_INCLUDE) $(FW_INCLUDE) $(SPL_INCLUDE) # $(EXAMPLELIB_INCLUDE)
CC_FLAGS        := -mstm8 --out-fmt-elf -c --opt-code-size $(INCLUDE)

# Flashing

# Please modify the parameters below to match your needs!
# The default values provided assume an STM8S103F3 target device and the stlinkv2 as a programmer

RAM_SIZE                := # 1024        # Specify the RAM size of the target device here!
FLASH_SIZE              := # 8096        # Specify the flash size of the target device here!
UPLOAD_TARGET_DEVICE    := # stm8s103f3  # Specify the target device for flashing here! See stm8flash -l for a list of supported devices
UPLOAD_PROGRAMMER       := # stlinkv2    # Specify the programmer (stlink, stlinkv2, stlinkv21, stlinkv3, or espstlink) to use for flashing here!
UPLOAD_FLAGS            := -c $(UPLOAD_PROGRAMMER) -p $(UPLOAD_TARGET_DEVICE) -w

# ------------------------------------
# Firmware Targets
# ------------------------------------

default: build

# Uploads firmware to device
upload: upload_make_param_check toolchain_check $(OBJ)/$(FW_BIN).hex size_check
	@echo "\nUPLOADING FIRMWARE"
	@echo "----------------------------------------"
	$(FLASH_TOOL) $(UPLOAD_FLAGS) $(OBJ)/$(FW_BIN).hex

upload_make_param_check:
# Check if all required parameters are set
ifeq ($(RAM_SIZE),)
	$(error RAM_SIZE is not defined. Please specify the RAM size of the target device in the Makefile)
endif
ifeq ($(FLASH_SIZE),)
	$(error FLASH_SIZE is not defined. Please specify the flash size of the target device in the Makefile)
endif
ifeq ($(UPLOAD_TARGET_DEVICE),)
	$(error UPLOAD_TARGET_DEVICE is not defined. Please specify the target device in the Makefile)
endif
ifeq ($(UPLOAD_PROGRAMMER),)
	$(error UPLOAD_PROGRAMMER is not defined. Please specify the programmer in the Makefile)
endif

# Builds firmware
build: clean build_make_param_check toolchain_check $(OBJ)/$(FW_BIN).hex size_check 
	@echo "\nBUILD SUCCESSFUL\n"
	@echo "Firmware: $(OBJ)/$(FW_BIN).hex"

build_make_param_check:
# Check if BUILD_TARGET_DEVICE is defined
ifeq ($(BUILD_TARGET_DEVICE),)
	$(error BUILD_TARGET_DEVICE is not defined. Please specify the target device in the Makefile)
endif

# Prints size of firmware and checks if it fits into the flash and ram of the target device
size_check: $(OBJ)/$(FW_BIN).elf $(OBJ)/$(FW_BIN).hex toolchain_check
	@echo "\nPROGRAM SIZE:"; \
	TOO_LARGE_RAM=0; \
	TOO_LARGE_FLASH=0; \
	USED_RAM=$$($(SIZE) -A $(OBJ)/$(FW_BIN).elf | grep -o 'DATA.*[0-9]* ' | grep -o '[0-9]*' || echo 0 ); \
	USED_RAM=$$(echo $$USED_RAM | tr -d '[:space:]' ); \
	RAM_SIZE=$$(echo $(RAM_SIZE) | tr -d '[:space:]' ); \
	echo "------------------------------------------------------"; \
	echo "RAM:\tUsed $$USED_RAM bytes from $$RAM_SIZE bytes ($$(((100 * USED_RAM)/$(RAM_SIZE)))%)"; \
	if [ $$USED_RAM -gt $(RAM_SIZE) ]; then \
		TOO_LARGE_RAM=1; \
	fi; \
	USED_FLASH=$$($(SIZE) $(OBJ)/$(FW_BIN).hex | grep -E -o '.{13}$(OBJ)/$(FW_BIN).hex' | cut -c1-4 || echo 0); \
	USED_FLASH=$$(echo $$USED_FLASH | tr -d '[:space:]' ); \
	FLASH_SIZE=$$(echo $(FLASH_SIZE) | tr -d '[:space:]' ); \
	echo "FLASH:\tUsed $$USED_FLASH bytes from $$FLASH_SIZE bytes ($$(((100 * USED_FLASH)/$(FLASH_SIZE)))%)"; \
	if [ $$USED_FLASH -gt $(FLASH_SIZE) ]; then \
		TOO_LARGE_FLASH=1; \
	fi; \
	echo "------------------------------------------------------"; \
	if [ $$TOO_LARGE_RAM -eq 1 ]; then echo "ERROR: Program exceeds RAM!"; fi; \
	if [ $$TOO_LARGE_FLASH -eq 1 ]; then echo "ERROR: Program exceeds FLASH!"; fi; \
	if [ $$TOO_LARGE_RAM -eq 1 ] || [ $$TOO_LARGE_FLASH -eq 1 ]; then exit 1; fi

# Builds the firmware binary as a hex file
hex: $(OBJ)/$(FW_BIN).hex

$(OBJ)/$(FW_BIN).hex: $(OBJ)/$(FW_BIN).elf toolchain_check
	$(OBJCOPY) -O ihex --remove-section=".debug*" --remove-section=SSEG --remove-section=INITIALIZED --remove-section=DATA $< $@
	@echo "Hex file generated: $(OBJ)/$(FW_BIN).hex"
	$(SIZE) $(OBJ)/$(FW_BIN).hex

# Builds the firmware binary as an elf file
elf: $(OBJ)/$(FW_BIN).elf

$(OBJ)/$(FW_BIN).elf: dce $(OBJS) toolchain_check
	$(LD) $(LD_FLAGS) $(LIB_DIRS) $(LIBS) $(OBJS) -o $@
	@echo "ELF file generated: $(OBJ)/$(FW_BIN).elf"
	$(SIZE) $(OBJ)/$(FW_BIN).elf

# Applies dead code elimination on assembly files
dce: $(ASMS) toolchain_check
	$(DCE) $(DCE_FLAGS) $(DCE_ASMS)

# Builds assembly files from c files
asm: $(ASMS)

# Object targets
all_obj: $(OBJS)

# SPL objects
spl_obj: $(SPL_OBJS) $(SPL_MMS)

$(SPL_OBJ)%.$(OBJ_EXT): $(SPL_OBJ)%.asm toolchain_check
	@$(MKDIR) -p $(SPL_OBJ)
	$(AS) $(AS_FLAGS) $<

$(SPL_OBJ)%.asm: $(SPL_SRC)%.c toolchain_check
	@$(MKDIR) -p $(SPL_OBJ)
	$(CC) $< $(DEFINES) $(CC_FLAGS) -S -o $@

$(SPL_MM)%.d: $(SPL_SRC)%.c toolchain_check
	@$(MKDIR) -p $(SPL_OBJ)
	$(CC) $< $(DEFINES) $(CC_FLAGS) -MM > $@

# Library objects
# examplelib_obj: $(EXAMPLELIB_MMS) $(EXAMPLELIB_OBJS)
#     @echo $^

# $(EXAMPLELIB_OBJ)%.$(OBJ_EXT): $(EXAMPLELIB_OBJ)%.asm toolchain_check
#     @$(MKDIR) -p $(EXAMPLELIB_OBJ)
#     $(AS) $(AS_FLAGS) $<

# $(EXAMPLELIB_OBJ)%.asm: $(EXAMPLELIB_SRC)%.c toolchain_check
#     @$(MKDIR) -p $(EXAMPLELIB_OBJ)
#     $(CC) $< $(DEFINES) $(CC_FLAGS) -S -o $@

# $(EXAMPLELIB_MM)%.d: $(EXAMPLELIB_SRC)%.c toolchain_check
#     @$(MKDIR) -p $(EXAMPLELIB_OBJ)
#     $(CC) $< $(DEFINES) $(CC_FLAGS) -MM > $@

# Firmware objects
fw_obj: $(FW_MMS) $(FW_OBJS) toolchain_check
	@echo $^

$(FW_OBJ)%.$(OBJ_EXT): $(FW_OBJ)%.asm toolchain_check
	@$(MKDIR) -p $(FW_OBJ)
	$(AS) $(AS_FLAGS) $<

$(FW_OBJ)%.asm: $(FW_SRC)%.c toolchain_check
	@$(MKDIR) -p $(FW_OBJ)
	$(CC) $< $(DEFINES) $(CC_FLAGS) -S -o $@

$(FW_MM)%.d: $(FW_SRC)%.c toolchain_check
	@$(MKDIR) -p $(FW_OBJ)
	$(CC) $< $(DEFINES) $(CC_FLAGS) -MM > $@

# Clean build files
clean:
	rm -rf $(OBJ)/

# ----------------------------------------
# Toolchain Targets
# ----------------------------------------

UBUNTU_DEPENDENCIES :=  build-essential \
                        subversion \
                        bison \
                        flex \
                        libboost-dev \
                        zlib1g-dev \
                        git \
                        texinfo \
                        pkg-config \
                        libusb-1.0-0-dev \
                        perl \
                        autoconf \
                        automake \
                        help2man

STM8_BIN_UTILS_URL  := http://sourceforge.net/projects/stm8-binutils-gdb/files/latest/download?source=files

# Fetches dependencies for the toolchain on Ubuntu
ubuntu_deps:
	@sudo apt install -y $(UBUNTU_DEPENDENCIES)

# Checks if the toolchain is installed
toolchain_check:
	@if [ ! -d "$(TOOLCHAIN_DIR)" ]; then \
		echo -n "Toolchain not found! Please run make toolchain to install it, " && \
		echo "or set TOOLCHAIN_DIR in the makefile to the path of an existing toolchain." && \
		exit 1; \
	fi

# Builds the toolchain
toolchain: toolchain_start toolchain_sdcc toolchain_stm8-binutils-gdb toolchain_stm8flash toolchain_sdccrm
	@echo
	@echo "Toolchain successfully installed to $(TOOLCHAIN_DIR)"
	@echo "All tools (sdcc, stm8flash, etc.) can be found in: $(TOOLCHAIN_BIN_DIR)"
	@echo
	@echo "Please run make clean_toolchain to remove the toolchain build directory"
	@echo

toolchain_start:
	@echo "Building toolchain"
	@echo
	@echo "-----------------------------------------------------------------------------"
	@echo "NOTE: Please ensure beforehand that the following dependencies are installed:"
	@echo "$(UBUNTU_DEPENDENCIES)"
	@echo
	@echo "On Ubuntu 20.04+ systems, these can be installed using:"
	@echo "\tmake ubuntu_deps"
	@echo "-----------------------------------------------------------------------------"
	@echo
	@echo "This could take a while, so feel free to make yourself a coffee :)"
	@echo
	@sleep 10

toolchain_autoconf:
	@mkdir -p $(TOOLCHAIN_DIR)
	@mkdir -p $(TOOLCHAIN_BUILD_DIR)
	@mkdir -p $(TOOLCHAIN_BIN_DIR)

	@echo
	@echo "Downloading autoconf..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR) && \
	if [ -d autoconf ]; then \
		echo "autoconf already downloaded"; \
	else \
		git clone http://git.sv.gnu.org/r/autoconf.git; \
	fi

	@echo
	@echo "Building autoconf..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/autoconf && \
	export PERL_5_BIN=$$(find /usr/bin/ -name perl5* | grep -o "/usr/bin/perl5\..*\.."); \
	export PATH="$(TOOLCHAIN_BIN_DIR):$$PATH"; \
	./bootstrap && \
	PERL="$$PERL_5_BIN" ./configure --prefix=$(TOOLCHAIN_DIR) && \
	$(MAKE) && \
	$(MAKE) install

toolchain_gputils:
	@mkdir -p $(TOOLCHAIN_DIR)
	@mkdir -p $(TOOLCHAIN_BUILD_DIR)
	@mkdir -p $(TOOLCHAIN_BIN_DIR)

	@echo
	@echo "Downloading gputils..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR) && \
	if [ -d gputils ]; then \
		echo "gputils already downloaded"; \
	else \
		svn checkout svn://svn.code.sf.net/p/gputils/code/trunk .; \
	fi

	@echo
	@echo "Building gputils..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/gputils && \
	export PATH="$(TOOLCHAIN_BIN_DIR):$$PATH" && \
	./configure --prefix=$(TOOLCHAIN_DIR) && \
	$(MAKE) && \
	$(MAKE) install

toolchain_sdcc: toolchain_autoconf toolchain_gputils
	@mkdir -p $(TOOLCHAIN_DIR)
	@mkdir -p $(TOOLCHAIN_BUILD_DIR)
	@mkdir -p $(TOOLCHAIN_BIN_DIR)

	@echo
	@echo "Downloading SDCC..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR) && \
	if [ -d sdcc ]; then \
		echo "sdcc already downloaded"; \
	else \
		svn checkout svn://svn.code.sf.net/p/sdcc/code/trunk/sdcc sdcc; \
	fi

	@echo
	@echo "Building SDCC..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/sdcc && \
	export PATH="$(TOOLCHAIN_BIN_DIR):$$PATH" && \
	./configure --prefix=$(TOOLCHAIN_DIR) && \
	$(MAKE) && \
	$(MAKE) install

toolchain_stm8-binutils-gdb:
	@echo
	@echo "Downloading STM8 binutils-gdb"
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR) && \
	if [ -d "stm8-binutils-gdb-sources" ]; then \
		echo "stm8-binutils-gdb-sources already downloaded"; \
	else \
		wget $(STM8_BIN_UTILS_URL) \
		--output-document stm8-binutils-gdb-sources.tar.gz && \
		tar -xvf stm8-binutils-gdb-sources.tar.gz; \
	fi

	@echo
	@echo "Building STM8 binutils-gdb..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/stm8-binutils-gdb-sources && \
	export PATH="$(TOOLCHAIN_BIN_DIR):$$PATH" && \
	./patch_binutils.sh && \
	PREFIX=$(TOOLCHAIN_DIR) ./configure_binutils.sh && \
	cd binutils-* && \
	$(MAKE) && \
	$(MAKE) install

toolchain_stm8flash:
	@mkdir -p $(TOOLCHAIN_DIR)
	@mkdir -p $(TOOLCHAIN_BUILD_DIR)
	@mkdir -p $(TOOLCHAIN_BIN_DIR)

	@echo
	@echo "Downloading stm8Flash..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/ && \
	if [ -d stm8flash ]; then \
		echo "stm8flash already downloaded"; \
	else \
		git clone https://github.com/vdudouyt/stm8flash.git; \
	fi

	@echo
	@echo "Building stm8flash..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/stm8flash && \
	export PATH="$(TOOLCHAIN_BIN_DIR):$$PATH" && \
	$(MAKE) && \
	$(MAKE) DESTDIR=$(TOOLCHAIN_DIR) install

toolchain_sdccrm:
	@echo
	@echo "Downloading sdccrm..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/ && \
	if [ -d sdccrm ]; then \
		echo "sdccrm already downloaded"; \
	else \
		git clone https://github.com/XaviDCR92/sdccrm.git; \
	fi

	@echo
	@echo "Building sdccrm..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/sdccrm \
	sdccrm && \
	export PATH="$(TOOLCHAIN_BIN_DIR):$$PATH" && \
	$(MAKE) && \
	cp sdccrm $(TOOLCHAIN_BIN_DIR)

# Removes the toolchain directory
clean_toolchain:
	rm -rf $(TOOLCHAIN_BUILD_DIR)
	@echo "Toolchain cleaned"

# ----------------------------------------
# Phony targets
# ----------------------------------------
.PHONY: clean
