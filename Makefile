# README README README README README README README README README README README README README README
#
# Template Makefile for STM8S103F3P6 Project
#
# ---- Overview ----
#
# The following makefile contains targets to build and flash
# a STM8S103F3P6 project using the SDCC compiler and STM8 binutils.
# Notably, the makefile:
# 	- builds the standard peripheral library
# 	- builds all source files in the src directory
# 	- eliminates unused code sections during linking via XaviDCR92's SDCC and STM8 binutils fork
#	- generates a .ihx file for flashing
# The ihx file can be flashed via the make flash or make upload target.
#
# ---- Installing the Toolchain ----
#
# To use the makefile, ensure that the necessary toolchain is installed.
# The toolchain can be built as follows:
# 	1. Run make ubuntu_deps to install the necessary dependencies on Debian/Ubuntu systems
#         For other systems, please install the following dependencies manually:
#         - subversion bison flex libboost dev zlib1g dev git texinfo pkg config 
#	    libusb-1.0-0 dev perl autoconf automake help2man
#
# 	2. Run `make toolchain` to build the toolchain. This may take a while.
# 	   The toolchain will be installed to the stm8-toolchain directory
#	   and contains the following tools:
#		- XaviDCR92's SDCC Fork: SDCC compiler with GNU-GAS support for STM8
#		- XaviDCR92's STM8 Binutils Fork: Binutils with STM8 support
#		- stm8flash: Flashing tool for STM8
# 	   XaviDCR92's SDCC fork is used to eliminate unused code sections by compiling the code into
#	   GNU assembler format, which is then linked using XaviDCR92's STM8 binutils fork. Unlike the
#	   standard SDCC linker, the GAS linker can eliminate unused code sections, vastly reducing the
#	   size of the final binary. See https://github.com/XaviDCR92/stm8-dce-example for more information.
#
# 	3. After building the toolchain, you may run `make clean_toolchain` 
#	   to remove the toolchain build files
#
# ---- Configuring the Makefile ----
# 
# For STM8S103F3P6 projects, the makefile should work out of the box and
# compile all source files in the src directory as well as the standard peripheral library.
#
# For other STM8S variants, please alter the following variables in the makefile:
# 	- In "Build options": Change the DEFINE variable to the appropriate STM8S variant
# 	- In "Flash Options": Change the FLASH_FLAGS variable to the appropriate STM8S variant
# 	- In "Standard Peripheral Library": Comment and uncomment the peripheral modules that apply to your STM8S variant
#	- Also adjust the linker file (elf32stm8s103f3.x) to match your STM8S variant. The section sizes can be
#	  found in the memory map section of the STM8S variant's datasheet. In the make "Build options" section,
#	  change the LD_FLAGS variable to point to the appropriate linker file.
#
# ---- Building the Project ----
#
# First, source the toolchain environment:
# 	source stm8-toolchain/env.sh
#
# The following targets are available:
# 	- make: Builds the project into a .ihx file
# 	- make flash: Flashes the .ihx file
# 	- make upload: Same as make flash
# NOTE: If you're not using a stlinkv2 programmer, please adjust the FLASH_FLAGS variable in the
#       "Flash Options" section of the makefile
#
# From here on, feel free to adjust the makefile to suit your project's needs.
#
# README README README README README README README README README README README README README README


#######################################
# Toolchain
#######################################

CC = sdcc
LD = stm8-ld
AS = stm8-as
FLASH = stm8flash
OBJCOPY = stm8-objcopy

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

# Assembler flags
AS_FLAGS =

# Compiler flags
CC_FLAGS = -mstm8 --out-fmt-elf -c --debug --opt-code-size --asm=gas --function-sections --data-sections $(INCLUDE)

# Project name
PROJECT = Template

# Build directory
BUILD_DIR = build

# Objects
OBJ_DIR = $(BUILD_DIR)/obj

