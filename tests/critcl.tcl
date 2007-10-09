#!/usr/bin/env tclsh
# Critcl (partial) emulation on top of tcc (Janssen)

load ../tcc02.dll
namespace eval ::critcl {
  variable critcl
  set critcl(dir) [file normalize [file dirname [info script]]/../pkg]
  puts "dir $critcl(dir)"
}
proc ::critcl::Log {args} {
  # puts $args
}
proc ::critcl::reset {} {
  variable critcl
  set critcl(code)   ""
  set critcl(cfiles) [list]
  set critcl(tk) 0
}
# Custom helpers
proc ::critcl::checkname {n} {expr {[regexp {^[a-zA-Z0-9_]+$} $n] > 0}}
proc ::critcl::cleanname {n} {regsub -all {[^a-zA-Z0-9_]+} $n _}

proc ::critcl::ccode {code} {
  variable critcl
  Log "INJECTING CCODE"
  append critcl(code) $code \n
}
proc ::critcl::cc {code} {
  variable critcl
  if {![info exists critcl(cc)]} {
      set cc tcc1
      tcc $critcl(dir) $cc
      set critcl(cc) $cc
  }
  Log code:$code
  $cc compile $code
}
proc ::critcl::cproc {name adefs rtype {body "#"}} {
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
  if {[info exists critcl(tk)] && $critcl(tk)} {
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
proc ::critcl::cdata {name data} {
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
proc ::critcl::ccommand {procname anames args} {
  variable critcl
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
  if {[info exists critcl(tk)] && $critcl(tk)} {
    append code "\#include <tk.h>" "\n"
  }
  if {[info exists critcl(code)] && [string length $critcl(code)]>0} {
    append code $critcl(code)
    append code "\n"
  }
  append code "int $cname (ClientData $v(clientdata),Tcl_Interp *$v(interp),"
  append code "int $v(objc),Tcl_Obj *CONST $v(objv)\[\]) {" "\n"
  append code [lindex $args end] "\n"
  append code "}" "\n"
  set ns [namespace current]
  uplevel 1 [list ${ns}::cc $code]
  Log "CREATING TCL COMMAND $procname / $cname"
  uplevel 1 [list $critcl(cc) command $procname $cname]
  unset critcl(cc) ;# can't be used for compiling anymore
}
proc ::critcl::tk {args} {
  variable critcl
  set critcl(tk) 1
}
::critcl::reset
package provide critcl 0.1.1
