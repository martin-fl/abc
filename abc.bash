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
TESTS_OBJECTS=$(filter-out bin/main.o, $(OBJECTS))

# main recipe
$(BIN)/$(EXE): $(OBJECTS)
\t$(CC) $(CFLAGS) $(OBJECTS) -g -o $@
    
# compiles to object a source file in the source code directory 
$(BIN)/%.o: src/%.c
\tmkdir -p $(dir $@)
\t$(CC) -c $(CFLAGS) $< -o $@

# compiles to an executable a source file in the source directory, except for the main one
$(BIN)/%.tst: $(TESTS_OBJECTS)
\tmkdir -p $(dir $@)
\t$(CC) $(CFLAGS) $(TESTS_OBJECTS) -o $@


# phony in case a file is named clean ??
.PHONY:clean
clean:
\t[ $(BIN) != "/" ] && rm -rf $(BIN)/*
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
    # TODO: add example test file and unit test 
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


# compiles the project, excluding tests
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

# runs tests in files
# TODO: add code to handle unit tests, i.e tests in #ifdef TEST ... #endif blocks
abctest() {
    # total number of tests
    ntest=0
    # number of tests passed 
    passed=0

    # unit tests in files
    if [[ ! -e Makefile ]]; then
        error "Makefile not found"
        return
    fi
    
    potential_tests=$(find src -name '*.c')
    # remove main.c file
    # NOTE: there cannot be tests in main.c
    potential_tests=${potential_tests[@]/src\/main.c/}

    # regex that matches function names (with parentheses) between #ifdef TEST .. #endif markers
    # NOTE: One test == One #ifdef TEST #endif block !!
    regex_test_fns='(#ifdef TEST){1}((\s|\r\n|\r|\n)*?(int (\w+)\(\)){1}(\s|.|\r\n|\r|\n)*?)(#endif){1}'
    for potential_file in $potential_tests; do 
        # remove src/ part of the directory
        potential_file=${potential_file#*/}
        # get every functions within #ifdef TEST #endif blocks
        test_fns=$(rg -UIN "$regex_test_fns" -r '$5' src/$potential_file)
        if [[ -n $test_fns ]]; then
            # save current file to a backup, to be restored later
            cp src/$potential_file src/$potential_file.abc_back
            # remove file extension
            potential_file=${potential_file%.c}
            ntest_here=$(echo "$test_fns" | wc -l)
            (( ntest += ntest_here ))

            # building the main function
            echo "#ifdef TEST
#include<stdio.h>
#define RED \"\\x1b[31m\"
#define GREEN \"\\x1b[32m\"
#define RESET \"\\x1b[0m\"
int main() {
    unsigned long passed = 0;
    printf(\"\\nrunning $ntest_here tests in $potential_file\\n\");
    " >> src/$potential_file.c

            echo "$test_fns" | while read function_name; do 
                echo "
    printf(\"test $function_name ... \");
    if ($function_name()) {
        printf(GREEN\"ok\"RESET\"\n\");
        passed++;
    } else {
        printf(RED\"FAILED\"RESET\"\n\");
    }
    " >> src/$potential_file.c 
            done 
            echo -e "return passed;\n}\n#endif" >> src/$potential_file.c

            # main function is built, now compile it
            make -s bin/$potential_file.tst CFLAGS+="-D TEST"

            # it is compiled, run tests in that file
            ./bin/$potential_file.tst

            (( passed += $? ))

            # TODO: make sure test runs are contiguous with the tests in tests/

        
            # restoring code and removing object file to not interfere with the rest of
            # the program
            mv src/$potential_file.c.abc_back src/$potential_file.c
            rm bin/$potential_file.o
        fi 
    done 

    # print results
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

# Parse args
# TODO: Add a `cargo check` style command
case $1 in
    "new") shift; abcnew $@ ;;
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
    "test" | "t" )
        abcexists
        shift
        abctest $@
        ;;
    "help" | "-h" )
        abchelp
        ;;
    *)
        echo "Invalid command"
        ;;
esac
