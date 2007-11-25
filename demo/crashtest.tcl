set auto_autopath [linsert $auto_path 0 ..]
package require tcc
set i 50
while {$i} {
   tcc $tcc::dir tcc1
   incr i -1
}
tcc1 compile nonsnes
