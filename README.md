# STM8 Project Template

This repository contains a template to kickstart your STM8 projects.

The template provides the STM8 standard peripheral library and a Makefile to build a toolchain, build the project, and flash the device. Once everything is set up, any source files in the `src/` directory will be compiled and linked into a firmware binary by the Makefile.

The toolchain provided by the template only includes free and open-source tools:
- [SDCC](http://sdcc.sourceforge.net/) as the compiler
- [stm8flash](https://github.com/vdudouyt/stm8flash) to flash the device
- [stm8dce](https://github.com/CTXz/STM8-DCE) for dead code elimination
- [stm8-binutils-gdb](https://stm8-binutils-gdb.sourceforge.io/) for binary utilities and debugging

The toolchain is built from source and always pulls the latest release of each of these tools.

Beyond the project template itself, this repository also publishes a Docker image with the full toolchain prebuilt, available at `ghcr.io/ctxz/stm8-toolchain`. Because compiling the toolchain from source can take 30 to 60 minutes, the prebuilt image lets you build and flash STM8 firmware right away without setting anything up on the host.

## Choosing a Workflow

There are two ways to work with this template, and you can switch between them at any time:

1. Docker workflow: the `compose.sh` wrapper runs `make` (and STM8CubeMX) inside a container using the prebuilt toolchain image. You don't install the toolchain on the host, and you don't run `make` directly. This is the quickest way to get going. See [Docker Workflow](#docker-workflow).
2. Native toolchain: you obtain the toolchain on the host and run `make` yourself. The toolchain can either be built from source on the host or pulled from the prebuilt Docker image. This gives you the standard `make` / `make upload` workflow without a container wrapper. See [Toolchain](#toolchain).

## Table of Contents

- [STM8 Project Template](#stm8-project-template)
  - [Table of Contents](#table-of-contents)
  - [Choosing a Workflow](#choosing-a-workflow)
  - [Getting Started](#getting-started)
    - [Docker Workflow](#docker-workflow)
    - [Toolchain](#toolchain)
      - [Dependencies](#dependencies)
      - [Building the Toolchain](#building-the-toolchain)
      - [Sourcing the Toolchain](#sourcing-the-toolchain)
      - [Installing the Toolchain](#installing-the-toolchain)
      - [Using the Prebuilt Docker Toolchain](#using-the-prebuilt-docker-toolchain)
    - [Preparing the Makefile](#preparing-the-makefile)
      - [Target MCU Variant](#target-mcu-variant)
      - [RAM \& Flash Size](#ram--flash-size)
      - [Flashing Options](#flashing-options)
      - [Standard Peripheral Library](#standard-peripheral-library)
    - [Building and Uploading the Project](#building-and-uploading-the-project)

## Getting Started

### Docker Workflow

The `compose.sh` wrapper can build, flash, and run STM8CubeMX without installing the toolchain or STM8CubeMX on the host. It pulls the prebuilt toolchain image, mounts the project into a container, and runs the appropriate `make` target for you, so you never have to invoke `make` directly:

```bash
$ ./compose.sh build
$ ./compose.sh flash
```

On first use, the toolchain image is pulled from `ghcr.io/ctxz/stm8-toolchain:latest`. If the pull fails (for example when offline), the wrapper falls back to building the image locally from the Dockerfile, which compiles the toolchain from source and can take 30 to 60 minutes. Any extra arguments are forwarded to `make`, for example `./compose.sh build hex`.

If you would rather run `make` yourself instead of going through the wrapper, see the [Toolchain](#toolchain) section.

To use STM8CubeMX, place the STM8CubeMX installer ZIP in the repository root. The ZIP is ignored by Git. Then build the GUI image:

```bash
$ ./compose.sh cube-image
```

The wrapper scans root-level ZIP files and accepts the one containing `SetupSTM8CubeMX-<version>.exe` and `SetupSTM8CubeMX-<version>.linux`. You can also pass it explicitly:

```bash
$ ./compose.sh cube-image --stm8cubemxzip stm8cubemx.zip
```

Start STM8CubeMX with X11/XWayland forwarding:

```bash
$ xhost +SI:localuser:$(id -un)
$ ./compose.sh stm8cubemx
```

Use `./compose.sh cube-shell` to open a shell in the STM8CubeMX container.

### Toolchain

If you prefer to run `make` directly on the host instead of using the `compose.sh` wrapper, you need the toolchain available. There are two ways to get it:

1. Build it from source on the host with `make toolchain`. This produces a self-contained toolchain under `stm8-toolchain/`, but compiling it can take 30 to 60 minutes. See [Dependencies](#dependencies) and [Building the Toolchain](#building-the-toolchain).
2. Pull the prebuilt Docker image published by this repository and run the tools from there, with no compilation on the host. See [Using the Prebuilt Docker Toolchain](#using-the-prebuilt-docker-toolchain).

The following sections are only relevant if you intend to build the toolchain yourself. If you would rather use the prebuilt toolchain, skip ahead to [Using the Prebuilt Docker Toolchain](#using-the-prebuilt-docker-toolchain).

#### Dependencies

The Makefile provides a target to build a toolchain locally, which will be installed under the `stm8-toolchain` directory in the project root. Before building the toolchain, make sure you have the following dependencies installed:

- make
- gcc
- libc
- subversion
- bison
- flex
- libboost-dev
- zlib1g-dev
- git
- texinfo
- pkg-config
- libusb-1.0-0-dev
- perl
- autoconf
- automake
- help2man
- python (3) and pip

On Ubuntu 20.04+ systems, you can install all of the above dependencies with the following make target:

```bash
$ make ubuntu_deps
```

On Debian systems, this target should also work. For other distributions, you will have to install the dependencies manually using your distro's package manager.

#### Building the Toolchain

Once the dependencies are installed, you can build the toolchain with the following command:

```bash
$ make toolchain
```

This might take a while, so feel free to grab a cup of coffee while you wait. Once the toolchain is built, it should be in the `stm8-toolchain` directory in the project root.

To save some space, clean up the build directory of the toolchain with the following command:

```bash
$ make toolchain_clean
```

#### Sourcing the Toolchain

The toolchain contains an `env.sh` script that sets the necessary environment variables to use the toolchain. To source the toolchain, run the following command:

```bash
$ source stm8-toolchain/env.sh
```

Now you should be able to use the toolchain. To test if the toolchain is working, you can run any of the following commands:

```bash
$ sdcc -v
$ stm8flash -?
$ stm8dce --version
```

The toolchain must be sourced every time you open a new terminal to be able to use it. If you want to make the toolchain available in every terminal session without having to source it manually, see the next section: [Installing the Toolchain](#installing-the-toolchain).

#### Installing the Toolchain

If you don't want to source the toolchain manually every time you open a new terminal, you can install the toolchain system-wide. We recommend copying the `stm8-toolchain` directory to `/opt`:

```bash
$ sudo cp -r stm8-toolchain /opt
```

Ensure that the toolchain is sourced on every new terminal session by adding the following line to your `.bashrc` or `.bash_profile`:

```bash
source /opt/stm8-toolchain/env.sh
```

In every new terminal session, the toolchain should now be available without having to source it manually.

#### Using the Prebuilt Docker Toolchain

If you don't want to compile the toolchain on the host, you can pull the prebuilt image instead. It ships the same toolchain that `make toolchain` would produce, installed under `/opt/stm8-toolchain`, and its entrypoint sources the environment for you so the tools are on the `PATH`:

```bash
$ docker pull ghcr.io/ctxz/stm8-toolchain:latest
```

The container expects your project to be mounted at `/project`. To build the firmware, mount the project root and run `make`:

```bash
$ docker run --rm -v "$PWD:/project" ghcr.io/ctxz/stm8-toolchain:latest make
```

To flash the device, the container additionally needs access to the USB programmer, so run it privileged and pass through the USB bus:

```bash
$ docker run --rm --privileged -v "$PWD:/project" -v /dev/bus/usb:/dev/bus/usb \
    ghcr.io/ctxz/stm8-toolchain:latest make upload
```

You can also drop into an interactive shell with the toolchain already on the `PATH`, which is handy for running the tools individually:

```bash
$ docker run --rm -it -v "$PWD:/project" ghcr.io/ctxz/stm8-toolchain:latest bash
$ sdcc -v
$ stm8flash -?
$ stm8dce --version
```

This is the same image that the `compose.sh` wrapper uses under the hood. If you want the container to handle the `docker run` plumbing for you, use the [Docker Workflow](#docker-workflow) instead.

### Preparing the Makefile

Before you can build your project, you will have to edit a couple of parameters in the Makefile to match your setup.

> Note: For STM8S103F3 devices, the `Makefile.stm8s103f3` file is already provided as an example.

#### Target MCU Variant

First, specify the target MCU variant that you're building in the following lines:

```makefile
# MCU Variant
DEFINE = -DYOUR_TARGET_VARIANT
```

Where `YOUR_TARGET_VARIANT` is the target device you're building. For example, if you're building for the STM8S103F3, you would specify: 

```makefile
# MCU Variant
DEFINE = -DSTM8S103F3
```

The target device should match the entries found in the [`stm8s.h` header](lib/STM8S_StdPeriph_Driver/inc/stm8s.h) from the standard peripheral library.

#### RAM & Flash Size 

Next, specify the RAM & Flash size of the target MCU:

```makefile
RAM_SIZE =
FLASH_SIZE =
```

The RAM & Flash size parameters are used by the Makefile to check if the firmware fits in the device's memory. As a reference, the STM8S103F3 has 1KB of RAM and 8KB of Flash:

```makefile
RAM_SIZE = 1024
FLASH_SIZE = 8096
```

#### Flashing Options

The flash options for the `stm8flash` tool must also be set:

```makefile
FLASH_FLAGS =
```

As a reference, if we are using a stlinkv2 programmer to flash a STM8S103F3 device, the flags would look like this:

```makefile
FLASH_FLAGS = -c stlinkv2 -p stm8s103f3
```

To list all supported upload programmers, you can run the following command:

```bash
$ stm8flash -?
```

And to list all supported devices, you can run the following command:

```bash
$ stm8flash -l
```

#### Standard Peripheral Library

Due to dead code elimination, all SPL modules supported by the MCU can be included in the project. However, certain peripherals may not be present on the target device, causing compilation errors. Therefore, you must uncomment all variant-supported modules in the following lines:

```makefile
# STDPER_SRC 	+= stm8s_adc1.c
# STDPER_SRC 	+= stm8s_adc2.c
# STDPER_SRC 	+= stm8s_awu.c
# STDPER_SRC 	+= stm8s_beep.c
# STDPER_SRC 	+= stm8s_can.c
# STDPER_SRC 	+= stm8s_clk.c
# STDPER_SRC 	+= stm8s_exti.c
# STDPER_SRC 	+= stm8s_flash.c
# STDPER_SRC 	+= stm8s_gpio.c
# STDPER_SRC 	+= stm8s_i2c.c
# STDPER_SRC 	+= stm8s_itc.c
# STDPER_SRC 	+= stm8s_iwdg.c
# STDPER_SRC 	+= stm8s_rst.c
# STDPER_SRC 	+= stm8s_spi.c
# STDPER_SRC 	+= stm8s_tim1.c
# STDPER_SRC 	+= stm8s_tim2.c
# STDPER_SRC 	+= stm8s_tim3.c
# STDPER_SRC 	+= stm8s_tim4.c
# STDPER_SRC 	+= stm8s_tim5.c
# STDPER_SRC 	+= stm8s_tim6.c
# STDPER_SRC 	+= stm8s_uart1.c
# STDPER_SRC 	+= stm8s_uart2.c
# STDPER_SRC 	+= stm8s_uart3.c
# STDPER_SRC 	+= stm8s_uart4.c
# STDPER_SRC 	+= stm8s_wwdg.c
```

You can get a good overview of the supported modules by looking at the [`stm8s.h` header](lib/STM8S_StdPeriph_Driver/inc/stm8s.h) from the standard peripheral library.

For the STM8S103F3, the following modules are supported:

```makefile
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
```

You will also need to uncomment all relevant include directives in the [`stm8_conf.h`](src/stm8_conf.h) file:

```c
...
// #include "stm8s_adc1.h"
// #include "stm8s_adc2.h"
// #include "stm8s_awu.h"
...
```

For the STM8S103F3, the `stm8_conf.h.stm8s103f3` file is already provided as an example.

Including all supported modules may seem a little tendious but will spare you the headache of having to uncomment the modules every time you need to use a new peripheral. Thanks to dead code elimination, the compiler will ensure to only include the necessary modules in the final firmware.

### Building and Uploading the Project

At this point, you should be able to build the blank project with the following command:

```bash
$ make
```

If everything went well, you should see a `build` directory in the project root, containing the compiled firmware as `.ihx` and `.elf` files.

To flash the device, attach the programmer and use the following command:

```bash
$ make upload
```

The firmware should now be flashed to the device.
