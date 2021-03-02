#!/usr/bin/bash
#-*- coding: utf-8 -*-
#----------------------------------------------
# very basic cargo-like utility for C projects
# written by Martin Fl. 
#----------------------------------------------

# initial content in src/main.c
mainfile_content='#include <stdio.h>

int main() {
    printf("Hello world!\n");
    return 0;
}'

# initial content in Makefile (shouldn't need to be changed for small-medium project)
makefile_content='# Compiler
CC=gcc
# Compiler flags
CFLAGS=-lm
# Final executable name 
EXE=main
# source code directory
SRC=./src
# objects files and executable directory
BIN=./bin
# possible directories where header files could be
HEADERS=-I./src
# c files to compile 
SOURCES=$(shell find src -name *.c)
# object files names
OBJECTS=$(SOURCES:src/%.c=bin/%.o)

# main recipe
$(BIN)/$(EXE): $(OBJECTS)
\t$(CC) $(CFLAGS) $(OBJECTS) -g -o $@
    
# compiles to object every source file in the source code directory 
$(BIN)/%.o: src/%.c
\t$(CC) -c $(CFLAGS) $< -o $@


# phony in case a file is named clean ??
.PHONY:clean
clean:
\trm bin/*
'

# Some config
config_file=".abc_config"
calling_dir=$(pwd)

if [[ -e $config_file ]]; then
    config=$(cat $config_file)
    project_name=${config[0]}
fi

build_recipe="bin/main"
clean_recipe="clean"

# convenience error function
error() {
    echo "$(tput setaf 1)$(tput bold)error$(tput sgr0): $1"
}

# convenience step printing function
print_step() {
    step_name=${1%% *}
    rest=${1#* }
    if [[ ${#step_name} -le 12 ]]; then
        num_space=$((12-${#step_name}))
        for ((i=1;i <= $num_space;i++)); do
            printf " "
        done
        echo "$(tput setaf 2)$(tput bold)$step_name$(tput sgr0) $rest"
    else
        error "Step name too long"
        return 
    fi
}

# creates a new abc project
abcnew() {
    # test if project name was given, else exit 
    if [[ -z $1 ]]; then
        error "no project name given"
        return 101
    fi
    project_name=$1
    # test if a file/directory already has the same name, else continue
    if [[ -e $project_name ]]; then
        error "file $project_name already exists"
        return 101
    fi

    # creates project structure
    mkdir $project_name/{,src,bin}
    # create light config file 
    # TODO: Make a bette config file, maybe use toml ?
    echo $project_name > $project_name/$config_file
    # creates base source file
    # TODO: support library creation ?
    echo "$mainfile_content" > $project_name/src/main.c
    # create Makefile
    echo -e "$makefile_content" > $project_name/Makefile
    print_step "Created $project_name package"
}

# intialize a new abc within a directory
abcinit() {
    # check if a config file exists, else continue
    if [[ -e $config_file ]]; then
        error "project already initialized"
        return
    fi
    # get current directory name, set as project name
    init_dir=$(pwd)
    echo ${init_dir##*/} > $config_file

    # test for structure existence and create missing files
    [[ ! -e Makefile ]] && printf "$makefile_content" > Makefile
    [[ ! -e src ]] && mkdir src && printf "$mainfile_content" > src/main.c
    [[ ! -e bin ]] && mkdir bin 

    print_step "Created $project_name package"
}

# check if project exists
abcexists() {
    [[ ! -e $config_file ]] && error "project doesn't exist" && exit
}


# compiles the project
abcbuild() {
    # test for Makefile existence, else exit
    if [[ ! -e Makefile ]]; then
        error "Makefile not found"
        return
    elif [[ ! -e src/main.c ]]; then
        error "src/main.c doesn't exist"
        return
    fi

    print_step "Compiling $project_name ($(pwd))"

    # if recipe name precised, compile it else compile main recipe
    if [[ -n $1 ]]; then
        make -s $1
    else
        make -s $build_recipe 
    fi
    
    # test if compilation was successful, to display the message
    [[ $? -eq 0 ]] && print_step "Finished building $project_name"
}

# clean bin/ directory if not empty
abcclean() {
    print_step "Cleaning $project_name/bin/ ($(pwd))"
    [[ -n $(ls bin/) ]] && make -s $clean_recipe && print_step "Finished cleaning" && return
    print_step "Finished cleaning"
}

# compiles then execute project
abcrun() {
    abcbuild 
    print_step "Running bin/main"
    ./bin/main
}

# displays the usage
abchelp() {
    echo -e "abc v0.1\nUsage : abc [new|init|build|run]"
}

# Parse args
# TODO: Add a `cargo check` style command
case $1 in
    "new") 
        shift; 
        abcnew $@
        ;;
    "init")
        abcinit
        ;;
    "build" | "b" )
        abcexists
        shift
        abcbuild $@
        ;;
    "clean")
        abcexists
        abcclean
        ;;
    "run" | "r" )
        abcexists
        shift
        abcrun
        ;;
    "help" | "-h" )
        abchelp
        ;;
    *)
        echo "Invalid command"
        ;;
esac
