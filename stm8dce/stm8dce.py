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
        self.calls_str = []
        self.calls = []
        self.mem_loads_str = []
        self.constants = []
        self.start_line = start_line
        self.end_line = None
        self.global_defs = []
        self.isr_def = None
        self.empty = True

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    def print(self):
        print("Function:", self.name)
        print("File:", self.path)
        print("Calls:", self.calls_str)
        print("Loads:", self.loads)
        print("Start line:", self.start_line)
        print("End line:", self.end_line)
        print("IRQ Handler:", self.isr)

    def resolve_globals(self, globals):
        # Get all matching global definitions
        for g in globals:
            if g.name == self.name:
                self.global_defs.append(g)
                if DEBUG:
                    print(
                        "Global in {}:{} matched to function {} in {}:{}".format(
                            g.path,
                            g.line,
                            self.name,
                            self.path,
                            self.start_line,
                        )
                    )

    def resolve_isr(self, interrupts):
        # Get all matching interrupt definitions
        for i in interrupts:
            if i.name == self.name:
                self.isr_def = i
                if DEBUG:
                    print(
                        "Interrupt {}:{} matched to function {} in {}:{}".format(
                            i.path, i.line, self.name, self.path, self.start_line
                        )
                    )

    # Precondition: Globals of all functions have been resolved first
    def resolve_calls(self, functions):
        # Get all matching functions called by this function
        for c in self.calls_str:
            funcs = functions_by_name(functions, c)

            # Check if either is defined globally/not-static
            glob = False
            for f in funcs:
                if f.global_defs:
                    glob = True
                    break

            # If function is defined globally, there can only be one instance!
            if glob:
                if len(funcs) > 1:
                    print("Error: Conflicting definitions for non-static function:", c)
                    for f in funcs:
                        print("In file {}:{}".format(f.path, f.start_line))
                    exit(1)
                self.calls.append(funcs[0])
                if DEBUG:
                    print(
                        "Function {} in {}:{} calls function {} in {}:{}".format(
                            self.name,
                            self.path,
                            self.start_line,
                            funcs[0].name,
                            funcs[0].path,
                            funcs[0].start_line,
                        )
                    )
            # Alternatively, there may be multiple static definitions
            # if so, choose the function within the same file
            else:
                matched = False
                for f in funcs:
                    if f.path == self.path:
                        if matched:
                            print(
                                "Error: Multiple static definitions for function {} in {}".format(
                                    f, f.path
                                )
                            )
                            exit(1)

                        self.calls.append(f)

                        if DEBUG:
                            print(
                                "Function {} in {}:{} calls static function {} in {}:{}".format(
                                    self.name,
                                    self.path,
                                    self.start_line,
                                    f.name,
                                    f.path,
                                    f.start_line,
                                )
                            )

    def resolve_constants(self, constants):
        for c in self.mem_loads_str:
            consts = constants_by_name(constants, c)

            glob = False
            for c in consts:
                if c.global_defs:
                    glob = True
                    break

            if glob:
                if len(consts) > 1:
                    print("Error: Conflicting definitions for global constant:", c)
                    for c in consts:
                        print("In file {}:{}".format(c.path, c.start_line))
                    exit(1)
                self.constants.append(consts[0])
                if DEBUG:
                    print(
                        "Function {} in {}:{} loads global constant {} in {}:{}".format(
                            self.name,
                            self.path,
                            self.start_line,
                            c,
                            consts[0].path,
                            consts[0].start_line,
                        )
                    )
            else:
                for c in consts:
                    if c.path == self.path:
                        self.constants.append(c)
                        if DEBUG:
                            print(
                                "Function {} in {}:{} loads local constant {} in {}:{}".format(
                                    self.name,
                                    self.path,
                                    self.start_line,
                                    c,
                                    consts[0].path,
                                    consts[0].start_line,
                                )
                            )


# Class to store constant definitions
class Constant:
    def __init__(self, path, name, start_line):
        self.path = path
        self.name = name
        self.start_line = start_line
        self.end_line = None
        self.global_defs = []

    def __str__(self):
        return self.name

    def __repr__(self):
        return self.name

    def print(self):
        print("Constant:", self.name)
        print("File:", self.path)
        print("Start line:", self.start_line)
        print("End line:", self.end_line)

    def resolve_globals(self, globals):
        # Get all matching global definitions
        for g in globals:
            if g.name == self.name:
                self.global_defs.append(g)
                if DEBUG:
                    print(
                        "Global in {}:{} matched to constant {} in {}:{}".format(
                            g.path,
                            g.line,
                            self.name,
                            self.path,
                            self.start_line,
                        )
                    )


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


# Returns if the line is a function label
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


# Returns if the line is a constant label
# Precondition: line is in constants section
# Critera for a constant label:
#   - Same as function label
def is_constant_label(line):
    return is_function_label(line)


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
def is_global_defs(line):
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


