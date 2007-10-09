namespace eval tcc {
   variable dir 
   variable libs
   variable includes
   variable count
   variable command_count
   variable commands

   set dir [file dirname [info script]]
   load $dir/tcc02.dll tcc
   set libs $dir/lib
   set includes $dir/includes
   set count 0
   set command_count 0
   array set commands {}
   proc new {} {
       variable dir
       variable count
       set handle tcc_[incr count]
       tcc $dir $handle
       return tcc_$count
   }

   proc tclcommand {handle name ccode} {
       variable commands
       variable command_count
       set cname _tcc_tcl_command_[incr command_count]
       set code    {#include "tcl.h"}
       append code "\n int $cname"
       append code "( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){"
       append code "\n$ccode"
       append code "}"
       $handle compile $code
       set commands($handle,$name) $cname
       return
   }

   proc compile {handle} {
       variable commands
       foreach cmd [array names commands $handle*] {
           puts $cmd
           puts $commands($cmd)
           set cname $commands($cmd)
           set tclcommand [join [lrange [split $cmd ,] 1 end] {}]
           set handle [lindex [split $cmd ,] 0]
           $handle command $tclcommand $cname
        }
       return
   }
}


