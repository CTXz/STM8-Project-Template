#!/usr/bin/env python3

# Copyright (C) 2024 Patrick Pedersen

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# SDCC STM8 Dead Code Elimination Tool
# Description: Accepts a list of SDCC generated ASM files for the
#              STM8 and removes unused functions from the code.
#
# Note: This tool still requires some more testing! Use at your own risk!

# This tool has been largely inspired by XaviDCR92's sdccrm tool:
#   https://github.com/XaviDCR92/sdccrm
#
# Due to sdccrm's deprecated status, it was written from scratch rather
# than being a fork of sdccrm. It aims to be more compatible with newer
# versions of SDCC (currently tested with 4.4.1) and attempts to provide
# a couple more improvements (e.g., IRQ handler detection). Additionally,
# the tool is written in Python, which I personally find to be more suitable
# for pattern matching and text processing tasks.
#
# XaviDCR92's sdccrm tool has been deprecated in favor of using their GNU Assembly-compatible
# SDCC fork for the STM8 along with their stm8-binutils fork to perform linking-time dead code
# elimination. I found that approach to sound good in theory, but in practice, the implementation
# comes with numerous flaws, such as being incompatible with newer versions of SDCC, and the
# fact that SDCC's standard library has to be compiled manually. Even once the standard library
# has been compiled, it uses platform-independent C code, which is not as optimized as the platform-
# specific assembly functions tailored for the STM8.

import os
import argparse
import shutil
from enum import Enum

############################################
# Globals
############################################

VERBOSE = False
DEBUG = False
OPT_IRQ = False
VERSION = "0.0.1"

############################################
# Classes
############################################


# Class to iterate over lines in a file
# Includes a prev() function to go back one line
class FileIterator:
    def __init__(self, f):
        self.path = f.name
        self.iterable = f.readlines()
        self.index = 0

    def __iter__(self):
        return self

    def __next__(self):
        if self.index < len(self.iterable):
            ret = self.iterable[self.index]
            self.index += 1
            return ret
        else:
            raise StopIteration

    def prev(self):
        if self.index > 0:
            self.index -= 1
            return self.iterable[self.index]
        else:
            raise StopIteration


# Class to store global definitions
# Includes:
#  - Path of the file the global is defined in
#  - Name of the global
#  - Line number of the global definition
class GlobalDef:
    def __init__(self, path, name, line):
        self.path = path
        self.name = name
        self.line = line

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    def print(self):
        print("Global:", self.name)
        print("File:", self.path)
        print("Line:", self.line)


# Class to store interrupt definitions
# Equivalent to GlobalDef, but prints differently
class IntDef:
    def __init__(self, path, name, line):
        self.path = path
        self.name = name
        self.line = line

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    def print(self):
        print("Interrupt:", self.name)
        print("File:", self.path)
        print("Line:", self.line)


# Class to store function definitions
# Includes:
#  - Path of the file the function is defined in
#  - Name of the function
#  - List of calls made by the function
#  - Start line of the function
#  - End line of the function
#  - Global definition/label assinged to the function
#  - If the function is an IRQ handler
#  - If the function is empty
class Function:
    def __init__(self, path, name, start_line):
        self.path = path
        self.name = name
        self.calls = []
        self.start_line = start_line
        self.end_line = None
        self.global_defs = []
        self.isr = False
        self.isr_def = None
        self.empty = True

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    def print(self):
        print("Function:", self.name)
        print("File:", self.path)
        print("Calls:", self.calls)
        print("Start line:", self.start_line)
        print("End line:", self.end_line)
        print("IRQ Handler:", self.isr)


############################################
# Debug Output
############################################


# Prints a seperator line for better debug output readability
def pseperator():
    print(
        "========================================================================================="
    )


############################################
# Pattern Matching
############################################


# Removes comments from a line
# This is used to prevent comments from
# polluting the pattern matching
# Criteria for a comment:
#   - Starts at ';'
def remove_comments(line):
    return line.split(";")[0].strip()


# Returns if the line is a comment
# Criteria for a comment:
#   - Start with ';'
def is_comment(line):
    return line.strip().startswith(";")


