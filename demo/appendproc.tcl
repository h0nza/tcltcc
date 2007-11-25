# do the results of this benchmark indicate the BC execution engine can be optimized further?

set auto_path [linsert $auto_path 0 ..]
package require tcc
tcc $tcc::dir tcc_1
set t tcc_1
puts $t
$t add_library tcl8.5
$t compile {
   #include "tcl.h"
    int tccappend( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
        Tcl_Obj * obj = Tcl_NewListObj(NULL,0);
        int i =0;
        for (i=0 ; i< 10000 ; i++) {
            Tcl_ListObjAppendElement(interp, obj, Tcl_NewIntObj(i));
        }
        Tcl_ObjSetVar2(interp, objv[1], NULL, obj,0);
       return TCL_OK;
   }
    int tcc2append( ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj * CONST objv[]){
        Tcl_Obj * obj = Tcl_NewListObj(NULL,0);
        int i =0;
        for (i=0 ; i< 10000 ; i++) {
            Tcl_ObjSetVar2(interp, objv[1], NULL, Tcl_NewIntObj(i), (TCL_APPEND_VALUE|TCL_LIST_ELEMENT));
        }
        Tcl_ObjSetVar2(interp, objv[1], NULL, obj,0);
       return TCL_OK;
   }

}

$t command tccappend tccappend
$t command tcc2append tcc2append
proc tcc2appendinp {a} {
    # a is now local to the proc, which makes a big difference in speed,
    # as MS remarked, NS var lookup is not quite optimal in HEAD
    tcc2append $a
}

proc tccappendinp {a} {
    tccappend $a
}

proc bcappendinp {a} {
    bcappend $a
}

proc bcappend {var} {
    for {set i 0} {$i < 10000} {incr i} {
        lappend var $i
    }
    return
}
set a {}
puts [time {tccappend a} 100]
set a {}
puts [time {tccappendinp a} 100]
set a {}
puts [time {tcc2append a} 100]
set a {}
puts [time {tcc2appendinp a} 100]
set a {}
puts [time {bcappend a} 100]
set a {}
puts [time {bcappendinp a} 100]
