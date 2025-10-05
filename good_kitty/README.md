# Static analysis
Static analysis of the decompiled code with Ghidra reveals that the program
is structured into the following parts

## 1. Initial password computation
```c
  local_20 = *(long *)(in_FS_OFFSET + 0x28);
  correct_passwd = (char  [8])get_largest_prime_factor();
  dVar3 = cbrt((double)(long)correct_passwd);
  correct_passwd = (char  [8])(long)dVar3;
  acVar1 = (char  [8])factorial(correct_passwd);
```

## 2. Password encryption
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

## 3. User I/O
This includes

## 4. Password comparison
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
