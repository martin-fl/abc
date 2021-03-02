# abc

A basic cargo-like utility for managing your small-to-medium sized C projects 

## How to use the command:

* Create a new project with `abc new <project_name>`
* Initialize a project within a directory with `abc init`
* Compile your code with `abc build` or `abc b`
* Execute your code with `abc run` or `abc r`
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

abc currently supports unit tests in `.c` files. Here is what a test in the `src/bar/foo.c` file would look like :
```c
// src/bar/foo.c
#include "foo.h"

// We want to test this function
int two_plus_two() {
        return 2 + 2;
}

#ifdef TEST
int test_two_plus_two() {
    int x = two_plus_two();
    return (x == 4);
}
#endif

```
More generally, a test in an integer function with no arguments, which returns 0 if the test fails, anything else if it is successfull. Every test function needs to be surrounded by `#ifdef TEST` and `endif`. Two test functions __cannot__ share the same `TEST` block.

Note: tests in the src/main.c file will __not__ be tested.