# Returns if the line is a load with a label
# as src
# Criteria for a load:
#   - Start with 'ld' or 'ldw' or 'ldf'
#   - Dst (Left) and src (Right) are separated by ','
#   - Src must contain a label appended with a + and a number (e.g., _label+1)
def is_load_src_label(line):
    sline = remove_comments(line.strip())
    if not (
        sline.startswith("ld") or sline.startswith("ldw") or sline.startswith("ldf")
    ):
        return None

    if "," not in sline:
        return None

    src = sline.split(",")[1].strip()
    if "+" not in src:
        return None

    label = src.split("+")[0].strip()
    # Label might currently include parantheses etc.
    # Remove them until we get to the actual label
    for i in range(len(label)):
        if label[i].isalnum() or label[i] == "_":
            return label[i:]

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
        if call and (call not in ret.calls_str):
            if DEBUG:
                print("Line {}: Call to {}".format(fileit.index, call))
            ret.calls_str.append(call)
            continue

        # Keep track of loads with labels as src (these are likely constants)
        load = is_load_src_label(line)
        if load and (load not in ret.mem_loads_str):
            if DEBUG:
                print("Line {}: Load with label as src {}".format(fileit.index, load))
            ret.mem_loads_str.append(load)
            continue

    if DEBUG:
        if ret.empty:
            print("Line {}: Function {} is empty!".format(fileit.index, label))
        print("Line {}: Function {} ends here".format(fileit.index, label))

    return ret


def parse_constant(fileit, label):
    if DEBUG:
        print("Line {}: Constant {} starts here".format(fileit.index, label))

    ret = Constant(fileit.path, label, fileit.index)
    while True:
        try:
            line = next(fileit)
        except StopIteration:
            break

        # Ignore comments
        if is_comment(line):
            continue

        # Check if this is the end of the constant
        if is_constant_label(line) or is_area(line):
            # Set back as this line is not part of the constant
            fileit.prev()
            ret.end_line = fileit.index
            break

    if DEBUG:
        print("Line {}: Constant {} ends here".format(fileit.index, label))

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
            fileit.prev()  # Set back as this line is not part of the code section
            break

        flabel = is_function_label(line)
        if flabel:
            functions += [parse_function(fileit, flabel)]

    if DEBUG:
        print("Line {}: Code section ends here".format(fileit.index))

    return functions


def parse_const_section(fileit):
    if DEBUG:
        print("Line {}: Constants section starts here".format(fileit.index))

    constants = []
    while True:
        try:
            line = next(fileit)
        except StopIteration:
            break

        area = is_area(line)
        if area:
            fileit.prev()  # Set back as this line is not part of the constants section
            break

        clabel = is_constant_label(line)
        if clabel:
            constants += [parse_constant(fileit, clabel)]

    if DEBUG:
        print("Line {}: Constants section ends here".format(fileit.index))

    return constants


# Parses the file iterator and returns a list of:
#   - Function objects
#   - GlobalDef objects
#   - IntDef objects
#   - Constant objects
# Parsing includes:
#   - Detecting global definitions
#   - Detecting and parsing code sections
def parse(fileit):
    globals = []
    interrupts = []
    functions = []
    constants = []
    while True:
        try:
            line = next(fileit)
        except StopIteration:
            break

        # Global definitions
        global_defs = is_global_defs(line)
        if global_defs:
            globals.append(GlobalDef(fileit.path, global_defs, fileit.index))

            if DEBUG:
                print("Line {}: Global definition {}".format(fileit.index, global_defs))

            continue

        # Interrupt definitions
        int_def = is_int_def(line)
        if int_def:
            interrupts.append(IntDef(fileit.path, int_def, fileit.index))

            if DEBUG:
                print("Line {}: Interrupt definition {}".format(fileit.index, int_def))

            continue

        # Code section
        area = is_area(line)
        if area == "CODE":
            functions += parse_code_section(fileit)

        # Constants section
        if area == "CONST":
            constants += parse_const_section(fileit)

    return globals, interrupts, constants, functions


# Parses a file and returns a list of:
#   - Function objects
#   - GlobalDef objects
#   - IntDef objects
#   - Constant objects
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


# Returns the a list of function objects matching
# by name from a list of functions
def functions_by_name(functions, name):
    ret = []
    for f in functions:
        if f.name == name:
            ret.append(f)
    return ret


# Returns the a function object matching
# by filename and name from a list of functions
def function_by_filename_name(functions, filename, name):
    ret = None
    for f in functions:
        f_filename = f.path.split("/")[-1]
        if f_filename == filename and f.name == name:
            if ret:
                print("Error: Multiple definitions for function:", name)
                print("In file {}:{}".format(f.path, f.start_line))
                exit(1)
            ret = f
    return ret


# Returns the a list of constant objects matching
# by name from a list of constants
def constants_by_name(constants, name):
    ret = []
    for c in constants:
        if c.name == name:
            ret.append(c)
    return ret