# Precondition: line is in code section
# Critera for a function label:
#   - Is not a comment
#   - Ends with ':'
#   - Second last character is not a '$' (nnnnn$ are local labels)
def is_function_label(line):
    sline = line.strip()

    if is_comment(sline):
        return None

    sline = remove_comments(sline)

    if sline.endswith(":") and sline[-2] != "$":
        return sline[:-1]


# Preconditions: line is after a function label
# Returns the call target if the line is a call
# instruction, None otherwise
# Critera for a call:
#   - Starts with 'call'
# or
#   - Starts with 'jp'
#   - Followed by a label which:
#       - Starts with _ or a letter
#       - Only contains letters, numbers, and '_'


def is_call(line):
    sline = remove_comments(line.strip())

    if sline.startswith("call"):
        return sline.split("call")[1].strip()

    if sline.startswith("jp"):
        label = sline.split("jp")[1].strip()
        if not (label.startswith("_") or label[0].isalpha()):
            return None
        if all(c.isalnum() or c == "_" for c in label):
            return label

    return None


# Preconditions: line is after a function label
# Returns if the line marks a interrupt return
# Critera for a interrupt return:
#   - Is 'iret'
def is_iret(line):
    sline = remove_comments(line.strip())
    if sline == "iret":
        return True
    return False


# Returns if the line is an area directive
# and which area it is
# Criteria for an area directive:
#   - Start with '.area'
def is_area(line):
    sline = remove_comments(line.strip())
    if sline.startswith(".area"):
        return sline.split(".area")[1].strip()
    return None


# Returns if the line is a global definition
# and the name of the global if it is one
# Critera for a global definition:
#   - Start with '.globl'
def is_global_def(line):
    sline = remove_comments(line.strip())
    if sline.startswith(".globl"):
        return sline.split(".globl")[1].strip()
    return None


# Returns if the line is an interrupt definition
# and the name of the interrupt if it is one
# Critera for an interrupt definition:
#   - Start with 'int'
def is_int_def(line):
    sline = remove_comments(line.strip())
    if sline.startswith("int"):
        return sline.split("int")[1].strip()
    return None


############################################
# Parsing
############################################


# Parses a function and returns a Function object
# Parsing includes:
#  - Detecting calls made by the function
#  - Detecting if the function is empty
#  - Detecting if the function is an IRQ handler
#  - Detecting the end of the function
def parse_function(fileit, label):
    if DEBUG:
        print("Line {}: Function {} starts here".format(fileit.index, label))

    ret = Function(fileit.path, label, fileit.index)
    while True:
        try:
            line = next(fileit)
        except StopIteration:
            break

        # Ignore comments
        if is_comment(line):
            continue

        # Check if this is an IRQ handler
        if is_iret(line):
            if DEBUG:
                print(
                    "Line {}: Function {} detected as IRQ Handler".format(
                        fileit.index, label
                    )
                )
            ret.isr = True
            continue

        # Check if this is the end of the function
        if is_function_label(line) or is_area(line):
            # Set back as this line is not part of the function
            fileit.prev()
            ret.end_line = fileit.index
            break

        # From here on we can assume the function is not empty
        ret.empty = False

        # Keep track of calls made by this function
        call = is_call(line)
        if call and (call not in ret.calls):
            if DEBUG:
                print("Line {}: Call to {}".format(fileit.index, call))
            ret.calls.append(call)
            continue

    if DEBUG:
        if ret.empty:
            print("Line {}: Function {} is empty!".format(fileit.index, label))
        print("Line {}: Function {} ends here".format(fileit.index, label))

    return ret


# Parses the code section of the file
# Returns a list of Function objects within the code section
# Parsing includes:
#  - Detecting and parsing functions
#  - Detecting end of code section
def parse_code_section(fileit):
    if DEBUG:
        print("Line {}: Code section starts here".format(fileit.index))

    functions = []
    while True:
        try:
            line = next(fileit)
        except StopIteration:
            break

        area = is_area(line)
        if area:
            break

        flabel = is_function_label(line)
        if flabel:
            functions += [parse_function(fileit, flabel)]

    if DEBUG:
        print("Line {}: Code section ends here".format(fileit.index))

    return functions


