set auto_path [linsert $auto_path 0 ..]
package require tcc

tcc $tcc::dir dll tcc_1
set t tcc_1
puts $t
$t add_include_path expat
$t add_include_path generic
$t add_library tcl8.5

set tdomver 0.8.2

  lappend defs "BUILD_tdom=1"
  # tdom 0.8
  lappend defs "VERSION=\"$tdomver\""
  # tdom CVS
  lappend defs "PACKAGE_NAME=\"tdom\""
  lappend defs "PACKAGE_VERSION=\"$tdomver\""

  lappend defs "XML_DTD=1"
  lappend defs "XML_NS=1"
  lappend defs "TDOM_NO_UNKNOWN_CMD=1"
  lappend defs "HAVE_MEMMOVE=0"
  if {$::tcl_platform(platform) eq "windows"} {
    lappend defs "strcasecmp=stricmp"
  } 
  
  # Use Tcl allocator (instead of default tDom one, which is heap 
  # optimized, but not multi-thread friendly)
  lappend defs "USE_NORMAL_ALLOCATOR=1"
  
  # Since expat library is linked statically inside
  # same library than tdom, no need to have any special
  # call mechanism
  # lappend defs "XMLCALL="
  lappend defs "XML_STATIC=1"

foreach def $defs {
    puts $def
    eval $t define [split $def =]
}
$t define DLL_EXPORT {__declspec(dllexport)} 
puts [time {
foreach file [glob */*.c] {
    puts $file
    $t compile [read [open $file]]
}
$t add_file ../c/libtcc1.c
$t add_file ../c/dllcrt1.c
$t add_file ../c/dllmain.c
puts here

$t output_file tdom.0.8.2.dll
puts here
load tdom.0.8.2.dll
puts here

} 1]
puts [[dom parse {<test><woot/></test>}] asXML]

# performance bench tcc/gcc
if {[file exists [file dirname [info script]]/large.xml]} {
    set f [open [file dirname [info script]]/large.xml]
    set xml [read $f]
    close $f
    rename dom tccdom
    package forget tdom
    package require tdom
    rename dom gccdom
    puts "Parsing a [file size [file dirname [info script]]/large.xml] byte XML file"
    puts "--------------------------------"
    puts "tcc: [time {tccdom parse $xml}]"
    puts "gcc: [time {gccdom parse $xml}]"
} else {
    puts "Put a large XML file large.xml in the demo directory to test the performance"
}
