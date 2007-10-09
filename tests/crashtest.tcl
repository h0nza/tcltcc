load ../tcc02.dll
set i 50
while {$i} {
   tcc . tcc1
   incr i -1
}
tcc1 compile nonsnes
