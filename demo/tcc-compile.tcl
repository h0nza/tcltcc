switch -exact -- $::tcl_platform(platform) {
	windows {load ../tcc02.dll}
	unix {load ../libtcc0.2.so}
}
tcc .. dll tcc_1
set t tcc_1
puts $t
$t add_include_path ../generic/i386
$t add_include_path ../generic
$t define PACKAGE_NAME \"tcc\"
$t define PACKAGE_VERSION \"0.2\"
$t define DLL_EXPORT {__declspec(dllexport)}
$t define LIBTCC 1
$t define WIN32 1
$t add_library tcl8.5
$t add_file ../c/libtcc1.c
$t add_file ../c/dllcrt1.c
$t add_file ../c/dllmain.c
$t add_file ../generic/tcc.c
$t output_file tcc-test.dll