# Traverse all calls made by a function and return a list of
# all functions
def traverse_calls(functions, top):
    if DEBUG:
        print("Traversing in {} in {}:{}".format(top.name, top.path, top.start_line))

    ret = []

    for call in top.calls:
        # Prevent infinite recursion
        if call == top:
            continue

        ret += [call] + traverse_calls(functions, call)

    if DEBUG:
        print("Traversing out {} in {}:{}".format(top.name, top.path, top.start_line))

    return ret


# Returns a list of all interrupt handlers in the list of functions
def interrupt_handlers(functions):
    ret = []
    for f in functions:
        if f.isr_def:
            ret.append(f)
    return ret


############################################
# Arg Parsing
############################################


# Evaluate a function label for exclusion
# User can either specify function label
# as is (ex. _hello), or with its filename
# (ex. file.asm:_hello) to allow exclusiong
# for cases where multiple functions have
# the same name
# Returns a tuple of filename and name
# if filename is not specified, filename is None
def eval_flabel(flabel):
    if ":" in flabel:
        filename, name = flabel.split(":")
        return filename, name
    return None, flabel


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
    constants = []
    for file in os.listdir(args.output):
        if file.endswith(".asm"):
            g, i, c, f = parse_file(args.output + "/" + file)
            globals += g
            interrupts += i
            constants += c
            functions += f

    # Resolve globals assigned to functions
    if DEBUG:
        print()
        print("Resolving globals assigned to functions")
        pseperator()

    for f in functions:
        f.resolve_globals(globals)

    # Resolve interrupts
    if DEBUG:
        print()
        print("Resolving interrupts")
        pseperator()

    for f in functions:
        f.resolve_isr(interrupts)

    # Resolve function calls
    if DEBUG:
        print()
        print("Resolving function calls")
        pseperator()

    for f in functions:
        f.resolve_calls(functions)

    # Resolve globals assigned to constants
    if DEBUG:
        print()
        print("Resolving globals assigned to constants")
        pseperator()

    for c in constants:
        c.resolve_globals(globals)

    # Resolve constants loaded by functions
    if DEBUG:
        print()
        print("Resolving constants loaded by functions")
        pseperator()

    for f in functions:
        f.resolve_constants(constants)

    # Get entry function object
    mainf = functions_by_name(functions, args.entry)
    if not mainf:
        print("Error: Entry label not found:", args.entry)
        exit(1)
    elif len(mainf) > 1:
        print("Error: Multiple definitions for entry label:", args.entry)
        for f in mainf:
            print("In file {}:{}".format(f.path, f.start_line))
        exit(1)

    mainf = mainf[0]

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
            filename, name = eval_flabel(name)
            if filename:
                f = function_by_filename_name(functions, filename, name)
            else:
                f = functions_by_name(functions, name)
                if len(f) > 1:
                    print(
                        "Error: Multiple possible definitions excluded for function:",
                        name,
                    )
                    for f in f:
                        print("In file {}:{}".format(f.path, f.start_line))
                    print(
                        "Please use the format file.asm:label to specify the exact function to exclude"
                    )
                    exit(1)
                f = f[0]

            if f and (f not in keep):
                if DEBUG:
                    print()
                    print("Traversing excluded function:", name)
                    pseperator()
                keep += [f] + traverse_calls(functions, f)

    # Remove duplicates
    keep = list(set(keep))

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

    # Remove constants that are not used
    removec = constants.copy()
    for c in constants:
        for f in keep:
            if c in f.constants:
                removec.remove(c)
                break

    # Remove global labels assigned to removed constants
    removeg += [g for c in removec for g in c.global_defs]

    if VERBOSE:
        print()
        print("Removing functions:")
        for f in removef:
            print("\t{} - {}:{}".format(f.name, f.path, f.start_line))
        print()
        print("Removing Constants:")
        for c in removec:
            print("\t{} - {}:{}".format(c.name, c.path, c.start_line))
        print()

    # Group functions, globals, int defs and constants by file to reduce file I/O
    filef = {}
    fileg = {}
    filei = {}
    filec = {}
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
    for c in removec:
        if c.path not in filec:
            filec[c.path] = []
        filec[c.path].append(c)

    # Remove (comment out) unused functions,
    # global definitions, interrupt definitions
    # and constants from the files
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

        # Constants
        if file in filec:
            for c in filec[file]:
                for i in range(c.start_line - 1, c.end_line):
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

    # Remove any remaining constants
    for file in filec:
        with open(file, "r") as f:
            lines = f.readlines()

        for c in filec[file]:
            for i in range(c.start_line - 1, c.end_line):
                lines[i] = ";" + lines[i]

        with open(file, "w") as f:
            f.writelines(lines)

    print("Detected and removed:")
    print(
        "{} unused functions from a total of {} functions".format(
            len(removef), len(functions)
        )
    )
    print(
        "{} unused constants from a total of {} constants".format(
            len(removec), len(constants)
        )
    )


if __name__ == "__main__":
    main()
