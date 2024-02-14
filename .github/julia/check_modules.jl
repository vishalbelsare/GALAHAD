using Test

function exported_modules(path::String)
  modules = String[]
  files = readdir(path)
  for file in files
    if endswith(file, ".mod")
      push!(modules, file)
    end
  end
  return modules
end

modules_single_int32 = exported_modules(joinpath(@__DIR__, "..", "..", "builddir_int32", "libgalahad_single.so.p"))
modules_double_int32 = exported_modules(joinpath(@__DIR__, "..", "..", "builddir_int32", "libgalahad_double.so.p"))
modules_single_int64 = exported_modules(joinpath(@__DIR__, "..", "..", "builddir_int64", "libgalahad_single.so.p"))
modules_double_int64 = exported_modules(joinpath(@__DIR__, "..", "..", "builddir_int64", "libgalahad_double.so.p"))

modules_combinations = [(modules_single_int32, modules_double_int32, 32, 32, "libgalahad_single.so (Int32) and libgalahad_double.so (Int32)"),
                        (modules_single_int32, modules_single_int64, 32, 64, "libgalahad_single.so (Int32) and libgalahad_single.so (Int64)"),
                        (modules_single_int32, modules_double_int64, 32, 64, "libgalahad_single.so (Int32) and libgalahad_double.so (Int64)"),
                        (modules_double_int32, modules_single_int64, 32, 64, "libgalahad_double.so (Int32) and libgalahad_single.so (Int64)"),
                        (modules_double_int32, modules_double_int64, 32, 64, "libgalahad_double.so (Int32) and libgalahad_double.so (Int64)"),
                        (modules_double_int64, modules_double_int64, 64, 64, "libgalahad_double.so (Int64) and libgalahad_double.so (Int64)")]

single_double_modules = ["galahad_blas_interface", "galahad_lapack_interface", "galahad_clock", "galahad_common_ciface",
                         "galahad_copyright", "galahad_hash", "galahad_hash_ciface", "galahad_hsl_kb22_long_integer",
                         "galahad_hsl_mc68_integer", "galahad_hsl_mc68_integer_ciface", "galahad_hsl_mc78_integer",
                         "galahad_hsl_of01_integer", "galahad_hsl_zb01_integer", "galahad_kinds", "galahad_kinds_double",
                         "galahad_kinds_single", "galahad_string", "galahad_symbols", "galahad_tools", "lancelot_hsl_routines",
                         "mkl_pardiso", "mkl_pardiso_private", "pastixf_enums", "pastixf_interfaces", "spmf_enums",
                         "spmf_interfaces", "spral_core_analyse", "spral_hw_topology", "spral_kinds", "spral_kinds_double",
                         "spral_kinds_single", "spral_metis_wrapper", "spral_pgm", "spral_ssids_blas_iface",
                         "spral_ssids_lapack_iface", "spral_ssids_profile"]

for (modules1, modules2, int1, int2, name) in modules_combinations
  intersect_modules = intersect(modules1, modules2)
  println("---------------------------------------------------------------------------------------------------------------------------")
  @warn("The following modules are generated for both libraries $name:")
  for mod in intersect_modules
    flag1 = mapreduce(x -> (x * ".mod") == mod, |, single_double_modules) && (int1 == int2 == 32)
    flag2 = mapreduce(x -> (x * "_64.mod") == mod, |, single_double_modules) && (int1 == int2 == 64)
    if !flag1 && !flag2
      println(mod)
    end
  end
  println("---------------------------------------------------------------------------------------------------------------------------")
  println()
end