# Source files
VPATH += src
SRC_FILES = $(wildcard src/*.c) # Compile all .c files in src directory
OBJECTS += $(addprefix $(OBJ_DIR)/, $(notdir $(SRC_FILES:.c=.o)))

# Linker flags
LD_FLAGS = -T./elf32stm8s103f3.x --print-memory-usage --gc-sections -Map $(OBJ_DIR)/map_$(PROJECT).map
LIB_DIRS = $(addprefix -L, /usr/local/share/sdcc/lib/stm8)

# Source dependencies:
DEPS = $(OBJECTS:.o=.d)
ASM_DEPS = $(OBJECTS:.o=.asm)

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
# by looking at the STM8S_StdPeriph_Driver/inc/stm8s.h file or

STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_adc1.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_adc2.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_awu.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_beep.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_can.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_clk.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_exti.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_flash.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_gpio.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_i2c.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_itc.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_iwdg.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_rst.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_spi.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_tim1.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_tim2.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_tim3.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_tim4.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_tim5.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_tim6.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_uart1.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_uart2.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_uart3.o)
# STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_uart4.o)
STDPERIPH_OBJECTS 	+= $(addprefix $(OBJ_DIR)/, stm8s_wwdg.o)

OBJECTS += $(STDPERIPH_OBJECTS)

#######################################
# Project targets
#######################################

$(BUILD_DIR)/$(PROJECT).ihx: $(BUILD_DIR)/$(PROJECT).elf
	$(CP) $< $@
	$(OBJCOPY) -O ihex $@ $@

# ELF file
$(BUILD_DIR)/$(PROJECT).elf: $(OBJECTS)
	@$(MKDIR) -p $(BUILD_DIR)
	$(LD) $^ -o $@ $(LD_FLAGS) $(LIBS)

$(OBJ_DIR)/%.d: %.c
	@$(MKDIR) -p $(OBJ_DIR)
	$(CC) $< $(DEFINE) $(CC_FLAGS) -MM > $@

# 
$(OBJ_DIR)/%.o: %.c $(OBJ_DIR)/%.d
	@$(MKDIR) -p $(OBJ_DIR)
	$(CC) $< $(DEFINE) $(CC_FLAGS) -o $@

# Assemble using STM8 binutils
$(OBJ_DIR)/%.o: %.asm
	@$(MKDIR) -p $(OBJ_DIR)
	$(AS) $< $(AS_FLAGS) -o $@

# Upload/Flash
flash: $(BUILD_DIR)/$(PROJECT).ihx
	$(FLASH) $(FLASH_FLAGS) -w $<

upload: flash

# Clean
clean:
	rm -rf $(OBJ_DIR)/ $(BUILD_DIR)/

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
                        help2man

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR := $(realpath -s $(dir $(mkfile_path)))
TOOLCHAIN_DIR        := $(MKFILE_DIR)/stm8-toolchain
TOOLCHAIN_BUILD_DIR  := $(TOOLCHAIN_DIR)/build
TOOLCHAIN_BIN_DIR    := $(TOOLCHAIN_DIR)/bin

STM8_BIN_UTILS_REPO  := https://github.com/XaviDCR92/stm8-binutils-gdb.git
STM8_SDCC_REPO       := https://github.com/XaviDCR92/sdcc-gas.git

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
toolchain: toolchain_start toolchain_sdcc toolchain_stm8-binutils-gdb toolchain_stm8flash toolchain_env
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
	@echo "Downloading XaviDCR92's GNU-GAS SDCC fork..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR) && \
	if [ -d sdcc-gas ]; then \
		echo "sdcc-gas already downloaded"; \
	else \
		git clone $(STM8_SDCC_REPO); \
	fi

	@echo
	@echo "Building XaviDCR92's GNU-GAS SDCC fork..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/sdcc-gas && \
	export PATH="$(TOOLCHAIN_BIN_DIR):$$PATH" && \
	./configure --prefix=$(TOOLCHAIN_DIR) && \
	$(MAKE) && \
	$(MAKE) install

toolchain_stm8-binutils-gdb:
	@echo
	@echo "Downloading XaviDCR92's STM8 binutils-gdb fork"
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR) && \
	if [ -d "stm8-binutils-gdb" ]; then \
		echo "stm8-binutils-gdb already downloaded"; \
	else \
		git clone $(STM8_BIN_UTILS_REPO); \
	fi

	@echo
	@echo "Building XaviDCR92's STM8 binutils-gdb fork..."
	@echo
	@sleep 2
	@cd $(TOOLCHAIN_BUILD_DIR)/stm8-binutils-gdb && \
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
.PHONY: clean debug