# Parses the file iterator and returns a list of:
#   - Function objects
#   - GlobalDef objects
#   - IntDef objects
# Parsing includes:
#   - Detecting global definitions
#   - Detecting and parsing code sections
def parse(fileit):
    globals = []
    interrupts = []
    functions = []

    while True:
        try:
            line = next(fileit)
        except StopIteration:
            break

        # Global definitions
        global_def = is_global_def(line)
        if global_def:
            globals.append(GlobalDef(fileit.path, global_def, fileit.index))

            if DEBUG:
                print("Line {}: Global definition {}".format(fileit.index, global_def))

            continue

        # Interrupt definitions
        int_def = is_int_def(line)
        if int_def:
            interrupts.append(IntDef(fileit.path, int_def, fileit.index))

            if DEBUG:
                print("Line {}: Interrupt definition {}".format(fileit.index, int_def))

            continue

        area = is_area(line)
        if area == "CODE":
            functions += parse_code_section(fileit)

    return globals, interrupts, functions


# Parses a file and returns a list of:
#   - Function objects
#   - GlobalDef objects
#   - IntDef objects
# This function opens the file and creates a FileIterator
# The actual parsing is done by the parse() function
def parse_file(file):
    if DEBUG:
        print()
        print("Parsing file:", file)
        pseperator()

    with open(file, "r") as f:
        fileit = FileIterator(f)
        return parse(fileit)


############################################
# Function Object Operations
############################################


# Returns the function object with the given name
# from a list of functions
def function_by_name(functions, name):
    for f in functions:
        if f.name == name:
            return f
    return None


# Traverse all calls made by a function and return a list of
# all functions
def traverse_calls(functions, top):
    if DEBUG:
        print("Traversing into:", top.name)

    ret = []

    if not top:
        return ret

    for call in top.calls:
        f = function_by_name(functions, call)
        if f and (f not in ret):
            ret += [f] + traverse_calls(functions, f)

    if DEBUG:
        print("Traversing out of:", top.name)

    return ret


# Returns a list of all interrupt handlers in the list of functions
def interrupt_handlers(functions):
    ret = []
    for f in functions:
        if f.isr:
            ret.append(f)
    return ret


