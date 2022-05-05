! THIS VERSION: GALAHAD 4.0 - 2022-05-05 AT 08:00 GMT.

!-*-*-*-*-*-*-*-*-  G A L A H A D _ T R U   M O D U L E  *-*-*-*-*-*-*-*-*-*-

!  Copyright reserved, Gould/Orban/Toint, for GALAHAD productions
!  Principal author: Nick Gould

!  History -
!   originally released GALAHAD Version 2.2. May 16th 2008

!  For full documentation, see
!   http://galahad.rl.ac.uk/galahad-www/specs.html

   MODULE GALAHAD_TRU_double

!     --------------------------------------------------------------
!    |                                                              |
!    | TRU, a trust-region algorithm for unconstrained optimization |
!    |                                                              |
!    |   Aim: find a (local) minimizer of the objective f(x)        |
!    |                                                              |
!     --------------------------------------------------------------

     USE GALAHAD_CLOCK
     USE GALAHAD_SYMBOLS
     USE GALAHAD_NLPT_double, ONLY: NLPT_problem_type, NLPT_userdata_type
     USE GALAHAD_SPECFILE_double
     USE GALAHAD_PSLS_double
     USE GALAHAD_GLTR_double
     USE GALAHAD_TRS_double
     USE GALAHAD_DPS_double
     USE GALAHAD_LMS_double
     USE GALAHAD_SEC_double
     USE GALAHAD_SHA_double
     USE GALAHAD_SPACE_double
     USE GALAHAD_MOP_double, ONLY: mop_Ax
     USE GALAHAD_NORMS_double, ONLY: TWO_NORM
     USE GALAHAD_STRING, ONLY: STRING_integer_6
     USE GALAHAD_BLAS_interface, ONLY: SWAP
     USE GALAHAD_LAPACK_interface, ONLY : GESVD
!    USE SPDSOL
!    USE HSL_MI13
!    USE IEEE_ARITHMETIC

     IMPLICIT NONE

     PRIVATE
     PUBLIC :: TRU_initialize, TRU_read_specfile, TRU_solve,                   &
               TRU_terminate, NLPT_problem_type, NLPT_userdata_type,           &
               SMT_type, SMT_put,                                              &
               TRU_import, TRU_solve_with_mat, TRU_solve_without_mat,          &
               TRU_solve_reverse_with_mat, TRU_solve_reverse_without_mat,      &
               TRU_full_initialize, TRU_full_terminate, TRU_reset_control,     &
               TRU_information

!----------------------
!   I n t e r f a c e s
!----------------------

     INTERFACE TRU_initialize
       MODULE PROCEDURE TRU_initialize, TRU_full_initialize
     END INTERFACE TRU_initialize

     INTERFACE TRU_terminate
       MODULE PROCEDURE TRU_terminate, TRU_full_terminate
     END INTERFACE TRU_terminate

!--------------------
!   P r e c i s i o n
!--------------------

     INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
     INTEGER, PARAMETER :: long = SELECTED_INT_KIND( 18 )

!----------------------
!   P a r a m e t e r s
!----------------------

     INTEGER, PARAMETER  :: nskip_prec_max = 0
     INTEGER, PARAMETER  :: history_max = 100
     LOGICAL, PARAMETER  :: debug_model_4 = .TRUE.
     LOGICAL, PARAMETER  :: test_s = .TRUE.
!    LOGICAL, PARAMETER  :: test_s = .FALSE.
     REAL ( KIND = wp ), PARAMETER :: zero = 0.0_wp
     REAL ( KIND = wp ), PARAMETER :: one = 1.0_wp
     REAL ( KIND = wp ), PARAMETER :: two = 2.0_wp
     REAL ( KIND = wp ), PARAMETER :: three = 3.0_wp
     REAL ( KIND = wp ), PARAMETER :: half = 0.5_wp
     REAL ( KIND = wp ), PARAMETER :: tenth = 0.1_wp
     REAL ( KIND = wp ), PARAMETER :: sixteenth = 0.0625_wp
     REAL ( KIND = wp ), PARAMETER :: ten = 10.0_wp
     REAL ( KIND = wp ), PARAMETER :: hundred = 100.0_wp
     REAL ( KIND = wp ), PARAMETER :: sixteen = 16.0_wp
     REAL ( KIND = wp ), PARAMETER :: tenm5 = ten ** ( - 5 )
     REAL ( KIND = wp ), PARAMETER :: tenm8 = ten ** ( - 8 )
     REAL ( KIND = wp ), PARAMETER :: point9 = 0.9_wp
     REAL ( KIND = wp ), PARAMETER :: point1 = ten ** ( - 1 )
     REAL ( KIND = wp ), PARAMETER :: point01 = ten ** ( - 2 )
     REAL ( KIND = wp ), PARAMETER :: infinity = ten ** 19
     REAL ( KIND = wp ), PARAMETER :: epsmch = EPSILON( one )
     REAL ( KIND = wp ), PARAMETER :: teneps = ten * epsmch
     REAL ( KIND = wp ), PARAMETER :: rho_quad = epsmch * ten ** 4

     REAL ( KIND = wp ), PARAMETER :: gamma_1 = sixteenth
     REAL ( KIND = wp ), PARAMETER :: gamma_2 = half
     REAL ( KIND = wp ), PARAMETER :: gamma_3 = two
     REAL ( KIND = wp ), PARAMETER :: gamma_4 = sixteen
     REAL ( KIND = wp ), PARAMETER :: mu_1 = one - ten ** ( - 8 )
     REAL ( KIND = wp ), PARAMETER :: mu_2 = point1
     REAL ( KIND = wp ), PARAMETER :: theta = half
     REAL ( KIND = wp ), PARAMETER :: skip_sr1 = ten ** ( - 8 )

!  models

     INTEGER, PARAMETER  :: dynamic_model = 0
     INTEGER, PARAMETER  :: first_order_model = 1
     INTEGER, PARAMETER  :: second_order_model = 2
     INTEGER, PARAMETER  :: identity_hessian_model = 3
     INTEGER, PARAMETER  :: sparsity_hessian_model = 4
     INTEGER, PARAMETER  :: l_bfgs_hessian_model = 5
     INTEGER, PARAMETER  :: l_sr1_hessian_model = 6
     INTEGER, PARAMETER  :: bfgs_hessian_model = 7
     INTEGER, PARAMETER  :: sr1_hessian_model = 8

!  preconditioners (defines norms)

     INTEGER, PARAMETER  :: user_preconditioner = - 3
     INTEGER, PARAMETER  :: l_bfgs_preconditioner = - 2
     INTEGER, PARAMETER  :: identity_preconditioner = - 1
     INTEGER, PARAMETER  :: automatic_preconditioner = 0
     INTEGER, PARAMETER  :: diagonal_preconditioner = 1
     INTEGER, PARAMETER  :: band_preconditioner = 2
     INTEGER, PARAMETER  :: reordered_band_preconditioner = 3
     INTEGER, PARAMETER  :: schnabel_eskow_preconditioner = 4
     INTEGER, PARAMETER  :: gmps_preconditioner = 5
     INTEGER, PARAMETER  :: lin_more_preconditioner = 6
     INTEGER, PARAMETER  :: mi28_preconditioner = 7
     INTEGER, PARAMETER  :: munksgaard_preconditioner = 8
     INTEGER, PARAMETER  :: expanding_band_preconditioner = 9
     INTEGER, PARAMETER  :: diagonalising_preconditioner = 10

!-------------------------------------------------
!  D e r i v e d   t y p e   d e f i n i t i o n s
!-------------------------------------------------

!  - - - - - - - - - - - - - - - - - - - - - - -
!   control derived type with component defaults
!  - - - - - - - - - - - - - - - - - - - - - - -

     TYPE, PUBLIC :: TRU_control_type

!   error and warning diagnostics occur on stream error

       INTEGER :: error = 6

!   general output occurs on stream out

       INTEGER :: out = 6

!   the level of output required. <= 0 gives no output, = 1 gives a one-line
!    summary for every iteration, = 2 gives a summary of the inner iteration
!    for each iteration, >= 3 gives increasingly verbose (debugging) output

       INTEGER :: print_level = 0

!   any printing will start on this iteration

       INTEGER :: start_print = - 1

!   any printing will stop on this iteration

       INTEGER :: stop_print = - 1

!   the number of iterations between printing

       INTEGER :: print_gap = 1

!   the maximum number of iterations performed

       INTEGER :: maxit = 100

!   removal of the file alive_file from unit alive_unit terminates execution

       INTEGER :: alive_unit = 40
       CHARACTER ( LEN = 30 ) :: alive_file = 'ALIVE.d'

!   non-monotone <= 0 monotone strategy used, anything else non-monotone
!     strategy with this history length used

       INTEGER :: non_monotone = 1

!   specify the model used. Possible values are
!
!      0  dynamic (*not yet implemented*)
!      1  first-order (no Hessian)
!      2  second-order (exact Hessian)
!      3  barely second-order (identity Hessian)
!      4  secant second-order (sparsity-based)
!      5  secant second-order (limited-memory BFGS, with %lbfgs_vectors history)
!      6  secant second-order (limited-memory SR1, with %lbfgs_vectors history)
!      7  secant second-order (dense BFGS)
!      8  secant second-order (dense symmetric rank-one)

       INTEGER :: model = 2

!   specify the norm used. The norm is defined via ||v||^2 = v^T P v,
!    and will define the preconditioner used for iterative methods.
!    Possible values for P are
!
!     -3  user's own norm
!     -2  P = limited-memory BFGS matrix (with %lbfgs_vectors history)
!     -1  identity (= Euclidan two-norm)
!      0  automatic (*not yet implemented*)
!      1  diagonal, P = diag( max( Hessian, %min_diagonal ) )
!      2  banded, P = band( Hessian ) with semi-bandwidth %semi_bandwidth
!      3  re-ordered band, P=band(order(A)) with semi-bandwidth %semi_bandwidth
!      4  full factorization, P = Hessian, Schnabel-Eskow modification
!      5  full factorization, P = Hessian, GMPS modification (*not yet impltd*)
!      6  incomplete factorization of Hessian, Lin-More'
!      7  incomplete factorization of Hessian, HSL_MI28
!      8  incomplete factorization of Hessian, Munskgaard (*not yet impltd*)
!      9  expanding band of Hessian (*not yet implemented*)
!     10  diagonalizing norm from GALAHAD_DPS (*subproblem_direct only*)

       INTEGER :: norm = 1

!   specify the semi-bandwidth of the band matrix P if required

       INTEGER :: semi_bandwidth = 10

!   number of vectors used by the L-BFGS matrix P if required

       INTEGER :: lbfgs_vectors = 10

!   number of vectors used by the sparsity-based secant Hessian if required

       INTEGER :: max_dxg = 100

!   number of vectors used by the Lin-More' incomplete factorization
!    matrix P if required

       INTEGER :: icfs_vectors = 10

!  the maximum number of fill entries within each column of the incomplete
!  factor L computed by HSL_MI28. In general, increasing mi28_lsize improves
!  the quality of the preconditioner but increases the time to compute
!  and then apply the preconditioner. Values less than 0 are treated as 0

        INTEGER :: mi28_lsize = 10

!  the maximum number of entries within each column of the strictly lower
!  triangular matrix R used in the computation of the preconditioner by
!  HSL_MI28.  Rank-1 arrays of size mi28_rsize *  n are allocated internally
!  to hold R. Thus the amount of memory used, as well as the amount of work
!  involved in computing the preconditioner, depends on mi28_rsize. Setting
!  mi28_rsize > 0 generally leads to a higher quality preconditioner than
!  using mi28_rsize = 0, and choosing mi28_rsize >= mi28_lsize is generally
!  recommended

        INTEGER :: mi28_rsize = 10

!   try to pick a good initial trust-region radius using %advanced_start
!    iterates of a variant on the strategy of Sartenaer SISC 18(6)1990:1788-1803

       INTEGER :: advanced_start = 0

!   overall convergence tolerances. The iteration will terminate when the
!     norm of the gradient of the objective function is smaller than
!       MAX( %stop_g_absolute, %stop_g_relative * norm of the initial gradient
!     or if the step is less than %stop_s

       REAL ( KIND = wp ) :: stop_g_absolute = tenm5
       REAL ( KIND = wp ) :: stop_g_relative = tenm8
       REAL ( KIND = wp ) :: stop_s = epsmch

!   initial value for the trust-region radius (-ve => ||g_0||)

       REAL ( KIND = wp ) :: initial_radius = hundred

!   maximum permitted trust-region radius

       REAL ( KIND = wp ) :: maximum_radius = ten ** 8

!   a potential iterate will only be accepted if the actual decrease
!    f - f(x_new) is larger than %eta_successful times that predicted
!    by a quadratic model of the decrease. The trust-region radius will be
!    increased if this relative decrease is greater than %eta_very_successful
!    but smaller than %eta_too_successful

       REAL ( KIND = wp ) :: eta_successful = ten ** ( - 8 )
       REAL ( KIND = wp ) :: eta_very_successful = point9
       REAL ( KIND = wp ) :: eta_too_successful = two

!   on very successful iterations, the trust-region radius will be increased by
!    the factor %radius_increase, while if the iteration is unsucceful, the
!    radius will be decreased by a factor %radius_reduce but no more than
!    %radius_reduce_max

       REAL ( KIND = wp ) :: radius_increase = two
       REAL ( KIND = wp ) :: radius_reduce = half
       REAL ( KIND = wp ) :: radius_reduce_max = sixteenth

!   the smallest value the onjective function may take before the problem
!    is marked as unbounded

       REAL ( KIND = wp ) :: obj_unbounded = - epsmch ** ( - 2 )

!   the maximum CPU time allowed (-ve means infinite)

       REAL ( KIND = wp ) :: cpu_time_limit = - one

!   the maximum elapsed clock time allowed (-ve means infinite)

       REAL ( KIND = wp ) :: clock_time_limit = - one

!   is the Hessian matrix of second derivatives available or is access only
!    via matrix-vector products?

       LOGICAL :: hessian_available = .TRUE.

!   use a direct (factorization) or (preconditioned) iterative method to
!    find the search direction

       LOGICAL :: subproblem_direct = .FALSE.

!   is a retrospective strategy to be used to update the trust-region radius?

       LOGICAL :: retrospective_trust_region = .FALSE.

!   should the radius be renormalized to account for a change in preconditioner?

       LOGICAL :: renormalize_radius = .FALSE.

!   if %space_critical true, every effort will be made to use as little
!    space as possible. This may result in longer computation time

       LOGICAL :: space_critical = .FALSE.

!   if %deallocate_error_fatal is true, any array/pointer deallocation error
!     will terminate execution. Otherwise, computation will continue

       LOGICAL :: deallocate_error_fatal = .FALSE.

!  all output lines will be prefixed by %prefix(2:LEN(TRIM(%prefix))-1)
!   where %prefix contains the required string enclosed in
!   quotes, e.g. "string" or 'string'

       CHARACTER ( LEN = 30 ) :: prefix = '""                            '

!  control parameters for TRS

       TYPE ( TRS_control_type ) :: TRS_control

!  control parameters for DPS

       TYPE ( DPS_control_type ) :: DPS_control

!  control parameters for GLTR

       TYPE ( GLTR_control_type ) :: GLTR_control

!  control parameters for PSLS

       TYPE ( PSLS_control_type ) :: PSLS_control

!  control parameters for LMS

       TYPE ( LMS_control_type ) :: LMS_control
       TYPE ( LMS_control_type ) :: LMS_control_prec

!  control parameters for SEC

       TYPE ( SEC_control_type ) :: SEC_control

!  control parameters for SHA

       TYPE ( SHA_control_type ) :: SHA_control
     END TYPE TRU_control_type

!  - - - - - - - - - - - - - - - - - - - - - -
!   time derived type with component defaults
!  - - - - - - - - - - - - - - - - - - - - - -

     TYPE, PUBLIC :: TRU_time_type

!  the total CPU time spent in the package

       REAL :: total = 0.0

!  the CPU time spent preprocessing the problem

       REAL :: preprocess = 0.0

!  the CPU time spent analysing the required matrices prior to factorization

       REAL :: analyse = 0.0

!  the CPU time spent factorizing the required matrices

       REAL :: factorize = 0.0

!  the CPU time spent computing the search direction

       REAL :: solve = 0.0

!  the total clock time spent in the package

       REAL ( KIND = wp ) :: clock_total = 0.0

!  the clock time spent preprocessing the problem

       REAL ( KIND = wp ) :: clock_preprocess = 0.0

!  the clock time spent analysing the required matrices prior to factorization

       REAL ( KIND = wp ) :: clock_analyse = 0.0

!  the clock time spent factorizing the required matrices

       REAL ( KIND = wp ) :: clock_factorize = 0.0

!  the clock time spent computing the search direction

       REAL ( KIND = wp ) :: clock_solve = 0.0

     END TYPE

!  - - - - - - - - - - - - - - - - - - - - - - -
!   inform derived type with component defaults
!  - - - - - - - - - - - - - - - - - - - - - - -

     TYPE, PUBLIC :: TRU_inform_type

!  return status. See TRU_solve for details

       INTEGER :: status = 0

!  the status of the last attempted allocation/deallocation

       INTEGER :: alloc_status = 0

!  the name of the array for which an allocation/deallocation error ocurred

       CHARACTER ( LEN = 80 ) :: bad_alloc = REPEAT( ' ', 80 )

!  the total number of iterations performed

       INTEGER :: iter = 0

!  the total number of CG iterations performed

       INTEGER :: cg_iter = 0

!  the total number of evaluations of the objection function

       INTEGER :: f_eval = 0

!  the total number of evaluations of the gradient of the objection function

       INTEGER :: g_eval = 0

!  the total number of evaluations of the Hessian of the objection function

       INTEGER :: h_eval = 0

!  the return status from the factorization

       INTEGER :: factorization_status = 0

!  the maximum number of factorizations in a sub-problem solve

       INTEGER :: factorization_max = 0

!   the maximum number of entries in the factors

        INTEGER ( KIND = long ) :: max_entries_factors = 0

!  the total integer workspace required for the factorization

       INTEGER :: factorization_integer = - 1

!  the total real workspace required for the factorization

       INTEGER :: factorization_real = - 1

!  the average number of factorizations per sub-problem solve

       REAL ( KIND = wp ) :: factorization_average = zero

!  the value of the objective function at the best estimate of the solution
!   determined by TRU_solve

       REAL ( KIND = wp ) :: obj = HUGE( one )

!  the norm of the gradient of the objective function at the best estimate
!   of the solution determined by TRU_solve

       REAL ( KIND = wp ) :: norm_g = HUGE( one )

!  the current value of the trust-region radius

       REAL ( KIND = wp ) :: radius = zero

!  timings (see above)

       TYPE ( TRU_time_type ) :: time

!  inform parameters for TRS

       TYPE ( TRS_inform_type ) :: TRS_inform

!  inform parameters for DPS

       TYPE ( DPS_inform_type ) :: DPS_inform

!  inform parameters for GLTR

       TYPE ( GLTR_inform_type ) :: GLTR_inform

!  inform parameters for PSLS

       TYPE ( PSLS_inform_type ) :: PSLS_inform

!  inform parameters for LMS

       TYPE ( LMS_inform_type ) :: LMS_inform
       TYPE ( LMS_inform_type ) :: LMS_inform_prec

!  inform parameters for SEC

       TYPE ( SEC_inform_type ) :: SEC_inform

!  inform parameters for SHA

       TYPE ( SHA_inform_type ) :: SHA_inform
     END TYPE TRU_inform_type

!  - - - - - - - - - -  
!   data derived types
!  - - - - - - - - - -

     TYPE, PUBLIC :: TRU_data_type
       INTEGER :: branch = 1
       INTEGER :: eval_status, out, start_print, stop_print, advanced_start_iter
       INTEGER :: print_level, print_level_gltr, print_level_trs, ref( 1 )
       INTEGER :: h_ne, len_history, ibound, ipoint, icp, lbfgs_mem, max_hist
       INTEGER :: nprec, nskip_lbfgs, nskip_prec, non_monotone_history, it_succ
       INTEGER :: print_gap, max_diffs, latest_diff, total_diffs, lwork_svd
       INTEGER :: gltr_inform_status
       REAL :: time_start, time_record, time_now
       REAL ( KIND = wp ) :: clock_start, clock_record, clock_now
       REAL ( KIND = wp ) :: f_ref, f_trial, f_best, m_best, model, ratio
       REAL ( KIND = wp ) :: old_radius, radius_trial, etat, ometat
       REAL ( KIND = wp ) :: dxtdg, dgtdg, df, stg, hstbs, s_norm, radius_max
       REAL ( KIND = wp ) :: stop_g, s_new_norm, rho_g
       LOGICAL :: printi, printt, printd, printm
       LOGICAL :: print_iteration_header, print_1st_header
       LOGICAL :: set_printi, set_printt, set_printd, set_printm, use_dps
       LOGICAL :: monotone, new_h, got_h, poor_model, f_is_nan, non_trivial_p
       LOGICAL :: reverse_f, reverse_g, reverse_h, reverse_hprod, reverse_prec
       CHARACTER ( LEN = 1 ) :: negcur = ' '
       CHARACTER ( LEN = 1 ) :: bndry = ' '
       CHARACTER ( LEN = 1 ) :: perturb = ' '
       CHARACTER ( LEN = 1 ) :: hard = ' '
       CHARACTER ( LEN = 1 ) :: accept = ' '
       TYPE ( TRS_history_type ), DIMENSION( history_max ) :: history
       INTEGER, ALLOCATABLE, DIMENSION( : ) :: PAST
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: X_best
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: X_current
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: G_current
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: S
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: U
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: V
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: VECTOR
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: RHO
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: ALPHA
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: D_hist
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: F_hist
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: VAL_est
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: DX
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: DG
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : , : ) :: BANDH
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : , : ) :: DX_past
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : , : ) :: DG_past

       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : , : ) :: DX_svd
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : , : ) :: U_svd
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : , : ) :: VT_svd
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: S_svd
       REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: WORK_svd

       TYPE ( SMT_type ) :: P

!  copy of controls

       TYPE ( TRU_control_type ) :: control

!  data for TRS

       TYPE ( TRS_data_type ) :: TRS_data

