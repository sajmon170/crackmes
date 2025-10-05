b main
r
c
b *main + 0x1b2
c
# p *(char (*)[8])($rsp + 0x10)
printf "%.8s\n", $rsp + 0x10
