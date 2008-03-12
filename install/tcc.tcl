namespace eval tcc {
   variable dir 
   variable libs
   variable includes
   variable count
   set dir [file join {*}[lrange [file split [info script]] 0 end-1]]
   load $dir/tcc01.dll tcc
   set libs $dir/lib
   set includes $dir/includes
   set count 0
   proc new {} {
       variable dir
       variable count
       tcc $dir tcc_[incr count]
       return tcc_$count
   } 
}