!  data for DPS

       TYPE ( DPS_data_type ) :: DPS_data

!  data for GLTR

       TYPE ( GLTR_data_type ) :: GLTR_data

!  data for PSLS

       TYPE ( PSLS_data_type ) :: PSLS_data

!  data for LMS

       TYPE ( LMS_data_type ) :: LMS_data
       TYPE ( LMS_data_type ) :: LMS_data_prec

!  data for SHA

       TYPE ( SHA_data_type ) :: SHA_data
     END TYPE TRU_data_type

     TYPE, PUBLIC :: TRU_full_data_type
       LOGICAL :: f_indexing
       TYPE ( TRU_data_type ) :: tru_data
       TYPE ( TRU_control_type ) :: tru_control
       TYPE ( TRU_inform_type ) :: tru_inform
       TYPE ( NLPT_problem_type ) :: nlp
       TYPE ( NLPT_userdata_type ) :: userdata
     END TYPE TRU_full_data_type

   CONTAINS

!-*-*-  G A L A H A D -  T R U _ I N I T I A L I Z E  S U B R O U T I N E  -*-

     SUBROUTINE TRU_initialize( data, control, inform )

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!   Provide default values for TRU controls

!   Arguments:

!   data     private internal data
!   control  a structure containing control information. See preamble
!   inform   a structure containing output information. See preamble

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( TRU_data_type ), INTENT( INOUT ) :: data
     TYPE ( TRU_control_type ), INTENT( OUT ) :: control
     TYPE ( TRU_inform_type ), INTENT( OUT ) :: inform

!-----------------------------------------------
!   L o c a l   V a r i a b l e s
!-----------------------------------------------

     inform%status = GALAHAD_ok

!  initalize TRS components

     CALL TRS_initialize( data%TRS_data, control%TRS_control,                  &
                          inform%TRS_inform )
     control%TRS_control%prefix = '" - TRS:"                     '

!  initalize DPS components

     CALL DPS_initialize( data%DPS_data, control%DPS_control,                  &
                          inform%DPS_inform )
     control%DPS_control%prefix = '" - DPS:"                     '

!  initalize GLTR components

     CALL GLTR_initialize( data%GLTR_data, control%GLTR_control,               &
                           inform%GLTR_inform )
     control%GLTR_control%prefix = '" - GLTR:"                    '

!  initalize PSLS components

     CALL PSLS_initialize( data%PSLS_data, control%PSLS_control,               &
                           inform%PSLS_inform )
     control%PSLS_control%prefix = '" - PSLS:"                    '

!  initalize LMS components

     CALL LMS_initialize( data%LMS_data, control%LMS_control,                  &
                          inform%LMS_inform )
     control%LMS_control%prefix = '" - LMS:"                     '

!  initalize LMS_prec components

     CALL LMS_initialize( data%LMS_data_prec, control%LMS_control_prec,        &
                          inform%LMS_inform_prec )
     control%LMS_control_prec%prefix = '" - LMS_prec:"                '

!  initalize SEC components

     CALL SEC_initialize( control%SEC_control, inform%SEC_inform )
     control%SEC_control%prefix = '" - SEC:"                     '

!  initalize SHA components

     CALL SHA_initialize( data%SHA_data, control%SHA_control,                  &
                          inform%SHA_inform )
     control%SHA_control%prefix = '" - SHA:"                     '

!  initial private data. Set branch for initial entry

     data%branch = 1

     RETURN

!  End of subroutine TRU_initialize

     END SUBROUTINE TRU_initialize

!- G A L A H A D -  T R U _ F U L L _ I N I T I A L I Z E  S U B R O U T I N E -

     SUBROUTINE TRU_full_initialize( data, control, inform )

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!   Provide default values for TRU controls

!   Arguments:

!   data     private internal data
!   control  a structure containing control information. See preamble
!   inform   a structure containing output information. See preamble

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     TYPE ( TRU_control_type ), INTENT( OUT ) :: control
     TYPE ( TRU_inform_type ), INTENT( OUT ) :: inform

     CALL TRU_initialize( data%tru_data, data%tru_control, data%tru_inform )
     control = data%tru_control
     inform = data%tru_inform

     RETURN

!  End of subroutine TRU_full_initialize

     END SUBROUTINE TRU_full_initialize

!-*-*-*-*-   T R U _ R E A D _ S P E C F I L E  S U B R O U T I N E  -*-*-*-*-

     SUBROUTINE TRU_read_specfile( control, device, alt_specname )

!  Reads the content of a specification file, and performs the assignment of
!  values associated with given keywords to the corresponding control parameters

!  The default values as given by TRU_initialize could (roughly)
!  have been set as:

! BEGIN TRU SPECIFICATIONS (DEFAULT)
!  error-printout-device                           6
!  printout-device                                 6
!  alive-device                                    40
!  print-level                                     0
!  maximum-number-of-iterations                    100
!  start-print                                     -1
!  stop-print                                      -1
!  iterations-between-printing                     1
!  advanced-start                                  5
!  history-length-for-non-monotone-descent         0
!  model-used                                      2
!  norm-used                                       1
!  semi-bandwidth-for-band-norm                    5
!  number-of-lbfgs-vectors                         5
!  number-of-lin-more-vectors                      5
!  max-number-of-secant-vectors                    100
!  mi28-l-fill-size                                10
!  mi28-r-entry-size                               10
!  absolute-gradient-accuracy-required             1.0D-5
!  relative-gradient-reduction-required            1.0D-5
!  minimum-step-allowed                            2.0D-16
!  initial-trust-region-radius                     1.0D+0
!  maximum-trust-region-radius                     1.0D+19
!  successful-iteration-tolerance                  0.01
!  very-successful-iteration-tolerance             0.9
!  too-successful-iteration-tolerance              2.0
!  trust-region-increase-factor                    2.0
!  trust-region-decrease-factor                    0.5
!  trust-region-maximum-decrease-factor            0.0625
!  minimum-objective-before-unbounded              -1.0D+32
!  maximum-cpu-time-limit                          -1.0
!  maximum-clock-time-limit                        -1.0
!  hessian-available                               yes
!  sub-problem-direct                              no
!  retrospective-trust-region                      no
!  renormalize-radius                              no
!  space-critical                                  no
!  deallocate-error-fatal                          no
!  alive-filename                                  ALIVE.d
!  output-line-prefix                              ""
! END TRU SPECIFICATIONS

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( TRU_control_type ), INTENT( INOUT ) :: control
     INTEGER, INTENT( IN ) :: device
     CHARACTER( LEN = * ), OPTIONAL :: alt_specname

!  Programming: Nick Gould and Ph. Toint, January 2002.

!-----------------------------------------------
!   L o c a l   V a r i a b l e s
!-----------------------------------------------

     INTEGER, PARAMETER :: error = 1
     INTEGER, PARAMETER :: out = error + 1
     INTEGER, PARAMETER :: print_level = out + 1
     INTEGER, PARAMETER :: start_print = print_level + 1
     INTEGER, PARAMETER :: stop_print = start_print + 1
     INTEGER, PARAMETER :: print_gap = stop_print + 1
     INTEGER, PARAMETER :: maxit = print_gap + 1
     INTEGER, PARAMETER :: alive_unit = maxit + 1
     INTEGER, PARAMETER :: non_monotone = alive_unit + 1
     INTEGER, PARAMETER :: model = non_monotone + 1
     INTEGER, PARAMETER :: norm = model + 1
     INTEGER, PARAMETER :: semi_bandwidth = norm + 1
     INTEGER, PARAMETER :: lbfgs_vectors = semi_bandwidth + 1
     INTEGER, PARAMETER :: icfs_vectors = lbfgs_vectors + 1
     INTEGER, PARAMETER :: max_dxg = icfs_vectors + 1
     INTEGER, PARAMETER :: mi28_lsize = max_dxg + 1
     INTEGER, PARAMETER :: mi28_rsize = mi28_lsize + 1
     INTEGER, PARAMETER :: advanced_start = mi28_rsize + 1
     INTEGER, PARAMETER :: stop_g_absolute = advanced_start + 1
     INTEGER, PARAMETER :: stop_g_relative = stop_g_absolute + 1
     INTEGER, PARAMETER :: stop_s = stop_g_relative + 1
     INTEGER, PARAMETER :: initial_radius = stop_s + 1
     INTEGER, PARAMETER :: maximum_radius = initial_radius + 1
     INTEGER, PARAMETER :: eta_successful = maximum_radius + 1
     INTEGER, PARAMETER :: eta_very_successful = eta_successful + 1
     INTEGER, PARAMETER :: eta_too_successful = eta_very_successful + 1
     INTEGER, PARAMETER :: radius_increase = eta_too_successful + 1
     INTEGER, PARAMETER :: radius_reduce = radius_increase + 1
     INTEGER, PARAMETER :: radius_reduce_max = radius_reduce + 1
     INTEGER, PARAMETER :: obj_unbounded = radius_reduce_max + 1
     INTEGER, PARAMETER :: cpu_time_limit = obj_unbounded + 1
     INTEGER, PARAMETER :: clock_time_limit = cpu_time_limit + 1
     INTEGER, PARAMETER :: hessian_available = clock_time_limit + 1
     INTEGER, PARAMETER :: subproblem_direct = hessian_available + 1
     INTEGER, PARAMETER :: retrospective_trust_region = subproblem_direct + 1
     INTEGER, PARAMETER :: renormalize_radius = retrospective_trust_region + 1
     INTEGER, PARAMETER :: space_critical = renormalize_radius + 1
     INTEGER, PARAMETER :: deallocate_error_fatal = space_critical + 1
     INTEGER, PARAMETER :: alive_file = deallocate_error_fatal + 1
     INTEGER, PARAMETER :: prefix = alive_file + 1
     INTEGER, PARAMETER :: lspec = prefix
     CHARACTER( LEN = 4 ), PARAMETER :: specname = 'TRU '
     TYPE ( SPECFILE_item_type ), DIMENSION( lspec ) :: spec

!  Define the keywords

     spec%keyword = ''

!  Integer key-words

     spec( error )%keyword = 'error-printout-device'
     spec( out )%keyword = 'printout-device'
     spec( print_level )%keyword = 'print-level'
     spec( start_print )%keyword = 'start-print'
     spec( stop_print )%keyword = 'stop-print'
     spec( print_gap )%keyword = 'iterations-between-printing'
     spec( maxit )%keyword = 'maximum-number-of-iterations'
     spec( alive_unit )%keyword = 'alive-device'
     spec( non_monotone )%keyword = 'history-length-for-non-monotone-descent'
     spec( model )%keyword = 'model-used'
     spec( norm )%keyword = 'norm-used'
     spec( semi_bandwidth )%keyword = 'semi-bandwidth-for-band-norm'
     spec( lbfgs_vectors )%keyword = 'number-of-lbfgs-vectors'
     spec( icfs_vectors )%keyword = 'number-of-lin-more-vectors'
     spec( max_dxg )%keyword = 'max-number-of-secant-vectors'
     spec( mi28_lsize )%keyword = 'mi28-l-fill-size'
     spec( mi28_rsize )%keyword = 'mi28-r-entry-size'
     spec( advanced_start )%keyword = 'advanced-start'

!  Real key-words

     spec( stop_g_absolute )%keyword = 'absolute-gradient-accuracy-required'
     spec( stop_g_relative )%keyword = 'relative-gradient-reduction-required'
     spec( stop_s )%keyword = 'minimum-step-allowed'
     spec( initial_radius )%keyword = 'initial-trust-region-radius'
     spec( maximum_radius )%keyword = 'maximum-trust-region-radius'
     spec( eta_successful )%keyword = 'successful-iteration-tolerance'
     spec( eta_very_successful )%keyword = 'very-successful-iteration-tolerance'
     spec( eta_too_successful )%keyword = 'too-successful-iteration-tolerance'
     spec( radius_increase )%keyword = 'trust-region-increase-factor'
     spec( radius_reduce )%keyword = 'trust-region-decrease-factor'
     spec( radius_reduce_max )%keyword = 'trust-region-maximum-decrease-factor'
     spec( obj_unbounded )%keyword = 'minimum-objective-before-unbounded'
     spec( cpu_time_limit )%keyword = 'maximum-cpu-time-limit'
     spec( clock_time_limit )%keyword = 'maximum-clock-time-limit'

!  Logical key-words

     spec( hessian_available )%keyword = 'hessian-available'
     spec( subproblem_direct )%keyword = 'sub-problem-direct'
     spec( retrospective_trust_region )%keyword = 'retrospective-trust-region'
     spec( renormalize_radius )%keyword = 'renormalize-radius'
     spec( space_critical )%keyword = 'space-critical'
     spec( deallocate_error_fatal )%keyword = 'deallocate-error-fatal'

!  Character key-words

     spec( alive_file )%keyword = 'alive-filename'
     spec( prefix )%keyword = 'output-line-prefix'

!  Read the specfile

     IF ( PRESENT( alt_specname ) ) THEN
       CALL SPECFILE_read( device, alt_specname, spec, lspec, control%error )
     ELSE
       CALL SPECFILE_read( device, specname, spec, lspec, control%error )
     END IF

!  Interpret the result

!  Set integer values

     CALL SPECFILE_assign_value( spec( error ),                                &
                                 control%error,                                &
                                 control%error )
     CALL SPECFILE_assign_value( spec( out ),                                  &
                                 control%out,                                  &
                                 control%error )
     CALL SPECFILE_assign_value( spec( print_level ),                          &
                                 control%print_level,                          &
                                 control%error )
     CALL SPECFILE_assign_value( spec( start_print ),                          &
                                 control%start_print,                          &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_print ),                           &
                                 control%stop_print,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( print_gap ),                            &
                                 control%print_gap,                            &
                                 control%error )
     CALL SPECFILE_assign_value( spec( maxit ),                                &
                                 control%maxit,                                &
                                 control%error )
     CALL SPECFILE_assign_value( spec( alive_unit ),                           &
                                 control%alive_unit,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( non_monotone ),                         &
                                 control%non_monotone,                         &
                                 control%error )
     CALL SPECFILE_assign_value( spec( model ),                                &
                                 control%model,                                &
                                 control%error )
     CALL SPECFILE_assign_value( spec( norm ),                                 &
                                 control%norm,                                 &
                                 control%error )
     CALL SPECFILE_assign_value( spec( semi_bandwidth ),                       &
                                 control%semi_bandwidth,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( lbfgs_vectors ),                        &
                                 control%lbfgs_vectors,                        &
                                 control%error )
     CALL SPECFILE_assign_value( spec( icfs_vectors ),                         &
                                 control%icfs_vectors,                         &
                                 control%error )
     CALL SPECFILE_assign_value( spec( max_dxg ),                              &
                                 control%max_dxg,                              &
                                 control%error )
     CALL SPECFILE_assign_value( spec( mi28_lsize ),                           &
                                 control%mi28_lsize,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( mi28_rsize ),                           &
                                 control%mi28_rsize,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( advanced_start ),                       &
                                 control%advanced_start,                       &
                                 control%error )

!  Set real values

     CALL SPECFILE_assign_value( spec( stop_g_absolute ),                      &
                                 control%stop_g_absolute,                      &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_g_relative ),                      &
                                 control%stop_g_relative,                      &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_s ),                               &
                                 control%stop_s,                               &
                                 control%error )
     CALL SPECFILE_assign_value( spec( initial_radius ),                       &
                                 control%initial_radius,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( maximum_radius ),                       &
                                 control%maximum_radius,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( eta_successful ),                       &
                                 control%eta_successful,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( eta_very_successful ),                  &
                                 control%eta_very_successful,                  &
                                 control%error )
     CALL SPECFILE_assign_value( spec( eta_too_successful ),                   &
                                 control%eta_too_successful,                   &
                                 control%error )
     CALL SPECFILE_assign_value( spec( radius_increase ),                      &
                                 control%radius_increase,                      &
                                 control%error )
     CALL SPECFILE_assign_value( spec( radius_reduce ),                        &
                                 control%radius_reduce,                        &
                                 control%error )
     CALL SPECFILE_assign_value( spec( radius_reduce_max ),                    &
                                 control%radius_reduce_max,                    &
                                 control%error )
     CALL SPECFILE_assign_value( spec( obj_unbounded ),                        &
                                 control%obj_unbounded,                        &
                                 control%error )
     CALL SPECFILE_assign_value( spec( cpu_time_limit ),                       &
                                 control%cpu_time_limit,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( clock_time_limit ),                     &
                                 control%clock_time_limit,                     &
                                 control%error )

!  Set logical values

     CALL SPECFILE_assign_value( spec( hessian_available ),                    &
                                 control%hessian_available,                    &
                                 control%error )
     CALL SPECFILE_assign_value( spec( subproblem_direct ),                    &
                                 control%subproblem_direct,                    &
                                 control%error )
     CALL SPECFILE_assign_value( spec( retrospective_trust_region ),           &
                                 control%retrospective_trust_region,           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( renormalize_radius ),                   &
                                 control%renormalize_radius,                   &
                                 control%error )
     CALL SPECFILE_assign_value( spec( space_critical ),                       &
                                 control%space_critical,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( deallocate_error_fatal ),               &
                                 control%deallocate_error_fatal,               &
                                 control%error )

!  Set character values

     CALL SPECFILE_assign_value( spec( alive_file ),                           &
                                 control%alive_file,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( prefix ),                               &
                                 control%prefix,                               &
                                 control%error )

