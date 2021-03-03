#!/usr/bin/env bash
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
CFLAGS=-g -Wall -Wextra
LDLIBS=-lm
# Final executable name 
EXE=main
# source code directory
SRC=./src
# objects files and executable directory
BIN=./bin
# possible directories where header files could be
HEADERS=-I./src
# c files to compile 
SOURCES=$(shell find src -name "*".c)
# object files names
OBJECTS=$(SOURCES:src/%.c=bin/%.o)
TESTS_OBJECTS=$(filter-out bin/main.o, $(OBJECTS))

# main recipe
$(BIN)/$(EXE): $(OBJECTS)
\t$(CC) $(CFLAGS) $(OBJECTS) -o $@ $(LDLIBS)
    
# compiles to object a source file in the source code directory 
$(BIN)/%.o: src/%.c
\tmkdir -p $(dir $@)
\t$(CC) -c $(CFLAGS) $< -o $@ $(LDLIBS)

# compiles to an executable a source file in the source directory, except for the main one
$(BIN)/%.tst: $(TESTS_OBJECTS)
\tmkdir -p $(dir $@)
\t$(CC) $(CFLAGS) $(TESTS_OBJECTS) -o $@ $(LDLIBS)


# phony in case a file is named clean ??
.PHONY:clean
clean:
\t[ -n $(BIN) ] && rm -rf $(BIN)/*
'

# Some config
# TODO: Make a better config file, maybe use toml ?
config_file=".abc_config"

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
        for ((i=1;i <= num_space;i++)); do
            printf " "
        done
        echo "$(tput setaf 2)$(tput bold)$step_name$(tput sgr0) $rest"
    else
        error "Step name too long"
        return 
    fi
}

# creates a new abc project
# TODO: support library creation ?
abcnew() {
    if [[ -z $1 ]]; then
        error "no project name given"
        return 101
    fi
    project_name=$1
    if [[ -e $project_name ]]; then
        error "file $project_name already exists"
        return 101
    fi

    mkdir "$project_name"/{,src,bin}
    printf "%s" "$project_name" > "$project_name"/$config_file
    printf "%s" "$mainfile_content" > "$project_name"/src/main.c
    echo -e "$makefile_content" > "$project_name"/Makefile
    print_step "Created $project_name package"
}

# intializes a new abcproject within a directory
abcinit() {
    if [[ -e $config_file ]]; then
        error "project already initialized"
        return
    fi

    echo "${PWD##*/}" > $config_file

    [[ ! -e Makefile ]] && printf "%s" "$makefile_content" > Makefile
    [[ ! -e src ]] && mkdir src && echo -e "$mainfile_content" > src/main.c
    [[ ! -e bin ]] && mkdir bin 

    print_step "Created $project_name package"
}

# checks if project exists
abcexists() {
    [[ ! -e $config_file ]] && error "project doesn't exist" && exit
}


# compiles the project, excluding tests
abcbuild() {
    if [[ ! -e Makefile ]]; then
        error "Makefile not found"
        return
    elif [[ ! -e src/main.c ]]; then
        error "src/main.c doesn't exist"
        return
    fi

    print_step "Compiling $project_name ($PWD)"

    if make -s "${1:-$build_recipe}"; then     
        print_step "Finished building $project_name"
    fi
}

# cleans bin/ directory if not empty
abcclean() {
    print_step "Cleaning $project_name/bin/ ($PWD)"
    [[ -n $(ls bin/) ]] && make -s "$clean_recipe" && print_step "Finished cleaning" && return
    print_step "Finished cleaning"
}

# compiles then execute project
abcrun() {
    abcbuild 
    print_step "Running bin/main"
    ./bin/main
}

# runs tests in files
abctest() {
    # total number of tests
    ntest=0
    # number of tests passed 
    passed=0

    if [[ ! -e Makefile ]]; then
        error "Makefile not found"
        return
    fi
    
    potential_tests=$(find src -name '*.c')
    # remove main.c file
    # NOTE: there cannot be tests in main.c
    potential_tests=${potential_tests/src\/main.c/}

    # regex that matches function names between #ifdef ABC_TEST .. #endif markers
    # NOTE: One test == One #ifdef ABC_TEST #endif block !!
    regex_test_fns='(#ifdef ABC_TEST){1}((\s|\r\n|\r|\n)*?(int (\w+)\(\)){1}(\s|.|\r\n|\r|\n)*?)(#endif){1}'
    for potential_file in $potential_tests; do 
        potential_file=${potential_file#src/}
        # get every functions within #ifdef ABC_TEST #endif blocks
        test_fns=$(rg -UIN "$regex_test_fns" -r '$5' src/"$potential_file")

        if [[ -n $test_fns ]]; then
            # save current file to a backup, to be restored later
            cp src/"$potential_file" src/"$potential_file".abc_back

            potential_file=${potential_file%.c}
            ntest_here=$(echo "$test_fns" | wc -l)
            (( ntest += ntest_here ))

            # building the main function
            echo "
#include<stdio.h>
#ifdef ABC_TEST
#define RED \"\\x1b[31m\"
#define GREEN \"\\x1b[32m\"
#define RESET \"\\x1b[0m\"
int main() {
    unsigned long passed = 0;
    printf(\"\\nrunning $ntest_here tests in $potential_file\\n\");
    " >> src/"$potential_file".c

            echo "$test_fns" | while read function_name; do 
                echo "
    printf(\"test $function_name ... \");
    if ($function_name()) {
        printf(GREEN\"ok\"RESET\"\\n\");
        passed++;
    } else {
        printf(RED\"FAILED\"RESET\"\\n\");
    }
    " >> src/"$potential_file".c 
            done 
            echo -e "return passed;\n}\n#endif" >> src/"$potential_file".c

            make -s bin/"$potential_file".tst CFLAGS+="-D ABC_TEST"

            ./bin/"$potential_file".tst
            (( passed += $? ))

            # restoring code and removing object file to not interfere with the rest of the program
            mv src/"$potential_file".c.abc_back src/"$potential_file".c
            rm bin/"$potential_file".o
        fi 
    done 

    echo -ne "\ntests results:"
    if [[ $passed -lt $ntest ]]; then 
        echo -n "$(tput setaf 1) FAILED$(tput sgr0)"
    else
        echo -n "$(tput setaf 2) ok$(tput sgr0)"
    fi
    echo ". $passed passed; $(( ntest - passed )) failed."
}

# displays the usage
abchelp() {
    echo -e "abc v0.1\nUsage : abc [new|init|build|run|test]"
}

# Parses args
# TODO: Add a `cargo check` style command
case $1 in
    "new") 
        shift; 
        abcnew "$@" 
        ;;
    "init")
        abcinit
        ;;
    "build" | "b" )
        abcexists
        shift
        abcbuild "$@"
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
    "test" | "t" )
        abcexists
        shift
        abctest "$@"
        ;;
    "help" | "-h" )
        abchelp
        ;;
    *)
        echo "Invalid command"
        ;;
esac
