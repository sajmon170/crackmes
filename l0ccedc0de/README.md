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
`user_string_buffer`. Therefore, the missing `printf` arguments will be read
directly from that buffer.

#### Format string exploit outline
1. We need to write to `0x70707070`. Since `0x70` is the ASCII code for `p` we
can store it in the `user_string_buffer` by providing a `pppp` input
2. We now know how to encode the output address, but we also need some way to
write to it. Luckily `printf` provides a `%n` conversion specifier for saving
the number of previously written chars into some pointer argument. Therefore,
we need to pass `pppp` as an argument to `%n`.
3. Since the pointer address is stored in the `user_string_buffer` we need to
advance the `printf` argument pointer (AP) to point to it. We can use any output
specifier for that - I chose to use `%x` for its hex memory view.
4. We need to determine by how much to advance the AP. The format string itself
is passed as a pointer inside a register, and there are 5 other registers left
to use for passing arguments according to the Sys-V ABI. We need to read data
from the stack, therefore, we need 5 consecutive `%x` specifiers to skip those
registers.
```c
%x%x%x%x%x%npppp
🡩__ the AP points here
```
This is how the current format string looks like. However, this will not work,
since the AP points to its beginning and not to the `pppp` address. Each output
specifier advances the AP by 8 bytes because of 64-bit addressing. Adding
another `%x` moves the AP like so:
```c
%x%x%x%x%x%x%npppp
        🡩__ the AP points here
```
We can move the AP once more to get to the final result:
```c
%x%x%x%x%x%x%x%npppp
                🡩__ the AP points here
```

Note that `0x70707070` is actually `0x0000000070707070` when written as a 64-bit
address. However, everything turns out alright, because the array is filled with
zeros after `pppp`. When `printf` reads the pointer for `%n` it takes the `pppp`
value along with the remaining `\0\0\0\0` values next to it (remember that it
needs to read 8 bytes). Since numbers are stored in little endian `pppp\0\0\0\0`
is a valid representation for the `0x70707070` pointer. Our job is now done.

> [!NOTE]
> We can overwrite the memory at address `0x70707070` by passing in
> `%x%x%x%x%x%x%x%npppp` as an input to the `fgets` call.
