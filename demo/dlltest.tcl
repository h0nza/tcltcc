load ../tcc02.dll
proc to_dll {code dll} {
    tcc ../pkg dll tcc_1
    tcc_1 add_library tcl8.5
    if {$::tcl_platform(platform) eq "windows"} {
        tcc_1 define DLL_EXPORT {__declspec(dllexport)} 
        set f [open ../pkg/c/dllcrt1.c]
        tcc_1 compile [read $f]
        close $f
        set f [open ../pkg/c/dllmain.c]
        tcc_1 compile [read $f]
        close $f
    } else {
        tcc_1 define DLL_EXPORT ""
    }
        
    tcc_1 compile $code
    tcc_1 output_file $dll
    rename tcc_1 {}
}

set code {
    #include "tcl.h"
    DLL_EXPORT int Test_Init(Tcl_Interp *interp)
    {
        Tcl_Eval(interp, "puts success");
        return TCL_OK;
    }
}

puts [time {to_dll $code test[info sharedlibextension]}]
load test[info sharedlibextension]