!  read the controls for the sub-problem solvers and preconditioner

     IF ( PRESENT( alt_specname ) ) THEN
       CALL TRS_read_specfile( control%TRS_control, device,                    &
              alt_specname = TRIM( alt_specname ) // '-TRS' )
       CALL DPS_read_specfile( control%DPS_control, device,                    &
              alt_specname = TRIM( alt_specname ) // '-DPS' )
       CALL GLTR_read_specfile( control%GLTR_control, device,                  &
              alt_specname = TRIM( alt_specname ) // '-GLTR' )
       CALL PSLS_read_specfile( control%PSLS_control, device,                  &
              alt_specname = TRIM( alt_specname ) // '-PSLS'  )
       CALL LMS_read_specfile( control%LMS_control, device,                    &
              alt_specname = TRIM( alt_specname ) // '-LMS' )
       CALL LMS_read_specfile( control%LMS_control_prec, device,               &
              alt_specname = TRIM( alt_specname ) // '-PREC-LMS' )
       CALL SEC_read_specfile( control%SEC_control, device,                    &
              alt_specname = TRIM( alt_specname ) // '-SEC' )
       CALL SHA_read_specfile( control%SHA_control, device,                    &
              alt_specname = TRIM( alt_specname ) // '-SHA' )
     ELSE
       CALL TRS_read_specfile( control%TRS_control, device )
       CALL DPS_read_specfile( control%DPS_control, device )
       CALL GLTR_read_specfile( control%GLTR_control, device )
       CALL PSLS_read_specfile( control%PSLS_control, device )
       CALL LMS_read_specfile( control%LMS_control, device )
       CALL LMS_read_specfile( control%LMS_control_prec, device,               &
                               alt_specname = 'prec-LMS' )
       CALL SEC_read_specfile( control%SEC_control, device )
       CALL SHA_read_specfile( control%SHA_control, device )
     END IF

     RETURN

     END SUBROUTINE TRU_read_specfile

!-*-*-*-  G A L A H A D -  T R U _ s o l v e  S U B R O U T I N E  -*-*-*-

     SUBROUTINE TRU_solve( nlp, control, inform, data, userdata,               &
                           eval_F, eval_G, eval_H, eval_HPROD, eval_PREC )

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!  TRU_solve, a trust-region method for finding a local unconstrained
!    minimizer of a given function

!  *-*-*-*-*-*-*-*-*-*-*-*-  A R G U M E N T S  -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
!
!  For full details see the specification sheet for GALAHAD_TRU.
!
!  ** NB. default real/complex means double precision real/complex in
!  ** GALAHAD_TRU_double
!
! nlp is a scalar variable of type NLPT_problem_type that is used to
!  hold data about the objective function. Relevant components are
!
!  n is a scalar variable of type default integer, that holds the number of
!   variables
!
!  H is scalar variable of type SMT_TYPE that holds the Hessian matrix H. The
!   following components are used here:
!
!   H%type is an allocatable array of rank one and type default character, that
!    is used to indicate the storage scheme used. If the dense storage scheme
!    is used, the first five components of H%type must contain the string DENSE.
!    For the sparse co-ordinate scheme, the first ten components of H%type must
!    contain the string COORDINATE, for the sparse row-wise storage scheme, the
!    first fourteen components of H%type must contain the string SPARSE_BY_ROWS,
!    and for the diagonal storage scheme, the first eight components of H%type
!    must contain the string DIAGONAL.
!
!    For convenience, the procedure SMT_put may be used to allocate sufficient
!    space and insert the required keyword into H%type. For example, if nlp is
!    of derived type packagename_problem_type and involves a Hessian we wish to
!    store using the co-ordinate scheme, we may simply
!
!         CALL SMT_put( nlp%H%type, 'COORDINATE', stat )
!
!    See the documentation for the galahad package SMT for further details on
!    the use of SMT_put.

!   H%ne is a scalar variable of type default integer, that holds the number of
!    entries in the  lower triangular part of H in the sparse co-ordinate
!    storage scheme. It need not be set for any of the other three schemes.
!
!   H%val is a rank-one allocatable array of type default real, that holds
!    the values of the entries of the  lower triangular part of the Hessian
!    matrix H in any of the available storage schemes.
!
!   H%row is a rank-one allocatable array of type default integer, that holds
!    the row indices of the  lower triangular part of H in the sparse
!    co-ordinate storage scheme. It need not be allocated for any of the other
!    three schemes.
!
!   H%col is a rank-one allocatable array variable of type default integer,
!    that holds the column indices of the  lower triangular part of H in either
!    the sparse co-ordinate, or the sparse row-wise storage scheme. It need not
!    be allocated when the dense or diagonal storage schemes are used.
!
!   H%ptr is a rank-one allocatable array of dimension n+1 and type default
!    integer, that holds the starting position of  each row of the  lower
!    triangular part of H, as well as the total number of entries plus one,
!    in the sparse row-wise storage scheme. It need not be allocated when the
!    other schemes are used.
!
!  G is a rank-one allocatable array of dimension n and type default real,
!   that holds the gradient g of the objective function. The j-th component of
!   G, j = 1,  ... ,  n, contains g_j.
!
!  f is a scalar variable of type default real, that holds the value of
!   the objective function.
!
!  X is a rank-one allocatable array of dimension n and type default real, that
!   holds the values x of the optimization variables. The j-th component of
!   X, j = 1, ... , n, contains x_j.
!
!  pname is a scalar variable of type default character and length 10, which
!   contains the ``name'' of the problem for printing. The default ``empty''
!   string is provided.
!
!  VNAMES is a rank-one allocatable array of dimension n and type default
!   character and length 10, whose j-th entry contains the ``name'' of the j-th
!   variable for printing. This is only used  if ``debug''printing
!   control%print_level > 4) is requested, and will be ignored if the array is
!   not allocated.
!
! control is a scalar variable of type TRU_control_type. See TRU_initialize
!  for details
!
! inform is a scalar variable of type TRU_inform_type. On initial entry,
!  inform%status should be set to 1. On exit, the following components will
!  have been set:
!
!  status is a scalar variable of type default integer, that gives
!   the exit status from the package. Possible values are:
!
!     0. The run was succesful
!
!    -1. An allocation error occurred. A message indicating the offending
!        array is written on unit control%error, and the returned allocation
!        status and a string containing the name of the offending array
!        are held in inform%alloc_status and inform%bad_alloc respectively.
!    -2. A deallocation error occurred.  A message indicating the offending
!        array is written on unit control%error and the returned allocation
!        status and a string containing the name of the offending array
!        are held in inform%alloc_status and inform%bad_alloc respectively.
!    -3. The restriction nlp%n > 0 or requirement that prob%H_type contains
!        its relevant string 'DENSE', 'COORDINATE', 'SPARSE_BY_ROWS'
!          or 'DIAGONAL' has been violated.
!    -7. The objective function appears to be unbounded from below
!    -9. The analysis phase of the factorization failed; the return status
!        from the factorization package is given in the component
!        inform%factor_status
!   -10. The factorization failed; the return status from the factorization
!        package is given in the component inform%factor_status.
!   -11. The solution of a set of linear equations using factors from the
!        factorization package failed; the return status from the factorization
!        package is given in the component inform%factor_status.
!   -16. The problem is so ill-conditioned that further progress is impossible.
!   -18. Too many iterations have been performed. This may happen if
!        control%maxit is too small, but may also be symptomatic of
!        a badly scaled problem.
!   -19. The CPU time limit has been reached. This may happen if
!        control%cpu_time_limit is too small, but may also be symptomatic of
!        a badly scaled problem.
!   -40. The user has forced termination of solver by removing the file named
!        control%alive_file from unit unit control%alive_unit.
!
!     2. The user should compute the objective function value f(x) at the point
!        x indicated in nlp%X and then re-enter the subroutine. The required
!        value should be set in nlp%f, and data%eval_status should be set to 0.
!        If the user is unable to evaluate f(x) - for instance, if the function
!        is undefined at x - the user need not set nlp%f, but should then set
!        data%eval_status to a non-zero value.
!     3. The user should compute the gradient of the objective function
!        nabla_x f(x) at the point x indicated in nlp%X  and then re-enter the
!        subroutine. The value of the i-th component of the gradient should be
!        set in nlp%G(i), for i = 1, ..., n and data%eval_status should be set
!        to 0. If the user is unable to evaluate a component of nabla_x f(x)
!        - for instance if a component of the gradient is undefined at x - the
!        user need not set nlp%G, but should then set data%eval_status to a
!        non-zero value.
!     4. The user should compute the Hessian of the objective function
!        nabla_xx f(x) at the point x indicated in nlp%X and then re-enter the
!        subroutine. The value l-th component of the Hessian stored according to
!        the scheme input in the remainder of nlp%H should be set in
!        nlp%H%val(l), for l = 1, ..., nlp%H%ne and data%eval_status should be
!        set to 0. If the user is unable to evaluate a component of
!        nabla_xx f(x) - for instance, if a component of the Hessian is
!        undefined at x - the user need not set nlp%H%val, but should then set
!        data%eval_status to a non-zero value.
!     5. The user should compute the product nabla_xx f(x)v of the Hessian
!        of the objective function nabla_xx f(x) at the point x indicated in
!        nlp%X with the vector v and add the result to the vector u and then
!        re-enter the subroutine. The vectors u and v are given in data%U and
!        data%V respectively, the resulting vector u + nabla_xx f(x)v should be
!        set in data%U and  data%eval_status should be set to 0. If the user is
!        unable to evaluate the product - for instance, if a component of the
!        Hessian is undefined at x - the user need not alter data%U, but
!        should then set data%eval_status to a non-zero value.
!     6. The user should compute the product u = P(x)v of their preconditioner
!        P(x) at the point x indicated in nlp%X with the vector v and then
!        re-enter the subroutine. The vectors v is given in data%V, the
!        resulting vector u = P(x)v should be set in data%U and
!        data%eval_status should be set to 0. If the user is unable to evaluate
!        the product - for instance, if a component of the preconditioner is
!        undefined at x - the user need not set data%U, but should then set
!        data%eval_status to a non-zero value.
!
!  alloc_status is a scalar variable of type default integer, that gives
!   the status of the last attempted array allocation or deallocation.
!   This will be 0 if status = 0.
!
!  bad_alloc is a scalar variable of type default character
!   and length 80, that  gives the name of the last internal array
!   for which there were allocation or deallocation errors.
!   This will be the null string if status = 0.
!
!  iter is a scalar variable of type default integer, that holds the
!   number of iterations performed.
!
!  cg_iter is a scalar variable of type default integer, that gives the
!   total number of conjugate-gradient iterations required.
!
!  factorization_status is a scalar variable of type default integer, that
!   gives the return status from the matrix factorization.
!
!  factorization_integer is a scalar variable of type default integer,
!   that gives the amount of integer storage used for the matrix factorization.
!
!  factorization_real is a scalar variable of type default integer,
!   that gives the amount of real storage used for the matrix factorization.
!
!  f_eval is a scalar variable of type default integer, that gives the
!   total number of objective function evaluations performed.
!
!  g_eval is a scalar variable of type default integer, that gives the
!   total number of objective function gradient evaluations performed.
!
!  h_eval is a scalar variable of type default integer, that gives the
!   total number of objective function Hessian evaluations performed.
!
!  obj is a scalar variable of type default real, that holds the
!   value of the objective function at the best estimate of the solution found.
!
!  norm_g is a scalar variable of type default real, that holds the
!   value of the norm of the objective function gradient at the best estimate
!   of the solution found.
!
!  time is a scalar variable of type TRU_time_type whose components are used to
!   hold elapsed CPU and clock times for the various parts of the calculation.
!   Components are:
!
!    total is a scalar variable of type default real, that gives
!     the total CPU time spent in the package.
!
!    preprocess is a scalar variable of type default real, that gives the
!      CPU time spent reordering the problem to standard form prior to solution.
!
!    analyse is a scalar variable of type default real, that gives
!      the CPU time spent analysing required matrices prior to factorization.
!
!    factorize is a scalar variable of type default real, that gives
!      the CPU time spent factorizing the required matrices.
!
!    solve is a scalar variable of type default real, that gives
!     the CPU time spent using the factors to solve relevant linear equations.
!
!    clock_total is a scalar variable of type default real, that gives
!     the total clock time spent in the package.
!
!    clock_preprocess is a scalar variable of type default real, that gives
!      the clock time spent reordering the problem to standard form prior
!      to solution.
!
!    clock_analyse is a scalar variable of type default real, that gives
!      the clock time spent analysing required matrices prior to factorization.
!
!    clock_factorize is a scalar variable of type default real, that gives
!      the clock time spent factorizing the required matrices.
!
!    clock_solve is a scalar variable of type default real, that gives
!     the clock time spent using the factors to solve relevant linear equations.
!
!  data is a scalar variable of type TRU_data_type used for internal data.
!
!  userdata is a scalar variable of type NLPT_userdata_type which may be used
!   to pass user data to and from the eval_* subroutines (see below)
!   Available coomponents which may be allocated as required are:
!
!    integer is a rank-one allocatable array of type default integer.
!    real is a rank-one allocatable array of type default real
!    complex is a rank-one allocatable array of type default comple.
!    character is a rank-one allocatable array of type default character.
!    logical is a rank-one allocatable array of type default logical.
!    integer_pointer is a rank-one pointer array of type default integer.
!    real_pointer is a rank-one pointer array of type default  real
!    complex_pointer is a rank-one pointer array of type default complex.
!    character_pointer is a rank-one pointer array of type default character.
!    logical_pointer is a rank-one pointer array of type default logical.
!
!  eval_F is an optional subroutine which if present must have the arguments
!   given below (see the interface blocks). The value of the objective
!   function f(x) evaluated at x=X must be returned in f, and the status
!   variable set to 0. If the evaluation is impossible at X, status should
!   be set to a nonzero value. If eval_F is not present, TRU_solve will
!   return to the user with inform%status = 2 each time an evaluation is
!   required.
!
!  eval_G is an optional subroutine which if present must have the arguments
!   given below (see the interface blocks). The components of the gradient
!   nabla_x f(x) of the objective function evaluated at x=X must be returned in
!   G, and the status variable set to 0. If the evaluation is impossible at X,
!   status should be set to a nonzero value. If eval_G is not present,
!   TRU_solve will return to the user with inform%status = 3 each time an
!   evaluation is required.
!
!  eval_H is an optional subroutine which if present must have the arguments
!   given below (see the interface blocks). The nonzeros of the Hessian
!   nabla_xx f(x) of the objective function evaluated at x=X must be returned in
!   H in the same order as presented in nlp%H, and the status variable set to 0.
!   If the evaluation is impossible at X, status should be set to a nonzero
!   value. If eval_H is not present, TRU_solve will return to the user with
!   inform%status = 4 each time an evaluation is required.
!
!  eval_HPROD is an optional subroutine which if present must have the arguments
!   given below (see the interface blocks). The sum u + nabla_xx f(x) v of the
!   product of the Hessian nabla_xx f(x) of the objective function evaluated
!   at x=X with the vector v=V and the vector u=U must be returned in U, and the
!   status variable set to 0. If the evaluation is impossible at X, status
!   should be set to a nonzero value. If eval_HPROD is not present, TRU_solve
!   will return to the user with inform%status = 5 each time an evaluation is
!   required. The Hessian has already been evaluated or used at x=X if got_h
!   is .TRUE.
!
!  eval_PREC is an optional subroutine which if present must have the arguments
!   given below (see the interface blocks). The product u = P(x) v of the
!   user's preconditioner P(x) evaluated at x=X with the vector v=V, the result
!   u must be retured in U, and the status variable set to 0. If the evaluation
!   is impossible at X, status should be set to a nonzero value. If eval_PREC
!   is not present, TRU_solve will return to the user with inform%status = 6
!   each time an evaluation is required.
!
!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( NLPT_problem_type ), INTENT( INOUT ) :: nlp
     TYPE ( TRU_control_type ), INTENT( IN ) :: control
     TYPE ( TRU_inform_type ), INTENT( INOUT ) :: inform
     TYPE ( TRU_data_type ), INTENT( INOUT ) :: data
     TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
     OPTIONAL :: eval_F, eval_G, eval_H, eval_HPROD, eval_PREC

!----------------------------------
!   I n t e r f a c e   B l o c k s
!----------------------------------

     INTERFACE
       SUBROUTINE eval_F( status, X, userdata, f )
       USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
       INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
       INTEGER, INTENT( OUT ) :: status
       REAL ( KIND = wp ), INTENT( OUT ) :: f
       REAL ( KIND = wp ), DIMENSION( : ),INTENT( IN ) :: X
       TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
       END SUBROUTINE eval_F
     END INTERFACE

     INTERFACE
       SUBROUTINE eval_G( status, X, userdata, G )
       USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
       INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
       INTEGER, INTENT( OUT ) :: status
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: X
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: G
       TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
       END SUBROUTINE eval_G
     END INTERFACE

     INTERFACE
       SUBROUTINE eval_H( status, X, userdata, Hval )
       USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
       INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
       INTEGER, INTENT( OUT ) :: status
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: X
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: Hval
       TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
       END SUBROUTINE eval_H
     END INTERFACE

     INTERFACE
       SUBROUTINE eval_HPROD( status, X, userdata, U, V, got_h )
       USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
       INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
       INTEGER, INTENT( OUT ) :: status
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: X
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: U
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: V
       TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
       LOGICAL, OPTIONAL, INTENT( IN ) :: got_h
       END SUBROUTINE eval_HPROD
     END INTERFACE

     INTERFACE
       SUBROUTINE eval_PREC( status, X, userdata, U, V )
       USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
       INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
       INTEGER, INTENT( OUT ) :: status
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: U
       REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: V, X
       TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
       END SUBROUTINE eval_PREC
     END INTERFACE

!-----------------------------------------------
!   L o c a l   V a r i a b l e s
!-----------------------------------------------

     INTEGER :: i, j, ic, ir, l, facts_this_solve, info_svd
     REAL ( KIND = wp ) :: delta, ared, prered, rounding, multiplier
!    REAL ( KIND = wp ) :: radmin
     REAL ( KIND = wp ) :: tau, tau_1, tau_2, tau_min, tau_max
     LOGICAL :: alive
     CHARACTER ( LEN = 6 ) :: char_iter, char_facts, char_sit, char_sit2
     CHARACTER ( LEN = 80 ) :: array_name
!    REAL ( KIND = wp ), DIMENSION( nlp%n ) :: V

!  prefix for all output

     CHARACTER ( LEN = LEN( TRIM( control%prefix ) ) - 2 ) :: prefix
     IF ( LEN( TRIM( control%prefix ) ) > 2 )                                  &
       prefix = control%prefix( 2 : LEN( TRIM( control%prefix ) ) - 1 )

!  branch to different sections of the code depending on input status

     IF ( inform%status < 1 ) THEN
       CALL CPU_time( data%time_start ) ; CALL CLOCK_time( data%clock_start )
       GO TO 990
     END IF
     IF ( inform%status == 1 ) data%branch = 10

     SELECT CASE ( data%branch )
     CASE ( 10 )  ! initialization
       GO TO 10
     CASE ( 20 )  ! initial objective evaluation
       GO TO 20
     CASE ( 30 )  ! initial gradient evaluation
       GO TO 30
     CASE ( 110 )  ! Hessian evaluation
       GO TO 110
     CASE ( 210 )  ! Hessian-vector product
       GO TO 210
     CASE ( 310 )  ! Hessian-vector or preconditioner product
       GO TO 310
     CASE ( 420 )  ! objective evaluation
       GO TO 420
     CASE ( 440 )  ! Hessian-vector product
       GO TO 440
     CASE ( 450 )  ! gradient evaluation
       GO TO 450
     END SELECT

!  ============================================================================
!  0. Initialization
!  ============================================================================

  10 CONTINUE
     CALL CPU_time( data%time_start ) ; CALL CLOCK_time( data%clock_start )

!  ensure that input parameters are within allowed ranges

     IF ( nlp%n <= 0 ) THEN
       inform%status = GALAHAD_error_restrictions
       GO TO 990
     END IF

!  record the problem dimensions

     nlp%H%n = nlp%n ; nlp%H%m = nlp%H%n
     IF ( control%hessian_available ) THEN
       IF ( SMT_get( nlp%H%type ) == 'DIAGONAL' ) THEN
         nlp%H%ne = nlp%n
       ELSE IF ( SMT_get( nlp%H%type ) == 'DENSE' ) THEN
         nlp%H%ne = ( nlp%n * ( nlp%n + 1 ) ) / 2
       ELSE IF ( SMT_get( nlp%H%type ) == 'SPARSE_BY_ROWS' ) THEN
         nlp%H%ne = nlp%H%ptr( nlp%n + 1 ) - 1
!      ELSE
!        nlp%H%ne = nlp%H%ne
       END IF
     ELSE
       nlp%H%ne = 0
     END IF

!  allocate sufficient space for the problem

     array_name = 'tru: data%X_current'
     CALL SPACE_resize_array( nlp%n, data%X_current, inform%status,            &
            inform%alloc_status, array_name = array_name,                      &
            deallocate_error_fatal = control%deallocate_error_fatal,           &
            exact_size = control%space_critical,                               &
            bad_alloc = inform%bad_alloc, out = control%error )
     IF ( inform%status /= 0 ) GO TO 980

     array_name = 'tru: data%G_current'
     CALL SPACE_resize_array( nlp%n, data%G_current, inform%status,            &
            inform%alloc_status, array_name = array_name,                      &
            deallocate_error_fatal = control%deallocate_error_fatal,           &
            exact_size = control%space_critical,                               &
            bad_alloc = inform%bad_alloc, out = control%error )
     IF ( inform%status /= 0 ) GO TO 980

     array_name = 'tru: data%S'
     CALL SPACE_resize_array( nlp%n, data%S, inform%status,                    &
            inform%alloc_status, array_name = array_name,                      &
            deallocate_error_fatal = control%deallocate_error_fatal,           &
            exact_size = control%space_critical,                               &
            bad_alloc = inform%bad_alloc, out = control%error )
     IF ( inform%status /= 0 ) GO TO 980

     array_name = 'tru: data%V'
     CALL SPACE_resize_array( nlp%n, data%V, inform%status,                    &
            inform%alloc_status, array_name = array_name,                      &
            deallocate_error_fatal = control%deallocate_error_fatal,           &
            exact_size = control%space_critical,                               &
            bad_alloc = inform%bad_alloc, out = control%error )
     IF ( inform%status /= 0 ) GO TO 980

     IF ( control%advanced_start > 0 ) THEN
       array_name = 'tru: data%X_best'
       CALL SPACE_resize_array( nlp%n, data%X_best, inform%status,             &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980
     END IF

!  ensure that the data is consistent

     data%control = control
     data%control%TRS_control%initial_multiplier = zero
     data%control%PSLS_control%preconditioner = control%norm
     data%control%PSLS_control%semi_bandwidth = control%semi_bandwidth
     data%control%PSLS_control%icfs_vectors = control%icfs_vectors
     data%control%PSLS_control%mi28_lsize = control%mi28_lsize
     data%control%PSLS_control%mi28_rsize = control%mi28_rsize

     data%non_monotone_history = data%control%non_monotone
     IF ( data%non_monotone_history <= 0 ) data%non_monotone_history = 1
     data%monotone = data%non_monotone_history == 1
     inform%radius = data%control%initial_radius
     data%etat = half * ( data%control%eta_very_successful +                   &
                          data%control%eta_successful )
     data%ometat = one - data%etat
     data%advanced_start_iter = 0
     data%rho_g = two * rho_quad
!    data%lbfgs_mem = MAX( 1, data%control%lbfgs_vectors )
     data%negcur = ' '
     inform%max_entries_factors = 0
     inform%factorization_average = zero
     data%it_succ = 0

!  decide how much reverse communication is required

     data%reverse_f = .NOT. PRESENT( eval_F )
     data%reverse_g = .NOT. PRESENT( eval_G )
     IF ( data%control%model == second_order_model .OR.                        &
          ( data%control%model == sparsity_hessian_model .AND.                 &
            debug_model_4 ) ) THEN
       IF ( data%control%hessian_available ) THEN
         data%reverse_h = .NOT. PRESENT( eval_H )
       ELSE
         data%control%subproblem_direct = .FALSE.
         IF ( data%control%norm >= 0 )                                         &
           data%control%norm = identity_preconditioner
         data%reverse_h = .FALSE.
       END IF
       data%reverse_hprod = .NOT. PRESENT( eval_HPROD )
     ELSE
       IF ( data%control%norm >= 0 ) data%control%norm = identity_preconditioner
       data%control%hessian_available = .FALSE.
       data%reverse_h = .FALSE.
       data%reverse_hprod = .FALSE.
       IF ( data%control%model /= first_order_model .AND.                      &
            data%control%model /= identity_hessian_model .AND.                 &
            data%control%model /= sparsity_hessian_model .AND.                 &
            data%control%model /= l_bfgs_hessian_model .AND.                   &
            data%control%model /= l_sr1_hessian_model .AND.                    &
            data%control%model /= bfgs_hessian_model .AND.                     &
            data%control%model /= sr1_hessian_model )                          &
         data%control%model = identity_hessian_model
       IF ( data%control%model == first_order_model .OR.                       &
            data%control%model == identity_hessian_model )                     &
         data%control%GLTR_control%steihaug_toint = .TRUE.
     END IF
     data%reverse_prec = .NOT. PRESENT( eval_PREC )
     IF ( data%control%norm == diagonalising_preconditioner ) THEN
       IF ( data%control%subproblem_direct ) THEN
         data%use_dps = .TRUE.
       ELSE
         IF ( control%error > 0 ) WRITE(  control%error,                       &
           "( A, ' diagonalizing norm not avaible with iterative',             &
          & ' subproblem solution' )" ) prefix
         inform%status = GALAHAD_not_yet_implemented ; GO TO 990
       END IF
     ELSE
       data%use_dps = .FALSE.
     END IF

     data%nprec = data%control%norm
     data%control%GLTR_control%unitm = data%nprec == identity_preconditioner
     data%control%PSLS_control%preconditioner = data%nprec
     data%control%PSLS_control%semi_bandwidth = data%control%semi_bandwidth
     data%control%PSLS_control%icfs_vectors = data%control%icfs_vectors
     data%control%PSLS_control%new_structure = .TRUE.

!  control the output printing

     IF ( data%control%start_print < 0 ) THEN
       data%start_print = - 1
     ELSE
       data%start_print = data%control%start_print
     END IF

     IF ( data%control%stop_print < 0 ) THEN
       data%stop_print = data%control%maxit + 1
     ELSE
       data%stop_print = data%control%stop_print
     END IF

     IF ( control%print_gap < 2 ) THEN
       data%print_gap = 1
     ELSE
       data%print_gap = control%print_gap
     END IF

     data%out = data%control%out
     data%print_level_gltr = data%control%GLTR_control%print_level
     data%print_level_trs = data%control%TRS_control%print_level
     data%print_1st_header = .TRUE.

!  basic single line of output per iteration

     data%set_printi = data%out > 0 .AND. data%control%print_level >= 1

!  as per printi, but with additional timings for various operations

     data%set_printt = data%out > 0 .AND. data%control%print_level >= 2

!  as per printt with a few more scalars

     data%set_printm = data%out > 0 .AND. data%control%print_level >= 3

!  full debug printing

     data%set_printd = data%out > 0 .AND. data%control%print_level > 10

!  set iteration-specific print controls

     IF ( inform%iter >= data%start_print .AND.                                &
          inform%iter < data%stop_print .AND.                                  &
          MOD( inform%iter + 1 - data%start_print, data%print_gap ) == 0 ) THEN
       data%printi = data%set_printi ; data%printt = data%set_printt
       data%printm = data%set_printm ; data%printd = data%set_printd
       data%print_level = data%control%print_level
     ELSE
       data%printi = .FALSE. ; data%printt = .FALSE.
       data%printm = .FALSE. ; data%printd = .FALSE.
       data%print_level = 0
     END IF

!  create a file which the user may subsequently remove to cause
!  immediate termination of a run

     IF ( control%alive_unit > 0 ) THEN
      INQUIRE( FILE = control%alive_file, EXIST = alive )
      IF ( .NOT. alive ) THEN
         OPEN( control%alive_unit, FILE = control%alive_file,                  &
               FORM = 'FORMATTED', STATUS = 'NEW' )
         REWIND control%alive_unit
         WRITE( control%alive_unit, "( ' GALAHAD rampages onwards ' )" )
         CLOSE( control%alive_unit )
       END IF
     END IF

!  allocate further arrays

     IF ( .NOT. data%monotone ) THEN
       array_name = 'tru: data%F_hist'
       CALL SPACE_resize_array( data%non_monotone_history + 1, data%F_hist,    &
              inform%status,                                                   &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

       array_name = 'tru: data%D_hist'
       CALL SPACE_resize_array( data%non_monotone_history + 1, data%D_hist,    &
              inform%status,                                                   &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980
     END IF

!    IF ( .NOT. data%control%subproblem_direct .OR.                            &
!         data%control%retrospective_trust_region ) THEN
       array_name = 'tru: data%U'
       CALL SPACE_resize_array( nlp%n, data%U, inform%status,                  &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980
!    END IF

!  a limited-memory or secant matrix is to be used

     IF ( data%control%model == l_bfgs_hessian_model .OR.                      &
          data%control%model == l_sr1_hessian_model .OR.                       &
          data%control%model == bfgs_hessian_model .OR.                        &
          data%control%model == sr1_hessian_model .OR.                         &
          data%nprec == l_bfgs_preconditioner ) THEN

       array_name = 'tru: data%DX'
       CALL SPACE_resize_array( nlp%n, data%DX, inform%status,                 &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

       array_name = 'tru: data%DG'
       CALL SPACE_resize_array( nlp%n, data%DG, inform%status,                 &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

!  parameters needed for the limited-memory BFGS preconditioner

       data%ibound = - 1 ; data%ipoint = 0 ; data%nskip_lbfgs  = 0
     END IF
     data%nskip_prec = nskip_prec_max

! evaluate the objective function at the initial point

     IF ( data%reverse_f ) THEN
       data%branch = 20 ; inform%status = 2 ; RETURN
     ELSE
       CALL eval_F( data%eval_status, nlp%X( : nlp%n ), userdata, inform%obj )
     END IF

!  return from reverse communication to obtain the objective value

  20 CONTINUE
     IF ( data%reverse_f ) inform%obj = nlp%f
     inform%f_eval = inform%f_eval + 1
!write(6,"(' X ', 5ES12.4)" ) nlp%X( : nlp%n )

!  test to see if the initial objective value is undefined

!    data%f_is_nan = IEEE_IS_NAN( inform%obj )
     data%f_is_nan = inform%obj /= inform%obj
!write(6,*) ' objective is NaN? ', data%f_is_nan

     IF ( data%f_is_nan ) THEN
       IF ( data%printi ) WRITE( data%out,                                     &
          "( A, ' initial objective value is a NaN' )" ) prefix
       inform%status = GALAHAD_error_evaluation ; GO TO 990
     END IF

!  test to see if the objective appears to be unbounded from below

     IF ( inform%obj < control%obj_unbounded ) THEN
       IF ( data%printi ) WRITE( data%out,                                     &
          "( A, ' objective value', ES12.4, ' is lower than unbounded limit',  &
         &   ES12.4 )" ) prefix, inform%obj, control%obj_unbounded
       inform%status = GALAHAD_error_unbounded ; GO TO 990
     END IF

     data%f_ref = inform%obj
     IF ( .NOT. data%monotone ) THEN
        data%F_hist = data%f_ref ; data%D_hist = zero ; data%max_hist = 1
     END IF

!  evaluate the gradient of the objective function

     IF ( data%reverse_g ) THEN
       data%branch = 30 ; inform%status = 3 ; RETURN
     ELSE
       CALL eval_G( data%eval_status, nlp%X( : nlp%n ), userdata,              &
                    nlp%G( : nlp%n ) )
     END IF

!  return from reverse communication to obtain the gradient

  30 CONTINUE
     inform%g_eval = inform%g_eval + 1
     inform%norm_g = TWO_NORM( nlp%G( : nlp%n ) )
!    WRITE(6,"( ' g: ', ( 5ES12.4 ) )" ) nlp%G( : nlp%n )

!  reset the initial radius to ||g|| if no sensible value is given

     IF ( data%control%initial_radius <= zero )                                &
       inform%radius = inform%norm_g

!  if a sparsity-based secant approximation of the Hessian is required,
!  compute the evaluation ordering

     IF ( data%control%model == sparsity_hessian_model ) THEN
!      write(6,*) ' number of entries ', nlp%H%ne
!      DO i = 1, nlp%H%ne
!        write(6, "( ' row, col ', 2I7 )" ) nlp%H%row( i ), nlp%H%col( i )
!      END DO
       CALL SHA_analyse( nlp%n, nlp%H%ne, nlp%H%row, nlp%H%col, data%SHA_data, &
                         data%control%SHA_control, inform%SHA_inform )

!  allocate space for the differences

       data%latest_diff = 0
       data%max_diffs = MIN( inform%SHA_inform%differences_needed,             &
                             data%control%max_dxg )
       write(6, "( ' maximum # differences required = ', I0 )" ) data%max_diffs

       array_name = 'tru: data%DX_past'
       CALL SPACE_resize_array( nlp%n, data%max_diffs, data%DX_past,           &
              inform%status, inform%alloc_status, array_name = array_name,     &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

       array_name = 'tru: data%DX_svd'
       CALL SPACE_resize_array( nlp%n, data%max_diffs, data%DX_svd,            &
              inform%status, inform%alloc_status, array_name = array_name,     &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

       array_name = 'tru: data%DG_past'
       CALL SPACE_resize_array( nlp%n, data%max_diffs, data%DG_past,           &
              inform%status, inform%alloc_status, array_name = array_name,     &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

       array_name = 'tru: data%PAST'
       CALL SPACE_resize_array( data%max_diffs, data%PAST, inform%status,      &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

       array_name = 'tru: data%VAL_est'
       CALL SPACE_resize_array( nlp%H%ne, data%VAL_est, inform%status,         &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

       IF ( test_s ) THEN
         array_name = 'tru: data%U_svd'
         CALL SPACE_resize_array( 1, 1, data%U_svd, inform%status,             &
                inform%alloc_status, array_name = array_name,                  &
                deallocate_error_fatal = control%deallocate_error_fatal,       &
                exact_size = control%space_critical,                           &
                bad_alloc = inform%bad_alloc, out = control%error )
         IF ( inform%status /= 0 ) GO TO 980

         array_name = 'tru: data%VT_svd'
         CALL SPACE_resize_array( 1, 1, data%VT_svd, inform%status,            &
                inform%alloc_status, array_name = array_name,                  &
                deallocate_error_fatal = control%deallocate_error_fatal,       &
                exact_size = control%space_critical,                           &
                bad_alloc = inform%bad_alloc, out = control%error )
         IF ( inform%status /= 0 ) GO TO 980

         array_name = 'tru: data%S_svd'
         i = MIN( nlp%n, data%max_diffs )
         CALL SPACE_resize_array( i, data%S_svd, inform%status,                &
                inform%alloc_status, array_name = array_name,                  &
                deallocate_error_fatal = control%deallocate_error_fatal,       &
                exact_size = control%space_critical,                           &
                bad_alloc = inform%bad_alloc, out = control%error )
         IF ( inform%status /= 0 ) GO TO 980

         array_name = 'tru: data%WORK_svd'
         CALL SPACE_resize_array( 1, data%WORK_svd, inform%status,             &
                inform%alloc_status, array_name = array_name,                  &
                deallocate_error_fatal = control%deallocate_error_fatal,       &
                exact_size = control%space_critical,                           &
                bad_alloc = inform%bad_alloc, out = control%error )
         IF ( inform%status /= 0 ) GO TO 980

         CALL GESVD( 'N', 'N', nlp%n, data%max_diffs, data%DX_svd,             &
                      nlp%n, data%S_svd, data%U_svd, 1, data%VT_svd, 1,        &
                      data%WORK_svd, - 1, info_svd )
         data%lwork_svd = INT( data%WORK_svd( 1 ) )

         array_name = 'tru: data%WORK_svd'
         CALL SPACE_resize_array( data%lwork_svd, data%WORK_svd,               &
                inform%status, inform%alloc_status, array_name = array_name,   &
                deallocate_error_fatal = control%deallocate_error_fatal,       &
                exact_size = control%space_critical,                           &
                bad_alloc = inform%bad_alloc, out = control%error )
         IF ( inform%status /= 0 ) GO TO 980
       END IF
     END IF

!  if a limited memory-based secant approximation of the Hessian is required,
!  set up the storage required

     IF ( data%control%model == l_bfgs_hessian_model .OR.                      &
          data%control%model == l_sr1_hessian_model ) THEN
       IF ( data%control%model == l_bfgs_hessian_model ) THEN
         data%control%LMS_control%method = 1
       ELSE
         data%control%LMS_control%method = 2
       END IF
       CALL LMS_setup( nlp%n, data%LMS_data, data%control%LMS_control,         &
                       inform%LMS_inform )

!  if a secant Hessian approximation is required, initialize the matrix

    ELSE IF ( data%control%model == bfgs_hessian_model .OR.                    &
              data%control%model == sr1_hessian_model ) THEN
       nlp%H%ne = ( nlp%n * ( nlp%n + 1 ) ) / 2
       CALL SPACE_resize_array( nlp%H%ne, nlp%H%val, inform%status,            &
              inform%alloc_status, array_name = array_name,                    &
              deallocate_error_fatal = control%deallocate_error_fatal,         &
              exact_size = control%space_critical,                             &
              bad_alloc = inform%bad_alloc, out = control%error )
       IF ( inform%status /= 0 ) GO TO 980

       CALL SMT_put( nlp%H%type, 'DENSE', inform%alloc_status )
       CALL SEC_initial_approximation( nlp%n, nlp%H%val,                       &
                                       data%control%sec_control,               &
                                       inform%sec_inform )
     END IF

!  if a limited memory-based secant approximation of the inverse of the
!  Hessian is required for preconditioning, set up the storage required

     IF ( data%nprec == l_bfgs_preconditioner ) THEN
       data%control%LMS_control_prec%method = 3
       CALL LMS_setup( nlp%n, data%LMS_data_prec,                              &
                       data%control%LMS_control_prec,                          &
                       inform%LMS_inform_prec )
     END IF

!  compute the stopping tolerance

     data%stop_g = MAX( control%stop_g_absolute,                               &
                        control%stop_g_relative * inform%norm_g )

!    data%new_h = data%control%hessian_available
     data%new_h = .TRUE.

     IF ( data%printi ) WRITE( data%out, "( A, '  Problem: ', A,               &
    &   ' (n = ', I0, '): TRU stopping tolerance =', ES11.4, / )" )            &
       prefix, TRIM( nlp%pname ), nlp%n, data%stop_g

!  ============================================================================
!  Start of main iteration
!  ============================================================================

 100 CONTINUE

!  control printing

       IF ( inform%iter >= data%start_print .AND.                              &
            inform%iter < data%stop_print .AND.                                &
            MOD( inform%iter + 1 - data%start_print, data%print_gap ) == 0 )   &
           THEN
         data%printi = data%set_printi ; data%printt = data%set_printt
         data%printm = data%set_printm ; data%printd = data%set_printd
         data%print_level = data%control%print_level
         data%control%GLTR_control%print_level = data%print_level_gltr
         data%control%TRS_control%print_level = data%print_level_trs
       ELSE
         data%printi = .FALSE. ; data%printt = .FALSE.
         data%printm = .FALSE. ; data%printd = .FALSE.
         data%print_level = 0
         data%control%GLTR_control%print_level = 0
         data%control%TRS_control%print_level = 0
       END IF
       data%print_iteration_header = data%print_level > 1 .OR.                 &
         ( data%control%GLTR_control%print_level > 0 .AND. .NOT.               &
           data%control%subproblem_direct ) .OR.                               &
         ( data%control%TRS_control%print_level > 0 .AND.                      &
           data%control%subproblem_direct )

!  print one-line summary

       IF ( data%printi ) THEN
          IF ( data%print_iteration_header .OR. data%print_1st_header ) THEN
           WRITE( data%out, 2090 ) prefix
           IF ( data%control%subproblem_direct ) THEN
             WRITE( data%out, 2100 ) prefix
           ELSE
             WRITE( data%out, 2110 ) prefix
           END IF
         END IF
         data%print_1st_header = .FALSE.
         char_iter = ADJUSTR( STRING_integer_6( inform%iter ) )
         IF ( inform%iter > 0 ) THEN
           IF ( data%control%subproblem_direct ) THEN
             char_facts =                                                      &
               ADJUSTR( STRING_integer_6( inform%TRS_inform%factorizations ) )
             IF ( data%use_dps ) THEN
               multiplier = inform%DPS_inform%multiplier
             ELSE
               multiplier = inform%TRS_inform%multiplier
             END IF
             WRITE( data%out, 2120 ) prefix, char_iter, data%accept,           &
                data%bndry, data%negcur, data%hard, inform%obj,                &
                inform%norm_g, data%ratio, inform%radius, multiplier,          &
                char_facts, data%clock_now
           ELSE
             char_sit = ADJUSTR( STRING_integer_6( inform%GLTR_inform%iter ) )
             char_sit2 =                                                       &
                ADJUSTR( STRING_integer_6( inform%GLTR_inform%iter_pass2 ) )
             WRITE( data%out, 2130 ) prefix, char_iter, data%accept,           &
                data%bndry, data%negcur, data%perturb, inform%obj,             &
                inform%norm_g, data%ratio, inform%radius, char_sit,            &
                char_sit2, data%clock_now
           END IF
         ELSE
          IF ( data%control%subproblem_direct ) THEN
             WRITE( data%out, 2140 ) prefix,                                   &
                  char_iter, inform%obj, inform%norm_g, inform%radius
           ELSE
             WRITE( data%out, 2150 ) prefix,                                   &
                  char_iter, inform%obj, inform%norm_g, inform%radius
           END IF
         END IF
       END IF

!IF ( nlp%X( nlp%n ) > zero ) THEN
!  write(6,"( '+' )" )
!ELSE IF ( nlp%X( nlp%n ) < zero ) THEN
!  write(6,"( '-' )" )
!ELSE
!  write(6,"( '0' )" )
!END IF

!  ============================================================================
!  1. Test for convergence
!  ============================================================================

!  stop if the gradient is small enough

       IF ( inform%norm_g <= data%stop_g ) THEN
!        IF ( inform%GLTR_inform%it_st /= 0 ) THEN
!           WRITE( data%outln, "( A10, 2ES10.2, 5I6 )" )                       &
!             nlp%pname, inform%GLTR_inform%f_st, inform%GLTR_inform%f_e,      &
!             inform%GLTR_inform%it_st,  inform%GLTR_inform%it_p1,             &
!             inform%GLTR_inform%it_p9, inform%GLTR_inform%it_p99,             &
!             inform%GLTR_inform%it_e
!        ELSE
!           WRITE( data%outln, "( A10, '     -    ', ES10.2, '   -  ', 4I6 )" )&
!             nlp%pname, inform%GLTR_inform%f_e,                               &
!             inform%GLTR_inform%it_p1, inform%GLTR_inform%it_p9,              &
!             inform%GLTR_inform%it_p99, inform%GLTR_inform%it_e
!        END IF
         inform%status = GALAHAD_ok ; GO TO 900
       END IF

!  stop if the gradient is swamped by the Hessian

!write(6,*) nlp%H%val( 1 )
!do i = 1, nlp%H%ne
!write(6,*) nlp%H%val( i )
!end do
       IF ( data%control%hessian_available .AND. inform%iter > 0 ) THEN
         IF ( inform%norm_g <= MIN( one,                                       &
                MAXVAL( ABS( nlp%H%val( : nlp%H%ne ) ) ) * epsmch ) ) THEN
! write(6,*) ' stopping as g is too ill-conditioned to make further progress!'
! write(6,*) inform%norm_g, MAXVAL( ABS( nlp%H%val( : nlp%H%ne ) ) ) * epsmch
           inform%status = GALAHAD_error_ill_conditioned ; GO TO 900
         END IF
       END IF

!  check to see if we are still "alive"

       IF ( data%control%alive_unit > 0 ) THEN
         INQUIRE( FILE = data%control%alive_file, EXIST = alive )
         IF ( .NOT. alive ) THEN
           inform%status = GALAHAD_error_alive
           RETURN
         END IF
       END IF

!  check to see if the iteration limit has been exceeded

       inform%iter = inform%iter + 1
       IF ( inform%iter > data%control%maxit ) THEN
!        IF ( inform%GLTR_inform%it_st /= 0 ) THEN
!           WRITE( outln, "( A10, 2ES10.2, 5I6 )" )                            &
!             nlp%pname, inform%GLTR_inform%f_st, inform%GLTR_inform%f_e,      &
!             inform%GLTR_inform%it_st,  inform%GLTR_inform%it_p1,             &
!             inform%GLTR_inform%it_p9, inform%GLTR_inform%it_p99,             &
!             inform%GLTR_inform%it_e
!        ELSE
!           WRITE( outln, "( A10, '     -    ', ES10.2, '   -  ', 4I6 )" )     &
!             nlp%pname, inform%GLTR_inform%f_e,                               &
!             inform%GLTR_inform%it_p1, inform%GLTR_inform%it_p9,
!             inform%GLTR_inform%it_p99, inform%GLTR_inform%it_e
!        END IF
         inform%status = GALAHAD_error_max_iterations ; GO TO 900
       END IF

!  debug printing for X and G

       IF ( data%out > 0 .AND. data%print_level > 4 ) THEN
         WRITE ( data%out, 2040 ) prefix, TRIM( nlp%pname ), nlp%n
         WRITE ( data%out, 2000 ) prefix, inform%f_eval, prefix, inform%g_eval,&
           prefix, inform%h_eval, prefix, inform%iter, prefix, inform%cg_iter, &
           prefix, inform%obj, prefix, inform%norm_g
         WRITE ( data%out, 2010 ) prefix
!        l = nlp%n
         l = 2
         DO j = 1, 2
            IF ( j == 1 ) THEN
               ir = 1 ; ic = MIN( l, nlp%n )
            ELSE
               IF ( ic < nlp%n - l ) WRITE( data%out, 2050 ) prefix
               ir = MAX( ic + 1, nlp%n - ic + 1 ) ; ic = nlp%n
            END IF
            IF ( ALLOCATED( nlp%vnames ) ) THEN
              DO i = ir, ic
                 WRITE( data%out, 2020 ) prefix, nlp%vnames( i ), nlp%X( i ),  &
                  nlp%G( i )
              END DO
            ELSE
              DO i = ir, ic
                 WRITE( data%out, 2030 ) prefix, i, nlp%X( i ), nlp%G( i )
              END DO
            END IF
         END DO
       END IF

!  recompute the Hessian if it has changed

       data%perturb = ' '
       IF ( data%new_h ) data%nskip_prec = data%nskip_prec + 1
       IF ( data%new_h .AND. data%control%hessian_available ) THEN
         data%got_h = .FALSE.

!  form the Hessian or a preconditioner based on the Hessian

         IF ( data%nskip_prec > nskip_prec_max ) THEN
           IF ( data%reverse_h ) THEN
             data%branch = 110 ; inform%status = 4 ; RETURN
           ELSE
             CALL eval_H( data%eval_status, nlp%X( : nlp%n ),                  &
                          userdata, nlp%H%val( : nlp%H%ne ) )
           END IF
         END IF
       END IF

!  return from reverse communication to obtain the Hessian

 110   CONTINUE
       IF ( data%new_h ) THEN
         IF ( data%control%hessian_available ) THEN
           IF ( data%nskip_prec > nskip_prec_max ) THEN
             inform%h_eval = inform%h_eval + 1  ; data%got_h = .TRUE.

!  debug printing for H

             IF ( data%printd ) THEN
               WRITE( data%out, "( A, ' Hessian ' )" ) prefix
               DO l = 1, nlp%H%ne
                 WRITE( data%out, "( A, 2I7, ES24.16 )" ) prefix,              &
                   nlp%H%row( l ), nlp%H%col( l ), nlp%H%val( l )
               END DO
             END IF
           END IF
         END IF

!  if the Hessian has changed, recompute the preconditioner

         IF ( data%control%subproblem_direct ) THEN
           IF ( .NOT. data%use_dps ) THEN

!  build the preconditioner

             IF ( data%nprec > 0 .AND. data%control%hessian_available ) THEN
               IF ( data%printt ) WRITE( data%out,                             &
                     "( A, ' Computing preconditioner' )" ) prefix
               CALL PSLS_build( nlp%H, data%P, data%PSLS_data,                 &
                                data%control%PSLS_control, inform%PSLS_inform )

!  check for error returns

               data%non_trivial_p = inform%PSLS_inform%status == GALAHAD_ok
               IF ( inform%PSLS_inform%perturbed ) data%perturb = 'p'
             ELSE
               data%non_trivial_p = .FALSE.
             END IF
             data%control%PSLS_control%new_structure = .FALSE.
           END IF
         ELSE
           IF ( data%nskip_prec > nskip_prec_max ) THEN
             IF ( data%nprec > 0 .AND. data%control%hessian_available ) THEN

!  form and factorize the preconditioner

               IF ( data%printt ) WRITE( data%out,                             &
                     "( A, ' Computing preconditioner' )" ) prefix
               CALL PSLS_form_and_factorize( nlp%H, data%PSLS_data,            &
                 data%control%PSLS_control, inform%PSLS_inform )

!  check for error returns

               IF ( inform%PSLS_inform%status /= 0 ) THEN
                 inform%status = inform%PSLS_inform%status ; GO TO 900
               END IF
               IF ( inform%PSLS_inform%perturbed ) data%perturb = 'p'
               data%control%PSLS_control%new_structure = .FALSE.
             END IF
             data%nskip_prec = 0
           END IF
         END IF

!  if a new Hessian approximation is required, compute it

         IF ( inform%iter > 1 ) THEN

!  if a sparsity-based secant approximation of the Hessian is required,
!  record the latest step and gradient difference

           IF ( data%control%model == sparsity_hessian_model ) THEN
             data%latest_diff = data%latest_diff + 1
             IF ( data%latest_diff > data%max_diffs ) data%latest_diff = 1
             data%DX_past( : , data%latest_diff ) = nlp%X - data%X_current
             data%DG_past( : , data%latest_diff ) = nlp%G - data%G_current
!write(6,*) ' latest ', data%latest_diff
!write(6,*) 's', data%DX_past( : , data%latest_diff )

!  record the column positions in DX and DG of the ordered latest differences
!  (most to least recent)

             IF ( data%total_diffs < data%max_diffs ) THEN
               DO i = data%total_diffs, 1, - 1
                 data%PAST( i + 1 ) = data%PAST( i )
               END DO
               data%total_diffs = data%total_diffs + 1
               data%PAST( 1 ) = data%total_diffs
             ELSE
               DO i = data%max_diffs - 1, 1, - 1
                 data%PAST( i + 1 ) = data%PAST( i )
               END DO
               data%PAST( 1 ) = data%latest_diff
             END IF

             IF ( test_s ) THEN
               data%DX_svd( : nlp%n, : data%total_diffs ) =                    &
                 data%DX_past( : nlp%n, : data%total_diffs )

               CALL GESVD( 'N', 'N', nlp%n, data%total_diffs, data%DX_svd,     &
                           nlp%n, data%S_svd, data%U_svd, 1, data%VT_svd, 1,   &
                           data%WORK_svd, data%lwork_svd, info_svd )

!              write(6,"( ' sigma (info=', I0, '):', /, 7( ES9.2 :, ' ' ) )" ) &
!                info_svd, data%S_svd( : data%total_diffs )
             END IF

!write(6,"( ' PAST ', /, 20( I0 :, ' ' ) )" ) &
! ( data%PAST( i ), i = 1, data%total_diffs )

!  compute the new Hessian estimates

             CALL SHA_estimate( nlp%n, nlp%H%ne, nlp%H%row, nlp%H%col,         &
                                data%max_diffs, data%total_diffs, data%PAST,   &
                                nlp%n, data%total_diffs, data%DX_past,         &
                                nlp%n, data%total_diffs, data%DG_past,         &
                                data%VAL_est, data%SHA_data,                   &
                                data%control%SHA_control, inform%SHA_inform )

             IF ( inform%SHA_inform%status == 0 ) THEN
               IF ( .FALSE. ) THEN
                 IF ( test_s ) THEN
                   WRITE( data%out, "( '    row    col     true         est',  &
                  & '       error' )" )
                   DO i = 1, nlp%H%ne
                     WRITE( data%out, "( 2I7, 3ES12.4 )" ) nlp%H%row( i ),     &
                       nlp%H%col( i ), nlp%H%val( i ), data%VAL_est( i ),      &
                       ABS( nlp%H%val( i ) - data%VAL_est( i ) )
                   END DO
                 ELSE
                   WRITE(6,*) ' diff ', MAXVAL( ABS( nlp%H%val( : nlp%H%ne ) - &
                                                data%VAL_est( : nlp%H%ne ) ) / &
                                 MAX( 1.0_wp, ABS( nlp%H%val( : nlp%H%ne ) ) ) )
                 END IF
               END IF
               nlp%H%val( : nlp%H%ne ) = data%VAL_est( : nlp%H%ne )

               IF ( .FALSE. ) THEN
                 WRITE( data%out, "( '    row    col      val    for H' )" )
                 DO i = 1, nlp%H%ne
                   WRITE( data%out, "( 2I7, 3ES12.4 )" ) nlp%H%row( i ),       &
                     nlp%H%col( i ), nlp%H%val( i )
                 END DO
               END IF
             ELSE
               WRITE( data%out, "( ' SHA status = ', I0 )" )                   &
                 inform%SHA_inform%status
             END IF
           END IF

!  if a limited-memory-based secant approximation of the Hessian or its
!  inverse is required, record the latest step and gradient difference

           IF ( data%control%model == l_bfgs_hessian_model .OR.                &
                data%control%model == l_sr1_hessian_model .OR.                 &
                data%nprec == l_bfgs_preconditioner ) THEN
             data%DX = nlp%X - data%X_current
             data%DG = nlp%G - data%G_current
             data%dxtdg = DOT_PRODUCT( data%DX, data%DG )

!  ensure that the limited-memory formula is well defined

             IF ( data%dxtdg > zero ) THEN
               data%dgtdg = DOT_PRODUCT( data%DG, data%DG )
               delta = data%dgtdg / data%dxtdg
!              delta = data%dxtdg / data%dgtdg

!  form the limited-memory approximation to the Hessian ...

               IF ( data%control%model == l_bfgs_hessian_model .OR.            &
                    data%control%model == l_sr1_hessian_model ) THEN
                 CALL LMS_form( data%DX, data%DG, delta,                       &
                                data%LMS_data, data%control%LMS_control,       &
                                inform%LMS_inform )
               END IF

!  ... and/or its inverse

               IF ( data%nprec == l_bfgs_preconditioner ) THEN
                 CALL LMS_form( data%DX, data%DG, delta,                       &
                                data%LMS_data_prec,                            &
                                data%control%LMS_control_prec,                 &
                                inform%LMS_inform_prec )
               END IF

             ELSE
               IF ( data%nprec == l_bfgs_preconditioner ) THEN
                 data%nskip_lbfgs = data%nskip_lbfgs + 1
                 IF ( data%printt ) WRITE( data%out,                           &
                   "( /, A, ' Preconditioner update skipped ' )" ) prefix
               END IF
             END IF

!  if a secant approximation of the Hessian is required, record the
!  latest step and gradient difference

           ELSE IF ( data%control%model == bfgs_hessian_model .OR.             &
                    data%control%model == sr1_hessian_model ) THEN
             data%DX = nlp%X - data%X_current
             data%DG = nlp%G - data%G_current

!  apply the BFGS update

             IF ( data%control%model == bfgs_hessian_model ) THEN
               CALL SEC_bfgs_update( nlp%n, data%DX, data%DG, nlp%H%val,       &
                          data%U, data%control%sec_control, inform%sec_inform )

!  apply the symmetric rank-one update

             ELSE
               CALL SEC_sr1_update( nlp%n, data%DX, data%DG, nlp%H%val,        &
                          data%U, data%control%sec_control, inform%sec_inform )
             END IF
           END IF
         END IF
!write(6,"( ' H_r ', /, ( 5ES12.4 ) )" ) nlp%H%val(:nlp%H%ne)
       END IF

!  ============================================================================
!  2. Update the trust-region radius and other book-keeping
!  ============================================================================

       IF ( inform%iter > 1 ) THEN
         data%old_radius = inform%radius

!  if the iteration has increased the objective, decrease the radius so that
!  had the objective been quadratic the next iteration would be very successful

         IF ( data%ratio < zero ) THEN
           inform%radius =                                                     &
             MIN( data%control%radius_reduce * data%s_norm, inform%radius *    &
                  MAX( data%control%radius_reduce_max,                         &
                       data%ometat * data%stg / ( data%df +                    &
                         data%ometat * data%stg + data%etat * data%model ) ) )

!  if the iteration was very unsuccesful, decrease the radius to chop off the
!  current step

         ELSE IF ( data%ratio < data%control%eta_successful ) THEN
           inform%radius = data%control%radius_reduce * data%s_norm

!          radmin = data%s_norm * MAX( data%control%radius_reduce_max,         &
!                data%ometat * data%stg /                                      &
!             ( data%df + data%ometat * data%stg + data%etat * data%model ) )
!          radmin = data%s_norm
!          DO
!            inform%radius = data%control%radius_reduce * inform%radius
!            IF ( inform%radius < radmin ) EXIT
!          END DO

!  compute the new norm of the step

         ELSE
           IF ( data%control%norm /= identity_preconditioner ) THEN
             IF ( data%control%renormalize_radius ) THEN
               IF ( data%control%subproblem_direct ) THEN
                 data%s_new_norm = data%s_norm
               ELSE
                 data%s_new_norm = PSLS_norm( nlp%H, data%S, data%PSLS_data,   &
                     data%control%PSLS_control, inform%PSLS_inform )
                 IF ( inform%PSLS_inform%status == GALAHAD_norm_unknown ) THEN
                   data%s_new_norm = data%s_norm
                 ELSE IF ( inform%PSLS_inform%status /= 0 ) THEN
                   GO TO 980
                 END IF
               END IF
               IF ( data%printt )                                              &
                 WRITE( data%out, "( A, ' ratio new, old norms = ', ES12.4 )" )&
                   prefix, data%s_new_norm / data%s_norm
             ELSE
               data%s_new_norm = data%s_norm
             END IF

!  if the norm has changed, adjust the radius accordingly

             IF ( data%s_norm /= zero )                                        &
               inform%radius = inform%radius * ( data%s_new_norm / data%s_norm )
             data%s_norm = data%s_new_norm
           END IF

!  a retrospective radius update strategy will be used
!  ---------------------------------------------------

           IF ( data%control%retrospective_trust_region ) THEN

!  compute the new Hessian-step product u = H s

             SELECT CASE( data%control%model )

!  linear model

             CASE ( first_order_model )
               data%U( : nlp%n ) = zero

!  quadratic model with identity Hessian

             CASE ( identity_hessian_model )
               data%U( : nlp%n ) = data%S( : nlp%n )

!  quadratic model with true or sparsity-based Hessian

             CASE ( second_order_model, sparsity_hessian_model )

!  if the Hessian has been calculated, form the product directly

               IF ( data%control%hessian_available ) THEN
                 CALL mop_Ax( one, nlp%H, data%S( : nlp%n ), zero,             &
                              data%U( : nlp%n ), data%out, data%control%error, &
                              0, symmetric = .TRUE. )

!  if the Hessian is unavailable, obtain a matrix-free product

               ELSE
                 data%U( : nlp%n ) = zero
                 data%V( : nlp%n ) = data%S( : nlp%n )
                 IF ( data%reverse_hprod ) THEN
                   data%branch = 210 ; inform%status = 5 ; RETURN
                 ELSE
                   CALL eval_HPROD( data%eval_status, nlp%X( : nlp%n ),        &
                                    userdata, data%U( : nlp%n ),               &
                                    data%S( : nlp%n ), got_h = data%got_h )
                   data%got_h = .TRUE.
                 END IF
               END IF

!  quadratic model with limited-memory Hessian

             CASE ( l_bfgs_hessian_model, l_sr1_hessian_model )
               CALL LMS_apply( data%S( : nlp%n ), data%U( : nlp%n ),           &
                               data%LMS_data, data%control%LMS_control,        &
                               inform%LMS_inform )

!  quadratic model with secant-approximation Hessian

             CASE ( bfgs_hessian_model, sr1_hessian_model )
               CALL mop_Ax( one, nlp%H, data%S( : nlp%n ), zero,               &
                            data%U( : nlp%n ), data%out, data%control%error,   &
                            0, symmetric = .TRUE. )
             END SELECT

!  a traditional radius update strategy will be used
!  -------------------------------------------------

           ELSE

!write(6,*) ' rho_g ', data%rho_g, ABS( data%ratio - one ), rho_quad

!  if the iteration was very (but not too) successful, increase the radius

             IF ( data%ratio >= data%control%eta_very_successful .AND.         &
                  data%ratio <= data%control%eta_too_successful ) THEN
               IF ( ABS( data%ratio - one ) <= rho_quad .AND.                  &
                    data%rho_g <= rho_quad ) THEN
                 inform%radius = data%control%maximum_radius
               ELSE
                 IF ( data%control%radius_increase * data%s_norm               &
                      > inform%radius )                                        &
                   inform%radius = MIN( data%control%maximum_radius,           &
                                    data%control%radius_increase * data%s_norm )
               END IF
             END IF
           END IF
         END IF
       END IF

!  return from reverse communication to obtain the Hessian-vector product

   210 CONTINUE

!  update after a successful step with a retrospective radius update strategy

       IF ( inform%iter > 1 .AND. data%ratio >= data%control%eta_successful    &
            .AND. data%control%retrospective_trust_region ) THEN

!  compute the new model change

         data%stg = DOT_PRODUCT( data%S( : nlp%n ), nlp%G( : nlp%n ) )
         data%model = - data%stg +                                             &
           half * DOT_PRODUCT( data%S( : nlp%n ), data%U( : nlp%n ) )

         rounding =                                                            &
           MAX( one, ABS( inform%obj ) ) * REAL( nlp%n, KIND = wp ) * epsmch
         ared = data%df + rounding
         prered = - data%model - rounding
         IF ( ABS( ared ) < teneps .AND. ABS( inform%obj ) > teneps )          &
           ared = prered
         data%ratio = - ared / prered
!write(6,*) ' ratio backwards ', data%ratio, ared, prered

!  if the iteration has increased the objective, decrease the radius so that
!  had the objective been quadratic the next iteration would be very successful

         IF ( data%ratio < zero ) THEN
           data%poor_model = .FALSE.
           inform%radius =                                                     &
             MIN( data%control%radius_reduce * data%s_norm, inform%radius *    &
                  MAX( data%control%radius_reduce_max,                         &
                       - data%ometat * data%stg / ( - data%df -                &
                       data%ometat * data%stg + data%etat * data%model ) ) )

!  if the iteration was very unsuccesful, decrease the radius to chop off the
!  current step

         ELSE IF ( data%ratio < data%control%eta_successful ) THEN
           data%poor_model = .FALSE.
           inform%radius = data%control%radius_reduce * data%s_norm
         ELSE IF ( data%ratio >= data%control%eta_very_successful .AND.        &
                   data%ratio <= data%control%eta_too_successful ) THEN
           IF ( ABS( data%ratio - one ) <= rho_quad .AND.                      &
                data%rho_g <= rho_quad ) THEN
             inform%radius = data%control%maximum_radius
           ELSE
             IF ( data%control%radius_increase * data%s_norm > inform%radius)  &
                 inform%radius = MIN( data%control%maximum_radius,             &
                                data%control%radius_increase * data%s_norm )
           END IF
         END IF
       END IF

   220 CONTINUE

!  ============================================================================
!  3. Calculate the search direction, s
!  ============================================================================

!  3a. Direct solution
!  -------------------

!write(6,*) ' direct, type ', &
! data%control%subproblem_direct, SMT_get( nlp%H%type )
       IF ( data%control%subproblem_direct ) THEN

!  norm constructed by the DPS package

         IF ( data%use_dps ) THEN

!  refactorize the Hessian if it has changed

           IF ( data%new_h ) THEN
             IF ( inform%iter <= 1 )THEN
               data%control%DPS_control%new_h = 2
             ELSE
               data%control%DPS_control%new_h = 1
             END IF
           ELSE
             data%control%DPS_control%new_h = 0
           END IF

!  Solve the trust-region subproblem
!  .................................

           data%model = zero
           IF ( data%poor_model ) THEN
             CALL DPS_resolve( nlp%n, data%S( : nlp%n ), data%DPS_data,        &
                             data%control%DPS_control, inform%DPS_inform,      &
                             delta = inform%radius )
             facts_this_solve = 0
           ELSE
             CALL DPS_solve( nlp%n, nlp%H, nlp%G( : nlp%n ), data%model,       &
                             data%S( : nlp%n ), data%DPS_data,                 &
                             data%control%DPS_control, inform%DPS_inform,      &
                             delta = inform%radius )
             facts_this_solve = 1
             data%it_succ = data%it_succ + 1
           END IF

!  check for successful convergence

           IF ( inform%DPS_inform%status < 0 .AND.                             &
                inform%DPS_inform%status /= GALAHAD_error_ill_conditioned ) THEN
             IF ( data%printt ) WRITE( data%out, "( /,                         &
            &    A, ' Error return from DPS, status = ', I0 )" ) prefix,       &
               inform%DPS_inform%status
             inform%status = inform%DPS_inform%status ; GO TO 900
           END IF

!  record subproblem solution information

           data%model = inform%DPS_inform%obj
           IF ( inform%DPS_inform%hard_case ) data%hard = 'h'
!          inform%factorization_average = ( inform%factorization_average *     &
!           ( inform%iter - 1 ) + inform%DPS_inform%factorizations )/inform%iter
!          inform%factorization_max =                                          &
!            MAX( inform%factorization_max, inform%DPS_inform%factorizations )
           inform%factorization_average = data%it_succ / inform%iter
           inform%factorization_max =                                          &
             MAX( inform%factorization_max, facts_this_solve )
           inform%max_entries_factors = MAX( inform%max_entries_factors,       &
                inform%DPS_inform%SLS_inform%entries_in_factors )
           IF ( inform%DPS_inform%pole > zero ) THEN
             data%negcur = 'n'
           ELSE
             data%negcur = ' '
           END IF

           data%s_norm = inform%DPS_inform%x_norm
           IF ( ABS( inform%radius - data%s_norm )                             &
                  <= tenm8 * inform%radius ) THEN
             data%bndry = 'b'
           ELSE
             data%bndry = ' '
           END IF

           IF ( inform%DPS_inform%hard_case ) THEN
             data%hard = 'h'
           ELSE
             data%hard = ' '
           END IF

           GO TO 400

!  other norms

         ELSE

!  estimate Lagrange multipler for the next trust-region subproblem

           IF ( inform%iter > 1 ) THEN

!  only the radius for the next problem differs from the current one

             IF ( data%poor_model ) THEN

!  if there is a history of points with smaller norms, record them

               IF ( inform%TRS_inform%len_history > 0 ) THEN
                 data%len_history = inform%TRS_inform%len_history
                 data%history( : data%len_history )                            &
                   = inform%TRS_inform%history( : data%len_history )
               ELSE
                 data%len_history = 0
               END IF

!  set the lower bound and estimate of the next multiplier to the current
!  values, as Newton will converge rapidly from here

               data%control%TRS_control%lower = inform%TRS_inform%multiplier
               data%control%TRS_control%initial_multiplier =                   &
                 data%control%TRS_control%lower
               data%control%TRS_control%use_initial_multiplier = .TRUE.

!  if the hard case was possible, slightly perturb the multiplier

               IF ( inform%TRS_inform%pole > zero )                            &
                 data%control%TRS_control%initial_multiplier =                 &
                   data%control%TRS_control%initial_multiplier                 &
                     + MAX( inform%TRS_inform%pole, one ) * epsmch ** half

!  look through the history to see if a better starting value is available

               DO i = data%len_history, 1, - 1
                 IF ( data%history( i )%x_norm > inform%radius ) THEN
                   data%control%TRS_control%initial_multiplier =               &
                     data%history( i )%lambda
                 ELSE
                   EXIT
                 END IF
               END DO
               data%control%TRS_control%initialize_approx_eigenvector = .FALSE.
!              data%control%TRS_control%initialize_approx_eigenvector = .TRUE.

!  the next problem is likley different - try to guess a good initial
!  value for the next multiplier

             ELSE
               data%control%TRS_control%lower = zero
               data%control%TRS_control%use_initial_multiplier = .TRUE.
               IF ( inform%TRS_inform%multiplier == zero ) THEN
                 data%control%TRS_control%initial_multiplier = zero
               ELSE
                 data%control%TRS_control%initial_multiplier =                 &
                   inform%TRS_inform%multiplier *                              &
                     ( data%old_radius / inform%radius ) +                     &
                   inform%TRS_inform%pole *                                    &
                   ( one - ( data%old_radius / inform%radius ) )
                 IF ( inform%TRS_inform%pole > zero )                          &
                   data%control%TRS_control%initial_multiplier =               &
                     data%control%TRS_control%initial_multiplier               &
                       + MAX( inform%TRS_inform%pole, one ) * epsmch ** half
               END IF
!              data%control%TRS_control%initialize_approx_eigenvector = .TRUE.
             END IF
           END IF

!  refactorize the Hessian if it has changed

           IF ( data%new_h ) THEN
             IF ( data%nskip_prec > nskip_prec_max ) THEN
               IF ( inform%iter <= 1 )THEN
                 data%control%TRS_control%new_h = 2
               ELSE
                 data%control%TRS_control%new_m = 1
                 data%control%TRS_control%new_h = 1
               END IF
               data%nskip_prec = 0
             ELSE
               data%control%TRS_control%new_m = 0
               data%control%TRS_control%new_h = 0
             END IF
           END IF

!  Solve the trust-region subproblem
!  .................................

           data%model = zero
           facts_this_solve = inform%TRS_inform%factorizations

           IF ( data%non_trivial_p ) THEN
             CALL TRS_solve( nlp%n, inform%radius, data%model,                 &
                             nlp%G( : nlp%n ), nlp%H, data%S( : nlp%n ),       &
                             data%TRS_data, data%control%TRS_control,          &
                             inform%TRS_inform, M = data%P )
           ELSE
             CALL TRS_solve( nlp%n, inform%radius, data%model,                 &
                             nlp%G( : nlp%n ), nlp%H, data%S( : nlp%n ),       &
                             data%TRS_data, data%control%TRS_control,          &
                             inform%TRS_inform )
           END IF

!  check for successful convergence

           IF ( inform%TRS_inform%status < 0 .AND.                             &
                inform%TRS_inform%status /= GALAHAD_error_ill_conditioned ) THEN
             IF ( data%printt ) WRITE( data%out, "( /,                         &
            &    A, ' Error return from TRS, status = ', I0 )" ) prefix,       &
               inform%TRS_inform%status
             inform%status = inform%TRS_inform%status ; GO TO 900
           END IF

!  record subproblem solution information

           data%model = inform%TRS_inform%obj
           IF ( inform%TRS_inform%hard_case ) data%hard = 'h'
           facts_this_solve                                                    &
             = inform%TRS_inform%factorizations - facts_this_solve
!          inform%factorization_average = ( inform%factorization_average *     &
!           ( inform%iter - 1 ) + inform%TRS_inform%factorizations )/inform%iter
!          inform%factorization_max =                                          &
!            MAX( inform%factorization_max, inform%TRS_inform%factorizations )
           inform%factorization_average =                                      &
             inform%TRS_inform%factorizations / inform%iter
           inform%factorization_max =                                          &
             MAX( inform%factorization_max, facts_this_solve )
           inform%max_entries_factors = MAX( inform%max_entries_factors,       &
                                         inform%TRS_inform%max_entries_factors )

           IF ( inform%TRS_inform%pole > zero ) THEN
             data%negcur = 'n'
           ELSE
             data%negcur = ' '
           END IF

           data%s_norm = inform%TRS_inform%x_norm
           IF ( ABS( inform%radius - data%s_norm )                             &
                  <= tenm8 * inform%radius ) THEN
             data%bndry = 'b'
           ELSE
             data%bndry = ' '
           END IF

           IF ( inform%TRS_inform%hard_case ) THEN
             data%hard = 'h'
           ELSE
             data%hard = ' '
           END IF

           GO TO 400
         END IF
       END IF

!  3b. Iterative solution
!  ----------------------

       data%control%GLTR_control%stop_relative                                 &
         = MIN( data%control%GLTR_control%stop_relative, inform%norm_g ** 0.1 )

!      data%model = zero
       data%model = inform%obj
       data%control%GLTR_control%f_0 = inform%obj
       data%S( : nlp%n ) = zero
       data%G_current( : nlp%n ) = nlp%G( : nlp%n )
       IF ( data%new_h ) THEN
         inform%GLTR_inform%status = 1
       ELSE
         IF ( data%control%GLTR_control%steihaug_toint ) THEN
           inform%GLTR_inform%status = 1
         ELSE
           inform%GLTR_inform%status = 4
         END IF
       END IF

!  Start of the generalized Lanczos iteration
!  ..........................................

  300  CONTINUE

!  perform a generalized Lanczos iteration

         CALL GLTR_solve( nlp%n, inform%radius, data%model, data%S( : nlp%n ), &
                          data%G_current( : nlp%n ), data%V( : nlp%n ),        &
                          data%GLTR_data, data%control%GLTR_control,           &
                          inform%GLTR_inform )
         data%gltr_inform_status = inform%GLTR_inform%status

         SELECT CASE( inform%GLTR_inform%status )

!  form the preconditioned gradient

         CASE ( 2 )

!  use the factors obtained from PSLS

           IF ( data%nprec > 0 ) THEN
             CALL PSLS_apply( data%V, data%PSLS_data,                          &
                              data%control%PSLS_control, inform%PSLS_inform )

!  compute the precoditioned gradient BFGS * g using Nocedal's LBFGS formula

           ELSE IF ( data%nprec == l_bfgs_preconditioner ) THEN
             CALL LMS_apply( data%V( : nlp%n ), data%U( : nlp%n ),             &
                             data%LMS_data_prec,                               &
                             data%control%LMS_control_prec,                    &
                             inform%LMS_inform_prec )
             data%V( : nlp%n ) = data%U( : nlp%n )
           ELSE IF ( data%nprec == user_preconditioner ) THEN
             IF ( data%reverse_prec ) THEN
               data%branch = 310 ; inform%status = 6 ; RETURN
             ELSE
               CALL eval_PREC( data%eval_status, nlp%X( : nlp%n ), userdata,   &
                               data%U( : nlp%n ), data%V( : nlp%n ) )
               data%V( : nlp%n ) = data%U( : nlp%n )
             END IF
           END IF

!  form the Hessian-vector product v <- u = H v

         CASE ( 3 )
           SELECT CASE( data%control%model )

!  linear model

           CASE ( first_order_model )
             data%V( : nlp%n ) = zero

!  quadratic model with true or sparsity-based Hessian

           CASE ( second_order_model, sparsity_hessian_model )

!  if the Hessian has been calculated, form the product directly

             IF ( data%control%hessian_available ) THEN
               CALL mop_Ax( one, nlp%H, data%V( : nlp%n ), zero,               &
                            data%U( : nlp%n ), data%out, data%control%error,   &
                            0, symmetric = .TRUE. )
               data%V( : nlp%n ) = data%U( : nlp%n )

!  if the Hessian is unavailable, obtain a matrix-free product

             ELSE
               data%U( : nlp%n ) = zero
               IF ( data%reverse_hprod ) THEN
                 data%branch = 310 ; inform%status = 5 ; RETURN
               ELSE
                 CALL eval_HPROD( data%eval_status, nlp%X( : nlp%n ),          &
                                  userdata, data%U( : nlp%n ),                 &
                                  data%V( : nlp%n ), got_h = data%got_h )
                 data%got_h = .TRUE.
               END IF
             END IF

!  quadratic model with identity Hessian

           CASE ( identity_hessian_model )

!  quadratic model with limited-memory Hessian

           CASE ( l_bfgs_hessian_model, l_sr1_hessian_model )
             CALL LMS_apply( data%V( : nlp%n ), data%U( : nlp%n ),             &
                             data%LMS_data, data%control%LMS_control,          &
                             inform%LMS_inform )
             data%V( : nlp%n ) = data%U( : nlp%n )

!  quadratic model with secant-approximation Hessian

           CASE ( bfgs_hessian_model, sr1_hessian_model )
!write(6,"('v=', 3ES12.4)" ) data%V( : nlp%n )
             CALL mop_Ax( one, nlp%H, data%V( : nlp%n ), zero,                 &
                          data%U( : nlp%n ), data%out, data%control%error,     &
                          0, symmetric = .TRUE. )
!write(6,"('u=', 3ES12.4)" ) data%U( : nlp%n )
               data%V( : nlp%n ) = data%U( : nlp%n )
           END SELECT

!  restore the gradient

         CASE ( 5 )
           data%G_current( : nlp%n ) = nlp%G( : nlp%n )

!  successful return

         CASE ( GALAHAD_ok, GALAHAD_warning_on_boundary,                       &
                GALAHAD_error_max_iterations )
           GO TO 390

!  error returns

         CASE DEFAULT
           IF ( data%printt ) WRITE( data%out, "( /,                           &
           &  A, ' Error return from GLTR, status = ', I0 )" ) prefix,         &
             inform%GLTR_inform%status
           inform%status = inform%GLTR_inform%status
           GO TO 900
         END SELECT

!  return from reverse communication to obtain the Hessian-vector product
!  or preconditioned vector

  310    CONTINUE
         IF (  data%control%model == second_order_model ) THEN
           IF ( .NOT. data%control%hessian_available ) THEN
!            IF ( inform%GLTR_inform%status == 3 ) THEN
             IF ( data%gltr_inform_status == 3 ) THEN
               inform%h_eval = inform%h_eval + 1 ; data%got_h = .TRUE.
               data%V( : nlp%n ) = data%U( : nlp%n )
             END IF
           END IF
         END IF
!        IF ( inform%GLTR_inform%status == 2 .AND.                             &
         IF ( data%gltr_inform_status == 2 .AND.                               &
                data%nprec == user_preconditioner .AND. data%reverse_prec ) THEN
           data%V( : nlp%n ) = data%U( : nlp%n )
         END IF
       GO TO 300

!  End of the generalized Lanczos iteration
!  ........................................

  390  CONTINUE
       data%model = data%model - inform%obj
!      WRITE(6,"( ' ratio model / f ', ES12.4 )" ) data%model / tf

!  Record whether there is negative curvature or if the boundary is encountered

       IF ( inform%GLTR_inform%negative_curvature ) THEN
         data%negcur = 'n'
       ELSE
         data%negcur = ' '
       END IF

       data%s_norm = inform%GLTR_inform%mnormx
       IF ( ABS( inform%radius - inform%GLTR_inform%mnormx )                   &
              <= tenm8 * inform%radius ) THEN
         data%bndry = 'b'
       ELSE
         data%bndry = ' '
       END IF

!  Record the total number of Lanczos iterations

       inform%cg_iter = inform%cg_iter +                                       &
         inform%GLTR_inform%iter + inform%GLTR_inform%iter_pass2
       IF ( data%printt ) WRITE( data%out,                                     &
          "( /, A, ' CG iterations required = ', I8 )" )                       &
            prefix, inform%GLTR_inform%iter

!  ============================================================================
!  4. check for acceptance of the new point
!  ============================================================================

 400   CONTINUE

!  If necessary, temporarily store the old gradient

       IF ( data%nprec == l_bfgs_preconditioner .OR.                           &
            data%control%model == sparsity_hessian_model .OR.                  &
            data%control%model == l_bfgs_hessian_model .OR.                    &
            data%control%model == l_sr1_hessian_model .OR.                     &
            data%control%model == bfgs_hessian_model .OR.                      &
            data%control%model == sr1_hessian_model )                          &
         data%G_current = nlp%G

!  see if the correction will make any difference

       IF ( MAXVAL( ABS( data%S( : nlp%n ) ) / MAX( one, nlp%X( : nlp%n ) ) )  &
            <= data%control%stop_s ) THEN
         inform%status = GALAHAD_error_tiny_step ; GO TO 900
       END IF

!  compute the slope and curvature along the step

       data%stg = DOT_PRODUCT( data%S( : nlp%n ), nlp%G( : nlp%n ) )
       data%hstbs = data%model - data%stg
!write(6,*) ' gTs, 1/2stBs ', data%stg, data%hstbs
!  prepare for advanced starting-point calculation if requested

       IF ( inform%iter == 1 .AND. data%control%advanced_start > 0 ) THEN
         IF ( data%hstbs > zero ) THEN
           data%radius_max = - half * data%stg * data%s_norm / data%hstbs
         ELSE
           data%radius_max = data%control%maximum_radius
         END IF
!write(6,*) ' radius_max ', data%radius_max
         inform%radius = data%s_norm
         data%X_best( : nlp%n )  = nlp%X( : nlp%n )
         data%f_best = inform%obj
         data%m_best = data%model
       END IF

!  record the current point

       data%X_current( : nlp%n )  = nlp%X( : nlp%n )

!  form the trial point

 410   CONTINUE
       nlp%X( : nlp%n ) = data%X_current( : nlp%n ) + data%S( : nlp%n )
!write(6,"(' X ', 5ES12.4)" ) data%X_current( : nlp%n )
!write(6,"(' S ', 5ES12.4)" ) data%S( : nlp%n )
!write(6,"(' X ', 5ES12.4)" ) nlp%X( : nlp%n )

!  evaluate the objective function at the trial point

       IF ( data%reverse_f ) THEN
         data%branch = 420 ; inform%status = 2 ; RETURN
       ELSE
         CALL eval_F( data%eval_status, nlp%X( : nlp%n ), userdata,            &
                      data%f_trial )
       END IF

!  return from reverse communication to obtain the objective value

 420   CONTINUE
       IF ( data%reverse_f ) data%f_trial = nlp%f
       inform%f_eval = inform%f_eval + 1

!  check to ensure that the trial objective value is not a NaN

!      data%f_is_nan = IEEE_IS_NAN( data%f_trial )
       data%f_is_nan = data%f_trial /= data%f_trial
!write(6,*) ' objective is NaN? ', data%f_is_nan
       IF ( data%f_is_nan ) THEN
         data%poor_model = .TRUE.
         data%accept = 'n'
         nlp%X( : nlp%n ) = data%X_current( : nlp%n )

!  control printing for the NaN case

         IF ( inform%iter >= data%start_print .AND.                            &
              inform%iter < data%stop_print .AND.                              &
              MOD( inform%iter + 1 - data%start_print, data%print_gap ) == 0 ) &
             THEN
           data%printi = data%set_printi ; data%printt = data%set_printt
           data%printm = data%set_printm ; data%printd = data%set_printd
           data%print_level = data%control%print_level
           data%control%GLTR_control%print_level = data%print_level_gltr
           data%control%TRS_control%print_level = data%print_level_trs
         ELSE
           data%printi = .FALSE. ; data%printt = .FALSE.
           data%printm = .FALSE. ; data%printd = .FALSE.
           data%print_level = 0
           data%control%GLTR_control%print_level = 0
           data%control%TRS_control%print_level = 0
         END IF
         data%print_iteration_header = data%print_level > 1 .OR.               &
           ( data%control%GLTR_control%print_level > 0 .AND. .NOT.             &
             data%control%subproblem_direct ) .OR.                             &
           ( data%control%TRS_control%print_level > 0 .AND.                    &
             data%control%subproblem_direct )

!  print one-line summary

         IF ( data%printi ) THEN
            IF ( data%print_iteration_header .OR. data%print_1st_header ) THEN
             WRITE( data%out, 2090 ) prefix
             IF ( data%control%subproblem_direct ) THEN
               WRITE( data%out, 2100 ) prefix
             ELSE
               WRITE( data%out, 2110 ) prefix
             END IF
           END IF
           data%print_1st_header = .FALSE.
           char_iter = ADJUSTR( STRING_integer_6( inform%iter ) )
           IF ( data%control%subproblem_direct ) THEN
             char_facts =                                                      &
               ADJUSTR( STRING_integer_6( inform%TRS_inform%factorizations ) )
             IF ( data%use_dps ) THEN
               multiplier = inform%DPS_inform%multiplier
             ELSE
               multiplier = inform%TRS_inform%multiplier
             END IF
             WRITE( data%out,  "( A, A6, 1X, 4A1, '    NaN           -    ',   &
            &  '    - Inf ', '    -    ', 2ES8.1, 1X, A6, F8.2 )" )            &
                prefix, char_iter, data%accept, data%bndry, data%negcur,       &
                data%hard, inform%radius, multiplier, char_facts, data%clock_now
           ELSE
             char_sit = ADJUSTR( STRING_integer_6( inform%GLTR_inform%iter ) )
             char_sit2 =                                                       &
                ADJUSTR( STRING_integer_6( inform%GLTR_inform%iter_pass2 ) )
             WRITE( data%out, "( A, A6, 1X, 4A1, '    NaN           -    ',    &
            &  '    - Inf ', '    -    ', ES9.1, 1X, 2A6, F8.2 )" ) prefix,    &
                char_iter, data%accept, data%bndry, data%negcur, data%perturb, &
                inform%radius, char_sit, char_sit2, data%clock_now
           END IF
         END IF

!  check to see if we are still "alive"

         IF ( data%control%alive_unit > 0 ) THEN
           INQUIRE( FILE = data%control%alive_file, EXIST = alive )
           IF ( .NOT. alive ) THEN
             inform%status = GALAHAD_error_alive
             RETURN
           END IF
         END IF

!  check to see if the iteration limit has been exceeded

         inform%iter = inform%iter + 1
         IF ( inform%iter > data%control%maxit ) THEN
           inform%status = GALAHAD_error_max_iterations ; GO TO 900
         END IF

!  reduce the trust region radiius and try again

         inform%radius = data%control%radius_reduce * data%s_norm
         GO TO 220
       END IF

!  test to see if the objective appears to be unbounded from below

       IF ( data%f_trial < control%obj_unbounded ) THEN
         inform%obj = data%f_trial
         IF ( data%printi ) WRITE( data%out,                                   &
          "( A, ' objective value', ES12.4, ' is lower than unbounded limit',  &
         &   ES12.4 )" ) prefix, data%f_trial, control%obj_unbounded
         inform%status = GALAHAD_error_unbounded ; GO TO 990
       END IF

!  Advanced starting point
!  .......................

!  if an advanced starting point/radius is desired, proceed as per
!  Sartenaer (SISC 18(6) 1990:1788-1803)

       IF ( inform%iter == 1 .AND. data%control%advanced_start > 0 ) THEN
         data%advanced_start_iter = data%advanced_start_iter + 1

!  If the predicted radius is larger than its upper bound, exit

         IF ( inform%radius >= data%radius_max ) GO TO 430

!  perform another iteration

         IF ( data%advanced_start_iter <= data%control%advanced_start ) THEN

!  compute the change in objective and the slope

           data%df = inform%obj - data%f_trial

!  record any improvement in the objective value

           IF ( data%f_trial < data%f_best ) THEN
             data%X_best( : nlp%n )  = nlp%X( : nlp%n )
             data%f_best = data%f_trial
             data%m_best = data%model
           END IF

!  compute the ratio of actual to predicted reduction over the current iteration

           ared = data%df + MAX( one, ABS( inform%obj ) ) * teneps
           prered = - data%model + MAX( one, ABS( inform%obj ) ) * teneps
           IF ( ABS( ared ) < teneps .AND. ABS( inform%obj ) > teneps )        &
             ared = prered
           data%ratio = ared / prered
           IF ( data%printm ) WRITE( data%out, "( /, A, ' actual, predicted',  &
          & ' reductions = ', 2ES12.4 )" ) prefix, ared, prered

!  compute radius adjustment factors

           tau_1 = - theta * data%stg / ( data%hstbs - ( one - theta ) *       &
                    ( data%f_trial - inform%obj - data%stg ) )
           tau_2 = theta * data%stg / ( data%hstbs - ( one + theta ) *         &
                    ( data%f_trial - inform%obj - data%stg ) )
           tau_min = MIN( tau_1, tau_2 )
           tau_max = MAX( tau_1, tau_2 )

!  very good agreement - increase step using Sartenaer's formula

           IF ( ABS( data%ratio - one ) <= mu_2 ) THEN
!write(6,*) ' very good agreement '
             IF ( tau_max < one ) THEN
               tau = gamma_3
             ELSE IF ( tau_max > gamma_4 ) THEN
               tau = gamma_4
             ELSE IF ( tau_1 >= one .AND. tau_1 <= gamma_4 .AND.               &
                       tau_2 < one ) THEN
               tau = tau_1
             ELSE IF ( tau_2 >= one .AND. tau_2 <= gamma_4 .AND.               &
                       tau_1 < one ) THEN
               tau = tau_2
             ELSE
               tau = tau_max
             END IF

!  poor agreement  - decrease step using Sartenaer's formula

           ELSE IF ( ABS( data%ratio - one ) > mu_1 ) THEN
!write(6,*) ' poor agreement '
             IF ( tau_min > one ) THEN
               tau = gamma_2
             ELSE IF ( tau_max < gamma_1 ) THEN
               tau = gamma_1
             ELSE IF ( tau_min < gamma_1 .AND. tau_max >= one ) THEN
               tau = gamma_1
             ELSE IF ( tau_1 >= gamma_1 .AND. tau_1 < one .AND.                &
                     ( tau_2 < gamma_1 .OR. tau_2 >= one ) ) THEN
               tau = tau_1
             ELSE IF ( tau_2 >= gamma_1 .AND. tau_2 < one .AND.                &
                     ( tau_1 < gamma_1 .OR. tau_1 >= one ) ) THEN
               tau = tau_2
             ELSE
               tau = tau_max
             END IF

!  acceptable agreement - refine step

           ELSE
!write(6,*) ' acceptable agreement '
             IF ( tau_max < gamma_2 ) THEN
               tau = gamma_2
             ELSE IF ( tau_max > gamma_3 ) THEN
               tau = gamma_3
             ELSE
               tau = tau_max
             END IF
           END IF

!  restrict any increasze so that the radius does not exceed its maximim value

           tau = MIN( tau, data%radius_max / inform%radius )
!write(6,*) ' tau ', tau

!  update the radius and step length

           data%old_radius = inform%radius
           inform%radius = inform%radius * tau
           data%s_norm = data%s_norm * tau

!  update the slope, curvature and model value

           data%stg = tau * data%stg
           data%hstbs = tau * tau * data%hstbs
           data%model = data%stg + data%hstbs

           IF ( data%printi ) THEN
              IF ( data%print_iteration_header .OR. data%print_1st_header ) THEN
               WRITE( data%out, 2090 ) prefix
               IF ( data%control%subproblem_direct ) THEN
                 WRITE( data%out, 2100 ) prefix
               ELSE
                 WRITE( data%out, 2110 ) prefix
               END IF
             END IF
             data%print_1st_header = .FALSE.
             CALL CPU_time( data%time_now ) ; CALL CLOCK_time( data%clock_now )
             data%time_now = data%time_now - data%time_start
             data%clock_now = data%clock_now - data%clock_start
             char_iter = STRING_integer_6( inform%iter +                       &
                                             data%advanced_start_iter )
             IF ( data%control%subproblem_direct ) THEN
               char_facts =                                                    &
                 STRING_integer_6( inform%TRS_inform%factorizations )
               IF ( data%use_dps ) THEN
                 multiplier = inform%DPS_inform%multiplier
               ELSE
                 multiplier = inform%TRS_inform%multiplier
               END IF
               WRITE( data%out, 2120 ) prefix, char_iter, data%accept,         &
                  data%bndry, data%negcur, data%hard, data%f_trial,            &
                  inform%norm_g, data%ratio, data%old_radius,                  &
                  multiplier, char_facts, data%clock_now
                inform%TRS_inform%factorizations = 0
             ELSE
               char_sit = STRING_integer_6( inform%GLTR_inform%iter )
               char_sit2 = STRING_integer_6( inform%GLTR_inform%iter_pass2 )
               WRITE( data%out, 2130 ) prefix, char_iter, data%accept,         &
                  data%bndry, data%negcur, data%perturb, data%f_trial,         &
                  inform%norm_g, data%ratio, data%old_radius, char_sit,        &
                  char_sit2, data%clock_now
                inform%GLTR_inform%iter = 0
                inform%GLTR_inform%iter_pass2 = 0
             END IF
           END IF

!  form the next trial step

           data%S( : nlp%n ) = tau * data%S( : nlp%n )
           GO TO 410
         END IF

!  record the best value found

 430     CONTINUE
         inform%iter = inform%iter + data%advanced_start_iter - 1
         IF ( data%f_best < inform%obj ) THEN
           data%S( : nlp%n ) = data%X_best( : nlp%n ) - nlp%X( : nlp%n )
           nlp%X( : nlp%n )  = data%X_best( : nlp%n )
           data%f_trial = data%f_best
           data%model = data%m_best
         END IF
       END IF

!  compute the change in objective and the slope

       data%df = inform%obj - data%f_trial

!  compute the ratio of actual to predicted reduction over the current iteration

!      rounding = MAX( one, ABS( inform%obj ) ) * teneps
       rounding =                                                              &
         MAX( one, ABS( inform%obj ) ) * REAL( nlp%n, KIND = wp ) * epsmch

       ared = data%df + rounding
       prered = - data%model + rounding
       IF ( ABS( ared ) < teneps .AND. ABS( inform%obj ) > teneps )            &
         ared = prered
       data%ratio = ared / prered
!write(6,*) ' ratio ', data%ratio, ared, prered
       IF ( data%printm ) WRITE( data%out, "( /, A, ' actual, predicted',      &
      &   ' reductions = ', 2ES12.4 )" ) prefix, ared, prered

!  compute the ratio of actual to predicted reduction over the recent history

       IF ( .NOT. data%monotone ) THEN

!  compute the largest f in the history

         data%ref = MAXLOC( data%F_hist( data%non_monotone_history + 2         &
                            - data%max_hist : data%non_monotone_history + 1 ) )
         data%f_ref = data%F_hist( data%ref( 1 ) )

!  use the larger of these two ratios to assess progress

         data%ratio = MAX( data%ratio, ( data%f_trial - data%f_ref ) /         &
           ( SUM( data%D_hist( data%ref( 1 ) + 1 :                             &
             data%non_monotone_history + 1 ) ) + data%model ) )
       END IF

!  if the function and model values agree very closely, examime the
!  corresponding gradients

       IF ( ABS( data%ratio - one ) <= rho_quad ) THEN

!  compute the gradient of the model at the new point; store in U

         SELECT CASE( data%control%model )

!  linear model

         CASE ( first_order_model )
           data%U( : nlp%n ) = nlp%G( : nlp%n )

!  quadratic model with true or sparsity-based Hessian

         CASE ( second_order_model, sparsity_hessian_model )
           data%U( : nlp%n ) = nlp%G( : nlp%n )
           IF ( data%control%hessian_available ) THEN
             CALL mop_Ax( one, nlp%H, data%S( : nlp%n ), one,                  &
                          data%U( : nlp%n ), data%out, data%control%error,     &
                          0, symmetric = .TRUE. )

!  if necessary, return to the user to obtain the model Hessian product with s

           ELSE
             IF ( data%reverse_hprod ) THEN
               data%V( : nlp%n ) = data%S( : nlp%n )
               CALL SWAP( nlp%n, nlp%X( : nlp%n ), 1,                          &
                          data%X_current( : nlp%n ), 1 ) ! evaluate at current x
               data%branch = 440 ; inform%status = 5 ; RETURN
             ELSE
               CALL eval_HPROD( data%eval_status, data%X_current( : nlp%n ),   &
                                userdata, data%U( : nlp%n ), data%S( : nlp%n ),&
                                got_h = data%got_h )
               data%got_h = .TRUE.
             END IF
           END IF

!  quadratic model with identity Hessian

         CASE ( identity_hessian_model )
           data%U( : nlp%n ) = nlp%G( : nlp%n ) + data%S( : nlp%n )

!  quadratic model with limited-memory Hessian

         CASE ( l_bfgs_hessian_model, l_sr1_hessian_model )
           CALL LMS_apply( data%S( : nlp%n ), data%U( : nlp%n ),               &
                           data%LMS_data, data%control%LMS_control,            &
                           inform%LMS_inform )
           data%U( : nlp%n ) = data%U( : nlp%n ) + nlp%G( : nlp%n )

!  quadratic model with secant-approximation Hessian

         CASE ( bfgs_hessian_model, sr1_hessian_model )
           data%U( : nlp%n ) = nlp%G( : nlp%n )
           CALL mop_Ax( one, nlp%H, data%S( : nlp%n ), one,                    &
                        data%U( : nlp%n ), data%out, data%control%error,       &
                        0, symmetric = .TRUE. )
         END SELECT
       END IF

!  the new point is acceptable

 440   CONTINUE
       IF ( data%ratio >= data%control%eta_successful ) THEN
         IF ( ABS( data%ratio - one ) <= rho_quad .AND.                        &
              data%control%model == second_order_model .AND.                   &
             .NOT. data%control%hessian_available .AND.                        &
             data%reverse_hprod ) CALL SWAP( nlp%n, nlp%X( : nlp%n ), 1,       &
                                             data%X_current( : nlp%n ), 1 )
         data%poor_model = .FALSE.
         data%accept = 'a'
         inform%obj = data%f_trial

!  evaluate the gradient of the objective function

         IF ( data%reverse_g ) THEN
            data%branch = 450 ; inform%status = 3 ; RETURN
         ELSE
           CALL eval_G( data%eval_status, nlp%X( : nlp%n ),                    &
                        userdata, nlp%G( : nlp%n ) )
         END IF
       ELSE
         data%poor_model = .TRUE.
         data%accept = 'r'
         nlp%X( : nlp%n ) = data%X_current( : nlp%n )
       END IF

!  return from reverse communication to obtain the gradient

 450   CONTINUE

!  compute rho_g, the relative difference in model and true gradients

       IF ( ABS( data%ratio - one ) <= rho_quad ) THEN
         IF ( MAXVAL( ABS( nlp%G( : nlp%n ) ) ) /= zero ) THEN
           data%rho_g = MAXVAL( ABS( data%U( : nlp%n ) - nlp%G( : nlp%n ) ) )  &
                          / MAXVAL( ABS( nlp%G( : nlp%n )  ) )
         ELSE
           data%rho_g = zero
         END IF
       ELSE
         data%rho_g = - one
       END IF
!write(6,*) ' rho_g', data%rho_g

       IF ( data%ratio >= data%control%eta_successful ) THEN
         inform%g_eval = inform%g_eval + 1
         inform%norm_g = TWO_NORM( nlp%G( : nlp%n ) )
         data%new_h = .TRUE.

!  update the history

         IF ( data%monotone ) THEN
           data%f_ref = inform%obj

!  shift history of function and model values

         ELSE
           DO i = 1, data%non_monotone_history
             data%F_hist( i ) = data%F_hist( i + 1 )
             data%D_hist( i ) = data%D_hist( i + 1 )
           END DO

!  replace the oldest

           data%F_hist( data%non_monotone_history + 1 ) = inform%obj
           data%D_hist( data%non_monotone_history + 1 ) = data%model

!  find how much past history is allowed

           data%max_hist = MIN( data%max_hist + 1, data%non_monotone_history )

!          write( 6, "( ' f, fref ', 2ES12.4 ) " ) inform%obj, data%f_ref
!          write( 6, "( ' fhist ', ( 6ES12.4 ) ) " ) &
!            data%F_hist( data%non_monotone_history + 2 - data%max_hist :      &
!                         data%non_monotone_history + 1 )

         END IF

!  the new point is not acceptable

       ELSE
         data%new_h = .FALSE.
       END IF

!  record the clock time

       CALL CPU_time( data%time_now ) ; CALL CLOCK_time( data%clock_now )
       data%time_now = data%time_now - data%time_start
       data%clock_now = data%clock_now - data%clock_start
       IF ( data%printt ) WRITE( data%out, "( /, A, ' Time so far = ', 0P,     &
      &    F12.2,  ' seconds' )" ) prefix, data%clock_now
       IF ( ( data%control%cpu_time_limit >= zero .AND.                        &
              data%time_now > data%control%cpu_time_limit ) .OR.               &
            ( data%control%clock_time_limit >= zero .AND.                      &
              data%clock_now > data%control%clock_time_limit ) ) THEN
         inform%status = GALAHAD_error_cpu_limit ; GO TO 900
       END IF

     GO TO 100

!  ============================================================================
!  End of the main iteration
!  ============================================================================

 900 CONTINUE

!  print details of solution

     inform%norm_g = TWO_NORM( nlp%G( : nlp%n ) )

     CALL CPU_time( data%time_record ) ; CALL CLOCK_time( data%clock_record )
     inform%time%total = data%time_record - data%time_start
     inform%time%clock_total = data%clock_record - data%clock_start

     IF ( data%printi ) THEN
!      WRITE ( data%out, 2040 ) nlp%pname, nlp%n
!      WRITE ( data%out, 2000 ) inform%f_eval, inform%g_eval, inform%h_eval,   &
!         inform%iter, inform%cg_iter, inform%obj, inform%norm_g
!      WRITE ( data%out, 2010 )
!      IF ( data%print_level > 3 ) THEN
!         l = nlp%n
!      ELSE
!         l = 2
!      END IF
!      DO j = 1, 2
!         IF ( j == 1 ) THEN
!            ir = 1 ; ic = MIN( l, nlp%n )
!         ELSE
!            IF ( ic < nlp%n - l ) WRITE( data%out, 2050 )
!            ir = MAX( ic + 1, nlp%n - ic + 1 ) ; ic = nlp%n
!         END IF
!         DO i = ir, ic
!            WRITE ( data%out, 2020 ) nlp%vnames( i ), nlp%X( i ), nlp%G( i )
!         END DO
!      END DO
       WRITE( data%out, "( /, A, '  Problem: ', A,                             &
      &   ' (n = ', I0, '): TRU stopping tolerance =', ES11.4 )" )             &
         prefix, TRIM( nlp%pname ), nlp%n, data%stop_g
       IF ( .NOT. data%monotone ) WRITE( data%out,                             &
           "( A, '  Non-monotone method used (history = ', I0, ')' )" ) prefix,&
         data%non_monotone_history
       SELECT CASE( data%control%model )
       CASE ( first_order_model )
         WRITE( data%out, "( A, '  First-order model used' )" ) prefix
       CASE ( second_order_model )
         WRITE( data%out, "( A, '  Second-order model used' )" ) prefix
       CASE ( identity_hessian_model )
         WRITE( data%out, "( A, '  Secod-order model with identity',           &
        &  ' Hessian used' )" ) prefix
       CASE ( sparsity_hessian_model )
         WRITE( data%out, "( A, '  Secod-order model with sparse secant',      &
        &  ' Hessian used' )" ) prefix
       CASE ( l_bfgs_hessian_model )
         WRITE( data%out, "( A, '  Secod-order model with ', I0, '-step',      &
        &  ' L-BFGS secant Hessian used' )" )                                  &
          prefix, data%control%LMS_control%memory_length
       CASE ( l_sr1_hessian_model )
         WRITE( data%out, "( A, '  Secod-order model with ', I0, '-step',      &
        &  ' L-SR1 secant Hessian used' )" )                                   &
          prefix, data%control%LMS_control%memory_length
       CASE ( bfgs_hessian_model )
         WRITE( data%out, "( A, '  Secod-order model with BFGS secant Hessian',&
        &  ' used' )" ) prefix
       CASE ( sr1_hessian_model )
         WRITE( data%out, "( A, '  Secod-order model with SR1 secant Hessian', &
        &  ' used' )" ) prefix
       END SELECT
       IF ( data%control%subproblem_direct ) THEN
         IF ( inform%TRS_inform%dense_factorization ) THEN
           WRITE( data%out,                                                    &
           "( A, '  Direct solution (eigen solver SYSV',                       &
          &      ') of the trust-region sub-problem' )" ) prefix
         ELSE
           WRITE( data%out,                                                    &
           "( A, '  Direct solution (solver ', A,                              &
          &      ') of the trust-region sub-problem' )" )                      &
              prefix, TRIM( data%control%TRS_control%definite_linear_solver )
         END IF
         SELECT CASE ( data%nprec )
         CASE ( user_preconditioner )
           WRITE( data%out, "( A, '  User-defined TR-norm used' )" )           &
             prefix
         CASE ( l_bfgs_preconditioner )
           WRITE( data%out, "( A, 2X, I0, '-step L-BFGS TR-norm used' )" )     &
             prefix, data%control%LMS_control_prec%memory_length
         CASE ( identity_preconditioner )
           WRITE( data%out, "( A, '  Two-norm TR used' )" ) prefix
         CASE ( diagonal_preconditioner )
           WRITE( data%out, "( A, '  Diagonal TR-norm used' )" ) prefix
         CASE ( band_preconditioner )
           WRITE( data%out, "( A, '  Band TR-norm (semi-bandwidth ',           &
          &   I0, ') used' )" ) prefix, inform%PSLS_inform%semi_bandwidth_used
         CASE ( reordered_band_preconditioner )
           WRITE( data%out, "( A, ' Reordered band TR-norm (semi-bandwidth ',  &
          &   I0, ') used' )" ) prefix, inform%PSLS_inform%semi_bandwidth_used
         CASE ( schnabel_eskow_preconditioner, gmps_preconditioner,            &
                lin_more_preconditioner, mi28_preconditioner )
           WRITE( data%out, "( A, '  Modified full matrix TR-norm used' )")    &
             prefix
         CASE (  diagonalising_preconditioner )
           IF (  data%control%DPS_control%goldfarb ) THEN
             WRITE(data%out, "( A,                                             &
            &  '  Goldfarb diagonalising TR-norm used')")  prefix
           ELSE
             WRITE(data%out, "( A, '  Modified absolute-value ',               &
            &   'diagonalising TR-norm used')")  prefix
           END IF
         END SELECT
         WRITE( data%out, "( A, '  Number of factorization = ', I0,            &
        &     ', factorization time = ', F0.2, ' seconds'  )" ) prefix,        &
           inform%TRS_inform%factorizations,                                   &
           inform%TRS_inform%time%clock_factorize
         IF ( TRIM( data%control%TRS_control%definite_linear_solver ) ==       &
              'pbtr' ) THEN
           WRITE( data%out, "( A, '  Max entries in factors = ', I0,           &
          & ', semi-bandwidth = ', I0  )" ) prefix, inform%max_entries_factors,&
              inform%TRS_inform%SLS_inform%semi_bandwidth
         ELSE
           WRITE( data%out, "( A, '  Max entries in factors = ', I0 )" )       &
             prefix, inform%max_entries_factors
         END IF
       ELSE
         IF ( data%nprec > 0 )                                                 &
           WRITE( data%out, "( A, '  Hessian semi-bandwidth (original,',       &
          &     ' re-ordered) = ', I0, ', ', I0 )" ) prefix,                   &
             inform%PSLS_inform%semi_bandwidth,                                &
             inform%PSLS_inform%reordered_semi_bandwidth
         SELECT CASE ( data%nprec )
         CASE ( user_preconditioner )
           WRITE( data%out, "( A, '  User-defined TR-norm used' )" )           &
             prefix
         CASE ( l_bfgs_preconditioner )
           WRITE( data%out, "( A, 2X, I0, '-step L-BFGS TR-norm used' )" )     &
             prefix, data%control%LMS_control_prec%memory_length
         CASE ( identity_preconditioner )
           WRITE( data%out, "( A, '  Two-norm TR used' )" ) prefix
         CASE ( diagonal_preconditioner )
           WRITE( data%out, "( A, '  Diagonal TR-norm used' )" ) prefix
         CASE ( band_preconditioner )
           WRITE( data%out, "( A, '  Band TR-norm (semi-bandwidth ',           &
          &   I0, ') used' )" ) prefix, inform%PSLS_inform%semi_bandwidth_used
         CASE ( reordered_band_preconditioner )
           WRITE( data%out, "( A, ' Reordered band TR-norm (semi-bandwidth ',  &
          &   I0, ') used' )" ) prefix, inform%PSLS_inform%semi_bandwidth_used
         CASE ( schnabel_eskow_preconditioner )
           WRITE( data%out, "( A, '  SE (solver ', A, ') full TR-norm used' )")&
             prefix, TRIM( data%control%PSLS_control%definite_linear_solver )
         CASE ( gmps_preconditioner )
          WRITE( data%out, "( A, '  GMPS (solver ', A, ') full TR-norm used')")&
             prefix, TRIM( data%control%PSLS_control%definite_linear_solver )
         CASE ( lin_more_preconditioner )
           WRITE( data%out, "( A, '  Lin-More''(', I0, ') incomplete Cholesky',&
          &  ' factorization TR-norm used ' )" )                               &
            prefix, data%control%icfs_vectors
         CASE ( mi28_preconditioner )
           WRITE( data%out, "( A, '  HSL_MI28(', I0, ',', I0,                  &
          & ') incomplete Cholesky factorization TR-norm used ' )" )           &
            prefix, data%control%mi28_lsize, data%control%mi28_rsize
         END SELECT
         IF ( data%control%renormalize_radius ) WRITE( data%out,               &
            "( A, '  Radius renormalized' )" ) prefix
       END IF
       WRITE ( data%out, "( A, '  Total time = ', 0P, F0.2, ' seconds', / )" ) &
         prefix, inform%time%clock_total
     END IF
     IF ( inform%status /= GALAHAD_OK ) GO TO 990
     RETURN

!  -------------
!  Error returns
!  -------------

 980 CONTINUE
     CALL CPU_time( data%time_record ) ; CALL CLOCK_time( data%clock_record )
     inform%time%total = data%time_record - data%time_start
     inform%time%clock_total = data%clock_record - data%clock_start
     RETURN

 990 CONTINUE
     CALL CPU_time( data%time_record ) ; CALL CLOCK_time( data%clock_record )
     inform%time%total = data%time_record - data%time_start
     inform%time%clock_total = data%clock_record - data%clock_start
     IF ( control%error > 0 ) THEN
       CALL SYMBOLS_status( inform%status, control%error, prefix, 'TRU_solve' )
       WRITE( control%error, "( ' ' )" )
     END IF
     RETURN

!  Non-executable statements

 2000 FORMAT( /, A, ' # function evaluations  = ', I10,                        &
              /, A, ' # gradient evaluations  = ', I10,                        &
              /, A, ' # Hessian evaluations   = ', I10,                        &
              /, A, ' # major  iterations     = ', I10,                        &
              /, A, ' # minor (cg) iterations = ', I10,                        &
             //, A, ' objective value         = ', ES22.14,                    &
              /, A, ' gradient norm           = ', ES12.4 )
 2010 FORMAT( /, A, ' name             X         G ' )
 2020 FORMAT(  A, 1X, A10, 2ES12.4 )
 2030 FORMAT(  A, 1X, I10, 2ES12.4 )
 2040 FORMAT( /, A, ' Problem: ', A, ' n = ', I8 )
 2050 FORMAT( A, ' .          ........... ...........' )
 2090 FORMAT( A, '        (a=accept r=reject b=TR boundary',                   &
                 ' n=-ve curvature h=hard case)' )
 2100 FORMAT( A, '    It           f         grad    ',                        &
             ' ratio   radius multplr # fact    time' )
 2110 FORMAT( A, '    It           f         grad     ',                       &
             ' ratio   radius pass 1 pass 2   time' )
 2120 FORMAT( A, A6, 1X, 4A1, ES12.4, ES10.3, ES9.1, 2ES8.1, 1X, A6, F8.2 )
 2130 FORMAT( A, A6, 1X, 4A1, ES12.4, ES11.4, ES9.1, ES8.1, 1X, 2A6, F8.2 )
 2140 FORMAT( A, A6, 5X, ES12.4, ES10.3, 9X, ES8.1 )
 2150 FORMAT( A, A6, 5X, ES12.4, ES11.4, 9X, ES8.1 )

 !  End of subroutine TRU_solve

     END SUBROUTINE TRU_solve

!-*-*-  G A L A H A D -  T R U _ t e r m i n a t e  S U B R O U T I N E -*-*-

     SUBROUTINE TRU_terminate( data, control, inform )

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!   Deallocate all private storage

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( TRU_data_type ), INTENT( INOUT ) :: data
     TYPE ( TRU_control_type ), INTENT( IN ) :: control
     TYPE ( TRU_inform_type ), INTENT( INOUT ) :: inform

!-----------------------------------------------
!   L o c a l   V a r i a b l e s
!-----------------------------------------------

     LOGICAL :: alive
     CHARACTER ( LEN = 80 ) :: array_name

!  Deallocate all remaining allocated arrays

     array_name = 'tru: data%X_best'
     CALL SPACE_dealloc_array( data%X_best,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%X_current'
     CALL SPACE_dealloc_array( data%X_current,                                 &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%G_current'
     CALL SPACE_dealloc_array( data%G_current,                                 &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%S'
     CALL SPACE_dealloc_array( data%S,                                         &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%U'
     CALL SPACE_dealloc_array( data%U,                                         &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%V'
     CALL SPACE_dealloc_array( data%V,                                         &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%RHO'
     CALL SPACE_dealloc_array( data%RHO,                                       &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%ALPHA'
     CALL SPACE_dealloc_array( data%ALPHA,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%D_hist'
     CALL SPACE_dealloc_array( data%D_hist,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%F_hist'
     CALL SPACE_dealloc_array( data%F_hist,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%DX'
     CALL SPACE_dealloc_array( data%DX,                                        &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%DG'
     CALL SPACE_dealloc_array( data%DG,                                        &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%DX_past'
     CALL SPACE_dealloc_array( data%DX_past,                                   &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%DG_past'
     CALL SPACE_dealloc_array( data%DG_past,                                   &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%PAST'
     CALL SPACE_dealloc_array( data%PAST,                                      &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%VAL_est'
     CALL SPACE_dealloc_array( data%VAL_est,                                   &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%BANDH'
     CALL SPACE_dealloc_array( data%BANDH,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%DX_svd'
     CALL SPACE_dealloc_array( data%DX_svd,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%U_svd'
     CALL SPACE_dealloc_array( data%U_svd,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%VT_svd'
     CALL SPACE_dealloc_array( data%VT_svd,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%S_svd'
     CALL SPACE_dealloc_array( data%S_svd,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%WORK_svd'
     CALL SPACE_dealloc_array( data%WORK_svd,                                  &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%P%row'
     CALL SPACE_dealloc_array( data%P%row,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%P%col'
     CALL SPACE_dealloc_array( data%P%col,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%P%val'
     CALL SPACE_dealloc_array( data%P%val,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

!  Deallocate all arrays allocated within PSLS

     CALL PSLS_terminate( data%PSLS_data, data%control%PSLS_control,           &
                          inform%PSLS_inform )
     inform%status = inform%PSLS_inform%status
     IF ( inform%status /= 0 ) THEN
       inform%alloc_status = inform%PSLS_inform%alloc_status
       inform%bad_alloc = inform%PSLS_inform%bad_alloc
       IF ( control%deallocate_error_fatal ) RETURN
     END IF

!  Deallocate all arrays allocated within SHA

     CALL SHA_terminate( data%SHA_data, data%control%SHA_control,              &
                         inform%SHA_inform )
     inform%status = inform%SHA_inform%status
     IF ( inform%status /= 0 ) THEN
       inform%alloc_status = inform%SHA_inform%alloc_status
       inform%bad_alloc = inform%SHA_inform%bad_alloc
       IF ( control%deallocate_error_fatal ) RETURN
     END IF

!  Deallocate all arrays allocated within LMS

     CALL LMS_terminate( data%LMS_data, data%control%LMS_control,              &
                         inform%LMS_inform )
     inform%status = inform%LMS_inform%status
     IF ( inform%status /= 0 ) THEN
       inform%alloc_status = inform%LMS_inform%alloc_status
       inform%bad_alloc = inform%LMS_inform%bad_alloc
       IF ( control%deallocate_error_fatal ) RETURN
     END IF

!  Deallocate all arrays allocated within GLTR

     CALL GLTR_terminate( data%GLTR_data, data%control%GLTR_control,           &
                          inform%GLTR_inform )
     inform%status = inform%GLTR_inform%status
     IF ( inform%status /= 0 ) THEN
       inform%alloc_status = inform%GLTR_inform%alloc_status
       inform%bad_alloc = inform%GLTR_inform%bad_alloc
       IF ( control%deallocate_error_fatal ) RETURN
     END IF

!  Deallocate all arraysn allocated within TRS

     CALL TRS_terminate( data%TRS_data, data%control%TRS_control,              &
                          inform%TRS_inform )
     inform%status = inform%TRS_inform%status
     IF ( inform%status /= 0 ) THEN
       inform%alloc_status = inform%TRS_inform%alloc_status
       inform%bad_alloc = inform%TRS_inform%bad_alloc
       IF ( control%deallocate_error_fatal ) RETURN
     END IF

!  Close and delete 'alive' file

     IF ( control%alive_unit > 0 ) THEN
       INQUIRE( FILE = control%alive_file, EXIST = alive )
       IF ( alive .AND. control%alive_unit > 0 ) THEN
         OPEN( control%alive_unit, FILE = control%alive_file,                  &
               FORM = 'FORMATTED', STATUS = 'UNKNOWN' )
         REWIND control%alive_unit
         CLOSE( control%alive_unit, STATUS = 'DELETE' )
       END IF
     END IF

     RETURN

!  End of subroutine TRU_terminate

     END SUBROUTINE TRU_terminate

!-  G A L A H A D -  T R U _ f u l l _ t e r m i n a t e  S U B R O U T I N E -

     SUBROUTINE TRU_full_terminate( data, control, inform )

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!   Deallocate all private storage

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     TYPE ( TRU_control_type ), INTENT( IN ) :: control
     TYPE ( TRU_inform_type ), INTENT( INOUT ) :: inform

!-----------------------------------------------
!   L o c a l   V a r i a b l e s
!-----------------------------------------------

     CHARACTER ( LEN = 80 ) :: array_name

!  deallocate workspace

     CALL TRU_terminate( data%tru_data, data%tru_control, data%tru_inform )
     inform = data%tru_inform

!  deallocate any internal problem arrays

     array_name = 'tru: data%nlp%X'
     CALL SPACE_dealloc_array( data%nlp%X,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%nlp%G'
     CALL SPACE_dealloc_array( data%nlp%G,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%nlp%Z'
     CALL SPACE_dealloc_array( data%nlp%Z,                                     &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%nlp%H%row'
     CALL SPACE_dealloc_array( data%nlp%H%row,                                 &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%nlp%H%col'
     CALL SPACE_dealloc_array( data%nlp%H%col,                                 &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%nlp%H%ptr'
     CALL SPACE_dealloc_array( data%nlp%H%ptr,                                 &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%nlp%H%val'
     CALL SPACE_dealloc_array( data%nlp%H%val,                                 &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'tru: data%nlp%H%type'
     CALL SPACE_dealloc_array( data%nlp%H%type,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     RETURN

!  End of subroutine TRU_full_terminate

     END SUBROUTINE TRU_full_terminate

! -----------------------------------------------------------------------------
! =============================================================================
! -----------------------------------------------------------------------------
!              specific interfaces to make calls from C easier
! -----------------------------------------------------------------------------
! =============================================================================
! -----------------------------------------------------------------------------

!-*-*-*-*-  G A L A H A D -  T R U _ i m p o r t _ S U B R O U T I N E -*-*-*-*-

     SUBROUTINE TRU_import( control, data, status, n, H_type, H_ne, H_row,     &
                            H_col, H_ptr )

!  import fixed problem data into internal storage prior to solution. 
!  Arguments are as follows:

!  control is a derived type whose components are described in the leading 
!   comments to TRU_solve
!
!  data is a scalar variable of type TRU_full_data_type used for internal data
!
!  status is a scalar variable of type default intege that indicates the
!   success or otherwise of the import. Possible values are:
!
!    1. The import was succesful, and the package is ready for the solve phase
!
!   -1. An allocation error occurred. A message indicating the offending
!       array is written on unit control.error, and the returned allocation
!       status and a string containing the name of the offending array
!       are held in inform.alloc_status and inform.bad_alloc respectively.
!   -2. A deallocation error occurred.  A message indicating the offending
!       array is written on unit control.error and the returned allocation
!       status and a string containing the name of the offending array
!       are held in inform.alloc_status and inform.bad_alloc respectively.
!   -3. The restriction n > 0 or requirement that H_type contains
!       its relevant string 'DENSE', 'COORDINATE', 'SPARSE_BY_ROWS',
!       'DIAGONAL' or 'ABSENT' has been violated.
!  -79. An optional array required by storage type H_type is missing
!
!  n is a scalar variable of type default integer, that holds the number of
!   variables
!
!  H_type is a character string that specifies the Hessian storage scheme
!   used. It should be one of 'coordinate', 'sparse_by_rows', 'dense',
!   'diagonal' or 'absent', the latter if access to the Hessian is via
!   matrix-vector products; lower or upper case variants are allowed
!
!  H_ne is an optional scalar variable of type default integer, that holds the 
!   number of entries in the  lower triangular part of H in the sparse 
!   co-ordinate storage scheme. It is not required and need not be set for 
!   any of the other three schemes.
!
!  H_row is an optional rank-one array of type default integer, that holds
!   the row indices of the  lower triangular part of H in the sparse
!   co-ordinate storage scheme. It is not required and need not be set for 
!   any of the other three schemes, and in this case can be of length 0
!
!  H_col is an optional rank-one array of type default integer, that holds the 
!   column indices of the  lower triangular part of H in either the sparse 
!   co-ordinate, or the sparse row-wise storage scheme. It is not required and 
!   need not be set when the dense or diagonal storage schemes are used, and 
!   in this case can be of length 0
!
!  H_ptr is an optional rank-one array of dimension n+1 and type default
!   integer, that holds the starting position of  each row of the  lower
!   triangular part of H, as well as the total number of entries plus one,
!   in the sparse row-wise storage scheme. It is not required and need not be
!   set when the other schemes are used, and in this case can be of length 0

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( TRU_control_type ), INTENT( INOUT ) :: control
     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     INTEGER, INTENT( IN ) :: n
     INTEGER, INTENT( OUT ) :: status
     CHARACTER ( LEN = * ), INTENT( IN ) :: H_type
     INTEGER, INTENT( IN ), OPTIONAL :: H_ne
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: H_row
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: H_col
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: H_ptr

!  local variables

     INTEGER :: error
     LOGICAL :: deallocate_error_fatal, space_critical
     CHARACTER ( LEN = 80 ) :: array_name

!  copy control to data

     WRITE( control%out, "( '' )", ADVANCE = 'no') ! prevents ifort bug
     data%tru_control = control

     error = data%tru_control%error
     space_critical = data%tru_control%space_critical
     deallocate_error_fatal = data%tru_control%deallocate_error_fatal

!  allocate space if required

     array_name = 'tru: data%nlp%X'
     CALL SPACE_resize_array( n, data%nlp%X,                                   &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
     IF ( data%tru_inform%status /= 0 ) GO TO 900

     array_name = 'tru: data%nlp%G'
     CALL SPACE_resize_array( n, data%nlp%G,                                   &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
     IF ( data%tru_inform%status /= 0 ) GO TO 900

!  put data into the required components of the nlpt storage type

     data%nlp%n = n

!  set H appropriately in the nlpt storage type

     SELECT CASE ( H_type )
     CASE ( 'coordinate', 'COORDINATE' )
       IF ( .NOT. ( PRESENT( H_ne ) .AND. PRESENT( H_row ) .AND.               &
                    PRESENT( H_col ) ) ) THEN
         data%tru_inform%status = GALAHAD_error_optional
         GO TO 900
       END IF
       CALL SMT_put( data%nlp%H%type, 'COORDINATE',                            &
                     data%tru_inform%alloc_status )
       data%nlp%H%n = n
       data%nlp%H%ne = H_ne

       array_name = 'tru: data%nlp%H%row'
       CALL SPACE_resize_array( data%nlp%H%ne, data%nlp%H%row,                 &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
       IF ( data%tru_inform%status /= 0 ) GO TO 900

       array_name = 'tru: data%nlp%H%col'
       CALL SPACE_resize_array( data%nlp%H%ne, data%nlp%H%col,                 &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
       IF ( data%tru_inform%status /= 0 ) GO TO 900

       array_name = 'tru: data%nlp%H%val'
       CALL SPACE_resize_array( data%nlp%H%ne, data%nlp%H%val,                 &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
       IF ( data%tru_inform%status /= 0 ) GO TO 900

       data%nlp%H%row( : data%nlp%H%ne ) = H_row( : data%nlp%H%ne )
       data%nlp%H%col( : data%nlp%H%ne ) = H_col( : data%nlp%H%ne )

     CASE ( 'sparse_by_rows', 'SPARSE_BY_ROWS' )
       IF ( .NOT. ( PRESENT( H_ptr ) .AND. PRESENT( H_col ) ) ) THEN
         data%tru_inform%status = GALAHAD_error_optional
         GO TO 900
       END IF
       CALL SMT_put( data%nlp%H%type, 'SPARSE_BY_ROWS',                        &
                     data%tru_inform%alloc_status )
       data%nlp%H%n = n
       data%nlp%H%ne = H_ptr( n + 1 ) - 1

       array_name = 'tru: data%nlp%H%ptr'
       CALL SPACE_resize_array( n + 1, data%nlp%H%ptr,                         &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
       IF ( data%tru_inform%status /= 0 ) GO TO 900

       array_name = 'tru: data%nlp%H%col'
       CALL SPACE_resize_array( data%nlp%H%ne, data%nlp%H%col,                 &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
       IF ( data%tru_inform%status /= 0 ) GO TO 900

       array_name = 'tru: data%nlp%H%val'
       CALL SPACE_resize_array( data%nlp%H%ne, data%nlp%H%val,                 &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
       IF ( data%tru_inform%status /= 0 ) GO TO 900

       data%nlp%H%ptr( : n + 1 ) = H_ptr( : n + 1 )
       data%nlp%H%col( : data%nlp%H%ne ) = H_col( : data%nlp%H%ne )

     CASE ( 'dense', 'DENSE' )
       CALL SMT_put( data%nlp%H%type, 'DENSE', data%tru_inform%alloc_status )
       data%nlp%H%n = n
       data%nlp%H%ne = ( n * ( n + 1 ) ) / 2

       array_name = 'tru: data%nlp%H%val'
       CALL SPACE_resize_array( data%nlp%H%ne, data%nlp%H%val,                 &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
       IF ( data%tru_inform%status /= 0 ) GO TO 900

     CASE ( 'diagonal', 'DIAGONAL' )
       CALL SMT_put( data%nlp%H%type, 'DIAGONAL', data%tru_inform%alloc_status )
       data%nlp%H%n = n
       data%nlp%H%ne = n

       array_name = 'tru: data%nlp%H%val'
       CALL SPACE_resize_array( data%nlp%H%ne, data%nlp%H%val,                 &
            data%tru_inform%status, data%tru_inform%alloc_status,              &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%tru_inform%bad_alloc, out = error )
       IF ( data%tru_inform%status /= 0 ) GO TO 900
     CASE ( 'absent', 'ABSENT' )
       data%tru_control%hessian_available = .FALSE.
     CASE DEFAULT
       data%tru_inform%status = GALAHAD_error_unknown_storage
     END SELECT       

     status = GALAHAD_ready_to_solve
     RETURN

!  error returns

 900 CONTINUE
     status =  data%tru_inform%status
     RETURN

!  End of subroutine TRU_import

     END SUBROUTINE TRU_import

!-  G A L A H A D -  T R U _ r e s e t _ c o n t r o l   S U B R O U T I N E  -

     SUBROUTINE TRU_reset_control( control, data, status )

!  reset control parameters after import if required.
!  See TRU_solve for a description of the required arguments

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( TRU_control_type ), INTENT( IN ) :: control
     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     INTEGER, INTENT( OUT ) :: status

!  set control in internal data

     data%tru_control = control
     
!  flag a successful call

     status = GALAHAD_ready_to_solve
     RETURN

!  end of subroutine TRU_reset_control

     END SUBROUTINE TRU_reset_control

!-  G A L A H A D -  T R U _ s o l v e _ w i t h _ m a t  S U B R O U T I N E  -

     SUBROUTINE TRU_solve_with_mat( data, userdata, status, X, G,              &
                                    eval_F, eval_G, eval_H, eval_PREC )

!  solve the unconstrained problem previously imported when access
!  to function, gradient, Hessian and preconditioning operations are
!  available via subroutine calls. See TRU_solve for a description of 
!  the required arguments. The variable status is a proxy for inform%status

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     INTEGER, INTENT( INOUT ) :: status
     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: X
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: G
     EXTERNAL :: eval_F, eval_G, eval_H, eval_PREC

     data%tru_inform%status = status
     IF ( data%tru_inform%status == 1 )                                        &
       data%nlp%X( : data%nlp%n ) = X( : data%nlp%n )

!  call the solver

     CALL TRU_solve( data%nlp, data%tru_control, data%tru_inform,              &
                     data%tru_data, userdata, eval_F = eval_F,                 &
                     eval_G = eval_G, eval_H = eval_H, eval_PREC = eval_PREC )

     X( : data%nlp%n ) = data%nlp%X( : data%nlp%n )
     IF ( data%tru_inform%status == GALAHAD_ok )                               &
       G( : data%nlp%n ) = data%nlp%G( : data%nlp%n )
     status = data%tru_inform%status

     RETURN

!  end of subroutine TRU_solve_with_mat

     END SUBROUTINE TRU_solve_with_mat

! - G A L A H A D -  T R U _ s o l v e _ without _ m a t  S U B R O U T I N E -

     SUBROUTINE TRU_solve_without_mat( data, userdata, status, X, G,           &
                                       eval_F, eval_G, eval_HPROD, eval_PREC )

!  solve the unconstrained problem previously imported when access
!  to function, gradient, Hessian-vector and preconditioning operations 
!  are available via subroutine calls. See TRU_solve for a description 
!  of the required arguments. The variable status is a proxy for inform%status

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     INTEGER, INTENT( INOUT ) :: status
     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: X
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: G
     EXTERNAL :: eval_F, eval_G, eval_HPROD, eval_PREC

     data%tru_inform%status = status
     IF ( data%tru_inform%status == 1 )                                        &
       data%nlp%X( : data%nlp%n ) = X( : data%nlp%n )

!  call the solver

     CALL TRU_solve( data%nlp, data%tru_control, data%tru_inform,              &
                     data%tru_data, userdata, eval_F = eval_F,                 &
                     eval_G = eval_G, eval_HPROD = eval_HPROD,                 &
                     eval_PREC = eval_PREC )

     X( : data%nlp%n ) = data%nlp%X( : data%nlp%n )
     IF ( data%tru_inform%status == GALAHAD_ok )                               &
       G( : data%nlp%n ) = data%nlp%G( : data%nlp%n )
     status = data%tru_inform%status

     RETURN

!  end of subroutine TRU_solve_without_mat

     END SUBROUTINE TRU_solve_without_mat

!-  G A L A H A D -  T R U _ s o l v e _ reverse _ M A T  S U B R O U T I N E -

     SUBROUTINE TRU_solve_reverse_with_mat( data, status, eval_status,         &
                                            X, f, G, H_val, U, V )

!  solve the unconstrained problem previously imported when access
!  to function, gradient, Hessian and preconditioning operations are
!  available via reverse communication. See TRU_solve for a description 
!  of the required arguments. The variable status is a proxy for inform%status

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     INTEGER, INTENT( INOUT ) :: status
     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     INTEGER, INTENT( INOUT ) :: eval_status
     REAL ( KIND = wp ), INTENT( IN ) :: f
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: X
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: G
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: H_val
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: U
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: V

!  recover data from reverse communication

     data%tru_inform%status = status
     data%tru_data%eval_status = eval_status
     SELECT CASE ( data%tru_inform%status )
     CASE ( 1 )
       data%nlp%X( : data%nlp%n ) = X( : data%nlp%n )
     CASE ( 2 )
       data%tru_data%eval_status = eval_status
       IF ( eval_status == 0 ) data%nlp%f = f
     CASE( 3 ) 
       data%tru_data%eval_status = eval_status
       IF ( eval_status == 0 ) data%nlp%G( : data%nlp%n ) = G( : data%nlp%n )
     CASE( 4 ) 
       data%tru_data%eval_status = eval_status
       IF ( eval_status == 0 )                                                 &
         data%nlp%H%val( : data%nlp%H%ne ) = H_val( : data%nlp%H%ne )
     CASE( 6 )
       data%tru_data%eval_status = eval_status
       IF ( eval_status == 0 )                                                 &
         data%tru_data%U( : data%nlp%n ) = U( : data%nlp%n )
     END SELECT

!  call the solver

     CALL TRU_solve( data%nlp, data%tru_control, data%tru_inform,              &
                     data%tru_data, data%userdata )

!  collect data for reverse communication

     X( : data%nlp%n ) = data%nlp%X( : data%nlp%n )
     SELECT CASE ( data%tru_inform%status )
     CASE( 0 )
       G( : data%nlp%n ) = data%nlp%G( : data%nlp%n )
     CASE( 6 )
       V( : data%nlp%n ) = data%tru_data%V( : data%nlp%n )
     CASE( 5 ) 
       WRITE( 6, "( ' there should not be a case ', I0, ' return' )" )         &
         data%tru_inform%status
     END SELECT
     status = data%tru_inform%status

     RETURN

!  end of subroutine TRU_solve_reverse_with_mat

     END SUBROUTINE TRU_solve_reverse_with_mat

!-  G A L A H A D -  T R U _ s o l v e _ reverse _ no _ mat  S U B R O U T I N E

     SUBROUTINE TRU_solve_reverse_without_mat( data, status, eval_status,      &
                                               X, f, G, U, V )

!  solve the unconstrained problem previously imported when access
!  to function, gradient, Hessian-vector and preconditioning operations 
!  are available via reverse communication. See TRU_solve for a description 
!  of the required arguments. The variable status is a proxy for inform%status

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     INTEGER, INTENT( INOUT ) :: status
     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     INTEGER, INTENT( INOUT ) :: eval_status
     REAL ( KIND = wp ), INTENT( IN ) :: f
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: X
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: G
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: U
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: V

!  recover data from reverse communication

     data%tru_inform%status = status
     data%tru_data%eval_status = eval_status
     SELECT CASE ( data%tru_inform%status )
     CASE ( 1 )
       data%nlp%X( : data%nlp%n ) = X( : data%nlp%n )
     CASE ( 2 )
       data%tru_data%eval_status = eval_status
       IF ( eval_status == 0 ) data%nlp%f = f
     CASE( 3 ) 
       data%tru_data%eval_status = eval_status
       IF ( eval_status == 0 ) data%nlp%G( : data%nlp%n ) = G( : data%nlp%n )
     CASE( 5 ) 
       data%tru_data%eval_status = eval_status
       IF ( eval_status == 0 )                                                 &
         data%tru_data%U( : data%nlp%n ) = U( : data%nlp%n )
     CASE( 6 )
       data%tru_data%eval_status = eval_status
       IF ( eval_status == 0 )                                                 &
         data%tru_data%U( : data%nlp%n ) = U( : data%nlp%n )
     END SELECT

!  call the solver

     CALL TRU_solve( data%nlp, data%tru_control, data%tru_inform,              &
                     data%tru_data, data%userdata )

!  collect data for reverse communication

     X( : data%nlp%n ) = data%nlp%X( : data%nlp%n )
     SELECT CASE ( data%tru_inform%status )
     CASE( 0 )
       G( : data%nlp%n ) = data%nlp%G( : data%nlp%n )
     CASE( 2, 3 ) 
     CASE( 4 ) 
       WRITE( 6, "( ' there should not be a case ', I0, ' return' )" )         &
         data%tru_inform%status
     CASE( 5 )
       U( : data%nlp%n ) = data%tru_data%U( : data%nlp%n )
       V( : data%nlp%n ) = data%tru_data%V( : data%nlp%n )
     CASE( 6 )
       V( : data%nlp%n ) = data%tru_data%V( : data%nlp%n )
     END SELECT
     status = data%tru_inform%status

     RETURN

!  end of subroutine TRU_solve_reverse_without_mat

     END SUBROUTINE TRU_solve_reverse_without_mat

!-  G A L A H A D -  T R U _ i n f o r m a t i o n   S U B R O U T I N E  -

     SUBROUTINE TRU_information( data, inform, status )

!  return solver information during or after solution by TRU
!  See TRU_solve for a description of the required arguments

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( TRU_full_data_type ), INTENT( INOUT ) :: data
     TYPE ( TRU_inform_type ), INTENT( OUT ) :: inform
     INTEGER, INTENT( OUT ) :: status

!  recover inform from internal data

     inform = data%tru_inform
     
!  flag a successful call

     status = GALAHAD_ok
     RETURN

!  end of subroutine TRU_information

     END SUBROUTINE TRU_information

!  End of module GALAHAD_TRU

   END MODULE GALAHAD_TRU_double
