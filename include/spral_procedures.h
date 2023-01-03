#ifdef SPRAL_SINGLE
#define analyse_precision analyse_single
#define analyse_precision_ptr32 analyse_single_ptr32
#define apply_conversion_map_ptr32_precision apply_conversion_map_ptr32_single
#define apply_conversion_map_ptr64_precision apply_conversion_map_ptr64_single
#define clean_cscl_oop_ptr32_precision clean_cscl_oop_ptr32_single
#define clean_cscl_oop_ptr64_precision clean_cscl_oop_ptr64_single
#define convert_coord_to_cscl_ptr32_precision convert_coord_to_cscl_ptr32_single
#define convert_coord_to_cscl_ptr64_precision convert_coord_to_cscl_ptr64_single
#define cscl_verify_precision cscl_verify_single
#define cudaMemcpy_h2d_precision cudaMemcpy_h2d_single
#define factor_alloc_precision factor_alloc_single
#define free_akeep_precision free_akeep_single
#define free_both_precision free_both_single
#define free_fkeep_precision free_fkeep_single
#define print_matrix_int_precision print_matrix_int_single
#define print_matrix_long_precision print_matrix_long_single
#define rb_read_precision_int32 rb_read_single_int32
#define rb_read_precision_int64 rb_read_single_int64
#define rb_write_precision_int32 rb_write_single_int32
#define rb_write_precision_int64 rb_write_single_int64
#define simd_precision_type simd_single_type
#define simd_precision_type_val simd_single_type_val
#define spral_ssids_precision spral_ssids_single
#define ssids_alter_precision ssids_alter_single
#define ssids_analyse_coord_precision ssids_analyse_coord_single
#define ssids_enquire_indef_precision ssids_enquire_indef_single
#define ssids_enquire_posdef_precision ssids_enquire_posdef_single
#define ssids_factor_ptr32_precision ssids_factor_ptr32_single
#define ssids_factor_ptr64_precision ssids_factor_ptr64_single
#define ssids_solve_mult_precision ssids_solve_mult_single
#define ssids_solve_one_precision ssids_solve_one_single
#define spral_blas_iface_precision spral_blas_iface_single
#define spral_core_analyse_precision spral_core_analyse_single
#define spral_cuda_precision spral_cuda_single
#define spral_lapack_iface_precision spral_lapack_iface_single
#define spral_match_order_precision spral_match_order_single
#define spral_matrix_util_precision spral_matrix_util_single
#define spral_random_precision spral_random_single
#define spral_rutherford_boeing_precision spral_rutherford_boeing_single
#define spral_scaling_precision spral_scaling_single
#define spral_ssids_precision spral_ssids_single
#define spral_ssids_akeep_precision spral_ssids_akeep_single
#define spral_ssids_anal_precision spral_ssids_anal_single
#define spral_ssids_contrib_precision spral_ssids_contrib_single
#define spral_ssids_contrib_free_precision spral_ssids_contrib_free_sgl
#define spral_ssids_contrib_precision_free spral_ssids_contrib_single_free
#define spral_ssids_cpu_iface_precision spral_ssids_cpu_iface_single
#define spral_ssids_cpu_subtree_precision spral_ssids_cpu_subtree_single
#define spral_ssids_types_precision spral_ssids_types_single
#define spral_ssids_fkeep_precision spral_ssids_fkeep_single
#define spral_ssids_gpu_alloc_precision spral_ssids_gpu_alloc_single
#define spral_ssids_gpu_types_precision spral_ssids_gpu_types_single
#define spral_ssids_gpu_denfact_precision spral_ssids_gpu_denfact_single
#define spral_ssids_gpu_factor_precision spral_ssids_gpu_factor_single
#define spral_ssids_gpu_ifaces_precision spral_ssids_gpu_ifaces_single
#define spral_ssids_gpu_smalloc_precision spral_ssids_gpu_smalloc_single
#define spral_ssids_gpu_solve_precision spral_ssids_gpu_solve_single
#define spral_ssids_gpu_subtree_precision spral_ssids_gpu_subtree_single
#define spral_ssids_inform_precision spral_ssids_inform_single
#define spral_ssids_profile_precision spral_ssids_profile_single
#define spral_ssids_subtree_precision spral_ssids_subtree_single
#define spral_ssids_contrib_get_data_precision spral_ssids_contrib_get_data_single
#else
#define analyse_precision analyse_double
#define analyse_precision_ptr32 analyse_double_ptr32
#define apply_conversion_map_ptr32_precision apply_conversion_map_ptr32_double
#define apply_conversion_map_ptr64_precision apply_conversion_map_ptr64_double
#define clean_cscl_oop_ptr32_precision clean_cscl_oop_ptr32_double
#define clean_cscl_oop_ptr64_precision clean_cscl_oop_ptr64_double
#define convert_coord_to_cscl_ptr32_precision convert_coord_to_cscl_ptr32_double
#define convert_coord_to_cscl_ptr64_precision convert_coord_to_cscl_ptr64_double
#define cscl_verify_precision cscl_verify_double
#define cudaMemcpy_h2d_precision cudaMemcpy_h2d_double
#define factor_alloc_precision factor_alloc_double
#define free_akeep_precision free_akeep_double
#define free_both_precision free_both_double
#define free_fkeep_precision free_fkeep_double
#define print_matrix_int_precision print_matrix_int_double
#define print_matrix_long_precision print_matrix_long_double
#define rb_read_precision_int32 rb_read_double_int32
#define rb_read_precision_int64 rb_read_double_int64
#define rb_write_precision_int32 rb_write_double_int32
#define rb_write_precision_int64 rb_write_double_int64
#define simd_precision_type simd_double_type
#define simd_precision_type_val simd_double_type_val
#define spral_ssids_precision spral_ssids_double
#define ssids_alter_precision ssids_alter_double
#define ssids_analyse_coord_precision ssids_analyse_coord_double
#define ssids_enquire_indef_precision ssids_enquire_indef_double
#define ssids_enquire_posdef_precision ssids_enquire_posdef_double
#define ssids_factor_ptr32_precision ssids_factor_ptr32_double
#define ssids_factor_ptr64_precision ssids_factor_ptr64_double
#define ssids_solve_mult_precision ssids_solve_mult_double
#define ssids_solve_one_precision ssids_solve_one_double
#define spral_blas_iface_precision spral_blas_iface_double
#define spral_core_analyse_precision spral_core_analyse_double
#define spral_cuda_precision spral_cuda_double
#define spral_lapack_iface_precision spral_lapack_iface_double
#define spral_match_order_precision spral_match_order_double
#define spral_matrix_util_precision spral_matrix_util_double
#define spral_random_precision spral_random_double
#define spral_rutherford_boeing_precision spral_rutherford_boeing_double
#define spral_scaling_precision spral_scaling_double
#define spral_ssids_precision spral_ssids_double
#define spral_ssids_akeep_precision spral_ssids_akeep_double
#define spral_ssids_anal_precision spral_ssids_anal_double
#define spral_ssids_contrib_precision spral_ssids_contrib_double
#define spral_ssids_contrib_precision_free spral_ssids_contrib_double_free
#define spral_ssids_contrib_free_precision spral_ssids_contrib_free_dbl
#define spral_ssids_cpu_iface_precision spral_ssids_cpu_iface_double
#define spral_ssids_cpu_subtree_precision spral_ssids_cpu_subtree_double
#define spral_ssids_fkeep_precision spral_ssids_fkeep_double
#define spral_ssids_types_precision spral_ssids_types_double
#define spral_ssids_gpu_alloc_precision spral_ssids_gpu_alloc_double
#define spral_ssids_gpu_types_precision spral_ssids_gpu_types_double
#define spral_ssids_gpu_denfact_precision spral_ssids_gpu_denfact_double
#define spral_ssids_gpu_factor_precision spral_ssids_gpu_factor_double
#define spral_ssids_gpu_ifaces_precision spral_ssids_gpu_ifaces_double
#define spral_ssids_gpu_smalloc_precision spral_ssids_gpu_smalloc_double
#define spral_ssids_gpu_solve_precision spral_ssids_gpu_solve_double
#define spral_ssids_gpu_subtree_precision spral_ssids_gpu_subtree_double
#define spral_ssids_inform_precision spral_ssids_inform_double
#define spral_ssids_profile_precision spral_ssids_profile_double
#define spral_ssids_subtree_precision spral_ssids_subtree_double
#define spral_ssids_contrib_get_data_precision spral_ssids_contrib_get_data_double
#endif


