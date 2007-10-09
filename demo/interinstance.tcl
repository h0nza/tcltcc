lappend auto_path ../
package require tcc
tcc $::tcc::dir tcc1
tcc1 compile {

 #include <stdio.h>
 #include <math.h>

  int fib(int n)
  {
    if (n <= 2) {
      return 1;
    } else {
      return fib(n-1) + fib(n-2);
    }
  }
}
catch {tcc1 get_symbol fiba} res
puts $res
set addr [tcc1 get_symbol fib]
 puts $addr
tcc $::tcc::dir tcc2
tcc2 add_symbol fib $addr
tcc2 compile {
   #include "tcl.h"
   int fibo( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){

  int n;

  if (objc!=2) {
    Tcl_WrongNumArgs(interp,1,objv,"int");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp,objv[1],&n)!=TCL_OK) {
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_NewIntObj(fib(n)));
  return TCL_OK;
 }
}

tcc2 command fib fibo
puts [fib 40]

tcc2 get_symbol "eh?"

