# STM8S Project Template <!-- omit in toc -->

This repository contains a template to kickstart your STM8S projects.

The template provides the STM8S standard peripheral library and a Makefile to build a toolchain, build the project and flash the device.
As a nice bonus, the toolchain provided by the template only bundles free and open source tools:
 - [sdcc](http://sdcc.sourceforge.net/) as the compiler
 - [stm8flash](https://github.com/vdudouyt/stm8flash) to flash the device
 - [sdccrm](https://github.com/XaviDCR92/sdccrm) for dead code elimination
 - [stm8-binutils-gdb](https://stm8-binutils-gdb.sourceforge.io/) for binary utilities and debugging

As can be seen from the list above, dead code elimination is also taken care of by the template via [sdccrm](https://github.com/XaviDCR92/sdccrm). This is very convenient because SDCC lacks native dead code elimination, causing the STM8's limited flash memory to deplete rapidly, especially when utilizing the standard peripheral library.

## Table of contents <!-- omit in toc -->

- [Getting started](#getting-started)
  - [Building the toolchain](#building-the-toolchain)
  - [Preparing the Makefile](#preparing-the-makefile)
  - [Building and uploading the project](#building-and-uploading-the-project)
- [STM8S Standard Peripheral Library](#stm8s-standard-peripheral-library)
  - [Configuring the Standard Peripheral Library: src/stm8\_conf.h](#configuring-the-standard-peripheral-library-srcstm8_confh)
  - [Prepping the interrupts: src/stm8s\_it.c, include/stm8s\_it.h](#prepping-the-interrupts-srcstm8s_itc-includestm8s_ith)
    - [A technical note on the interrupt handlers](#a-technical-note-on-the-interrupt-handlers)
- [Adding libraries](#adding-libraries)
- [VSCode](#vscode)
- [Final words](#final-words)


## Getting started

### Building the toolchain

The makefile provides a target to build a toolchain locally, which will be installed under the `stm8-toolchain` directory in the project root.
Before building the toolchain, make sure you have the following dependencies installed:

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

On Ubuntu 20.04+ systems, you can install all of the above dependencies with the following make target:

```bash
$ make ubuntu_deps
```

On debian systems, this target should likely work as well. For other distributions, you will have
to install the dependencies manually using your distro's package manager.

Once the dependencies are installed, you can build the toolchain with the following command:

```bash
$ make toolchain
```

This might take a while, so feel free to grab a cup of coffee while you wait.
Once the toolchain is built, it should be in the `stm8-toolchain` directory in the project root.

To save some space, clean up the build directory of the toolchain with the following command:

```bash
$ make toolchain_clean
```

### Preparing the Makefile

Before you can build your project, you will have to edit a couple of parameters in the Makefile to match your setup.

First, specify the target device that you're building for by setting the following parameter:

```makefile
BUILD_TARGET_DEVICE :=
```

The target device should match the entries found in the [`stm8s.h` header](lib/STM8S_StdPeriph_Driver/inc/stm8s.h) from the standard peripheral library.
This lets the standard peripheral library know which device you're building for, so it can include the correct headers for your device.
As an example, if you're building for the STM8S103 series, set the parameter to `STM8S103`.

Next, specify the RAM & Flash size, upload target device and upload programmer that you're using:

```makefile
RAM_SIZE              :=
FLASH_SIZE            :=
UPLOAD_TARGET_DEVICE  :=
UPLOAD_PROGRAMMER     :=
```

The RAM & Flash size parameters are used by the Makefile to check if the firmware fits in the device's memory.
The upload target device parameter and upload programmer parameters are used required by the flash tool to flash the device.


As an example, if we were to flash an STM8S103F3 device using an ST-Link V2 programmer, the parameters would look like this:

```makefile
RAM_SIZE             := 1024
FLASH_SIZE           := 8096
UPLOAD_TARGET_DEVICE := stm8s103f3
UPLOAD_PROGRAMMER    := stlinkv2
```

These are the supported upload target devices (at the time of writing):
```
stlux385 stlux???a stm8af526? stm8af528? stm8af52a? stm8af6213 stm8af6223 stm8af6223a stm8af6226 stm8af624? stm8af6266 stm8af6268 stm8af6269 stm8af628? stm8af62a? stm8al313? stm8al314? stm8al316? stm8al318? stm8al31e8? stm8al3l4? stm8al3l6? stm8al3l8? stm8al3le8? stm8l001j3 stm8l050j3 stm8l051f3 stm8l052c6 stm8l052r8 stm8l101f1 stm8l101?2 stm8l101?3 stm8l151?2 stm8l151?3 stm8l151?4 stm8l151?6 stm8l151?8 stm8l152?4 stm8l152?6 stm8l152?8 stm8l162?8 stm8s001j3 stm8s003?3 stm8s005?6 stm8s007c8 stm8s103f2 stm8s103?3 stm8s105?4 stm8s105?6 stm8s207c8 stm8s207cb stm8s207k8 stm8s207m8 stm8s207mb stm8s207r8 stm8s207rb stm8s207s8 stm8s207sb stm8s207?6 stm8s208c6 stm8s208r6 stm8s208s6 stm8s208?8 stm8s208?b stm8s903?3 stm8splnb1 stm8tl5??4 stnrg???a
```

You can print these out using the `stm8flash` tool from the toolchain:

```bash
$ stm8-toolchain/bin/stm8flash -l
```

These are the supported upload programmers (at the time of writing):
```
stlink, stlinkv2, stlinkv21, stlinkv3 or espstlink
```

You can find those in the help message of the `stm8flash` tool:

```bash
$ stm8-toolchain/bin/stm8flash -?
```

### Building and uploading the project

At this point, you should be able to build the blank project with the following command:

```bash
$ make
```

If everything went well, you should see a `build` directory in the project root, containing the compiled firmware as `.hex` and `.elf` file.

**Quick note regarding dead code elimination:**
This template uses [sdccrm](https://github.com/XaviDCR92/sdccrm) for dead code elimination. Unfortunately, sdccrm is not perfect and sometimes
removes code that is actually used (ex. interrupt handlers, functions called via function pointers, etc.). This will manifest itself through
missing symbol errors from the linker. If you run into this issue, you can manually exclude the missing symbols from dead code elimination 
by adding them to the `DCE_EXCLUDE` list in the Makefile. If your linker complains about missing symbols but you're certain that they're defined,
try adding them to the `DCE_EXCLUDE` list! Should that not do the trick, you can opt to exclude a whole assembly file from dead code elimination
by adding it to the `DCE_EXCLUDE_ASM` list in the Makefile.

To flash the device, attach the programmer and use the following command:

```bash
$ make upload
```

If everything went well, the flash tool should report a successful flash and your device should be running the blank firmware (i.e. do nothing).

## STM8S Standard Peripheral Library

In it's current state, the template is not very useful, since it only contains a main.c file that does nothing.
The upcoming sections provide a short introduction on how to get started with the standard peripheral library.

> Note: Feel free to skip this section if you're already familiar with the standard peripheral library.

### Configuring the Standard Peripheral Library: [src/stm8_conf.h](src/stm8_conf.h)

The [`stm8_conf.h`](src/stm8s_conf.h) header serves as a configuration file for the STM8S standard peripheral library. It contains a list of headers, or
as some refer to them, "modules", that include a variety of function calls to interact with the STM8S peripherals.

To name a few:

* `stm8s_gpio.h` - GPIOs (Ex. `GPIO_Init()`, `GPIO_WriteHigh()`, `GPIO_WriteLow()`)
* `stm8s_exti.h` - External interrupts (Ex. `EXTI_SetExtIntSensitivity()`)
* `stm8s_clk.h` - Clock (Ex. `CLK_HSIPrescalerConfig()`, `CLK_SYSCLKConfig()`, `CLK_PeripheralClockConfig()`)
* `stm8s_tim1.h` - Timer 1 (Ex. `TIM1_DeInit()`, `TIM1_TimeBaseInit()`, `TIM1_Cmd()`)
* ...

[This website](https://documentation.help/STM8S/) provides a somewhat messy reference for the STM8S standard peripheral library modules.
Alternatively, you can opt to browse through the headers yourself (For ex. [here](https://github.com/bschwand/STM8-SPL-SDCC/tree/master/Libraries/STM8S_StdPeriph_Driver/inc))

Depending on the project, you must uncomment the necessary modules you need in [`stm8_conf.h`](src/stm8s_conf.h). For example, if you want to use the GPIO functions, you
must uncomment the line:

```c
// #include "stm8s_gpio.h"
```

Please ensure beforehand that the modules you include are supported by your target device. You can check this by either looking at the device's datasheet, or by
using the STM8CubeMX tool.
To provide an example: The STM8S103 only has 1 UART peripheral, so you can only include the `stm8s_uart1.h` header. 

### Prepping the interrupts: [src/stm8s_it.c](src/stm8s_it.c), [include/stm8s_it.h](include/stm8s_it.h)

The [`stm8s_it.c`](src/stm8s_it.c) and [`stm8s_it.h`](include/stm8s_it.h) files declare and define IRQ handlers. The [`stm8s_it.h`](include/stm8s_it.h) header contains
the necessary IRQ handler prototypes and links them to their appropriate interrupt vectors. The [`stm8s_it.c`](src/stm8s_it.c) file contains the
user defined code for the IRQ handlers.

To put it simply, the [`stm8s_it.c`](src/stm8s_it.c) file is where you will write your interrupt handlers. The [`stm8s_it.h`](include/stm8s_it.h) header remains untouched and must simply be included in your main file.

> **Note:** Not including the [`stm8s_it.h`](include/stm8s_it.h) header file in your main file will result in the interrupt handlers not being called!

> **Note:** Should you not be require interrupts throughout your projects, [`stm8s_it.h`](include/stm8s_it.h) and [`stm8s_it.c`](src/stm8s_it.c) may be omitted. 
> That being said, it does not harm to keep them as they will barely take up any program space.

As an example, suppose we have a LED connected to pin `B5` (Such as the built-in LED on the generic blue STM8S103F3P6 breakout boards). We also
have a button connected to any pin on `PORTD`, with the internal pull-up resistor enabled. For the sake of simplicity, we will reserve the full `PORTD` bank for the button so that we must not test which pin was toggled.

Now we wish to toggle the LED whenever the button is released (that is, on rising edge since we have the internal pull-up resistor enabled). 

We begin by including the `stm8s_exti.h` module in our [`stm8_conf.h`](src/stm8s_conf.h) file. Uncomment the following line inside [`stm8_conf.h`](src/stm8s_conf.h):

```c
// #include "stm8s_exti.h"
```

Within our main file, we must first include the [`stm8s_it.h`](include/stm8s_it.h) header file (This template project already does so):

```c
#include "stm8s_it.h"
```

In the main function we then initialize the GPIOs and the external interrupts.

```c
int main() {
  // Initialize the GPIOs
  GPIO_Init(GPIOB, GPIO_PIN_5, GPIO_MODE_OUT_PP_LOW_FAST); // LED
  GPIO_Init(GPIOD, GPIO_PIN_ALL, GPIO_MODE_IN_PU_IT);      // Button with internal pull-up resistor and external interrupt enabled
```

We then set the external interrupt sensitivity to rising edge and enable the interrupts.

```c
  // Initialize the external interrupts
  EXTI_SetExtIntSensitivity(EXTI_PORT_GPIOD, EXTI_SENSITIVITY_RISE_ONLY);
  enableInterrupts();
```

Finally, we let the MCU loop forever.

```c
  while(TRUE);
}
```

All in all our main function should look like this:

```c
int main() {
  // Initialize the GPIOs
  GPIO_Init(GPIOB, GPIO_PIN_5, GPIO_MODE_OUT_PP_LOW_FAST); // LED
  GPIO_Init(GPIOD, GPIO_PIN_ALL, GPIO_MODE_IN_PU_IT);      // Button with internal pull-up resistor and external interrupt enabled

  // Initialize the external interrupts
  EXTI_SetExtIntSensitivity(EXTI_PORT_GPIOD, EXTI_SENSITIVITY_RISE_ONLY);
  enableInterrupts();

  while(TRUE);
}
```

Now for the last part, we must write the interrupt handler. Within the [`stm8s_it.c`](src/stm8s_it.c) file, search for the following handler:

```c
/**
  * @brief External Interrupt PORTD Interrupt routine.
  * @param  None
  * @retval None
  */
INTERRUPT_HANDLER(EXTI_PORTD_IRQHandler, 6)
{
  /* In order to detect unexpected events during development,
     it is recommended to set a breakpoint on the following instruction.
  */
}
```

Within the function, we simply toggle the LED pin.

```c
/**
  * @brief External Interrupt PORTD Interrupt routine.
  * @param  None
  * @retval None
  */
INTERRUPT_HANDLER(EXTI_PORTD_IRQHandler, 6)
{
     GPIO_WriteReverse(GPIOB, GPIO_PIN_5);
}
```

And that's it! Our LED should now toggle whenever the button is released.

#### A technical note on the interrupt handlers

The procedures above may seem a bit convoluted. Why do we need to declare the interrupt handlers in the [`stm8s_it.h`](include/stm8s_it.h) file and then define them in the [`stm8s_it.c`](src/stm8s_it.c) file? Why can't we just define the interrupt handlers in the main file?

In theory we can ommit the `stm8s_it` files and declare the handler within the main file using the `INTERRUPT_HANDLER` macro, declared in `stm8s.h`, which for SDCC expands to:
```c
 #define INTERRUPT_HANDLER(a,b) void a() __interrupt(b)
```

with `a` being the name of the handler, which may be user defined, and `b` being the interrupt vector number. A overview of the interrupt vectors along with their IRQ number and meaning can be found in the "Interupt Vector Mapping" section of your STM8's specific datasheet.

If cross-compiler compatibility is not a concern, then you can also opt to use the SDCC specific interrupt handler declaration to which the `INTERRUPT_HANDLER` macro expands to.

That being said, while we can define the interrupt handlers in the main file, keeping them seperated in the `stm8_it.c` file not only ensures that the developer knows where to look for the interrupt handlers, but also provides a handy reference for the interrupt vectors so that one must not always refer to the datasheet.

## Adding libraries

To add libraries to your project, first add the library files to the [`lib`](lib) folder. Within the makefile, you will find numerous commented out
definitions that start with `EXAMPLELIB_`. With a bit of makefile knowledge, these should provide a decemt example on how to add libraries to your project.

## VSCode

While this template project is not specifically designed for VSCode, it does include a `.vscode` folder with a `tasks.json` file that allows you to comfortably run the `build`, `clean` and `upload` targets from within VSCode. To execute a task, simply press `Ctrl+Shift+P` and type `Run Task`. You will then be presented with a list of available tasks. Alternatively you can use extensions such as [Task Explorer](https://marketplace.visualstudio.com/items?itemName=spmeesseman.vscode-taskexplorer) to run tasks from within the sidebar.

## Final words

Hopefully this template project will help you get started with your STM8 projects without having to spend uncessary time on setting up a working environment.

Obviously you can feel free to alter the makefile according to your needs. I also must admit that I suck at makefiles, so if you have any suggestions, feel free to open an issue or a pull request.