#!/usr/bin/env tclsh
#-- tests for Critcl emulation on mjtcc

package require tcltest
namespace import tcltest::test

test critcl-0 load {
   source critcl.tcl
   package present critcl
} 0.1.1

test critcl-1 add {
	critcl::cproc add {int a int b} int {return a+b;}
	add 3 4
} 7
test critcl-2 sub {
	critcl::cproc sub {int a int b} int {return a-b;}
	sub 3 4
} -1

test critcl-3 fibo {
    critcl::ccode {
        static int fibo(int n) {return n<=2? 1: fibo(n-1)+fibo(n-2);}
    }
    critcl::cproc fibo {int n} int {return fibo(n);}
    fibo 20
} 6765

test critcl-4 variable {
 critcl::cproc myincr {Tcl_Interp* interp char* varname} ok {
    Tcl_Obj* var = Tcl_GetVar2Ex(interp,varname, NULL, TCL_LEAVE_ERR_MSG);
    Tcl_Obj *res;
    int i;
    if(var == NULL) return TCL_ERROR;
    if(Tcl_GetIntFromObj(interp, var, &i) != TCL_OK) return TCL_ERROR;
    res = Tcl_NewIntObj(i+1);
    Tcl_SetVar2Ex(interp, varname, NULL, res, 0);
    Tcl_SetObjResult(interp, res);
    return TCL_OK;
 }
 set foo 42
 list $foo [myincr foo] $foo
} {42 43 43}

test critcl-5 sigmsg {
    critcl::cproc sigmsg {int i} char* {return Tcl_SignalMsg(i);} 
    sigmsg 4
} "illegal instruction"

test critcl-6 strrev {
   critcl::cproc strrev {char* s} char* {
      char *cp0, *cp1, t;
      for (cp0=s, cp1=s+strlen(s)-1; cp1 > cp0; cp0++, cp1--) {
		 t=*cp0; *cp0=*cp1; *cp1=t;
      }
      return s;
   }
  strrev hello
} olleh

test critcl-7 fibo {
    critcl::ccode { static int fib(int n) {return n <= 2? 1 : fib(n-1) + fib(n-2);} } 
    critcl::cproc fib {int n} int {return fib(n);} 
    fibo 20
} 6765

test critcl-8 cdata {
	critcl::cdata foo hello
	foo
} hello

test critcl-9 hypot {
	critcl::ccode {#include <math.h>}
	critcl::cproc hypot {double a double b} double {return sqrt(a*a+b*b);}
	hypot 3.0 4.0
} 5.0


#-- epilog
tcltest::cleanupTests

