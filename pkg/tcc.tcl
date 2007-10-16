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
   set includes $dir/include
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

namespace eval ::tcc {
  variable tcc
  set tcc(dir) [file dirname [info script]]
}
proc ::tcc::Log {args} {
  # puts $args
}
proc ::tcc::reset {} {
  variable tcc
  set tcc(code)   ""
  set tcc(cfiles) [list]
  set tcc(tk) 0
}
# Custom helpers
proc ::tcc::checkname {n} {expr {[regexp {^[a-zA-Z0-9_]+$} $n] > 0}}
proc ::tcc::cleanname {n} {regsub -all {[^a-zA-Z0-9_]+} $n _}

proc ::tcc::ccode {code} {
  variable tcc
  Log "INJECTING CCODE"
  append tcc(code) $code \n
}
proc ::tcc::cc {code} {
  variable tcc
  if {![info exists tcc(cc)]} {
      set tcc(cc) tcc1
      tcc $tcc(dir) $tcc(cc)
      $tcc(cc) add_library tcl8.5
  }
  Log code:$code
  $tcc(cc) compile $code
}
proc ::tcc::cproc {name adefs rtype {body "#"}} {
  set cname c_$name
  set wname tcl_$name
  array set types {}
  set names {}
  set cargs {}
  set cnames {}  
  # if first arg is "Tcl_Interp*", pass it without counting it as a cmd arg
  if {[lindex $adefs 0] == "Tcl_Interp*"} {
    lappend cnames ip
    lappend cargs [lrange $adefs 0 1]
    set adefs [lrange $adefs 2 end]
  }
  foreach {t n} $adefs {
    set types($n) $t
    lappend names $n
    lappend cnames _$n
    lappend cargs "$t $n"
  }
  switch -- $rtype {
    ok      { set rtype2 "int" }
    string - dstring - vstring { set rtype2 "char*" }
    default { set rtype2 $rtype }
  }
  set code ""
  append code "\#include <tcl.h>" "\n"
  if {[info exists tcc(tk)] && $tcc(tk)} {
    append code "\#include <tk.h>" "\n"
  }
  if {$body != "#"} {
    append code "static $rtype2" "\n"
    append code "${cname}([join $cargs {, }])" "\n"
    append code "\{" "\n"
    append code $body
    append code "\}" "\n"
  } else {
    append code "#define $cname $name" "\n"
  }
  # Supported input types
  #   Tcl_Interp*
  #   int
  #   long
  #   float
  #   double
  #   char*
  #   Tcl_Obj*
  #   void*
  foreach x $names {
    set t $types($x)
    switch -- $t {
      int - long - float - double - char* - Tcl_Obj* {
          append cbody "  $types($x) _$x;" "\n"
      }
      default {append cbody "  void *_$x;" "\n"}
    }
  }
  if {$rtype ne "void"} { append cbody  "  $rtype2 rv;" "\n" }  
  append cbody "  if (objc != [expr {[llength $names] + 1}]) {" "\n"
  append cbody "    Tcl_WrongNumArgs(ip, 1, objv, \"[join $names { }]\");" "\n"
  append cbody "    return TCL_ERROR;" "\n"
  append cbody "  }" "\n"
  set n 0
  foreach x $names {
    incr n
    switch -- $types($x) {
      int {
	append cbody "  if (Tcl_GetIntFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
	append cbody "    return TCL_ERROR;" "\n"
      }
      long {
	append cbody "  if (Tcl_GetLongFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
	append cbody "    return TCL_ERROR;" "\n"
      }
      float {
	append cbody "  {" "\n"
	append cbody "    double t;" "\n"
	append cbody "    if (Tcl_GetDoubleFromObj(ip, objv\[$n], &t) != TCL_OK)"
	append cbody "      return TCL_ERROR;" "\n"
	append cbody "    _$x = (float) t;" "\n"
	append cbody "  }" "\n"
      }
      double {
	append cbody "  if (Tcl_GetDoubleFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
	append cbody "    return TCL_ERROR;" "\n"
      }
      char* {
	append cbody "  _$x = Tcl_GetString(objv\[$n]);" "\n"
      }
      default {
	append cbody "  _$x = objv\[$n];" "\n"
      }
    }
  }
  append cbody "\n  "
  if {$rtype != "void"} {append cbody "rv = "}
  append cbody "${cname}([join $cnames {, }]);" "\n"
  # Return types supported by critcl
  #   void
  #   ok
  #   int
  #   long
  #   float
  #   double
  #   char*     (TCL_STATIC char*)
  #   string    (TCL_DYNAMIC char*)
  #   dstring   (TCL_DYNAMIC char*)
  #   vstring   (TCL_VOLATILE char*)
  #   default   (Tcl_Obj*)
  # Our extensions
  #   wide
  switch -- $rtype {
    void    	{ }
    ok	        { append cbody "  return rv;" "\n" }
    int	        { append cbody "  Tcl_SetIntObj(Tcl_GetObjResult(ip), rv);" "\n" }
    long	{ append cbody "  Tcl_SetLongObj(Tcl_GetObjResult(ip), rv);" "\n" }
    float       -
    double	{ append cbody "  Tcl_SetDoubleObj(Tcl_GetObjResult(ip), rv);" "\n" }
    char*	{ append cbody "  Tcl_SetResult(ip, rv, TCL_STATIC);" "\n" }
    string      -
    dstring	{ append cbody "  Tcl_SetResult(ip, rv, TCL_DYNAMIC);" "\n" }
    vstring	{ append cbody "  Tcl_SetResult(ip, rv, TCL_VOLATILE);" "\n" }
    default 	{ append cbody "  Tcl_SetObjResult(ip, rv); Tcl_DecrRefCount(rv);" "\n" }
  }
  if {$rtype != "ok"} {append cbody "  return TCL_OK;" \n}
  ccode $code
  set ns [namespace current]
  uplevel 1 [list ${ns}::ccommand $name {dummy ip objc objv} $cbody]
}
proc ::tcc::cdata {name data} {
  # Extract bytes from data
  binary scan $data c* bytes
    set inittext "\n"
  set line ""
  set n 0
  set l 0
  foreach c $bytes {
    if {$n>0} {append inittext ","}
    if {$l>20} {
      append inittext "\n"
      set l 0
    }
    if {$l==0} {append inittext "  "}
    append inittext [format "0x%02X" [expr {$c & 0xff}]]
    incr n
    incr l
  }
  append inittext "\n"
  set count [llength $bytes]  
  set cbody ""
  append cbody "static unsigned char script\[$count\] = \{" "\n"
  append cbody $inittext
  append cbody "\};" "\n"
  append cbody "Tcl_SetByteArrayObj(Tcl_GetObjResult(ip), (unsigned char*) script, $count);" "\n"
  append cbody "return TCL_OK;" "\n"
  set ns [namespace current]
  uplevel 1 [list ${ns}::ccommand $name {dummy ip objc objv} $cbody]
  return $name
}
#-------------------------------------------------------------------
proc ::tcc::ccommand {procname anames args} {
  variable tcc
  # Fully qualified proc name
  if {[string match "::*" $procname]} {
    # procname is already absolute
  } else {
    set nsfrom [uplevel 1 {namespace current}]    
    if {$nsfrom eq "::"} {set nsfrom ""}
    set procname "${nsfrom}::${procname}"
  }      
  set v(clientdata) clientdata
  set v(interp)     interp
  set v(objc)       objc
  set v(objv)       objv
  set id 0
  foreach defname {clientdata interp objc objv} {
    if {[llength $anames]>$id} {
      set vname [lindex $anames $id]
      if {![checkname $vname]} {
	error "invalid variable name \"$vname\""
      }
    } else {set vname $defname}
    set v($defname) $vname
    incr id
  }
  set cname Cmd_N${id}_[cleanname $procname]
  set code ""
  if {[info exists tcc(tk)] && $tcc(tk)} {
    append code "\#include <tk.h>" "\n"
  }
  if {[info exists tcc(code)] && [string length $tcc(code)]>0} {
    append code $tcc(code)
    append code "\n"
  }
  append code "int $cname (ClientData $v(clientdata),Tcl_Interp *$v(interp),"
  append code "int $v(objc),Tcl_Obj *CONST $v(objv)\[\]) {" "\n"
  append code [lindex $args end] "\n"
  append code "}" "\n"
  set ns [namespace current]
  uplevel 1 [list ${ns}::cc $code]
  Log "CREATING TCL COMMAND $procname / $cname"
  uplevel 1 [list $tcc(cc) command $procname $cname]
  unset tcc(cc) ;# can't be used for compiling anymore
}
proc ::tcc::tk {args} {
  variable tcc
  set tcc(tk) 1
}
::tcc::reset
namespace eval tcc {namespace export cproc ccode cdata}


