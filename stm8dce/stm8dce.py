#!/usr/bin/env python3

import os
import argparse
import shutil
from enum import Enum

# SDCC dead code elimination tool for STM8


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


class Function:
    def __init__(self, path, name, start_line):
        self.path = path
        self.name = name
        self.calls = []
        self.start_line = start_line
        self.end_line = None
        self.global_def = None
        self.isr = False

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
        if self.global_def:
            print("Global def:", self.global_def.line)


def is_comment(line):
    return line.strip().startswith(";")


# Precondition: line is in code section
# Conditions for a function label:
# 0. Is not a comment
# 1. Ends with a colon
# 2. Second last character is not a $ (nnnnn$ are local labels)
def is_function_label(line):
    sline = line.strip()

    if is_comment(line):
        return None

    if sline.endswith(":") and sline[-2] != "$":
        return sline[:-1]


# Preconditions: line is after a function label
# Returns the call target if the line is a call
# instruction, None otherwise
# Conditions for a call:
# 0. call instruction
def is_call(line):
    sline = line.strip()
    if sline.startswith("call"):
        return sline.split("call")[1].strip()
    return None


# Preconditions: line is after a function label
# Returns if the line marks a interrupt return
# Conditions for a interrupt return:
# 0. iret instruction
def is_iret(line):
    sline = line.strip()
    if sline.startswith("iret"):
        return True
    return False


# Returns if the line is an area directive
# and which area it is
def is_area(line):
    sline = line.strip()
    if sline.startswith(".area"):
        return sline.split(".area")[1].strip()
    return None


# Returns if the line is a global definition
# and the name of the global if it is one
# Conditions for a global definition:
# 0. Start with .globl directive
def is_global_def(line):
    sline = line.strip()
    if sline.startswith(".globl"):
        return sline.split(".globl")[1].strip()
    return None


def parse_function(fileit, label):
    ret = Function(fileit.path, label, fileit.index)
    while True:
        try:
            line = next(fileit)
        except StopIteration:
            break

        call = is_call(line)
        if call and (call not in ret.calls):
            ret.calls.append(call)
            continue

        if is_iret(line):
            ret.isr = True
            continue

        if is_function_label(line) or is_area(line):
            # Set back as this line is not part of the function
            fileit.prev()
            ret.end_line = fileit.index
            break

    return ret


def parse_code_section(fileit):
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

    return functions


def parse(fileit):
    globals = []
    functions = []

    while True:
        try:
            line = next(fileit)
        except StopIteration:
            break

        global_def = is_global_def(line)
        if global_def:
            globals.append(GlobalDef(fileit.path, global_def, fileit.index))
            continue

        area = is_area(line)
        if area == "CODE":
            functions += parse_code_section(fileit)

    # Assign global definitions to functions
    for g in globals:
        for f in functions:
            if f.name == g.name:
                f.global_def = g

    return functions


def parse_file(file):
    functions = []
    with open(file, "r") as f:
        fileit = FileIterator(f)
        functions = parse(fileit)

    return functions


def function_by_name(functions, name):
    for f in functions:
        if f.name == name:
            return f
    return None


def traverse_calls(functions, top):
    ret = []

    if not top:
        return ret

    for call in top.calls:
        f = function_by_name(functions, call)
        if f and (f not in ret):
            ret += [f] + traverse_calls(functions, f)

    return ret


def interrupt_handlers(functions):
    ret = []
    for f in functions:
        if f.isr:
            ret.append(f)
    return ret


############################################
# Main
############################################

parser = argparse.ArgumentParser(description="STM8 SDCC dead code elimination tool")
parser.add_argument("input", nargs="+", help="ASM files to process", type=str)
parser.add_argument("-o", "--output", help="Output directory", required=True)
parser.add_argument("-x", "--exclude", help="Exclude functions", type=str, nargs="+")
args = parser.parse_args()

# Create output directory if it doesn't exist
if not os.path.exists(args.output):
    os.makedirs(args.output)

# Copy all files to args.output directory
# input are files seperated by space
for file in args.input:
    shutil.copy(file, args.output)

functions = []

for file in os.listdir(args.output):
    if file.endswith(".asm"):
        functions += parse_file(args.output + "/" + file)

mainf = function_by_name(functions, "_main")
keep = [mainf] + traverse_calls(functions, mainf)

# Add interrupt handlers to keep
keep += interrupt_handlers(functions)

# Add functions that are excluded by the user
if args.exclude:
    for name in args.exclude:
        f = function_by_name(functions, name)
        if f and (f not in keep):
            keep.append(f)

# Remove duplicates
keep = list(set(keep))

# Create list of functions that are not in keep
remove = [f for f in functions if f not in keep]

# Categorize by file
files = {}
for f in remove:
    if f.path not in files:
        files[f.path] = []
    files[f.path].append(f)

# Remove dead functions
for file in files:
    with open(file, "r") as f:
        lines = f.readlines()

    for f in files[file]:
        if f.global_def:
            lines[f.global_def.line - 1] = ";" + lines[f.global_def.line - 1]

        for i in range(f.start_line - 1, f.end_line):
            lines[i] = ";" + lines[i]

    with open(file, "w") as f:
        f.writelines(lines)
