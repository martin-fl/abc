# abc

A basic cargo-like utility for managing your small-to-medium size C projects.

## Dependencies:

* make
* gcc
* tput
* ripgrep

Note: ripgrep instead of grep for faster parsing with tests.

## Installation:

If `.local/bin/` is in your `$PATH` :
```bash 
wget "https://raw.githubusercontent.com/martin-fl/abc/main/abc" -O .local/bin/abc
chmod +x .local/bin/abc
```

## How to use the command:

* Create a new project with `abc new <project_name>`
* Initialize a project within a directory with `abc init`
* Compile your code with `abc build` or `abc b`
* Execute your code with `abc run` or `abc r`
* Run unit tests with `abc test` or `abc t`
* Other commands: `abc help` 

## The abc-project architecture:

An abc-project has the following structure:

```
project
├── .abc_config
├── bin
├── Makefile
└── src
   └── main.c
```

Every `.c` and `.h` file needs to live in the `src/` directory (there can be subdirectories in `src/`). The `main.c` contains the `main()` function and needs to be present, otherwise it will not work. The `bin/` directory will mimic the`src/` directory's architecture but with object files and executables.

## Writing tests with abc: 

abc currently supports unit tests in `.c` files. Tests are functions that will only be compiled and executed when the `abc test` command is invoked.
Here is what a test in the `src/bar/foo.c` file would look like :
```c
// src/bar/foo.c
#include "foo.h"

// We want to test this function
int two_plus_two() {
        return 2 + 2;
}

#ifdef ABC_TEST
int test_two_plus_two() {
    int x = two_plus_two();
    return (x == 4);
}
#endif

```
More generally, a test in an integer function with no arguments, which returns 0 if the test fails, anything else if it is successfull. 

### Limitations/rules:
* Every test function needs to be surrounded by `#ifdef ABC_TEST` and `endif`. Two test functions __cannot__ share the same `ABC_TEST` block.
* Tests in the `src/main.c` file will __not__ be run.
* Right now, `#include`s required for the tests need to live outside of the `ABC_TEST` bloc, else the test will not be parsed (i.e, not be seen as a test).

