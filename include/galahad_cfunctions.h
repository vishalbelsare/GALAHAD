#ifdef GALAHAD_SINGLE
#define arc_initialize arc_initialize_s
#define arc_read_specfile arc_read_specfile_s
#define arc_import arc_import_s
#define arc_reset_control arc_reset_control_s
#define arc_solve_with_mat arc_solve_with_mat_s
#define arc_solve_without_mat arc_solve_without_mat_s
#define arc_solve_reverse_with_mat arc_solve_reverse_with_mat_s
#define arc_solve_reverse_without_mat arc_solve_reverse_without_mat_s
#define arc_information arc_information_s
#define arc_terminate arc_terminate_s
#define bgo_initialize bgo_initialize_s
#define bgo_read_specfile bgo_read_specfile_s
#define bgo_import bgo_import_s
#define bgo_reset_control bgo_reset_control_s
#define bgo_solve_with_mat bgo_solve_with_mat_s
#define bgo_solve_without_mat bgo_solve_without_mat_s
#define bgo_solve_reverse_with_mat bgo_solve_reverse_with_mat_s
#define bgo_solve_reverse_without_mat bgo_solve_reverse_without_mat_s
#define bgo_information bgo_information_s
#define bgo_terminate bgo_terminate_s
#define blls_initialize blls_initialize_s
#define blls_read_specfile blls_read_specfile_s
#define blls_import blls_import_s
#define blls_import_without_a blls_import_without_a_s
#define blls_reset_control blls_reset_control_s
#define blls_solve_given_a blls_solve_given_a_s
#define blls_solve_reverse_a_prod blls_solve_reverse_a_prod_s
#define blls_information blls_information_s
#define blls_terminate blls_terminate_s
#define bqpb_initialize bqpb_initialize_s
#define bqpb_read_specfile bqpb_read_specfile_s
#define bqpb_import bqpb_import_s
#define bqpb_reset_control bqpb_reset_control_s
#define bqpb_solve_qp bqpb_solve_qp_s
#define bqpb_solve_sldqp bqpb_solve_sldqp_s
#define bqpb_information bqpb_information_s
#define bqpb_terminate bqpb_terminate_s
#define bqp_initialize bqp_initialize_s
#define bqp_read_specfile bqp_read_specfile_s
#define bqp_import bqp_import_s
#define bqp_import_without_h bqp_import_without_h_s
#define bqp_reset_control bqp_reset_control_s
#define bqp_solve_given_h bqp_solve_given_h_s
#define bqp_solve_reverse_h_prod bqp_solve_reverse_h_prod_s
#define bqp_information bqp_information_s
#define bqp_terminate bqp_terminate_s
#define bsc_initialize bsc_initialize_s
#define bsc_read_specfile bsc_read_specfile_s
#define bsc_terminate bsc_terminate_s
#define ccqp_initialize ccqp_initialize_s
#define ccqp_read_specfile ccqp_read_specfile_s
#define ccqp_import ccqp_import_s
#define ccqp_reset_control ccqp_reset_control_s
#define ccqp_solve_qp ccqp_solve_qp_s
#define ccqp_solve_sldqp ccqp_solve_sldqp_s
#define ccqp_information ccqp_information_s
#define ccqp_terminate ccqp_terminate_s
#define clls_initialize clls_initialize_s
#define clls_read_specfile clls_read_specfile_s
#define clls_import clls_import_s
#define clls_reset_control clls_reset_control_s
#define clls_solve_clls clls_solve_clls_s
#define clls_information clls_information_s
#define clls_terminate clls_terminate_s
#define cqp_initialize cqp_initialize_s
#define cqp_read_specfile cqp_read_specfile_s
#define cqp_import cqp_import_s
#define cqp_reset_control cqp_reset_control_s
#define cqp_solve_qp cqp_solve_qp_s
#define cqp_solve_sldqp cqp_solve_sldqp_s
#define cqp_information cqp_information_s
#define cqp_terminate cqp_terminate_s
#define cro_initialize cro_initialize_s
#define cro_read_specfile cro_read_specfile_s
#define cro_crossover_solution cro_crossover_solution_s
#define cro_terminate cro_terminate_s
#define dgo_initialize dgo_initialize_s
#define dgo_read_specfile dgo_read_specfile_s
#define dgo_import dgo_import_s
#define dgo_reset_control dgo_reset_control_s
#define dgo_solve_with_mat dgo_solve_with_mat_s
#define dgo_solve_without_mat dgo_solve_without_mat_s
#define dgo_solve_reverse_with_mat dgo_solve_reverse_with_mat_s
#define dgo_solve_reverse_without_mat dgo_solve_reverse_without_mat_s
#define dgo_information dgo_information_s
#define dgo_terminate dgo_terminate_s
#define dps_initialize dps_initialize_s
#define dps_read_specfile dps_read_specfile_s
#define dps_import dps_import_s
#define dps_reset_control dps_reset_control_s
#define dps_solve_tr_problem dps_solve_tr_problem_s
#define dps_solve_rq_problem dps_solve_rq_problem_s
#define dps_resolve_tr_problem dps_resolve_tr_problem_s
#define dps_resolve_rq_problem dps_resolve_rq_problem_s
#define dps_information dps_information_s
#define dps_terminate dps_terminate_s
#define dqp_initialize dqp_initialize_s
#define dqp_read_specfile dqp_read_specfile_s
#define dqp_import dqp_import_s
#define dqp_reset_control dqp_reset_control_s
#define dqp_solve_qp dqp_solve_qp_s
#define dqp_solve_sldqp dqp_solve_sldqp_s
#define dqp_information dqp_information_s
#define dqp_terminate dqp_terminate_s
#define eqp_initialize eqp_initialize_s
#define eqp_read_specfile eqp_read_specfile_s
#define eqp_import eqp_import_s
#define eqp_reset_control eqp_reset_control_s
#define eqp_solve_qp eqp_solve_qp_s
#define eqp_solve_sldqp eqp_solve_sldqp_s
#define eqp_resolve_qp eqp_resolve_qp_s
#define eqp_information eqp_information_s
#define eqp_terminate eqp_terminate_s
#define fdc_initialize fdc_initialize_s
#define fdc_read_specfile fdc_read_specfile_s
#define fdc_find_dependent_rows fdc_find_dependent_rows_s
#define fdc_terminate fdc_terminate_s
#define fit_initialize fit_initialize_s
#define fit_read_specfile fit_read_specfile_s
#define fit_terminate fit_terminate_s
#define glrt_initialize glrt_initialize_s
#define glrt_read_specfile glrt_read_specfile_s
#define glrt_import_control glrt_import_control_s
#define glrt_solve_problem glrt_solve_problem_s
#define glrt_information glrt_information_s
#define glrt_terminate glrt_terminate_s
#define gls_initialize gls_initialize_s
#define gls_reset_control gls_reset_control_s
#define gls_information gls_information_s
#define gls_finalize gls_finalize_s
#define gltr_initialize gltr_initialize_s
#define gltr_read_specfile gltr_read_specfile_s
#define gltr_import_control gltr_import_control_s
#define gltr_solve_problem gltr_solve_problem_s
#define gltr_information gltr_information_s
#define gltr_terminate gltr_terminate_s
#define hash_initialize hash_initialize_s
#define hash_terminate hash_terminate_s
#define l2rt_initialize l2rt_initialize_s
#define l2rt_read_specfile l2rt_read_specfile_s
#define l2rt_import_control l2rt_import_control_s
#define l2rt_solve_problem l2rt_solve_problem_s
#define l2rt_information l2rt_information_s
#define l2rt_terminate l2rt_terminate_s
#define lhs_initialize lhs_initialize_s
#define lhs_read_specfile lhs_read_specfile_s
#define lhs_ihs lhs_ihs_s
#define lhs_get_seed lhs_get_seed_s
#define lhs_terminate lhs_terminate_s
#define lms_initialize lms_initialize_s
#define lms_read_specfile lms_read_specfile_s
#define lms_terminate lms_terminate_s
#define lpa_initialize lpa_initialize_s
#define lpa_read_specfile lpa_read_specfile_s
#define lpa_import lpa_import_s
#define lpa_reset_control lpa_reset_control_s
#define lpa_solve_lp lpa_solve_lp_s
#define lpa_information lpa_information_s
#define lpa_terminate lpa_terminate_s
#define lpb_initialize lpb_initialize_s
#define lpb_read_specfile lpb_read_specfile_s
#define lpb_import lpb_import_s
#define lpb_reset_control lpb_reset_control_s
#define lpb_solve_lp lpb_solve_lp_s
#define lpb_information lpb_information_s
#define lpb_terminate lpb_terminate_s
#define lsqp_initialize lsqp_initialize_s
#define lsqp_read_specfile lsqp_read_specfile_s
#define lsqp_import lsqp_import_s
#define lsqp_reset_control lsqp_reset_control_s
#define lsqp_solve_qp lsqp_solve_qp_s
#define lsqp_information lsqp_information_s
#define lsqp_terminate lsqp_terminate_s
#define lsrt_initialize lsrt_initialize_s
#define lsrt_read_specfile lsrt_read_specfile_s
#define lsrt_import_control lsrt_import_control_s
#define lsrt_solve_problem lsrt_solve_problem_s
#define lsrt_information lsrt_information_s
#define lsrt_terminate lsrt_terminate_s
#define lstr_initialize lstr_initialize_s
#define lstr_read_specfile lstr_read_specfile_s
#define lstr_import_control lstr_import_control_s
#define lstr_solve_problem lstr_solve_problem_s
#define lstr_information lstr_information_s
#define lstr_terminate lstr_terminate_s
#define nls_initialize nls_initialize_s
#define nls_read_specfile nls_read_specfile_s
#define nls_import nls_import_s
#define nls_reset_control nls_reset_control_s
#define nls_solve_with_mat nls_solve_with_mat_s
#define nls_solve_without_mat nls_solve_without_mat_s
#define nls_solve_reverse_with_mat nls_solve_reverse_with_mat_s
#define nls_solve_reverse_without_mat nls_solve_reverse_without_mat_s
#define nls_information nls_information_s
#define nls_terminate nls_terminate_s
#define presolve_initialize presolve_initialize_s
#define presolve_read_specfile presolve_read_specfile_s
#define presolve_import_problem presolve_import_problem_s
#define presolve_transform_problem presolve_transform_problem_s
#define presolve_restore_solution presolve_restore_solution_s
#define presolve_information presolve_information_s
#define presolve_terminate presolve_terminate_s
#define psls_initialize psls_initialize_s
#define psls_read_specfile psls_read_specfile_s
#define psls_import psls_import_s
#define psls_reset_control psls_reset_control_s
#define psls_form_preconditioner psls_form_preconditioner_s
#define psls_form_subset_preconditioner psls_form_subset_preconditioner_s
#define psls_update_preconditioner psls_update_preconditioner_s
#define psls_apply_preconditioner psls_apply_preconditioner_s
#define psls_information psls_information_s
#define psls_terminate psls_terminate_s
#define qpa_initialize qpa_initialize_s
#define qpa_read_specfile qpa_read_specfile_s
#define qpa_import qpa_import_s
#define qpa_reset_control qpa_reset_control_s
#define qpa_solve_qp qpa_solve_qp_s
#define qpa_solve_l1qp qpa_solve_l1qp_s
#define qpa_solve_bcl1qp qpa_solve_bcl1qp_s
#define qpa_information qpa_information_s
#define qpa_terminate qpa_terminate_s
#define qpb_initialize qpb_initialize_s
#define qpb_read_specfile qpb_read_specfile_s
#define qpb_import qpb_import_s
#define qpb_reset_control qpb_reset_control_s
#define qpb_solve_qp qpb_solve_qp_s
#define qpb_information qpb_information_s
#define qpb_terminate qpb_terminate_s
#define roots_initialize roots_initialize_s
#define roots_read_specfile roots_read_specfile_s
#define roots_terminate roots_terminate_s
#define rpd_initialize rpd_initialize_s
#define rpd_get_stats rpd_get_stats_s
#define rpd_get_g rpd_get_g_s
#define rpd_get_f rpd_get_f_s
#define rpd_get_xlu rpd_get_xlu_s
#define rpd_get_clu rpd_get_clu_s
#define rpd_get_h rpd_get_h_s
#define rpd_get_a rpd_get_a_s
#define rpd_get_h_c rpd_get_h_c_s
#define rpd_get_x_type rpd_get_x_type_s
#define rpd_get_x rpd_get_x_s
#define rpd_get_y rpd_get_y_s
#define rpd_get_z rpd_get_z_s
#define rpd_terminate rpd_terminate_s
#define rqs_initialize rqs_initialize_s
#define rqs_read_specfile rqs_read_specfile_s
#define rqs_import rqs_import_s
#define rqs_import_m rqs_import_m_s
#define rqs_import_a rqs_import_a_s
#define rqs_reset_control rqs_reset_control_s
#define rqs_solve_problem rqs_solve_problem_s
#define rqs_information rqs_information_s
#define rqs_terminate rqs_terminate_s
#define sbls_initialize sbls_initialize_s
#define sbls_read_specfile sbls_read_specfile_s
#define sbls_import sbls_import_s
#define sbls_reset_control sbls_reset_control_s
#define sbls_factorize_matrix sbls_factorize_matrix_s
#define sbls_solve_system sbls_solve_system_s
#define sbls_information sbls_information_s
#define sbls_terminate sbls_terminate_s
#define scu_terminate scu_terminate_s
#define sec_initialize sec_initialize_s
#define sec_read_specfile sec_read_specfile_s
#define sec_terminate sec_terminate_s
#define sha_initialize sha_initialize_s
#define sha_read_specfile sha_read_specfile_s
#define sha_terminate sha_terminate_s
#define sils_initialize sils_initialize_s
#define sils_reset_control sils_reset_control_s
#define sils_information sils_information_s
#define sils_finalize sils_finalize_s
#define slls_initialize slls_initialize_s
#define slls_read_specfile slls_read_specfile_s
#define slls_import slls_import_s
#define slls_import_without_a slls_import_without_a_s
#define slls_reset_control slls_reset_control_s
#define slls_solve_given_a slls_solve_given_a_s
#define slls_solve_reverse_a_prod slls_solve_reverse_a_prod_s
#define slls_information slls_information_s
#define slls_terminate slls_terminate_s
#define sls_initialize sls_initialize_s
#define sls_read_specfile sls_read_specfile_s
#define sls_analyse_matrix sls_analyse_matrix_s
#define sls_reset_control sls_reset_control_s
#define sls_factorize_matrix sls_factorize_matrix_s
#define sls_solve_system sls_solve_system_s
#define sls_partial_solve_system sls_partial_solve_system_s
#define sls_information sls_information_s
#define sls_terminate sls_terminate_s
#define trb_initialize trb_initialize_s
#define trb_read_specfile trb_read_specfile_s
#define trb_import trb_import_s
#define trb_reset_control trb_reset_control_s
#define trb_solve_with_mat trb_solve_with_mat_s
#define trb_solve_without_mat trb_solve_without_mat_s
#define trb_solve_reverse_with_mat trb_solve_reverse_with_mat_s
#define trb_solve_reverse_without_mat trb_solve_reverse_without_mat_s
#define trb_information trb_information_s
#define trb_terminate trb_terminate_s
#define trs_initialize trs_initialize_s
#define trs_read_specfile trs_read_specfile_s
#define trs_import trs_import_s
#define trs_import_m trs_import_m_s
#define trs_import_a trs_import_a_s
#define trs_reset_control trs_reset_control_s
#define trs_solve_problem trs_solve_problem_s
#define trs_information trs_information_s
#define trs_terminate trs_terminate_s
#define tru_initialize tru_initialize_s
#define tru_read_specfile tru_read_specfile_s
#define tru_import tru_import_s
#define tru_reset_control tru_reset_control_s
#define tru_solve_with_mat tru_solve_with_mat_s
#define tru_solve_without_mat tru_solve_without_mat_s
#define tru_solve_reverse_with_mat tru_solve_reverse_with_mat_s
#define tru_solve_reverse_without_mat tru_solve_reverse_without_mat_s
#define tru_information tru_information_s
#define tru_terminate tru_terminate_s
#define ugo_initialize ugo_initialize_s
#define ugo_read_specfile ugo_read_specfile_s
#define ugo_import ugo_import_s
#define ugo_reset_control ugo_reset_control_s
#define ugo_solve_direct ugo_solve_direct_s
#define ugo_solve_reverse ugo_solve_reverse_s
#define ugo_information ugo_information_s
#define ugo_terminate ugo_terminate_s
#define uls_initialize uls_initialize_s
#define uls_read_specfile uls_read_specfile_s
#define uls_factorize_matrix uls_factorize_matrix_s
#define uls_reset_control uls_reset_control_s
#define uls_solve_system uls_solve_system_s
#define uls_information uls_information_s
#define uls_terminate uls_terminate_s
#define wcp_initialize wcp_initialize_s
#define wcp_read_specfile wcp_read_specfile_s
#define wcp_import wcp_import_s
#define wcp_reset_control wcp_reset_control_s
#define wcp_find_wcp wcp_find_wcp_s
#define wcp_information wcp_information_s
#define wcp_terminate wcp_terminate_s
#define spral_c_dgemm spral_c_sgemm
#define spral_c_dpotrf spral_c_spotrf
#define spral_c_dsytrf spral_c_ssytrf
#define spral_c_dtrsm spral_c_strsm
#define spral_c_dsyrk spral_c_ssyrk
#define spral_c_dtrsv spral_c_strsv
#define spral_c_dgemv spral_c_sgemv
#endif