############################################
# Main
############################################


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description="STM8 SDCC dead code elimination tool")
    parser.add_argument("input", nargs="+", help="ASM files to process", type=str)
    parser.add_argument("-o", "--output", help="Output directory", required=True)
    parser.add_argument(
        "-e", "--entry", help="Entry function", type=str, default="_main"
    )
    parser.add_argument(
        "-x", "--exclude", help="Exclude functions", type=str, nargs="+"
    )
    parser.add_argument("-v", "--verbose", help="Verbose output", action="store_true")
    parser.add_argument("-d", "--debug", help="Debug output", action="store_true")
    parser.add_argument("--version", action="version", version="%(prog)s " + VERSION)
    parser.add_argument(
        "--opt-irq",
        help="Remove unused IRQ handlers (Caution: Removes iret's for unsued interrupts!)",
        action="store_true",
    )
    args = parser.parse_args()

    global VERBOSE
    VERBOSE = args.verbose or args.debug

    global DEBUG
    DEBUG = args.debug

    global OPT_IRQ
    OPT_IRQ = args.opt_irq

    # Check if output directory exists
    if not os.path.exists(args.output):
        print("Error: Output directory does not exist:", args.output)

    # Copy all files to args.output directory
    # input are files seperated by space
    for file in args.input:
        shutil.copy(file, args.output)

    # Parse all asm files for functions
    # functions is a list of Function objects and
    # globals is a list of GlobalDef objects
    globals = []
    interrupts = []
    functions = []
    for file in os.listdir(args.output):
        if file.endswith(".asm"):
            g, i, f = parse_file(args.output + "/" + file)
            globals += g
            interrupts += i
            functions += f

    # Assign GlobalDef objects to their respective functions
    for g in globals:
        f = function_by_name(functions, g.name)
        if f:
            f.global_defs.append(g)

    # Assign IntDef objects to their respective functions
    for i in interrupts:
        f = function_by_name(functions, i.name)
        if f:
            f.isr_def = i

    # Get entry function object
    mainf = function_by_name(functions, args.entry)
    if not mainf:
        print("Error: Entry label not found:", args.entry)
        exit(1)

    # Keep main function and all of its traversed calls
    if DEBUG:
        print()
        print("Traversing entry function:", args.entry)
        pseperator()
    keep = [mainf] + traverse_calls(functions, mainf)

    # Keep interrupt handlers and all of their traversed calls
    # but exclude unused IRQ handlers if opted by the user
    ihandlers = interrupt_handlers(functions)
    for ih in ihandlers:
        if OPT_IRQ and ih.empty:
            continue
        if DEBUG:
            print()
            print("Traversing IRQ handler:", ih.name)
            pseperator()
        keep += [ih] + traverse_calls(functions, ih)

    # Keep functions excluded by the user and all of their traversed calls
    if args.exclude:
        for name in args.exclude:
            f = function_by_name(functions, name)
            if f and (f not in keep):
                if DEBUG:
                    print()
                    print("Traversing excluded function:", name)
                    pseperator()
                keep += [f] + traverse_calls(functions, f)

    # Remove duplicates
    keep = list(set(keep))

    if VERBOSE:
        print()
        print("Keeping functions:")
        for f in keep:
            print("\t", f)
        print()

    # Remove functions that are not in keep
    removef = [f for f in functions if f not in keep]

    # Remove global labels assigned to removed functions
    removeg = []
    for f in removef:
        removeg += f.global_defs

    # Remove interrupt definitions assigned to removed IRQ handlers
    removei = []
    for f in removef:
        if f.isr_def:
            removei.append(f.isr_def)

    if VERBOSE:
        print("Removing functions:")
        for f in removef:
            print("\t", f)
        print()

    # Group functions, globals and int defs by file to reduce file I/O
    filef = {}
    fileg = {}
    filei = {}
    for f in removef:
        if f.path not in filef:
            filef[f.path] = []
        filef[f.path].append(f)
    for g in removeg:
        if g.path not in fileg:
            fileg[g.path] = []
        fileg[g.path].append(g)
    for i in removei:
        if i.path not in filei:
            filei[i.path] = []
        filei[i.path].append(i)

    # Remove (comment out) unused functions,
    # global definitions and interrupt definitions
    for file in filef:
        with open(file, "r") as f:
            lines = f.readlines()

        # Global definitions
        if file in fileg:
            for g in fileg[file]:
                lines[g.line - 1] = ";" + lines[g.line - 1]
            fileg[file].remove(g)

        # Interrupt definitions
        # These must be set to 0x000000 instead of being commented out.
        # else remaining IRQ handlers will be moved to a different VTABLE
        # entry!
        if file in filei:
            for i in filei[file]:
                lines[i.line - 1] = "	int 0x000000\n"
            filei[file].remove(i)

        # Functions
        if file in filef:
            for f in filef[file]:
                for i in range(f.start_line - 1, f.end_line):
                    lines[i] = ";" + lines[i]

        with open(file, "w") as f:
            f.writelines(lines)

    # Remove any remaing global definitions
    # assigned to removed functions
    # This catches any global labels that import unused
    # functions from other files
    for file in fileg:
        with open(file, "r") as f:
            lines = f.readlines()

        for g in fileg[file]:
            lines[g.line - 1] = ";" + lines[g.line - 1]

        with open(file, "w") as f:
            f.writelines(lines)

    # Remove interrupt definitions assigned to removed IRQ handlers
    # if they haven't already been removed
    for file in filei:
        with open(file, "r") as f:
            lines = f.readlines()

        for i in filei[file]:
            lines[i.line - 1] = "	int 0x000000\n"

        with open(file, "w") as f:
            f.writelines(lines)

    print(
        "Detected and removed {} unused functions from a total of {} functions".format(
            len(removef), len(functions)
        )
    )


if __name__ == "__main__":
    main()