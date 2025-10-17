# 0xL0CCEDC0DE'S REVENGE
Solution to https://crackmes.one/crackme/686c7b57aadb6eeafb3990d7

## Stage 0
This crackme is structured into multiple stages, each with a different challenge.
### Static analysis
#### mmap syscall
The `stage0` function begins with a setup of an mmapped memory region
```c
  int newline_input;
  char user_string_buffer [256];
  char *switch_var;
  void *mmapped_region;

  mmapped_region = mmap((void *)0x70707000,1,3,0x22,-1,0);
```

The `mmap` man page reveals the name of each argument:
```c
void *mmap(void *addr, size_t len, int prot, int flags, 
    int fildes, off_t off);
```

The `mmap` syscall maps files into the virtual process memory. However, the
`fildes` argument value is negative. This is an invalid descriptor value on Unix
so something else must be at play here.

The flags argument is equal to `0x22`. We can find out which flags this value is
being composed of by looking through the Linux header files:

`[...]/linux-headers-6.16/include/asm-generic/mman-common.h`
```c
/* 0x01 - 0x03 are defined in linux/mman.h */
#define MAP_ANONYMOUS	0x20		/* don't use a file */
```

and

`[...]/linux-headers-6.16/include/linux/mman.h`
```c
#define MAP_PRIVATE	0x02		/* Changes are private */
```

> [!NOTE]
> We now know that `mmap` is being called to set up a valid memory page beginning
> at address `0x70707000`

Then, the program sets up a switch variable

```c
  switch_var = (char *)((long)mmapped_region + 0x70);
  *switch_var = '\0';
```

The switch variable is located at `0x70707070` and set to zero.

#### printf call
The next part of the `stage0` function is a loop that zeroes out
`user_string_buffer`, then reads user input and prints it out.

```c
    user_string_buffer[0] = '\0';
    user_string_buffer[1] = '\0';
    // ...
    user_string_buffer[0xfe] = '\0';
    user_string_buffer[0xff] = '\0';

    fgets(user_string_buffer,0x100,stdin);
    printf(user_string_buffer);
```

We can pass to `stage1` if the switch variable is non-empty:

```c
    if (*switch_var != '\0') {
      puts("The door opens and you walk thru!");
      munmap(mmapped_region,1);
      stage1();
    }
```

Therefore, we need a way to write to `switch_var`.
We can't do a buffer overflow since the call to `fgets` limits us to at most
`0x100` read characters. However, the `printf` call processes unsanitized user
input!

#### Variadic arguments
The `printf` function is declared as follows:

```c
int printf(const char *restrict format, ...);
```

The `...` ellipsis signify that this is a variadic argument function.
Its arguments must be processed through the `va_args` macros. In particular -
the `va_start` macro sets the argument pointer to point to the first unnamed
argument (i.e. - the first argument passed after `format`).

The `format` string specifies how many arguments `printf` needs to read. However,
passing the correct argument count isn't actually required since the processing
is fully done at runtime. So what happens then?

We know that this program is an x86\_64 ELF binary. The `file` command confirms
that it follows the System V ABI:

```
$ file revenge
revenge: ELF 64-bit LSB executable, x86-64, version 1 (SYSV)
```

According to the Sys-V ABI function calls need to pass the first 6 arguments
through the `rdi`, `rsi`, `rdx`, `rcx`, `r8`, and `r9` registers. All other
arguments are passed through the stack.

When `va_start` is invoked on a function without the correct number of arguments
the argument pointer will point to the end of the `printf` callee's stack memory.
This allows us to read its contents!

We also know that the last variable declared on the `stage0` call frame is the
`user_string_buffer`. Therefore, the `printf` arguments will be read directly
from that buffer.
