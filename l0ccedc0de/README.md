# 0xL0CCEDC0DE'S REVENGE
Solution to https://crackmes.one/crackme/686c7b57aadb6eeafb3990d7

## Stage 0
This crackme is structured into multiple stages, each with a different challenge.
### Static analysis
#### mmap syscall
The `stage0` function begins with a setup of a switch variable
```c
  int newline_input;
  char user_string_buffer [256];
  char *switch_var;
  void *mmapped_region;
  
                    /* protection: READ | WRITE
                            flags: MAP_PRIVATE | MAP_ANONYMOUS */
  mmapped_region = mmap((void *)0x70707000,1,3,0x22,-1,0);
  switch_var = (char *)((long)mmapped_region + 0x70);
  *switch_var = '\0';
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

`[...]/linux-headers-6.16/include/asm-generic/mman-common.h`
```

and

`[...]/linux-headers-6.16/include/linux/mman.h`
```c
#define MAP_PRIVATE	0x02		/* Changes are private */
```

> [!NOTE]
> We now know that mmap is being called to set up a valid memory page beginning
> at address `0x70707000`
