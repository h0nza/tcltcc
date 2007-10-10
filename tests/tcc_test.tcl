#!/usr/bin/env tclsh
#-- tests for tcc (Janssen), R. Suchenwirth 2007-10-06

package require tcltest
namespace import tcltest::test

set errorInfo ""
test tcc-1 "load library" {
    if {$::tcl_platform(platform) eq "windows"} {
	load ../tcc02.dll
    } else {
        load ../libtcc0.2.so
    }
    package present tcc
} 0.2
test tcc-2 "very simple command" {
    tcc ../pkg tcc1
    tcc1 add_library tcl8.5
    tcc1 compile {
        #include "tcl.h"
        int testc( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
            Tcl_Eval (interp, "puts woot");
            return TCL_OK;
        }
    }
    tcc1 command test2 testc
    rename tcc1 {}
    test2
} ""
test tcc-3 "addition" {
    tcc ../pkg tcc2
    tcc2 add_library tcl8.5
    tcc2 compile {

        #include "tcl.h"
        int add2(ClientData cd, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
            int a, b;
            if (objc!=3) {
                Tcl_WrongNumArgs(interp,2,objv,"int");return TCL_ERROR;
            }
            if (Tcl_GetIntFromObj(interp,objv[1],&a)!=TCL_OK) return TCL_ERROR;
            if (Tcl_GetIntFromObj(interp,objv[2],&b)!=TCL_OK) return TCL_ERROR;
            Tcl_SetObjResult(interp, Tcl_NewIntObj( a + b ));
            return TCL_OK;
        }
    }
    tcc2 command add2 add2
    rename tcc2 {}
    add2 3 4
} 7
test tcc-4 fibo {
    tcc ../pkg tcc1
    tcc1 add_library tcl8.5
    set l2 [time {
    tcc1 compile {
        #include "tcl.h"

        static int fib(int n) {return n <= 2? 1 : fib(n-1) + fib(n-2);}

        int fibo( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
            int n;
            if (objc!=2) {
                Tcl_WrongNumArgs(interp,1,objv,"int"); return TCL_ERROR;
            }
            if (Tcl_GetIntFromObj(interp,objv[1],&n)!=TCL_OK) return TCL_ERROR;
            Tcl_SetObjResult(interp, Tcl_NewIntObj(fib(n)));
            return TCL_OK;
        }
    }
    tcc1 command fibo fibo
    }]
    puts "fibo compile time: $l2, fibo 20: [time {fibo 20}]"
    rename tcc1 {}
    fibo 20
} 6765

test tcc-5 "no more compiling allowed" -body {
    tcc ../pkg tcc1
    tcc1 add_symbol test 1
    tcc1 get_symbol test
    tcc1 compile whatever
} -returnCodes 1 -result {code already relocated, cannot compile more} -cleanup {rename tcc1 {}}
set errorInfo ""

test tcc-6 fiboTcl {
    set l1 [time {
        proc fib n {
           expr {$n <= 2? 1: [fib [expr {$n-1}]] + [fib [expr {$n-2}]]}
        }
    }]
    puts "tcl:fib compile: $l1"
    fib 20
} 6765

test tcc-7 uuid -constraints pc -body  {
    tcc ../pkg tccuuid
    tccuuid add_library rpcrt4
    tccuuid add_library tcl8.5
    tccuuid add_include_path ../pkg/include/generic
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
    set t1 [time {uuid} 100]
    puts "Example tcc:\t [uuid]\n$t1"
} -result  ""

test tcc-8 sigid {
    tcc ../pkg sigid_
    sigid_ add_library tcl8.5
    sigid_ compile {
        #include "tcl.h"
        int sigid(ClientData cd, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
            int i;
            if (objc!=2) {
                Tcl_WrongNumArgs(interp,1,objv,"int"); return TCL_ERROR;
            }
            if (Tcl_GetIntFromObj(interp,objv[1],&i)!=TCL_OK) return TCL_ERROR;
            Tcl_SetObjResult(interp, Tcl_NewStringObj(Tcl_SignalId(i),-1));
            return TCL_OK;
         }
    }
    sigid_ command sigid sigid
    sigid 2
} SIGINT

puts $errorInfo
tcltest::cleanupTests

