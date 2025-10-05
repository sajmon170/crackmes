# Good kitty
Solution to https://crackmes.one/crackme/68c44e20224c0ec5dcedbf4b

## Static analysis
Static analysis of the decompiled code with Ghidra reveals that the program
is structured into the following parts

### 1. Initial password computation
```c
  local_20 = *(long *)(in_FS_OFFSET + 0x28);
  correct_passwd = (char  [8])get_largest_prime_factor();
  dVar3 = cbrt((double)(long)correct_passwd);
  correct_passwd = (char  [8])(long)dVar3;
  acVar1 = (char  [8])factorial(correct_passwd);
```

### 2. Password encryption
```c
  loop_ctr = 0;
  do {
    passwd_char = correct_passwd[loop_ctr];
    if ((0x19 < (byte)((passwd_char & 0xdf) + 0xbf)) && (9 < (byte)(passwd_char - 0x30))) {
      passwd_char = passwd_char % 0x3e;
      if ((byte)(passwd_char - 10) < 0x1a) {
        correct_passwd[loop_ctr] = passwd_char + 0x37;
      }
      else if ((byte)(passwd_char + 0x30) < 0x54) {
        correct_passwd[loop_ctr] = passwd_char + 0x30;
      }
      else {
        correct_passwd[loop_ctr] = passwd_char + 0x3d;
      }
    }
    loop_ctr = loop_ctr + 1;
  } while (loop_ctr != 8);
```

### 3. User I/O
This includes all the `write` and `read` calls

### 4. Password comparison
```c
  is_pass_correct = 1;
  passwd_idx = 0;
  if (0 < loop_ctr) {
    do {
      if (7 < passwd_idx) break;
      if (entered_passwd[(int)passwd_idx] != correct_passwd[(int)passwd_idx]) {
        is_pass_correct = 0;
      }
      passwd_idx = passwd_idx + 1;
    } while ((int)passwd_idx < loop_ctr);
  }
  is_pass_correct = loop_ctr == 8 & is_pass_correct;
  if (is_pass_correct == 0) {
    puts("bad kitty!");
  }
  else {
    puts("good kitty!");
  }
```
That `do..while` loop is clearly a string comparison function.

## Dynamic analysis
### Setting the correct breakpoint
Since the correct password is stored inside the `correct_passwd` variable all
we have to do is read it after the encryption step is done.

```c
  } while (loop_ctr != 8);
  _message_str = 0x6874207265746e65;
  iVar2 = 0; // <- We're setting the breakpoint here
```

Inspecting the dissassembly of that line in Ghidra we find that it corresponds
to instruction offset `main + 0x12b`

> [!NOTE]
> We don't need to concern ourselves with how the encryption is actually done,
> nor with what the functions from the first static analysis step compute.

### Reading the correct value
Now we need to read the actual computed and encrypted password string. Let's
select some line from the encryption code that uses the `correct_passwd`
variable.

The line:
```c
correct_passwd[loop_ctr] = passwd_char + 0x3d;
```
corresponds to the following assembly code:
```asm
00101367 40 88 74        MOV        byte ptr [RSP + loop_ctr*0x1 + 0x10],SIL
         14 10
```

We can infer from the addressing mode that the password string variable begins
at address `$RSP + 0x10`.

### Putting it all together
The script `solution.gdb` contains GDB instructions for returning the password.
Running it with 

```bash
gdb --batch --quiet --command=solution.gdb ./crack 2>/dev/null | tail -n1
```
We find out that the password is `00sGo4M0`.
