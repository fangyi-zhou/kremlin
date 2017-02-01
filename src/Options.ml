(** Some of these will be filled by [Driver]. In particular, the following are
 * automatically added:
 * $krml_home/kremlib/kremlib.c is added to c_files
 * $krml_home/kremlib is added to includes
 *)
let no_prefix: string list ref = ref [ "C" ]
let add_include: string list ref = ref [ "\"kremlib.h\"" ]
let warn_error = ref "+1-2+3..8"
let tmpdir = ref "."
let includes: string list ref = ref [ "FSTAR_LIB/hyperstack" ]
let verbose = ref false
let exe_name = ref ""
let cc = ref "gcc"
let m32 = ref false
let fsopts: string list ref = ref []
let ccopts: string list ref = ref []
let ldopts: string list ref = ref []
let bundle: Bundle.t list ref = ref [ [ "FStar" ], [ Bundle.Prefix [ "FStar" ] ] ]

(** These are modules that we do not want to drop (because they have meaningful
 * function signatures); but do not want to compile them (because they have no
 * meaning, contain only models, etc.). *)
let drop: Bundle.pat list ref =
  ref Bundle.([
    Module [ "C" ];
    Module [ "FStar"; "Int"; "Cast" ];
    Module [ "FStar"; "Heap"; ];
    Module [ "FStar"; "Monotonic"; "RRef" ];
  ])
