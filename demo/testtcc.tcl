load ../libtcc0.2.so
# second parameter is the path to the tcc libraries
tcc ../pkg tcc1

# path to the lib and include dir
tcc1 compile {
   #include "tcl.h"
   int test( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
       Tcl_Eval (interp, "puts woot");
       return TCL_OK;
   }
}
tcc1 command test test

test

set l1 [time {proc fib n {
   if {$n <= 2} {return 1}
   expr {[fib [expr {$n-1}]] + [fib [expr {$n-2}]]}
}
}]

tcc ../pkg tcc1
tcc1 add_library user32

set l2 [time {
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

tcc1 compile {
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

tcc1 command fibo fibo
}]
catch {tcc1 compile dum} res
puts $res

puts Definition
puts "Tcl [lindex $l1 0]"
puts "TCC [lindex $l2 0]"

set l1 [lindex [time {fib 10}] 0]
set l2 [lindex [time {fibo 10}] 0]
puts "Tcl: $l1"
puts "TCC: $l2"
puts "factor: [expr $l1/$l2]"

fibo 1

tcc ../pkg tcc1
tcc1 add_library user32

set ok {
  #include <windows.h>
  #include "tcl.h"
   int ok( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
      MessageBox(NULL,"test","test",MB_OK);
      return TCL_OK;
}
	
}

tcc1 compile $ok
tcc1 command ok ok
ok
set ok2 {
  #include <windows.h>
  #include "tcl.h"
   int ok2( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
      MessageBox(NULL,"test2","test2",MB_OK);
      return TCL_OK;
}
	
}


# so create a new one
tcc ../pkg tcc1
tcc1 add_library user32
tcc1 compile $ok2
tcc1 command ok2 ok2
ok2

# test advapi doesn't do anything but crash, but checks compilation
tcc ../pkg tcc2
tcc2 add_library advapi32
tcc2 compile {
    void test (void) {
        int m;
        MD5Init(m);
    }
}

tcc2 command test test

# if you need a lot of UUID's the difference is huge
tcc ../pkg tccuuid
tccuuid add_library rpcrt4
set code {
    #include "tcl.h"
    #include "rpc.h"
   int uuid( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
      UUID id;
      unsigned char * strUUID;
      UuidCreate(&id);
      UuidToString(&id, &strUUID);
      Tcl_SetObjResult(interp, Tcl_NewStringObj(strUUID,-1));
      RpcStringFree(&strUUID);
      return TCL_OK;
   }
}
tccuuid compile $code
tccuuid command uuid uuid

package require uuid
puts "uuid tcc:\t\t[set t1 [time {uuid} 100]]"
puts "uuid tcllib:\t\t[set t2 [time {uuid::tostring [uuid::generate]} 40]]"  
puts "factor: [expr {[lindex $t2 0]/[lindex $t1 0]}]"
puts "Example tcc:\t [uuid]"
puts "Example tcllib:\t [uuid::tostring [uuid::generate]]"
