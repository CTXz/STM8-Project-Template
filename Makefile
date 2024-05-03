#######################################
# Toolchain
#######################################

CC = sdcc
LD = sdcc
AS = sdasstm8
FLASH = stm8flash
OBJCOPY = stm8-objcopy
SIZE = stm8-size
DCE = stm8dce

MKDIR = mkdir
CP = cp

#######################################
# Build options
#######################################

# MCU Variant
DEFINE = -DSTM8S103 # Change to your STM8S variant

# Defines
DEFINE +=

# Include directories
INCLUDE = $(addprefix -I, \
	include/ \
	src/ \
)

# Compiler flags
CC_FLAGS = -mstm8 --out-fmt-elf

# Project name
PROJECT = Template

# Build directory
BUILD_DIR = build

# Assembly files
ASM_DIR = $(BUILD_DIR)/asm
AS_FLAGS = -plosg -ff

# Dead Code Elimination
DCE_DIR = $(BUILD_DIR)/dce
DCE_FLAGS = --opt-irq

# Object files
OBJ_DIR = $(BUILD_DIR)/obj

# Source files
VPATH += src
SRC_FILES = $(wildcard src/*.c) # Compile all .c files in src directory

# Linker flags
LD_FLAGS = -mstm8 --out-fmt-elf --opt-code-size
LIBS = $(addprefix -l, stm8)

# ELF to HEX flags
OBJCOPY_FLAGS = --remove-section=".debug*" --remove-section=SSEG --remove-section=INITIALIZED --remove-section=DATA

# Size Check
RAM_SIZE = 1024
FLASH_SIZE = 8192

#######################################
# Flash Options
#######################################

FLASH_FLAGS = -c stlinkv2 -p stm8s103f3

#######################################
# Standard Peripheral Library
#######################################

VPATH += lib/STM8S_StdPeriph_Driver/src
INCLUDE += -Ilib/STM8S_StdPeriph_Driver/inc

# Comment/Uncomment according to your STM8S variant
# Which peripherals apply to your STM8S variant can be found out
# by looking at the STM8S_StdPeriph_Driver/inc/stm8s.h file

STDPER_SRC 	+= stm8s_adc1.c
# STDPER_SRC 	+= stm8s_adc2.c
STDPER_SRC 	+= stm8s_awu.c
STDPER_SRC 	+= stm8s_beep.c
# STDPER_SRC 	+= stm8s_can.c
STDPER_SRC 	+= stm8s_clk.c
STDPER_SRC 	+= stm8s_exti.c
STDPER_SRC 	+= stm8s_flash.c
STDPER_SRC 	+= stm8s_gpio.c
STDPER_SRC 	+= stm8s_i2c.c
STDPER_SRC 	+= stm8s_itc.c
STDPER_SRC 	+= stm8s_iwdg.c
STDPER_SRC 	+= stm8s_rst.c
STDPER_SRC 	+= stm8s_spi.c
STDPER_SRC 	+= stm8s_tim1.c
STDPER_SRC 	+= stm8s_tim2.c
# STDPER_SRC 	+= stm8s_tim3.c
# STDPER_SRC 	+= stm8s_tim4.c
# STDPER_SRC 	+= stm8s_tim5.c
# STDPER_SRC 	+= stm8s_tim6.c
STDPER_SRC 	+= stm8s_uart1.c
# STDPER_SRC 	+= stm8s_uart2.c
# STDPER_SRC 	+= stm8s_uart3.c
# STDPER_SRC 	+= stm8s_uart4.c
STDPER_SRC 	+= stm8s_wwdg.c

SRC_FILES += $(STDPER_SRC)

#######################################
# Project targets
#######################################

ASM = $(addprefix $(ASM_DIR)/, $(notdir $(SRC_FILES:.c=.asm)))
DCE_ASM = $(addprefix $(DCE_DIR)/, $(notdir $(ASM:.asm=.asm)))
OBJ = $(addprefix $(OBJ_DIR)/, $(notdir $(ASM:.asm=.rel)))

all: size_check $(BUILD_DIR)/$(PROJECT).ihx

# Upload/Flash
flash: $(BUILD_DIR)/$(PROJECT).ihx size_check
	$(FLASH) $(FLASH_FLAGS) -w $<

upload: flash

hex: $(BUILD_DIR)/$(PROJECT).ihx
elf: $(BUILD_DIR)/$(PROJECT).elf
obj: $(OBJ)
asm: $(ASM)
dce: $(DCE_ASM)

$(BUILD_DIR)/$(PROJECT).ihx: $(BUILD_DIR)/$(PROJECT).elf
	$(OBJCOPY) $(OBJCOPY_FLAGS) $< -O ihex $@

# ELF file
$(BUILD_DIR)/$(PROJECT).elf: $(OBJ)
	@$(MKDIR) -p $(BUILD_DIR)
	$(LD) $(LD_FLAGS) $(LIBS) -o $@ $^

$(ASM_DIR)/%.asm: %.c
	@$(MKDIR) -p $(ASM_DIR)
	$(CC) $< $(CC_FLAGS) $(INCLUDE) $(DEFINE) -S -o $@

$(DCE_DIR)/%.asm: $(ASM)
	@$(MKDIR) -p $(DCE_DIR)
	$(DCE) $(DCE_FLAGS) -o $(DCE_DIR) $^

$(OBJ_DIR)/%.rel: $(DCE_DIR)/%.asm
	@$(MKDIR) -p $(OBJ_DIR)
	$(AS) $(AS_FLAGS) -o $@ $<

# Clean
clean:
	rm -rf $(ASM_DIR)/ $(DCE_DIR) $(BUILD_DIR)/

# Prints size of firmware and checks if it fits into the flash and ram of the target device
# The RAM size is based on the DATA section of the ELF file
# The flash size is based on the ihx file which strips out any RAM related sections
size_check: $(BUILD_DIR)/$(PROJECT).ihx $(BUILD_DIR)/$(PROJECT).elf
	@echo "\nPROGRAM SIZE:"; \
	TOO_LARGE_RAM=0; \
	TOO_LARGE_FLASH=0; \
	USED_RAM=$$($(SIZE) -A $(BUILD_DIR)/$(PROJECT).elf | grep -o 'DATA.*[0-9]* ' | grep -o '[0-9]*' || echo 0 ); \
	USED_RAM=$$(echo $$USED_RAM | tr -d '[:space:]' ); \
	RAM_SIZE=$$(echo $(RAM_SIZE) | tr -d '[:space:]' ); \
	echo "------------------------------------------------------"; \
	echo "RAM:\tUsed $$USED_RAM bytes from $$RAM_SIZE bytes ($$(((100 * USED_RAM)/$(RAM_SIZE)))%)"; \
	if [ $$USED_RAM -gt $(RAM_SIZE) ]; then \
		TOO_LARGE_RAM=1; \
	fi; \
	USED_FLASH=$$($(SIZE) -A $(BUILD_DIR)/$(PROJECT).ihx | grep -o 'Total.*[0-9]' | grep -o '[0-9]*' || echo 0 ); \
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

#######################################
# Building Toolchain
#######################################

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
                        help2man \
			python3 \
			python3-pip

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR := $(realpath -s $(dir $(mkfile_path)))
TOOLCHAIN_DIR        := $(MKFILE_DIR)/stm8-toolchain
TOOLCHAIN_BUILD_DIR  := $(TOOLCHAIN_DIR)/build
TOOLCHAIN_BIN_DIR    := $(TOOLCHAIN_DIR)/bin

GPUITLS_REPO		:= svn://svn.code.sf.net/p/gputils/code/trunk
STM8_BIN_UTILS_TAR 	:= http://sourceforge.net/projects/stm8-binutils-gdb/files/latest/download?source=files
SDCC_REPO		:= svn://svn.code.sf.net/p/sdcc/code/trunk/sdcc
STM8DCE_REPO		:= https://github.com/CTXz/STM8-DCE.git

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
toolchain: toolchain_start toolchain_sdcc toolchain_stm8-binutils-gdb toolchain_stm8flash toolchain_stm8dce toolchain_env
	@echo
	@echo "Toolchain successfully installed to $(TOOLCHAIN_DIR)"
	@echo "All tools (sdcc, stm8flash, etc.) can be found in: $(TOOLCHAIN_BIN_DIR)"
	@echo 
	@echo "Don't forget to source the environment script before using building your project:"
	@echo "\tsource $(TOOLCHAIN_DIR)/env.sh"
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
		git clone https://git.savannah.gnu.org/git/autoconf.git; \
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
		svn checkout $(GPUITLS_REPO) .; \
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
		svn checkout $(SDCC_REPO) sdcc; \
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
		wget $(STM8_BIN_UTILS_TAR) \
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

toolchain_stm8dce:
	@mkdir -p $(TOOLCHAIN_DIR)
	@mkdir -p $(TOOLCHAIN_BUILD_DIR)
	@mkdir -p $(TOOLCHAIN_BIN_DIR)

	@echo
	@echo "Downloading STM8-DCE..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/ && \
	if [ -d STM8-DCE ]; then \
		echo "STM8-DCE already downloaded"; \
	else \
		git clone $(STM8DCE_REPO); \
	fi

	@echo
	@echo "Building STM8-DCE..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/STM8-DCE && \
	pip install . --prefix=$(TOOLCHAIN_DIR)

toolchain_env:
	@echo 'SCRIPT_DIR="$$( cd "$$( dirname "$${BASH_SOURCE[0]}" )" && pwd )"' > $(TOOLCHAIN_DIR)/env.sh
	@echo 'export PATH=$$SCRIPT_DIR/bin:$$PATH' >> $(TOOLCHAIN_DIR)/env.sh

# Removes the toolchain directory
clean_toolchain:
	rm -rf $(TOOLCHAIN_BUILD_DIR)
	@echo "Toolchain cleaned"

#######################################
# Phony targets
#######################################
.PHONY: clean
