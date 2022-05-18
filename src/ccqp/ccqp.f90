! THIS VERSION: GALAHAD 4.1 - 2022-05-17 AT 08:30 GMT.

!-*-*-*-*-*-*-*-*-*-  G A L A H A D _ C C Q P    M O D U L E  -*-*-*-*-*-*-*-*-

!  Copyright reserved, Gould/Orban/Toint, for GALAHAD productions
!  Principal author: Nick Gould

!  History -
!   originally released as cqp with GALAHAD Version 2.4, January 1st 2010
!   modified to form ccqp with GALAHAD 4.1, May 17th 2022

!  For full documentation, see
!   http://galahad.rl.ac.uk/galahad-www/specs.html

    MODULE GALAHAD_CCQP_double

!     ------------------------------------------------
!     |                                              |
!     | Minimize the quadratic objective function    |
!     |                                              |
!     |        1/2 x^T H x + g^T x + f               |
!     |                                              |
!     | or linear/seprable objective function        |
!     |                                              |
!     |  1/2 || W * ( x - x^0 ) ||_2^2 + g^T x + f   |
!     |                                              |
!     | subject to the linear constraints and bounds |
!     |                                              |
!     |           c_l <= A x <= c_u                  |
!     |           x_l <=  x <= x_u                   |
!     |                                              |
!     | for some positive-semi-definite Hessian H    |
!     | or |(possibly zero) diagonal matrix W using  |
!     | an infeasible-point primal-dual method       |
!     |                                              |
!     ------------------------------------------------

!$    USE omp_lib
!NOT95USE GALAHAD_CPU_time
      USE GALAHAD_CLOCK
      USE GALAHAD_SYMBOLS
      USE GALAHAD_STRING, ONLY: STRING_pleural, STRING_verb_pleural,           &
                                       STRING_ies, STRING_are, STRING_ordinal
      USE GALAHAD_SPACE_double
      USE GALAHAD_SMT_double
      USE GALAHAD_QPT_double
      USE GALAHAD_SPECFILE_double
      USE GALAHAD_QPP_double, CCQP_dims_type => QPP_dims_type
      USE GALAHAD_QPD_double, CCQP_data_type => QPD_data_type,                 &
                              CCQP_AX => QPD_AX, CCQP_HX => QPD_HX,            &
                              CCQP_abs_AX => QPD_abs_AX,                       &
                              CCQP_abs_HX => QPD_abs_HX
      USE GALAHAD_ROOTS_double
      USE GALAHAD_LMS_double, ONLY: LMS_data_type, LMS_apply_lbfgs
      USE GALAHAD_SORT_double, ONLY: SORT_inverse_permute
      USE GALAHAD_FDC_double
      USE GALAHAD_SBLS_double
      USE GALAHAD_CRO_double
      USE GALAHAD_FIT_double
      USE GALAHAD_NORMS_double, ONLY: TWO_norm
      USE GALAHAD_CHECKPOINT_double
      USE GALAHAD_RPD_double, ONLY: RPD_inform_type, RPD_write_qp_problem_data

      IMPLICIT NONE

      PRIVATE
      PUBLIC :: CCQP_initialize, CCQP_read_specfile, CCQP_solve,               &
                CCQP_solve_main, CCQP_terminate,                               &
                QPT_problem_type, SMT_type, SMT_put, SMT_get,                  &
                CCQP_Ax, CCQP_data_type, CCQP_dims_type, CCQP_indicators,      &
                CCQP_workspace, CCQP_full_initialize, CCQP_full_terminate,     &
                CCQP_import, CCQP_solve_qp, CCQP_solve_sldqp,                  &
                CCQP_reset_control, CCQP_information

!----------------------
!   I n t e r f a c e s
!----------------------

     INTERFACE CCQP_initialize
       MODULE PROCEDURE CCQP_initialize, CCQP_full_initialize
     END INTERFACE CCQP_initialize

     INTERFACE CCQP_terminate
       MODULE PROCEDURE CCQP_terminate, CCQP_full_terminate
     END INTERFACE CCQP_terminate

!--------------------
!   P r e c i s i o n
!--------------------

      INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
      INTEGER, PARAMETER :: long = SELECTED_INT_KIND( 18 )

!----------------------
!   P a r a m e t e r s
!----------------------

      INTEGER, PARAMETER :: max_sc = 200
      INTEGER, PARAMETER :: no_last = - 1000
      REAL ( KIND = wp ), PARAMETER :: zero = 0.0_wp
      REAL ( KIND = wp ), PARAMETER :: point1 = 0.1_wp
      REAL ( KIND = wp ), PARAMETER :: point01 = 0.01_wp
      REAL ( KIND = wp ), PARAMETER :: half = 0.5_wp
      REAL ( KIND = wp ), PARAMETER :: one = 1.0_wp
      REAL ( KIND = wp ), PARAMETER :: two = 2.0_wp
      REAL ( KIND = wp ), PARAMETER :: three = 3.0_wp
      REAL ( KIND = wp ), PARAMETER :: four = 4.0_wp
      REAL ( KIND = wp ), PARAMETER :: eight = 8.0_wp
      REAL ( KIND = wp ), PARAMETER :: sixteen = 16.0_wp
      REAL ( KIND = wp ), PARAMETER :: ten = 10.0_wp
      REAL ( KIND = wp ), PARAMETER :: hundred = 100.0_wp
      REAL ( KIND = wp ), PARAMETER :: thousand = 1000.0_wp
      REAL ( KIND = wp ), PARAMETER :: tenm4 = ten ** ( - 4 )
      REAL ( KIND = wp ), PARAMETER :: tenm5 = ten ** ( - 5 )
      REAL ( KIND = wp ), PARAMETER :: tenm7 = ten ** ( - 7 )
      REAL ( KIND = wp ), PARAMETER :: tenm10 = ten ** ( - 10 )
      REAL ( KIND = wp ), PARAMETER :: ten4 = ten ** 4
      REAL ( KIND = wp ), PARAMETER :: ten5 = ten ** 5
      REAL ( KIND = wp ), PARAMETER :: infinity = HUGE( one )
      REAL ( KIND = wp ), PARAMETER :: epsmch = EPSILON( one )
      REAL ( KIND = wp ), PARAMETER :: onemeps = one - epsmch
      REAL ( KIND = wp ), PARAMETER :: teneps = ten * epsmch
      REAL ( KIND = wp ), PARAMETER :: rminvr_zero = epsmch
      REAL ( KIND = wp ), PARAMETER :: twentyeps = two * teneps
      REAL ( KIND = wp ), PARAMETER :: stop_alpha = ten ** ( -15 )
      REAL ( KIND = wp ), PARAMETER :: relative_pivot_default = 0.01_wp

!-------------------------------------------------
!  D e r i v e d   t y p e   d e f i n i t i o n s
!-------------------------------------------------

!  - - - - - - - - - - - - - - - - - - - - - - -
!   control derived type with component defaults
!  - - - - - - - - - - - - - - - - - - - - - - -

      TYPE, PUBLIC :: CCQP_control_type

!   error and warning diagnostics occur on stream error

        INTEGER :: error = 6

!   general output occurs on stream out

        INTEGER :: out = 6

!   the level of output required is specified by print_level

        INTEGER :: print_level = 0

!   any printing will start on this iteration

        INTEGER :: start_print = - 1

!   any printing will stop on this iteration

        INTEGER :: stop_print = - 1

!   at most maxit inner iterations are allowed

        INTEGER :: maxit = 1000

!   the number of iterations for which the overall infeasibility
!     of the problem is not reduced by at least a factor %reduce_infeas
!     before the problem is flagged as infeasible (see reduce_infeas)

        INTEGER :: infeas_max = 10

!   the initial value of the barrier parameter will not be changed for the
!     first muzero_fixed iterations
!
        INTEGER :: muzero_fixed = 0

!   indicate whether and how much of the input problem
!    should be restored on output. Possible values are

!      0 nothing restored
!      1 scalar and vector parameters
!      2 all parameters

        INTEGER :: restore_problem = 2

!   specifies the type of indicator function used. Pssible values are

!     1 primal indicator: constraint active <=> distance to nearest bound
!         <= %indicator_p_tol
!     2 primal-dual indicator: constraint active <=> distance to nearest bound
!        <= %indicator_tol_pd * size of corresponding multiplier
!     3 primal-dual indicator: constraint active <=> distance to nearest bound
!        <= %indicator_tol_tapia * distance to same bound at previous iteration

        INTEGER :: indicator_type = 2

!   which residual trajectory should be used to aim from the current iterate
!   to the solution

!     1 the Zhang linear residual trajectory
!     2 the Zhao-Sun quadratic residual trajectory
!     3 the Zhang arc ultimately switching to the Zhao-Sun residual trajectory
!     4 the mixed linear-quadratic residual trajectory
!     5 the Zhang arc ultimately switching to the mixed linear-quadratic
!       residual trajectory

        INTEGER :: arc = 1

!    the order of (Taylor/Puiseux) series to fit to the path data

        INTEGER :: series_order = 2

!    specifies the unit number to write generated SIF file describing the
!     current problem

        INTEGER :: sif_file_device = 52

!    specifies the unit number to write generated QPLIB file describing the
!     current problem

        INTEGER :: qplib_file_device = 53

!   any bound larger than infinity in modulus will be regarded as infinite

        REAL ( KIND = wp ) :: infinity = ten ** 19

!   the required absolute and relative accuracies for the primal infeasibility

        REAL ( KIND = wp ) :: stop_abs_p = epsmch
        REAL ( KIND = wp ) :: stop_rel_p = epsmch

!   the required absolute and relative accuracies for the dual infeasibility

        REAL ( KIND = wp ) :: stop_abs_d = epsmch
        REAL ( KIND = wp ) :: stop_rel_d = epsmch

!   the required absolute and relative accuracies for the complementarity

        REAL ( KIND = wp ) :: stop_abs_c = epsmch
        REAL ( KIND = wp ) :: stop_rel_c = epsmch

!   perturb_h will be added to the Hessian

        REAL ( KIND = wp ) :: perturb_h = zero

!   initial primal variables will not be closer than prfeas from their bounds

        REAL ( KIND = wp ) :: prfeas = ten4

!   initial dual variables will not be closer than dufeas from their bounds
!
        REAL ( KIND = wp ) :: dufeas = ten4

!   the initial value of the barrier parameter. If muzero is not positive,
!    it will be reset to an appropriate value

        REAL ( KIND = wp ) :: muzero = - one

!   the weight attached to primal-dual infeasibility compared to complementarity
!    when assessing step acceptance

        REAL ( KIND = wp ) :: tau = one

!   individual complementarities will not be allowed to be smaller than
!    gamma_c times the average value

        REAL ( KIND = wp ) :: gamma_c = tenm5

!   the average complementarity will not be allowed to be smaller than
!    gamma_f times the primal/dual infeasibility

        REAL ( KIND = wp ) :: gamma_f = tenm5

!   if the overall infeasibility of the problem is not reduced by at least a
!    factor reduce_infeas over %infeas_max iterations, the problem is flagged
!    as infeasible (see infeas_max)

        REAL ( KIND = wp ) :: reduce_infeas = one - point01

!   if the objective function value is smaller than obj_unbounded, it will be
!    flagged as unbounded from below.

        REAL ( KIND = wp ) :: obj_unbounded = - one / epsmch

!   if W=0 and the potential function value is smaller than
!         potential_unbounded * number of one-sided bounds,
!     the analytic center will be flagged as unbounded

        REAL ( KIND = wp ) :: potential_unbounded = - 10.0_wp

!   any pair of constraint bounds (c_l,c_u) or (x_l,x_u) that are closer than
!    identical_bounds_tol will be reset to the average of their values

        REAL ( KIND = wp ) :: identical_bounds_tol = epsmch

!  start terminal extrapolation when mu reaches mu_lunge

        REAL ( KIND = wp ) :: mu_lunge = ten ** ( - 5 )

!   if %indicator_type = 1, a constraint/bound will be
!    deemed to be active <=> distance to nearest bound <= %indicator_p_tol

        REAL ( KIND = wp ) :: indicator_tol_p = epsmch

!   if %indicator_type = 2, a constraint/bound will be deemed to be active
!     <=> distance to nearest bound
!        <= %indicator_tol_pd * size of corresponding multiplier

        REAL ( KIND = wp ) :: indicator_tol_pd = 1.0_wp

!   if %indicator_type = 3, a constraint/bound will be deemed to be active
!     <=> distance to nearest bound
!        <= %indicator_tol_tapia * distance to same bound at previous iteration

        REAL ( KIND = wp ) :: indicator_tol_tapia = 0.9_wp

!   the maximum CPU time allowed (-ve means infinite)

        REAL ( KIND = wp ) :: cpu_time_limit = - one

!   the maximum elapsed clock time allowed (-ve means infinite)

        REAL ( KIND = wp ) :: clock_time_limit = - one

!   the equality constraints will be preprocessed to remove any linear
!    dependencies if true

        LOGICAL :: remove_dependencies = .TRUE.

!    any problem bound with the value zero will be treated as if it were a
!     general value if true

        LOGICAL :: treat_zero_bounds_as_general = .FALSE.

!   if %just_feasible is true, the algorithm will stop as soon as a feasible
!     point is found. Otherwise, the optimal solution to the problem will be
!     found

        LOGICAL :: treat_separable_as_general = .FALSE.

!   if %treat_separable_as_general, is true, any separability in the
!    problem structure will be ignored

        LOGICAL :: just_feasible  = .FALSE.

!   if %getdua, is true, advanced initial values are obtained for the
!    dual variables

        LOGICAL :: getdua = .FALSE.

!  decide between Puiseux and Taylor series approximations to the arc

        LOGICAL :: puiseux = .TRUE.

!    try every order of series up to series_order?

        LOGICAL :: every_order = .TRUE.

!   if %feasol is true, the final solution obtained will be perturbed so that
!    variables close to their bounds are moved onto these bounds

        LOGICAL :: feasol = .FALSE.

!   if %balance_initial_complentarity is true, the initial complemetarity
!    is required to be balanced
!
        LOGICAL :: balance_initial_complentarity = .FALSE.
!
!  if %crossover is true, cross over the solution to one defined by
!   linearly-independent constraints if possible
!
        LOGICAL :: crossover = .TRUE.

!   if %space_critical true, every effort will be made to use as little
!     space as possible. This may result in longer computation time

        LOGICAL :: space_critical = .FALSE.

!   if %deallocate_error_fatal is true, any array/pointer deallocation error
!     will terminate execution. Otherwise, computation will continue

        LOGICAL :: deallocate_error_fatal = .FALSE.

!   if %generate_sif_file is .true. if a SIF file describing the current
!    problem is to be generated

        LOGICAL :: generate_sif_file = .FALSE.

!   if %generate_qplib_file is .true. if a QPLIB file describing the current
!    problem is to be generated

        LOGICAL :: generate_qplib_file = .FALSE.

!  name of generated SIF file containing input problem

        CHARACTER ( LEN = 30 ) :: sif_file_name =                              &
         "CCQPPROB.SIF"  // REPEAT( ' ', 18 )

!  name of generated QPLIB file containing input problem

        CHARACTER ( LEN = 30 ) :: qplib_file_name =                            &
         "CCQPPROB.qplib"  // REPEAT( ' ', 16 )

!  all output lines will be prefixed by %prefix(2:LEN(TRIM(%prefix))-1)
!   where %prefix contains the required string enclosed in
!   quotes, e.g. "string" or 'string'

        CHARACTER ( LEN = 30 ) :: prefix = '""                            '

!  control parameters for FDC

        TYPE ( FDC_control_type ) :: FDC_control

!  control parameters for SBLS

        TYPE ( SBLS_control_type ) :: SBLS_control

!  control parameters for FIT

        TYPE ( FIT_control_type ) :: FIT_control

!  control parameters for ROOTS

        TYPE ( ROOTS_control_type ) :: ROOTS_control

!  control parameters for CRO

        TYPE ( CRO_control_type ) :: CRO_control
      END TYPE

!  - - - - - - - - - - - - - - - - - - - - - -
!   time derived type with component defaults
!  - - - - - - - - - - - - - - - - - - - - - -

      TYPE, PUBLIC :: CCQP_time_type

!  the total CPU time spent in the package

        REAL ( KIND = wp ) :: total = 0.0

!  the CPU time spent preprocessing the problem

        REAL ( KIND = wp ) :: preprocess = 0.0

!  the CPU time spent detecting linear dependencies

        REAL ( KIND = wp ) :: find_dependent = 0.0

!  the CPU time spent analysing the required matrices prior to factorization

        REAL ( KIND = wp ) :: analyse = 0.0

!  the CPU time spent factorizing the required matrices

        REAL ( KIND = wp ):: factorize = 0.0

!  the CPU time spent computing the search direction

        REAL ( KIND = wp ) :: solve = 0.0

!  the total clock time spent in the package

        REAL ( KIND = wp ) :: clock_total = 0.0

!  the clock time spent preprocessing the problem

        REAL ( KIND = wp ) :: clock_preprocess = 0.0

!  the clock time spent detecting linear dependencies

        REAL ( KIND = wp ) :: clock_find_dependent = 0.0

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

      TYPE, PUBLIC :: CCQP_inform_type

!  return status. See CCQP_solve for details

        INTEGER :: status = 0

!  the status of the last attempted allocation/deallocation

        INTEGER :: alloc_status = 0

!  the name of the array for which an allocation/deallocation error ocurred

        CHARACTER ( LEN = 80 ) :: bad_alloc = REPEAT( ' ', 80 )

!  the total number of iterations required

        INTEGER :: iter = - 1

!  the return status from the factorization

        INTEGER :: factorization_status = 0

!  the total integer workspace required for the factorization

        INTEGER  ( KIND = long ) :: factorization_integer = - 1

!  the total real workspace required for the factorization

        INTEGER  ( KIND = long ) :: factorization_real = - 1

!  the total number of factorizations performed

        INTEGER :: nfacts = - 1

!  the total number of "wasted" function evaluations during the linesearch

        INTEGER :: nbacts = - 1

!  the number of threads used

        INTEGER :: threads = 1

!  the value of the objective function at the best estimate of the solution
!   determined by CCQP_solve

        REAL ( KIND = wp ) :: obj = HUGE( one )

!  the value of the primal infeasibility

        REAL ( KIND = wp ) :: primal_infeasibility = HUGE( one )

!  the value of the dual infeasibility

        REAL ( KIND = wp ) :: dual_infeasibility = HUGE( one )

!  the value of the complementary slackness

        REAL ( KIND = wp ) :: complementary_slackness = HUGE( one )

!  these values at the initial point (needed bg GALAHAD_CDQP)

        REAL ( KIND = wp ) :: init_primal_infeasibility = HUGE( one )
        REAL ( KIND = wp ) :: init_dual_infeasibility = HUGE( one )
        REAL ( KIND = wp ) :: init_complementary_slackness = HUGE( one )

!  the value of the logarithmic potential function
!      sum -log(distance to constraint boundary)

        REAL ( KIND = wp ) :: potential

!  the smallest pivot which was not judged to be zero when detecting linearly
!   dependent constraints

        REAL ( KIND = wp ) :: non_negligible_pivot = - one

!  is the returned "solution" feasible?

        LOGICAL :: feasible = .FALSE.

!  checkpoints(i) records the iteration at which the criticality measures
!   first fall below 10**-i, i = 1, ..., 16 (-1 means not achieved)

        INTEGER, DIMENSION( 16 ) :: checkpointsIter = - 1
        REAL ( KIND = wp ), DIMENSION( 16 ) :: checkpointsTime = - one

!  timings (see above)

        TYPE ( CCQP_time_type ) :: time

!  inform parameters for FDC

        TYPE ( FDC_inform_type ) :: FDC_inform

!  inform parameters for SBLS

        TYPE ( SBLS_inform_type ) :: SBLS_inform

!  return information from FIT

        TYPE ( FIT_inform_type ) :: FIT_inform

!  return information from ROOTS

        TYPE ( ROOTS_inform_type ) :: ROOTS_inform

!  inform parameters for CRO

        TYPE ( CRO_inform_type ) :: CRO_inform

!  inform parameters for RPD

        TYPE ( RPD_inform_type ) :: RPD_inform
      END TYPE

!  - - - - - - - - - - - -
!   full_data derived type
!  - - - - - - - - - - - -

      TYPE, PUBLIC :: CCQP_full_data_type
        LOGICAL :: f_indexing
        TYPE ( CCQP_data_type ) :: CCQP_data
        TYPE ( CCQP_control_type ) :: CCQP_control
        TYPE ( CCQP_inform_type ) :: CCQP_inform
        TYPE ( QPT_problem_type ) :: prob
      END TYPE CCQP_full_data_type

   CONTAINS

!-*-*-*-*-*-   C C Q P _ I N I T I A L I Z E   S U B R O U T I N E   -*-*-*-*-*

      SUBROUTINE CCQP_initialize( data, control, inform )

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Default control data for CCQP. This routine should be called before
!  CCQP_solve
!
!  ---------------------------------------------------------------------------
!
!  Arguments:
!
!  data     private internal data
!  control  a structure containing control information. See preamble
!  inform   a structure containing output information. See preamble
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      TYPE ( CCQP_data_type ), INTENT( INOUT ) :: data
      TYPE ( CCQP_control_type ), INTENT( OUT ) :: control
      TYPE ( CCQP_inform_type ), INTENT( OUT ) :: inform

      inform%status = GALAHAD_ok

!  Set real control parameters

      control%stop_abs_p = epsmch ** 0.33
!     control%stop_rel_p = epsmch ** 0.33
      control%stop_abs_c = epsmch ** 0.33
!     control%stop_rel_c = epsmch ** 0.33
      control%stop_abs_d = epsmch ** 0.33
!     control%stop_rel_d = epsmch ** 0.33
      control%obj_unbounded = - epsmch ** ( - 2 )
      control%indicator_tol_p = control%stop_abs_p

!  Initalize FDC components

      CALL FDC_initialize( data%FDC_data, control%FDC_control,                 &
                           inform%FDC_inform  )
      control%FDC_control%max_infeas = control%stop_abs_p
      control%FDC_control%prefix = '" - FDC:"                     '

!  Initalize SBLS components

      CALL SBLS_initialize( data%SBLS_data, control%SBLS_control,              &
                            inform%SBLS_inform )
!     control%SBLS_control%perturb_to_make_definite = .FALSE.
!     control%SBLS_control%preconditioner = 2
      control%SBLS_control%prefix = '" - SBLS:"                    '

!  Set FIT control parameters

      CALL FIT_initialize( data%FIT_data, control%FIT_control,                 &
                           inform%FIT_inform )
      control%FIT_control%prefix = '" - FIT:"                     '

!  Set ROOTS control parameters

      CALL ROOTS_initialize( data%ROOTS_data, control%ROOTS_control,           &
                             inform%ROOTS_inform )
      control%ROOTS_control%tol = epsmch ** 0.75
      control%ROOTS_control%prefix = '" - ROOTS:"                   '

!  Set CRO control parameters

      CALL CRO_initialize( data%CRO_data, control%CRO_control,                 &
                           inform%CRO_inform )
      control%CRO_control%prefix = '" - CRO:"                     '

!  initialise private data

      data%trans = 0 ; data%tried_to_remove_deps = .FALSE.
      data%save_structure = .TRUE.

      RETURN

!  End of CCQP_initialize

      END SUBROUTINE CCQP_initialize

!- G A L A H A D -  C C Q P _ F U L L _ I N I T I A L I Z E  S U B R O U T I N E -

     SUBROUTINE CCQP_full_initialize( data, control, inform )

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!   Provide default values for CCQP controls

!   Arguments:

!   data     private internal data
!   control  a structure containing control information. See preamble
!   inform   a structure containing output information. See preamble

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( CCQP_full_data_type ), INTENT( INOUT ) :: data
     TYPE ( CCQP_control_type ), INTENT( OUT ) :: control
     TYPE ( CCQP_inform_type ), INTENT( OUT ) :: inform

     CALL CCQP_initialize( data%ccqp_data, control, inform )

     RETURN

!  End of subroutine CCQP_full_initialize

     END SUBROUTINE CCQP_full_initialize

!-*-*-*-*-   C C Q P _ R E A D _ S P E C F I L E  S U B R O U T I N E   -*-*-*-

      SUBROUTINE CCQP_read_specfile( control, device, alt_specname )

!  Reads the content of a specification file, and performs the assignment of
!  values associated with given keywords to the corresponding control parameters

!  The defauly values as given by CCQP_initialize could (roughly)
!  have been set as:

! BEGIN CCQP SPECIFICATIONS (DEFAULT)
!  error-printout-device                             6
!  printout-device                                   6
!  print-level                                       0
!  start-print                                       -1
!  stop-print                                        -1
!  maximum-number-of-iterations                      1000
!  maximum-number-of-pcg-iterations                  1000
!  maximum-poor-iterations-before-infeasible         200
!  barrier-fixed-until-iteration                     1
!  indicator-type-used                               3
!  arc-used                                          1
!  series-order                                      5
!  restore-problem-on-output                         2
!  sif-file-device                                   52
!  qplib-file-device                                 53
!  infinity-value                                    1.0D+19
!  absolute-primal-accuracy                          1.0D-5
!  relative-primal-accuracy                          1.0D-5
!  absolute-dual-accuracy                            1.0D-5
!  relative-dual-accuracy                            1.0D-5
!  absolute-complementary-slackness-accuracy         1.0D-5
!  relative-complementary-slackness-accuracy         1.0D-5
!  perturb-hessian-by                                0.0
!  mininum-initial-primal-feasibility                1000.0
!  mininum-initial-dual-feasibility                  1000.0
!  initial-barrier-parameter                         -1.0
!  feasibility-vs-complementarity-weight             1.0
!  balance-complentarity-factor                      1.0D-5
!  balance-feasibility-factor                        1.0D-5
!  poor-iteration-tolerance                          0.98
!  minimum-objective-before-unbounded                -1.0D+32
!  minimum-potential-before-unbounded                -10.0
!  identical-bounds-tolerance                        1.0D-15
!  barrier-rqeuired-before-final-lunge               1.0D-5
!  primal-indicator-tolerance                        1.0D-5
!  primal-dual-indicator-tolerance                   1.0
!  tapia-indicator-tolerance                         0.9
!  maximum-cpu-time-limit                            -1.0
!  maximum-clock-time-limit                          -1.0
!  remove-linear-dependencies                        T
!  treat-zero-bounds-as-general                      F
!  treat-separable-as-general                        F
!  just-find-feasible-point                          F
!  balance-initial-complentarity                     F
!  get-advanced-dual-variables                       F
!  puiseux-series                                    T
!  try-every-order-of-series                         T
!  move-final-solution-onto-bound                    F
!  cross-over-solution                               T
!  array-syntax-worse-than-do-loop                   F
!  space-critical                                    F
!  deallocate-error-fatal                            F
!  generate-sif-file                                 F
!  generate-qplib-file                               F
!  sif-file-name                                     CCQPPROB.SIF
!  qplib-file-name                                   CCQPPROB.qplib
!  output-line-prefix                                ""
! END CCQP SPECIFICATIONS (DEFAULT)

!  Dummy arguments

      TYPE ( CCQP_control_type ), INTENT( INOUT ) :: control
      INTEGER, INTENT( IN ) :: device
      CHARACTER( LEN = * ), OPTIONAL :: alt_specname

!  Programming: Nick Gould and Ph. Toint, January 2002.

!  Local variables

      INTEGER, PARAMETER :: error = 1
      INTEGER, PARAMETER :: out = error + 1
      INTEGER, PARAMETER :: print_level = out + 1
      INTEGER, PARAMETER :: start_print = print_level + 1
      INTEGER, PARAMETER :: stop_print = start_print + 1
      INTEGER, PARAMETER :: maxit = stop_print + 1
      INTEGER, PARAMETER :: infeas_max = maxit + 1
      INTEGER, PARAMETER :: muzero_fixed = infeas_max + 1
      INTEGER, PARAMETER :: restore_problem = muzero_fixed + 1
      INTEGER, PARAMETER :: indicator_type = restore_problem + 1
      INTEGER, PARAMETER :: arc = indicator_type + 1
      INTEGER, PARAMETER :: series_order = arc + 1
      INTEGER, PARAMETER :: sif_file_device = series_order + 1
      INTEGER, PARAMETER :: qplib_file_device = sif_file_device + 1
      INTEGER, PARAMETER :: infinity = qplib_file_device + 1
      INTEGER, PARAMETER :: stop_abs_p = infinity + 1
      INTEGER, PARAMETER :: stop_rel_p = stop_abs_p + 1
      INTEGER, PARAMETER :: stop_abs_d = stop_rel_p + 1
      INTEGER, PARAMETER :: stop_rel_d = stop_abs_d + 1
      INTEGER, PARAMETER :: stop_abs_c = stop_rel_d + 1
      INTEGER, PARAMETER :: stop_rel_c = stop_abs_c + 1
      INTEGER, PARAMETER :: perturb_h = stop_rel_c + 1
      INTEGER, PARAMETER :: prfeas = perturb_h + 1
      INTEGER, PARAMETER :: dufeas = prfeas + 1
      INTEGER, PARAMETER :: muzero = dufeas + 1
      INTEGER, PARAMETER :: tau = muzero + 1
      INTEGER, PARAMETER :: gamma_c = tau + 1
      INTEGER, PARAMETER :: gamma_f = gamma_c + 1
      INTEGER, PARAMETER :: reduce_infeas = gamma_f + 1
      INTEGER, PARAMETER :: obj_unbounded = reduce_infeas + 1
      INTEGER, PARAMETER :: potential_unbounded =obj_unbounded + 1
      INTEGER, PARAMETER :: identical_bounds_tol = potential_unbounded + 1
      INTEGER, PARAMETER :: mu_lunge = identical_bounds_tol + 1
      INTEGER, PARAMETER :: indicator_tol_p = mu_lunge + 1
      INTEGER, PARAMETER :: indicator_tol_pd = indicator_tol_p + 1
      INTEGER, PARAMETER :: indicator_tol_tapia = indicator_tol_pd + 1
      INTEGER, PARAMETER :: cpu_time_limit = indicator_tol_tapia + 1
      INTEGER, PARAMETER :: clock_time_limit = cpu_time_limit + 1
      INTEGER, PARAMETER :: remove_dependencies = clock_time_limit + 1
      INTEGER, PARAMETER :: treat_zero_bounds_as_general =                     &
                              remove_dependencies + 1
      INTEGER, PARAMETER :: treat_separable_as_general =                       &
                              treat_zero_bounds_as_general + 1
      INTEGER, PARAMETER :: just_feasible = treat_separable_as_general + 1
      INTEGER, PARAMETER :: getdua = just_feasible + 1
      INTEGER, PARAMETER :: puiseux = getdua + 1
      INTEGER, PARAMETER :: every_order = puiseux + 1
      INTEGER, PARAMETER :: feasol = every_order + 1
      INTEGER, PARAMETER :: balance_initial_complentarity = feasol + 1
      INTEGER, PARAMETER :: crossover = balance_initial_complentarity + 1
      INTEGER, PARAMETER :: space_critical = crossover + 1
      INTEGER, PARAMETER :: deallocate_error_fatal = space_critical + 1
      INTEGER, PARAMETER :: generate_sif_file = deallocate_error_fatal + 1
      INTEGER, PARAMETER :: generate_qplib_file = generate_sif_file + 1
      INTEGER, PARAMETER :: sif_file_name = generate_qplib_file + 1
      INTEGER, PARAMETER :: qplib_file_name = sif_file_name + 1
      INTEGER, PARAMETER :: prefix = qplib_file_name + 1
      INTEGER, PARAMETER :: lspec = prefix
      CHARACTER( LEN = 3 ), PARAMETER :: specname = 'CCQP'
      TYPE ( SPECFILE_item_type ), DIMENSION( lspec ) :: spec

!  Define the keywords

!  Integer key-words

      spec( error )%keyword = 'error-printout-device'
      spec( out )%keyword = 'printout-device'
      spec( print_level )%keyword = 'print-level'
      spec( start_print )%keyword = 'start-print'
      spec( stop_print )%keyword = 'stop-print'
      spec( maxit )%keyword = 'maximum-number-of-iterations'
      spec( infeas_max )%keyword = 'maximum-poor-iterations-before-infeasible'
      spec( muzero_fixed )%keyword = 'barrier-fixed-until-iteration'
      spec( restore_problem )%keyword = 'restore-problem-on-output'
      spec( indicator_type )%keyword = 'indicator-type-used'
      spec( arc )%keyword = 'arc-used'
      spec( series_order )%keyword = 'series-order'
      spec( sif_file_device )%keyword = 'sif-file-device'
      spec( qplib_file_device )%keyword = 'qplib-file-device'

!  Real key-words

      spec( infinity )%keyword = 'infinity-value'
      spec( stop_abs_p )%keyword = 'absolute-primal-accuracy'
      spec( stop_rel_p )%keyword = 'relative-primal-accuracy'
      spec( stop_abs_d )%keyword = 'absolute-dual-accuracy'
      spec( stop_rel_d )%keyword = 'relative-dual-accuracy'
      spec( stop_abs_c )%keyword = 'absolute-complementary-slackness-accuracy'
      spec( stop_rel_c )%keyword = 'relative-complementary-slackness-accuracy'
      spec( perturb_h )%keyword = 'perturb-hessian-by'
      spec( prfeas )%keyword = 'mininum-initial-primal-feasibility'
      spec( dufeas )%keyword = 'mininum-initial-dual-feasibility'
      spec( muzero )%keyword = 'initial-barrier-parameter'
      spec( tau )%keyword = 'feasibility-vs-complementarity-weight'
      spec( gamma_c )%keyword = 'balance-complentarity-factor'
      spec( gamma_f )%keyword = 'balance-feasibility-factor'
      spec( reduce_infeas )%keyword = 'poor-iteration-tolerance'
      spec( obj_unbounded )%keyword = 'minimum-objective-before-unbounded'
      spec( potential_unbounded )%keyword = 'minimum-potential-before-unbounded'
      spec( identical_bounds_tol )%keyword = 'identical-bounds-tolerance'
      spec( mu_lunge )%keyword = 'minimum-barrier-before-final-extrapolation'
      spec( indicator_tol_p )%keyword = 'primal-indicator-tolerance'
      spec( indicator_tol_pd )%keyword = 'primal-dual-indicator-tolerance'
      spec( indicator_tol_tapia )%keyword = 'tapia-indicator-tolerance'
      spec( cpu_time_limit )%keyword = 'maximum-cpu-time-limit'
      spec( clock_time_limit )%keyword = 'maximum-clock-time-limit'

!  Logical key-words

      spec( remove_dependencies )%keyword = 'remove-linear-dependencies'
      spec( treat_zero_bounds_as_general )%keyword =                           &
        'treat-zero-bounds-as-general'
      spec( treat_separable_as_general )%keyword = 'treat-separable-as-general'
      spec( just_feasible )%keyword = 'just-find-feasible-point'
      spec( getdua )%keyword = 'get-advanced-dual-variables'
      spec( puiseux )%keyword = 'puiseux-series'
      spec( every_order )%keyword = 'try-every-order-of-series'
      spec( feasol )%keyword = 'move-final-solution-onto-bound'
      spec( balance_initial_complentarity )%keyword =                          &
        'balance-initial-complentarity'
      spec( crossover )%keyword = 'cross-over-solution'
      spec( space_critical )%keyword = 'space-critical'
      spec( deallocate_error_fatal )%keyword = 'deallocate-error-fatal'
      spec( generate_sif_file )%keyword = 'generate-sif-file'
      spec( generate_qplib_file )%keyword = 'generate-qplib-file'

!  Character key-words

      spec( sif_file_name )%keyword = 'sif-file-name'
      spec( qplib_file_name )%keyword = 'qplib-file-name'
      spec( prefix )%keyword = 'output-line-prefix'

!     IF ( PRESENT( alt_specname ) ) WRITE(6,*) ' ccqp: ', alt_specname

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
     CALL SPECFILE_assign_value( spec( maxit ),                                &
                                 control%maxit,                                &
                                 control%error )
     CALL SPECFILE_assign_value( spec( infeas_max ),                           &
                                 control%infeas_max,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( muzero_fixed ),                         &
                                 control%muzero_fixed,                         &
                                 control%error )
     CALL SPECFILE_assign_value( spec( restore_problem ),                      &
                                 control%restore_problem,                      &
                                 control%error )
     CALL SPECFILE_assign_value( spec( indicator_type ),                       &
                                 control%indicator_type,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( arc ),                                  &
                                 control%arc,                                  &
                                 control%error )
     CALL SPECFILE_assign_value( spec( series_order ),                         &
                                 control%series_order,                         &
                                 control%error )
     CALL SPECFILE_assign_value( spec( sif_file_device ),                      &
                                 control%sif_file_device,                      &
                                 control%error )
     CALL SPECFILE_assign_value( spec( qplib_file_device ),                    &
                                 control%qplib_file_device,                    &
                                 control%error )

!  Set real values

     CALL SPECFILE_assign_value( spec( infinity ),                             &
                                 control%infinity,                             &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_abs_p ),                           &
                                 control%stop_abs_p,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_rel_p ),                           &
                                 control%stop_rel_p,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_abs_d ),                           &
                                 control%stop_abs_d,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_rel_d ),                           &
                                 control%stop_rel_d,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_abs_c ),                           &
                                 control%stop_abs_c,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( stop_rel_c ),                           &
                                 control%stop_rel_c,                           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( perturb_h ),                            &
                                 control%perturb_h,                            &
                                 control%error )
     CALL SPECFILE_assign_value( spec( prfeas ),                               &
                                 control%prfeas,                               &
                                 control%error )
     CALL SPECFILE_assign_value( spec( dufeas ),                               &
                                 control%dufeas,                               &
                                 control%error )
     CALL SPECFILE_assign_value( spec( muzero ),                               &
                                 control%muzero,                               &
                                 control%error )
     CALL SPECFILE_assign_value( spec( tau ),                                  &
                                 control%tau,                                  &
                                 control%error )
     CALL SPECFILE_assign_value( spec( gamma_c ),                              &
                                 control%gamma_c,                              &
                                 control%error )
     CALL SPECFILE_assign_value( spec( gamma_f ),                              &
                                 control%gamma_f,                              &
                                 control%error )
     CALL SPECFILE_assign_value( spec( reduce_infeas ),                        &
                                 control%reduce_infeas,                        &
                                 control%error )
     CALL SPECFILE_assign_value( spec( obj_unbounded ),                        &
                                 control%obj_unbounded,                        &
                                 control%error )
     CALL SPECFILE_assign_value( spec( potential_unbounded ),                  &
                                 control%potential_unbounded,                  &
                                 control%error )
     CALL SPECFILE_assign_value( spec( identical_bounds_tol ),                 &
                                 control%identical_bounds_tol,                 &
                                 control%error )
     CALL SPECFILE_assign_value( spec( mu_lunge ),                             &
                                 control%mu_lunge,                             &
                                 control%error )
     CALL SPECFILE_assign_value( spec( indicator_tol_p ),                      &
                                 control%indicator_tol_p,                      &
                                 control%error )
     CALL SPECFILE_assign_value( spec( indicator_tol_pd ),                     &
                                 control%indicator_tol_pd,                     &
                                 control%error )
     CALL SPECFILE_assign_value( spec( indicator_tol_tapia ),                  &
                                 control%indicator_tol_tapia,                  &
                                 control%error )
     CALL SPECFILE_assign_value( spec( cpu_time_limit ),                       &
                                 control%cpu_time_limit,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( clock_time_limit ),                     &
                                 control%clock_time_limit,                     &
                                 control%error )

!  Set logical values

     CALL SPECFILE_assign_value( spec( remove_dependencies ),                  &
                                 control%remove_dependencies,                  &
                                 control%error )
     CALL SPECFILE_assign_value( spec( treat_zero_bounds_as_general ),         &
                                 control%treat_zero_bounds_as_general,         &
                                 control%error )
     CALL SPECFILE_assign_value( spec( just_feasible ),                        &
                                 control%just_feasible,                        &
                                 control%error )
     CALL SPECFILE_assign_value( spec( treat_separable_as_general ),           &
                                 control%treat_separable_as_general,           &
                                 control%error )
     CALL SPECFILE_assign_value( spec( getdua ),                               &
                                 control%getdua,                               &
                                 control%error )
     CALL SPECFILE_assign_value( spec( puiseux ),                              &
                                 control%puiseux,                              &
                                 control%error )
     CALL SPECFILE_assign_value( spec( every_order ),                          &
                                 control%every_order,                          &
                                 control%error )
     CALL SPECFILE_assign_value( spec( feasol ),                               &
                                 control%feasol,                               &
                                 control%error )
     CALL SPECFILE_assign_value( spec( balance_initial_complentarity ),        &
                                 control%balance_initial_complentarity,        &
                                 control%error )
     CALL SPECFILE_assign_value( spec( crossover ),                            &
                                 control%crossover,                            &
                                 control%error )
     CALL SPECFILE_assign_value( spec( space_critical ),                       &
                                 control%space_critical,                       &
                                 control%error )
     CALL SPECFILE_assign_value( spec( deallocate_error_fatal ),               &
                                 control%deallocate_error_fatal,               &
                                 control%error )
     CALL SPECFILE_assign_value( spec( generate_sif_file ),                    &
                                 control%generate_sif_file,                    &
                                 control%error )
     CALL SPECFILE_assign_value( spec( generate_qplib_file ),                  &
                                 control%generate_qplib_file,                  &
                                 control%error )

!  Set character values

     CALL SPECFILE_assign_value( spec( sif_file_name ),                        &
                                 control%sif_file_name,                        &
                                 control%error )
     CALL SPECFILE_assign_value( spec( qplib_file_name ),                      &
                                 control%qplib_file_name,                      &
                                 control%error )
     CALL SPECFILE_assign_value( spec( prefix ),                               &
                                 control%prefix,                               &
                                 control%error )

!  Read the specfile for FDC

      IF ( PRESENT( alt_specname ) ) THEN
        CALL FDC_read_specfile( control%FDC_control, device,                   &
                                alt_specname = TRIM( alt_specname ) // '-FDC' )
      ELSE
        CALL FDC_read_specfile( control%FDC_control, device )
      END IF
      control%FDC_control%max_infeas = control%stop_abs_p

!  Read the specfile for SBLS

      IF ( PRESENT( alt_specname ) ) THEN
        CALL SBLS_read_specfile( control%SBLS_control, device,                 &
                                 alt_specname = TRIM( alt_specname ) // '-SBLS')
      ELSE
        CALL SBLS_read_specfile( control%SBLS_control, device )
      END IF

!  Read the specfile for FIT

      IF ( PRESENT( alt_specname ) ) THEN
        CALL FIT_read_specfile( control%FIT_control, device,                   &
                                alt_specname = TRIM( alt_specname ) // '-FIT' )
      ELSE
        CALL FIT_read_specfile( control%FIT_control, device )
      END IF

!  Read the specfile for CRO

      IF ( PRESENT( alt_specname ) ) THEN
        CALL CRO_read_specfile( control%CRO_control, device,                   &
                                alt_specname = TRIM( alt_specname ) // '-CRO' )
      ELSE
        CALL CRO_read_specfile( control%CRO_control, device )
      END IF

!  Read the specfile for ROOTS

      IF ( PRESENT( alt_specname ) ) THEN
        CALL ROOTS_read_specfile( control%ROOTS_control, device,               &
                              alt_specname = TRIM( alt_specname ) // '-ROOTS' )
      ELSE
        CALL ROOTS_read_specfile( control%ROOTS_control, device )
      END IF

      RETURN

      END SUBROUTINE CCQP_read_specfile

!-*-*-*-*-*-*-*-*-*-   C C Q P _ S O L V E  S U B R O U T I N E   -*-*-*-*-*-*-*

      SUBROUTINE CCQP_solve( prob, data, control, inform, C_stat, B_stat )

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Minimize the quadratic objective
!
!        1/2 x^T H x + g^T x + f
!
!  or the linear/separable objective
!
!        1/2 || W * ( x - x^0 ) ||_2^2 + g^T x + f
!
!  where
!
!               (c_l)_i <= (Ax)_i <= (c_u)_i , i = 1, .... , m,
!
!  and        (x_l)_i <=   x_i  <= (x_u)_i , i = 1, .... , n,
!
!  where x is a vector of n components ( x_1, .... , x_n ),
!  A is an m by n matrix, and any of the bounds (c_l)_i, (c_u)_i
!  (x_l)_i, (x_u)_i may be infinite, using a primal-dual method.
!  The subroutine is particularly appropriate when A is sparse.
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Arguments:
!
!  prob is a structure of type QPT_problem_type, whose components hold
!   information about the problem on input, and its solution on output.
!   The following components must be set:
!
!   %new_problem_structure is a LOGICAL variable, which must be set to
!    .TRUE. by the user if this is the first problem with this "structure"
!    to be solved since the last call to CCQP_initialize, and .FALSE. if
!    a previous call to a problem with the same "structure" (but different
!    numerical data) was made.
!
!   %n is an INTEGER variable, which must be set by the user to the
!    number of optimization parameters, n.  RESTRICTION: %n >= 1
!
!   %m is an INTEGER variable, which must be set by the user to the
!    number of general linear constraints, m. RESTRICTION: %m >= 0
!
!   %gradient_kind is an INTEGER variable which defines the type of linear
!    term of the objective function to be used. Possible values are
!
!     0  the linear term g will be zero, and the analytic centre of the
!        feasible region will be found if in addition %Hessian_kind is 0.
!        %G (see below) need not be set
!
!     1  each component of the linear terms g will be one.
!        %G (see below) need not be set
!
!     any other value - the gradients will be those given by %G (see below)
!
!   %Hessian_kind is an INTEGER variable which defines the type of objective
!    function to be used. Possible values are
!
!     0  all the weights will be zero, and the analytic centre of the
!        feasible region will be found. %WEIGHT (see below) need not be set
!
!     1  all the weights will be one. %WEIGHT (see below) need not be set
!
!     2  the weights will be those given by %WEIGHT (see below)
!
!    <0  the positive semi-definite Hessian H will be used
!
!   %H is a structure of type SMT_type used to hold the LOWER TRIANGULAR part
!    of H (except for the L-BFGS case). Eight storage formats are permitted:
!
!    i) sparse, co-ordinate
!
!       In this case, the following must be set:
!
!       H%type( 1 : 10 ) = TRANSFER( 'COORDINATE', H%type )
!       H%val( : )   the values of the components of H
!       H%row( : )   the row indices of the components of H
!       H%col( : )   the column indices of the components of H
!       H%ne         the number of nonzeros used to store
!                    the LOWER TRIANGULAR part of H
!
!    ii) sparse, by rows
!
!       In this case, the following must be set:
!
!       H%type( 1 : 14 ) = TRANSFER( 'SPARSE_BY_ROWS', H%type )
!       H%val( : )   the values of the components of H, stored row by row
!       H%col( : )   the column indices of the components of H
!       H%ptr( : )   pointers to the start of each row, and past the end of
!                    the last row
!
!    iii) dense, by rows
!
!       In this case, the following must be set:
!
!       H%type( 1 : 5 ) = TRANSFER( 'DENSE', H%type )
!       H%val( : )   the values of the components of H, stored row by row,
!                    with each the entries in each row in order of
!                    increasing column indicies.
!
!    iv) diagonal
!
!       In this case, the following must be set:
!
!       H%type( 1 : 8 ) = TRANSFER( 'DIAGONAL', H%type )
!       H%val( : )   the values of the diagonals of H, stored in order
!
!   v) scaled identity
!
!       In this case, the following must be set:
!
!       H%type( 1 : 15) = 'SCALED-IDENTITY'
!       H%val( 1 )  the value assigned to each diagonal of H
!
!   vi) identity
!
!       In this case, the following must be set:
!
!       H%type( 1 : 8 ) = 'IDENTITY'
!
!   vii) no Hessian
!
!       In this case, the following must be set:
!
!       H%type( 1 : 4 ) = 'ZERO' or 'NONE'
!
!   ix) L-BFGS Hessian
!
!       In this case, the following must be set:
!
!       H%type( 1 : 5 ) = 'LBFGS'
!
!       The Hessian in this case is available via the component H_lm below
!
!    On exit, the components will most likely have been reordered.
!    The output  matrix will be stored by rows, according to scheme (ii) above,
!    except for scheme (ix), for which a permutation will be set within H_lm.
!    However, if scheme (i) is used for input, the output H%row will contain
!    the row numbers corresponding to the values in H%val, and thus in this
!    case the output matrix will be available in both formats (i) and (ii).
!
!   %H_lm is a structure of type LMS_data_type, whose components hold the
!     L-BFGS Hessian. Access to this structure is via the module GALAHAD_LMS,
!     and this component needs only be set if %H%type( 1 : 5 ) = 'LBFGS.'
!
!   %WEIGHT is a REAL array, which need only be set if %Hessian_kind is larger
!    than 1. If this is so, it must be of length at least %n, and contain the
!    weights W for the objective function.
!
!   %X0 is a REAL array, which need only be set if %Hessian_kind is not 1 or 2.
!    If this is so, it must be of length at least %n, and contain the
!    weights X^0 for the objective function.
!
!   %G is a REAL array, which need only be set if %gradient_kind is not 0
!    or 1. If this is so, it must be of length at least %n, and contain the
!    linear terms g for the objective function.
!
!   %f is a REAL variable, which must be set by the user to the value of
!    the constant term f in the objective function. On exit, it may have
!    been changed to reflect variables which have been fixed.
!
!   %A is a structure of type SMT_type used to hold the matrix A.
!    Three storage formats are permitted:
!
!    i) sparse, co-ordinate
!
!       In this case, the following must be set:
!
!       A%type( 1 : 10 ) = TRANSFER( 'COORDINATE', A%type )
!       A%val( : )   the values of the components of A
!       A%row( : )   the row indices of the components of A
!       A%col( : )   the column indices of the components of A
!       A%ne         the number of nonzeros used to store A
!
!    ii) sparse, by rows
!
!       In this case, the following must be set:
!
!       A%type( 1 : 14 ) = TRANSFER( 'SPARSE_BY_ROWS', A%type )
!       A%val( : )   the values of the components of A, stored row by row
!       A%col( : )   the column indices of the components of A
!       A%ptr( : )   pointers to the start of each row, and past the end of
!                    the last row
!
!    iii) dense, by rows
!
!       In this case, the following must be set:
!
!       A%type( 1 : 5 ) = TRANSFER( 'DENSE', A%type )
!       A%val( : )   the values of the components of A, stored row by row,
!                    with each the entries in each row in order of
!                    increasing column indicies.
!
!    On exit, the components will most likely have been reordered.
!    The output  matrix will be stored by rows, according to scheme (ii) above.
!    However, if scheme (i) is used for input, the output A%row will contain
!    the row numbers corresponding to the values in A%val, and thus in this
!    case the output matrix will be available in both formats (i) and (ii).
!
!   %C is a REAL array of length %m, which is used to store the values of
!    A x. It need not be set on entry. On exit, it will have been filled
!    with appropriate values.
!
!   %X is a REAL array of length %n, which must be set by the user
!    to estimaes of the solution, x. On successful exit, it will contain
!    the required solution, x.
!
!   %C_l, %C_u are REAL arrays of length %n, which must be set by the user
!    to the values of the arrays c_l and c_u of lower and upper bounds on A x.
!    Any bound c_l_i or c_u_i larger than or equal to control%infinity in
!    absolute value will be regarded as being infinite (see the entry
!    control%infinity). Thus, an infinite lower bound may be specified by
!    setting the appropriate component of %C_l to a value smaller than
!    -control%infinity, while an infinite upper bound can be specified by
!    setting the appropriate element of %C_u to a value larger than
!    control%infinity. On exit, %C_l and %C_u will most likely have been
!    reordered.
!
!   %Y is a REAL array of length %m, which must be set by the user to
!    appropriate estimates of the values of the Lagrange multipliers
!    corresponding to the general constraints c_l <= A x <= c_u.
!    On successful exit, it will contain the required vector of Lagrange
!    multipliers.
!
!   %X_l, %X_u are REAL arrays of length %n, which must be set by the user
!    to the values of the arrays x_l and x_u of lower and upper bounds on x.
!    Any bound x_l_i or x_u_i larger than or equal to control%infinity in
!    absolute value will be regarded as being infinite (see the entry
!    control%infinity). Thus, an infinite lower bound may be specified by
!    setting the appropriate component of %X_l to a value smaller than
!    -control%infinity, while an infinite upper bound can be specified by
!    setting the appropriate element of %X_u to a value larger than
!    control%infinity. On exit, %X_l and %X_u will most likely have been
!    reordered.
!
!   %Z is a REAL array of length %n, which must be set by the user to
!    appropriate estimates of the values of the dual variables
!    (Lagrange multipliers corresponding to the simple bound constraints
!    x_l <= x <= x_u). On successful exit, it will contain
!   the required vector of dual variables.
!
!  data is a structure of type CCQP_data_type which holds private internal data
!
!  control is a structure of type CCQP_control_type that controls the
!   execution of the subroutine and must be set by the user. Default values for
!   the elements may be set by a call to CCQP_initialize. See the preamble
!   for details
!
!  inform is a structure of type CCQP_inform_type that provides
!    information on exit from CCQP_solve. The component status
!    has possible values:
!
!     0 Normal termination with a locally optimal solution.
!
!    -1 An allocation error occured; the status is given in the component
!       alloc_status.
!
!    -2 A deallocation error occured; the status is given in the component
!       alloc_status.
!
!   - 3 one of the restrictions
!        prob%n     >=  1
!        prob%m     >=  0
!        prob%A%type in { 'DENSE', 'SPARSE_BY_ROWS', 'COORDINATE' }
!       has been violated.
!
!    -4 The constraints are inconsistent.
!
!    -5 The constraints appear to have no feasible point.
!
!    -7 The objective function appears to be unbounded from below on the
!       feasible set.
!
!    -8 The analytic center appears to be unbounded.
!
!    -9 The analysis phase of the factorization failed; the return status
!       from the factorization package is given in the component factor_status.
!
!   -10 The factorization failed; the return status from the factorization
!       package is given in the component factor_status.
!
!   -11 The solve of a required linear system failed; the return status from
!       the factorization package is given in the component factor_status.
!
!   -16 The problem is so ill-conditoned that further progress is impossible.
!
!   -17 The step is too small to make further impact.
!
!   -18 Too many iterations have been performed. This may happen if
!       control%maxit is too small, but may also be symptomatic of
!       a badly scaled problem.
!
!   -19 Too much time has passed. This may happen if control%cpu_time_limit or
!       control%clock_time_limit is too small, but may also be symptomatic of
!       a badly scaled problem.
!
!  On exit from CCQP_solve, other components of inform are given in the preamble
!
!  C_stat is an optional INTEGER array of length m, which if present will be
!   set on exit to indicate the likely ultimate status of the constraints.
!   Possible values are
!   C_stat( i ) < 0, the i-th constraint is likely in the active set,
!                    on its lower bound,
!               > 0, the i-th constraint is likely in the active set
!                    on its upper bound, and
!               = 0, the i-th constraint is likely not in the active set
!
!  B_stat is an optional  INTEGER array of length n, which if present will be
!   set on exit to indicate the likely ultimate status of the simple bound
!   constraints. Possible values are
!   B_stat( i ) < 0, the i-th bound constraint is likely in the active set,
!                    on its lower bound,
!               > 0, the i-th bound constraint is likely in the active set
!                    on its upper bound, and
!               = 0, the i-th bound constraint is likely not in the active set
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( QPT_problem_type ), INTENT( INOUT ) :: prob
      TYPE ( CCQP_data_type ), INTENT( INOUT ) :: data
      TYPE ( CCQP_control_type ), INTENT( IN ) :: control
      TYPE ( CCQP_inform_type ), INTENT( OUT ) :: inform
      INTEGER, INTENT( OUT ), OPTIONAL, DIMENSION( prob%m ) :: C_stat
      INTEGER, INTENT( OUT ), OPTIONAL, DIMENSION( prob%n ) :: B_stat

!  Local variables

      INTEGER :: i, j, l, n_depen, nzc
      REAL :: time_start, time_record, time_now
      REAL ( KIND = wp ) :: time_analyse, time_factorize
      REAL ( KIND = wp ) :: clock_start, clock_record, clock_now
      REAL ( KIND = wp ) :: clock_analyse, clock_factorize, cro_clock_matrix
      REAL ( KIND = wp ) :: av_bnd
!     REAL ( KIND = wp ) :: fixed_sum, xi
      LOGICAL :: printi, printa, remap_freed, reset_bnd, stat_required
      LOGICAL :: separable_bqp, lbfgs
      CHARACTER ( LEN = 80 ) :: array_name

!  functions

!$    INTEGER :: OMP_GET_MAX_THREADS

!  prefix for all output

      CHARACTER ( LEN = LEN( TRIM( control%prefix ) ) - 2 ) :: prefix
      IF ( LEN( TRIM( control%prefix ) ) > 2 )                                 &
        prefix = control%prefix( 2 : LEN( TRIM( control%prefix ) ) - 1 )

      IF ( control%out > 0 .AND. control%print_level >= 5 )                    &
        WRITE( control%out, "( A, ' entering CCQP_solve ' )" ) prefix

! -------------------------------------------------------------------
!  If desired, generate a SIF file for problem passed

      IF ( control%generate_sif_file ) THEN
        CALL QPD_SIF( prob, control%sif_file_name, control%sif_file_device,    &
                      control%infinity, .TRUE. )
      END IF

!  SIF file generated
! -------------------------------------------------------------------

! -------------------------------------------------------------------
!  If desired, generate a QPLIB file for problem passed

      IF ( control%generate_qplib_file ) THEN
        CALL RPD_write_qp_problem_data( prob, control%qplib_file_name,         &
                    control%qplib_file_device, inform%rpd_inform )
      END IF

!  QPLIB file generated
! -------------------------------------------------------------------

!  initialize time

      CALL CPU_TIME( time_start ) ; CALL CLOCK_time( clock_start )

!  initialize counts

      inform%status = GALAHAD_ok
      inform%alloc_status = 0 ; inform%bad_alloc = ''
      inform%factorization_status = 0
      inform%iter = - 1 ; inform%nfacts = - 1 ; inform%nbacts = 0
      inform%factorization_integer = - 1 ; inform%factorization_real = - 1
      inform%obj = - one ; inform%potential = infinity
      inform%non_negligible_pivot = zero
      inform%feasible = .FALSE.
!$    inform%threads = OMP_GET_MAX_THREADS( )
      stat_required = PRESENT( C_stat ) .AND. PRESENT( B_stat )
      cro_clock_matrix = 0.0_wp

!  basic single line of output per iteration

      printi = control%out > 0 .AND. control%print_level >= 1
      printa = control%out > 0 .AND. control%print_level >= 101

!  ensure that input parameters are within allowed ranges

      IF ( prob%n < 1 .OR. prob%m < 0 .OR.                                     &
           .NOT. QPT_keyword_A( prob%A%type ) ) THEN
        inform%status = GALAHAD_error_restrictions
        IF ( control%error > 0 .AND. control%print_level > 0 )                 &
          WRITE( control%error, 2010 ) prefix, inform%status
        GO TO 800
      END IF

!  if required, write out problem

      IF ( prob%Hessian_kind < 0 ) THEN
        lbfgs = SMT_get( prob%H%type ) == 'LBFGS'
      ELSE
        lbfgs = .FALSE.
      END IF
      IF ( control%out > 0 .AND. control%print_level >= 20 )                   &
        CALL QPT_summarize_problem( control%out, prob )

!  check that problem bounds are consistent; reassign any pair of bounds
!  that are "essentially" the same

      reset_bnd = .FALSE.
      DO i = 1, prob%n
        IF ( prob%X_l( i ) - prob%X_u( i ) > control%identical_bounds_tol ) THEN
          inform%status = GALAHAD_error_bad_bounds
          IF ( control%error > 0 .AND. control%print_level > 0 )               &
            WRITE( control%error, 2010 ) prefix, inform%status
          GO TO 800
        ELSE IF ( prob%X_u( i ) == prob%X_l( i )  ) THEN
        ELSE IF ( prob%X_u( i ) - prob%X_l( i )                                &
                  <= control%identical_bounds_tol ) THEN
          av_bnd = half * ( prob%X_l( i ) + prob%X_u( i ) )
          prob%X_l( i ) = av_bnd ; prob%X_u( i ) = av_bnd
          reset_bnd = .TRUE.
        END IF
      END DO
      IF ( reset_bnd .AND. printi ) WRITE( control%out,                        &
        "( /, A, '   **  Warning: one or more variable bounds reset ' )" )     &
         prefix

      reset_bnd = .FALSE.
      DO i = 1, prob%m
        IF ( prob%C_l( i ) - prob%C_u( i ) > control%identical_bounds_tol ) THEN
          inform%status = GALAHAD_error_bad_bounds
          IF ( control%error > 0 .AND. control%print_level > 0 )               &
            WRITE( control%error, 2010 ) prefix, inform%status
          GO TO 800
        ELSE IF ( prob%C_u( i ) == prob%C_l( i ) ) THEN
        ELSE IF ( prob%C_u( i ) - prob%C_l( i )                                &
                  <= control%identical_bounds_tol ) THEN
          av_bnd = half * ( prob%C_l( i ) + prob%C_u( i ) )
          prob%C_l( i ) = av_bnd ; prob%C_u( i ) = av_bnd
          reset_bnd = .TRUE.
        END IF
      END DO
      IF ( reset_bnd .AND. printi ) WRITE( control%out,                        &
        "( A, /, '   **  Warning: one or more constraint bounds reset ' )" )   &
          prefix

!  ===========================
!  Preprocess the problem data
!  ===========================

      IF ( data%save_structure ) THEN
        data%new_problem_structure = prob%new_problem_structure
        data%save_structure = .FALSE.
      END IF

      IF ( prob%new_problem_structure ) THEN

!  store the problem dimensions

        SELECT CASE ( SMT_get( prob%A%type ) )
        CASE ( 'DENSE' )
          data%a_ne = prob%m * prob%n
        CASE ( 'SPARSE_BY_ROWS' )
          data%a_ne = prob%A%ptr( prob%m + 1 ) - 1
        CASE ( 'COORDINATE' )
          data%a_ne = prob%A%ne
        END SELECT

        IF ( prob%Hessian_kind < 0 ) THEN
          SELECT CASE ( SMT_get( prob%H%type ) )
          CASE ( 'NONE', 'ZERO', 'IDENTITY' )
            data%h_ne = 0
          CASE ( 'SCALED_IDENTITY' )
            data%h_ne = 1
          CASE ( 'DIAGONAL' )
            data%h_ne = prob%n
          CASE ( 'DENSE' )
            data%h_ne = ( prob%n * ( prob%n + 1 ) ) / 2
          CASE ( 'SPARSE_BY_ROWS' )
            data%h_ne = prob%H%ptr( prob%n + 1 ) - 1
          CASE ( 'COORDINATE' )
            data%h_ne = prob%H%ne
          CASE ( 'LBFGS' )
            data%h_ne = 0
          END SELECT
        END IF
      END IF

!  if the problem has no general constraints, check to see if it is separable

      IF ( data%a_ne <= 0 ) THEN
        separable_bqp = .TRUE.
        IF ( prob%Hessian_kind < 0 ) THEN
          SELECT CASE ( SMT_get( prob%H%type ) )
          CASE ( 'NONE', 'ZERO', 'IDENTITY', 'SCALED_IDENTITY', 'DIAGONAL' )
          CASE ( 'DENSE' )
            l = 0
            DO i = 1, prob%n
              DO j = 1, i
                l = l + 1
                IF ( i /= j .AND. prob%H%val( l ) /= zero ) THEN
                  separable_bqp = .FALSE. ; GO TO 10
                END IF
              END DO
            END DO
          CASE ( 'SPARSE_BY_ROWS' )
            DO i = 1, prob%n
              DO l = prob%H%ptr( i ), prob%H%ptr( i + 1 ) - 1
                j = prob%H%col( l )
                IF ( i /= j .AND. prob%H%val( l ) /= zero ) THEN
                  separable_bqp = .FALSE. ; GO TO 10
                END IF
              END DO
            END DO
          CASE ( 'COORDINATE' )
            DO l = 1, prob%H%ne
              i = prob%H%row( l ) ; j = prob%H%col( l )
              IF ( i /= j .AND. prob%H%val( l ) /= zero ) THEN
                separable_bqp = .FALSE. ; GO TO 10
              END IF
            END DO
          CASE ( 'LBFGS' )
            separable_bqp = .FALSE.
          END SELECT
        END IF
 10     CONTINUE

!  the problem is a separable bound-constrained QP. Solve it explicitly

        IF ( control%treat_separable_as_general ) separable_bqp = .FALSE.
        IF ( separable_bqp ) THEN
          IF ( printi ) WRITE( control%out,                                    &
            "( /, A, ' Solving separable bound-constrained QP -' )" ) prefix
          IF ( PRESENT( B_stat ) ) THEN
            CALL QPD_solve_separable_BQP( prob, control%infinity,              &
                                          control%obj_unbounded,  inform%obj,  &
                                          inform%feasible, inform%status,      &
                                          B_stat = B_stat( : prob%n ) )
          ELSE
            CALL QPD_solve_separable_BQP( prob, control%infinity,              &
                                          control%obj_unbounded,  inform%obj,  &
                                          inform%feasible, inform%status )
          END IF
          IF ( printi ) THEN
            CALL CLOCK_time( clock_now )
            WRITE( control%out,                                                &
               "( A, ' On exit from QPD_solve_separable_BQP: status = ',       &
            &   I0, ', time = ', F0.2, /, A, ' objective value =', ES12.4 )",  &
              advance = 'no' ) prefix, inform%status, inform%time%clock_total  &
                + clock_now - clock_start, prefix, inform%obj
            IF ( PRESENT( B_stat ) ) THEN
              WRITE( control%out, "( ', active bounds: ', I0, ' from ', I0 )" )&
                COUNT( B_stat( : prob%n ) /= 0 ), prob%n
            ELSE
              WRITE( control%out, "( '' )" )
            END IF
          END IF
          inform%iter = 0 ; inform%non_negligible_pivot = zero
          inform%factorization_integer = 0 ; inform%factorization_real = 0

          IF ( printi ) then
            SELECT CASE( inform%status )
              CASE( GALAHAD_error_restrictions  ) ; WRITE( control%out,        &
                "( /, A, '  Warning - input paramters incorrect' )" ) prefix
              CASE( GALAHAD_error_primal_infeasible ) ; WRITE( control%out,    &
                "( /, A, '  Warning - the constraints appear to be',           &
               &   ' inconsistent' )" ) prefix
              CASE( GALAHAD_error_unbounded ) ; WRITE( control%out,            &
                "( /, A, '  Warning - problem appears to be unbounded from',   &
               & ' below' )") prefix
            END SELECT
          END IF
          IF ( inform%status /= GALAHAD_ok ) RETURN
          GO TO 800
        END IF
      END IF

!  perform the preprocessing

      IF ( prob%new_problem_structure ) THEN
        IF ( printi ) THEN
          IF ( prob%m > 0 ) THEN
            WRITE( control%out,                                                &
               "(  A, ' problem dimensions before preprocessing: ', /,  A,     &
           &   ' n = ', I0, ' m = ', I0, ' a_ne = ', I0, ' h_ne = ', I0 )" )   &
               prefix, prefix, prob%n, prob%m, data%a_ne, data%h_ne
          ELSE
            WRITE( control%out,                                                &
               "(  A, ' problem dimensions before preprocessing:',             &
           &   ' n = ', I0, ' h_ne = ', I0 )" ) prefix, prob%n, data%h_ne
          END IF
        END IF

        CALL QPP_initialize( data%QPP_map, data%QPP_control )
        data%QPP_control%infinity = control%infinity
        data%QPP_control%treat_zero_bounds_as_general =                        &
          control%treat_zero_bounds_as_general

        CALL CPU_TIME( time_record ) ; CALL CLOCK_time( clock_record )
        CALL QPP_reorder( data%QPP_map, data%QPP_control,                      &
                          data%QPP_inform, data%dims, prob,                    &
                          .FALSE., .FALSE., .FALSE. )
        CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
        inform%time%preprocess = inform%time%preprocess + time_now - time_record
        inform%time%clock_preprocess =                                         &
          inform%time%clock_preprocess + clock_now - clock_record

!  test for satisfactory termination

        IF ( data%QPP_inform%status /= GALAHAD_ok ) THEN
          inform%status = data%QPP_inform%status
          IF ( control%out > 0 .AND. control%print_level >= 5 )                &
            WRITE( control%out, "( A, ' status ', I0, ' after QPP_reorder')" ) &
             prefix, data%QPP_inform%status
          IF ( control%error > 0 .AND. control%print_level > 0 )               &
            WRITE( control%error, 2010 ) prefix, inform%status
          CALL QPP_terminate( data%QPP_map, data%QPP_control, data%QPP_inform )
          GO TO 800
        END IF

!  record array lengths

        SELECT CASE ( SMT_get( prob%A%type ) )
        CASE ( 'DENSE' )
          data%a_ne = prob%m * prob%n
        CASE ( 'SPARSE_BY_ROWS' )
          data%a_ne = prob%A%ptr( prob%m + 1 ) - 1
        CASE ( 'COORDINATE' )
          data%a_ne = prob%A%ne
        END SELECT

        IF ( prob%Hessian_kind < 0 ) THEN
          SELECT CASE ( SMT_get( prob%H%type ) )
          CASE ( 'NONE', 'ZERO', 'IDENTITY' )
            data%h_ne = 0
          CASE ( 'SCALED_IDENTITY' )
            data%h_ne = 1
          CASE ( 'DIAGONAL' )
            data%h_ne = prob%n
          CASE ( 'DENSE' )
            data%h_ne = ( prob%n * ( prob%n + 1 ) ) / 2
          CASE ( 'SPARSE_BY_ROWS' )
            data%h_ne = prob%H%ptr( prob%n + 1 ) - 1
          CASE ( 'COORDINATE' )
            data%h_ne = prob%H%ne
          CASE ( 'LBFGS' )
            data%h_ne = 0
          END SELECT
        END IF

        IF ( printi ) THEN
          IF ( prob%m > 0 ) THEN
            WRITE( control%out,                                                &
               "(  A, ' problem dimensions after preprocessing: ', /,  A,      &
           &   ' n = ', I0, ' m = ', I0, ' a_ne = ', I0, ' h_ne = ', I0 )" )   &
               prefix, prefix, prob%n, prob%m, data%a_ne, data%h_ne
          ELSE
            WRITE( control%out,                                                &
               "(  A, ' problem dimensions after  preprocessing:',             &
           &   ' n = ', I0, ' h_ne = ', I0 )" ) prefix, prob%n, data%h_ne
          END IF
        END IF

        prob%new_problem_structure = .FALSE.
        data%trans = 1

!  recover the problem dimensions after preprocessing

      ELSE
        IF ( data%trans == 0 ) THEN
          CALL CPU_TIME( time_record ) ; CALL CLOCK_time( clock_record )
          CALL QPP_apply( data%QPP_map, data%QPP_inform,                       &
                          prob, get_all = .TRUE. )
          CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
          inform%time%preprocess =                                             &
            inform%time%preprocess + time_now - time_record
          inform%time%clock_preprocess =                                       &
            inform%time%clock_preprocess + clock_now - clock_record

!  test for satisfactory termination

          IF ( data%QPP_inform%status /= GALAHAD_ok ) THEN
            inform%status = data%QPP_inform%status
            IF ( control%out > 0 .AND. control%print_level >= 5 )              &
              WRITE( control%out, "( A, ' status ', I0, ' after QPP_apply')" ) &
               prefix, data%QPP_inform%status
            IF ( control%error > 0 .AND. control%print_level > 0 )             &
              WRITE( control%error, 2010 ) prefix, inform%status
            CALL QPP_terminate( data%QPP_map, data%QPP_control, data%QPP_inform)
            GO TO 800
          END IF
        END IF
        data%trans = data%trans + 1
      END IF

!  =================================================================
!  Check to see if the equality constraints are linearly independent
!  =================================================================

      time_analyse = inform%FDC_inform%time%analyse
      clock_analyse = inform%FDC_inform%time%clock_analyse
      time_factorize = inform%FDC_inform%time%factorize
      clock_factorize = inform%FDC_inform%time%clock_factorize

      IF ( prob%m > 0 .AND.                                                    &
           ( .NOT. data%tried_to_remove_deps .AND.                             &
              control%remove_dependencies ) ) THEN
        IF ( control%out > 0 .AND. control%print_level >= 1 )                  &
          WRITE( control%out,                                                  &
           "( /, A, 1X, I0, ' equalit', A, ' from ', I0, ' constraint', A )" ) &
              prefix, data%dims%c_equality,                                    &
              TRIM( STRING_ies( data%dims%c_equality ) ),                      &
              prob%m, TRIM( STRING_pleural( prob%m ) )

!  set control parameters

        data%FDC_control = control%FDC_control
        data%FDC_control%max_infeas = control%stop_abs_p

!  find any dependent rows

        nzc = prob%A%ptr( data%dims%c_equality + 1 ) - 1
        CALL CPU_TIME( time_record ) ; CALL CLOCK_time( clock_record )
        CALL FDC_find_dependent( prob%n, data%dims%c_equality,                 &
                                 prob%A%val( : nzc ),                          &
                                 prob%A%col( : nzc ),                          &
                                 prob%A%ptr( : data%dims%c_equality + 1 ),     &
                                 prob%C_l, n_depen, data%Index_C_freed,        &
                                 data%FDC_data, data%FDC_control,              &
                                 inform%FDC_inform )
        CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
        inform%time%find_dependent =                                           &
          inform%time%find_dependent + time_now - time_record
        inform%time%clock_find_dependent =                                     &
          inform%time%clock_find_dependent + clock_now - clock_record

!  record output parameters

        inform%status = inform%FDC_inform%status
        inform%non_negligible_pivot = inform%FDC_inform%non_negligible_pivot
        inform%alloc_status = inform%FDC_inform%alloc_status
        inform%factorization_status = inform%FDC_inform%factorization_status
        inform%factorization_integer = inform%FDC_inform%factorization_integer
        inform%factorization_real = inform%FDC_inform%factorization_real
        inform%bad_alloc = inform%FDC_inform%bad_alloc
        inform%nfacts = 1

        IF ( ( control%cpu_time_limit >= zero .AND.                            &
             REAL( time_now - time_start, wp ) > control%cpu_time_limit ) .OR. &
             ( control%clock_time_limit >= zero .AND.                          &
               clock_now - clock_start > control%clock_time_limit ) ) THEN
          inform%status = GALAHAD_error_cpu_limit
          IF ( control%error > 0 .AND. control%print_level > 0 )               &
            WRITE( control%error, 2010 ) prefix, inform%status
          GO TO 800
        END IF

        IF ( printi .AND. inform%non_negligible_pivot < thousand *             &
          control%FDC_control%SLS_control%absolute_pivot_tolerance )           &
            WRITE( control%out, "(                                             &
       &  /, A, 1X, 26 ( '*' ), ' WARNING ', 26 ( '*' ), /, A,                 &
       &  ' ***  smallest allowed pivot =', ES11.4,' may be too small ***',    &
       &  /, A, ' ***  perhaps increase',                                      &
       &     ' FDC_control%SLS_control%absolute_pivot_tolerance from',         &
       &    ES11.4,'  ***', /, A, 1X, 26 ( '*' ), ' WARNING ', 26 ('*') )" )   &
           prefix, prefix, inform%non_negligible_pivot, prefix,                &
           control%FDC_control%SLS_control%absolute_pivot_tolerance, prefix

!  check for error exits

        IF ( inform%status /= 0 ) THEN

!  print details of the error exit

          IF ( control%error > 0 .AND. control%print_level >= 1 ) THEN
            WRITE( control%out, "( ' ' )" )
            IF ( inform%status /= GALAHAD_ok ) WRITE( control%error,           &
                 "( A, '    ** Error return ', I0, ' from ', A )" )            &
               prefix, inform%status, 'FDC_dependent'
          END IF
          GO TO 700
        END IF

        IF ( control%out > 0 .AND. control%print_level >= 2 .AND. n_depen > 0 )&
          WRITE( control%out, "(/, A, ' The following ', I0, ' constraint',    &
         &  A, ' appear', A, ' to be dependent', /, ( 4X, 8I8 ) )" )           &
              prefix, n_depen, TRIM(STRING_pleural( n_depen ) ),               &
              TRIM( STRING_verb_pleural( n_depen ) ), data%Index_C_freed

        remap_freed = n_depen > 0 .AND. prob%n > 0

!  special case: no free variables

        IF ( prob%n == 0 ) THEN
          prob%Y( : prob%m ) = zero
          prob%Z( : prob%n ) = zero
          prob%C( : prob%m ) = zero
          CALL CCQP_AX( prob%m, prob%C( : prob%m ), prob%m,                    &
                       prob%A%ptr( prob%m + 1 ) - 1, prob%A%val,               &
                       prob%A%col, prob%A%ptr, prob%n, prob%X, '+ ')
          GO TO 700
        END IF
        data%tried_to_remove_deps = .TRUE.
      ELSE
        remap_freed = .FALSE.
      END IF

      IF ( remap_freed ) THEN

!  some of the current constraints will be removed by freeing them

        IF ( control%error > 0 .AND. control%print_level >= 1 )                &
          WRITE( control%out, "( /, A, ' -> ', I0, ' constraint', A, ' ', A,   &
         & ' dependent and will be temporarily removed' )" ) prefix, n_depen,  &
           TRIM( STRING_pleural( n_depen ) ), TRIM( STRING_are( n_depen ) )

!  allocate arrays to indicate which constraints have been freed

          array_name = 'ccqp: data%C_freed'
          CALL SPACE_resize_array( n_depen, data%C_freed,                      &
                 inform%status, inform%alloc_status, array_name = array_name,  &
                 deallocate_error_fatal = control%deallocate_error_fatal,      &
                 exact_size = control%space_critical,                          &
                 bad_alloc = inform%bad_alloc, out = control%error )
          IF ( inform%status /= GALAHAD_ok ) GO TO 900

!  free the constraint bounds as required

        DO i = 1, n_depen
          j = data%Index_c_freed( i )
          data%C_freed( i ) = prob%C_l( j )
          prob%C_l( j ) = - control%infinity
          prob%C_u( j ) = control%infinity
          prob%Y( j ) = zero
        END DO

        CALL QPP_initialize( data%QPP_map_freed, data%QPP_control )
        data%QPP_control%infinity = control%infinity
        data%QPP_control%treat_zero_bounds_as_general =                        &
          control%treat_zero_bounds_as_general

!  store the problem dimensions

        data%dims_save_freed = data%dims
        data%a_ne = prob%A%ne

        IF ( printi ) WRITE( control%out,                                      &
               "( /, A, ' problem dimensions before removal of dependecies: ', &
              &   /, A, ' n = ', I8, ' m = ', I8, ' a_ne = ', I8 )" )          &
               prefix, prefix, prob%n, prob%m, data%a_ne

!  perform the preprocessing

        CALL CPU_TIME( time_record )  ; CALL CLOCK_time( clock_record )
        CALL QPP_reorder( data%QPP_map_freed, data%QPP_control,                &
                          data%QPP_inform, data%dims, prob,                    &
                          .FALSE., .FALSE., .FALSE. )
        CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
        inform%time%preprocess = inform%time%preprocess + time_now - time_record
        inform%time%clock_preprocess =                                         &
          inform%time%clock_preprocess + clock_now - clock_record

        data%dims%nc = data%dims%c_u_end - data%dims%c_l_start + 1
        data%dims%x_s = 1 ; data%dims%x_e = prob%n
        data%dims%c_s = data%dims%x_e + 1
        data%dims%c_e = data%dims%x_e + data%dims%nc
        data%dims%c_b = data%dims%c_e - prob%m
        data%dims%y_s = data%dims%c_e + 1
        data%dims%y_e = data%dims%c_e + prob%m
        data%dims%y_i = data%dims%c_s + prob%m
        data%dims%v_e = data%dims%y_e

!  test for satisfactory termination

        IF ( data%QPP_inform%status /= GALAHAD_ok ) THEN
          inform%status = data%QPP_inform%status
          IF ( control%out > 0 .AND. control%print_level >= 5 )                &
            WRITE( control%out, "( A, ' status ', I0, ' after QPP_reorder')" ) &
             prefix, data%QPP_inform%status
          IF ( control%error > 0 .AND. control%print_level > 0 )               &
            WRITE( control%error, 2010 ) prefix, inform%status
          CALL QPP_terminate( data%QPP_map_freed, data%QPP_control,            &
                              data%QPP_inform )
          CALL QPP_terminate( data%QPP_map, data%QPP_control, data%QPP_inform )
          GO TO 800
        END IF

!  record revised array lengths

        IF ( SMT_get( prob%A%type ) == 'DENSE' ) THEN
          data%a_ne = prob%m * prob%n
        ELSE IF ( SMT_get( prob%A%type ) == 'SPARSE_BY_ROWS' ) THEN
          data%a_ne = prob%A%ptr( prob%m + 1 ) - 1
        ELSE
          data%a_ne = prob%A%ne
        END IF

        IF ( printi ) WRITE( control%out,                                      &
               "( /, A, ' problem dimensions after removal of dependencies: ', &
             &    /, A, ' n = ', I8, ' m = ', I8, ' a_ne = ', I8 )" )          &
               prefix, prefix, prob%n, prob%m, data%a_ne
      END IF

!  compute the dimension of the KKT system

      data%dims%nc = data%dims%c_u_end - data%dims%c_l_start + 1

!  arrays containing data relating to the composite vector ( x  c  y )
!  are partitioned as follows:

!   <---------- n --------->  <---- nc ------>  <-------- m --------->
!                             <-------- m --------->
!                        <-------- m --------->
!   -------------------------------------------------------------------
!   |                   |    |                 |    |                 |
!   |         x              |       c         |          y           |
!   |                   |    |                 |    |                 |
!   -------------------------------------------------------------------
!    ^                 ^    ^ ^               ^ ^    ^               ^
!    |                 |    | |               | |    |               |
!   x_s                |    |c_s              |y_s  y_i             y_e = v_e
!                      |    |                 |
!                     c_b  x_e               c_e

      data%dims%x_s = 1 ; data%dims%x_e = prob%n
      data%dims%c_s = data%dims%x_e + 1
      data%dims%c_e = data%dims%x_e + data%dims%nc
      data%dims%c_b = data%dims%c_e - prob%m
      data%dims%y_s = data%dims%c_e + 1
      data%dims%y_e = data%dims%c_e + prob%m
      data%dims%y_i = data%dims%c_s + prob%m
      data%dims%v_e = data%dims%y_e

!  ----------------
!  set up workspace
!  ----------------

      CALL CCQP_workspace( prob%m, prob%n, data%dims, data%a_ne, data%h_ne,    &
                          prob%Hessian_kind, lbfgs, stat_required, data%order, &
                          data%GRAD_L, data%DIST_X_l, data%DIST_X_u, data%Z_l, &
                          data%Z_u, data%BARRIER_X, data%Y_l, data%DIST_C_l,   &
                          data%Y_u, data%DIST_C_u, data%C, data%BARRIER_C,     &
                          data%SCALE_C, data%RHS, data%OPT_alpha,              &
                          data%OPT_merit, data%BINOMIAL, data%CS_coef,         &
                          data%COEF, data%ROOTS, data%DX_zh, data%DY_zh,       &
                          data%DC_zh, data%DY_l_zh, data%DY_u_zh,              &
                          data%DZ_l_zh, data%DZ_u_zh, data%X_coef,             &
                          data%C_coef, data%Y_coef, data%Y_l_coef,             &
                          data%Y_u_coef, data%Z_l_coef, data%Z_u_coef,         &
                          data%H_s, data%A_s, data%Y_last, data%Z_last,        &
                          data%A_sbls, data%H_sbls, control, inform )


!  =================
!  Solve the problem
!  =================

!  constraint/variable exit status required

      IF ( stat_required ) THEN
        IF ( prob%Hessian_kind == 0 ) THEN
          IF ( prob%gradient_kind == 0 .OR. prob%gradient_kind == 1 ) THEN
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 C_last = data%A_s, X_last = data%H_s,         &
                                 Y_last = data%Y_last, Z_last = data%Z_last,   &
                                 C_stat = C_stat, B_Stat = B_Stat )
          ELSE
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 G = prob%G,                                   &
                                 C_last = data%A_s, X_last = data%H_s,         &
                                 Y_last = data%Y_last, Z_last = data%Z_last,   &
                                 C_stat = C_stat, B_Stat = B_Stat )
          END IF
        ELSE IF ( prob%Hessian_kind == 1 ) THEN
          IF ( prob%gradient_kind == 0 .OR. prob%gradient_kind == 1 ) THEN
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 X0 = prob%X0,                                 &
                                 C_last = data%A_s, X_last = data%H_s,         &
                                 Y_last = data%Y_last, Z_last = data%Z_last,   &
                                 C_stat = C_stat, B_Stat = B_Stat )
          ELSE
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 X0 = prob%X0, G = prob%G,                     &
                                 C_last = data%A_s, X_last = data%H_s,         &
                                 Y_last = data%Y_last, Z_last = data%Z_last,   &
                                 C_stat = C_stat, B_Stat = B_Stat )
          END IF
        ELSE IF ( prob%Hessian_kind == 2 ) THEN
          IF ( prob%gradient_kind == 0 .OR. prob%gradient_kind == 1 ) THEN
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 WEIGHT = prob%WEIGHT, X0 = prob%X0,           &
                                 C_last = data%A_s, X_last = data%H_s,         &
                                 Y_last = data%Y_last, Z_last = data%Z_last,   &
                                 C_stat = C_stat, B_Stat = B_Stat )
          ELSE
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 WEIGHT = prob%WEIGHT, X0 = prob%X0,           &
                                 G = prob%G,                                   &
                                 C_last = data%A_s, X_last = data%H_s,         &
                                 Y_last = data%Y_last, Z_last = data%Z_last,   &
                                 C_stat = C_stat, B_Stat = B_Stat )
          END IF
        ELSE
          IF ( prob%gradient_kind == 0 .OR. prob%gradient_kind == 1 ) THEN
            IF ( lbfgs ) THEN
              CALL CCQP_solve_main( data%dims, prob%n, prob%m,                 &
                                   prob%A%val, prob%A%col, prob%A%ptr,         &
                                   prob%C_l, prob%C_u, prob%X_l, prob%X_u,     &
                                   prob%C, prob%X, prob%Y, prob%Z,             &
                                   data%GRAD_L, data%DIST_X_l, data%DIST_X_u,  &
                                   data%Z_l, data%Z_u, data%BARRIER_X,         &
                                   data%Y_l, data%DIST_C_l, data%Y_u,          &
                                   data%DIST_C_u, data%C, data%BARRIER_C,      &
                                   data%SCALE_C, data%RHS, prob%f,             &
                                   data%H_sbls, data%A_sbls, data%C_sbls,      &
                                   data%order, data%X_coef, data%C_coef,       &
                                   data%Y_coef, data%Y_l_coef, data%Y_u_coef,  &
                                   data%Z_l_coef, data%Z_u_coef,               &
                                   data%BINOMIAL, data%CS_coef, data%COEF,     &
                                   data%ROOTS, data%ROOTS_data,                &
                                   data%DX_zh, data%DC_zh,                     &
                                   data%DY_zh, data%DY_l_zh,                   &
                                   data%DY_u_zh, data%DZ_l_zh,                 &
                                   data%DZ_u_zh,                               &
                                   data%OPT_alpha, data%OPT_merit,             &
                                   data%SBLS_data, prefix,                     &
                                   control, inform,                            &
                                   prob%Hessian_kind, prob%gradient_kind,      &
                                   prob%target_kind,                           &
                                   H_lm = prob%H_lm,                           &
                                   C_last = data%A_s, X_last = data%H_s,       &
                                   Y_last = data%Y_last,                       &
                                   Z_last = data%Z_last,                       &
                                   C_stat = C_stat, B_Stat = B_Stat )
            ELSE
              CALL CCQP_solve_main( data%dims, prob%n, prob%m,                 &
                                   prob%A%val, prob%A%col, prob%A%ptr,         &
                                   prob%C_l, prob%C_u, prob%X_l, prob%X_u,     &
                                   prob%C, prob%X, prob%Y, prob%Z,             &
                                   data%GRAD_L, data%DIST_X_l, data%DIST_X_u,  &
                                   data%Z_l, data%Z_u, data%BARRIER_X,         &
                                   data%Y_l, data%DIST_C_l, data%Y_u,          &
                                   data%DIST_C_u, data%C, data%BARRIER_C,      &
                                   data%SCALE_C, data%RHS, prob%f,             &
                                   data%H_sbls, data%A_sbls, data%C_sbls,      &
                                   data%order, data%X_coef, data%C_coef,       &
                                   data%Y_coef, data%Y_l_coef, data%Y_u_coef,  &
                                   data%Z_l_coef, data%Z_u_coef,               &
                                   data%BINOMIAL, data%CS_coef, data%COEF,     &
                                   data%ROOTS, data%ROOTS_data,                &
                                   data%DX_zh, data%DC_zh,                     &
                                   data%DY_zh, data%DY_l_zh,                   &
                                   data%DY_u_zh, data%DZ_l_zh,                 &
                                   data%DZ_u_zh,                               &
                                   data%OPT_alpha, data%OPT_merit,             &
                                   data%SBLS_data, prefix,                     &
                                   control, inform,                            &
                                   prob%Hessian_kind, prob%gradient_kind,      &
                                   prob%target_kind,                           &
                                   H_val = prob%H%val, H_col = prob%H%col,     &
                                   H_ptr = prob%H%ptr,                         &
                                   C_last = data%A_s, X_last = data%H_s,       &
                                   Y_last = data%Y_last,                       &
                                   Z_last = data%Z_last,                       &
                                   C_stat = C_stat, B_Stat = B_Stat )
            END IF
          ELSE
            IF ( lbfgs ) THEN
              CALL CCQP_solve_main( data%dims, prob%n, prob%m,                 &
                                   prob%A%val, prob%A%col, prob%A%ptr,         &
                                   prob%C_l, prob%C_u, prob%X_l, prob%X_u,     &
                                   prob%C, prob%X, prob%Y, prob%Z,             &
                                   data%GRAD_L, data%DIST_X_l, data%DIST_X_u,  &
                                   data%Z_l, data%Z_u, data%BARRIER_X,         &
                                   data%Y_l, data%DIST_C_l, data%Y_u,          &
                                   data%DIST_C_u, data%C, data%BARRIER_C,      &
                                   data%SCALE_C, data%RHS, prob%f,             &
                                   data%H_sbls, data%A_sbls, data%C_sbls,      &
                                   data%order, data%X_coef, data%C_coef,       &
                                   data%Y_coef, data%Y_l_coef, data%Y_u_coef,  &
                                   data%Z_l_coef, data%Z_u_coef,               &
                                   data%BINOMIAL, data%CS_coef, data%COEF,     &
                                   data%ROOTS, data%ROOTS_data,                &
                                   data%DX_zh, data%DC_zh,                     &
                                   data%DY_zh, data%DY_l_zh,                   &
                                   data%DY_u_zh, data%DZ_l_zh,                 &
                                   data%DZ_u_zh,                               &
                                   data%OPT_alpha, data%OPT_merit,             &
                                   data%SBLS_data, prefix,                     &
                                   control, inform,                            &
                                   prob%Hessian_kind, prob%gradient_kind,      &
                                   prob%target_kind,                           &
                                   H_lm = prob%H_lm, G = prob%G,               &
                                   C_last = data%A_s, X_last = data%H_s,       &
                                   Y_last = data%Y_last,                       &
                                   Z_last = data%Z_last,                       &
                                   C_stat = C_stat, B_Stat = B_Stat )
            ELSE
              CALL CCQP_solve_main( data%dims, prob%n, prob%m,                 &
                                   prob%A%val, prob%A%col, prob%A%ptr,         &
                                   prob%C_l, prob%C_u, prob%X_l, prob%X_u,     &
                                   prob%C, prob%X, prob%Y, prob%Z,             &
                                   data%GRAD_L, data%DIST_X_l, data%DIST_X_u,  &
                                   data%Z_l, data%Z_u, data%BARRIER_X,         &
                                   data%Y_l, data%DIST_C_l, data%Y_u,          &
                                   data%DIST_C_u, data%C, data%BARRIER_C,      &
                                   data%SCALE_C, data%RHS, prob%f,             &
                                   data%H_sbls, data%A_sbls, data%C_sbls,      &
                                   data%order, data%X_coef, data%C_coef,       &
                                   data%Y_coef, data%Y_l_coef, data%Y_u_coef,  &
                                   data%Z_l_coef, data%Z_u_coef,               &
                                   data%BINOMIAL, data%CS_coef, data%COEF,     &
                                   data%ROOTS, data%ROOTS_data,                &
                                   data%DX_zh, data%DC_zh,                     &
                                   data%DY_zh, data%DY_l_zh,                   &
                                   data%DY_u_zh, data%DZ_l_zh,                 &
                                   data%DZ_u_zh,                               &
                                   data%OPT_alpha, data%OPT_merit,             &
                                   data%SBLS_data, prefix,                     &
                                   control, inform,                            &
                                   prob%Hessian_kind, prob%gradient_kind,      &
                                   prob%target_kind,                           &
                                   H_val = prob%H%val, H_col = prob%H%col,     &
                                   H_ptr = prob%H%ptr, G = prob%G,             &
                                   C_last = data%A_s, X_last = data%H_s,       &
                                   Y_last = data%Y_last,                       &
                                   Z_last = data%Z_last,                       &
                                   C_stat = C_stat, B_Stat = B_Stat )
            END IF
          END IF
        END IF

!  constraint/variable exit status not required

      ELSE
        IF ( prob%Hessian_kind == 0 ) THEN
          IF ( prob%gradient_kind == 0 .OR. prob%gradient_kind == 1 ) THEN
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind )

          ELSE
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 G = prob%G )
          END IF
        ELSE IF ( prob%Hessian_kind == 1 ) THEN
          IF ( prob%gradient_kind == 0 .OR. prob%gradient_kind == 1 ) THEN
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 X0 = prob%X0 )
          ELSE
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 X0 = prob%X0, G = prob%G )
          END IF
        ELSE IF ( prob%Hessian_kind == 1 ) THEN
          IF ( prob%gradient_kind == 0 .OR. prob%gradient_kind == 1 ) THEN
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 WEIGHT = prob%WEIGHT, X0 = prob%X0 )
          ELSE
            CALL CCQP_solve_main( data%dims, prob%n, prob%m,                   &
                                 prob%A%val, prob%A%col, prob%A%ptr,           &
                                 prob%C_l, prob%C_u, prob%X_l, prob%X_u,       &
                                 prob%C, prob%X, prob%Y, prob%Z,               &
                                 data%GRAD_L, data%DIST_X_l, data%DIST_X_u,    &
                                 data%Z_l, data%Z_u, data%BARRIER_X,           &
                                 data%Y_l, data%DIST_C_l, data%Y_u,            &
                                 data%DIST_C_u, data%C, data%BARRIER_C,        &
                                 data%SCALE_C, data%RHS, prob%f,               &
                                 data%H_sbls, data%A_sbls, data%C_sbls,        &
                                 data%order, data%X_coef, data%C_coef,         &
                                 data%Y_coef, data%Y_l_coef, data%Y_u_coef,    &
                                 data%Z_l_coef, data%Z_u_coef, data%BINOMIAL,  &
                                 data%CS_coef, data%COEF,                      &
                                 data%ROOTS, data%ROOTS_data,                  &
                                 data%DX_zh, data%DC_zh,                       &
                                 data%DY_zh, data%DY_l_zh,                     &
                                 data%DY_u_zh, data%DZ_l_zh,                   &
                                 data%DZ_u_zh,                                 &
                                 data%OPT_alpha, data%OPT_merit,               &
                                 data%SBLS_data, prefix,                       &
                                 control, inform,                              &
                                 prob%Hessian_kind, prob%gradient_kind,        &
                                 prob%target_kind,                             &
                                 WEIGHT = prob%WEIGHT, X0 = prob%X0,           &
                                 G = prob%G )
          END IF
        ELSE
          IF ( prob%gradient_kind == 0 .OR. prob%gradient_kind == 1 ) THEN
            IF ( lbfgs ) THEN
              CALL CCQP_solve_main( data%dims, prob%n, prob%m,                 &
                                   prob%A%val, prob%A%col, prob%A%ptr,         &
                                   prob%C_l, prob%C_u, prob%X_l, prob%X_u,     &
                                   prob%C, prob%X, prob%Y, prob%Z,             &
                                   data%GRAD_L, data%DIST_X_l, data%DIST_X_u,  &
                                   data%Z_l, data%Z_u, data%BARRIER_X,         &
                                   data%Y_l, data%DIST_C_l, data%Y_u,          &
                                   data%DIST_C_u, data%C, data%BARRIER_C,      &
                                   data%SCALE_C, data%RHS, prob%f,             &
                                   data%H_sbls, data%A_sbls, data%C_sbls,      &
                                   data%order, data%X_coef, data%C_coef,       &
                                   data%Y_coef, data%Y_l_coef, data%Y_u_coef,  &
                                   data%Z_l_coef, data%Z_u_coef,               &
                                   data%BINOMIAL, data%CS_coef, data%COEF,     &
                                   data%ROOTS, data%ROOTS_data,                &
                                   data%DX_zh, data%DC_zh,                     &
                                   data%DY_zh, data%DY_l_zh,                   &
                                   data%DY_u_zh, data%DZ_l_zh,                 &
                                   data%DZ_u_zh,                               &
                                   data%OPT_alpha, data%OPT_merit,             &
                                   data%SBLS_data, prefix,                     &
                                   control, inform,                            &
                                   prob%Hessian_kind, prob%gradient_kind,      &
                                   prob%target_kind,                           &
                                   H_lm = prob%H_lm )
            ELSE
              CALL CCQP_solve_main( data%dims, prob%n, prob%m,                 &
                                   prob%A%val, prob%A%col, prob%A%ptr,         &
                                   prob%C_l, prob%C_u, prob%X_l, prob%X_u,     &
                                   prob%C, prob%X, prob%Y, prob%Z,             &
                                   data%GRAD_L, data%DIST_X_l, data%DIST_X_u,  &
                                   data%Z_l, data%Z_u, data%BARRIER_X,         &
                                   data%Y_l, data%DIST_C_l, data%Y_u,          &
                                   data%DIST_C_u, data%C, data%BARRIER_C,      &
                                   data%SCALE_C, data%RHS, prob%f,             &
                                   data%H_sbls, data%A_sbls, data%C_sbls,      &
                                   data%order, data%X_coef, data%C_coef,       &
                                   data%Y_coef, data%Y_l_coef, data%Y_u_coef,  &
                                   data%Z_l_coef, data%Z_u_coef,               &
                                   data%BINOMIAL, data%CS_coef, data%COEF,     &
                                   data%ROOTS, data%ROOTS_data,                &
                                   data%DX_zh, data%DC_zh,                     &
                                   data%DY_zh, data%DY_l_zh,                   &
                                   data%DY_u_zh, data%DZ_l_zh,                 &
                                   data%DZ_u_zh,                               &
                                   data%OPT_alpha, data%OPT_merit,             &
                                   data%SBLS_data, prefix,                     &
                                   control, inform,                            &
                                   prob%Hessian_kind, prob%gradient_kind,      &
                                   prob%target_kind,                           &
                                   H_val = prob%H%val, H_col = prob%H%col,     &
                                   H_ptr = prob%H%ptr )
            END IF
          ELSE
            IF ( lbfgs ) THEN
              CALL CCQP_solve_main( data%dims, prob%n, prob%m,                 &
                                   prob%A%val, prob%A%col, prob%A%ptr,         &
                                   prob%C_l, prob%C_u, prob%X_l, prob%X_u,     &
                                   prob%C, prob%X, prob%Y, prob%Z,             &
                                   data%GRAD_L, data%DIST_X_l, data%DIST_X_u,  &
                                   data%Z_l, data%Z_u, data%BARRIER_X,         &
                                   data%Y_l, data%DIST_C_l, data%Y_u,          &
                                   data%DIST_C_u, data%C, data%BARRIER_C,      &
                                   data%SCALE_C, data%RHS, prob%f,             &
                                   data%H_sbls, data%A_sbls, data%C_sbls,      &
                                   data%order, data%X_coef, data%C_coef,       &
                                   data%Y_coef, data%Y_l_coef, data%Y_u_coef,  &
                                   data%Z_l_coef, data%Z_u_coef,               &
                                   data%BINOMIAL, data%CS_coef, data%COEF,     &
                                   data%ROOTS, data%ROOTS_data,                &
                                   data%DX_zh, data%DC_zh,                     &
                                   data%DY_zh, data%DY_l_zh,                   &
                                   data%DY_u_zh, data%DZ_l_zh,                 &
                                   data%DZ_u_zh,                               &
                                   data%OPT_alpha, data%OPT_merit,             &
                                   data%SBLS_data, prefix,                     &
                                   control, inform,                            &
                                   prob%Hessian_kind, prob%gradient_kind,      &
                                   prob%target_kind,                           &
                                   H_lm = prob%H_lm, G = prob%G )
            ELSE
              CALL CCQP_solve_main( data%dims, prob%n, prob%m,                 &
                                   prob%A%val, prob%A%col, prob%A%ptr,         &
                                   prob%C_l, prob%C_u, prob%X_l, prob%X_u,     &
                                   prob%C, prob%X, prob%Y, prob%Z,             &
                                   data%GRAD_L, data%DIST_X_l, data%DIST_X_u,  &
                                   data%Z_l, data%Z_u, data%BARRIER_X,         &
                                   data%Y_l, data%DIST_C_l, data%Y_u,          &
                                   data%DIST_C_u, data%C, data%BARRIER_C,      &
                                   data%SCALE_C, data%RHS, prob%f,             &
                                   data%H_sbls, data%A_sbls, data%C_sbls,      &
                                   data%order, data%X_coef, data%C_coef,       &
                                   data%Y_coef, data%Y_l_coef, data%Y_u_coef,  &
                                   data%Z_l_coef, data%Z_u_coef,               &
                                   data%BINOMIAL, data%CS_coef, data%COEF,     &
                                   data%ROOTS, data%ROOTS_data,                &
                                   data%DX_zh, data%DC_zh,                     &
                                   data%DY_zh, data%DY_l_zh,                   &
                                   data%DY_u_zh, data%DZ_l_zh,                 &
                                   data%DZ_u_zh,                               &
                                   data%OPT_alpha, data%OPT_merit,             &
                                   data%SBLS_data, prefix,                     &
                                   control, inform,                            &
                                   prob%Hessian_kind, prob%gradient_kind,      &
                                   prob%target_kind,                           &
                                   H_val = prob%H%val, H_col = prob%H%col,     &
                                   H_ptr = prob%H%ptr, G = prob%G )
            END IF
          END IF
        END IF
      END IF

      inform%time%analyse = inform%time%analyse +                              &
        inform%FDC_inform%time%analyse - time_analyse
      inform%time%clock_analyse = inform%time%clock_analyse +                  &
        inform%FDC_inform%time%clock_analyse - clock_analyse
      inform%time%factorize = inform%time%factorize +                          &
        inform%FDC_inform%time%factorize - time_factorize
      inform%time%clock_factorize = inform%time%clock_factorize +              &
        inform%FDC_inform%time%clock_factorize - clock_factorize

!  crossover solution if required

! ** NB. No crossover for shifted least-norm problems currently

      IF ( stat_required .AND. control%crossover .AND.                         &
           inform%status == GALAHAD_ok .AND. prob%Hessian_kind < 0 ) THEN
        IF ( printa ) THEN
          WRITE( control%out, "( A, ' Before crossover:' )" ) prefix
          WRITE( control%out, "( /, A, '      i       X_l             X   ',   &
         &   '          X_u            Z        st' )" ) prefix
          DO i = 1, prob%n
            WRITE( control%out, "( A, I7, 4ES15.7, I3 )" ) prefix, i,          &
            prob%X_l( i ), prob%X( i ), prob%X_u( i ), prob%Z( i ), B_stat( i )
          END DO

          WRITE( control%out, "( /, A, '      i       C_l             C   ',   &
         &   '          C_u            Y        st' )" ) prefix
          DO i = 1, prob%m
            WRITE( control%out, "( A, I7, 4ES15.7, I3 )" ) prefix, i,          &
            prob%C_l( i ), prob%C( i ), prob%C_u( i ), prob%Y( i ), C_stat( i )
          END DO
        END IF
        data%CRO_control = control%CRO_control
        data%CRO_control%feasibility_tolerance =                               &
          MAX( inform%primal_infeasibility, inform%dual_infeasibility,         &
               inform%complementary_slackness,                                 &
               control%CRO_control%feasibility_tolerance )
        IF ( data%CRO_control%feasibility_tolerance < infinity / two ) THEN
          data%CRO_control%feasibility_tolerance =                             &
            two * data%CRO_control%feasibility_tolerance
        ELSE
          data%CRO_control%feasibility_tolerance = infinity
        END IF
        time_analyse = inform%CRO_inform%time%analyse
        clock_analyse = inform%CRO_inform%time%clock_analyse
        time_factorize = inform%CRO_inform%time%factorize
        clock_factorize = inform%CRO_inform%time%clock_factorize
        IF ( lbfgs ) THEN
          CALL CRO_crossover( prob%n, prob%m, data%dims%c_equality,            &
                              prob%H_lm, prob%A%val,                           &
                              prob%A%col, prob%A%ptr, prob%G, prob%C_l,        &
                              prob%C_u, prob%X_l, prob%X_u, prob%C, prob%X,    &
                              prob%Y, prob%Z, C_stat, B_stat, data%CRO_data,   &
                              data%CRO_control, inform%CRO_inform )
        ELSE
          CALL CRO_crossover( prob%n, prob%m, data%dims%c_equality,            &
                              prob%H%val, prob%H%col, prob%H%ptr, prob%A%val,  &
                              prob%A%col, prob%A%ptr, prob%G, prob%C_l,        &
                              prob%C_u, prob%X_l, prob%X_u, prob%C, prob%X,    &
                              prob%Y, prob%Z, C_stat, B_stat, data%CRO_data,   &
                              data%CRO_control, inform%CRO_inform )
        END IF
        inform%time%analyse = inform%time%analyse +                            &
          inform%CRO_inform%time%analyse - time_analyse
        inform%time%clock_analyse = inform%time%clock_analyse +                &
          inform%CRO_inform%time%clock_analyse - clock_analyse
        inform%time%factorize = inform%time%factorize +                        &
          inform%CRO_inform%time%factorize - time_factorize
        inform%time%clock_factorize = inform%time%clock_factorize +            &
          inform%CRO_inform%time%clock_factorize - clock_factorize
        cro_clock_matrix =                                                     &
          inform%CRO_inform%time%clock_analyse - clock_analyse +               &
          inform%CRO_inform%time%clock_factorize - clock_factorize

        IF ( printa ) THEN
          WRITE( control%out, "( A, ' After crossover:' )" ) prefix
          WRITE( control%out, "( /, A, '      i       X_l             X   ',   &
         &   '          X_u            Z        st' )" ) prefix
          DO i = 1, prob%n
            WRITE( control%out, "( A, I7, 4ES15.7, I3 )" ) prefix, i,          &
            prob%X_l( i ), prob%X( i ), prob%X_u( i ), prob%Z( i ), B_stat( i )
          END DO

          WRITE( control%out, "( /, A, '      i       C_l             C   ',   &
         &   '          C_u            Y        st' )" ) prefix
          DO i = 1, prob%m
            WRITE( control%out, "( A, I7, 4ES15.7, I3 )" ) prefix, i,          &
            prob%C_l( i ), prob%C( i ), prob%C_u( i ), prob%Y( i ), C_stat( i )
          END DO
        END IF
      END IF

!  if some of the constraints were freed during the computation, refix them now

      IF ( remap_freed ) THEN
        CALL CPU_TIME( time_record ) ; CALL CLOCK_time( clock_record )
        IF ( stat_required ) THEN
          C_stat( prob%m + 1 : data%QPP_map_freed%m ) = 0
          CALL SORT_inverse_permute( data%QPP_map_freed%m,                     &
                                     data%QPP_map_freed%c_map,                 &
                                     IX = C_stat( : data%QPP_map_freed%m ) )
          B_stat( prob%n + 1 : data%QPP_map_freed%n ) = - 1
          CALL SORT_inverse_permute( data%QPP_map_freed%n,                     &
                                     data%QPP_map_freed%x_map,                 &
                                     IX = B_stat( : data%QPP_map_freed%n ) )
        END IF
        CALL QPP_restore( data%QPP_map_freed, data%QPP_inform, prob,           &
                          get_all = .TRUE.)
        CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
        inform%time%preprocess = inform%time%preprocess + time_now - time_record
        inform%time%clock_preprocess =                                         &
          inform%time%clock_preprocess + clock_now - clock_record
        data%dims = data%dims_save_freed

!  fix the temporarily freed constraint bounds

        DO i = 1, n_depen
          j = data%Index_c_freed( i )
          prob%C_l( j ) = data%C_freed( i )
          prob%C_u( j ) = data%C_freed( i )
        END DO
      END IF
      data%tried_to_remove_deps = .FALSE.

!  retore the problem to its original form

  700 CONTINUE
      data%trans = data%trans - 1
      IF ( data%trans == 0 ) THEN
!       data%IW( : prob%n + 1 ) = 0
        CALL CPU_TIME( time_record ) ; CALL CLOCK_time( clock_record )
        IF ( stat_required ) THEN
          C_stat( prob%m + 1 : data%QPP_map%m ) = 0
          CALL SORT_inverse_permute( data%QPP_map%m, data%QPP_map%c_map,       &
                                     IX = C_stat( : data%QPP_map%m ) )
          B_stat( prob%n + 1 : data%QPP_map%n ) = - 1
          CALL SORT_inverse_permute( data%QPP_map%n, data%QPP_map%x_map,       &
                                     IX = B_stat( : data%QPP_map%n ) )
        END IF

!  full restore

        IF ( control%restore_problem >= 2 .OR. stat_required ) THEN
          CALL QPP_restore( data%QPP_map, data%QPP_inform, prob,               &
                            get_all = .TRUE. )

!  restore vectors and scalars

        ELSE IF ( control%restore_problem == 1 ) THEN
          CALL QPP_restore( data%QPP_map, data%QPP_inform, prob,               &
                            get_f = .TRUE., get_g = .TRUE.,                    &
                            get_x = .TRUE., get_x_bounds = .TRUE.,             &
                            get_y = .TRUE., get_z = .TRUE.,                    &
                            get_c = .TRUE., get_c_bounds = .TRUE. )

!  recover solution

        ELSE
          CALL QPP_restore( data%QPP_map, data%QPP_inform, prob,               &
                            get_x = .TRUE., get_y = .TRUE.,                    &
                            get_z = .TRUE., get_c = .TRUE. )
        END IF

        CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
        inform%time%preprocess = inform%time%preprocess + time_now - time_record
        inform%time%clock_preprocess =                                         &
          inform%time%clock_preprocess + clock_now - clock_record
        prob%new_problem_structure = data%new_problem_structure
        data%save_structure = .TRUE.
      END IF

!  compute total time

  800 CONTINUE
      CALL CPU_time( time_now ) ; CALL CLOCK_time( clock_now )
      inform%time%total = inform%time%total + REAL( time_now - time_start, wp )
      inform%time%clock_total =                                                &
        inform%time%clock_total + clock_now - clock_start

      IF ( printi ) WRITE( control%out,                                        &
     "( /, A, 3X, ' =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=',    &
    &             '-=-=-=-=-=-=-=',                                            &
    &   /, A, 3X, ' =                            total time              ',    &
    &             '             =',                                            &
    &   /, A, 3X, ' =', 24X, 0P, F12.2, 29x, '='                               &
    &   /, A, 3X, ' =    preprocess    analyse    factorize     solve    ',    &
    &             ' crossover   =',                                            &
    &   /, A, 3X, ' =', 5F12.2, 5x, '=',                                       &
    &   /, A, 3X, ' =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=',    &
    &             '-=-=-=-=-=-=-=') ")                                         &
        prefix, prefix, prefix, inform%time%clock_total, prefix, prefix,       &
        inform%time%clock_preprocess, inform%time%clock_analyse,               &
        inform%time%clock_factorize, inform%time%clock_solve,                  &
        inform%CRO_inform%time%clock_total - cro_clock_matrix, prefix

      IF ( control%out > 0 .AND. control%print_level >= 5 )                    &
        WRITE( control%out, "( A, ' leaving CCQP_solve ' )" ) prefix
      RETURN

!  allocation error

  900 CONTINUE
      inform%status = GALAHAD_error_allocate
      CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
      inform%time%total = inform%time%total + REAL( time_now - time_start, wp )
      inform%time%clock_total =                                                &
        inform%time%clock_total + clock_now - clock_start
      IF ( printi ) WRITE( control%out,                                        &
        "( A, ' ** Message from -CCQP_solve-', /,  A,                          &
       &      ' Allocation error, for ', A, /, A, ' status = ', I0 ) " )       &
        prefix, prefix, inform%bad_alloc, inform%alloc_status

      IF ( control%out > 0 .AND. control%print_level >= 5 )                    &
        WRITE( control%out, "( A, ' leaving CCQP_solve ' )" ) prefix
      RETURN

!  non-executable statements

 2010 FORMAT( ' ', /, A, '    ** Error return ', I0, ' from CCQP ' )

!  End of CCQP_solve

      END SUBROUTINE CCQP_solve

!-*-*-*-*-*-   C C Q P _ S O L V E _ M A I N   S U B R O U T I N E   -*-*-*-*-*

      SUBROUTINE CCQP_solve_main( dims, n, m, A_val, A_col, A_ptr,             &
                                 C_l, C_u, X_l, X_u, C_RES, X, Y, Z, GRAD_L,   &
                                 DIST_X_l, DIST_X_u, Z_l, Z_u, BARRIER_X,      &
                                 Y_l, DIST_C_l, Y_u, DIST_C_u, C, BARRIER_C,   &
                                 SCALE_C, RHS, f, H_sbls, A_sbls, C_sbls,      &
                                 order, X_coef, C_coef, Y_coef, Y_l_coef,      &
                                 Y_u_coef, Z_l_coef, Z_u_coef, BINOMIAL,       &
                                 CS_coef, COEF, ROOTS, ROOTS_data,             &
                                 DX_zh, DC_zh, DY_zh, DY_l_zh,                 &
                                 DY_u_zh, DZ_l_zh, DZ_u_zh,                    &
                                 OPT_alpha, OPT_merit,                         &
                                 SBLS_data, prefix, control, inform,           &
                                 Hessian_kind, gradient_kind, target_kind,     &
                                 H_val, H_col, H_ptr, H_lm, WEIGHT, X0, G,     &
                                 C_last, X_last, Y_last, Z_last,               &
                                 C_stat, B_Stat )                              

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Minimize the quadratic objective function
!
!        1/2 x^T H x + g^T x + f
!
!  or the linear/separable objective function
!
!        1/2 || W * ( x - x^0 ) ||_2^2 + g^T x + f
!
!  subject to the constraints
!
!               (c_l)_i <= (Ax)_i <= (c_u)_i , i = 1, .... , m,
!
!    and        (x_l)_i <=   x_i  <= (x_u)_i , i = 1, .... , n,
!
!  where x is a vector of n components ( x_1, .... , x_n ),
!  A is an m by n matrix, and any of the bounds (c_l)_i, (c_u)_i
!  (x_l)_i, (x_u)_i may be infinite, using a primal-dual method.
!  The subroutine is particularly appropriate when A is sparse.
!
!  In order that many of the internal computations may be performed
!  efficiently, it is required that
!
!  * the variables are ordered so that their bounds appear in the order
!
!    free                      x
!    non-negativity      0  <= x
!    lower              x_l <= x
!    range              x_l <= x <= x_u   (x_l < x_u)
!    upper                     x <= x_u
!    non-positivity            x <=  0
!
!    Fixed variables are not permitted (ie, x_l < x_u for range variables).
!
!  * the constraints are ordered so that their bounds appear in the order
!
!    equality           c_l  = A x
!    lower              c_l <= A x
!    range              c_l <= A x <= c_u
!    upper                     A x <= c_u
!
!    Free constraints are not permitted (ie, at least one of c_l and c_u
!    must be finite). Bounds with the value zero are not treated separately.
!
!  These transformations may be effected, in place, using the module
!  GALAHAD_QPP. The same module may subsequently used to recover the solution.
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Arguments:
!
!  dims is a structure of type CCQP_data_type, whose components hold SCALAR
!   information about the problem on input. The components will be unaltered
!   on exit. The following components must be set:
!
!   %x_free is an INTEGER variable, which must be set by the user to the
!    number of free variables. RESTRICTION: %x_free >= 0
!
!   %x_l_start is an INTEGER variable, which must be set by the user to the
!    index of the first variable with a nonzero lower (or lower range) bound.
!    RESTRICTION: %x_l_start >= %x_free + 1
!
!   %x_l_end is an INTEGER variable, which must be set by the user to the
!    index of the last variable with a nonzero lower (or lower range) bound.
!    RESTRICTION: %x_l_end >= %x_l_start
!
!   %x_u_start is an INTEGER variable, which must be set by the user to the
!    index of the first variable with a nonzero upper (or upper range) bound.
!    RESTRICTION: %x_u_start >= %x_l_start
!
!   %x_u_end is an INTEGER variable, which must be set by the user to the
!    index of the last variable with a nonzero upper (or upper range) bound.
!    RESTRICTION: %x_u_end >= %x_u_start
!
!   %c_equality is an INTEGER variable, which must be set by the user to the
!    number of equality constraints, m. RESTRICTION: %c_equality >= 0
!
!   %c_l_start is an INTEGER variable, which must be set by the user to the
!    index of the first inequality constraint with a lower (or lower range)
!    bound. RESTRICTION: %c_l_start = %c_equality + 1
!    (strictly, this information is redundant!)
!
!   %c_l_end is an INTEGER variable, which must be set by the user to the
!    index of the last inequality constraint with a lower (or lower range)
!    bound. RESTRICTION: %c_l_end >= %c_l_start
!
!   %c_u_start is an INTEGER variable, which must be set by the user to the
!    index of the first inequality constraint with an upper (or upper range)
!    bound. RESTRICTION: %c_u_start >= %c_l_start
!    (strictly, this information is redundant!)
!
!   %c_u_end is an INTEGER variable, which must be set by the user to the
!    index of the last inequality constraint with an upper (or upper range)
!    bound. RESTRICTION: %c_u_end = %m
!    (strictly, this information is redundant!)
!
!   %nc is an INTEGER variable, which must be set by the user to the
!    value dims%c_u_end - dims%c_l_start + 1
!
!   %x_s is an INTEGER variable, which must be set by the user to the
!    value 1
!
!   %x_e is an INTEGER variable, which must be set by the user to the
!    value n
!
!   %c_s is an INTEGER variable, which must be set by the user to the
!    value dims%x_e + 1
!
!   %c_e is an INTEGER variable, which must be set by the user to the
!    value dims%x_e + dims%nc
!
!   %c_b is an INTEGER variable, which must be set by the user to the
!    value dims%c_e - m
!
!   %y_s is an INTEGER variable, which must be set by the user to the
!    value dims%c_e + 1
!
!   %y_i is an INTEGER variable, which must be set by the user to the
!    value dims%c_s + m
!
!   %y_e is an INTEGER variable, which must be set by the user to the
!    value dims%c_e + m
!
!   %v_e is an INTEGER variable, which must be set by the user to the
!    value dims%y_e
!
!  A_col/ptr/val is used to hold the matrix A by rows. In particular:
!      A_col( : )   the column indices of the components of A
!      A_ptr( : )   pointers to the start of each row, and past the end of
!                   the last row.
!      A_val( : )   the values of the components of A
!
!  C_l, C_u are REAL arrays of length m, which must be set by the user to
!   the values of the arrays x_l and x_u of lower and upper bounds on x, ordered
!   as described above (strictly only C_l( dims%c_l_start : dims%c_l_end )
!   and C_u( dims%c_u_start : dims%c_u_end ) need be set, as the other
!   components are ignored!).
!
!  X_l, X_u are REAL arrays of length n, which must be set by the user to
!   the values of the arrays x_l and x_u of lower and upper bounds on x, ordered
!   as described above (strictly only X_l( dims%x_l_start : dims%x_l_end )
!   and X_u( dims%x_u_start : dims%x_u_end ) need be set, as the other
!   components are ignored!).
!
!  C_RES is a REAL array of length m, which need not be set on entry. On exit,
!   the i-th component of C_RES will contain (A * x)_i, for i = 1, .... , m.
!
!  X is a REAL array of length n, which must be set by
!   the user on entry to CCQP_solve to give an initial estimate of the
!   optimization parameters, x. The i-th component of X should contain
!   the initial estimate of x_i, for i = 1, .... , n.  The estimate need
!   not satisfy the simple bound constraints and may be perturbed by
!   CCQP_solve prior to the start of the minimization.  Any estimate which is
!   closer to one of its bounds than control%prfeas may be reset to try to
!   ensure that it is at least control%prfeas from its bounds. On exit from
!   CCQP_solve, X will contain the best estimate of the optimization
!   parameters found
!
!  Y is a REAL array of length m, which must be set by the user
!   on entry to CCQP_solve to give an initial estimates of the
!   optimal Lagrange multipiers, y. The i-th component of Y
!   should contain the initial estimate of y_i, for i = 1, .... , m.
!   Any estimate which is smaller than control%dufeas may be
!   reset to control%dufeas. The dual variable for any variable with both
!   On exit from CCQP_solve, Y will contain the best estimate of
!   the Lagrange multipliers found
!
!  Z, is a REAL array of length n, which must be set by
!   on entry to CCQP_solve to hold the values of the the dual variables
!   associated with the simple bound constraints.
!   Any estimate which is smaller than control%dufeas may be
!   reset to control%dufeas. The dual variable for any variable with both
!   infinite lower and upper bounds need not be set. On exit from
!   CCQP_solve, Z will contain the best estimates obtained
!
!  control and inform are exactly as for CCQP_solve
!
!  Hessian_kind is an INTEGER variable which defines the type of objective
!    function to be used. Possible values are
!
!     0  all the weights will be zero, and the analytic centre of the
!        feasible region will be found. WEIGHT (see below) need not be set
!
!     1  all the weights will be one. WEIGHT (see below) need not be set
!
!     2  the weights will be those given by WEIGHT (see below)
!
!     any other value  - the Hessian will be given by H (see below)
!
!   WEIGHT is an optional REAL array, which need only be included if
!    Hessian_kind is 2. If this is so, it must be of length at least
!    n, and contain the weights W for the objective function.
!
!   X0 is an optional REAL array, which need only be included if
!    Hessian_kind is 1 or 2. If this is so, it must be of length at least
!    n, and contain the shifts X^0 for the objective function.
!
!   H_col/ptr/val is used to hold the lower triangle of the matrix H by rows.
!    In particular:
!      H_col( : )   the column indices of the components of H
!      H_ptr( : )   pointers to the start of each row, and past the end of
!                   the last row.
!      H_val( : )   the values of the components of H.
!     If H_ptr or H_col is absent, H will be presumed to be a scalar
!     multiple, H_val(1), of the identity
!
!   H_lm is used to hold a "limited-memory" representation of H as set up by
!     the module GALAHAD_LMS
!
!   gradient_kind is an INTEGER variable which defines the type of linear
!    term of the objective function to be used. Possible values are
!
!     0  the linear term will be zero, and the analytic centre of the
!        feasible region will be found if in addition Hessian_kind is 0.
!        G (see below) need not be set
!
!     1  each component of the linear terms g will be one.
!        G (see below) need not be set
!
!     any other value - the gradients will be those given by G (see below)
!
!   G is an optional REAL array, which need only be included if
!    gradient_kind is not 0 or 1. If this is so, it must be of length at least
!    n, and contain the gradient term g for the objective function.
!
!  The remaining arguments are used as internal workspace, and need not be
!  set on entry
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n, m, order
      INTEGER, INTENT( IN ) :: Hessian_kind, gradient_kind, target_kind
      REAL ( KIND = wp ), INTENT( IN ) :: f
      INTEGER, INTENT( IN ), DIMENSION( m + 1 ) :: A_ptr
      INTEGER, INTENT( IN ), DIMENSION( A_ptr( m + 1 ) - 1 ) :: A_col
      INTEGER, INTENT( IN ), DIMENSION( n + 1 ), OPTIONAL  :: H_ptr
      INTEGER, INTENT( IN ), DIMENSION( : ), OPTIONAL  :: H_col
      INTEGER, INTENT( OUT ), OPTIONAL, DIMENSION( m ) :: C_stat
      INTEGER, INTENT( OUT ), OPTIONAL, DIMENSION( n ) :: B_stat
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( m ) :: C_l, C_u
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X_l, X_u
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( n ) :: X
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( m ) :: Y
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( n ) :: Z
      REAL ( KIND = wp ), INTENT( IN ),                                        &
                          DIMENSION( : ), OPTIONAL  :: H_val
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ), OPTIONAL :: WEIGHT, X0
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ), OPTIONAL :: G
      REAL ( KIND = wp ), INTENT( IN ),                                        &
                          DIMENSION( A_ptr( m + 1 ) - 1 ) :: A_val
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( m ) :: C_RES
      REAL ( KIND = wp ), INTENT( OUT ), OPTIONAL, DIMENSION( n ) :: X_last
      REAL ( KIND = wp ), INTENT( OUT ), OPTIONAL, DIMENSION( m ) :: C_last
      REAL ( KIND = wp ), INTENT( OUT ), OPTIONAL, DIMENSION( m ) :: Y_last
      REAL ( KIND = wp ), INTENT( OUT ), OPTIONAL, DIMENSION( n ) :: Z_last
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( dims%v_e ) :: RHS
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( dims%c_e ) :: GRAD_L
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
                          DIMENSION( dims%x_l_start : dims%x_l_end ) :: DIST_X_l
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
                          DIMENSION( dims%x_u_start : dims%x_u_end ) :: DIST_X_u
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
             DIMENSION( dims%x_free + 1 : dims%x_l_end ) ::  Z_l
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
             DIMENSION( dims%x_u_start : n ) :: Z_u
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
                          DIMENSION( dims%x_free + 1 : n ) :: BARRIER_X
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
             DIMENSION( dims%c_l_start : dims%c_l_end ) :: Y_l, DIST_C_l
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
             DIMENSION( dims%c_u_start : dims%c_u_end ) :: Y_u, DIST_C_u
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
             DIMENSION( dims%c_l_start : dims%c_u_end ) :: C, BARRIER_C, SCALE_C

      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( n, 0 : order ) :: X_coef
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( dims%c_l_start : dims%c_u_end, 0 : order ) :: C_coef
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( m, 0 : order ) :: Y_coef
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( dims%c_l_start : dims%c_l_end, 0 : order ) ::  Y_l_coef
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( dims%c_u_start : dims%c_u_end, 0 : order ) ::  Y_u_coef
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION(   dims%x_free + 1 : dims%x_l_end, 0 : order ) :: Z_l_coef
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( dims%x_u_start : n, 0 : order ) :: Z_u_coef
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( 0 : order - 1 , order ) :: BINOMIAL
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( 0 : 2 * order ) :: CS_coef
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( 0 : 2 * order ) :: COEF
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( 2 * order ) :: ROOTS
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( n ) :: DX_zh
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( dims%c_l_start : dims%c_u_end ) :: DC_zh
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( m ) :: DY_zh
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( dims%c_l_start : dims%c_l_end ) ::  DY_l_zh
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( dims%c_u_start : dims%c_u_end ) ::  DY_u_zh
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION(   dims%x_free + 1 : dims%x_l_end ) :: DZ_l_zh
      REAL ( KIND = wp ), INTENT( OUT ),                                       &
        DIMENSION( dims%x_u_start : n ) :: DZ_u_zh
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( order ) :: OPT_alpha
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( order ) :: OPT_merit

      TYPE ( SMT_type ), INTENT( INOUT ) :: H_sbls, A_sbls, C_sbls
      TYPE ( LMS_data_type ), OPTIONAL, INTENT( INOUT ) :: H_lm

      CHARACTER ( LEN = * ), INTENT( IN ) :: prefix
      TYPE ( CCQP_control_type ), INTENT( IN ) :: control
      TYPE ( CCQP_inform_type ), INTENT( INOUT ) :: inform
      TYPE ( SBLS_data_type ), INTENT( INOUT ) :: SBLS_data
      TYPE ( ROOTS_data_type ), INTENT( INOUT ) :: ROOTS_data

!  Parameters

      REAL ( KIND = wp ), PARAMETER :: eta = tenm4
      REAL ( KIND = wp ), PARAMETER :: sigma_max = point01
      REAL ( KIND = wp ), PARAMETER :: degen_tol = tenm5

!  Local variables

      INTEGER :: a_ne, h_ne, i, j, k, l, start_print, stop_print, print_level
      INTEGER :: nbnds, nbnds_x, nbnds_c, muzero_fixed, nbact, iorder, sorder
      INTEGER :: out, error, it_best, infeas_max, n_sbls, b_change, c_change
      INTEGER :: primal_nonopt, dual_nonopt, cs_nonopt
      INTEGER, DIMENSION( 1 ) :: iorder_array
      REAL :: time, time_record, time_start, time_now, time_solve
      REAL ( KIND = wp ) :: time_analyse, time_factorize
      REAL ( KIND = wp ) :: clock_record, clock_start, clock_now, clock_solve
      REAL ( KIND = wp ) :: clock_analyse, clock_factorize
      REAL ( KIND = wp ) :: pjgnrm, mu, amax, gmax, hmax, gamma_f, bik, slope
      REAL ( KIND = wp ) :: cs, slknes, slkmin, reduce_infeas, tau, comp
      REAL ( KIND = wp ) :: slknes_x, slknes_c, slkmax_x, slkmax_c, res_cs
      REAL ( KIND = wp ) :: slkmin_x, slkmin_c, res_primal, res_primal_dual
      REAL ( KIND = wp ) :: merit, merit_trial, merit_best, merit_model
      REAL ( KIND = wp ) :: prfeas, dufeas, p_min, p_max, d_min, d_max
      REAL ( KIND = wp ) :: pivot_tol, relative_pivot_tol, min_pivot_tol
      REAL ( KIND = wp ) :: alpha, alpha_l, alpha_u, alpha_max, one_minus_alpha
      REAL ( KIND = wp ) :: sigma, gamma_c, gi, co, sigma_mu, sigma_mu2, curv
      REAL ( KIND = wp ) :: one_plus_sigma_mu, two_plus_sigma_mu, balance, xi
      REAL ( KIND = wp ) :: one_plus_2_sigma_mu, two_sigma_mu2, two_sigma_mu
      REAL ( KIND = wp ) :: opt_alpha_guarantee, opt_merit_guarantee
      REAL ( KIND = wp ) :: stop_p, stop_d, stop_c, two_mu

      LOGICAL :: set_printt, set_printi, set_printw, set_printd, set_printe
      LOGICAL :: printt, printi, printe, printd, printw, set_printp, printp
      LOGICAL :: maxpiv, stat_required, guarantee, unbounded, lbfgs, optimal
!     LOGICAL :: root_arc
      LOGICAL :: diagonal_hessian, puiseux, get_stat, stat_known
      LOGICAL :: use_scale_c = .FALSE.
      CHARACTER ( LEN = 1 ) :: re, pui
      CHARACTER ( LEN = 2 ) :: arc
      CHARACTER ( len = 10 ) :: char_x, char_c, char_y
      CHARACTER ( len = 10 ) :: char_z_l, char_z_u, char_y_l, char_y_u
!     REAL ( KIND = wp ), DIMENSION( n ) :: DX, WORK_n
      INTEGER, DIMENSION( m ) :: C_stat_old
      INTEGER, DIMENSION( n ) :: B_stat_old

      TYPE ( SBLS_control_type ) :: SBLS_control

      INTEGER :: sif = 50
!     LOGICAL :: generate_sif = .TRUE.
      LOGICAL :: generate_sif = .FALSE.

      IF ( control%out > 0 .AND. control%print_level >= 5 )                    &
        WRITE( control%out, "( A, ' entering CCQP_solve_main ' )" ) prefix

      IF ( hessian_kind < 0 ) THEN
        lbfgs = PRESENT( H_lm )
      ELSE
        lbfgs = .FALSE.
      END IF

!  detemine what kind of Hessian is to be stored

      diagonal_hessian = .FALSE.
      IF ( Hessian_kind < 0 ) THEN
        IF ( .NOT. PRESENT( H_col ) .OR. .NOT. PRESENT( H_ptr ) )             &
          diagonal_hessian = .TRUE.
      END IF

!  move to argument list

      IF ( control%out > 0 .AND. control%print_level >= 20 ) THEN
!     IF ( control%out > 0 .AND. control%print_level >= 1 ) THEN
        WRITE( control%out, "( /, A, ' n = ', I0, ', m = ', I0, ', f =',       &
       &                       ES24.16 )" ) prefix, n, m, f
        IF ( gradient_kind == 0 ) THEN
          WRITE( control%out, "( A, ' G = zeros' )" ) prefix
        ELSE IF ( gradient_kind == 1 ) THEN
          WRITE( control%out, "( A, ' G = ones' )" ) prefix
        ELSE
          WRITE( control%out, "( A, ' G =', /, ( 5X, 3ES24.16 ) )" )           &
            prefix, G( : n )
        END IF
        IF ( Hessian_kind == 0 ) THEN
          WRITE( control%out, "( A, ' W = zeros' )" ) prefix
        ELSE IF ( Hessian_kind == 1 ) THEN
          WRITE( control%out, "( A, ' W = ones ' )" ) prefix
        ELSE IF ( Hessian_kind == 2 ) THEN
          WRITE( control%out, "( A, ' W = ', /, ( 5X, 3ES24.16 ) )" )          &
            prefix, WEIGHT( : n )
        ELSE IF ( hessian_kind < 0 ) THEN
          IF ( lbfgs ) THEN
            WRITE( control%out, "( ' H (limited-memory, held implicitly)' )" )
          ELSE
            WRITE( control%out, "( A, ' H (row-wise) =' )" ) prefix
            DO i = 1, n
              IF ( H_ptr( i ) <= H_ptr( i + 1 ) - 1 )                          &
                WRITE( control%out, "( ( 2X, 2( 2I8, ES24.16 ) ) )" )          &
               ( i, H_col( j ), H_val( j ), j = H_ptr( i ), H_ptr( i + 1 ) - 1 )
            END DO
          END IF
        END IF
        WRITE( control%out, "( A,                                              &
       &  ' X_l =', /, ( 5X, 3ES24.16 ) )" ) prefix, X_l( : n )
        WRITE( control%out, "( A,                                              &
       &  ' X_u =', /, ( 5X, 3ES24.16 ) )" ) prefix, X_u( : n )
        IF ( m > 0 ) THEN
          WRITE( control%out, "( A, ' A (row-wise) =' )" ) prefix
          DO i = 1, m
           IF ( A_ptr( i ) <= A_ptr( i + 1 ) - 1 )                             &
              WRITE( control%out, "( ( 2X, 2( 2I8, ES24.16 ) ) )" )            &
              ( i, A_col( j ), A_val( j ), j = A_ptr( i ), A_ptr( i + 1 ) - 1 )
          END DO
          WRITE( control%out, "( A,                                            &
         &  ' C_l =', /, ( 5X, 3ES24.16 ) )" ) prefix, C_l( : m )
          WRITE( control%out, "( A,                                            &
         &  ' C_u =', /, ( 5X, 3ES24.16 ) )" ) prefix, C_u( : m )
        END IF
      END IF

! -------------------------------------------------------------------
!  If desired, generate a SIF file for problem passed

      IF ( generate_sif .AND. .NOT. lbfgs .AND. PRESENT( G ) ) THEN
        WRITE( sif, "( 'NAME          CCQP_OUT', //, 'VARIABLES', / )" )
        DO i = 1, n
          WRITE( sif, "( '    X', I8 )" ) i
        END DO

        WRITE( sif, "( /, 'GROUPS', / )" )
        DO i = 1, n
          IF ( G( i ) /= zero )                                                &
            WRITE( sif, "( ' N  OBJ      ', ' X', I8, ' ', ES12.5 )" ) i, G( i )
        END DO
        DO i = 1, dims%c_l_start - 1
          DO l = A_ptr( i ), A_ptr( i + 1 ) - 1
            WRITE( sif, "( ' E  C', I8, ' X', I8, ' ', ES12.5 )" )             &
              i, A_col( l ), A_val( l )
          END DO
        END DO
        DO i = dims%c_l_start, dims%c_l_end
          DO l = A_ptr( i ), A_ptr( i + 1 ) - 1
            WRITE( sif, "( ' G  C', I8, ' X', I8, ' ', ES12.5 )" )             &
              i, A_col( l ), A_val( l )
          END DO
        END DO
        DO i = dims%c_l_end + 1, dims%c_u_end
          DO l = A_ptr( i ), A_ptr( i + 1 ) - 1
            WRITE( sif, "( ' L  C', I8, ' X', I8, ' ', ES12.5 )" )             &
              i, A_col( l ), A_val( l )
          END DO
        END DO

        WRITE( sif, "( /, 'CONSTANTS', / )" )
        DO i = 1, dims%c_l_end
          IF ( C_l( i ) /= zero )                                              &
          WRITE( sif, "( '    RHS      ', ' C', I8, ' ', ES12.5 )" ) i, C_l( i )
        END DO
        DO i = dims%c_l_end + 1, dims%c_u_end
          IF ( C_u( i ) /= zero )                                              &
          WRITE( sif, "( '    RHS      ', ' C', I8, ' ', ES12.5 )" ) i, C_u( i )
        END DO

        IF ( dims%c_u_start <= dims%c_l_end ) THEN
          WRITE( sif, "( /, 'RANGES', / )" )
          DO i = dims%c_u_start, dims%c_l_end
            WRITE( sif, "( '    RANGE    ', ' C', I8, ' ', ES12.5 )" )        &
              i, C_u( i ) - C_l( i )
          END DO
        END IF

        IF ( dims%x_free /= 0 .OR. dims%x_l_start <= n ) THEN
          WRITE( sif, "( /, 'BOUNDS', /, ' FR BND       ''DEFAULT''' )" )
          DO i = dims%x_free + 1, dims%x_l_start - 1
            WRITE( sif, "( ' LO BND       X', I8, ' ', ES12.5 )" ) i, zero
          END DO
          DO i = dims%x_l_start, dims%x_l_end
            WRITE( sif, "( ' LO BND       X', I8, ' ', ES12.5 )" ) i, X_l( i )
          END DO
          DO i = dims%x_u_start, dims%x_u_end
            WRITE( sif, "( ' UP BND       X', I8, ' ', ES12.5 )" ) i, X_u( i )
          END DO
          DO i = dims%x_u_end + 1, n
            WRITE( sif, "( ' UP BND       X', I8, ' ', ES12.5 )" ) i, zero
          END DO
        END IF

        WRITE( sif, "( /, 'START POINT', / )" )
        DO i = 1, n
          IF ( X( i ) /= zero )                                                &
            WRITE( sif, "( ' V  START    ', ' X', I8, ' ', ES12.5 )" ) i, X( i )
        END DO

        WRITE( sif, "( /, 'ENDATA' )" )
      END IF

!  SIF file generated
! -------------------------------------------------------------------

!  initialize time

      CALL CPU_time( time_start ) ; CALL CLOCK_time( clock_start )

!  ===========================
!  Control the output printing
!  ===========================

      print_level = 0
      IF ( control%start_print < 0 ) THEN
        start_print = - 1
      ELSE
        start_print = control%start_print
      END IF

      IF ( control%stop_print < 0 ) THEN
        stop_print = control%maxit + 1
      ELSE
        stop_print = control%stop_print
      END IF

      error = control%error ; out = control%out

      set_printe = error > 0 .AND. control%print_level >= 1

!  basic single line of output per iteration

      set_printi = out > 0 .AND. control%print_level >= 1

!  as per printi, but with additional timings for various operations

      set_printt = out > 0 .AND. control%print_level >= 2

!  as per printt but also with an indication of where in the code we are

      set_printp = out > 0 .AND. control%print_level >= 3

!  as per printp but also with details of innner iterations

      set_printw = out > 0 .AND. control%print_level >= 4

!  full debugging printing with significant arrays printed

      set_printd = out > 0 .AND. control%print_level >= 5

!  start setting control parameters

      IF ( inform%iter >= start_print .AND. inform%iter < stop_print ) THEN
        printe = set_printe ; printi = set_printi ; printt = set_printt
        printp = set_printp ;
        printw = set_printw ; printd = set_printd
        print_level = control%print_level
      ELSE
        printe = .FALSE. ; printi = .FALSE. ; printt = .FALSE.
        printp = .FALSE. ;
        printw = .FALSE. ; printd = .FALSE.
        print_level = 0
      END IF

      SBLS_control = control%SBLS_control
      IF ( SBLS_control%factorization < 0 .OR.                                 &
           SBLS_control%factorization > 3 ) THEN
        IF ( printi ) WRITE( out,                                              &
          "( A,' factor = ', I0, ' out of range [0,3]. Reset to 0' )" )        &
          prefix, SBLS_control%factorization
        SBLS_control%factorization = 0
      END IF

!  if there are no variables, exit

      IF ( n == 0 ) THEN
        i = COUNT( ABS( C_l( : dims%c_equality ) ) > control%stop_abs_p ) +    &
            COUNT( C_l( dims%c_l_start : dims%c_l_end ) > control%stop_abs_p)+ &
            COUNT( C_u( dims%c_u_start : dims%c_u_end ) < - control%stop_abs_p )
        inform%dual_infeasibility = zero
        inform%complementary_slackness = zero
        IF ( i == 0 ) THEN
          inform%primal_infeasibility = zero
          inform%status = GALAHAD_ok
        ELSE
          inform%primal_infeasibility = MAX(                                   &
            MAXVAL( ABS( C_l( : dims%c_equality ) ) ),                         &
            MAXVAL( MAX( C_l( dims%c_l_start : dims%c_l_end ), zero ) ),       &
            MAXVAL( MAX( - C_u( dims%c_u_start : dims%c_u_end ), zero ) ) )
          inform%status = GALAHAD_error_primal_infeasible
        END IF
        C_RES = zero ; Y = zero
        inform%obj = zero
        GO TO 810
      END IF

!  store the Jacobian and Hessian accounting for slack variables

      n_sbls = n + dims%nc

!  A will be in coordinate form

      CALL SMT_put( A_sbls%type, 'COORDINATE', inform%alloc_status )
      a_ne = A_ptr( m + 1 ) - 1
      A_sbls%n = n_sbls ; A_sbls%m = m ; A_sbls%ne = a_ne + dims%nc

!  set the components of A in coordinate form ...

      DO i = 1, m
        A_sbls%row( A_ptr( i ) : A_ptr( i + 1 ) - 1 ) = i
      END DO
      A_sbls%col( : a_ne ) = A_col( : a_ne )
      A_sbls%val( : a_ne ) = A_val( : a_ne )

!  ... and include the coodinates corresponding to the slack variables

      DO i = 1, dims%nc
        A_sbls%row( a_ne + i ) = dims%c_equality + i
        A_sbls%col( a_ne + i ) = n + i
      END DO

!  If H is not diagonal or LBFGS, it will be in coordinate form

      IF ( Hessian_kind < 0 .AND. .NOT. lbfgs ) THEN
        CALL SMT_put( H_sbls%type, 'COORDINATE', inform%alloc_status )
        H_sbls%n = n_sbls ; H_sbls%m = n_sbls

!  set the components of the barrier terms in coordinate form ...

        DO i = 1, n_sbls
          H_sbls%row( i ) = i ; H_sbls%col( i ) = i
        END DO

!  ... and add the components of H

        IF ( diagonal_hessian ) THEN
          h_ne = n
          DO i = 1, n
            H_sbls%row( n_sbls + i ) = i
            H_sbls%col( n_sbls + i ) = i
            H_sbls%val( n_sbls + i ) = H_val( i )
          END DO
        ELSE
          h_ne = H_ptr( n + 1 ) - 1
          DO i = 1, n
            H_sbls%row( n_sbls + H_ptr( i ) : n_sbls + H_ptr( i + 1 ) - 1 ) = i
          END DO
          H_sbls%col( n_sbls + 1 : n_sbls + h_ne ) = H_col( : h_ne )
!         SELECT CASE ( SMT_get( H_type ) )
!         CASE ( 'SCALED_IDENTITY', 'DIAGONAL', 'DENSE', 'SPARSE_BY_ROWS',     &
!              'COORDINATE' )
          H_sbls%val( n_sbls + 1 : n_sbls + h_ne ) = H_val( : h_ne )
!         END SELECT
        END IF
        H_sbls%ne = h_ne + n_sbls

!  otherwise H will be in diagonal form

      ELSE
        CALL SMT_put( H_sbls%type, 'DIAGONAL', inform%alloc_status )
        h_ne = 0
        H_sbls%n = n_sbls ; H_sbls%ne = n_sbls
      END IF

!  the zero matrix C will be in zero form

      CALL SMT_put( C_sbls%type, 'ZERO', inform%alloc_status )

!  set control parameters

      muzero_fixed = control%muzero_fixed
      prfeas = MAX( control%prfeas, epsmch )
      dufeas = MAX( control%dufeas, epsmch )
      reduce_infeas = MAX( epsmch,                                             &
                           MIN( control%reduce_infeas ** 2, one - epsmch ) )
      infeas_max = MAX( 0, control%infeas_max )
      stat_required = PRESENT( C_stat ) .AND. PRESENT( B_stat )
      IF ( stat_required ) THEN
        B_stat  = 0
        C_stat( : dims%c_equality ) = - 1
        C_stat( dims%c_equality + 1 : ) = 0
      END IF
      get_stat = .FALSE.
      stat_known = .FALSE.
      iorder = 0

!  if required, write out the problem

      IF ( printd ) WRITE( out, "( A, A6, /, ( 4( 2I5, ES10.2 ) ) )" ) prefix, &
     &  ' a ', ( ( i, A_col( l ), A_val( l ), l = A_ptr( i ),                  &
          A_ptr( i + 1 ) - 1 ), i = 1, m )

      IF ( control%balance_initial_complentarity ) THEN
        IF ( control%muzero <= zero ) THEN
          balance = one
        ELSE
          balance = control%muzero
        END IF
      END IF

!  record the initial point, move the starting point away from any bounds,
!  and move that for dual variables away from zero

      nbnds_x = 0

!  the variable is free

      IF ( printd ) THEN
        WRITE( out, "( /, A, 5X, 'i', 6x, 'x', 10X, 'x_l', 9X, 'x_u', 9X,      &
       &       'z_l', 9X, 'z_u')") prefix
        DO i = 1, dims%x_free
          WRITE( out, "( A, I6, ES12.4, 4( '      -     '))" ) prefix, i, X( i )
        END DO
      END IF

!  the variable is a non-negativity

      DO i = dims%x_free + 1, dims%x_l_start - 1
        nbnds_x = nbnds_x + 1
        X( i ) = MAX( X( i ), prfeas )
        IF ( control%balance_initial_complentarity ) THEN
          Z_l( i ) = balance / X( i )
        ELSE
          Z_l( i ) = MAX( ABS( Z( i ) ), dufeas )
        END IF
        IF ( printd ) WRITE( out, "( A, I6, 2ES12.4, '      -     ', ES12.4,   &
       &  '      -     ' )" ) prefix, i, X( i ), zero, Z_l( i )
      END DO

!  the variable has just a lower bound

      DO i = dims%x_l_start, dims%x_u_start - 1
        nbnds_x = nbnds_x + 1
        X( i ) = MAX( X( i ), X_l( i ) + prfeas )
        DIST_X_l( i ) = X( i ) - X_l( i )
        IF ( control%balance_initial_complentarity ) THEN
          Z_l( i ) = balance / DIST_X_l( i )
        ELSE
          Z_l( i ) = MAX( ABS( Z( i ) ), dufeas )
        END IF
        IF ( printd ) WRITE( out, "( A, I6, 2ES12.4, '      -     ', ES12.4,   &
       &  '      -     ' )" ) prefix, i, X( i ), X_l( i ), Z_l( i )
      END DO

!  the variable has both lower and upper bounds

      DO i = dims%x_u_start, dims%x_l_end

!  check that range constraints are not simply fixed variables,
!  and that the upper bounds are larger than the corresponing lower bounds

        IF ( X_u( i ) - X_l( i ) <= epsmch ) THEN
          inform%status = GALAHAD_error_bad_bounds
          GO TO 700
        END IF
        nbnds_x = nbnds_x + 2
        IF ( X_l( i ) + prfeas >= X_u( i ) - prfeas ) THEN
          X( i ) = half * ( X_l( i ) + X_u( i ) )
        ELSE
          X( i ) = MIN( MAX( X( i ), X_l( i ) + prfeas ), X_u( i ) - prfeas )
        END IF
        DIST_X_l( i ) = X( i ) - X_l( i ) ; DIST_X_u( i ) = X_u( i ) - X( i )
        IF ( control%balance_initial_complentarity ) THEN
          Z_l( i ) = balance / DIST_X_l( i )
          Z_u( i ) = - balance / DIST_X_u( i )
        ELSE
          Z_l( i ) = MAX(   ABS( Z( i ) ),   dufeas )
          Z_u( i ) = MIN( - ABS( Z( i ) ), - dufeas )
        END IF
        IF ( printd ) WRITE( out, "( A, I6, 5ES12.4 )" )                       &
             prefix, i, X( i ), X_l( i ), X_u( i ), Z_l( i ), Z_u( i )
      END DO

!  the variable has just an upper bound

      DO i = dims%x_l_end + 1, dims%x_u_end
        nbnds_x = nbnds_x + 1
        X( i ) = MIN( X( i ), X_u( i ) - prfeas )
        DIST_X_u( i ) = X_u( i ) - X( i )
        IF ( control%balance_initial_complentarity ) THEN
          Z_u( i ) = - balance / DIST_X_u( i )
        ELSE
          Z_u( i ) = MIN( - ABS( Z( i ) ), - dufeas )
        END IF
        IF ( printd ) WRITE( out, "( A, I6, ES12.4, '      -     ', ES12.4,    &
       &  '      -     ', ES12.4 )" ) prefix, i, X( i ), X_u( i ), Z_u( i )
      END DO

!  the variable is a non-positivity

      DO i = dims%x_u_end + 1, n
        nbnds_x = nbnds_x + 1
        X( i ) = MIN( X( i ), - prfeas )
        IF ( control%balance_initial_complentarity ) THEN
          Z_u( i ) = balance / X( i )
        ELSE
          Z_u( i ) = MIN( - ABS( Z( i ) ), - dufeas )
        END IF
        IF ( printd ) WRITE( out, "( A, I6, ES12.4, '      -     ', ES12.4,    &
       &  '      -     ',  ES12.4 )" ) prefix, i, X( i ), zero, Z_u( i )
      END DO

!  compute the value of the constraint, and their residuals

      nbnds_c = 0
      IF ( m > 0 ) THEN
        C_RES( : dims%c_equality ) = - C_l( : dims%c_equality )
        C_RES( dims%c_l_start : dims%c_u_end ) = zero
        CALL CCQP_AX( m, C_RES, m, a_ne, A_val, A_col, A_ptr,                   &
                      n, X, '+ ' )
        IF ( printd ) THEN
          WRITE( out, "( /, A, 5X,'i', 6x, 'c', 10X, 'c_l', 9X, 'c_u', 9X,     &
         &     'y_l', 9X, 'y_u' )") prefix
          DO i = 1, dims%c_l_start - 1
            WRITE( out, "( A, I6, 3ES12.4 )" )                                 &
              prefix, i, C_RES( i ), C_l( i ), C_u( i )
          END DO
        END IF

!  the constraint has just a lower bound

        DO i = dims%c_l_start, dims%c_u_start - 1
          nbnds_c = nbnds_c + 1

!  compute an appropriate scale factor

          IF ( use_scale_c ) THEN
            SCALE_C( i ) = MAX( one, ABS( C_RES( i ) ) )
          ELSE
            SCALE_C( i ) = one
          END IF

!  scale the bounds

          C_l( i ) = C_l( i ) / SCALE_C( i )

!  compute an appropriate initial value for the slack variable

          C( i ) = MAX( C_RES( i ) / SCALE_C( i ), C_l( i ) + prfeas )
          DIST_C_l( i ) = C( i ) - C_l( i )
          C_RES( i ) = C_RES( i ) - SCALE_C( i ) * C( i )
          IF ( control%balance_initial_complentarity ) THEN
            Y_l( i ) = balance / DIST_C_l( i )
          ELSE
            Y_l( i ) = MAX( ABS( SCALE_C( i ) * Y( i ) ),  dufeas )
          END IF
          IF ( printd ) WRITE( out,  "( A, I6, 2ES12.4, '      -     ',       &
         &  ES12.4, '      -    ' )" ) prefix, i, C_RES( i ), C_l( i ), Y_l( i )
        END DO

!  the constraint has both lower and upper bounds

        DO i = dims%c_u_start, dims%c_l_end

!  check that range constraints are not simply fixed variables,
!  and that the upper bounds are larger than the corresponing lower bounds

          IF ( C_u( i ) - C_l( i ) <= epsmch ) THEN
            inform%status = GALAHAD_error_bad_bounds
            GO TO 700
          END IF
          nbnds_c = nbnds_c + 2

!  compute an appropriate scale factor

          IF ( use_scale_c ) THEN
            SCALE_C( i ) = MAX( one, ABS( C_RES( i ) ) )
          ELSE
            SCALE_C( i ) = one
          END IF

!  scale the bounds

          C_l( i ) = C_l( i ) / SCALE_C( i )
          C_u( i ) = C_u( i ) / SCALE_C( i )

!  compute an appropriate initial value for the slack variable

          IF ( C_l( i ) + prfeas >= C_u( i ) - prfeas ) THEN
            C( i ) = half * ( C_l( i ) + C_u( i ) )
          ELSE
            C( i ) = MIN( MAX( C_RES( i ) / SCALE_C( i ), C_l( i ) + prfeas ), &
                               C_u( i ) - prfeas )
          END IF
          DIST_C_l( i ) = C( i ) - C_l( i )
          DIST_C_u( i ) = C_u( i ) - C( i )
          C_RES( i ) = C_RES( i ) - SCALE_C( i ) * C( i )
          IF ( control%balance_initial_complentarity ) THEN
            Y_l( i ) = balance / DIST_C_l( i )
            Y_u( i ) = - balance / DIST_C_u( i )
          ELSE
            Y_l( i ) = MAX(   ABS( SCALE_C( i ) * Y( i ) ),   dufeas )
            Y_u( i ) = MIN( - ABS( SCALE_C( i ) * Y( i ) ), - dufeas )
          END IF
          IF ( printd ) WRITE( out, "( A, I6, 5ES12.4 )" )                     &
            prefix, i, C_RES( i ), C_l( i ), C_u( i ), Y_l( i ), Y_u( i )
        END DO

!  the constraint has just an upper bound

        DO i = dims%c_l_end + 1, dims%c_u_end
          nbnds_c = nbnds_c + 1

!  compute an appropriate scale factor

          IF ( use_scale_c ) THEN
            SCALE_C( i ) = MAX( one, ABS( C_RES( i ) ) )
          ELSE
            SCALE_C( i ) = one
          END IF

!  scale the bounds

          C_u( i ) = C_u( i ) / SCALE_C( i )

!  compute an appropriate initial value for the slack variable

          C( i ) = MIN( C_RES( i ) / SCALE_C( i ), C_u( i ) - prfeas )
          DIST_C_u( i ) = C_u( i ) - C( i )
          C_RES( i ) = C_RES( i ) - SCALE_C( i ) * C( i )
          IF ( control%balance_initial_complentarity ) THEN
            Y_u( i ) = - balance / DIST_C_u( i )
          ELSE
            Y_u( i ) = MIN( - ABS( SCALE_C( i ) * Y( i ) ), - dufeas )
          END IF
          IF ( printd ) WRITE( out, "( A, I6, ES12.4, '      -     ', ES12.4,  &
         &  '      -     ', ES12.4 )") prefix, i, C_RES( i ), C_u( i ), Y_u( i )
        END DO
        inform%primal_infeasibility = MAXVAL( ABS( C_RES( : dims%c_u_end ) ) )
      ELSE
        inform%primal_infeasibility = zero
      END IF

!  record the starting vector

      IF ( stat_required ) THEN
        C_last( dims%c_l_start : dims%c_u_end )                                &
          = C( dims%c_l_start : dims%c_u_end )
        X_last = X

        DO i = dims%c_l_start, dims%c_u_start - 1
          Y_last( i ) = Y_l( i )
        END DO
        DO i = dims%c_u_start, dims%c_l_end
          IF ( DIST_C_l( i ) <= DIST_C_u( i ) ) THEN
            Y_last( i ) = Y_l( i )
          ELSE
            Y_last( i ) = Y_u( i )
          END IF
        END DO
        DO i = dims%c_l_end + 1, dims%c_u_end
          Y_last( i ) = Y_u( i )
        END DO

        Z_last( : dims%x_free ) = zero
        DO i = dims%x_free + 1, dims%x_u_start - 1
          Z_last( i ) = Z_l( i )
        END DO
        DO i = dims%x_u_start, dims%x_l_end
          IF ( DIST_X_l( i ) <= DIST_X_u( i ) ) THEN
            Z_last( i ) = Z_l( i )
          ELSE
            Z_last( i ) = Z_u( i )
          END IF
        END DO
        DO i = dims%x_l_end + 1, n
          Z_last( i ) = Z_u( i )
        END DO
      END IF

!  compute the initial objective value

      IF ( Hessian_kind == 0 ) THEN
        inform%obj = f
      ELSE IF ( Hessian_kind == 1 ) THEN
        IF ( target_kind == 0 ) THEN
          inform%obj = f + half * SUM( X ** 2 )
        ELSE IF ( target_kind == 1 ) THEN
          inform%obj = f + half * SUM( ( X - one ) ** 2 )
        ELSE
          inform%obj = f + half * SUM( ( X - X0 ) ** 2 )
        END IF
      ELSE IF ( Hessian_kind == 2 ) THEN
        IF ( target_kind == 0 ) THEN
          inform%obj = f + half * SUM( ( WEIGHT * X ) ** 2 )
        ELSE IF ( target_kind == 1 ) THEN
          inform%obj = f + half * SUM( ( WEIGHT * ( X - one ) ) ** 2 )
        ELSE
          inform%obj = f + half * SUM( ( WEIGHT * ( X - X0 ) ) ** 2 )
        END IF
      ELSE
        IF ( lbfgs ) THEN
          CALL LMS_apply_lbfgs( X, H_lm, i, RESULT = RHS( : n ) )
          curv = DOT_PRODUCT( X, RHS( : n ) )

! DX = zero
! DO i = 1, n
!   DX( i ) = one
!   CALL LMS_apply_lbfgs( DX, H_lm, j, RESULT = WORK_n )
!   WRITE(6,"( ' H_lm column ', I0, /, ( 4ES18.10 ) )" ) i, WORK_n
!   DX( i ) = zero
! END DO

        ELSE
          curv = zero
          DO i = 1, n
            xi = X( i )
            IF ( diagonal_hessian ) THEN
              curv = curv + xi * xi * H_val( i )
            ELSE
              DO l = H_ptr( i ), H_ptr( i + 1 ) - 1
                j = H_col( l )
                IF ( i == j ) THEN
                  curv = curv + xi * xi * H_val( l )
                ELSE
                  curv = curv + two * xi * X( j ) * H_val( l )
                END IF
              END DO
            END IF
          END DO
        END IF
        inform%obj = f + half * curv
      END IF

!  also compute the largest component of g

      IF ( gradient_kind == 1 ) THEN
        inform%obj = inform%obj + SUM( X )
        gmax = one
      ELSE IF ( gradient_kind /= 0 ) THEN
        inform%obj = inform%obj + DOT_PRODUCT( G, X )
        gmax = MAXVAL( ABS( G( : n ) ) )
      ELSE
        gmax = zero
      END IF

!  find the largest components of A and H

      IF ( a_ne > 0 ) THEN
        amax = MAXVAL( ABS( A_val( : a_ne ) ) )
      ELSE
        amax = zero
      END IF

      IF ( hessian_kind < 0 ) THEN
        IF ( lbfgs ) THEN
          hmax = ABS( H_lm%delta )
        ELSE IF ( h_ne > 0 ) THEN
          IF ( diagonal_hessian ) THEN
            hmax = MAXVAL( ABS( H_val( : n ) ) )
          ELSE
            hmax = MAXVAL( ABS( H_val( : h_ne ) ) )
          END IF
        ELSE
          hmax = zero
        END IF
      ELSE
        hmax = zero
      END IF

      IF ( printi .AND. m > 0 ) WRITE( out,                                    &
         "( /, A, '  maximum element of A =', ES11.4 )" ) prefix, amax
      IF ( printi ) WRITE( out, "( /, A, '  maximum element of H =', ES11.4,   &
    &    /, A, '  maximum element of G =', ES11.4 )") prefix, hmax, prefix, gmax

!  test to see if we are feasible

      inform%feasible = inform%primal_infeasibility <= control%stop_abs_p
      pjgnrm = infinity

      IF ( inform%feasible ) THEN
        IF ( printi ) WRITE( out, 2070 ) prefix
        IF ( control%just_feasible ) THEN
          inform%status = GALAHAD_ok
          GO TO 500
        END IF
        IF ( Hessian_kind == 0 .AND. gradient_kind == 0 )                      &
          inform%potential = CCQP_potential_value( dims, n,                     &
                                   X, DIST_X_l, DIST_X_u, DIST_C_l, DIST_C_u )
      END IF

!  compute the gradient of the Lagrangian function.

      CALL CCQP_Lagrangian_gradient( dims, n, m, X, Y, Y_l, Y_u, Z_l, Z_u,      &
                                     a_ne, A_val, A_col, A_ptr,                &
                                     DIST_X_l, DIST_X_u, DIST_C_l, DIST_C_u,   &
                                     GRAD_L( dims%x_s : dims%x_e ),            &
                                     control%getdua, dufeas,                   &
                                     control%perturb_h,                        &
                                     Hessian_kind, gradient_kind,              &
                                     target_kind,                              &
                                     h_ne = h_ne, H_val = H_val,               &
                                     H_col = H_col, H_ptr = H_ptr,             &
                                     H_lm = H_lm, G = G,                       &
                                     WEIGHT = WEIGHT, X0 = X0 )

!  evaluate the merit function

      tau = MAX( control%tau, zero )
      merit = CCQP_merit_value( dims, n, m, X, Y, Y_l, Y_u, Z_l, Z_u,           &
                               DIST_X_l, DIST_X_u, DIST_C_l, DIST_C_u,         &
                               GRAD_L( dims%x_s : dims%x_e ), C_RES,           &
                               tau, res_primal, inform%dual_infeasibility,     &
                               res_primal_dual, res_cs )

!  find the max-norm of the residual

      nbnds = nbnds_x + nbnds_c
      IF ( printi .AND. use_scale_c .AND. m > 0 .AND.                          &
           dims%c_l_start <= dims%c_u_end )                                    &
        WRITE( out, "( A, '  largest/smallest scale factor', 2ES11.4 )" )      &
          prefix, MAXVAL( SCALE_C ), MINVAL( SCALE_C )

!  compute the complementary slackness

      slknes_x = DOT_PRODUCT( X( dims%x_free + 1 : dims%x_l_start - 1 ),       &
                              Z_l( dims%x_free + 1 : dims%x_l_start - 1 ) ) +  &
                 DOT_PRODUCT( DIST_X_l( dims%x_l_start : dims%x_l_end ),       &
                              Z_l( dims%x_l_start : dims%x_l_end ) ) -         &
                 DOT_PRODUCT( DIST_X_u( dims%x_u_start : dims%x_u_end ),       &
                              Z_u( dims%x_u_start : dims%x_u_end ) ) +         &
                 DOT_PRODUCT( X( dims%x_u_end + 1 : n ),                       &
                              Z_u( dims%x_u_end + 1 : n ) )
      slknes_c = DOT_PRODUCT( DIST_C_l( dims%c_l_start : dims%c_l_end ),       &
                              Y_l( dims%c_l_start : dims%c_l_end ) ) -         &
                 DOT_PRODUCT( DIST_C_u( dims%c_u_start : dims%c_u_end ),       &
                              Y_u( dims%c_u_start : dims%c_u_end ) )
      slknes = slknes_x + slknes_c

      slkmin_x = MIN( MINVAL( X( dims%x_free + 1 : dims%x_l_start - 1 ) *      &
                              Z_l( dims%x_free + 1 : dims%x_l_start - 1 ) ),   &
                      MINVAL( DIST_X_l( dims%x_l_start : dims%x_l_end ) *      &
                              Z_l( dims%x_l_start : dims%x_l_end ) ),          &
                      MINVAL( - DIST_X_u( dims%x_u_start : dims%x_u_end ) *    &
                              Z_u( dims%x_u_start : dims%x_u_end ) ),          &
                      MINVAL( X( dims%x_u_end + 1 : n ) *                      &
                              Z_u( dims%x_u_end + 1 : n ) ) )
      slkmin_c = MIN( MINVAL( DIST_C_l( dims%c_l_start : dims%c_l_end ) *      &
                              Y_l( dims%c_l_start : dims%c_l_end ) ),          &
                      MINVAL( - DIST_C_u( dims%c_u_start : dims%c_u_end ) *    &
                              Y_u( dims%c_u_start : dims%c_u_end ) ) )
      slkmin = MIN( slkmin_x, slkmin_c )

      slkmax_x = MAX( MAXVAL( X( dims%x_free + 1 : dims%x_l_start - 1 ) *      &
                              Z_l( dims%x_free + 1 : dims%x_l_start - 1 ) ),   &
                      MAXVAL( DIST_X_l( dims%x_l_start : dims%x_l_end ) *      &
                              Z_l( dims%x_l_start : dims%x_l_end ) ),          &
                      MAXVAL( - DIST_X_u( dims%x_u_start : dims%x_u_end ) *    &
                              Z_u( dims%x_u_start : dims%x_u_end ) ),          &
                      MAXVAL( X( dims%x_u_end + 1 : n ) *                      &
                              Z_u( dims%x_u_end + 1 : n ) ) )
      slkmax_c = MAX( MAXVAL( DIST_C_l( dims%c_l_start : dims%c_l_end ) *      &
                              Y_l( dims%c_l_start : dims%c_l_end ) ),          &
                      MAXVAL( - DIST_C_u( dims%c_u_start : dims%c_u_end ) *    &
                              Y_u( dims%c_u_start : dims%c_u_end ) ) )

      p_min = MIN( MINVAL( X( dims%x_free + 1 : dims%x_l_start - 1 ) ),        &
                   MINVAL( DIST_X_l( dims%x_l_start : dims%x_l_end ) ),        &
                   MINVAL( DIST_X_u( dims%x_u_start : dims%x_u_end ) ),        &
                   MINVAL( - X( dims%x_u_end + 1 : n ) ),                      &
                   MINVAL( DIST_C_l( dims%c_l_start : dims%c_l_end ) ),        &
                   MINVAL( DIST_C_u( dims%c_u_start : dims%c_u_end ) ) )

      p_max = MAX( MAXVAL( X( dims%x_free + 1 : dims%x_l_start - 1 ) ),        &
                   MAXVAL( DIST_X_l( dims%x_l_start : dims%x_l_end ) ),        &
                   MAXVAL( DIST_X_u( dims%x_u_start : dims%x_u_end ) ),        &
                   MAXVAL( - X( dims%x_u_end + 1 : n ) ),                      &
                   MAXVAL( DIST_C_l( dims%c_l_start : dims%c_l_end ) ),        &
                   MAXVAL( DIST_C_u( dims%c_u_start : dims%c_u_end ) ) )

      d_min = MIN( MINVAL(   Z_l( dims%x_free + 1 : dims%x_l_end ) ),          &
                   MINVAL( - Z_u( dims%x_u_start : n ) ),                      &
                   MINVAL(   Y_l( dims%c_l_start : dims%c_l_end ) ),           &
                   MINVAL( - Y_u( dims%c_u_start : dims%c_u_end ) ) )

      d_max = MAX( MAXVAL(   Z_l( dims%x_free + 1 : dims%x_l_end ) ),          &
                   MAXVAL( - Z_u( dims%x_u_start : n ) ),                      &
                   MAXVAL(   Y_l( dims%c_l_start : dims%c_l_end ) ),           &
                   MAXVAL( - Y_u( dims%c_u_start : dims%c_u_end ) ) )

!  record the slackness and the deviation from the central path

      IF ( nbnds_x > 0 ) THEN
        slknes_x = slknes_x / nbnds_x
      ELSE
        slknes_x = zero
      END IF

      IF ( nbnds_c > 0 ) THEN
        slknes_c = slknes_c / nbnds_c
      ELSE
        slknes_c = zero
      END IF

      IF ( nbnds > 0 ) THEN
        IF (  res_primal_dual > zero ) THEN
          gamma_f = control%gamma_f * slknes / res_primal_dual
        ELSE
          gamma_f = one
        END IF
        slknes = slknes / nbnds
        gamma_c = control%gamma_c * slkmin / slknes
      ELSE
        gamma_f = zero ; slknes = zero ; gamma_c = zero
      END IF

      IF ( printw .AND. nbnds > 0 ) THEN
        WRITE( out, 2130 )                         &
          prefix, slknes, prefix, slknes_x, prefix, slknes_c, prefix, slkmin_x,&
          slkmax_x, prefix, slkmin_c, slkmax_c, prefix, p_min, p_max, prefix,  &
          d_min, d_max
        WRITE( out, "( A, 31X, ' min x gap = ', ES12.4, /,                     &
       &               A, 31X, ' min c gap = ', ES12.4 )" )                    &
          prefix, MINVAL( X_u( dims%x_u_start : dims%x_l_end ) -               &
                          X_l( dims%x_u_start : dims%x_l_end ) ),              &
          prefix, MINVAL( C_u( dims%c_u_start : dims%c_l_end ) -               &
                          C_l( dims%c_u_start : dims%c_l_end ) )
        WRITE( out, "( A, 31X, ' gamma_c,f = ', 2ES12.4 )" )                   &
          prefix, gamma_c, gamma_f
      END IF

!  set the initial barrier parameter

      sigma = sigma_max
      IF ( control%muzero < zero ) THEN
        IF ( control%arc == 2 ) THEN
          mu = slknes
          sigma = one
        ELSE
          mu = sigma * slknes
        END IF
      ELSE
        mu = control%muzero
      END IF
      inform%complementary_slackness = slknes

      inform%init_primal_infeasibility = inform%primal_infeasibility
      inform%init_dual_infeasibility = inform%dual_infeasibility
      inform%init_complementary_slackness = inform%complementary_slackness

!  compute the binomial coefficients b_i^k = b_i^{k-1} + b_{i-1}^{k-1}

      IF ( order > 1 ) THEN
        BINOMIAL( 0, 1 ) = one
        DO j = 2, order
          BINOMIAL( j - 1, j - 1 ) = one
          BINOMIAL( 0, j ) = one
          DO i = 1, j - 1
            BINOMIAL( i, j ) = BINOMIAL( i, j - 1 ) + BINOMIAL( i - 1, j - 1 )
          END DO
        END DO
      END IF

!  prepare for the major iteration

      inform%iter = 0 ; inform%nfacts = 0
      IF ( printw ) WRITE( out, "( /, A, ' merit function value = ',           &
     &     ES12.4 )" ) prefix, merit

      IF ( n == 0 ) THEN
        inform%status = GALAHAD_ok ; GO TO 600
      END IF
      merit_best = merit ; it_best = 0

!  compute stopping tolerances

      stop_p = MAX( control%stop_abs_p,                                        &
                    control%stop_rel_p * inform%primal_infeasibility )
      stop_d = MAX( control%stop_abs_d,                                        &
                    control%stop_rel_d * inform%dual_infeasibility )
      stop_c = MAX( control%stop_abs_c,                                        &
                    control%stop_rel_c * inform%complementary_slackness )

!  test for convergence

      CALL CPU_TIME( time_record )
      CALL CHECKPOINT( inform%iter, time_record - time_start,                  &
         MAX( inform%primal_infeasibility,                                     &
         inform%dual_infeasibility, inform%complementary_slackness ),          &
         inform%checkpointsIter, inform%checkpointsTime, 1, 16 )
      IF ( inform%primal_infeasibility <= stop_p .AND.                         &
           inform%dual_infeasibility <= stop_d .AND.                           &
           inform%complementary_slackness <= stop_c ) THEN
        inform%status = GALAHAD_ok ; GO TO 600
      END IF

!  ===================================================
!  Analyse the sparsity pattern of the required matrix
!  ===================================================

      re = ' ' ; nbact = 0
      pivot_tol = SBLS_control%SLS_control%relative_pivot_tolerance
      min_pivot_tol = SBLS_control%SLS_control%minimum_pivot_tolerance
      relative_pivot_tol = pivot_tol
      maxpiv = pivot_tol >= half

      IF ( printi ) WRITE( out,                                                &
          "(  /, A, '  Primal    convergence tolerance =', ES11.4,             &
         &    /, A, '  Dual      convergence tolerance =', ES11.4,             &
         &    /, A, '  Slackness convergence tolerance =', ES11.4 )" )         &
              prefix, stop_p, prefix, stop_d, prefix, stop_c

!  complete A

      DO i = 1, dims%nc
        A_sbls%val( a_ne + i ) = - SCALE_C( dims%c_equality + i )
      END DO

!  ---------------------------------------------------------------------
!  ---------------------- Start of Major Iteration ---------------------
!  ---------------------------------------------------------------------

      puiseux = control%puiseux
      IF ( puiseux ) THEN
        pui = 'P'
      ELSE
        pui = 'T'
      END IF

      DO

!  =======
!  STEP 1:
!  =======

!  =====================================================================
!  -*-*-*-*-*-*-*-*-*-*-*-   Test for Optimality   -*-*-*-*-*-*-*-*-*-*-
!  =====================================================================

!  print a summary of the iteration

        CALL CLOCK_TIME( clock_now ) ; clock_now = clock_now - clock_start
        IF ( printi ) THEN
          IF ( inform%iter > 0 ) THEN
            IF ( printt .OR. ( printi .AND.                                    &
               inform%iter == start_print ) ) WRITE( out, 2000 ) prefix
            WRITE( out, 2030 ) prefix, inform%iter, re,                        &
             inform%primal_infeasibility, inform%dual_infeasibility,           &
             inform%complementary_slackness, inform%obj, alpha, mu,            &
             iorder, pui, arc, nbact, clock_now
          ELSE
            WRITE( out, 2000 ) prefix
            WRITE( out, 2020 ) prefix, inform%iter, re,                        &
              inform%primal_infeasibility, inform%dual_infeasibility,          &
              inform%complementary_slackness, inform%obj, mu, clock_now
          END IF

          IF ( printd ) THEN
            WRITE( out, 2100 ) prefix, ' X ', X
            IF ( dims%c_l_start <= dims%c_l_end ) WRITE( out, 2100 ) prefix,   &
                ' C_l ', DIST_C_l( dims%c_l_start : dims%c_l_end )
            IF ( dims%c_u_start <= dims%c_u_end ) WRITE( out, 2100 ) prefix,   &
                ' C_u ', DIST_C_u( dims%c_u_start : dims%c_u_end )
            IF ( dims%x_free + 1 <= dims%x_l_end ) WRITE( out, 2100 )          &
              prefix,  ' Z_l ', Z_l( dims%x_free + 1 : dims%x_l_end )
            IF (  dims%x_u_start <= n ) WRITE( out, 2100 )                     &
              prefix, ' Z_u ', Z_u( dims%x_u_start :  n )
          END IF
        END IF

        IF ( control%arc == 2 .OR.                                             &
             ( control%arc == 3 .AND. mu <= tenm4 ) ) THEN
          arc = 'ZS'
        ELSE IF ( control%arc == 4 .OR.                                        &
             ( control%arc == 5 .AND. mu <= tenm10 ) ) THEN
          arc = 'ZP'
          puiseux = .TRUE.
        ELSE
          arc = 'Zh'
        END IF

!  test for optimality

!  find how many primal optimality conditions are violated in the
!  sense that we require (componentwise)
!   | primal optimality | <= MAX( stop_rel * | typical value |, stop_abs )

        IF ( m > 0 ) THEN
          RHS( dims%y_s : dims%c_e + dims%c_equality ) =                       &
            ABS( C_l( : dims%c_equality ) )
          RHS( dims%c_e + dims%c_l_start : dims%c_e +  dims%c_u_end ) =        &
            ABS( SCALE_C * C )
          CALL CCQP_abs_AX( m, RHS( dims%y_s : dims%y_e ), m, a_ne,             &
                           A_val, A_col, A_ptr, n, X, ' ' )
          IF ( printw ) WRITE( out, "( A, '  abs(primal) ', ES12.4 )" )        &
            prefix, MAXVAL( RHS( dims%y_s : dims%y_e ) )
          primal_nonopt = COUNT( ABS( C_RES ) > MAX( control%stop_abs_p,       &
            RHS( dims%y_s : dims%y_e ) * control%stop_rel_p ) )
        ELSE
          primal_nonopt = 0
        END IF

!  now find how many dual optimality conditions are violated in the
!  sense that we require (componentwise)
!   | dual optimality | <= MAX( stop_rel * | typical value |, stop_abs )

!  evaluate abs(dual)

        IF ( Hessian_kind == 0 ) THEN
          RHS( : n ) = zero
        ELSE IF ( Hessian_kind == 1 ) THEN
          IF ( target_kind == 0 ) THEN
            RHS( : n ) = X
          ELSE IF ( target_kind == 1 ) THEN
            RHS( : n ) = X - one
          ELSE
            RHS( : n ) = X - X0
          END IF
        ELSE IF ( Hessian_kind == 2 ) THEN
          IF ( target_kind == 0 ) THEN
            RHS( : n ) = ( WEIGHT ** 2 ) * X
          ELSE IF ( target_kind == 1 ) THEN
            RHS( : n ) = ( WEIGHT ** 2 ) * ( X - one )
          ELSE
            RHS( : n ) = ( WEIGHT ** 2 ) * ( X - X0 )
          END IF
        ELSE
          IF ( lbfgs ) THEN  ! this is not quite right ... but not crucial
            CALL LMS_apply_lbfgs( ABS( X ), H_lm, i, RESULT = RHS( : n ) )
            RHS( : n ) = ABS( RHS( : n ) )
          ELSE
            IF ( diagonal_hessian ) THEN
              RHS( : n ) = H_val( : n ) * ABS( X( : n ) )
            ELSE
              RHS( : n ) = zero
              CALL CCQP_abs_HX( dims, n, RHS( : n ) ,                           &
                               h_ne, H_val, H_col, H_ptr, X )
            END IF
          END IF
        END IF
        IF ( control%perturb_h /= zero )                                       &
          RHS( : n ) = RHS( : n ) + control%perturb_h * X
        IF ( gradient_kind == 1 ) THEN
          RHS( : n ) = RHS( : n ) + one
        ELSE IF ( gradient_kind /= 0 ) THEN
          RHS( : n ) = RHS( : n ) + ABS( G )
        END IF
        CALL CCQP_abs_AX( n, RHS( : n ), m, a_ne, A_val, A_col, A_ptr, m, Y,    &
                          'T' )
        dual_nonopt = 0
        DO i = 1, dims%x_free
          IF ( ABS( GRAD_L( i ) ) >                                            &
            MAX( control%stop_abs_d, RHS( i ) * control%stop_rel_d ) )         &
              dual_nonopt = dual_nonopt + 1
        END DO
        DO i = dims%x_free + 1, dims%x_u_start - 1
          RHS( i ) = RHS( i ) + ABS( Z_l( i ) )
          IF ( ABS( GRAD_L( i ) - Z_l( i ) ) >                                 &
            MAX( control%stop_abs_d, RHS( i ) * control%stop_rel_d ) )         &
              dual_nonopt = dual_nonopt + 1
        END DO
        DO i = dims%x_u_start, dims%x_l_end
          RHS( i ) = RHS( i ) + ABS( Z_l( i ) ) + ABS( Z_u( i ) )
          IF ( ABS( GRAD_L( i ) - Z_l( i ) - Z_u( i ) ) >                      &
            MAX( control%stop_abs_d, RHS( i ) * control%stop_rel_d ) )         &
              dual_nonopt = dual_nonopt + 1
        END DO
        DO i = dims%x_l_end + 1, n
          RHS( i ) = RHS( i ) + ABS( Z_u( i ) )
          IF ( ABS( GRAD_L( i ) - Z_u( i ) ) >                                 &
            MAX( control%stop_abs_d, RHS( i ) * control%stop_rel_d ) )         &
              dual_nonopt = dual_nonopt + 1
        END DO

        DO i = dims%c_l_start, dims%c_u_start - 1
          RHS( dims%c_b + i ) = ABS( Y( i ) ) + ABS( Y_l( i ) )
          IF ( ABS( Y( i ) - Y_l( i ) ) >  MAX( control%stop_abs_d,            &
            RHS( dims%c_b + i ) * control%stop_rel_d ) )                       &
              dual_nonopt = dual_nonopt + 1
        END DO
        DO i = dims%c_u_start, dims%c_l_end
          RHS( dims%c_b + i ) = ABS( Y( i ) ) + ABS( Y_l( i ) ) + ABS( Y_u( i ))
          IF ( ABS( Y( i ) - Y_l( i ) - Y_u( i ) ) > MAX( control%stop_abs_d,  &
            RHS( dims%c_b + i ) * control%stop_rel_d ) )                       &
              dual_nonopt = dual_nonopt + 1
        END DO
        DO i = dims%c_l_end + 1, dims%c_u_end
          RHS( dims%c_b + i ) = ABS( Y( i ) ) + ABS( Y_u( i ) )
          IF ( ABS( Y( i ) - Y_u( i ) ) >  MAX( control%stop_abs_d,            &
            RHS( dims%c_b + i ) * control%stop_rel_d ) )                       &
              dual_nonopt = dual_nonopt + 1
        END DO

        IF ( printw ) WRITE( out, "( A, '  abs(dual) ', ES12.4 )" )            &
            prefix, MAXVAL( RHS( dims%x_s : dims%c_e ) )

!  finally find how many complementarity conditions are violated in the
!  sense that we require (componentwise)
!   | complementarity | <= MAX( stop_rel * | typical value |, stop_abs )

        cs_nonopt = 0
        cs = zero
        DO i = dims%x_free + 1, dims%x_l_start - 1
          cs = MAX( cs, ABS( Z_l( i ) ), ABS( X( i ) ) )
          IF ( ABS( Z_l( i ) * X( i ) ) > MAX( control%stop_abs_c,             &
                 MAX( ABS( Z_l( i ) ), ABS( X( i ) ) ) * control%stop_rel_c ) )&
                   cs_nonopt = cs_nonopt + 1
        END DO
        DO i = dims%x_l_start, dims%x_l_end
          cs = MAX( cs, ABS( Z_l( i ) ), ABS( DIST_X_l( i ) ) )
          IF ( ABS( Z_l( i ) * DIST_X_l( i ) ) > MAX( control%stop_abs_c,      &
                 MAX( ABS( Z_l( i ) ), ABS( DIST_X_l( i ) ) ) *                &
                   control%stop_rel_c ) ) cs_nonopt = cs_nonopt + 1
        END DO
        DO i = dims%x_u_start, dims%x_u_end
          cs =  MAX( cs, ABS( Z_u( i ) ), ABS( DIST_X_u( i ) ) )
          IF ( ABS( Z_u( i ) * DIST_X_u( i ) ) > MAX( control%stop_abs_c,      &
                 MAX( ABS( Z_u( i ) ), ABS( DIST_X_u( i ) ) ) *                &
                   control%stop_rel_c ) ) cs_nonopt = cs_nonopt + 1
        END DO
        DO i = dims%x_u_end + 1, n
          cs =  MAX( cs,  ABS( Z_u( i ) ), ABS( X( i ) ) )
          IF ( ABS( Z_u( i ) * X( i ) ) > MAX( control%stop_abs_c,             &
                 MAX( ABS( Z_u( i ) ), ABS( X( i ) ) ) * control%stop_rel_c ) )&
                   cs_nonopt = cs_nonopt + 1
        END DO

        DO i = dims%c_l_start, dims%c_l_end
          cs =  MAX( cs,  ABS( Y_l( i ) ), ABS( DIST_C_l( i ) ) )
          IF ( ABS( Y_l( i ) * DIST_C_l( i ) ) > MAX( control%stop_abs_c,      &
                 MAX( ABS( Y_l( i ) ), ABS( DIST_C_l( i ) ) ) *                &
                   control%stop_rel_c ) ) cs_nonopt = cs_nonopt + 1
        END DO
        DO i = dims%c_u_start, dims%c_u_end
          cs =  MAX( cs, ABS( Y_u( i ) ), ABS( DIST_C_u( i ) ) )
          IF ( ABS( Y_u( i ) * DIST_C_u( i ) ) > MAX( control%stop_abs_c,      &
                 MAX( ABS( Y_u( i ) ), ABS( DIST_C_u( i ) ) ) *                &
                   control%stop_rel_c ) ) cs_nonopt = cs_nonopt + 1
          IF ( ABS( Y_u( i ) * DIST_C_u( i ) ) > MAX( control%stop_abs_c,      &
                 MAX( ABS( Y_u( i ) ), ABS( DIST_C_u( i ) ) ) *                &
                   control%stop_rel_c ) ) THEN
          END IF
        END DO

        IF ( printw ) WRITE( out, "( A, '  abs(comp) ', ES12.4 )" )            &
            prefix, cs

        IF ( printw ) WRITE( out, "( A, '  # primal, dual, complementarity',   &
       &                     ' violations ' , I0, 1X, I0, 1X, I0 )" )          &
                                 prefix, primal_nonopt, dual_nonopt, cs_nonopt

!  test for optimality

        CALL CPU_TIME( time_record )
        CALL CHECKPOINT( inform%iter, time_record - time_start,                &
           MAX( inform%primal_infeasibility,                                   &
           inform%dual_infeasibility, inform%complementary_slackness ),        &
           inform%checkpointsIter, inform%checkpointsTime, 1, 16 )
        IF ( primal_nonopt + dual_nonopt + cs_nonopt == 0 ) THEN
          inform%status = GALAHAD_ok ; GO TO 600
        END IF

!  test to see if more than maxit iterations have been performed

        inform%iter = inform%iter + 1
        IF ( inform%iter > control%maxit ) THEN
          inform%status = GALAHAD_error_max_iterations ; GO TO 600
        END IF

!  check that the CPU time limit has not been reached

        CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
        IF ( ( control%cpu_time_limit >= zero .AND.                            &
             REAL( time_now - time_start, wp ) > control%cpu_time_limit ) .OR. &
             ( control%clock_time_limit >= zero .AND.                          &
               clock_now - clock_start > control%clock_time_limit ) ) THEN
          inform%status = GALAHAD_error_cpu_limit ; GO TO 600
        END IF

        IF ( inform%iter == start_print ) THEN
          printe = set_printe ; printi = set_printi ; printt = set_printt
          printw = set_printw ; printd = set_printd
          print_level = control%print_level
        END IF

        IF ( inform%iter == stop_print + 1 ) THEN
          printe = .FALSE. ; printi = .FALSE. ; printt = .FALSE.
          printw = .FALSE. ; printd = .FALSE.
          print_level = 0
        END IF

!  Test to see whether the method has stalled

        IF ( merit <= reduce_infeas * merit_best ) THEN
          merit_best = merit
          it_best = 0
        ELSE
          it_best = it_best + 1
          IF ( it_best > infeas_max ) THEN
            IF ( inform%feasible ) THEN
              inform%status = GALAHAD_error_unbounded ; GO TO 600
            ELSE
              IF ( printi ) WRITE( out, "( /, A, ' ================= the ',    &
             &  'problem appears to be infeasible ================= ', / )" )  &
               prefix
              inform%status = GALAHAD_error_primal_infeasible ; GO TO 600
            END IF
          END IF
        END IF

!  test to see if the potential function appears to be unbounded from below

        IF ( inform%feasible .AND. Hessian_kind == 0 .AND.                     &
             gradient_kind == 0 ) THEN
          IF ( inform%potential < control%potential_unbounded *                &
               ( ( dims%x_l_end - dims%x_free ) +                              &
               ( n -  dims%x_u_start + 1 ) +                                   &
               ( dims%c_l_end - dims%c_l_start + 1 ) +                         &
               ( dims%c_u_end - dims%c_u_start + 1 ) ) ) THEN
            inform%status = GALAHAD_error_no_center ; GO TO 600
          END IF

!  compute the Hessian matrix of the barrier terms

!  Special case for the analytic center

!  problem variables:

          DO i = dims%x_free + 1, dims%x_l_start - 1
            BARRIER_X( i ) =  mu / X( i ) ** 2
          END DO
          DO i = dims%x_l_start, dims%x_u_start - 1
            BARRIER_X( i ) = mu / DIST_X_l( i ) ** 2
          END DO
          DO i = dims%x_u_start, dims%x_l_end
            BARRIER_X( i ) = mu / DIST_X_l( i ) ** 2                           &
                             + mu / DIST_X_u( i ) ** 2
          END DO
          DO i = dims%x_l_end + 1, dims%x_u_end
            BARRIER_X( i ) = mu / DIST_X_u( i ) ** 2
          END DO
          DO i = dims%x_u_end + 1, n
            BARRIER_X( i ) = mu / X( i ) ** 2
          END DO

!  slack variables:

          BARRIER_C( dims%c_l_start : dims%c_u_end ) = zero
          DO i = dims%c_l_start, dims%c_u_start - 1
            BARRIER_C( i ) = mu / DIST_C_l( i ) ** 2
          END DO
          DO i = dims%c_u_start, dims%c_l_end
            BARRIER_C( i ) = mu / DIST_C_l( i ) ** 2                           &
                             + mu / DIST_C_u( i ) ** 2
          END DO
          DO i = dims%c_l_end + 1, dims%c_u_end
            BARRIER_C( i ) = mu / DIST_C_u( i ) ** 2
          END DO

!  General case

        ELSE

!  problem variables:

          DO i = dims%x_free + 1, dims%x_l_start - 1
            IF ( ABS( X( i ) ) <= degen_tol .AND. printd )                     &
              WRITE( out, "( A, ' i = ', i6, ' DIST X, Z ', 2ES12.4 )" )       &
                prefix, i, X( i ), Z_l( i )
            BARRIER_X( i ) = Z_l( i ) / X( i )
          END DO
          DO i = dims%x_l_start, dims%x_u_start - 1
            IF ( ABS( DIST_X_l( i ) ) <= degen_tol .AND. printd )              &
              WRITE( out, "( A, ' i = ', i6, ' DIST X, Z ', 2ES12.4 )" )       &
                prefix, i, DIST_X_l( i ), Z_l( i )
            BARRIER_X( i ) = Z_l( i ) / DIST_X_l( i )
          END DO
          DO i = dims%x_u_start, dims%x_l_end
            IF ( ABS( DIST_X_l( i ) ) <= degen_tol .AND. printd )              &
              WRITE( out, "( A, ' i = ', i6, ' DIST X, Z ', 2ES12.4 )" )       &
                prefix, i, DIST_X_l( i ), Z_l( i )
            IF ( ABS( DIST_X_u( i ) ) <= degen_tol .AND. printd )              &
              WRITE( out, "( A, ' i = ', i6, ' DIST X, Z ', 2ES12.4 )" )       &
                prefix, i, DIST_X_u( i ), Z_u( i )
            BARRIER_X( i ) = Z_l( i ) / DIST_X_l( i ) - Z_u( i ) / DIST_X_u( i )
          END DO
          DO i = dims%x_l_end + 1, dims%x_u_end
            IF ( ABS( DIST_X_u( i ) ) <= degen_tol .AND. printd )              &
              WRITE( out, "( A, ' i = ', i6, ' DIST X, Z ', 2ES12.4 )" )       &
                prefix, i, DIST_X_u( i ), Z_u( i )
            BARRIER_X( i ) = - Z_u( i ) / DIST_X_u( i )
          END DO
          DO i = dims%x_u_end + 1, n
            IF ( ABS( X( i ) ) <= degen_tol .AND. printd )                     &
              WRITE( out, "( A, ' i = ', i6, ' DIST X, Z ', 2ES12.4 )" )       &
                prefix, i, X( i ), Z_u( i )
            BARRIER_X( i ) = Z_u( i ) / X( i )
          END DO

!  slack variables:

          BARRIER_C( dims%c_l_start : dims%c_u_end ) = zero
          DO i = dims%c_l_start, dims%c_u_start - 1
            IF ( ABS( DIST_C_l( i ) ) <= degen_tol .AND. printd )              &
              WRITE( out, "( A, ' i = ', i6, ' DIST C, Y ', 2ES12.4 )" )       &
                prefix, i, DIST_C_l( i ), Y_l( i )
            BARRIER_C( i ) = Y_l( i ) / DIST_C_l( i )
          END DO
          DO i = dims%c_u_start, dims%c_l_end
            IF ( ABS( DIST_C_l( i ) ) <= degen_tol .AND. printd )              &
              WRITE( out, "( A, ' i = ', i6, ' DIST C, Y ', 2ES12.4 )" )       &
                prefix, i, DIST_C_l( i ), Y_l( i )
            IF ( ABS( DIST_C_u( i ) ) <= degen_tol .AND. printd )              &
              WRITE( out, "( A, ' i = ', i6, ' DIST C, Y ', 2ES12.4 )" )       &
                prefix, i, DIST_C_u( i ), Y_u( i )
            BARRIER_C( i ) = Y_l( i ) / DIST_C_l( i ) - Y_u( i ) / DIST_C_u( i )
          END DO
          DO i = dims%c_l_end + 1, dims%c_u_end
            IF ( ABS( DIST_C_u( i ) ) <= degen_tol .AND. printd )              &
              WRITE( out, "( A, ' i = ', i6, ' DIST C, Y ', 2ES12.4 )" )       &
                prefix, i, DIST_C_u( i ), Y_u( i )
            BARRIER_C( i ) = - Y_u( i ) / DIST_C_u( i )
          END DO
        END IF

!  =======
!  STEP 2:
!  =======

!  =====================================================================
!  -*-*-*-*-*-*-*-*-*-*-*-*-      Factorization      -*-*-*-*-*-*-*-*-*-
!  =====================================================================

!  only refactorize if B has changed

        re = 'r'
        CALL CPU_TIME( time )

!  include the values of the barrier terms

        IF ( Hessian_kind <= 0 ) THEN
          H_sbls%val( 1 : dims%x_free ) = control%perturb_h
          H_sbls%val(dims%x_free + 1 : n ) = BARRIER_X + control%perturb_h
        ELSE IF ( Hessian_kind == 1 ) THEN
          H_sbls%val( 1 : dims%x_free ) = one + control%perturb_h
          H_sbls%val( dims%x_free + 1 : n ) =                                  &
           one + BARRIER_X + control%perturb_h
        ELSE IF ( Hessian_kind == 2 ) THEN
          H_sbls%val( 1 : dims%x_free ) =                                      &
            WEIGHT( : dims%x_free ) ** 2 + control%perturb_h
          H_sbls%val( dims%x_free + 1 : n ) =                                  &
            WEIGHT( dims%x_free + 1 : ) ** 2 + BARRIER_X + control%perturb_h
        END IF
        H_sbls%val( dims%c_s : dims%c_e ) = BARRIER_C

!  ensure that the preconditioner is consistent with the Hessian type

        IF ( lbfgs ) THEN
          IF ( SBLS_control%preconditioner == 2 .OR.                           &
               SBLS_control%preconditioner == 4 .OR.                           &
               SBLS_control%preconditioner == 5 .OR.                           &
               SBLS_control%preconditioner >= 9 .OR.                           &
               SBLS_control%preconditioner <= 0 )                              &
            SBLS_control%preconditioner = 8
        ELSE
          IF ( SBLS_control%preconditioner == 6 .OR.                           &
               SBLS_control%preconditioner == 7 .OR.                           &
               SBLS_control%preconditioner == 8 )                              &
            SBLS_control%preconditioner = 2
        END IF

! ::::::::::::::::::::::::::::::
!  Factorize the required matrix
! ::::::::::::::::::::::::::::::

  200   CONTINUE

!  factorize

!   ( H + (X-X_l)^-1 Z_l               A^T )
!   (   - (X_u-X)^-1 Z_u                   )
!   (                    (C-C_l)^-1 Y_l -I )
!   (                   -(C_u-C)^-1 Y_u    )
!   (       A               -I             )

!  either explicitly or implicitly (via its Schur complement)

        time_analyse = inform%SBLS_inform%SLS_inform%time%analyse
        clock_analyse = inform%SBLS_inform%SLS_inform%time%clock_analyse
        time_factorize = inform%SBLS_inform%SLS_inform%time%factorize
        clock_factorize = inform%SBLS_inform%SLS_inform%time%clock_factorize

        IF ( printw ) WRITE( out, "( A,                                        &
       &  ' ......... factorization of KKT matrix ............... ' )" ) prefix
        IF ( lbfgs ) THEN
          CALL SBLS_form_and_factorize( A_sbls%n, A_sbls%m, H_sbls, A_sbls,    &
            C_sbls, SBLS_data, SBLS_control, inform%SBLS_inform,               &
            D = H_sbls%val, H_lm = H_lm )
        ELSE
          CALL SBLS_form_and_factorize( A_sbls%n, A_sbls%m, H_sbls, A_sbls,    &
            C_sbls, SBLS_data, SBLS_control, inform%SBLS_inform )
        END IF
!write(6,*) ' perturbed? ', inform%SBLS_inform%perturbed
        inform%nfacts = inform%nfacts + 1

        inform%time%analyse = inform%time%analyse +                            &
          inform%SBLS_inform%SLS_inform%time%analyse - time_analyse
        inform%time%clock_analyse = inform%time%clock_analyse +                &
          inform%SBLS_inform%SLS_inform%time%clock_analyse - clock_analyse
        inform%time%factorize = inform%time%factorize +                        &
          inform%SBLS_inform%SLS_inform%time%factorize - time_factorize
        inform%time%clock_factorize = inform%time%clock_factorize +            &
          inform%SBLS_inform%SLS_inform%time%clock_factorize - clock_factorize
        time_solve = 0.0 ; clock_solve = 0.0

        IF ( printw ) WRITE( out, "( A,                                        &
       &  ' ............... end of factorization ............... ' )" ) prefix

!  test that the factorization succeeded

        inform%factorization_status = inform%SBLS_inform%status
        IF ( inform%factorization_status == GALAHAD_error_preconditioner ) THEN
        ELSE IF ( inform%factorization_status < 0 ) THEN
          IF ( printe ) WRITE( error, "( A, '    ** Error return ', I0,        &
         &  ' from ', A )" ) prefix, inform%factorization_status,              &
            'SBLS_form_and_factorize'

!  It didn't. We might have run out of options

          IF ( SBLS_control%factorization == 2 .AND. maxpiv ) THEN
            inform%status = GALAHAD_error_factorization ; GO TO 700

!  ... or we may change the method

          ELSE IF ( SBLS_control%factorization < 2 .AND. maxpiv ) THEN
            pivot_tol = relative_pivot_tol
            maxpiv = pivot_tol >= half
            SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
            SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
            SBLS_control%factorization = 2
            IF ( printi )  WRITE( out,                                         &
              "( A, '    ** Switching to augmented system method' )" ) prefix

!  ... or we can increase the pivot tolerance

          ELSE IF ( SBLS_control%SLS_control%relative_pivot_tolerance          &
                    < relative_pivot_default ) THEN
            pivot_tol = relative_pivot_default
            min_pivot_tol = relative_pivot_default
            maxpiv = .FALSE.
            SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
            SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
!           SBLS_control%factorization = 2
            IF ( printi ) WRITE( out,                                          &
              "( A, '    ** Pivot tolerance increased to', ES11.4 )" )         &
              prefix, pivot_tol
          ELSE
            pivot_tol = half
            min_pivot_tol = half
            maxpiv = .TRUE.
            SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
            SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
!           SBLS_control%factorization = 2
            IF ( printi ) WRITE( out,                                          &
              "( A, '    ** Pivot tolerance increased to', ES11.4 )" )         &
              prefix, pivot_tol
          END IF
          alpha = zero ; nbact = 0
          inform%factorization_integer = - 1
          inform%factorization_real = - 1
          CYCLE

!  record warning conditions

        ELSE
          IF (inform%factorization_status > 0 ) THEN
            IF ( printt ) THEN
              WRITE( out, "( A, '   **  Warning ', I0, ' from ', A )" )        &
              prefix, inform%SBLS_inform%status, 'SBLS_form_andfactorize'
            END IF
          END IF

!  Record the storage required

          inform%factorization_integer =                                       &
            inform%SBLS_inform%SLS_inform%integer_size_necessary
          inform%factorization_real =                                          &
            inform%SBLS_inform%SLS_inform%real_size_necessary

        END IF

!  If the matrix is singular, there is a chance that the
!  problem is unbounded from below

        IF ( inform%feasible .AND. inform%SBLS_inform%rank_def ) THEN
          RHS( : n ) = - GRAD_L( : n )
          RHS( dims%c_s : dims%c_e ) = zero
          RHS( dims%y_s : dims%y_e ) = zero

          SBLS_control%get_norm_residual = .TRUE.
          CALL CPU_TIME( time_record ) ; CALL CLOCK_time( clock_record )
          IF ( inform%SBLS_inform%preconditioner == 2 ) THEN
            CALL SBLS_solve( A_sbls%n, A_sbls%m, A_sbls, C_sbls,               &
                             SBLS_data, SBLS_control, inform%SBLS_inform, RHS )
          ELSE IF ( lbfgs ) THEN
            CALL SBLS_solve( A_sbls%n, A_sbls%m, A_sbls, C_sbls, SBLS_data,    &
                         SBLS_control, inform%SBLS_inform, RHS, H_lm = H_lm )
          ELSE
            CALL SBLS_solve_iterative( A_sbls%n, A_sbls%m, H_sbls, A_sbls,     &
                                       RHS, SBLS_data, control%SBLS_control,   &
                                       inform%SBLS_inform )
          END IF
          CALL CPU_TIME( time_now ) ; CALL CLOCK_TIME( clock_now )
          time_solve = time_solve + time_now - time_record
          clock_solve = clock_solve + clock_now - clock_record
          inform%status = inform%SBLS_inform%status
          IF ( inform%status /= GALAHAD_ok ) GO TO 700

!  a potentially unbounded direction has been found. Check if bounds stop it

          IF ( inform%SBLS_inform%norm_residual > control%stop_abs_d ) THEN
            unbounded = .TRUE.
            DO i = dims%x_free + 1, n
              IF ( RHS( i ) > ten * epsmch ) THEN
                IF ( X_u( i ) < control%infinity ) THEN
                  unbounded = .FALSE. ; EXIT
                END IF
              ELSE IF ( RHS( i ) < - ten * epsmch ) THEN
                IF ( X_l( i ) > - control%infinity ) THEN
                  unbounded = .FALSE. ; EXIT
                END IF
              END IF
            END DO
            IF ( unbounded ) THEN
              inform%status = GALAHAD_error_unbounded ; GO TO 700
            END IF
          END IF
        END IF

        IF ( inform%SBLS_inform%perturbed ) THEN
          SBLS_control%new_h = 2
        ELSE
          SBLS_control%new_h = 1
        END IF
        SBLS_control%new_a = 0
        SBLS_control%new_c = 0

        IF ( printt ) THEN
          WRITE( out, "( A, ' factorization time = ', F0.2 )" ) prefix,        &
            inform%SBLS_inform%SLS_inform%time%factorize - time_factorize +    &
            inform%SBLS_inform%SLS_inform%time%clock_factorize - clock_factorize
          WRITE( out, "( A, 1X, I0, ' integer and ', I0, ' real words needed', &
         &    ' for factorization' )" ) prefix, inform%factorization_integer,  &
                                        inform%factorization_real
        END IF

!       IF ( printw ) WRITE( out, "( A,                                        &
!      &  ' ............... end of factorization ............... ' )" ) prefix

!  =======
!  STEP 3:
!  =======

        IF ( arc == 'ZS' .OR. arc == 'ZP' ) THEN
          two_mu = two * mu
          sigma_mu = sigma * mu
          sigma_mu2 = sigma_mu * mu
          IF ( puiseux ) THEN
            two_sigma_mu = two * sigma_mu
            two_sigma_mu2 = two * sigma_mu2
            two_plus_sigma_mu = two + sigma_mu
            one_plus_2_sigma_mu = one + two_sigma_mu
          ELSE
            one_plus_sigma_mu = one + sigma_mu
          END IF
        END IF

!  =======================================================================
!  -*-*-*-*-*-*-*-*-   Obtain the Primal-Dual Search Arc -*-*-*-*-*-*-*-*-
!  =======================================================================

!  we consider the search arc

!     v_l(alpha) = v + sum_k=1^l [ (-1)^k v^k / k! ] alpha^k

!  as alpha inceases from 0 to 1 and where v_l(alpha) is the l-th-order Taylor
!  series approximation of the arc v(1-alpha)) about alpha = 0 (equiv theta
!  = 1 - alpha about theta = 1) and for which v(theta) satisfies the conditions

!  H x(theta) - A^T y(theta) - z_l(theta) - z_u(theta) + g = dual(theta)
!                            A x(theta) - b                = prim(theta)
!                           X(theta) z(theta)              = comp(theta)

!  for suitable
!      prim(theta) = theta ( A x - b )
!      dual(theta) = theta ( H x - A^T y - z + g )
!  (Taylor or Taylor-Puisuex) or
!      prim(theta) = theta^2 ( A x - b )
!      dual(theta) = theta^2 ( H x - A^T y - z + g )
!  (Puiseux) and various possible comp(theta)

!  To find the coefficients v^k = ( x^k, c^k, y^k, z_l^k, z_u^k, y_l^k, y_u^k ),
!  solve the equations

!   (  H       A^T   -I    -I               ) (  x^k  )   (  h^k  )
!   (          -I                 -I   -I   ) (  c^k  )   (  d^k  )
!   (  A   -I                               ) ( -y^k  )   (  a^k  )
!   (  Z_l         X-X_l                    ) ( z_l^k ) = ( r_l^k )
!   ( -Z_u               X_u-X              ) ( z_u^k )   ( r_u^k )
!   (      Y_l                  C-C_l       ) ( y_l^k )   ( s_l^k )
!   (     -Y_u                        C_u-C ) ( y_u^k )   ( s_u^k )

!  for k > 0 for which

!  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  arc 1: for the Zhang arc,
!    comp(theta) =   theta Xz + (1-theta) sigma mu e      (lower)
!            or    - theta Xz - (1-theta) sigma mu e      (upper)
!  (Taylor) or
!    comp(theta) =   theta^2 Xz + (1-theta^2) sigma mu e  (lower)
!            or    - theta^2 Xz - (1-theta^2) sigma mu e  (upper)
!  (Taylor-Puisuex or Puiseux)
!  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

!     h^1 = g + Hx - A^Ty - z_l - z_u
!     d^i = y - y_l - y_u
!     a^1 =  A x - b
!     r_l^1 = - mu e + (X-X_l)z_l                    (store in z_l^1)
!     r_u^1 =   mu e + (X_u-X)z_u                    (store in z_u^1)
!     s_l^1 = - mu e + (C-C_l)y_l                    (store in y_l^1)
!   & s_u^1 =   mu e + (C_u-C)y_u                    (store in y_u^1)

!  (k=1) and

!     h^k = 0
!     d^k = 0
!     a^k = 0
!     r_l^k = - sum_i=1^k-1 b_i^k X^i z_l^{k-i}      (store in z_l^k)
!     r_u^k =   sum_i=1^k-1 b_i^k X^i z_u^{k-i}      (store in z_u^k)
!     s_l^k = - sum_i=1^k-1 b_i^k C^i y_l^{k-i}      (store in y_l^k)
!   & s_u^k =   sum_i=1^k-1 b_i^k C^i y_u^{k-i}      (store in y_u^k)

!  (k>1) for the Taylor arc,

!     h^1 = g + Hx - A^Ty - z_l - z_u
!     d^i = y - y_l - y_u
!     a^1 = A x - b
!     r_l^1 = 2 ( - mu e + (X-X_l)z_l )              (store in z_l^1)
!     r_u^1 = 2 (   mu e + (X_u-X)z_u )              (store in z_u^1)
!     s_l^1 = 2 ( - mu e + (C-C_l)y_l )              (store in y_l^1)
!   & s_u^1 = 2 (   mu e + (C_u-C)y_u )              (store in y_u^1)

!  (k=1),

!     h^2 = 0
!     d^2 = 0
!     a^2 = 0
!     r_l^2 = 2 ( - mu e + (X-X_l)z_l - X^1 z_l^1 )  (store in z_l^2)
!     r_u^2 = 2 (   mu e + (X_u-X)z_u + X^1 z_u^1 )  (store in z_u^2)
!     s_l^2 = 2 ( - mu e + (C-C_l)y_l - C^1 y_l^1 )  (store in y_l^2)
!   & s_u^2 = 2 (   mu e + (C_u-C)y_u + C^1 y_u^1 )  (store in y_u^2)

!  (k=2) and

!     h^k = 0
!     d^k = 0
!     a^k = 0
!     r_l^k = - sum_i=1^k-1 b_i^k X^i z_l^{k-i}      (store in z_l^k)
!     r_u^k =   sum_i=1^k-1 b_i^k X^i z_u^{k-i}      (store in z_u^k)
!     s_l^k = - sum_i=1^k-1 b_i^k C^i y_l^{k-i}      (store in y_l^k)
!   & s_u^k =   sum_i=1^k-1 b_i^k C^i y_u^{k-i}      (store in y_u^k)

!  (k>2) for the Zhang-Puiseux Taylor arc, or

!     h^1 = 2 ( g + Hx - A^Ty - z_l - z_u )
!     d^i = 2 ( y - y_l - y_u )
!     a^1 = 2 ( A x - b )
!     r_l^1 = 2 ( - mu e + (X-X_l)z_l )              (store in z_l^1)
!     r_u^1 = 2 (   mu e + (X_u-X)z_u )              (store in z_u^1)
!     s_l^1 = 2 ( - mu e + (C-C_l)y_l )              (store in y_l^1)
!   & s_u^1 = 2 (   mu e + (C_u-C)y_u )              (store in y_u^1)

!  (k=1),

!     h^2 = 2 ( g + Hx - A^Ty - z_l - z_u )
!     d^2 = 2 ( y - y_l - y_u )
!     a^2 = 2 ( A x - b )
!     r_l^2 = 2 ( - mu e + (X-X_l)z_l - X^1 z_l^1 )  (store in z_l^2)
!     r_u^2 = 2 (   mu e + (X_u-X)z_u + X^1 z_u^1 )  (store in z_u^2)
!     s_l^2 = 2 ( - mu e + (C-C_l)y_l - C^1 y_l^1 )  (store in y_l^2)
!   & s_u^2 = 2 (   mu e + (C_u-C)y_u + C^1 y_u^1 )  (store in y_u^2)

!  (k=2) and

!     h^k = 0
!     d^k = 0
!     a^k = 0
!     r_l^k = - sum_i=1^k-1 b_i^k X^i z_l^{k-i}      (store in z_l^k)
!     r_u^k =   sum_i=1^k-1 b_i^k X^i z_u^{k-i}      (store in z_u^k)
!     s_l^k = - sum_i=1^k-1 b_i^k C^i y_l^{k-i}      (store in y_l^k)
!   & s_u^k =   sum_i=1^k-1 b_i^k C^i y_u^{k-i}      (store in y_u^k)

!  (k>2) for the Puiseux arc, where b_i^k is the binomial coefficient
!     "k choose i"

!  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  arc 2: for the Zhao-Sun arc, comp(theta) =
!       theta Xz + sigma mu theta ( 1 - theta ) ( mu e - X z ) (lower) or
!     - theta Xz - sigma mu theta ( 1 - theta ) ( mu e - X z ) (upper)
!   or, in the Puiseux case,
!       theta^2 Xz + sigma mu theta^2 ( 1 - theta ) ( mu e - X z ) (lower) or
!     - theta^2 Xz - sigma mu theta^2 ( 1 - theta ) ( mu e - X z ) (upper)
!  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

!     h^1 = g + Hx - A^Ty - z_l - z_u
!     d^i = y - y_l - y_u
!     a^1 =  A x - b
!     r_l^1 = - sigma mu [ mu e - (X-X_l)z_l ] + (X-X_l)z_l  (store in z_l^1)
!     r_u^1 =   sigma mu [ mu e + (X_u-X)z_u ] + (X_u-X)z_u  (store in z_u^1)
!     s_l^1 = - sigma mu [ mu e - (C-C_l)y_l ] + (C-C_l)y_l  (store in y_l^1)
!   & s_u^1 =   sigma mu [ mu e + (C_u-C)y_u ] + (C_u-C)y_u  (store in y_u^1)

!  (k=1),

!     h^2 = 0
!     d^2 = 0
!     a^2 = 0
!     r_l^2 = 2 ( - sigma mu [mu e - (X-X_l)z_l] - X^1 z_l^1 ) (store in z_l^2)
!     r_u^2 = 2 (   sigma mu [mu e + (X_u-X)z_u] + X^1 z_u^1 ) (store in z_u^2)
!     s_l^2 = 2 ( - sigma mu [mu e - (C-C_l)y_l] - C^1 y_l^1 ) (store in y_l^2)
!   & s_u^2 = 2 (   sigma mu [mu e + (C_u-C)y_u] + C^1 y_u^1 ) (store in y_u^2)

!  (k=2) and

!     h^k = 0
!     d^k = 0
!     a^k = 0
!     r_l^k = - sum_i=1^k-1 b_i^k X^i z_l^{k-i}      (store in z_l^k)
!     r_u^k =   sum_i=1^k-1 b_i^k X^i z_u^{k-i}      (store in z_u^k)
!     s_l^k = - sum_i=1^k-1 b_i^k C^i y_l^{k-i}      (store in y_l^k)
!   & s_u^k =   sum_i=1^k-1 b_i^k C^i y_u^{k-i}      (store in y_u^k)

!  (k>2) for the Taylor arc, or

!     h^1 = 2 ( g + Hx - A^Ty - z_l - z_u )
!     d^i = 2 ( y - y_l - y_u )
!     a^1 = 2 ( A x - b )
!     r_l^1 = - sigma mu [ mu e - (X-X_l)z_l ] + 2(X-X_l)z_l  (store in z_l^1)
!     r_u^1 =   sigma mu [ mu e + (X_u-X)z_u ] + 2(X_u-X)z_u  (store in z_u^1)
!     s_l^1 = - sigma mu [ mu e - (C-C_l)y_l ] + 2(C-C_l)y_l  (store in y_l^1)
!   & s_u^1 =   sigma mu [ mu e + (C_u-C)y_u ] + 2(C_u-C)y_u  (store in y_u^1)

!  (k=1),

!     h^2 = 2 ( g + Hx - A^Ty - z_l - z_u )
!     d^2 = 2 ( y - y_l - y_u )
!     a^2 = 2 ( A x - b )
!     r_l^2 = - 4 sigma mu [ mu e - (X-X_l)z_l ] + 2(X-X_l)z_l - 2 X^1 z_l^1
!                                                              (store in z_l^2)
!     r_u^2 =   4 sigma mu [ mu e + (X_u-X)z_u ] + 2(X_u-X)z_u + 2 X^1 z_u^1
!                                                              (store in z_u^2)
!     s_l^2 = - 4 sigma mu [ mu e - (C-C_l)y_l ] + 2(C-C_l)y_l - 2 C^1 y_l^1
!                                                              (store in y_l^2)
!   & s_u^2 =   4 sigma mu [ mu e + (C_u-C)y_u ] + 2(C_u-C)y_u + 2 C^1 y_u^1
!                                                              (store in y_u^2)

!  (k=2) and

!     h^3 = 0
!     d^3 = 0
!     a^3 = 0
!     r_l^3 = - 6 sigma mu [ mu e - (X-X_l)z_l ] - 3 [ X^1 z_l^2 + X^2 z_l^1 ]
!                                                              (store in z_l^3)
!     r_u^3 =   6 sigma mu [ mu e + (X_u-X)z_u ] + 3 [ X^1 z_u^2 + X^2 z_u^1 ]
!                                                              (store in z_u^3)
!     s_l^3 = - 6 sigma mu [ mu e - (C-C_l)y_l ] - 3 [ C^1 c_l^2 + C^2 c_l^1 ]
!                                                              (store in y_l^3)
!   & s_u^3 =   6 sigma mu [ mu e + (C_u-C)y_u ] + 3 [ C^1 c_u^2 + C^2 c_u^1 ]
!                                                              (store in y_u^3)

!  (k=3) and

!     h^k = 0
!     d^k = 0
!     a^k = 0
!     r_l^k = - sum_i=1^k-1 b_i^k X^i z_l^{k-i}      (store in z_l^k)
!     r_u^k =   sum_i=1^k-1 b_i^k X^i z_u^{k-i}      (store in z_u^k)
!     s_l^k = - sum_i=1^k-1 b_i^k C^i y_l^{k-i}      (store in y_l^k)
!   & s_u^k =   sum_i=1^k-1 b_i^k C^i y_u^{k-i}      (store in y_u^k)

!  (k>3) for the Puiseux arc

!  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

!  On writing
!        z_l^k = (X-X_l)^-1 [ r_l^k - Z_l x^k ]
!        z_u^k = (X_u-X)^-1 [ r_u^k + Z_u x^k ]
!        y_l^k = (C-C_l)^-1 [ s_l^k - Y_l c^k ]
!      & y_u^k = (C_u-C)^-1 [ s_u^k + Y_u c^k ], we find

!  ( H + (X-X_l)^-1 Z_l               A^T ) ( x^k )   ( h^k + (X-X_l)^-1 r_l^k )
!  (   - (X_u-X)^-1 Z_u                   ) (     )   (     + (X_u-X)^-1 r_u^k )
!  (                    (C-C_l)^-1 Y_l -I ) ( c^k ) = ( d^k + (C-C_l)^-1 s_l^k )
!  (                   -(C_u-C)^-1 Y_u    ) (     )   (     + (C_u-C)^-1 s_u^k )
!  (       A               -I             ) (-y^k )   (           a^k          )

!  record the 0-th order coefficients

        X_coef( : , 0 ) = X
        C_coef( : , 0 ) = C
        Y_coef( : , 0 ) = Y
        Z_l_coef( : , 0 ) = Z_l
        Z_u_coef( : , 0 ) = Z_u
        Y_l_coef( : , 0 ) = Y_l
        Y_u_coef( : , 0 ) = Y_u

!  compute the k-th order coefficients

        DO k = 1, order

!  :::::::::::::::::::::::::::::::::::::
!  3a. Set up the right-hand-side vector
!  :::::::::::::::::::::::::::::::::::::

!  record rhs = ( h^k + (X-X_l)^-1 r_l^k + (X_u-X)^-1 r_u^k )
!               ( d^k + (C-C_l)^-1 s_l^k + (C_u-C)^-1 s_u^k )
!               (                   a^k                     )

          IF ( printd ) WRITE( out, 2100 )                                     &
            prefix, ' GRAD_L', GRAD_L( dims%x_s : dims%x_e )

!  for the 1st order Taylor and 1st and 2nd order Puiseux coefficients
!  and the Zhang arc or the 1st and 2nd order Zhang-Puiseux arc

          IF ( ( arc == 'Zh' .AND. ( k == 1 .OR. ( k == 2 .AND. puiseux ) ) )  &
                 .OR. ( arc == 'ZP' .AND. k <= 2 ) ) THEN

!  compute and store ( r_l^1, r_u^1, s_l^1, s_u^1 )

!  for the 1st order coefficients

            IF ( k == 1 ) THEN
              DO i = dims%x_free + 1, dims%x_l_end
                Z_l_coef( i, 1 ) = - mu + ( X( i ) - X_l( i ) ) * Z_l( i )
              END DO
              DO i = dims%x_u_start, n
                Z_u_coef( i, 1 ) =   mu + ( X_u( i ) - X( i ) ) * Z_u( i )
              END DO
              DO i = dims%c_l_start, dims%c_l_end
                Y_l_coef( i, 1 ) = - mu + ( C( i ) - C_l( i ) ) * Y_l( i )
              END DO
              DO i = dims%c_u_start, dims%c_u_end
                Y_u_coef( i, 1 ) =   mu + ( C_u( i ) - C( i ) ) * Y_u( i )
              END DO

!  for the 2nd order Puiseux coefficients

            ELSE
              DO i = dims%x_free + 1, dims%x_l_end
                Z_l_coef( i, 2 ) = - mu + ( X( i ) - X_l( i ) ) * Z_l( i ) -   &
                  X_coef( i, 1 ) * Z_l_coef( i, 1 )
              END DO
              DO i = dims%x_u_start, n
                Z_u_coef( i, 2 ) =   mu + ( X_u( i ) - X( i ) ) * Z_u( i ) +   &
                  X_coef( i, 1 ) * Z_u_coef( i, 1 )
              END DO
              DO i = dims%c_l_start, dims%c_l_end
                Y_l_coef( i, 2 ) = - mu + ( C( i ) - C_l( i ) ) * Y_l( i ) -   &
                  C_coef( i, 1 ) * Y_l_coef( i, 1 )
              END DO
              DO i = dims%c_u_start, dims%c_u_end
                Y_u_coef( i, 2 ) =   mu + ( C_u( i ) - C( i ) ) * Y_u( i ) +   &
                  C_coef( i, 1 ) * Y_u_coef( i, 1 )
              END DO
            END IF

!  double the Puiseux coefficients

            IF ( puiseux ) THEN
              Z_l_coef( dims%x_free + 1 : dims%x_l_end, k ) =                  &
                two * Z_l_coef( dims%x_free + 1 : dims%x_l_end, k )
              Z_u_coef( dims%x_u_start : n, k ) =                              &
                two * Z_u_coef( dims%x_u_start : n, k )
              Y_l_coef( dims%c_l_start : dims%c_l_end, k ) =                   &
                two * Y_l_coef( dims%c_l_start : dims%c_l_end, k )
              Y_u_coef( dims%c_u_start : dims%c_u_end, k ) =                   &
                two * Y_u_coef( dims%c_u_start : dims%c_u_end, k )
            END IF

!  for the Zhang arc

            IF ( arc == 'Zh' ) THEN

!  for the 1-st order rhs

              IF ( k == 1 ) THEN

!  rhs for problem variables: g + Hx - A^Ty - mu (X-X_l)^-1 e + mu (X_u-X)^-1 e

                RHS( : dims%x_free ) = GRAD_L( : dims%x_free )
                DO i = dims%x_free + 1, dims%x_l_start - 1
                  RHS( i ) = GRAD_L( i ) - mu / X( i )
                END DO
                DO i = dims%x_l_start, dims%x_u_start - 1
                  RHS( i ) = GRAD_L( i ) - mu / DIST_X_l( i )
                END DO
                DO i = dims%x_u_start, dims%x_l_end
                  RHS( i ) = GRAD_L( i ) - mu / DIST_X_l( i )                  &
                                         + mu / DIST_X_u( i )
                END DO
                DO i = dims%x_l_end + 1, dims%x_u_end
                  RHS( i ) = GRAD_L( i ) + mu / DIST_X_u( i )
                END DO
                DO i = dims%x_u_end + 1, n
                  RHS( i ) = GRAD_L( i ) - mu / X( i )
                END DO

!  rhs for slack variables: y - mu (C-C_l)^-1 e + mu (C_u-C)^-1 e

                DO i = dims%c_l_start, dims%c_u_start - 1
                  RHS( dims%c_b + i ) = Y( i ) - mu / DIST_C_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_l_end
                  RHS( dims%c_b + i ) = Y( i ) - mu / DIST_C_l( i )            &
                                               + mu / DIST_C_u( i )
                END DO
                DO i = dims%c_l_end + 1, dims%c_u_end
                  RHS( dims%c_b + i ) = Y( i ) + mu / DIST_C_u( i )
                END DO

!  for the 2nd order rhs

              ELSE

!  rhs for problem variables: g + Hx - A^Ty - (X-X_l)^-1 ( mu e + X^1 z_l^1 )
!    + (X_u-X)^-1 ( mu e + X^1 z_u^1 )

                RHS( : dims%x_free ) = GRAD_L( : dims%x_free )
                DO i = dims%x_free + 1, dims%x_l_start - 1
                  RHS( i ) = GRAD_L( i )                                       &
                    - ( mu + X_coef( i, 1 ) * Z_l_coef( i, 1 ) ) / X( i )
                END DO
                DO i = dims%x_l_start, dims%x_u_start - 1
                  RHS( i ) = GRAD_L( i )                                       &
                    - ( mu + X_coef( i, 1 ) * Z_l_coef( i, 1 ) ) / DIST_X_l( i )
                END DO
                DO i = dims%x_u_start, dims%x_l_end
                  RHS( i ) = GRAD_L( i )                                       &
                   - ( mu + X_coef( i, 1 ) * Z_l_coef( i, 1 ) ) / DIST_X_l( i )&
                   + ( mu + X_coef( i, 1 ) * Z_u_coef( i, 1 ) ) / DIST_X_u( i )
                END DO
                DO i = dims%x_l_end + 1, dims%x_u_end
                  RHS( i ) = GRAD_L( i )                                       &
                    + ( mu + X_coef( i, 1 ) * Z_u_coef( i, 1 ) ) / DIST_X_u( i )
                END DO
                DO i = dims%x_u_end + 1, n
                  RHS( i ) = GRAD_L( i )                                       &
                    - ( mu + X_coef( i, 1 ) * Z_u_coef( i, 1 ) ) / X( i )
                END DO

!  rhs for slack variables: y - (C-C_l)^-1 ( mu e + C^1 y_l^1 )
!    + (C_u-C)^-1 ( mu e + C^1 y_u^1 )

                DO i = dims%c_l_start, dims%c_u_start - 1
                  RHS( dims%c_b + i ) = Y( i )                                 &
                    - ( mu + C_coef( i, 1 ) * Y_l_coef( i, 1 ) ) / DIST_C_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_l_end
                  RHS( dims%c_b + i ) = Y( i )                                 &
                   - ( mu + C_coef( i, 1 ) * Y_l_coef( i, 1 ) ) / DIST_C_l( i )&
                  + ( mu + C_coef( i, 1 ) * Y_u_coef( i, 1 ) ) / DIST_C_u( i )
                END DO
                DO i = dims%c_l_end + 1, dims%c_u_end
                  RHS( dims%c_b + i ) = Y( i )                                 &
                    + ( mu + C_coef( i, 1 ) * Y_u_coef( i, 1 ) ) / DIST_C_u( i )
                END DO
              END IF

!  rhs for constraint infeasibilities: A x - b

              RHS( dims%y_s : dims%y_e ) = C_RES( : dims%c_u_end )

!  double the Puiseux rhs

              IF ( puiseux ) RHS( : dims%y_e ) = two * RHS( : dims%y_e )

!  for the Zhang-Puiseux arc

            ELSE

!  for the 1-st order rhs

              IF ( k == 1 ) THEN

!  rhs for problem variables: g + Hx - A^Ty + z_l + z_u -
!                             2 mu (X-X_l)^-1 e + 2 mu (X_u-X)^-1 e )

                RHS( : dims%x_free ) = GRAD_L( : dims%x_free )
                DO i = dims%x_free + 1, dims%x_l_start - 1
                  RHS( i ) = GRAD_L( i ) + Z_l( i ) - two_mu / X( i )
                END DO
                DO i = dims%x_l_start, dims%x_u_start - 1
                  RHS( i ) = GRAD_L( i ) + Z_l( i ) - two_mu / DIST_X_l( i )
                END DO
                DO i = dims%x_u_start, dims%x_l_end
                  RHS( i ) = GRAD_L( i ) + Z_l( i ) + Z_u( i )                 &
                                         - two_mu / DIST_X_l( i )              &
                                         + two_mu / DIST_X_u( i )
                END DO
                DO i = dims%x_l_end + 1, dims%x_u_end
                  RHS( i ) = GRAD_L( i ) + Z_u( i ) + two_mu / DIST_X_u( i )
                END DO
                DO i = dims%x_u_end + 1, n
                  RHS( i ) = GRAD_L( i ) + Z_u( i ) - two_mu / X( i )
                END DO

!  rhs for slack variables:
!       y + y_l + y_u - 2 mu (C-C_l)^-1 e + 2 mu (C_u-C)^-1 e

                DO i = dims%c_l_start, dims%c_u_start - 1
                  RHS( dims%c_b + i ) = Y( i ) + Y_l( i )                      &
                                               - two_mu / DIST_C_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_l_end
                  RHS( dims%c_b + i ) = Y( i ) + Y_l( i ) + Y_u( i )           &
                                               - two_mu / DIST_C_l( i )        &
                                               + two_mu / DIST_C_u( i )
                END DO
                DO i = dims%c_l_end + 1, dims%c_u_end
                  RHS( dims%c_b + i ) = Y( i ) + Y_u( i )                      &
                                               + two_mu / DIST_C_u( i )
                END DO

!  rhs for constraint infeasibilities: A x - b

                RHS( dims%y_s : dims%y_e ) = C_RES( : dims%c_u_end )

!  for the 2nd order rhs

              ELSE

!  rhs for problem variables: 2 z_l + 2 z_u
!                  - 2 (X-X_l)^-1 ( mu e + X^1 z_l^1 )
!                  + 2 (X_u-X)^-1 ( mu e + X^1 z_u^1 )

                RHS( : dims%x_free ) = zero
                DO i = dims%x_free + 1, dims%x_l_start - 1
                  RHS( i ) = two * ( Z_l( i ) -                                &
                    ( mu + X_coef( i, 1 ) * Z_l_coef( i, 1 ) ) / X( i ) )
                END DO
                DO i = dims%x_l_start, dims%x_u_start - 1
                  RHS( i ) = two * ( Z_l( i ) -                                &
                    ( mu + X_coef( i, 1 ) * Z_l_coef( i, 1 ) ) / DIST_X_l( i ) )
                END DO
                DO i = dims%x_u_start, dims%x_l_end
                  RHS( i ) = two * ( Z_l( i ) + Z_u( i ) -                     &
                   ( mu + X_coef( i, 1 ) * Z_l_coef( i, 1 ) ) / DIST_X_l( i ) +&
                   ( mu + X_coef( i, 1 ) * Z_u_coef( i, 1 ) ) / DIST_X_u( i ) )
                END DO
                DO i = dims%x_l_end + 1, dims%x_u_end
                  RHS( i ) = two * ( Z_u( i ) +                                &
                    ( mu + X_coef( i, 1 ) * Z_u_coef( i, 1 ) ) / DIST_X_u( i ) )
                END DO
                DO i = dims%x_u_end + 1, n
                  RHS( i ) = two * ( Z_u( i ) -                                &
                    ( mu + X_coef( i, 1 ) * Z_u_coef( i, 1 ) ) / X( i ) )
                END DO

!  rhs for slack variables: 2 y_l + 2 y_u
!             - 2 (C-C_l)^-1 ( mu e + C^1 y_l^1 )
!             + 2 (C_u-C)^-1 ( mu e + C^1 y_u^1 )

                DO i = dims%c_l_start, dims%c_u_start - 1
                  RHS( dims%c_b + i ) = two * ( Y_l( i ) -                     &
                    ( mu + C_coef( i, 1 ) * Y_l_coef( i, 1 ) ) / DIST_C_l( i ) )
                END DO
                DO i = dims%c_u_start, dims%c_l_end
                  RHS( dims%c_b + i ) = two * ( Y_l( i ) + Y_u( i ) -          &
                   ( mu + C_coef( i, 1 ) * Y_l_coef( i, 1 ) ) / DIST_C_l( i ) +&
                  ( mu + C_coef( i, 1 ) * Y_u_coef( i, 1 ) ) / DIST_C_u( i ) )
                END DO
                DO i = dims%c_l_end + 1, dims%c_u_end
                  RHS( dims%c_b + i ) = two * ( Y_u( i ) +                     &
                    ( mu + C_coef( i, 1 ) * Y_u_coef( i, 1 ) ) / DIST_C_u( i ) )
                END DO

!  rhs for constraint infeasibilities: 0

                RHS( dims%y_s : dims%y_e ) = zero
              END IF
            END IF

!  for the 1st and 2nd order Taylor and 1st to 3rd order Puiseux coefficients
!  and the Zhao-Sun arc

          ELSE IF ( arc == 'ZS' .AND.                                          &
            ( k <= 2 .OR. ( k <= 3 .AND. puiseux ) ) ) THEN

!  compute and store ( r_l^1, r_u^1, s_l^1, s_u^1 )

!  for the 1-st order coefficients

            IF ( k == 1 ) THEN

!  Puiseux case

              IF ( puiseux ) THEN
                DO i = dims%x_free + 1, dims%x_l_end
                  Z_l_coef( i, 1 ) = - sigma_mu2                               &
                    + two_plus_sigma_mu * ( X( i ) - X_l( i ) ) * Z_l( i )
                END DO
                DO i = dims%x_u_start, n
                  Z_u_coef( i, 1 ) =   sigma_mu2                               &
                    + two_plus_sigma_mu * ( X_u( i ) - X( i ) ) * Z_u( i )
                END DO
                DO i = dims%c_l_start, dims%c_l_end
                  Y_l_coef( i, 1 ) = - sigma_mu2                               &
                    + two_plus_sigma_mu * ( C( i ) - C_l( i ) ) * Y_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_u_end
                  Y_u_coef( i, 1 ) =   sigma_mu2                               &
                    + two_plus_sigma_mu * ( C_u( i ) - C( i ) ) * Y_u( i )
                END DO

!  Taylor case

              ELSE
                DO i = dims%x_free + 1, dims%x_l_end
                  Z_l_coef( i, 1 ) = - sigma_mu2                               &
                    + one_plus_sigma_mu * ( X( i ) - X_l( i ) ) * Z_l( i )
                END DO
                DO i = dims%x_u_start, n
                  Z_u_coef( i, 1 ) =   sigma_mu2                               &
                    + one_plus_sigma_mu * ( X_u( i ) - X( i ) ) * Z_u( i )
                END DO
                DO i = dims%c_l_start, dims%c_l_end
                  Y_l_coef( i, 1 ) = - sigma_mu2                               &
                    + one_plus_sigma_mu * ( C( i ) - C_l( i ) ) * Y_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_u_end
                  Y_u_coef( i, 1 ) =   sigma_mu2                               &
                    + one_plus_sigma_mu * ( C_u( i ) - C( i ) ) * Y_u( i )
                END DO
              END IF

!  for the 2nd order coefficients

            ELSE IF ( k == 2 ) THEN

!  Puiseux case

              IF ( puiseux ) THEN
                DO i = dims%x_free + 1, dims%x_l_end
                  Z_l_coef( i, 2 ) = two * ( - two * sigma_mu2                 &
                    + one_plus_2_sigma_mu * ( X( i ) - X_l( i ) ) * Z_l( i )   &
                      - X_coef( i, 1 ) * Z_l_coef( i, 1 ) )
                END DO
                DO i = dims%x_u_start, n
                  Z_u_coef( i, 2 ) = two * (   two * sigma_mu2                 &
                    + one_plus_2_sigma_mu * ( X_u( i ) - X( i ) ) * Z_u( i )   &
                      + X_coef( i, 1 ) * Z_u_coef( i, 1 ) )
                END DO
                DO i = dims%c_l_start, dims%c_l_end
                  Y_l_coef( i, 2 ) = two * ( - two * sigma_mu2                 &
                    + one_plus_2_sigma_mu * ( C( i ) - C_l( i ) ) * Y_l( i )   &
                      - C_coef( i, 1 ) * Y_l_coef( i, 1 ) )
                END DO
                DO i = dims%c_u_start, dims%c_u_end
                  Y_u_coef( i, 2 ) = two * (   two * sigma_mu2                 &
                    + one_plus_2_sigma_mu * ( C_u( i ) - C( i ) ) * Y_u( i )   &
                      + C_coef( i, 1 ) * Y_u_coef( i, 1 ) )
                END DO

!  Taylor case

              ELSE
                DO i = dims%x_free + 1, dims%x_l_end
                  Z_l_coef( i, 2 ) = two * (                                   &
                    - sigma_mu * ( mu - ( X( i ) - X_l( i ) ) * Z_l( i ) )     &
                      - X_coef( i, 1 ) * Z_l_coef( i, 1 ) )
                END DO
                DO i = dims%x_u_start, n
                  Z_u_coef( i, 2 ) = two * (                                   &
                      sigma_mu * ( mu + ( X_u( i ) - X( i ) ) * Z_u( i ) )     &
                      + X_coef( i, 1 ) * Z_u_coef( i, 1 ) )
                END DO
                DO i = dims%c_l_start, dims%c_l_end
                  Y_l_coef( i, 2 ) = two * (                                   &
                    - sigma_mu * ( mu - ( C( i ) - C_l( i ) ) * Y_l( i ) )     &
                      - C_coef( i, 1 ) * Y_l_coef( i, 1 ) )
                END DO
                DO i = dims%c_u_start, dims%c_u_end
                  Y_u_coef( i, 2 ) = two * (                                   &
                      sigma_mu * ( mu + ( C_u( i ) - C( i ) ) * Y_u( i ) )     &
                      + C_coef( i, 1 ) * Y_u_coef( i, 1 ) )
                END DO
              END IF

!  for the 3rd order Puiseux coefficients

            ELSE
              DO i = dims%x_free + 1, dims%x_l_end
                Z_l_coef( i, 3 ) = three * ( - two_sigma_mu2                   &
                  + two_sigma_mu * ( X( i ) - X_l( i ) ) * Z_l( i )            &
                    - X_coef( i, 1 ) * Z_l_coef( i, 2 )                        &
                    - X_coef( i, 2 ) * Z_l_coef( i, 1 ) )
              END DO
              DO i = dims%x_u_start, n
                Z_u_coef( i, 3 ) = three * (   two_sigma_mu2                   &
                  + two_sigma_mu * ( X_u( i ) - X( i ) ) * Z_u( i )            &
                    + X_coef( i, 1 ) * Z_u_coef( i, 2 )                        &
                    + X_coef( i, 2 ) * Z_u_coef( i, 1 ) )
              END DO
              DO i = dims%c_l_start, dims%c_l_end
                Y_l_coef( i, 3 ) = three * ( - two_sigma_mu2                   &
                  + two_sigma_mu * ( C( i ) - C_l( i ) ) * Y_l( i )            &
                    - C_coef( i, 1 ) * Y_l_coef( i, 2 )                        &
                    - C_coef( i, 2 ) * Y_l_coef( i, 1 ) )
              END DO
              DO i = dims%c_u_start, dims%c_u_end
                Y_u_coef( i, 3 ) = three * (   two_sigma_mu2                   &
                  + two_sigma_mu * ( C_u( i ) - C( i ) ) * Y_u( i )            &
                    + C_coef( i, 1 ) * Y_u_coef( i, 2 )                        &
                    + C_coef( i, 2 ) * Y_u_coef( i, 1 ) )
              END DO
            END IF

!  record rhs = h^k + (X-X_l)^-1 r_l^k + (X_u-X)^-1 r_u^k

!  for the 1st order rhs

            IF ( k == 1 ) THEN

!  Puiseux case

              IF ( puiseux ) THEN

!  rhs for problem variables:
!   2 ( g + Hx - A^Ty - z_l - z_u ) + (X-X_l)^-1 r_l^1 + (X_u-X)^-1 r_u^1 )

                RHS( : dims%x_free ) = two * GRAD_L( : dims%x_free )
                DO i = dims%x_free + 1, dims%x_l_start - 1
                  RHS( i ) = two * ( GRAD_L( i ) - Z_l( i ) ) +                &
                    Z_l_coef( i, 1 ) / X( i )
                END DO
                DO i = dims%x_l_start, dims%x_u_start - 1
                  RHS( i ) = two * ( GRAD_L( i ) - Z_l( i ) ) +                &
                    Z_l_coef( i, 1 ) / DIST_X_l( i )
                END DO
                DO i = dims%x_u_start, dims%x_l_end
                  RHS( i ) = two * ( GRAD_L( i ) - Z_l( i ) - Z_u( i ) ) +     &
                    Z_l_coef( i, 1 ) / DIST_X_l( i ) +                         &
                    Z_u_coef( i, 1 ) / DIST_X_u( i )
                END DO
                DO i = dims%x_l_end + 1, dims%x_u_end
                  RHS( i ) = two * ( GRAD_L( i ) - Z_u( i ) ) +                &
                    Z_u_coef( i, 1 ) / DIST_X_u( i )
                END DO
                DO i = dims%x_u_end + 1, n
                  RHS( i ) = two * ( GRAD_L( i ) - Z_u( i ) ) -                &
                    Z_u_coef( i, 1 ) / X( i )
                END DO

!  rhs for slack variables:
!    2 ( y - y_l - y_u ) + (C-C_l)^-1 s_l^k + (C_u-C)^-1 s_u^k )

                DO i = dims%c_l_start, dims%c_u_start - 1
                  RHS( dims%c_b + i ) = two * ( Y( i ) - Y_l( i ) ) +          &
                    Y_l_coef( i, 1 ) / DIST_C_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_l_end
                  RHS( dims%c_b + i ) = two * ( Y( i ) - Y_l( i ) - Y_u( i )) +&
                    Y_l_coef( i, 1 ) / DIST_C_l( i ) +                         &
                    Y_u_coef( i, 1 ) / DIST_C_u( i )
                END DO
                DO i = dims%c_l_end + 1, dims%c_u_end
                  RHS( dims%c_b + i ) = two * ( Y( i ) - Y_u( i ) ) +          &
                    Y_u_coef( i, 1 ) / DIST_C_u( i )
                END DO

!  rhs for constraint infeasibilities: 2 ( A x - b )

                RHS( dims%y_s : dims%y_e ) = two * C_RES( : dims%c_u_end )

!  Taylor case

              ELSE

!  rhs for problem variables:
!   g + Hx - A^Ty - z_l - z_u + (X-X_l)^-1 r_l^1 + (X_u-X)^-1 r_u^1

                RHS( : dims%x_free ) = GRAD_L( : dims%x_free )
                DO i = dims%x_free + 1, dims%x_l_start - 1
                  RHS( i ) = GRAD_L( i ) - Z_l( i ) +                          &
                    Z_l_coef( i, 1 ) / X( i )
                END DO
                DO i = dims%x_l_start, dims%x_u_start - 1
                  RHS( i ) = GRAD_L( i ) - Z_l( i ) +                          &
                    Z_l_coef( i, 1 ) / DIST_X_l( i )
                END DO
                DO i = dims%x_u_start, dims%x_l_end
                  RHS( i ) = GRAD_L( i ) - Z_l( i ) - Z_u( i ) +               &
                    Z_l_coef( i, 1 ) / DIST_X_l( i ) +                         &
                    Z_u_coef( i, 1 ) / DIST_X_u( i )
                END DO
                DO i = dims%x_l_end + 1, dims%x_u_end
                  RHS( i ) = GRAD_L( i ) - Z_u( i ) +                          &
                    Z_u_coef( i, 1 ) / DIST_X_u( i )
                END DO
                DO i = dims%x_u_end + 1, n
                  RHS( i ) = GRAD_L( i ) - Z_u( i ) -                          &
                    Z_u_coef( i, 1 ) / X( i )
                END DO

!  rhs for slack variables:
!    y - y_l - y_u + (C-C_l)^-1 s_l^k + (C_u-C)^-1 s_u^k

                DO i = dims%c_l_start, dims%c_u_start - 1
                  RHS( dims%c_b + i ) = Y( i ) - Y_l( i ) +                    &
                    Y_l_coef( i, 1 ) / DIST_C_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_l_end
                  RHS( dims%c_b + i ) = Y( i ) - Y_l( i ) - Y_u( i ) +         &
                    Y_l_coef( i, 1 ) / DIST_C_l( i ) +                         &
                    Y_u_coef( i, 1 ) / DIST_C_u( i )
                END DO
                DO i = dims%c_l_end + 1, dims%c_u_end
                  RHS( dims%c_b + i ) = Y( i ) - Y_u( i ) +                    &
                    Y_u_coef( i, 1 ) / DIST_C_u( i )
                END DO

!  rhs for constraint infeasibilities: A x - b

                RHS( dims%y_s : dims%y_e ) = C_RES( : dims%c_u_end )
              END IF

!  for the 2nd order rhs

            ELSE IF ( k == 2 ) THEN

!  Puiseux case

              IF ( puiseux ) THEN

!  rhs for problem variables:
!   2 ( g + Hx - A^Ty - z_l - z_u ) + (X-X_l)^-1 r_l^2 + (X_u-X)^-1 r_u^2

                RHS( : dims%x_free ) = two * GRAD_L( : dims%x_free )
                DO i = dims%x_free + 1, dims%x_l_start - 1
                  RHS( i ) = two * ( GRAD_L( i ) - Z_l( i ) ) +                &
                    Z_l_coef( i, 2 ) / X( i )
                END DO
                DO i = dims%x_l_start, dims%x_u_start - 1
                  RHS( i ) = two * ( GRAD_L( i ) - Z_l( i ) ) +                &
                    Z_l_coef( i, 2 ) / DIST_X_l( i )
                END DO
                DO i = dims%x_u_start, dims%x_l_end
                  RHS( i ) = two * ( GRAD_L( i ) - Z_l( i ) - Z_u( i ) ) +     &
                    Z_l_coef( i, 2 ) / DIST_X_l( i ) +                         &
                    Z_u_coef( i, 2 ) / DIST_X_u( i )
                END DO
                DO i = dims%x_l_end + 1, dims%x_u_end
                  RHS( i ) = two * ( GRAD_L( i ) - Z_u( i ) ) +                &
                    Z_u_coef( i, 2 ) / DIST_X_u( i )
                END DO
                DO i = dims%x_u_end + 1, n
                  RHS( i ) = two * ( GRAD_L( i ) - Z_u( i ) ) -                &
                    Z_u_coef( i, 2 ) / X( i )
                END DO

!  rhs for slack variables:
!    2 ( y - y_l - y_u ) + (C-C_l)^-1 s_l^2 + (C_u-C)^-1 s_u^2

                DO i = dims%c_l_start, dims%c_u_start - 1
                  RHS( dims%c_b + i ) = two * ( Y( i ) - Y_l( i ) ) +          &
                    Y_l_coef( i, 2 ) / DIST_C_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_l_end
                  RHS( dims%c_b + i ) = two * ( Y( i ) - Y_l( i ) - Y_u( i )) +&
                    Y_l_coef( i, 2 ) / DIST_C_l( i ) +                         &
                    Y_u_coef( i, 2 ) / DIST_C_u( i )
                END DO
                DO i = dims%c_l_end + 1, dims%c_u_end
                  RHS( dims%c_b + i ) = two * ( Y( i ) - Y_u( i ) ) +          &
                    Y_u_coef( i, 2 ) / DIST_C_u( i )
                END DO

!  rhs for constraint infeasibilities: 2 ( A x - b )

                RHS( dims%y_s : dims%y_e ) = two * C_RES( : dims%c_u_end )

!  Taylor case

              ELSE

!  rhs for problem variables: (X-X_l)^-1 r_l^2 + (X_u-X)^-1 r_u^2 )

                RHS( : dims%x_free ) = zero
                DO i = dims%x_free + 1, dims%x_l_start - 1
                  RHS( i ) = Z_l_coef( i, 2 ) / X( i )
                END DO
                DO i = dims%x_l_start, dims%x_u_start - 1
                  RHS( i ) = Z_l_coef( i, 2 ) / DIST_X_l( i )
                END DO
                DO i = dims%x_u_start, dims%x_l_end
                  RHS( i ) = Z_l_coef( i, 2 ) / DIST_X_l( i ) +                &
                             Z_u_coef( i, 2 ) / DIST_X_u( i )
                END DO
                DO i = dims%x_l_end + 1, dims%x_u_end
                  RHS( i ) = Z_u_coef( i, 2 ) / DIST_X_u( i )
                END DO
                DO i = dims%x_u_end + 1, n
                  RHS( i ) = - Z_u_coef( i, 2 ) / X( i )
                END DO

!  rhs for slack variables: (C-C_l)^-1 s_l^2 + (C_u-C)^-1 s_u^2 )

                DO i = dims%c_l_start, dims%c_u_start - 1
                  RHS( dims%c_b + i ) = Y_l_coef( i, 2 ) / DIST_C_l( i )
                END DO
                DO i = dims%c_u_start, dims%c_l_end
                  RHS( dims%c_b + i ) = Y_l_coef( i, 2 ) / DIST_C_l( i ) +     &
                                        Y_u_coef( i, 2 ) / DIST_C_u( i )
                END DO
                DO i = dims%c_l_end + 1, dims%c_u_end
                  RHS( dims%c_b + i ) = Y_u_coef( i, 2 ) / DIST_C_u( i )
                END DO

!  rhs for constraint infeasibilities: A x - b

                RHS( dims%y_s : dims%y_e ) = zero
              END IF

!  for the 3rd order rhs

            ELSE

!  rhs for problem variables: (X-X_l)^-1 r_l^3 + (X_u-X)^-1 r_u^3

              RHS( : dims%x_free ) = zero
              DO i = dims%x_free + 1, dims%x_l_start - 1
                RHS( i ) = Z_l_coef( i, 3 ) / X( i )
              END DO
              DO i = dims%x_l_start, dims%x_u_start - 1
                RHS( i ) = Z_l_coef( i, 3 ) / DIST_X_l( i )
              END DO
              DO i = dims%x_u_start, dims%x_l_end
                RHS( i ) = Z_l_coef( i, 3 ) / DIST_X_l( i ) +                  &
                           Z_u_coef( i, 3 ) / DIST_X_u( i )
              END DO
              DO i = dims%x_l_end + 1, dims%x_u_end
                RHS( i ) = Z_u_coef( i, 3 ) / DIST_X_u( i )
              END DO
              DO i = dims%x_u_end + 1, n
                RHS( i ) = - Z_u_coef( i, 3 ) / X( i )
              END DO

!  rhs for slack variables: (C-C_l)^-1 s_l^3 + (C_u-C)^-1 s_u^3

                DO i = dims%c_l_start, dims%c_u_start - 1
                RHS( dims%c_b + i ) = Y_l_coef( i, 3 ) / DIST_C_l( i )
              END DO
              DO i = dims%c_u_start, dims%c_l_end
                RHS( dims%c_b + i ) = Y_l_coef( i, 3 ) / DIST_C_l( i ) +       &
                                      Y_u_coef( i, 3 ) / DIST_C_u( i )
              END DO
              DO i = dims%c_l_end + 1, dims%c_u_end
                RHS( dims%c_b + i ) = Y_u_coef( i, 3 ) / DIST_C_u( i )
              END DO

!  rhs for constraint infeasibilities: 0

              RHS( dims%y_s : dims%y_e ) = zero
            END IF


!  for the kth order coefficients

          ELSE

!  compute and store ( r_l^k, r_u^k, s_l^k, s_u^k )

            bik = BINOMIAL( 1, k )
            Z_l_coef( dims%x_free + 1 : dims%x_l_end, k ) =                    &
              - bik * X_coef( dims%x_free + 1 : dims%x_l_end, 1 )              &
                    * Z_l_coef( dims%x_free + 1 : dims%x_l_end, k - 1 )
            Z_u_coef( dims%x_u_start : n, k ) =                                &
                bik * X_coef( dims%x_u_start : n, 1 )                          &
                    * Z_u_coef( dims%x_u_start : n, k - 1 )
            Y_l_coef( dims%c_l_start : dims%c_l_end, k ) =                     &
              - bik * C_coef( dims%c_l_start : dims%c_l_end, 1 )               &
                    * Y_l_coef( dims%c_l_start : dims%c_l_end, k - 1 )
            Y_u_coef( dims%c_u_start : dims%c_u_end, k ) =                     &
                bik * C_coef( dims%c_u_start : dims%c_u_end, 1 )               &
                    * Y_u_coef( dims%c_u_start : dims%c_u_end, k - 1 )

            DO i = 2, k - 1
              bik = BINOMIAL( i, k )
              Z_l_coef( dims%x_free + 1 : dims%x_l_end, k ) =                  &
                Z_l_coef( dims%x_free + 1 : dims%x_l_end, k )                  &
                  - bik * X_coef( dims%x_free + 1 : dims%x_l_end, i )          &
                        * Z_l_coef( dims%x_free + 1 : dims%x_l_end, k - i )
              Z_u_coef( dims%x_u_start : n, k ) =                              &
                Z_u_coef( dims%x_u_start : n, k )                              &
                  + bik * X_coef( dims%x_u_start : n, i )                      &
                        * Z_u_coef( dims%x_u_start : n, k - i )
              Y_l_coef( dims%c_l_start : dims%c_l_end, k ) =                   &
                Y_l_coef( dims%c_l_start : dims%c_l_end, k )                   &
                  - bik * C_coef( dims%c_l_start : dims%c_l_end, i )           &
                        * Y_l_coef( dims%c_l_start : dims%c_l_end, k - i )
              Y_u_coef( dims%c_u_start : dims%c_u_end, k ) =                   &
                Y_u_coef( dims%c_u_start : dims%c_u_end, k )                   &
                  + bik * C_coef( dims%c_u_start : dims%c_u_end, i )           &
                        * Y_u_coef( dims%c_u_start : dims%c_u_end, k - i )
            END DO

!  rhs for problem variables:  (X-X_l)^-1 r_l^k ) + (X_u-X)^-1 r_u^k )

            RHS( : dims%x_free ) = zero
            DO i = dims%x_free + 1, dims%x_l_start - 1
              RHS( i ) = Z_l_coef( i, k ) / X( i )
            END DO
            DO i = dims%x_l_start, dims%x_u_start - 1
              RHS( i ) = Z_l_coef( i, k ) / DIST_X_l( i )
            END DO
            DO i = dims%x_u_start, dims%x_l_end
              RHS( i ) = Z_l_coef( i, k ) / DIST_X_l( i )                      &
                       + Z_u_coef( i, k ) / DIST_X_u( i )
            END DO
            DO i = dims%x_l_end + 1, dims%x_u_end
              RHS( i ) = Z_u_coef( i, k ) / DIST_X_u( i )
            END DO
            DO i = dims%x_u_end + 1, n
              RHS( i ) = - Z_u_coef( i, k ) / X( i )
            END DO

!  rhs for slack variables:  (C-C_l)^-1 s_l^k ) + (C_u-C)^-1 s_u^k )

            DO i = dims%c_l_start, dims%c_u_start - 1
              RHS( dims%c_b + i ) = Y_l_coef( i, k ) / DIST_C_l( i )
            END DO
            DO i = dims%c_u_start, dims%c_l_end
              RHS( dims%c_b + i ) = Y_l_coef( i, k ) / DIST_C_l( i )           &
                                  + Y_u_coef( i, k ) / DIST_C_u( i )
            END DO
            DO i = dims%c_l_end + 1, dims%c_u_end
              RHS( dims%c_b + i ) = Y_u_coef( i, k ) / DIST_C_u( i )
            END DO

!  rhs for constraint infeasibilities: 0

            RHS( dims%y_s : dims%y_e ) = zero
          END IF

          IF ( printd ) THEN
            WRITE( out, 2100 ) prefix, ' RHS_x ', RHS( dims%x_s : dims%x_e )
            IF ( m > 0 )                                                     &
              WRITE( out, 2100 ) prefix, ' RHS_y ', RHS( dims%y_s : dims%y_e )
          END IF

! :::::::::::::::::::::::::::::::::::
! 3b. Compute the series coefficients
! :::::::::::::::::::::::::::::::::::

!  solve ( H + (X-X_l)^-1 Z_l               A^T ) (  x^k )
!        (   - (X_u-X)^-1 Z_u                   ) (      )
!        (                    (C-C_l)^-1 Y_l -I ) (  c^k ) = rhs
!        (                   -(C_u-C)^-1 Y_u    ) (      )
!        (       A               -I             ) ( -y^k )

          IF ( printw ) THEN
            IF ( puiseux ) THEN
              WRITE( out, "( A, ' ........... compute ', I0, A2,               &
             &           ' order Puiseux coefficients  ........... ' )" )      &
                prefix, k, STRING_ordinal( k )
            ELSE
              WRITE( out, "( A, ' ............ compute ', I0, A2,              &
             &           ' order Taylor coefficients  ............ ' )" )      &
                prefix, k, STRING_ordinal( k )
            END IF
          END IF

!  use a direct method

          CALL CPU_TIME( time_record ) ; CALL CLOCK_time( clock_record )
          IF ( inform%SBLS_inform%preconditioner == 2 ) THEN
            CALL SBLS_solve( A_sbls%n, A_sbls%m, A_sbls, C_sbls,               &
                             SBLS_data, SBLS_control, inform%SBLS_inform, RHS )
          ELSE IF ( lbfgs ) THEN
            CALL SBLS_solve( A_sbls%n, A_sbls%m, A_sbls, C_sbls, SBLS_data,    &
                         SBLS_control, inform%SBLS_inform, RHS, H_lm = H_lm )
          ELSE
            CALL SBLS_solve_iterative( A_sbls%n, A_sbls%m, H_sbls, A_sbls,     &
                                       RHS, SBLS_data, control%SBLS_control,   &
                                       inform%SBLS_inform )
          END IF
          CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
          time_solve = time_solve + time_now - time_record
          clock_solve = clock_solve + clock_now - clock_record

          inform%status = inform%SBLS_inform%status
          IF ( inform%status /= GALAHAD_ok ) GO TO 700

          IF ( printd ) THEN
            WRITE( out, 2100 ) prefix, ' SOL_x ', RHS( dims%x_s : dims%x_e )
            IF ( m > 0 )                                                       &
              WRITE( out, 2100 ) prefix, ' SOL_y ', RHS( dims%y_s : dims%y_e )
          END IF

!  if the residual of the linear system is larger than the current
!  optimality residual, no further progress is likely

          IF ( inform%SBLS_inform%norm_residual > merit ) THEN

!  it didn't. We might have run out of options ...

            IF ( SBLS_control%factorization == 2 .AND. maxpiv ) THEN
              inform%status = GALAHAD_error_ill_conditioned ; GO TO 600

!  ... or we may change the method ...

            ELSE IF ( SBLS_control%factorization < 2 .AND. maxpiv ) THEN
              pivot_tol = relative_pivot_tol
              maxpiv = pivot_tol >= half
              SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
              SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
              SBLS_control%factorization = 2
              IF ( printi ) WRITE( out,                                        &
                "( A, '    ** Switching to augmented system method' )" ) prefix

!  ... or we can increase the pivot tolerance

            ELSE IF ( SBLS_control%SLS_control%relative_pivot_tolerance        &
                      < relative_pivot_default ) THEN
              pivot_tol = relative_pivot_default
              min_pivot_tol = relative_pivot_default
              maxpiv = .FALSE.
              SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
              SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
!             SBLS_control%factorization = 2
              IF ( printi ) WRITE( out,                                        &
                "( A, '    ** Pivot tolerance increased to', ES11.4 )" )       &
                prefix, pivot_tol
            ELSE
              pivot_tol = half
              min_pivot_tol = half
              maxpiv = .TRUE.
              SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
              SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
!             SBLS_control%factorization = 2
              IF ( printi ) WRITE( out,                                        &
                "( A, '    ** Pivot tolerance increased to', ES11.4 )" )       &
                prefix, pivot_tol
            END IF
            alpha = zero ; nbact = 0

!  refactorize

            GO TO 200
          END IF

!  record ( x^k, c^k, y^k )

          X_coef( : n, k ) = RHS( dims%x_s : dims%x_e )
          C_coef( dims%c_l_start : dims%c_u_end, k ) =                         &
            RHS( dims%c_s : dims%c_e )
          Y_coef( : m, k ) = - RHS( dims%y_s : dims%y_e )

!  compute ( z_l^k, z_u^k, y_l^k, y_u^k ) via

!     z_l^k = (X-X_l)^-1 [ r_l^k - Z_l x^k ]
!     z_u^k = (X_u-X)^-1 [ r_u^k + Z_u x^k ]
!     y_l^k = (C-C_l)^-1 [ s_l^k - Y_l c^k ]
!   & y_u^k = (C_u-C)^-1 [ s_u^k + Y_u c^k ]


          DO i = dims%x_free + 1, dims%x_l_start - 1
            Z_l_coef( i, k ) =                                                 &
             ( Z_l_coef( i, k ) - Z_l( i ) * X_coef( i, k ) ) / X( i )
          END DO

          DO i = dims%x_l_start, dims%x_l_end
            Z_l_coef( i, k ) =                                                 &
             ( Z_l_coef( i, k ) - Z_l( i ) * X_coef( i, k ) ) / DIST_X_l( i )
          END DO

          DO i = dims%x_u_start, dims%x_u_end
            Z_u_coef( i, k ) =                                                 &
              ( Z_u_coef( i, k ) + Z_u( i ) * X_coef( i, k ) ) / DIST_X_u( i )
          END DO

          DO i = dims%x_u_end + 1, n
            Z_u_coef( i, k ) =                                                 &
              - ( Z_u_coef( i, k ) + Z_u( i ) * X_coef( i, k ) ) / X( i )
          END DO

          DO i = dims%c_l_start, dims%c_l_end
            Y_l_coef( i, k ) =                                                 &
              ( Y_l_coef( i, k ) - Y_l( i ) * C_coef( i, k ) ) / DIST_C_l( i )
          END DO

          DO i = dims%c_u_start, dims%c_u_end
            Y_u_coef( i, k ) =                                                 &
              ( Y_u_coef( i, k ) + Y_u( i ) * C_coef( i, k ) ) / DIST_C_u( i )
          END DO
        END DO

!  finally, scale the coefficients v^k <- (-1)^k v^k / k!

        co = one
        DO k = 1, order
          co = - co / REAL( k, KIND = wp )
          X_coef( : , k ) = co * X_coef( : , k )
          C_coef( : , k ) = co * C_coef( : , k )
          Y_coef( : , k ) = co * Y_coef( : , k )
          Z_l_coef( : , k ) = co * Z_l_coef( : , k )
          Z_u_coef( : , k ) = co * Z_u_coef( : , k )
          Y_l_coef( : , k ) = co * Y_l_coef( : , k )
          Y_u_coef( : , k ) = co * Y_u_coef( : , k )
        END DO

        IF ( printw ) THEN
          WRITE( out, "( A, '   k   ||X^k||   ||C^k||   ||Y^k||',              &
        &               ' ||Z_l^k|| ||Z_u^k|| ||Y_l^k|| ||Y_u^k||' )" ) prefix
          DO k = 0, order
            char_x = MAXVAL_ABS( X_coef( : , k ) )
            char_c = MAXVAL_ABS( C_coef( : , k ) )
            char_y = MAXVAL_ABS( Y_coef( : , k ) )
            char_z_l = MAXVAL_ABS( Z_l_coef( : , k ) )
            char_z_u = MAXVAL_ABS( Z_u_coef( : , k ) )
            char_y_l = MAXVAL_ABS( Y_l_coef( : , k ) )
            char_y_u = MAXVAL_ABS( Y_u_coef( : , k ) )
            WRITE( out, "( A, 1X, A, I1, 7A10 )" ) prefix, arc, k,             &
              char_x, char_c, char_y, char_z_l, char_z_u, char_y_l, char_y_u
          END DO
        END IF

!  Additionally, if the Taylor Zhang arc is not being used, we need to include
!  this as a precaution to guarantee convergence

        guarantee = arc /= 'Zh' .OR. puiseux .OR.                              &
                    ( order > 1 .AND. .NOT. control%every_order )

        IF ( guarantee ) THEN

!  Set up the right-hand-side vector

!  record rhs = ( h^k + (X-X_l)^-1 r_l^k + (X_u-X)^-1 r_u^k )
!               ( d^k + (C-C_l)^-1 s_l^k + (C_u-C)^-1 s_u^k )
!               (                   a^k                     )

          IF ( printd ) WRITE( out, 2100 )                                     &
            prefix, ' GRAD_L', GRAD_L( dims%x_s : dims%x_e )

!  compute and store ( r_l^1, r_u^1, s_l^1, s_u^1 )

          DO i = dims%x_free + 1, dims%x_l_end
            DZ_l_zh( i ) = - mu + ( X( i ) - X_l( i ) ) * Z_l( i )
          END DO
          DO i = dims%x_u_start, n
            DZ_u_zh( i ) =   mu + ( X_u( i ) - X( i ) ) * Z_u( i )
          END DO
          DO i = dims%c_l_start, dims%c_l_end
            DY_l_zh( i ) = - mu + ( C( i ) - C_l( i ) ) * Y_l( i )
          END DO
          DO i = dims%c_u_start, dims%c_u_end
            DY_u_zh( i ) =   mu + ( C_u( i ) - C( i ) ) * Y_u( i )
          END DO

!  rhs for problem variables: g + Hx - A^Ty - mu (X-X_l)^-1 e + mu (X_u-X)^-1 e

          RHS( : dims%x_free ) = GRAD_L( : dims%x_free )
          DO i = dims%x_free + 1, dims%x_l_start - 1
            RHS( i ) = GRAD_L( i ) - mu / X( i )
          END DO
          DO i = dims%x_l_start, dims%x_u_start - 1
            RHS( i ) = GRAD_L( i ) - mu / DIST_X_l( i )
          END DO
          DO i = dims%x_u_start, dims%x_l_end
            RHS( i ) = GRAD_L( i ) - mu / DIST_X_l( i ) + mu / DIST_X_u( i )
          END DO
          DO i = dims%x_l_end + 1, dims%x_u_end
            RHS( i ) = GRAD_L( i ) + mu / DIST_X_u( i )
          END DO
          DO i = dims%x_u_end + 1, n
            RHS( i ) = GRAD_L( i ) - mu / X( i )
          END DO

!  rhs for slack variables: y - mu (C-C_l)^-1 e + mu (C_u-C)^-1 e

          DO i = dims%c_l_start, dims%c_u_start - 1
            RHS( dims%c_b + i ) = Y( i ) - mu / DIST_C_l( i )
          END DO
          DO i = dims%c_u_start, dims%c_l_end
            RHS( dims%c_b + i ) = Y( i ) - mu / DIST_C_l( i )                  &
                                         + mu / DIST_C_u( i )
          END DO
          DO i = dims%c_l_end + 1, dims%c_u_end
            RHS( dims%c_b + i ) = Y( i ) + mu / DIST_C_u( i )
          END DO

!  rhs for constraint infeasibilities: A x - b

          IF ( m > 0 ) THEN
            RHS( dims%y_s : dims%y_e ) = C_RES( : dims%c_u_end )

            C_RES( : dims%c_equality ) = - C_l( : dims%c_equality )
            C_RES( dims%c_l_start : dims%c_u_end ) = - SCALE_C * C
            CALL CCQP_AX( m, C_RES, m, a_ne, A_val, A_col, A_ptr,               &
                          n, X, '+ ' )
            inform%primal_infeasibility = MAXVAL( ABS( C_RES ) )
          END IF

          IF ( printd ) THEN
            WRITE( out, 2100 ) prefix, ' RHS_x ', RHS( dims%x_s : dims%x_e )
            IF ( m > 0 )                                                       &
              WRITE( out, 2100 ) prefix, ' RHS_y ', RHS( dims%y_s : dims%y_e )
          END IF

! Compute the coefficients

!  solve ( H + (X-X_l)^-1 Z_l               A^T ) (  x^k )
!        (   - (X_u-X)^-1 Z_u                   ) (      )
!        (                    (C-C_l)^-1 Y_l -I ) (  c^k ) = rhs
!        (                   -(C_u-C)^-1 Y_u    ) (      )
!        (       A               -I             ) ( -y^k )

          IF ( printw ) WRITE( out, "( A, ' ............... compute',          &
         &        ' Zhang-Taylor coefficients  ............... ' )" )  prefix

!  use a direct method

          CALL CPU_TIME( time_record ) ; CALL CLOCK_time( clock_record )
          IF ( inform%SBLS_inform%preconditioner == 2 ) THEN
            CALL SBLS_solve( A_sbls%n, A_sbls%m, A_sbls, C_sbls,               &
                             SBLS_data, SBLS_control, inform%SBLS_inform, RHS )
          ELSE IF ( lbfgs ) THEN
            CALL SBLS_solve( A_sbls%n, A_sbls%m, A_sbls, C_sbls, SBLS_data,    &
                         SBLS_control, inform%SBLS_inform, RHS, H_lm = H_lm )
          ELSE
            CALL SBLS_solve_iterative( A_sbls%n, A_sbls%m, H_sbls, A_sbls,     &
                                       RHS, SBLS_data, control%SBLS_control,   &
                                       inform%SBLS_inform )
          END IF
          CALL CPU_TIME( time_now ) ; CALL CLOCK_time( clock_now )
          time_solve = time_solve + time_now - time_record
          clock_solve = clock_solve + clock_now - clock_record

          IF ( printd ) THEN
            WRITE( out, 2100 ) prefix, ' SOL_x ', RHS( dims%x_s : dims%x_e )
            IF ( m > 0 )                                                       &
              WRITE( out, 2100 ) prefix, ' SOL_y ', RHS( dims%y_s : dims%y_e )
          END IF

          inform%status = inform%SBLS_inform%status
          IF ( inform%status /= GALAHAD_ok ) GO TO 700

!  if the residual of the linear system is larger than the current
!  optimality residual, no further progress is likely

          IF ( inform%SBLS_inform%norm_residual > merit ) THEN

!  it didn't. We might have run out of options ...

            IF ( SBLS_control%factorization == 2 .AND. maxpiv ) THEN
              inform%status = GALAHAD_error_ill_conditioned ; GO TO 600

!  ... or we may change the method ...

            ELSE IF ( SBLS_control%factorization < 2 .AND. maxpiv ) THEN
              pivot_tol = relative_pivot_tol
              maxpiv = pivot_tol >= half
              SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
              SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
              SBLS_control%factorization = 2
              IF ( printi ) WRITE( out,                                        &
                "( A, '    ** Switching to augmented system method' )" ) prefix

!  ... or we can increase the pivot tolerance

            ELSE IF ( SBLS_control%SLS_control%relative_pivot_tolerance        &
                      < relative_pivot_default ) THEN
              pivot_tol = relative_pivot_default
              min_pivot_tol = relative_pivot_default
              maxpiv = .FALSE.
              SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
              SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
!             SBLS_control%factorization = 2
              IF ( printi ) WRITE( out,                                        &
                "( A, '    ** Pivot tolerance increased to', ES11.4 )" )       &
                prefix, pivot_tol
            ELSE
              pivot_tol = half
              min_pivot_tol = half
              maxpiv = .TRUE.
              SBLS_control%SLS_control%relative_pivot_tolerance = pivot_tol
              SBLS_control%SLS_control%minimum_pivot_tolerance = min_pivot_tol
!             SBLS_control%factorization = 2
              IF ( printi ) WRITE( out,                                        &
                "( A, '    ** Pivot tolerance increased to', ES11.4 )" )       &
                prefix, pivot_tol
            END IF
            alpha = zero ; nbact = 0

!  refactorize

            GO TO 200
          END IF

!  record ( x^k, c^k, y^k )

          DX_zh( : n ) = - RHS( dims%x_s : dims%x_e )
          DC_zh( dims%c_l_start : dims%c_u_end ) =                             &
            - RHS( dims%c_s : dims%c_e )
          DY_zh( : m ) = RHS( dims%y_s : dims%y_e )

!  compute ( z_l^k, z_u^k, y_l^k, y_u^k ) via

!     z_l^k = (X-X_l)^-1 [ r_l^k - Z_l x^k ]
!     z_u^k = (X_u-X)^-1 [ r_u^k + Z_u x^k ]
!     y_l^k = (C-C_l)^-1 [ s_l^k - Y_l c^k ]
!   & y_u^k = (C_u-C)^-1 [ s_u^k + Y_u c^k ]


          DO i = dims%x_free + 1, dims%x_l_start - 1
            DZ_l_zh( i ) =                                                     &
             - ( DZ_l_zh( i ) + Z_l( i ) * DX_zh( i ) ) / X( i )
          END DO

          DO i = dims%x_l_start, dims%x_l_end
            DZ_l_zh( i ) =                                                     &
             - ( DZ_l_zh( i ) + Z_l( i ) * DX_zh( i ) ) / DIST_X_l( i )
          END DO

          DO i = dims%x_u_start, dims%x_u_end
            DZ_u_zh( i ) =                                                     &
              - ( DZ_u_zh( i ) - Z_u( i ) * DX_zh( i ) ) / DIST_X_u( i )
          END DO

          DO i = dims%x_u_end + 1, n
            DZ_u_zh( i ) =                                                     &
                ( DZ_u_zh( i ) - Z_u( i ) * DX_zh( i ) ) / X( i )
          END DO

          DO i = dims%c_l_start, dims%c_l_end
            DY_l_zh( i ) =                                                     &
              - ( DY_l_zh( i ) + Y_l( i ) * DC_zh( i ) ) / DIST_C_l( i )
          END DO

          DO i = dims%c_u_start, dims%c_u_end
            DY_u_zh( i ) =                                                     &
              - ( DY_u_zh( i ) - Y_u( i ) * DC_zh( i ) ) / DIST_C_u( i )
          END DO

          IF ( printw ) THEN
            char_x = MAXVAL_ABS( DX_zh( : ) )
            char_c = MAXVAL_ABS( DC_zh( : ) )
            char_y = MAXVAL_ABS( DY_zh( : ) )
            char_z_l = MAXVAL_ABS( DZ_l_zh( : ) )
            char_z_u = MAXVAL_ABS( DZ_u_zh( : ) )
            char_y_l = MAXVAL_ABS( DY_l_zh( : ) )
            char_y_u = MAXVAL_ABS( DY_u_zh( : ) )
            WRITE( out, "( A, ' ZT', I1, 7A10 )" ) prefix, 1,                  &
              char_x, char_c, char_y, char_z_l, char_z_u, char_y_l, char_y_u
          END IF
        END IF

        IF ( printt ) WRITE( out,                                              &
           "( A, ' time for solves = ', F0.2 ) " ) prefix, clock_solve
        inform%time%solve = inform%time%solve + REAL( time_solve, wp )
        inform%time%clock_solve = inform%time%clock_solve + clock_solve

        IF ( printw ) WRITE( out,                                              &
             "( A, ' ............... arc computed ............... ' )" ) prefix

!  =======
!  STEP 4:
!  =======

!  =====================================================================
!  -*-*-*-*-*-*-*-*-*-*-*-   Line search   -*-*-*-*-*-*-*-*-*-*-*-*-*-*-
!  =====================================================================

        IF ( printw ) WRITE( out,                                              &
             "( A, ' .............. get steplength  .............. ' )" ) prefix

!  if a convergence guarantee is required, try the Taylor Zhang arc

        IF ( guarantee ) THEN

!  find the largest alpha in [0,1] for which

!     v_1(alpha) = v + alpha v^1

!  lies in a given wide neighbourhood of the central path

          CALL CCQP_compute_lmaxstep( dims, n, m, nbnds, X, X_l, X_u, DX_zh,    &
                                    C, C_l, C_u, DC_zh, Y_l, Y_u, DY_l_zh,     &
                                    DY_u_zh, Z_l, Z_u, DZ_l_zh, DZ_u_zh,       &
                                    gamma_c, gamma_f, res_primal_dual,         &
                                    alpha_max, inform )

!  check that resulting alpha is not too small

          IF ( inform%status == GALAHAD_error_tiny_step ) GO TO 500

! :::::::::::::::::::::::::::::::::::::::::::::::::::::::
!  Use a safeguarded arc-search, starting from alpha_max
! :::::::::::::::::::::::::::::::::::::::::::::::::::::::

!  record the initial slope along the search arc

          slope = - ( merit - mu * nbnds )

!  define an interval [alhpa_l,alpha_u] containing the required stepsize

          alpha_max = MIN( alpha_max, one )
          alpha_l = zero ; alpha_u = alpha_max ; alpha = alpha_u

          IF ( printw ) WRITE( out, "( /, A, ' ***  Linesearch       ',        &
         &  ' step       trial value     model value ', /, A, 16X, 3ES16.8 )" )&
              prefix, prefix, zero, merit, merit

!  backtracking loop

          nbact = 0
          DO

!  once the interval is small enough, accept the lower bound as the required
!  step so long as this step is not zero

            IF ( alpha_u - alpha_l <= stop_alpha .AND. alpha_l > zero ) THEN
              alpha = alpha_l
              EXIT
            END IF
            IF ( alpha_u <= epsmch ) THEN
              IF ( inform%iter - 1 > muzero_fixed ) THEN
                inform%status = GALAHAD_error_tiny_step
                GO TO 500
              ELSE
                muzero_fixed = inform%iter - 2
                EXIT
              END IF
            END IF

!  the merit value of an acceptable point must be smaller than a linear model

            merit_model = merit + alpha * eta * slope

!  compute the complementarity at the new point on the arc

            comp = zero
            DO i = dims%x_free + 1, dims%x_l_end
              comp = comp + ( Z_l( i ) + alpha * DZ_l_zh( i ) ) *              &
                            ( X( i ) + alpha * DX_zh( i ) - X_l( i ) )
            END DO
            DO i = dims%x_u_start, n
              comp = comp - ( Z_u( i ) + alpha * DZ_u_zh( i ) ) *              &
                            ( X_u( i ) - X( i ) - alpha * DX_zh( i ) )
            END DO

            DO i = dims%c_l_start, dims%c_l_end
              comp = comp + ( Y_l( i ) + alpha * DY_l_zh( i ) ) *              &
                            ( C( i ) + alpha * DC_zh( i ) - C_l( i ) )
            END DO
            DO i = dims%c_u_start, dims%c_u_end
              comp = comp - ( Y_u( i ) + alpha * DY_u_zh( i ) ) *              &
                            ( C_u( i ) - C( i ) - alpha * DC_zh( i ) )
            END DO

!  evaluate the merit function at the new point

            one_minus_alpha = one - alpha
            merit_trial = comp + one_minus_alpha * tau * res_primal_dual
            IF ( printw ) WRITE( out, "( A, 16X, 3ES16.8 )" )                  &
              prefix, alpha, merit_trial, merit_model

!  check to see if the Amijo criterion is satisfied.

            IF ( merit_trial <= merit_model ) THEN

!  if the current arc length is alpha_max, accept this as the required step

              IF ( alpha == alpha_max ) EXIT

!  increase the lower bound

              alpha_l = alpha
              alpha = half * ( alpha + alpha_u )

!  the current alpha is unacceptable ; reduce the upper bound

            ELSE
              alpha_u = alpha
              alpha = half * ( alpha + alpha_l )
            END IF
            nbact = nbact + 1
          END DO
          opt_alpha_guarantee = alpha
          opt_merit_guarantee = merit_trial
          IF ( printp ) WRITE( out, "( A, '      Zhang step, merit =',         &
         &            2ES24.16 )" ) prefix, alpha, merit_trial
        END IF

!  record the initial slope along the search arc

        IF ( arc == 'ZP' ) THEN
          slope = - two * ( merit - mu * nbnds ) + tau * res_primal_dual
        ELSE IF ( puiseux ) THEN
          slope = - two * ( merit - mu * nbnds )
        ELSE
          slope = - ( merit - mu * nbnds )
        END IF
        IF ( printw ) WRITE( out, "( A, '  value and slope = ', 1P, 2D12.4)")  &
          prefix, merit, slope

!  loop over arcs of increasing order

        IF ( control%every_order .OR. order <= 0 ) THEN
          sorder = 1
        ELSE
          sorder = order
        END IF

  step: DO iorder = sorder, order

          CALL CCQP_compute_v_alpha( dims, n, m, iorder, X_coef, C_coef,        &
                           Y_coef, Y_l_coef, Y_u_coef, Z_l_coef, Z_u_coef,     &
                           X, X_l, X_u, Z_l, Z_u, Y, Y_l, Y_u, C,              &
                           C_l, C_u, one, comp )

!  find the largest alpha in [0,1] for which

!     v_l(alpha) = v + sum_k=1^l [ (-1)^k v^k / k! ] alpha^k

!  lies in a given wide neighbourhood of the central path

!         IF ( .TRUE. ) THEN
          IF ( .FALSE. ) THEN    ! serial step
          CALL CCQP_compute_stepsize( dims, n, m, nbnds, iorder,                &
                                     puiseux .AND. arc /= 'ZP',                &
                                     X_coef, C_coef, Y_coef, Y_l_coef,         &
                                     Y_u_coef, Z_l_coef, Z_u_coef,             &
                                     X, X_l, X_u, Z_l, Z_u,                    &
                                     Y, Y_l, Y_u, C, C_l, C_u,                 &
                                     gamma_c, gamma_f, res_primal_dual,        &
                                     alpha_max, slknes, print_level,           &
                                     control, inform )
          ELSE
          CALL CCQP_compute_pmaxstep( dims, n, m, nbnds, iorder,                &
                                     puiseux .AND. arc /= 'ZP',                &
                                     X_coef, C_coef, Y_l_coef, Y_u_coef,       &
                                     Z_l_coef, Z_u_coef, X_l, X_u, C_l, C_u,   &
                                     CS_coef, COEF, ROOTS, gamma_c, gamma_f,   &
                                     res_primal_dual, alpha_max,               &
                                     control, inform, ROOTS_data )

!  compute the best point on the arc and its complementarity

          CALL CCQP_compute_v_alpha( dims, n, m, iorder, X_coef, C_coef, Y_coef,&
                                    Y_l_coef, Y_u_coef, Z_l_coef, Z_u_coef,    &
                                    X, X_l, X_u, Z_l, Z_u, Y, Y_l, Y_u, C,     &
                                    C_l, C_u, alpha_max, slknes )
          END IF

!  check that resulting alpha is not too small

          IF ( inform%status == GALAHAD_error_tiny_step ) THEN
            OPT_alpha( iorder ) = zero
            OPT_merit( iorder ) = merit
            IF ( printp ) WRITE( out, "( A, '  order ', I3, ' step, merit =',  &
           &                 2ES24.16 )" ) prefix, iorder, zero, merit
            CYCLE
          END IF

! :::::::::::::::::::::::::::::::::::::::::::::::::::::::
!  Use a safeguarded arc-search, starting from alpha_max
! :::::::::::::::::::::::::::::::::::::::::::::::::::::::

!  define an interval [alhpa_l,alpha_u] containing the required stepsize

          alpha_l = zero ; alpha_u = alpha_max ; alpha = alpha_max

          IF ( printw ) WRITE( out, "( /, A, ' ***  Linesearch       ',        &
         &  ' step       trial value     model value ', /, A, 16X, 3ES16.8 )" )&
              prefix, prefix, zero, merit, merit

!  backtracking loop

          nbact = 0
          DO

!  once the interval is small enough, accept the lower bound as the required
!  step so long as this step is not zero

            IF ( alpha_u - alpha_l <= stop_alpha .AND. alpha_l > zero ) THEN
              alpha = alpha_l
              EXIT
            END IF
            IF ( alpha_u <= epsmch ) THEN
              IF ( inform%iter - 1 > muzero_fixed ) THEN
                inform%status = GALAHAD_error_tiny_step
                OPT_alpha( iorder ) = zero
                OPT_merit( iorder ) = merit
                CYCLE step
              ELSE
                muzero_fixed = inform%iter - 2
                EXIT
              END IF
            END IF

!  the merit value of an acceptable point must be smaller than a linear model

            merit_model = merit + alpha * eta * slope

!  compute the complementarity at the new point on the arc

            CALL CCQP_compute_v_alpha( dims, n, m, iorder, X_coef, C_coef,      &
                             Y_coef, Y_l_coef, Y_u_coef, Z_l_coef, Z_u_coef,   &
                             X, X_l, X_u, Z_l, Z_u, Y, Y_l, Y_u, C,            &
                             C_l, C_u, alpha, comp )

!  evaluate the merit function at the new point

            one_minus_alpha = one - alpha
            one_minus_alpha = one - alpha
            IF ( puiseux .AND. arc /= 'ZP' ) THEN
              merit_trial = comp + one_minus_alpha ** 2 * tau * res_primal_dual
            ELSE
              merit_trial = comp + one_minus_alpha * tau * res_primal_dual
            END IF
            IF ( printw ) WRITE( out, "( A, 16X, 3ES16.8 )" )                  &
              prefix, alpha, merit_trial, merit_model

!  check to see if the Amijo criterion is satisfied.

            IF ( merit_trial <= merit_model ) THEN

!  if the current arc length is alpha_max, accept this as the required step

              IF ( alpha == alpha_max ) EXIT

!  increase the lower bound

              alpha_l = alpha
              alpha = half * ( alpha + alpha_u )

!  the current alpha is unacceptable ; reduce the upper bound

            ELSE
              alpha_u = alpha
              alpha = half * ( alpha + alpha_l )
            END IF
            nbact = nbact + 1
          END DO
          OPT_alpha( iorder ) = alpha
          OPT_merit( iorder ) = merit_trial
          IF ( printp ) WRITE( out, "( A, '  order ', I3, ' step, merit =',    &
         &                     2ES24.16 )" ) prefix, iorder, alpha, merit_trial
        END DO step


!  if the complementarity is small enough, try a lunge at the solution

        IF ( mu <= control%mu_lunge .AND. alpha < one ) THEN

!  evaluate the lunge

          CALL CCQP_compute_v_alpha( dims, n, m, order, X_coef, C_coef,         &
                           Y_coef, Y_l_coef, Y_u_coef, Z_l_coef, Z_u_coef,     &
                           X, X_l, X_u, Z_l, Z_u, Y, Y_l, Y_u, C,              &
                           C_l, C_u, one, comp )

!  project the lunge into the feasible region

          DO i = dims%x_free + 1, dims%x_l_end
            X( i ) = MAX( X( i ), X_l( i ) )
            Z_l( i ) = MAX( Z_l( i ), zero )
          END DO

          DO i = dims%x_u_start, n
            X( i ) = MIN( X( i ), X_u( i ) )
            Z_u( i ) = MIN( Z_u( i ), zero )
          END DO

          DO i = dims%c_l_start, dims%c_l_end
            C( i ) = MAX( C( i ), C_l( i ) )
            Y_l( i ) = MAX( Y_l( i ), zero )
          END DO

          DO i = dims%c_u_start, dims%c_u_end
            C( i ) = MIN( C( i ), C_u( i ) )
            Y_u( i ) = MIN( Y_u( i ), zero )
          END DO

!  update the distances to the bounds

          DO i = dims%x_l_start, dims%x_l_end
            DIST_X_l( i ) = X( i ) - X_l( i )
          END DO

          DO i = dims%x_u_start, dims%x_u_end
            DIST_X_u( i ) = X_u( i ) - X( i )
          END DO

          DO i = dims%c_l_start, dims%c_l_end
            DIST_C_l( i ) = C( i ) - C_l( i )
          END DO

          DO i = dims%c_u_start, dims%c_u_end
            DIST_C_u( i ) = C_u( i ) - C( i )
          END DO

!  compute the constraint residuals

          IF ( m > 0 ) THEN
            C_RES( : dims%c_equality ) = - C_l( : dims%c_equality )
            C_RES( dims%c_l_start : dims%c_u_end ) = - SCALE_C * C
            CALL CCQP_AX( m, C_RES, m, a_ne, A_val, A_col, A_ptr,      &
                          n, X, '+ ' )
            inform%primal_infeasibility = MAXVAL( ABS( C_RES ) )
            IF ( printw ) WRITE( out, "( A, '  constraint residual ', ES12.4)")&
              prefix, inform%primal_infeasibility
          END IF

!  compute the gradient of the Lagrangian function

          CALL CCQP_Lagrangian_gradient( dims, n, m, X, Y, Y_l, Y_u, Z_l, Z_u, &
                                         a_ne, A_val, A_col, A_ptr,            &
                                         DIST_X_l, DIST_X_u,                   &
                                         DIST_C_l, DIST_C_u,                   &
                                         GRAD_L( dims%x_s : dims%x_e ),        &
                                         control%getdua, dufeas,               &
                                         control%perturb_h,                    &
                                         Hessian_kind, gradient_kind,          &
                                         target_kind,                          &
                                         h_ne = h_ne, H_val = H_val,           &
                                         H_col = H_col, H_ptr = H_ptr,         &
                                         H_lm = H_lm, G = G,                   &
                                         WEIGHT = WEIGHT, X0 = X0 )

!  evaluate the primal and dual infeasibility and merit function

          merit = CCQP_merit_value( dims, n, m, X, Y, Y_l, Y_u, Z_l, Z_u,      &
                                    DIST_X_l, DIST_X_u, DIST_C_l, DIST_C_u,    &
                                    GRAD_L( dims%x_s : dims%x_e ), C_RES,      &
                                    tau, res_primal, inform%dual_infeasibility,&
                                    res_primal_dual, res_cs )

!  compute the complementary slackness, and the min/max components
!  of the primal/dual infeasibilities

          slknes = DOT_PRODUCT( X( dims%x_free + 1 : dims%x_l_start - 1 ),     &
                                Z_l( dims%x_free + 1 : dims%x_l_start - 1 ) ) +&
                   DOT_PRODUCT( DIST_X_l( dims%x_l_start : dims%x_l_end ),     &
                                Z_l( dims%x_l_start : dims%x_l_end ) ) -       &
                   DOT_PRODUCT( DIST_X_u( dims%x_u_start : dims%x_u_end ),     &
                                Z_u( dims%x_u_start : dims%x_u_end ) ) +       &
                   DOT_PRODUCT( X( dims%x_u_end + 1 : n ),                     &
                              Z_u( dims%x_u_end + 1 : n ) ) +                  &
                   DOT_PRODUCT( DIST_C_l( dims%c_l_start : dims%c_l_end ),     &
                                Y_l( dims%c_l_start : dims%c_l_end ) ) -       &
                   DOT_PRODUCT( DIST_C_u( dims%c_u_start : dims%c_u_end ),     &
                                Y_u( dims%c_u_start : dims%c_u_end ) )

          IF ( nbnds > 0 ) THEN
            slknes = slknes / nbnds
          ELSE
            slknes = zero
          END IF

!  test for optimality

!write(6,*) inform%primal_infeasibility, stop_p
!write(6,*) inform%dual_infeasibility, stop_d
!write(6,*) slknes, stop_c

          IF ( inform%primal_infeasibility <= stop_p .AND.                     &
               inform%dual_infeasibility <= stop_d .AND.                       &
               slknes <= stop_c ) THEN

!  checkpoint

            CALL CPU_TIME( time_record )
            CALL CHECKPOINT( inform%iter, time_record - time_start,            &
               MAX( inform%primal_infeasibility,                               &
               inform%dual_infeasibility, slknes ),                            &
               inform%checkpointsIter, inform%checkpointsTime, 1, 16 )

!  if optimal, compute the objective function value

            IF ( Hessian_kind == 0 ) THEN
              inform%obj = f
            ELSE IF ( Hessian_kind == 1 ) THEN
              IF ( target_kind == 0 ) THEN
                inform%obj = f + half * SUM( X ** 2 )
              ELSE IF ( target_kind == 1 ) THEN
                inform%obj = f + half * SUM( ( X - one ) ** 2 )
              ELSE
                inform%obj = f + half * SUM( ( X - X0 ) ** 2 )
              END IF
            ELSE IF ( Hessian_kind == 2 ) THEN
              IF ( target_kind == 0 ) THEN
                inform%obj = f + half * SUM( ( WEIGHT * X ) ** 2 )
              ELSE IF ( target_kind == 1 ) THEN
                inform%obj = f + half * SUM( ( WEIGHT * ( X - one ) ) ** 2 )
              ELSE
                inform%obj = f + half * SUM( ( WEIGHT * ( X - X0 ) ) ** 2 )
              END IF
            ELSE
              IF ( lbfgs ) THEN
                CALL LMS_apply_lbfgs( X, H_lm, i, RESULT = RHS( : n ) )
                curv = DOT_PRODUCT( X, RHS( : n ) )
              ELSE
                curv = zero
                DO i = 1, n
                  xi = X( i )
                  IF ( diagonal_hessian ) THEN
                    curv = curv + xi * xi * H_val( i )
                  ELSE
                    DO l = H_ptr( i ), H_ptr( i + 1 ) - 1
                      j = H_col( l )
                      IF ( i == j ) THEN
                        curv = curv + xi * xi * H_val( l )
                      ELSE
                        curv = curv + two * xi * X( j ) * H_val( l )
                      END IF
                    END DO
                  END IF
                END DO
              END IF
              inform%obj = f + half * curv
            END IF

            IF ( gradient_kind == 1 ) THEN
              inform%obj = inform%obj + SUM( X )
            ELSE IF ( gradient_kind /= 0 ) THEN
              inform%obj = inform%obj + DOT_PRODUCT( G, X )
            END IF

            IF ( .NOT. inform%feasible ) THEN
              IF ( printi ) WRITE( out, 2070 ) prefix
              inform%feasible = .TRUE.
            END IF

!  print a summary of the final iteration

            CALL CLOCK_TIME( clock_now )
            IF ( printi ) THEN
              IF ( printt .OR. ( printi .AND.                                  &
                 inform%iter == start_print ) ) WRITE( out, 2000 ) prefix
              WRITE( out, 2030 ) prefix, inform%iter, re,                      &
               inform%primal_infeasibility, inform%dual_infeasibility,         &
               slknes, inform%obj, one, mu, order, pui, arc, nbact,            &
               clock_now - clock_start
            END IF

            IF ( printd ) THEN
              WRITE( out, 2100 ) prefix, ' X ', X
              IF ( dims%x_free + 1 <= dims%x_l_end ) WRITE( out, 2100 )        &
                prefix,  ' Z_l ', Z_l( dims%x_free + 1 : dims%x_l_end )
              IF (  dims%x_u_start <= n ) WRITE( out, 2100 )                   &
                prefix, ' Z_u ', Z_u( dims%x_u_start :  n )
            END IF
            inform%status = GALAHAD_ok ; GO TO 600
          END IF

!  if the lunge failed, revert to the best point found in the linesearch

        END IF

!  accept the point that gives the largest merit function decrease

        IF ( control%every_order .AND. order > 0 ) THEN
          iorder_array = MINLOC( OPT_merit( : order ) )
          iorder = iorder_array( 1 )
          alpha = OPT_alpha( iorder )
          merit_trial = OPT_merit( order )
        ELSE IF ( .NOT. control%every_order .AND. order > 0 ) THEN
          iorder = order
          alpha = OPT_alpha( iorder )
          merit_trial = OPT_merit( order )
        ELSE
          iorder = 1
        END IF

!  ensure that if guaranteed convergence is required, the merit function
!  decrease is at least as good as that provided by the Zhang-Taylor step

        IF ( puiseux ) THEN
          pui = 'P'
        ELSE
          pui = 'T'
        END IF

        IF ( guarantee ) THEN
          IF ( order <= 0 .OR. opt_merit_guarantee < merit_trial ) THEN
            iorder = 0
            pui = 'T'
            arc = 'Zh'
            alpha = opt_alpha_guarantee
            merit_trial = opt_merit_guarantee
          END IF
        END IF

!  recover the point that gives the largest merit function decrease

        IF ( iorder > 0 ) THEN
          CALL CCQP_compute_v_alpha( dims, n, m, iorder, X_coef, C_coef,       &
                           Y_coef, Y_l_coef, Y_u_coef, Z_l_coef, Z_u_coef,     &
                           X, X_l, X_u, Z_l, Z_u, Y, Y_l, Y_u, C,              &
                           C_l, C_u, alpha, comp )

        ELSE
          DO i = 1, n
            X( i ) = X_coef( i, 0 ) + alpha * DX_zh( i )
          END DO
          DO i = dims%x_free + 1, dims%x_l_end
            Z_l( i ) = Z_l_coef( i, 0 ) + alpha * DZ_l_zh( i )
          END DO
          DO i = dims%x_u_start, n
            Z_u( i ) = Z_u_coef( i, 0 ) + alpha * DZ_u_zh( i )
          END DO
          DO i = 1, m
            Y( i ) = Y_coef( i, 0 ) + alpha * DY_zh( i )
          END DO
          DO i = dims%c_l_start, dims%c_u_end
            C( i ) = C_coef( i, 0 ) + alpha * DC_zh( i )
          END DO
          DO i = dims%c_l_start, dims%c_l_end
            Y_l( i ) = Y_l_coef( i, 0 ) + alpha * DY_l_zh( i )
          END DO
          DO i = dims%c_u_start, dims%c_u_end
            Y_u( i ) = Y_u_coef( i, 0 ) + alpha * DY_u_zh( i )
          END DO

          comp = zero
          DO i = dims%x_free + 1, dims%x_l_end
            comp = comp + ( X( i ) - X_l( i ) ) * Z_l( i )
          END DO
          DO i = dims%x_u_start, n
            comp = comp + ( X( i ) - X_u( i ) ) * Z_u( i )
          END DO
          DO i = dims%c_l_start, dims%c_l_end
            comp = comp + ( C( i ) - C_l( i ) ) * Y_l( i )
          END DO
          DO i = dims%c_u_start, dims%c_u_end
            comp = comp + ( C( i ) - C_u( i ) ) * Y_u( i )
          END DO

        END IF

        inform%nbacts = inform%nbacts + nbact

!  update the distances to the bounds with some precaution against exterme
!  roundoff

        DO i = dims%x_l_start, dims%x_l_end
          IF ( X( i ) <= X_l( i ) ) X( i ) = X( i ) + ABS( X( i ) ) * epsmch
          DIST_X_l( i ) = X( i ) - X_l( i )
        END DO

        DO i = dims%x_u_start, dims%x_u_end
          IF ( X( i ) >= X_u( i ) ) X( i ) = X( i ) - ABS( X( i ) ) * epsmch
          DIST_X_u( i ) = X_u( i ) - X( i )
        END DO

        DO i = dims%c_l_start, dims%c_l_end
          IF ( C( i ) <= C_l( i ) ) C( i ) = C( i ) + ABS( C( i ) ) * epsmch
          DIST_C_l( i ) = C( i ) - C_l( i )
        END DO

        DO i = dims%c_u_start, dims%c_u_end
          IF ( C( i ) >= C_u( i ) ) C( i ) = C( i ) - ABS( C( i ) ) * epsmch
          DIST_C_u( i ) = C_u( i ) - C( i )
        END DO

!  =======
!  STEP 5:
!  =======

!  =====================================================================
!  -*-*-*-*-*-*-*-*-*-*-*-   Book keeping  -*-*-*-*-*-*-*-*-*-*-*-*-*-*-
!  =====================================================================

!  compute the constraint residuals

        IF ( m > 0 ) THEN
          C_RES( : dims%c_equality ) = - C_l( : dims%c_equality )
          C_RES( dims%c_l_start : dims%c_u_end ) = - SCALE_C * C
          CALL CCQP_AX( m, C_RES, m, a_ne, A_val, A_col, A_ptr,      &
                        n, X, '+ ' )
          inform%primal_infeasibility = MAXVAL( ABS( C_RES ) )
          IF ( printw ) WRITE( out, "( A, '  constraint residual ', ES12.4 )" )&
            prefix, inform%primal_infeasibility
!         WRITE( 6, "( ' rec, cal cres = ', 2ES12.4 )" )                       &
!           inform%primal_infeasibility, MAXVAL( ABS( C_RES ) )
        END IF

!  compute the gradient of the Lagrangian function

        CALL CCQP_Lagrangian_gradient( dims, n, m, X, Y, Y_l, Y_u, Z_l, Z_u,   &
                                       a_ne, A_val, A_col, A_ptr,              &
                                       DIST_X_l, DIST_X_u, DIST_C_l, DIST_C_u, &
                                       GRAD_L( dims%x_s : dims%x_e ),          &
                                       control%getdua, dufeas,                 &
                                       control%perturb_h,                      &
                                       Hessian_kind, gradient_kind,            &
                                       target_kind,                            &
                                       h_ne = h_ne, H_val = H_val,             &
                                       H_col = H_col, H_ptr = H_ptr,           &
                                       H_lm = H_lm, G = G,                     &
                                       WEIGHT = WEIGHT, X0 = X0 )

!  update the values of the merit function, the gradient of the Lagrangian,
!  and the constraint residuals

!       GRAD_L( dims%x_s : dims%x_e ) = GRAD_L( dims%x_s : dims%x_e ) +        &
!         alpha * HX( dims%x_s : dims%x_e )

!       C_RES = one_minus_alpha * C_RES

!  update the norm of the constraint residual

!       inform%primal_infeasibility =one_minus_alpha*inform%primal_infeasibility

!  compute the objective function value

        IF ( Hessian_kind == 0 ) THEN
          inform%obj = f
        ELSE IF ( Hessian_kind == 1 ) THEN
          IF ( target_kind == 0 ) THEN
            inform%obj = f + half * SUM( X ** 2 )
          ELSE IF ( target_kind == 1 ) THEN
            inform%obj = f + half * SUM( ( X - one ) ** 2 )
          ELSE
            inform%obj = f + half * SUM( ( X - X0 ) ** 2 )
          END IF
        ELSE IF ( Hessian_kind == 2 ) THEN
          IF ( target_kind == 0 ) THEN
            inform%obj = f + half * SUM( ( WEIGHT * X ) ** 2 )
          ELSE IF ( target_kind == 1 ) THEN
            inform%obj = f + half * SUM( ( WEIGHT * ( X - one ) ) ** 2 )
          ELSE
            inform%obj = f + half * SUM( ( WEIGHT * ( X - X0 ) ) ** 2 )
          END IF
        ELSE
          IF ( lbfgs ) THEN
            CALL LMS_apply_lbfgs( X, H_lm, i, RESULT = RHS( : n ) )
            curv = DOT_PRODUCT( X, RHS( : n ) )
          ELSE
            curv = zero
            DO i = 1, n
              xi = X( i )
              IF ( diagonal_hessian ) THEN
                curv = curv + xi * xi * H_val( i )
              ELSE
                DO l = H_ptr( i ), H_ptr( i + 1 ) - 1
                  j = H_col( l )
                  IF ( i == j ) THEN
                    curv = curv + xi * xi * H_val( l )
                  ELSE
                    curv = curv + two * xi * X( j ) * H_val( l )
                  END IF
                END DO
              END IF
            END DO
          END IF
          inform%obj = f + half * curv
        END IF

        IF ( gradient_kind == 1 ) THEN
          inform%obj = inform%obj + SUM( X )
        ELSE IF ( gradient_kind /= 0 ) THEN
          inform%obj = inform%obj + DOT_PRODUCT( G, X )
        END IF

!  evaluate the merit function

        merit = CCQP_merit_value( dims, n, m, X, Y, Y_l, Y_u, Z_l, Z_u,        &
                                 DIST_X_l, DIST_X_u, DIST_C_l, DIST_C_u,       &
                                 GRAD_L( dims%x_s : dims%x_e ), C_RES,         &
                                 tau, res_primal, inform%dual_infeasibility,   &
                                 res_primal_dual, res_cs )

!  compute the complementary slackness, and the min/max components
!  of the primal/dual infeasibilities

        slknes_x = DOT_PRODUCT( X( dims%x_free + 1 : dims%x_l_start - 1 ),     &
                                Z_l( dims%x_free + 1 : dims%x_l_start - 1 ) ) +&
                   DOT_PRODUCT( DIST_X_l( dims%x_l_start : dims%x_l_end ),     &
                                Z_l( dims%x_l_start : dims%x_l_end ) ) -       &
                   DOT_PRODUCT( DIST_X_u( dims%x_u_start : dims%x_u_end ),     &
                                Z_u( dims%x_u_start : dims%x_u_end ) ) +       &
                   DOT_PRODUCT( X( dims%x_u_end + 1 : n ),                     &
                              Z_u( dims%x_u_end + 1 : n ) )
        slknes_c = DOT_PRODUCT( DIST_C_l( dims%c_l_start : dims%c_l_end ),     &
                                Y_l( dims%c_l_start : dims%c_l_end ) ) -       &
                   DOT_PRODUCT( DIST_C_u( dims%c_u_start : dims%c_u_end ),     &
                                Y_u( dims%c_u_start : dims%c_u_end ) )
        slknes = slknes_x + slknes_c

        slkmin_x = MIN( MINVAL( X( dims%x_free + 1 : dims%x_l_start - 1 ) *    &
                                Z_l( dims%x_free + 1 : dims%x_l_start - 1 ) ), &
                        MINVAL( DIST_X_l( dims%x_l_start : dims%x_l_end ) *    &
                                Z_l( dims%x_l_start : dims%x_l_end ) ),        &
                        MINVAL( - DIST_X_u( dims%x_u_start : dims%x_u_end ) *  &
                                Z_u( dims%x_u_start : dims%x_u_end ) ),        &
                        MINVAL( X( dims%x_u_end + 1 : n ) *                    &
                                Z_u( dims%x_u_end + 1 : n ) ) )
        slkmin_c = MIN( MINVAL( DIST_C_l( dims%c_l_start : dims%c_l_end ) *    &
                                Y_l( dims%c_l_start : dims%c_l_end ) ),        &
                        MINVAL( - DIST_C_u( dims%c_u_start : dims%c_u_end ) *  &
                                Y_u( dims%c_u_start : dims%c_u_end ) ) )
        slkmin = MIN( slkmin_x, slkmin_c )

        slkmax_x = MAX( MAXVAL( X( dims%x_free + 1 : dims%x_l_start - 1 ) *    &
                                Z_l( dims%x_free + 1 : dims%x_l_start - 1 ) ), &
                        MAXVAL( DIST_X_l( dims%x_l_start : dims%x_l_end ) *    &
                                Z_l( dims%x_l_start : dims%x_l_end ) ),        &
                        MAXVAL( - DIST_X_u( dims%x_u_start : dims%x_u_end ) *  &
                                Z_u( dims%x_u_start : dims%x_u_end ) ),        &
                        MAXVAL( X( dims%x_u_end + 1 : n ) *                    &
                                Z_u( dims%x_u_end + 1 : n ) ) )
        slkmax_c = MAX( MAXVAL( DIST_C_l( dims%c_l_start : dims%c_l_end ) *    &
                                Y_l( dims%c_l_start : dims%c_l_end ) ),        &
                        MAXVAL( - DIST_C_u( dims%c_u_start : dims%c_u_end ) *  &
                                Y_u( dims%c_u_start : dims%c_u_end ) ) )

        p_min = MIN( MINVAL( X( dims%x_free + 1 : dims%x_l_start - 1 ) ),      &
                     MINVAL( DIST_X_l( dims%x_l_start : dims%x_l_end ) ),      &
                     MINVAL( DIST_X_u( dims%x_u_start : dims%x_u_end ) ),      &
                     MINVAL( - X( dims%x_u_end + 1 : n ) ),                    &
                     MINVAL( DIST_C_l( dims%c_l_start : dims%c_l_end ) ),      &
                     MINVAL( DIST_C_u( dims%c_u_start : dims%c_u_end ) ) )

        p_max = MAX( MAXVAL( X( dims%x_free + 1 : dims%x_l_start - 1 ) ),      &
                     MAXVAL( DIST_X_l( dims%x_l_start : dims%x_l_end ) ),      &
                     MAXVAL( DIST_X_u( dims%x_u_start : dims%x_u_end ) ),      &
                     MAXVAL( - X( dims%x_u_end + 1 : n ) ),                    &
                     MAXVAL( DIST_C_l( dims%c_l_start : dims%c_l_end ) ),      &
                     MAXVAL( DIST_C_u( dims%c_u_start : dims%c_u_end ) ) )

        d_min = MIN( MINVAL(   Z_l( dims%x_free + 1 : dims%x_l_end ) ),        &
                     MINVAL( - Z_u( dims%x_u_start : n ) ),                    &
                     MINVAL(   Y_l( dims%c_l_start : dims%c_l_end ) ),         &
                     MINVAL( - Y_u( dims%c_u_start : dims%c_u_end ) ) )

        d_max = MAX( MAXVAL(   Z_l( dims%x_free + 1 : dims%x_l_end ) ),        &
                     MAXVAL( - Z_u( dims%x_u_start : n ) ),                    &
                     MAXVAL(   Y_l( dims%c_l_start : dims%c_l_end ) ),         &
                     MAXVAL( - Y_u( dims%c_u_start : dims%c_u_end ) ) )

        IF ( nbnds_x > 0 ) THEN
          slknes_x = slknes_x / nbnds_x
        ELSE
          slknes_x = zero
        END IF

        IF ( nbnds_c > 0 ) THEN
          slknes_c = slknes_c / nbnds_c
        ELSE
          slknes_c = zero
        END IF
        IF ( nbnds > 0 ) THEN
          slknes = slknes / nbnds
          inform%complementary_slackness = slknes
        ELSE
          slknes = zero
        END IF

!  checkpoint

        CALL CPU_TIME( time_record )
        CALL CHECKPOINT( inform%iter, time_record - time_start,                &
           MAX( inform%primal_infeasibility,                                   &
           inform%dual_infeasibility, slknes ),                                &
           inform%checkpointsIter, inform%checkpointsTime, 1, 16 )

!  test for optimality

        IF ( inform%primal_infeasibility <= stop_p .AND.                       &
             inform%dual_infeasibility <= stop_d .AND.                         &
             slknes <= stop_c ) THEN

!write(6,*) inform%primal_infeasibility, stop_p
!write(6,*) inform%dual_infeasibility, stop_d
!write(6,*) slknes, stop_c

          IF ( .NOT. inform%feasible ) THEN
            IF ( printi ) WRITE( out, 2070 ) prefix
            inform%feasible = .TRUE.
          END IF

!  print a summary of the final iteration

          CALL CLOCK_TIME( clock_now )
          IF ( printi ) THEN
            IF ( printt .OR. ( printi .AND.                                    &
               inform%iter == start_print ) ) WRITE( out, 2000 ) prefix
            WRITE( out, 2030 ) prefix, inform%iter, re,                        &
             inform%primal_infeasibility, inform%dual_infeasibility,           &
             slknes, inform%obj, one, mu, order, pui, arc, nbact,              &
             clock_now - clock_start
          END IF

          IF ( printd ) THEN
            WRITE( out, 2100 ) prefix, ' X ', X
            IF ( dims%x_free + 1 <= dims%x_l_end ) WRITE( out, 2100 )          &
              prefix,  ' Z_l ', Z_l( dims%x_free + 1 : dims%x_l_end )
            IF (  dims%x_u_start <= n ) WRITE( out, 2100 )                     &
              prefix, ' Z_u ', Z_u( dims%x_u_start :  n )
          END IF
          inform%status = GALAHAD_ok ; GO TO 600
        END IF

        IF ( printw .AND. nbnds > 0 ) WRITE( out, 2130 )                       &
          prefix, slknes, prefix, slknes_x, prefix, slknes_c, prefix, slkmin_x,&
          slkmax_x, prefix, slkmin_c, slkmax_c, prefix, p_min, p_max, prefix,  &
          d_min, d_max

!  test to see if we are feasible

        IF ( inform%primal_infeasibility <= stop_p ) THEN
          IF ( control%just_feasible ) THEN
            inform%status = GALAHAD_ok
            inform%feasible = .TRUE.
            IF ( printi ) THEN
              CALL CLOCK_TIME( clock_now )
              WRITE( out, 2070 ) prefix
              WRITE( out, 2030 ) prefix, inform%iter, re,                      &
                inform%primal_infeasibility, inform%dual_infeasibility,        &
                inform%complementary_slackness, zero, alpha, mu, nbact,        &
                clock_now - clock_start
              IF ( printt ) WRITE( out, 2000 ) prefix
            END IF
            GO TO 500
          END IF

          IF ( .NOT. inform%feasible ) THEN
            IF ( printi ) WRITE( out, 2070 ) prefix
            inform%feasible = .TRUE.
            IF ( Hessian_kind == 0 .AND. gradient_kind == 0 ) THEN
              IF ( slkmin_x >= epsmch .AND. slkmin_c >= epsmch ) THEN
                inform%potential = CCQP_potential_value( dims, n, X, DIST_X_l, &
                                                  DIST_X_u, DIST_C_l, DIST_C_u )
              ELSE
                inform%potential = infinity
              END IF
            END IF
          END IF
        END IF

!  =======
!  STEP 6:
!  =======

!  =====================================================================
!  -*-*-*-*-*-*-*-*- Penalty and Indicator Updates -*-*-*-*-*-*-*-*-*-*-
!  =====================================================================

!  compute the new penalty parameter

        sigma = sigma_max
        IF ( arc == 'ZS' ) THEN
          mu = slknes
        ELSE
          IF ( inform%iter > muzero_fixed )                                    &
            mu = MIN( SQRT( ABS( slknes ) ), sigma ) * ABS( slknes )
        END IF

!  estimate the variable and constraint exit status

        IF ( get_stat ) THEN
          B_stat_old = B_stat ; C_stat_old = C_stat
!         DO i = 1, dims%c_l_start-1
!           write(6,"(' cl ', I7,' c,y =', 2ES9.1)") i, C_res(i), Y( i )
!         END DO
          CALL CCQP_indicators( dims, n, m, C_l, C_u, C_last, C,               &
                               DIST_C_l, DIST_C_u, X_l, X_u, X_last, X,        &
                               DIST_X_l, DIST_X_u, Y_l, Y_u, Z_l, Z_u,         &
                               Y_last, Z_last,                                 &
                               control, C_stat = C_stat, B_stat = B_stat )

!  count the number of active constraints/bounds

          IF ( printw )                                                        &
            WRITE( out, "( A, ' indicators: n_active/n, m_active/m ', 4I7 )" ) &
               prefix, COUNT( B_stat /= 0 ), n, COUNT( C_stat /= 0 ), m

          IF ( n <= 20 .AND. m <= 20 ) THEN
            write(6,"( ' B_stat ', /, ( 10I7 ) )" ) B_stat
            write(6,"( ' C_stat ', /, ( 10I7 ) )" ) C_stat
          END IF

          b_change = COUNT( B_stat_old - B_stat /= 0 )
          c_change = COUNT( C_stat_old - C_stat /= 0 )

!  if desired, see if the predicted variable and constraint exit status
!  provides an optimal solution; only test if the predicted set has changed

          IF ( b_change + c_change /= 0 ) THEN
            WRITE( out, "( A, 7X, ' changes in predicted B/C_stat = ',         &
           &    I0, ', ', I0, ', lunging for solution ...' )" )                &
               prefix, b_change, c_change
            CALL CCQP_lunge( dims, n, m, A_val, A_col, A_ptr, C_l, C_u,        &
                            X_l, X_u, X_last, C_last, Y_last, Z_last,          &
                            Hessian_kind, gradient_kind, target_kind,          &
                            H_val, H_col, H_ptr, WEIGHT, X0, G,                &
                            C_stat, B_Stat, control, optimal )

!            IF ( n <= 20 .AND. m <= 20 ) THEN
              write(6,"( ' X before ', /, ( 5ES12.4 ) )" ) X
              write(6,"( ' X ', /, ( 5ES12.4 ) )" ) X_last 
              write(6,"( ' C before ', /, ( 5ES12.4 ) )" ) C_res
              write(6,"( ' C ', /, ( 5ES12.4 ) )" ) C_last 
              write(6,"( ' Y before ', /, ( 5ES12.4 ) )" ) Y
              write(6,"( ' Y ', /, ( 5ES12.4 ) )" ) Y_last 
              write(6,"( ' Z before ', /, ( 5ES12.4 ) )" ) Z
              write(6,"( ' Z ', /, ( 5ES12.4 ) )" ) Z_last 
!           END IF

            IF ( optimal ) THEN
              IF ( printi ) WRITE( out, "( A, 7X,                              &
             &   ' lunge successful, optimal solution found' )" ) prefix
              X = X_last ; C_res = C_last ; Y = Y_last ; Z = Z_last
              stat_known = .TRUE.
              GO TO 500
            ELSE
              IF ( printi ) WRITE( out, "( A, 7X,                              &
             &   ' lunge unsuccessful' )" ) prefix
            END IF
          END IF
        END IF

!       IF ( mu < one .AND. stat_required ) THEN
        IF ( mu < control%mu_lunge .AND. stat_required ) THEN
          get_stat = .TRUE.
          C_last( dims%c_l_start : dims%c_u_end )                              &
            = C( dims%c_l_start : dims%c_u_end )
          X_last = X

          DO i = dims%c_l_start, dims%c_u_start - 1
            Y_last( i ) = Y_l( i )
          END DO
          DO i = dims%c_u_start, dims%c_l_end
            IF ( DIST_C_l( i ) <= DIST_C_u( i ) ) THEN
              Y_last( i ) = Y_l( i )
            ELSE
              Y_last( i ) = Y_u( i )
            END IF
          END DO
          DO i = dims%c_l_end + 1, dims%c_u_end
            Y_last( i ) = Y_u( i )
          END DO

          Z_last( : dims%x_free ) = zero
          DO i = dims%x_free + 1, dims%x_u_start - 1
            Z_last( i ) = Z_l( i )
          END DO
          DO i = dims%x_u_start, dims%x_l_end
            IF ( DIST_X_l( i ) <= DIST_X_u( i ) ) THEN
              Z_last( i ) = Z_l( i )
            ELSE
              Z_last( i ) = Z_u( i )
            END IF
          END DO
          DO i = dims%x_l_end + 1, n
            Z_last( i ) = Z_u( i )
          END DO
        END IF

!  compute the projected gradient of the Lagrangian function

        pjgnrm = zero
        DO i = 1, n
          gi = GRAD_L( i )
          IF ( gi < zero ) THEN
            gi = - MIN( ABS( X_u( i ) - X( i ) ), - gi )
          ELSE
            gi = MIN( ABS( X_l( i ) - X( i ) ), gi )
          END IF
          pjgnrm = MAX( pjgnrm, ABS( gi ) )
        END DO

        IF ( printd ) THEN
          WRITE( out, 2100 ) prefix, ' DIST_X_l ',                             &
            X( dims%x_free + 1 : dims%x_l_start - 1 ), DIST_X_l
          WRITE( out, 2100 ) prefix, ' DIST_X_u ',                             &
            DIST_X_u, - X( dims%x_u_end + 1 : n )
          WRITE( out, "( ' ' )" )
        END IF

        IF ( printd ) WRITE( out, 2110 ) prefix, pjgnrm, prefix,               &
          inform%primal_infeasibility
      END DO

!  ---------------------------------------------------------------------
!  ---------------------- End of Major Iteration -----------------------
!  ---------------------------------------------------------------------

  500 CONTINUE

!  print details of the solution obtained

  600 CONTINUE

!  Compute the final objective function value

      IF ( Hessian_kind == 0 ) THEN
        inform%obj = f
      ELSE IF ( Hessian_kind == 1 ) THEN
        IF ( target_kind == 0 ) THEN
          inform%obj = f + half * SUM( X ** 2 )
        ELSE IF ( target_kind == 1 ) THEN
          inform%obj = f + half * SUM( ( X - one ) ** 2 )
        ELSE
          inform%obj = f + half * SUM( ( X - X0 ) ** 2 )
        END IF
      ELSE IF ( Hessian_kind == 2 ) THEN
        IF ( target_kind == 0 ) THEN
          inform%obj = f + half * SUM( ( WEIGHT * X ) ** 2 )
        ELSE IF ( target_kind == 1 ) THEN
          inform%obj = f + half * SUM( ( WEIGHT * ( X - one ) ) ** 2 )
        ELSE
          inform%obj = f + half * SUM( ( WEIGHT * ( X - X0 ) ) ** 2 )
        END IF
      ELSE
        IF ( lbfgs ) THEN
          CALL LMS_apply_lbfgs( X, H_lm, i, RESULT = RHS( : n ) )
          curv = DOT_PRODUCT( X, RHS( : n ) )
        ELSE
          curv = zero
          DO i = 1, n
            xi = X( i )
            IF ( diagonal_hessian ) THEN
              curv = curv + xi * xi * H_val( i )
            ELSE
              DO l = H_ptr( i ), H_ptr( i + 1 ) - 1
                j = H_col( l )
                IF ( i == j ) THEN
                  curv = curv + xi * xi * H_val( l )
                ELSE
                  curv = curv + two * xi * X( j ) * H_val( l )
                END IF
              END DO
            END IF
          END DO
        END IF
        inform%obj = f + half * curv
      END IF

      IF ( gradient_kind == 1 ) THEN
        inform%obj = inform%obj + SUM( X )
      ELSE IF ( gradient_kind /= 0 ) THEN
        inform%obj = inform%obj + DOT_PRODUCT( G, X )
      END IF

      IF ( printi ) THEN
        WRITE( out, "( /, A, '  Final objective function value is', ES22.14,   &
      &       /, A, '  Total number of iterations = ', I0,                     &
      &       /, A, '  Total number of backtracks = ', I0 )" )                 &
          prefix, inform%obj, prefix, inform%iter, prefix, inform%nbacts
        WRITE( out, 2110 ) prefix, pjgnrm, prefix, inform%primal_infeasibility
        IF ( control%getdua ) WRITE( out,                                      &
         "( /, A, ' Advanced starting point is used for dual variables' )" )   &
           prefix
        WRITE( out, "( A, '  gamma_c,f are', 2ES11.4 )" )                      &
          prefix, gamma_c, gamma_f
        IF ( puiseux ) THEN
          IF ( control%every_order ) THEN
            IF ( control%arc == 1 ) THEN
              WRITE( control%out, "( A, '  Maximum order ', I0, ' Puiseux',    &
           &   ' fit to the Zhang arc is used' )" ) prefix, order
            ELSE IF ( control%arc == 2 ) THEN
              WRITE( control%out, "( A, '  Maximum order ', I0, ' Puiseux',    &
           &   ' fit to the Zhao-Sun arc is used' )" ) prefix, order
            ELSE IF ( control%arc == 4 ) THEN
              WRITE( control%out, "( A, '  Maximum order ', I0, ' Puiseux',    &
           &   ' fit to the Zhang-Puiseux arc is used' )" ) prefix, order
            ELSE IF ( control%arc == 5 ) THEN
              WRITE( control%out, "( A, '  Maximum order ', I0, ' Puiseux',    &
           &   ' fit to the Zhang-Puiseux arc is used' )" ) prefix, order
            ELSE
              WRITE( control%out, "( A, '  Maximum order ', I0, ' Puiseux',    &
           &   ' fit to the Zhang-Zhao-Sun arc is used' )" ) prefix, order
            END IF
          ELSE
            IF ( control%arc == 1 ) THEN
              WRITE( control%out, "( A, '  Order ', I0, ' Puiseux',            &
           &   ' fit to the Zhang arc is used' )" ) prefix, order
            ELSE IF ( control%arc == 2 ) THEN
              WRITE( control%out, "( A, '  Order ', I0, ' Puiseux',            &
           &   ' fit to the Zhao-Sun arc is used' )" ) prefix, order
            ELSE IF ( control%arc == 4 ) THEN
              WRITE( control%out, "( A, '  Order ', I0, ' Puiseux',            &
           &   ' fit to the Zhang-Puiseux arc is used' )" ) prefix, order
            ELSE IF ( control%arc == 5 ) THEN
              WRITE( control%out, "( A, '  Order ', I0, ' Puiseux',            &
           &   ' fit to the Zhang-Puiseux arc is used' )" ) prefix, order
            ELSE
              WRITE( control%out, "( A, '  Order ', I0, ' Puiseux',            &
           &   ' fit to the Zhang-Zhao-Sun arc is used' )" ) prefix, order
            END IF
          END IF
        ELSE
          IF ( control%every_order ) THEN
            IF ( control%arc == 1 ) THEN
              WRITE( control%out, "( A, '  Maximum order ', I0, ' Taylor',     &
           &   ' fit to the Zhang arc is used' )" ) prefix, order
            ELSE IF ( control%arc == 2 ) THEN
              WRITE( control%out, "( A, '  Maximum order ', I0, ' Taylor',     &
           &   ' fit to the Zhao-Sun arc is used' )" ) prefix, order
!           ELSE IF ( control%arc == 4 ) THEN
!             WRITE( control%out, "( A, '  Maximum order ', I0, ' Taylor',     &
!          &   ' fit to the Zhang-Puiseux arc is used' )" ) prefix, order
            ELSE
              WRITE( control%out, "( A, '  Maximum order ', I0, ' Taylor',     &
           &   ' fit to the Zhang-Zhao-Sun arc is used' )" ) prefix, order
            END IF
          ELSE
            IF ( control%arc == 1 ) THEN
              WRITE( control%out, "( A, '  Order ', I0, ' Taylor',             &
           &   ' fit to the Zhang arc is used' )" ) prefix, order
            ELSE IF ( control%arc == 2 ) THEN
              WRITE( control%out, "( A, '  Order ', I0, ' Taylor',             &
           &   ' fit to the Zhao-Sun arc is used' )" ) prefix, order
!           ELSE IF ( control%arc == 4 ) THEN
!             WRITE( control%out, "( A, '  Order ', I0, ' Taylor',             &
!          &   ' fit to the Zhang Puiseux arc is used' )" ) prefix, order
            ELSE
              WRITE( control%out, "( A, '  Order ', I0, ' Taylor',             &
           &   ' fit to the Zhang-Zhao-Sun arc is used' )" ) prefix, order
            END IF
          END IF
        END IF
      END IF

!  If required, make the solution exactly complementary

      IF ( control%feasol ) THEN
        DO i = dims%x_free + 1, dims%x_l_start - 1
          IF ( ABS( Z_l( i ) ) < ABS( X( i ) ) ) THEN
            Z_l( i ) = zero
          ELSE
            X( i ) = X_l( i )
          END IF
        END DO

        DO i = dims%x_l_start, dims%x_l_end
          IF ( ABS( Z_l( i ) ) < ABS( DIST_X_l( i ) ) ) THEN
            Z_l( i ) = zero
          ELSE
            X( i ) = X_l( i )
          END IF
        END DO

        DO i = dims%x_u_start, dims%x_u_end
          IF ( ABS( Z_u( i ) ) < ABS( DIST_X_u( i ) ) ) THEN
            Z_u( i ) = zero
          ELSE
            X( i ) = X_u( i )
          END IF
        END DO

        DO i = dims%x_u_end + 1, n
          IF ( ABS( Z_u( i ) ) < ABS( X( i ) ) ) THEN
            Z_u( i ) = zero
          ELSE
            X( i ) = X_u( i )
          END IF
        END DO
      END IF

!  Exit

 700  CONTINUE
      IF ( optimal ) GO TO 810

!  Set the dual variables

      Z( : dims%x_free ) = zero
      DO i = dims%x_free + 1, dims%x_u_start - 1
        Z( i ) = Z_l( i )
      END DO

      DO i = dims%x_u_start, dims%x_l_end
        IF ( ABS( Z_l( i ) ) <= ABS( Z_u( i ) ) ) THEN
          Z( i ) = Z_u( i )
        ELSE
          Z( i ) = Z_l( i )
        END IF
      END DO

      DO i = dims%x_l_end + 1, n
        Z( i ) = Z_u( i )
      END DO

!  Unscale the constraint bounds

      DO i = dims%c_l_start, dims%c_l_end
        C_l( i ) = C_l( i ) * SCALE_C( i )
      END DO

      DO i = dims%c_u_start, dims%c_u_end
        C_u( i ) = C_u( i ) * SCALE_C( i )
      END DO

!  Compute the values of the constraints

      C_RES( : m ) = zero
      CALL CCQP_AX( m, C_RES( : m ), m, a_ne, A_val, A_col,                    &
                    A_ptr, n, X, '+ ')
      IF ( printi .AND. m > 0 ) THEN
        WRITE( out, "( A, '  Computed constraint residual is', ES11.4 )" )     &
             prefix,                                                           &
             MAX( zero, MAXVAL( ABS( C_l( : dims%c_equality ) -                &
                                     C_RES(: dims%c_equality ) ) ),            &
                        MAXVAL( C_l(  dims%c_l_start : dims%c_l_end ) -        &
                                C_RES(  dims%c_l_start : dims%c_l_end ) ),     &
                        MAXVAL( C_RES( dims%c_u_start : dims%c_u_end ) -       &
                                C_u( dims%c_u_start : dims%c_u_end ) ) )
      END IF

!  estimate the variable and constraint exit status

      IF ( stat_required .AND. .NOT. stat_known ) THEN
        B_stat_old = B_stat ; C_stat_old = C_stat
        CALL CCQP_indicators( dims, n, m, C_l, C_u, C_last, C,                 &
                             DIST_C_l, DIST_C_u, X_l, X_u, X_last, X,          &
                             DIST_X_l, DIST_X_u, Y_l, Y_u, Z_l, Z_u,           &
                             Y_last, Z_last,                                   &
                             control, C_stat = C_stat, B_stat = B_stat )


!  count the number of active constraints/bounds

        IF ( printi ) WRITE( out, "( A, '  Indicators: n_active/n,',           &
       &   ' m_active/m = ', 2( I0, '/', I0, : ', ' ) )" )                     &
             prefix, COUNT( B_stat /= 0 ), n, COUNT( C_stat /= 0 ), m

        b_change = COUNT( B_stat_old - B_stat /= 0 )
        c_change = COUNT( C_stat_old - C_stat /= 0 )

!  if desired, see if the predicted variable and constraint exit status
!  provides an optimal solution

        IF ( b_change + c_change /= 0 ) THEN
          WRITE( out, "( A, 7X, ' changes in predicted B/C_stat = ',           &
         &    I0, ', ', I0, ', lunging for solution ...' )" )                  &
             prefix, b_change, c_change
          CALL CCQP_lunge( dims, n, m, A_val, A_col, A_ptr, C_l, C_u,          &
                          X_l, X_u, X_last, C_last, Y_last, Z_last,            &
                          Hessian_kind, gradient_kind, target_kind,            &
                          H_val, H_col, H_ptr, WEIGHT, X0, G,                  &
                          C_stat, B_Stat, control, optimal )

          IF ( optimal ) THEN
            IF ( printi ) WRITE( out, "( A, 7X,                                &
           &   ' lunge successful, optimal solution found' )" ) prefix
            X = X_last ; C_res = C_last ; Y = Y_last ; Z = Z_last
            stat_known = .TRUE.
          ELSE
            IF ( printi ) WRITE( out, "( A, 7X,                                &
           &   ' lunge unsuccessful' )" ) prefix
          END IF
        END IF
      END IF

!  If necessary, print warning messages

  810 CONTINUE

      SBLS_data%last_preconditioner = no_last
      SBLS_data%last_factorization = no_last

      IF ( printi ) then
        SELECT CASE( inform%status )
          CASE( GALAHAD_error_restrictions  ) ; WRITE( out, "( /, A,           &
         & '  Warning - input paramters incorrect' )" ) prefix
          CASE( GALAHAD_error_no_center ) ; WRITE( out, "( /, A,               &
         & '  Warning - the analytic center appears to be unbounded' )" ) prefix
          CASE( GALAHAD_error_bad_bounds ) ; WRITE( out, "( /, A,              &
         &  '  Warning - the constraints are inconsistent' )" ) prefix
          CASE( GALAHAD_error_primal_infeasible ) ; WRITE( out, "( /, A,       &
         &  '  Warning - the constraints appear to be inconsistent' )" ) prefix
          CASE( GALAHAD_error_factorization ) ; WRITE( out, "( /, A,           &
         &   '  Warning - factorization failure' )" ) prefix
          CASE( GALAHAD_error_ill_conditioned ) ; WRITE( out, "( /, A,         &
         &   '  Warning - no further progress possible' )"  ) prefix
          CASE( GALAHAD_error_tiny_step ) ; WRITE( out, "( /, A,               &
         &   '  Warning - step too small to make progress,',                   &
         &   ' problem maybe infeasible' )" ) prefix
          CASE( GALAHAD_error_max_iterations ) ; WRITE( out, "( /, A,          &
         &   '  Warning - iteration bound exceeded' )" ) prefix
          CASE( GALAHAD_error_unbounded ) ; WRITE( out, "( /, A,               &
         &   '  Warning - problem appears to be unbounded from below' )") prefix
        END SELECT
        IF ( control%perturb_h /= zero )  WRITE( control%out,                  &
          "( A, '  Hessian perturbed by', ES11.4 )" ) prefix, control%perturb_h
        IF ( inform%SBLS_inform%factorization == 0 .OR.                        &
             inform%SBLS_inform%factorization == 1 ) THEN
          WRITE( control%out, "( A, '  Schur-complement factorization is',     &
         &       ' used (pivot tol =', ES9.2, ')' )" ) prefix,                 &
            SBLS_control%SLS_control%relative_pivot_tolerance
        ELSE
          WRITE( control%out, "( A, '  Augmented system factorization is',     &
         &       ' used (pivot tol =', ES9.2, ')' )" ) prefix,                 &
            SBLS_control%SLS_control%relative_pivot_tolerance
        END IF
        WRITE( out, "( A, '  Linear system solver ', A,                        &
       &               ' (preconditioner = ', I0, ') is used' )" )             &
            prefix, TRIM( SBLS_control%symmetric_linear_solver ),              &
            inform%SBLS_inform%preconditioner
        IF ( inform%SBLS_inform%preconditioner /= 2 .AND.                      &
             inform%SBLS_inform%preconditioner /= 7 )                          &
          WRITE( out, "( A, 2X, I0, ' projected CG iterations taken ' )" )     &
            prefix, inform%SBLS_inform%iter_pcg
        SELECT CASE ( control%indicator_type )
        CASE( 1 ) 
          WRITE( out, "( A, '  Primal indicators used' )" ) prefix
        CASE( 2 ) 
          WRITE( out, "( A, '  Primal-dual indicators used' )" ) prefix
        CASE( 3 ) 
          WRITE( out, "( A, '  Tapia indicators used' )" ) prefix
        END SELECT
      END IF
      IF ( control%out > 0 .AND. control%print_level >= 5 )                    &
        WRITE( control%out, "( A, ' leaving CCQP_solve_main ' )" ) prefix

      RETURN

!  Non-executable statements

 2000 FORMAT( /, A, ' Iter   p-feas  d-feas com-slk    obj   ',                &
                '  step   target   arc bt     time' )
 2020 FORMAT( A, I5, A1, 3ES8.1, ES9.1, '     -   ', ES7.1,                    &
            '    -   -', 0P, F9.2 )
 2030 FORMAT( A, I5, A1, 3ES8.1, ES9.1, ES8.1, 1X, ES7.1, I3, A1, A2, I3,      &
              0P, F9.2 )
 2070 FORMAT( /, A, ' ========================= feasible point found',         &
                    ' =========================', / )
 2100 FORMAT( A, A, /, ( 10X, 7ES10.2 ) )
 2110 FORMAT( /, A, '  Norm of projected gradient is', ES11.4,                 &
              /, A, '  Norm of infeasibility is', ES11.4 )
 2130 FORMAT( A, 21X, ' == >  mu estimated   = ', ES10.2, /,                   &
              A, 21X, '       mu_x estimated = ', ES10.2, /,                   &
              A, 21X, '       mu_c estimated = ', ES10.2, /,                   &
              A, 21X, ' min/max slackness_x = ', 2ES12.4, /,                   &
              A, 21X, ' min/max slackness_c = ', 2ES12.4, /,                   &
              A, 14X, ' min/max primal feasibility = ', 2ES12.4, /,            &
              A, 14X, ' min/max dual   feasibility = ', 2ES12.4 )

      CONTAINS

        FUNCTION MAXVAL_ABS( VECT )
        CHARACTER ( len = 10 ) :: MAXVAL_ABS
        REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( : ) :: VECT
        IF ( SIZE( VECT ) > 0 ) THEN
          WRITE( MAXVAL_ABS, "( ES10.2 )" ) MAXVAL( ABS( VECT ) )
        ELSE
          MAXVAL_ABS = '     -    '
        END IF
        RETURN
        END FUNCTION MAXVAL_ABS

!  End of CCQP_solve_main

      END SUBROUTINE CCQP_solve_main

!-*-*-*-*-*-*-   C C Q P _ T E R M I N A T E   S U B R O U T I N E   -*-*-*-*-*

      SUBROUTINE CCQP_terminate( data, control, inform )

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!      ..............................................
!      .                                            .
!      .  Deallocate internal arrays at the end     .
!      .  of the computation                        .
!      .                                            .
!      ..............................................

!  Arguments:
!
!   data    see Subroutine CCQP_initialize
!   control see Subroutine CCQP_initialize
!   inform  see Subroutine CCQP_solve

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_data_type ), INTENT( INOUT ) :: data
      TYPE ( CCQP_control_type ), INTENT( IN ) :: control
      TYPE ( CCQP_inform_type ), INTENT( INOUT ) :: inform

!  Local variables

      CHARACTER ( LEN = 80 ) :: array_name

!  Deallocate all arrays allocated by FDC

      CALL FDC_terminate( data%FDC_data, data%FDC_control,                     &
                          inform%FDC_inform )
      IF ( inform%FDC_inform%status /= GALAHAD_ok )                            &
        inform%status = inform%FDC_inform%status
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

!  Deallocate all arrays allocated by CRO

      CALL CRO_terminate( data%CRO_data, control%CRO_control,                  &
                          inform%CRO_inform )
      IF ( inform%CRO_inform%status /= GALAHAD_ok )                            &
        inform%status = inform%CRO_inform%status
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

!  Deallocate all arrays allocated within SBLS

      CALL SBLS_terminate( data%SBLS_data, control%SBLS_control,               &
                           inform%SBLS_inform )
      inform%status = inform%SBLS_inform%status
      IF ( inform%SBLS_inform%status /= 0 ) THEN
        inform%status = GALAHAD_error_deallocate
        inform%bad_alloc = 'ccqp: data%SBLS'
        IF ( control%deallocate_error_fatal ) RETURN
      END IF

!  Deallocate FIT internal arrays

      CALL FIT_terminate( data%FIT_data, control%FIT_control,                  &
                           inform%FIT_inform )
      IF ( inform%FIT_inform%status /= GALAHAD_ok )                            &
        inform%status = inform%FIT_inform%status
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

!  Deallocate ROOTS internal arrays

      CALL ROOTS_terminate( data%ROOTS_data, control%ROOTS_control,            &
                           inform%ROOTS_inform )
      IF ( inform%ROOTS_inform%status /= GALAHAD_ok )                          &
        inform%status = inform%ROOTS_inform%status
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

!  Deallocate QPP internal arrays

      CALL QPP_terminate( data%QPP_map, data%QPP_control,                      &
                          data%QPP_inform )
      IF ( data%QPP_inform%status /= GALAHAD_ok ) THEN
        inform%status = GALAHAD_error_deallocate
        inform%alloc_status = data%QPP_inform%alloc_status
        inform%bad_alloc = data%QPP_inform%bad_alloc
        IF ( control%deallocate_error_fatal ) RETURN
      END IF

      CALL QPP_terminate( data%QPP_map_freed, data%QPP_control,                &
                          data%QPP_inform)
      IF ( data%QPP_inform%status /= GALAHAD_ok ) THEN
        inform%status = GALAHAD_error_deallocate
        inform%alloc_status = data%QPP_inform%alloc_status
        inform%bad_alloc = data%QPP_inform%bad_alloc
        IF ( control%deallocate_error_fatal ) RETURN
      END IF

!  Deallocate all arrays allocated for the preprocessing stage

      CALL QPP_terminate( data%QPP_map, data%QPP_control, data%QPP_inform )
      IF ( data%QPP_inform%status /= 0 ) THEN
        inform%status = GALAHAD_error_deallocate
        inform%alloc_status = data%QPP_inform%alloc_status
        inform%bad_alloc = 'ccqp: data%QPP'
        IF ( control%deallocate_error_fatal ) RETURN
      END IF

!  Deallocate all remaing allocated arrays

      array_name = 'ccqp: data%INDEX_C_freed'
      CALL SPACE_dealloc_array( data%INDEX_C_freed,                            &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%GRAD_L'
      CALL SPACE_dealloc_array( data%GRAD_L,                                   &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DIST_X_l'
      CALL SPACE_dealloc_array( data%DIST_X_l,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DIST_X_u'
      CALL SPACE_dealloc_array( data%DIST_X_u,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Z_l'
      CALL SPACE_dealloc_array( data%Z_l,                                      &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Z_u'
      CALL SPACE_dealloc_array( data%Z_u,                                      &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%BARRIER_X'
      CALL SPACE_dealloc_array( data%BARRIER_X,                                &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Y_l'
      CALL SPACE_dealloc_array( data%Y_l,                                      &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DY_l'
      CALL SPACE_dealloc_array( data%DY_l,                                     &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DIST_C_l'
      CALL SPACE_dealloc_array( data%DIST_C_l,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Y_u'
      CALL SPACE_dealloc_array( data%Y_u,                                      &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DY_u'
      CALL SPACE_dealloc_array( data%DY_u,                                     &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DIST_C_u'
      CALL SPACE_dealloc_array( data%DIST_C_u,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%C'
      CALL SPACE_dealloc_array( data%C,                                        &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%BARRIER_C'
      CALL SPACE_dealloc_array( data%BARRIER_C,                                &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%SCALE_C'
      CALL SPACE_dealloc_array( data%SCALE_C,                                  &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%RHS'
      CALL SPACE_dealloc_array( data%RHS,                                      &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%H_s'
      CALL SPACE_dealloc_array( data%H_s,                                      &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%A_s'
      CALL SPACE_dealloc_array( data%A_s,                                      &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%X_last'
      CALL SPACE_dealloc_array( data%X_last,                                   &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Y_last'
      CALL SPACE_dealloc_array( data%Y_last,                                   &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Z_last'
      CALL SPACE_dealloc_array( data%Z_last,                                   &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%OPT_alpha'
      CALL SPACE_dealloc_array( data%OPT_alpha,                                &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%OPT_merit'
      CALL SPACE_dealloc_array( data%OPT_merit,                                &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%X_coef'
      CALL SPACE_dealloc_array( data%X_coef,                                   &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%C_coef'
      CALL SPACE_dealloc_array( data%C_coef,                                   &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Y_coef'
      CALL SPACE_dealloc_array( data%Y_coef,                                   &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Y_l_coef'
      CALL SPACE_dealloc_array( data%Y_l_coef,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Y_u_coef'
      CALL SPACE_dealloc_array( data%Y_u_coef,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Z_l_coef'
      CALL SPACE_dealloc_array( data%Z_l_coef,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%Z_u_coef'
      CALL SPACE_dealloc_array( data%Z_u_coef,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%BINOMIAL'
      CALL SPACE_dealloc_array( data%BINOMIAL,                                 &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DX_zh'
      CALL SPACE_dealloc_array( data%DX_zh,                                    &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DC_zh'
      CALL SPACE_dealloc_array( data%DC_zh,                                    &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DY_zh'
      CALL SPACE_dealloc_array( data%DY_zh,                                    &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DY_l_zh'
      CALL SPACE_dealloc_array( data%DY_l_zh,                                  &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DY_u_zh'
      CALL SPACE_dealloc_array( data%DY_u_zh,                                  &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DZ_l_zh'
      CALL SPACE_dealloc_array( data%DZ_l_zh,                                  &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%DZ_u_zh'
      CALL SPACE_dealloc_array( data%DZ_u_zh,                                  &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%A_sbls%row'
      CALL SPACE_dealloc_array( data%A_sbls%row,                               &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%A_sbls%col'
      CALL SPACE_dealloc_array( data%A_sbls%col,                               &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%A_sbls%val'
      CALL SPACE_dealloc_array( data%A_sbls%val,                               &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%H_sbls%row'
      CALL SPACE_dealloc_array( data%H_sbls%row,                               &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%H_sbls%col'
      CALL SPACE_dealloc_array( data%H_sbls%col,                               &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: data%H_sbls%val'
      CALL SPACE_dealloc_array( data%H_sbls%val,                               &
         inform%status, inform%alloc_status, array_name = array_name,          &
         bad_alloc = inform%bad_alloc, out = control%error )
      IF ( control%deallocate_error_fatal .AND.                                &
           inform%status /= GALAHAD_ok ) RETURN

      RETURN

!  End of subroutine CCQP_terminate

      END SUBROUTINE CCQP_terminate

! -  G A L A H A D -  C C Q P _ f u l l _ t e r m i n a t e  S U B R O U T I N E -

     SUBROUTINE CCQP_full_terminate( data, control, inform )

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!   Deallocate all private storage

!  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( CCQP_full_data_type ), INTENT( INOUT ) :: data
     TYPE ( CCQP_control_type ), INTENT( IN ) :: control
     TYPE ( CCQP_inform_type ), INTENT( INOUT ) :: inform

!-----------------------------------------------
!   L o c a l   V a r i a b l e s
!-----------------------------------------------

     CHARACTER ( LEN = 80 ) :: array_name

!  deallocate workspace

     CALL CCQP_terminate( data%ccqp_data, control, inform )

!  deallocate any internal problem arrays

     array_name = 'ccqp: data%prob%X'
     CALL SPACE_dealloc_array( data%prob%X,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%X_l'
     CALL SPACE_dealloc_array( data%prob%X_l,                                  &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%X_u'
     CALL SPACE_dealloc_array( data%prob%X_u,                                  &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%G'
     CALL SPACE_dealloc_array( data%prob%G,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%Y'
     CALL SPACE_dealloc_array( data%prob%Y,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%Z'
     CALL SPACE_dealloc_array( data%prob%Z,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%C'
     CALL SPACE_dealloc_array( data%prob%C,                                    &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%C_l'
     CALL SPACE_dealloc_array( data%prob%C_l,                                  &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%C_u'
     CALL SPACE_dealloc_array( data%prob%C_u,                                  &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%WEIGHT'
     CALL SPACE_dealloc_array( data%prob%WEIGHT,                               &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%X0'
     CALL SPACE_dealloc_array( data%prob%X0,                                   &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%H%ptr'
     CALL SPACE_dealloc_array( data%prob%H%ptr,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%H%row'
     CALL SPACE_dealloc_array( data%prob%H%row,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%H%col'
     CALL SPACE_dealloc_array( data%prob%H%col,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%H%val'
     CALL SPACE_dealloc_array( data%prob%H%val,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%A%ptr'
     CALL SPACE_dealloc_array( data%prob%A%ptr,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%A%row'
     CALL SPACE_dealloc_array( data%prob%A%row,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%A%col'
     CALL SPACE_dealloc_array( data%prob%A%col,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     array_name = 'ccqp: data%prob%A%val'
     CALL SPACE_dealloc_array( data%prob%A%val,                                &
        inform%status, inform%alloc_status, array_name = array_name,           &
        bad_alloc = inform%bad_alloc, out = control%error )
     IF ( control%deallocate_error_fatal .AND. inform%status /= 0 ) RETURN

     RETURN

!  End of subroutine CCQP_full_terminate

     END SUBROUTINE CCQP_full_terminate

!-*-*-*-*-*-   C C Q P _ M E R I T _ V A L U E   F U N C T I O N   -*-*-*-*-*-*-

      FUNCTION CCQP_merit_value( dims, n, m, X, Y, Y_l, Y_u, Z_l, Z_u,         &
                                 DIST_X_l, DIST_X_u, DIST_C_l, DIST_C_u,       &
                                 GRAD_L, C_RES, tau,                           &
                                 res_primal, res_dual, res_primal_dual, res_cs )

      REAL ( KIND = wp ) CCQP_merit_value

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Compute the value of the merit function
!
!     | < z_l . ( x - x_l ) > +  < z_u . ( x_u - x ) > +
!       < y_l . ( c - c_l ) > +  < y_u . ( c_u - c ) > | +
!            || ( GRAD_L - z_l - z_u ) ||
!      tau * || (   y - y_l - y_u    ) ||
!            || (  A x - SCALE_c * c ) ||_2
!
!  where GRAD_L = W*W*( x - x0 ) - A(transpose) y or H x + g -  A(transpose) y
!  is the gradient of the Lagrangian
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n, m
      REAL ( KIND = wp ), INTENT( IN ) :: tau
      REAL ( KIND = wp ), INTENT( OUT ) :: res_primal, res_dual
      REAL ( KIND = wp ), INTENT( OUT ) :: res_primal_dual, res_cs
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X, GRAD_L
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_l_start : dims%x_l_end ) :: DIST_x_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_free + 1 : dims%x_l_end ) :: Z_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_u_start : dims%x_u_end ) :: DIST_X_u
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_u_start : n ) :: Z_u
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( m ) :: Y, C_RES
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%c_l_start : dims%c_l_end ) :: Y_l, DIST_C_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%c_u_start : dims%c_u_end ) :: Y_u, DIST_C_u

!  Local variables

      INTEGER :: i

!  Compute in the l_2-norm

      res_dual = SUM( GRAD_L( : dims%x_free ) ** 2 ) ; res_cs = zero

!  Problem variables:

      DO i = dims%x_free + 1, dims%x_l_start - 1
        res_dual = res_dual + ( GRAD_L( i ) - Z_l( i ) ) ** 2
        res_cs = res_cs + Z_l( i ) * X( i )
      END DO
      DO i = dims%x_l_start, dims%x_u_start - 1
        res_dual = res_dual + ( GRAD_L( i ) - Z_l( i ) ) ** 2
        res_cs = res_cs + Z_l( i ) * DIST_X_l( i )
      END DO
      DO i = dims%x_u_start, dims%x_l_end
        res_dual = res_dual + ( GRAD_L( i ) - Z_l( i ) - Z_u( i ) ) ** 2
        res_cs = res_cs + Z_l( i ) * DIST_X_l( i ) - Z_u( i ) * DIST_X_u( i )
      END DO
      DO i = dims%x_l_end + 1, dims%x_u_end
        res_dual = res_dual + ( GRAD_L( i ) - Z_u( i ) ) ** 2
        res_cs = res_cs - Z_u( i ) * DIST_X_u( i )
      END DO
      DO i = dims%x_u_end + 1, n
        res_dual = res_dual + ( GRAD_L( i ) - Z_u( i ) ) ** 2
        res_cs = res_cs + Z_u( i ) * X( i )
      END DO

!  Slack variables:

      DO i = dims%c_l_start, dims%c_u_start - 1
        res_dual = res_dual + ( Y( i ) - Y_l( i ) ) ** 2
        res_cs = res_cs + Y_l( i ) * DIST_C_l( i )
      END DO
      DO i = dims%c_u_start, dims%c_l_end
        res_dual = res_dual + ( Y( i ) - Y_l( i ) - Y_u( i ) ) ** 2
        res_cs = res_cs + Y_l( i ) * DIST_C_l( i ) - Y_u( i ) * DIST_C_u( i )
      END DO
      DO i = dims%c_l_end + 1, dims%c_u_end
        res_dual = res_dual + ( Y( i ) - Y_u( i ) ) ** 2
        res_cs = res_cs - Y_u( i ) * DIST_C_u( i )
      END DO

      res_primal = SUM( C_RES ** 2 )
      res_primal_dual = SQRT( res_primal + res_dual )

      res_primal = SQRT( res_primal )
      res_dual = SQRT( res_dual )

      CCQP_merit_value = ABS( res_cs ) + tau * res_primal_dual

      RETURN

!  End of function CCQP_merit_value

      END FUNCTION CCQP_merit_value

!-*-*-*-  C C Q P _ P O T E N T I A L _ V A L U E   S U B R O U T I N E  -*-*-*-

      FUNCTION CCQP_potential_value( dims, n, X, DIST_X_l, DIST_X_u,           &
                                     DIST_C_l, DIST_C_u )
      REAL ( KIND = wp ) CCQP_potential_value

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Compute the value of the potential function
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_l_start : dims%x_l_end ) :: DIST_X_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_u_start : dims%x_u_end ) :: DIST_X_u
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%c_l_start : dims%c_l_end ) :: DIST_C_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%c_u_start : dims%c_u_end ) :: DIST_C_u

! Compute the potential terms

      CCQP_potential_value =                                                   &
        - SUM( LOG( X( dims%x_free + 1 : dims%x_l_start - 1 ) ) )              &
        - SUM( LOG( DIST_X_l ) ) - SUM( LOG( DIST_X_u ) )                      &
        - SUM( LOG( - X( dims%x_u_end + 1 : n ) ) )                            &
        - SUM( LOG( DIST_C_l ) ) - SUM( LOG( DIST_C_u ) )

      RETURN

!  End of CCQP_potential_value

      END FUNCTION CCQP_potential_value

!-*-  C C Q P _ L A G R A N G I A N _ G R A D I E N T   S U B R O U T I N E  -*-

      SUBROUTINE CCQP_Lagrangian_gradient( dims, n, m, X, Y, Y_l, Y_u,         &
                                          Z_l, Z_u, a_ne, A_val, A_col, A_ptr, &
                                          DIST_X_l, DIST_X_u, DIST_C_l,        &
                                          DIST_C_u, GRAD_L, getdua, dufeas,    &
                                          perturb_h, Hessian_kind,             &
                                          gradient_kind, target_kind,          &
                                          h_ne, H_val, H_col,                  &
                                          H_ptr, H_lm, G, WEIGHT, X0 )

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Compute the gradient of the Lagrangian function
!
!  GRAD_L = W*W*( x - x0 ) - A(transpose) y or H x + g -  A(transpose) y
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n, m, Hessian_kind, gradient_kind, target_kind
      REAL ( KIND = wp ), INTENT( IN ) :: dufeas, perturb_h
      LOGICAL, INTENT( IN ) :: getdua
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( m ) :: Y
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( n ) :: GRAD_L
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_l_start : dims%x_l_end ) :: DIST_X_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_u_start : dims%x_u_end ) :: DIST_X_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%x_free + 1 : dims%x_l_end ) :: Z_l
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%x_u_start : n ) :: Z_u
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%c_l_start : dims%c_l_end ) :: DIST_C_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%c_u_start : dims%c_u_end ) :: DIST_C_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%c_l_start : dims%c_l_end ) :: Y_l
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%c_u_start : dims%c_u_end ) :: Y_u
      INTEGER, INTENT( IN ) :: a_ne
      INTEGER, INTENT( IN ), OPTIONAL :: h_ne
      INTEGER, INTENT( IN ), DIMENSION( a_ne ) :: A_col
      INTEGER, INTENT( IN ), DIMENSION( m + 1 ) :: A_ptr
      INTEGER, INTENT( IN ), DIMENSION( n + 1 ), OPTIONAL  :: H_ptr
      INTEGER, INTENT( IN ), DIMENSION( : ), OPTIONAL  :: H_col
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( a_ne ) :: A_val
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( : ), OPTIONAL  :: H_val
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ), OPTIONAL :: G
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ), OPTIONAL :: WEIGHT, X0
      TYPE ( LMS_data_type ), OPTIONAL, INTENT( INOUT ) :: H_lm

!  Local variables

      INTEGER :: i
      REAL ( KIND = wp ) :: gi

!  Add the product A( transpose ) y to the gradient of the quadratic

      IF ( Hessian_kind == 0 ) THEN
        GRAD_L = zero
      ELSE IF ( Hessian_kind == 1 ) THEN
        IF ( target_kind == 0 ) THEN
          GRAD_L = X
        ELSE IF ( target_kind == 1 ) THEN
          GRAD_L = X - one
        ELSE
          GRAD_L = X - X0
        END IF
      ELSE IF ( Hessian_kind == 2 ) THEN
        IF ( target_kind == 0 ) THEN
          GRAD_L = ( WEIGHT ** 2 ) * X
        ELSE IF ( target_kind == 1 ) THEN
          GRAD_L = ( WEIGHT ** 2 ) * ( X - one )
        ELSE
          GRAD_L = ( WEIGHT ** 2 ) * ( X - X0 )
        END IF
      ELSE
!write(6, "( ' x ', /, ( 5ES12.4) )" ) X
        IF ( PRESENT( H_lm ) ) THEN
          CALL LMS_apply_lbfgs( X, H_lm, i, RESULT = GRAD_L )
        ELSE
          IF ( PRESENT( H_col ) .AND. PRESENT( H_ptr ) ) THEN
            GRAD_L = zero
            CALL CCQP_HX( dims, n, GRAD_L, h_ne, H_val, H_col, H_ptr, X, '+' )
          ELSE
            GRAD_L = H_val * X
          END IF
        END IF
!write(6, "( ' grad_l ', /, ( 5ES12.4) )" ) GRAD_l
      END IF
      IF ( perturb_h /= zero ) GRAD_L = GRAD_L + perturb_h * X

      IF ( gradient_kind == 1 ) THEN
        GRAD_L = GRAD_L + one
      ELSE IF ( gradient_kind /= 0 ) THEN
        GRAD_L = GRAD_L + G
      END IF

      CALL CCQP_AX( n, GRAD_L, m, a_ne, A_val, A_col, A_ptr, m, Y, '-T' )

!  If required, obtain suitable "good" starting values for the dual
!  variables ( see paper )

      IF ( getdua ) THEN

!  Problem variables:

!  The variable is a non-negativity

        DO i = dims%x_free + 1, dims%x_l_start - 1
          Z_l( i ) = MAX( dufeas, GRAD_L( i ) / ( one + X( i ) ** 2 ) )
        END DO

!  The variable has just a lower bound

        DO i = dims%x_l_start, dims%x_u_start - 1
          Z_l( i ) = MAX( dufeas, GRAD_L( i ) / ( one + DIST_X_l( i ) ** 2 ) )
        END DO

!  The variable has both lower and upper bounds

        DO i = dims%x_u_start, dims%x_l_end
          gi = GRAD_L( i )
          IF ( ABS( gi ) <= dufeas ) THEN
            Z_l( i ) = dufeas ; Z_u( i ) = - dufeas
          ELSE IF ( gi > dufeas ) THEN
            Z_l( i ) = ( gi + dufeas ) / ( one + DIST_X_l( i ) ** 2 )
            Z_u( i ) = - dufeas
          ELSE
            Z_l( i ) = dufeas
            Z_u( i ) = ( gi - dufeas ) / ( one + DIST_X_u( i ) ** 2 )
          END IF
        END DO

!  The variable has just an upper bound

        DO i = dims%x_l_end + 1, dims%x_u_end
          Z_u( i ) = MIN( - dufeas, GRAD_L( i ) / ( one + DIST_X_u( i ) ** 2 ) )
        END DO

!  The variable is a non-positivity

        DO i = dims%x_u_end + 1, n
          Z_u( i ) = MIN( - dufeas, GRAD_L( i ) / ( one + X( i ) ** 2 ) )
        END DO

!  Slack variables:

!  The variable has just a lower bound

        DO i = dims%c_l_start, dims%c_u_start - 1
          Y_l( i ) = MAX( dufeas, - Y( i ) / ( one + DIST_C_l( i ) ** 2 ) )
        END DO

!  The variable has both lower and upper bounds

        DO i = dims%c_u_start, dims%c_l_end
          gi = - Y( i )
          IF ( ABS( gi ) <= dufeas ) THEN
            Y_l( i ) = dufeas ; Y_u( i ) = - dufeas
          ELSE IF ( gi > dufeas ) THEN
            Y_l( i ) = ( gi + dufeas ) / ( one + DIST_C_l( i ) ** 2 )
            Y_u( i ) = - dufeas
          ELSE
            Y_l( i ) = dufeas
            Y_u( i ) = ( gi - dufeas ) / ( one + DIST_C_u( i ) ** 2 )
          END IF
        END DO

!  The variable has just an upper bound

        DO i = dims%c_l_end + 1, dims%c_u_end
          Y_u( i ) = MIN( - dufeas, - Y( i ) / ( one + DIST_C_u( i ) ** 2 ) )
        END DO
      END IF

      RETURN

!  End of CCQP_Lagrangian_gradient

      END SUBROUTINE CCQP_Lagrangian_gradient

!-*-*-*-  C C Q P _ C O M P U T E _ S T E P S I Z E   S U B R O U T I N E  -*-*-*-

      SUBROUTINE CCQP_compute_stepsize( dims, n, m, nbnds, order, puiseux,     &
                                       X_coef, C_coef, Y_coef, Y_l_coef,       &
                                       Y_u_coef, Z_l_coef, Z_u_coef,           &
                                       X, X_l, X_u, Z_l, Z_u,                  &
                                       Y, Y_l, Y_u, C, C_l, C_u,               &
                                       gamma_c, gamma_f, infeas, alpha_max,    &
                                       comp, print_level, control, inform )

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  Find an approximation to the maximum allowable stepsizes alpha_max
!  which balances the complementarity ie, such that
!
!      min (x-l)_i(z_l)_i - (gamma_c / nbds)( <x-l,z_l> + <x-u,z_u> ) >= 0
!       i
!  and
!      min (x-u)_i(z_u)_i - (gamma_c / nbds)( <x-l,z_l> + <x-u,z_u> ) >= 0 ,
!       i
!
!  and which favours feasibility over complementarity, ie, such that
!
!      <x-l,z_l> + <x-u,z_u> >= infeas * gamma_f
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n, m, nbnds, order, print_level
      LOGICAL, INTENT( IN ) :: puiseux
      REAL ( KIND = wp ), INTENT( IN ) :: gamma_c, gamma_f, infeas
      REAL ( KIND = wp ), INTENT( OUT ) :: alpha_max, comp

      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( n, 0 : order ) :: X_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_l_start : dims%c_u_end, 0 : order ) :: C_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( m, 0 : order ) :: Y_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_l_start : dims%c_l_end, 0 : order ) ::  Y_l_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_u_start : dims%c_u_end, 0 : order ) ::  Y_u_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION(   dims%x_free + 1 : dims%x_l_end, 0 : order ) :: Z_l_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%x_u_start : n, 0 : order ) :: Z_u_coef
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( n ) :: X
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( m ) :: Y
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X_l, X_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%x_free + 1 : dims%x_l_end ) :: Z_l
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%x_u_start : n ) :: Z_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%c_l_start : dims%c_l_end ) :: Y_l
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%c_u_start : dims%c_u_end ) :: Y_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
                          DIMENSION( dims%c_l_start : m ) :: C
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( m ) :: C_l, C_u
      TYPE ( CCQP_control_type ), INTENT( IN ) :: control
      TYPE ( CCQP_inform_type ), INTENT( INOUT ) :: inform

!  Local variables

      INTEGER :: i
      REAL ( KIND = wp ) :: x_p, z_l_p, z_u_p, c_p, y_l_p, y_u_p
      REAL ( KIND = wp ) :: alpha_l, alpha_u, scomp, infeas_gamma_f
      CHARACTER ( LEN = 1 ) :: fail
      LOGICAL :: ok, printd

!  prefix for all output

      CHARACTER ( LEN = LEN( TRIM( control%prefix ) ) - 2 ) :: prefix
      IF ( LEN( TRIM( control%prefix ) ) > 2 )                                 &
        prefix = control%prefix( 2 : LEN( TRIM( control%prefix ) ) - 1 )

      alpha_max = one
      inform%status = GALAHAD_ok
      IF ( nbnds == 0 ) GO TO 200
      printd = control%out > 0 .AND. print_level >= 6

      infeas_gamma_f = infeas * gamma_f

!  define an interval [alhpa_l,alpha_u] containing the required stepsize

      alpha_l = zero ; alpha_u = one

!  main loop to determine an approximation to the largest possible stepsize

      IF ( printd ) WRITE(  control%out, "( A, '  step' )" ) prefix
      DO

!  once the interval is small enough, accept the lower bound as the required
!  step so long as this step is not zero

        IF ( alpha_u - alpha_l <= stop_alpha .AND. alpha_l > zero ) THEN
          alpha_max = alpha_l
          EXIT
        END IF
        IF ( alpha_u <= epsmch ) THEN
          inform%status = GALAHAD_error_tiny_step
          RETURN
        END IF

!  Test the current alpha for acceptibility

        ok = .TRUE.

!  Evaluate the point on the path for the current alpha and the complementarity
!    comp = <x-x_l,z_l> + <x-x_u,z_u> +<c-c_l,z_l> + <c-c_u,y_u>

        comp = zero ; fail = ' '

!  primal and dual variables

        DO i = dims%x_free + 1, dims%x_u_start - 1
          x_p = FIT_evaluate_polynomial( order + 1,                            &
                      X_coef( i, 0 : order ), alpha_max )
          z_l_p = FIT_evaluate_polynomial( order + 1,                          &
                      Z_l_coef( i, 0 : order ), alpha_max )
          IF ( x_p > X_l( i ) .AND. z_l_p > zero ) THEN
            X( i ) = x_p
            Z_l( i ) = z_l_p
            comp = comp + ( X( i ) - X_l( i ) ) * Z_l( i )
          ELSE
            ok = .FALSE. ; fail = 'x' ; GO TO 100
          END IF
        END DO
        DO i = dims%x_u_start, dims%x_l_end
          x_p = FIT_evaluate_polynomial( order + 1,                            &
                      X_coef( i, 0 : order ), alpha_max )
          z_l_p = FIT_evaluate_polynomial( order + 1,                          &
                      Z_l_coef( i, 0 : order ), alpha_max )
          z_u_p = FIT_evaluate_polynomial( order + 1,                          &
                      Z_u_coef( i, 0 : order ), alpha_max )
          IF ( x_p > X_l( i ) .AND. z_l_p > zero .AND.                         &
               x_p < X_u( i ) .AND. z_u_p < zero ) THEN
            X( i ) = x_p
            Z_l( i ) = z_l_p
            Z_u( i ) = z_u_p
            comp = comp + ( X( i ) - X_l( i ) ) * Z_l( i )                     &
                        + ( X( i ) - X_u( i ) ) * Z_u( i )
          ELSE
            ok = .FALSE. ; fail = 'x' ; GO TO 100
          END IF
        END DO
        DO i = dims%x_l_end + 1, n
          x_p = FIT_evaluate_polynomial( order + 1,                            &
                      X_coef( i, 0 : order ), alpha_max )
          z_u_p = FIT_evaluate_polynomial( order + 1,                          &
                      Z_u_coef( i, 0 : order ), alpha_max )
          IF ( x_p < X_u( i ) .AND. z_u_p < zero ) THEN
            X( i ) = x_p
            Z_u( i ) = z_u_p
            comp = comp + ( X( i ) - X_u( i ) ) * Z_u( i )
          ELSE
            ok = .FALSE. ; fail = 'x' ; GO TO 100
          END IF
        END DO

!  slack variables and Lagrange multipliers

        DO i = dims%c_l_start, dims%c_u_start - 1
          c_p = FIT_evaluate_polynomial( order + 1,                            &
                      C_coef( i, 0 : order ), alpha_max )
          y_l_p = FIT_evaluate_polynomial( order + 1,                          &
                      Y_l_coef( i, 0 : order ), alpha_max )
          IF ( c_p > C_l( i ) .AND. y_l_p > zero ) THEN
            C( i ) = c_p
            Y_l( i ) = y_l_p
            comp = comp + ( C( i ) - C_l( i ) ) * Y_l( i )
          ELSE
            ok = .FALSE. ; fail = 'c' ; GO TO 100
          END IF
        END DO
        DO i = dims%c_u_start, dims%c_l_end
          c_p = FIT_evaluate_polynomial( order + 1,                            &
                      C_coef( i, 0 : order ), alpha_max )
          y_l_p = FIT_evaluate_polynomial( order + 1,                          &
                      Y_l_coef( i, 0 : order ), alpha_max )
          y_u_p = FIT_evaluate_polynomial( order + 1,                          &
                      Y_u_coef( i, 0 : order ), alpha_max )
          IF ( c_p > C_l( i ) .AND. y_l_p > zero .AND.                         &
               c_p < C_u( i ) .AND. y_u_p < zero ) THEN
            C( i ) = c_p
            Y_l( i ) = y_l_p
            Y_u( i ) = y_u_p
            comp = comp + ( C( i ) - C_l( i ) ) * Y_l( i )                     &
                        + ( C( i ) - C_u( i ) ) * Y_u( i )
          ELSE
            ok = .FALSE. ; fail = 'c' ; GO TO 100
          END IF
        END DO
        DO i = dims%c_l_end + 1, dims%c_u_end
          c_p = FIT_evaluate_polynomial( order + 1,                            &
                      C_coef( i, 0 : order ), alpha_max )
          y_u_p = FIT_evaluate_polynomial( order + 1,                          &
                      Y_u_coef( i, 0 : order ), alpha_max )
          IF ( c_p < C_u( i ) .AND. y_u_p < zero ) THEN
            C( i ) = c_p
            Y_u( i ) = y_u_p
            comp = comp + ( C( i ) - C_u( i ) ) * Y_u( i )
          ELSE
            ok = .FALSE. ; fail = 'c' ; GO TO 100
          END IF
        END DO

!  Now test that comp >= infeas * gamma_f ...

        IF ( puiseux ) THEN
          IF ( comp < infeas_gamma_f * ( one - alpha_max ) ** 2 ) THEN
            ok = .FALSE. ; fail = 'f' ; GO TO 100
          END IF
        ELSE
          IF ( comp < infeas_gamma_f * ( one - alpha_max ) ) THEN
            ok = .FALSE. ; fail = 'f' ; GO TO 100
          END IF
        END IF

!  ... and both (x-x_l)_i(z_l)_i - (gamma_c / nbds) * comp >= 0 and
!               (x-x_u)_i(z_u)_i - (gamma_c / nbds) * comp >= 0

        scomp = comp * gamma_c / nbnds

        DO i = dims%x_free + 1, dims%x_u_start - 1
          IF ( ( X( i ) - X_l( i ) ) * Z_l( i ) < scomp ) THEN
            ok = .FALSE. ; fail = 'b' ; GO TO 100
          END IF
        END DO
        DO i = dims%x_u_start, dims%x_l_end
          IF( ( X( i ) - X_l( i ) ) * Z_l( i ) < scomp .OR.                    &
              ( X( i ) - X_u( i ) ) * Z_u( i ) < scomp ) THEN
            ok = .FALSE. ; fail = 'b' ; GO TO 100
          END IF
        END DO
        DO i = dims%x_l_end + 1, n
          IF ( ( X( i ) - X_u( i ) ) * Z_u( i ) < scomp ) THEN
            ok = .FALSE. ; fail = 'b' ; GO TO 100
          END IF
        END DO

!  ... and both (c-c_l)_i(y_l)_i - (gamma_c / nbds) * comp >= 0 and
!               (c-c_u)_i(y_u)_i - (gamma_c / nbds) * comp >= 0

        DO i = dims%c_l_start, dims%c_u_start - 1
          IF ( ( C( i ) - C_l( i ) ) * Y_l( i ) < scomp ) THEN
            ok = .FALSE. ; fail = 'b' ; GO TO 100
          END IF
        END DO
        DO i = dims%c_u_start, dims%c_l_end
          IF ( ( C( i ) - C_l( i ) ) * Y_l( i ) < scomp .OR.                   &
               ( C( i ) - C_u( i ) ) * Y_u( i ) < scomp ) THEN
            ok = .FALSE. ; fail = 'b' ; GO TO 100
          END IF
        END DO
        DO i = dims%c_l_end + 1, dims%c_u_end
          IF (( C( i ) - C_u( i ) ) * Y_u( i ) < scomp ) THEN
            ok = .FALSE. ; fail = 'b' ; GO TO 100
          END IF
        END DO

!  the current alpha is acceptable

 100    CONTINUE
        IF ( ok ) THEN
          IF ( printd ) WRITE(  control%out, "( A, 1X, A1, ES12.4 )" ) prefix, &
            fail, alpha_max

!  if the current step is one, accept this as the required step

          IF ( alpha_max == one ) EXIT

!  increase the lower bound

          alpha_l = alpha_max
          alpha_max = half * ( alpha_max + alpha_u )

!  the current alpha is unacceptable ; reduce the upper bound

        ELSE
          IF ( printd ) WRITE(  control%out, "( A, 2X, ES12.4 )" ) prefix,     &
            alpha_max
          alpha_u = alpha_max
          alpha_max = half * ( alpha_max + alpha_l )
        END IF
      END DO

 200  CONTINUE
      inform%status = GALAHAD_ok

!  finally, compute the best point on the arc and its complementarity

      CALL CCQP_compute_v_alpha( dims, n, m, order, X_coef, C_coef, Y_coef,    &
                                 Y_l_coef, Y_u_coef, Z_l_coef, Z_u_coef,       &
                                 X, X_l, X_u, Z_l, Z_u, Y, Y_l, Y_u, C,        &
                                 C_l, C_u, alpha_max, comp )
      RETURN

!  End of subroutine CCQP_compute_stepsize

      END SUBROUTINE CCQP_compute_stepsize

!-*-*-*-  C C Q P _ C O M P U T E _ V _ A L P H A   S U B R O U T I N E  -*-*-*-

      SUBROUTINE CCQP_compute_v_alpha( dims, n, m, order, X_coef, C_coef,      &
                                       Y_coef, Y_l_coef, Y_u_coef,             &
                                       Z_l_coef, Z_u_coef,                     &
                                       X, X_l, X_u, Z_l, Z_u,                  &
                                       Y, Y_l, Y_u, C, C_l, C_u,               &
                                       alpha, comp )

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  compute the point v(alpha) on the arc and its complementarity

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n, m, order
      REAL ( KIND = wp ), INTENT( IN ) :: alpha
      REAL ( KIND = wp ), INTENT( OUT ) :: comp
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( n, 0 : order ) :: X_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_l_start : dims%c_u_end, 0 : order ) :: C_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( m, 0 : order ) :: Y_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_l_start : dims%c_l_end, 0 : order ) ::  Y_l_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_u_start : dims%c_u_end, 0 : order ) ::  Y_u_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION(   dims%x_free + 1 : dims%x_l_end, 0 : order ) :: Z_l_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%x_u_start : n, 0 : order ) :: Z_u_coef
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( n ) :: X
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( m ) :: Y
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X_l, X_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%x_free + 1 : dims%x_l_end ) :: Z_l
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%x_u_start : n ) :: Z_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%c_l_start : dims%c_l_end ) :: Y_l
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
             DIMENSION( dims%c_u_start : dims%c_u_end ) :: Y_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
                          DIMENSION( dims%c_l_start : m ) :: C
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( m ) :: C_l, C_u

!  Local variables

      INTEGER :: i

!  initialize the complemntarity

      comp = zero

!  primal and dual variables

      DO i = 1, n
        X( i ) = FIT_evaluate_polynomial( order + 1,                           &
                       X_coef( i, 0 : order ), alpha )
      END DO
      DO i = dims%x_free + 1, dims%x_l_end
        Z_l( i ) = FIT_evaluate_polynomial( order + 1,                         &
                    Z_l_coef( i, 0 : order ), alpha )
        comp = comp + ( X( i ) - X_l( i ) ) * Z_l( i )
      END DO
      DO i = dims%x_u_start, n
        Z_u( i ) = FIT_evaluate_polynomial( order + 1,                         &
                    Z_u_coef( i, 0 : order ), alpha )
        comp = comp + ( X( i ) - X_u( i ) ) * Z_u( i )
      END DO

!  slack variables and Lagrange multipliers

      DO i = 1, m
        Y( i ) = FIT_evaluate_polynomial( order + 1,                           &
                       Y_coef( i, 0 : order ), alpha )
      END DO
      DO i = dims%c_l_start, m
        C( i ) = FIT_evaluate_polynomial( order + 1,                           &
                    C_coef( i, 0 : order ), alpha )
      END DO
      DO i = dims%c_l_start, dims%c_l_end
        Y_l( i ) = FIT_evaluate_polynomial( order + 1,                         &
                    Y_l_coef( i, 0 : order ), alpha )
        comp = comp + ( C( i ) - C_l( i ) ) * Y_l( i )
      END DO
      DO i = dims%c_u_start, dims%c_u_end
        Y_u( i ) = FIT_evaluate_polynomial( order + 1,                         &
                    Y_u_coef( i, 0 : order ), alpha )
        comp = comp + ( C( i ) - C_u( i ) ) * Y_u( i )
      END DO

      RETURN

!  End of subroutine CCQP_compute_v_alpha

      END SUBROUTINE CCQP_compute_v_alpha

!-*-*-*-  C C Q P _ C O M P U T E _ L M A X S T E P   S U B R O U T I N E  -*-*-*-

      SUBROUTINE CCQP_compute_lmaxstep( dims, n, m, nbnds, X, X_l, X_u, DX,    &
                                        C, C_l, C_u, DC, Y_l, Y_u, DY_l, DY_u, &
                                        Z_l, Z_u, DZ_l, DZ_u,                  &
                                        gamma_c, gamma_f, infeas, alpha_max,   &
                                        inform )

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  For a linear arc (x,z), find the maximum allowable stepsizes alpha_max_b,
!  which balances the complementarity ie, such that
!
!      min (x-l)_i(z_l)_i - (gamma_c / nbds)( <x-l,z_l> + <x-u,z_u> ) >= 0
!       i
!  and
!      min (x-u)_i(z_u)_i - (gamma_c / nbds)( <x-l,z_l> + <x-u,z_u> ) >= 0 ,
!       i
!
!  and alpha_max_f, which favours feasibility over complementarity,
!  ie, such that
!
!      <x-l,z_l> + <x-u,z_u> >= infeas * gamma_f
!
!  and the smaller of the two, alpha_max = min( alpha_max_f, alpha_max_b )
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n, m, nbnds
      REAL ( KIND = wp ), INTENT( IN ) :: gamma_c, gamma_f, infeas
      REAL ( KIND = wp ), INTENT( OUT ) :: alpha_max
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( n ) :: X
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X_l, X_u, DX
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_free + 1 : dims%x_l_end ) :: Z_l, DZ_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_u_start : n ) :: Z_u, DZ_u
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%c_l_start : dims%c_l_end ) :: Y_l, DY_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%c_u_start : dims%c_u_end ) :: Y_u, DY_u
      REAL ( KIND = wp ), INTENT( INOUT ),                                     &
                          DIMENSION( dims%c_l_start : m ) :: C
      REAL ( KIND = wp ), INTENT( IN ),                                        &
                          DIMENSION( dims%c_l_start : m ) :: DC
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( m ) :: C_l, C_u
      TYPE ( CCQP_inform_type ), INTENT( INOUT ) :: inform

!  Local variables

      INTEGER :: i, nroots

!  Local variables

      REAL ( KIND = wp ) :: compc, compl, compq, coef0, coef1, coef2
      REAL ( KIND = wp ) :: coef0_f, coef1_f, coef2_f, root1, root2, tol
      REAL ( KIND = wp ) :: alpha_max_b, alpha_max_f, alpha, infeas_gamma_f

      alpha_max_b = infinity ; alpha_max_f = infinity
      inform%status = GALAHAD_ok
      IF ( nbnds == 0 ) THEN
        alpha_max = one
        RETURN
      END IF
      tol = epsmch ** 0.75

!  ================================================
!             part to compute alpha_max_b
!  ================================================

!  Compute the coefficients for the quadratic expression
!  for the overall complementarity

      coef0_f = zero ; coef1_f = zero ; coef2_f = zero
      DO i = dims%x_free + 1, dims%x_l_end
        coef0_f = coef0_f + ( X( i ) - X_l( i ) ) * Z_l( i )
        coef1_f = coef1_f + ( X( i ) - X_l( i ) ) * DZ_l( i )                  &
                          + DX( i ) * Z_l( i )
        coef2_f = coef2_f + DX( i ) * DZ_l( i )
      END DO
      DO i = dims%x_u_start, n
        coef0_f = coef0_f - ( X_u( i ) - X( i ) ) * Z_u( i )
        coef1_f = coef1_f - ( X_u( i ) - X( i ) ) * DZ_u( i )                  &
                          + DX( i ) * Z_u( i )
        coef2_f = coef2_f + DX( i ) * DZ_u( i )
      END DO
      DO i = dims%c_l_start, dims%c_l_end
        coef0_f = coef0_f + ( C( i ) - C_l( i ) ) * Y_l( i )
        coef1_f = coef1_f + ( C( i ) - C_l( i ) ) * DY_l( i )                  &
                            + DC( i ) * Y_l( i )
        coef2_f = coef2_f + DC( i ) * DY_l( i )
      END DO
      DO i = dims%c_u_start, dims%c_u_end
        coef0_f = coef0_f - ( C_u( i ) - C( i ) ) * Y_u( i )
        coef1_f = coef1_f - ( C_u( i ) - C( i ) ) * DY_u( i )                  &
                          + DC( i ) * Y_u( i )
        coef2_f = coef2_f + DC( i ) * DY_u( i )
      END DO

!  Scale these coefficients

      compc = - gamma_c * coef0_f / nbnds ; compl = - gamma_c * coef1_f / nbnds
      compq = - gamma_c * coef2_f / nbnds

!  Compute the coefficients for the quadratic expression
!  for the individual complementarity

      DO i = dims%x_free + 1, dims%x_l_end
        coef0 = compc + ( X( i ) - X_l( i ) ) * Z_l( i )
        coef1 = compl + ( X( i ) - X_l( i ) ) * DZ_l( i ) + DX( i ) * Z_l( i )
        coef2 = compq + DX( i ) * DZ_l( i )
        coef0 = MAX( coef0, zero )
        CALL ROOTS_quadratic( coef0, coef1, coef2, tol, nroots, root1, root2, &
                              .FALSE. )
        IF ( nroots == 2 ) THEN
          IF ( coef2 > zero ) THEN
            IF ( root2 > zero ) THEN
               alpha = root1
            ELSE
               alpha = infinity
            END IF
          ELSE
            alpha = root2
          END IF
        ELSE IF ( nroots == 1 ) THEN
          IF ( root1 > zero ) THEN
            alpha = root1
          ELSE
            alpha = infinity
          END IF
        ELSE
          alpha = infinity
        END IF
        IF ( alpha < alpha_max_b ) alpha_max_b = alpha
      END DO

      DO i = dims%x_u_start, n
        coef0 = compc - ( X_u( i ) - X( i ) ) * Z_u( i )
        coef1 = compl - ( X_u( i ) - X( i ) ) * DZ_u( i ) + DX( i ) * Z_u( i )
        coef2 = compq + DX( i ) * DZ_u( i )
        coef0 = MAX( coef0, zero )
        CALL ROOTS_quadratic( coef0, coef1, coef2, tol, nroots, root1, root2,  &
                              .FALSE. )
        IF ( nroots == 2 ) THEN
          IF ( coef2 > zero ) THEN
            IF ( root2 > zero ) THEN
               alpha = root1
            ELSE
               alpha = infinity
            END IF
          ELSE
            alpha = root2
          END IF
        ELSE IF ( nroots == 1 ) THEN
          IF ( root1 > zero ) THEN
            alpha = root1
          ELSE
            alpha = infinity
          END IF
        ELSE
          alpha = infinity
        END IF
        IF ( alpha < alpha_max_b ) alpha_max_b = alpha
      END DO

      DO i = dims%c_l_start, dims%c_l_end
        coef0 = compc + ( C( i ) - C_l( i ) ) * Y_l( i )
        coef1 = compl + ( C( i ) - C_l( i ) ) * DY_l( i ) + DC( i ) * Y_l( i )
        coef2 = compq + DC( i ) * DY_l( i )
        coef0 = MAX( coef0, zero )
        CALL ROOTS_quadratic( coef0, coef1, coef2, tol, nroots, root1, root2,  &
                              .FALSE. )
        IF ( nroots == 2 ) THEN
          IF ( coef2 > zero ) THEN
            IF ( root2 > zero ) THEN
               alpha = root1
            ELSE
               alpha = infinity
            END IF
          ELSE
            alpha = root2
          END IF
        ELSE IF ( nroots == 1 ) THEN
          IF ( root1 > zero ) THEN
            alpha = root1
          ELSE
            alpha = infinity
          END IF
        ELSE
          alpha = infinity
        END IF
        IF ( alpha < alpha_max_b ) alpha_max_b = alpha
      END DO

      DO i = dims%c_u_start, dims%c_u_end
        coef0 = compc - ( C_u( i ) - C( i ) ) * Y_u( i )
        coef1 = compl - ( C_u( i ) - C( i ) ) * DY_u( i ) + DC( i ) * Y_u( i )
        coef2 = compq + DC( i ) * DY_u( i )
        coef0 = MAX( coef0, zero )
        CALL ROOTS_quadratic( coef0, coef1, coef2, tol, nroots, root1, root2,  &
                              .FALSE. )
!       write( 6, "( 3ES10.2, 2ES22.14 )" )  coef2, coef1, coef0, root1, root2
        IF ( nroots == 2 ) THEN
          IF ( coef2 > zero ) THEN
            IF ( root2 > zero ) THEN
               alpha = root1
            ELSE
               alpha = infinity
            END IF
          ELSE
            alpha = root2
          END IF
        ELSE IF ( nroots == 1 ) THEN
          IF ( root1 > zero ) THEN
            alpha = root1
          ELSE
            alpha = infinity
          END IF
        ELSE
          alpha = infinity
        END IF
        IF ( alpha < alpha_max_b ) alpha_max_b = alpha
      END DO

      IF ( - compc <= epsmch ** 0.75 ) alpha_max_b = 0.99_wp * alpha_max_b

!  ================================================
!             part to compute alpha_max_f
!  ================================================

      infeas_gamma_f = infeas * gamma_f

!  Compute the coefficients for the quadratic expression
!  for the overall complementarity, remembering to first
!  subtract the term for the feasibility

      coef0_f = MAX( coef0_f - infeas_gamma_f, zero )
      coef1_f = coef1_f + infeas_gamma_f

!  Compute the coefficients for the quadratic expression
!  for the individual complementarity
!
      CALL ROOTS_quadratic( coef0_f, coef1_f, coef2_f, tol,                    &
                            nroots, root1, root2, .FALSE. )
      IF ( nroots == 2 ) THEN
        IF ( coef2_f > zero ) THEN
          IF ( root2 > zero ) THEN
            alpha = root1
          ELSE
            alpha = infinity
          END IF
        ELSE
          alpha = root2
        END IF
      ELSE IF ( nroots == 1 ) THEN
        IF ( root1 > zero ) THEN
          alpha = root1
        ELSE
          alpha = infinity
        END IF
      ELSE
        alpha = infinity
      END IF
      IF ( alpha < alpha_max_f ) alpha_max_f = alpha
      IF ( - compc <= epsmch ** 0.75 ) alpha_max_f = 0.99_wp * alpha_max_f

!  compute the smaller of alpha_max_b and alpha_max_f

      alpha_max = ( one - two * epsmch ) * MIN( alpha_max_b, alpha_max_f )

      RETURN

!  End of subroutine CCQP_compute_lmaxstep

      END SUBROUTINE CCQP_compute_lmaxstep

!-*-*-*-  C C Q P _ C O M P U T E _ P M A X S T E P   S U B R O U T I N E  -*-*-*-

      SUBROUTINE CCQP_compute_pmaxstep( dims, n, m, nbnds, order, puiseux,     &
                                       X_coef, C_coef, Y_l_coef,               &
                                       Y_u_coef, Z_l_coef, Z_u_coef,           &
                                       X_l, X_u, C_l, C_u,                     &
                                       CS_coef, COEF, ROOTS,                   &
                                       gamma_c, gamma_f, infeas, alpha_max,    &
                                       control, inform, ROOTS_data )

! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
!
!  For a polynomial arc (x,z), find the maximum allowable stepsizes
!  alpha_max_b, which balances the complementarity ie, such that
!
!      min (x-l)_i(z_l)_i - (gamma_c / nbds)( <x-l,z_l> + <x-u,z_u> ) >= 0
!       i
!  and
!      min (x-u)_i(z_u)_i - (gamma_c / nbds)( <x-l,z_l> + <x-u,z_u> ) >= 0 ,
!       i
!
!  and alpha_max_f, which favours feasibility over complementarity,
!  ie, such that
!
!      <x-l,z_l> + <x-u,z_u> >= infeas * gamma_f
!
!  and the smaller of the two, alpha_max = min( alpha_max_f, alpha_max_b )
!
! =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n, m, nbnds, order
      LOGICAL, INTENT( IN ) :: puiseux
      REAL ( KIND = wp ), INTENT( IN ) :: gamma_c, gamma_f, infeas
      REAL ( KIND = wp ), INTENT( OUT ) :: alpha_max
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( n, 0 : order ) :: X_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_l_start : dims%c_u_end, 0 : order ) :: C_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_l_start : dims%c_l_end, 0 : order ) ::  Y_l_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_u_start : dims%c_u_end, 0 : order ) ::  Y_u_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION(   dims%x_free + 1 : dims%x_l_end, 0 : order ) :: Z_l_coef
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%x_u_start : n, 0 : order ) :: Z_u_coef
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( 0 : 2 * order ) :: CS_coef
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( 0 : 2 * order ) :: COEF
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( 2 * order ) :: ROOTS
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X_l, X_u
      REAL ( KIND = wp ), INTENT( INOUT ), DIMENSION( m ) :: C_l, C_u
      TYPE ( CCQP_control_type ), INTENT( IN ) :: control
      TYPE ( CCQP_inform_type ), INTENT( INOUT ) :: inform
      TYPE ( ROOTS_data_type ), INTENT( INOUT ) :: ROOTS_data

!  Local variables

      INTEGER :: i, j, k, nroots, opj
      INTEGER :: thread
      REAL ( KIND = wp ) :: c, s, x0, c0, scale, lower, upper
      REAL ( KIND = wp ) :: alpha_max_b, alpha_max_f, alpha, infeas_gamma_f
!     LOGICAL :: old = .TRUE.
      LOGICAL :: old = .FALSE.
!     LOGICAL :: parallel = .FALSE.
      LOGICAL :: parallel = .TRUE.
      REAL ( KIND = wp ), DIMENSION( MAX( m, n ) ) :: ALPHA_m

      TYPE ( ROOTS_control_type ) :: local_ROOTS_control
      TYPE ( ROOTS_data_type ),                                                &
        DIMENSION( 0 : inform%threads - 1 ) :: local_ROOTS_data
      TYPE ( ROOTS_inform_type ),                                              &
        DIMENSION( 0 : inform%threads - 1 ) :: local_ROOTS_inform

!  Functions

!$    INTEGER :: OMP_GET_THREAD_NUM

      IF ( inform%threads == 1 ) parallel = .FALSE.
      inform%status = GALAHAD_ok

      thread = 1
      IF ( puiseux .AND. order == 1 ) THEN
        alpha_max = half
      ELSE
        alpha_max = one
      END IF
      IF ( nbnds == 0 ) RETURN
      alpha_max_b = infinity ; alpha_max_f = infinity
      scale = gamma_c / REAL( nbnds )
      infeas_gamma_f = infeas * gamma_f

!  ================================================
!             part to compute alpha_max_b
!  ================================================

!  Compute the coefficients for the polynomial expression
!  for the overall complementarity

!  parallel case ... skip as this does not seem to be efficient!

      IF ( .FALSE. ) THEN
!     IF ( parallel ) THEN
        c = zero
        DO i = dims%x_free + 1, dims%x_l_end
          c = c + ( X_coef( i, 0 ) - X_l( i ) ) * Z_l_coef( i, 0 )
        END DO
        DO i = dims%x_u_start, n
          c = c + ( X_coef( i, 0 ) - X_u( i ) ) * Z_u_coef( i, 0 )
        END DO
        DO i = dims%c_l_start, dims%c_l_end
          c = c + ( C_coef( i, 0 ) - C_l( i ) ) * Y_l_coef( i, 0 )
        END DO
        DO i = dims%c_u_start, dims%c_u_end
          c = c + ( C_coef( i, 0 ) - C_u( i ) ) * Y_u_coef( i, 0 )
        END DO
        CS_coef( 0 ) = c

!$OMP   PARALLEL                                                               &
!$OMP     DEFAULT( NONE )                                                      &
!$OMP     PRIVATE( i, x0, c0, j, c, s, k, opj )                                &
!$OMP     SHARED( order, dims, n, X_coef, X_l, X_u, Z_l_coef, Z_u_coef,        &
!$OMP             C_coef, C_l, C_u, Y_l_coef, Y_u_coef, CS_coef )
!$OMP   DO
        DO j = 1, order
          opj = order + j
          c = zero ; s = zero
          DO i = dims%x_free + 1, dims%x_l_end
            c = ( X_coef( i, 0 ) - X_l( i ) ) * Z_l_coef( i, j )
            DO k = 1, j
              c = c + X_coef( i, k ) * Z_l_coef( i, j - k )
            END DO
            s = X_coef( i, j ) * Z_l_coef( i, order )
            DO k = j + 1, order
              s = s + X_coef( i, k ) * Z_l_coef( i, opj - k )
            END DO
          END DO

          DO i = dims%x_u_start, n
            c = ( X_coef( i, 0 ) - X_u( i ) ) * Z_u_coef( i, j )
            DO k = 1, j
              c = c + X_coef( i, k ) * Z_u_coef( i, j - k )
            END DO
            s = X_coef( i, j ) * Z_u_coef( i, order )
            DO k = j + 1, order
              s = s + X_coef( i, k ) * Z_u_coef( i, opj - k )
            END DO
          END DO

          DO i = dims%c_l_start, dims%c_l_end
            c = ( C_coef( i, 0 ) - C_l( i ) ) * Y_l_coef( i, j )
            DO k = 1, j
              c = c + C_coef( i, k ) * Y_l_coef( i, j - k )
            END DO
            c = C_coef( i, j ) * Y_l_coef( i, order )
            DO k = j + 1, order
              c = c + C_coef( i, k ) * Y_l_coef( i, opj - k )
            END DO
          END DO

          DO i = dims%c_u_start, dims%c_u_end
            c = ( C_coef( i, 0 ) - C_u( i ) ) * Y_u_coef( i, j )
            DO k = 1, j
              c = c + C_coef( i, k ) * Y_u_coef( i, j - k )
            END DO
            s = C_coef( i, j ) * Y_u_coef( i, order )
            DO k = j + 1, order
              s = s + C_coef( i, k ) * Y_u_coef( i, opj - k )
            END DO
          END DO
          CS_coef( j ) = c
          CS_coef( opj ) = s
        END DO
!$OMP   END DO
!$OMP   END PARALLEL

!  sequential case

      ELSE
        CS_coef( 0 : 2 * order ) = zero
        DO i = dims%x_free + 1, dims%x_l_end
          x0 = X_coef( i, 0 ) - X_l( i )
          CS_coef( 0 ) = CS_coef( 0 ) + x0 * Z_l_coef( i, 0 )
          DO j = 1, order
            c = x0 * Z_l_coef( i, j )
            DO k = 1, j
              c = c + X_coef( i, k ) * Z_l_coef( i, j - k )
            END DO
            CS_coef( j ) = CS_coef( j ) + c
            opj = order + j
            c = X_coef( i, j ) * Z_l_coef( i, order )
            DO k = j + 1, order
              c = c + X_coef( i, k ) * Z_l_coef( i, opj - k )
            END DO
            CS_coef( opj ) = CS_coef( opj ) + c
          END DO
        END DO

        DO i = dims%x_u_start, n
          x0 = X_coef( i, 0 ) - X_u( i )
          CS_coef( 0 ) = CS_coef( 0 ) + x0 * Z_u_coef( i, 0 )
          DO j = 1, order
            c = x0 * Z_u_coef( i, j )
            DO k = 1, j
              c = c + X_coef( i, k ) * Z_u_coef( i, j - k )
            END DO
            CS_coef( j ) =  CS_coef( j ) + c
            opj = order + j
            c = X_coef( i, j ) * Z_u_coef( i, order )
            DO k = j + 1, order
              c = c + X_coef( i, k ) * Z_u_coef( i, opj - k )
            END DO
            CS_coef( opj ) = CS_coef( opj ) + c
          END DO
        END DO

        DO i = dims%c_l_start, dims%c_l_end
          c0 = C_coef( i, 0 ) - C_l( i )
          CS_coef( 0 ) = CS_coef( 0 ) + c0 * Y_l_coef( i, 0 )
          DO j = 1, order
            c = c0 * Y_l_coef( i, j )
            DO k = 1, j
              c = c + C_coef( i, k ) * Y_l_coef( i, j - k )
            END DO
            CS_coef( j ) = CS_coef( j ) + c
            opj = order + j
            c = C_coef( i, j ) * Y_l_coef( i, order )
            DO k = j + 1, order
              c = c + C_coef( i, k ) * Y_l_coef( i, opj - k )
            END DO
            CS_coef( opj ) = CS_coef( opj ) + c
          END DO
        END DO

        DO i = dims%c_u_start, dims%c_u_end
          c0 = C_coef( i, 0 ) - C_u( i )
          CS_coef( 0 ) = CS_coef( 0 ) + c0 * Y_u_coef( i, 0 )
          DO j = 1, order
            c = c0 * Y_u_coef( i, j )
            DO k = 1, j
              c = c + C_coef( i, k ) * Y_u_coef( i, j - k )
            END DO
            CS_coef( j ) = CS_coef( j ) + c
            opj = order + j
            c = C_coef( i, j ) * Y_u_coef( i, order )
            DO k = j + 1, order
              c = c + C_coef( i, k ) * Y_u_coef( i, opj - k )
            END DO
            CS_coef( opj ) =  CS_coef( opj ) + c
          END DO
        END DO
      END IF

!  Compute the coefficients for the polynomial expression
!  for the individual complementarity

!  parallel case

      IF ( parallel ) THEN
        lower = zero
        upper = alpha_max
        local_ROOTS_control = control%ROOTS_control

!$OMP   PARALLEL                                                               &
!$OMP     DEFAULT( NONE )                                                      &
!$OMP     PRIVATE( i, x0, c0, j, c, k, opj, thread, COEF )                     &
!$OMP     SHARED( X_coef, X_l, X_u, Z_l_coef, Z_u_coef,                        &
!$OMP             C_coef, C_l, C_u, Y_l_coef, Y_u_coef,                        &
!$OMP             CS_coef, ALPHA_m,                                            &
!$OMP             dims, n, lower, upper, alpha_max,                            &
!$OMP             order, scale, local_ROOTS_data,                              &
!$OMP             local_ROOTS_control, local_ROOTS_inform )
        IF ( dims%x_free + 1 <= dims%x_l_end ) THEN
!$OMP     DO
            DO i = dims%x_free + 1, dims%x_l_end
              x0 = X_coef( i, 0 ) - X_l( i )
              DO j = 0, order
                c = x0 * Z_l_coef( i, j )
                DO k = 1, j
                  c = c + X_coef( i, k ) * Z_l_coef( i, j - k )
                END DO
                COEF( j ) = c - scale * CS_coef( j )
              END DO
              DO j = 1, order
                opj = order + j
                c = X_coef( i, j ) * Z_l_coef( i, order )
                DO k = j + 1, order
                  c = c + X_coef( i, k ) * Z_l_coef( i, opj - k )
                END DO
                COEF( opj ) = c - scale * CS_coef( opj )
              END DO
              COEF( 0 ) = MAX( COEF( 0 ), zero )
!$            thread = OMP_get_thread_num( )
              ALPHA_m( i ) = ROOTS_smallest_root_in_interval(                  &
                          COEF( 0 : 2 * order ), lower, upper,                 &
                          local_ROOTS_data( thread ), local_ROOTS_control,     &
                          local_ROOTS_inform( thread ) )
            END DO
!$OMP     END DO
          alpha_max = MIN( alpha_max,                                          &
                           MINVAL( ALPHA_m( dims%x_free + 1 : dims%x_l_end ) ) )
          upper = alpha_max
        END IF

        IF ( dims%x_u_start <= n ) THEN
!$OMP     DO
            DO i = dims%x_u_start, n
              x0 = X_coef( i, 0 ) - X_u( i )
              DO j = 0, order
                c = x0 * Z_u_coef( i, j )
                DO k = 1, j
                  c = c + X_coef( i, k ) * Z_u_coef( i, j - k )
                END DO
                COEF( j ) = c - scale * CS_coef( j )
              END DO
              DO j = 1, order
                opj = order + j
                c = X_coef( i, j ) * Z_u_coef( i, order )
                DO k = j + 1, order
                  c = c + X_coef( i, k ) * Z_u_coef( i, opj - k )
                END DO
                COEF( opj ) = c - scale * CS_coef( opj )
              END DO
              COEF( 0 ) = MAX( COEF( 0 ), zero )
!$            thread = OMP_get_thread_num( )
              ALPHA_m( i ) = ROOTS_smallest_root_in_interval(                  &
                          COEF( 0 : 2 * order ), lower, upper,                 &
                          local_ROOTS_data( thread ), local_ROOTS_control,     &
                          local_ROOTS_inform( thread ) )
            END DO
!$OMP     END DO
          alpha_max = MIN( alpha_max,                                          &
                           MINVAL( ALPHA_m( dims%x_u_start : n ) ) )
          upper = alpha_max
        END IF

        IF ( dims%c_l_start <= dims%c_l_end ) THEN
!$OMP     DO
            DO i = dims%c_l_start, dims%c_l_end
              c0 = C_coef( i, 0 ) - C_l( i )
              DO j = 0, order
                c = c0 * Y_l_coef( i, j )
                DO k = 1, j
                  c = c + C_coef( i, k ) * Y_l_coef( i, j - k )
                END DO
                COEF( j ) = c - scale * CS_coef( j )
              END DO
              DO j = 1, order
                opj = order + j
                c = C_coef( i, j ) * Y_l_coef( i, order )
                DO k = j + 1, order
                  c = c + C_coef( i, k ) * Y_l_coef( i, opj - k )
                END DO
                COEF( opj ) = c - scale * CS_coef( opj )
              END DO
              COEF( 0 ) = MAX( COEF( 0 ), zero )
!$            thread = OMP_get_thread_num( )
              ALPHA_m( i ) = ROOTS_smallest_root_in_interval(                  &
                          COEF( 0 : 2 * order ), lower, upper,                 &
                          local_ROOTS_data( thread ), local_ROOTS_control,     &
                          local_ROOTS_inform( thread ) )
            END DO
!$OMP     END DO
          alpha_max = MIN( alpha_max,                                          &
                           MINVAL( ALPHA_m( dims%c_l_start : dims%c_l_end ) ) )
          upper = alpha_max
        END IF

        IF ( dims%c_u_start <= dims%c_u_end ) THEN
!$OMP     DO
            DO i = dims%c_u_start, dims%c_u_end
              c0 = C_coef( i, 0 ) - C_u( i )
              DO j = 0, order
                c = c0 * Y_u_coef( i, j )
                DO k = 1, j
                  c = c + C_coef( i, k ) * Y_u_coef( i, j - k )
                END DO
                COEF( j ) = c - scale * CS_coef( j )
              END DO
              DO j = 1, order
                opj = order + j
                c = C_coef( i, j ) * Y_u_coef( i, order )
                DO k = j + 1, order
                  c = c + C_coef( i, k ) * Y_u_coef( i, opj - k )
                END DO
                COEF( opj ) = c - scale * CS_coef( opj )
              END DO
              COEF( 0 ) = MAX( COEF( 0 ), zero )
!$            thread = OMP_get_thread_num( )
              ALPHA_m( i ) = ROOTS_smallest_root_in_interval(                  &
                          COEF( 0 : 2 * order ), lower, upper,                 &
                          local_ROOTS_data( thread ), local_ROOTS_control,     &
                          local_ROOTS_inform( thread ) )
            END DO
!$OMP     END DO
          alpha_max = MIN( alpha_max,                                          &
                            MINVAL( ALPHA_m( dims%c_u_start : dims%c_u_end ) ) )
        END IF
!$OMP   END PARALLEL

!  sequential case

      ELSE
        DO i = dims%x_free + 1, dims%x_l_end
          x0 = X_coef( i, 0 ) - X_l( i )
          DO j = 0, order
            c = x0 * Z_l_coef( i, j )
            DO k = 1, j
              c = c + X_coef( i, k ) * Z_l_coef( i, j - k )
            END DO
            COEF( j ) = c - scale * CS_coef( j )
          END DO
          DO j = 1, order
            opj = order + j
            c = X_coef( i, j ) * Z_l_coef( i, order )
            DO k = j + 1, order
              c = c + X_coef( i, k ) * Z_l_coef( i, opj - k )
            END DO
            COEF( opj ) = c - scale * CS_coef( opj )
          END DO
          COEF( 0 ) = MAX( COEF( 0 ), zero )
          IF ( old ) THEN
            CALL ROOTS_solve( COEF, nroots, ROOTS, control%ROOTS_control,      &
                              inform%ROOTS_inform, ROOTS_data )
            alpha = infinity
            DO j = 1, nroots
              IF ( ROOTS( j ) > zero ) THEN
                alpha = ROOTS( j )
                EXIT
              END IF
            END DO
            IF ( alpha < alpha_max_b ) alpha_max_b = alpha
          ELSE
            lower = zero
            upper = alpha_max
            alpha = ROOTS_smallest_root_in_interval(                           &
                        COEF( 0 : 2 * order ), lower, upper,                   &
                        ROOTS_data, control%ROOTS_control, inform%ROOTS_inform )
            alpha_max = alpha
          END IF
        END DO

        DO i = dims%x_u_start, n
          x0 = X_coef( i, 0 ) - X_u( i )
          DO j = 0, order
            c = x0 * Z_u_coef( i, j )
            DO k = 1, j
              c = c + X_coef( i, k ) * Z_u_coef( i, j - k )
            END DO
            COEF( j ) = c - scale * CS_coef( j )
          END DO
          DO j = 1, order
            opj = order + j
            c = X_coef( i, j ) * Z_u_coef( i, order )
            DO k = j + 1, order
              c = c + X_coef( i, k ) * Z_u_coef( i, opj - k )
            END DO
            COEF( opj ) = c - scale * CS_coef( opj )
          END DO
          COEF( 0 ) = MAX( COEF( 0 ), zero )
          IF ( old ) THEN
            CALL ROOTS_solve( COEF, nroots, ROOTS, control%ROOTS_control,      &
                              inform%ROOTS_inform, ROOTS_data )
            alpha = infinity
            DO j = 1, nroots
              IF ( ROOTS( j ) > zero ) THEN
                alpha = ROOTS( j )
                EXIT
              END IF
            END DO
            IF ( alpha < alpha_max_b ) alpha_max_b = alpha
          ELSE
            lower = zero
            upper = alpha_max
            alpha = ROOTS_smallest_root_in_interval(                           &
                        COEF( 0 : 2 * order ), lower, upper,                   &
                        ROOTS_data, control%ROOTS_control, inform%ROOTS_inform )
            alpha_max = alpha
          END IF
        END DO

        DO i = dims%c_l_start, dims%c_l_end
          c0 = C_coef( i, 0 ) - C_l( i )
          DO j = 0, order
            c = c0 * Y_l_coef( i, j )
            DO k = 1, j
              c = c + C_coef( i, k ) * Y_l_coef( i, j - k )
            END DO
            COEF( j ) = c - scale * CS_coef( j )
          END DO
          DO j = 1, order
            opj = order + j
            c = C_coef( i, j ) * Y_l_coef( i, order )
            DO k = j + 1, order
              c = c + C_coef( i, k ) * Y_l_coef( i, opj - k )
            END DO
            COEF( opj ) = c - scale * CS_coef( opj )
          END DO
          COEF( 0 ) = MAX( COEF( 0 ), zero )
          IF ( old ) THEN
            CALL ROOTS_solve( COEF, nroots, ROOTS, control%ROOTS_control,      &
                              inform%ROOTS_inform, ROOTS_data )
            alpha = infinity
            DO j = 1, nroots
              IF ( ROOTS( j ) > zero ) THEN
                alpha = ROOTS( j )
                EXIT
              END IF
            END DO
            IF ( alpha < alpha_max_b ) alpha_max_b = alpha
          ELSE
            lower = zero
            upper = alpha_max
            alpha = ROOTS_smallest_root_in_interval(                           &
                        COEF( 0 : 2 * order ), lower, upper,                   &
                        ROOTS_data, control%ROOTS_control, inform%ROOTS_inform )
            alpha_max = alpha
          END IF
        END DO

        DO i = dims%c_u_start, dims%c_u_end
          c0 = C_coef( i, 0 ) - C_u( i )
          DO j = 0, order
            c = c0 * Y_u_coef( i, j )
            DO k = 1, j
              c = c + C_coef( i, k ) * Y_u_coef( i, j - k )
            END DO
            COEF( j ) = c - scale * CS_coef( j )
          END DO
          DO j = 1, order
            opj = order + j
            c = C_coef( i, j ) * Y_u_coef( i, order )
            DO k = j + 1, order
              c = c + C_coef( i, k ) * Y_u_coef( i, opj - k )
            END DO
            COEF( opj ) = c - scale * CS_coef( opj )
          END DO
          COEF( 0 ) = MAX( COEF( 0 ), zero )
          IF ( old ) THEN
            CALL ROOTS_solve( COEF, nroots, ROOTS, control%ROOTS_control,      &
                              inform%ROOTS_inform, ROOTS_data )
            alpha = infinity
            DO j = 1, nroots
              IF ( ROOTS( j ) > zero ) THEN
                alpha = ROOTS( j )
                EXIT
              END IF
            END DO
            IF ( alpha < alpha_max_b ) alpha_max_b = alpha
          ELSE
            lower = zero
            upper = alpha_max
            alpha = ROOTS_smallest_root_in_interval(                           &
                        COEF( 0 : 2 * order ), lower, upper,                   &
                        ROOTS_data, control%ROOTS_control, inform%ROOTS_inform )
            alpha_max = alpha
          END IF
        END DO
      END IF

!  ================================================
!             part to compute alpha_max_f
!  ================================================

!  Compute the coefficients for the quadratic expression
!  for the overall complementarity, remembering to first
!  subtract the term for the feasibility

      IF ( puiseux ) THEN
        CS_COEF( 0 ) = MAX( CS_COEF( 0 ) - infeas_gamma_f, zero )
        CS_COEF( 1 ) = CS_COEF( 1 ) + two * infeas_gamma_f
        IF ( order > 1 ) CS_COEF( 2 ) = CS_COEF( 2 ) - infeas_gamma_f
      ELSE
        CS_COEF( 0 ) = MAX( CS_COEF( 0 ) - infeas_gamma_f, zero )
        CS_COEF( 1 ) = CS_COEF( 1 ) + infeas_gamma_f
      END IF

      IF ( old ) THEN
        CALL ROOTS_solve( CS_COEF, nroots, ROOTS, control%ROOTS_control,       &
                          inform%ROOTS_inform, ROOTS_data )
        alpha = infinity
        DO j = 1, nroots
          IF ( ROOTS( j ) > zero ) THEN
            alpha = ROOTS( j )
            EXIT
          END IF
        END DO
        IF ( alpha < alpha_max_f ) alpha_max_f = alpha

!  compute the smaller of alpha_max_b and alpha_max_f

        alpha_max = MIN( alpha_max_b, alpha_max_f, one )
      ELSE
        lower = zero
        upper = alpha_max
        alpha = ROOTS_smallest_root_in_interval(                               &
                      CS_COEF( 0 : 2 * order ), lower, upper,                  &
                      ROOTS_data, control%ROOTS_control, inform%ROOTS_inform )
        alpha_max = alpha
        alpha_max = ( one - two * epsmch ) * alpha_max
      END IF

      RETURN

!  End of subroutine CCQP_compute_pmaxstep

      END SUBROUTINE CCQP_compute_pmaxstep

!-*-*-*-*-*-   C C Q P _ I N D I C A T O R S   S U B R O U T I N E   -*-*-*-*-*-

     SUBROUTINE CCQP_indicators( dims, n, m, C_l, C_u, C_last, C,              &
                                 DIST_C_l, DIST_C_u, X_l, X_u, X_last, X,      &
                                 DIST_X_l, DIST_X_u, Y_l, Y_u, Z_l, Z_u,       &
                                 Y_last, Z_last, control, C_stat, B_stat )

!  ---------------------------------------------------------------------------

!  Compute indicatirs for active simnple bounds and general constraints

!  C_stat is an INTEGER array of length m, which if present will be
!   set on exit to indicate the likely ultimate status of the constraints.
!   Possible values are
!   C_stat( i ) < 0, the i-th constraint is likely in the active set,
!                    on its lower bound,
!               > 0, the i-th constraint is likely in the active set
!                    on its upper bound, and
!               = 0, the i-th constraint is likely not in the active set

!  B_stat is an INTEGER array of length n, which if present will be
!   set on exit to indicate the likely ultimate status of the simple bound
!   constraints. Possible values are
!   B_stat( i ) < 0, the i-th bound constraint is likely in the active set,
!                    on its lower bound,
!               > 0, the i-th bound constraint is likely in the active set
!                    on its upper bound, and
!               = 0, the i-th bound constraint is likely not in the active set

!  ---------------------------------------------------------------------------

!  Dummy arguments

      INTEGER, INTENT( IN ) :: n, m
      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X_l, X_u, X
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X_last, Z_last
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( m ) :: C_l, C_u
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( m ) :: C_last, Y_last
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%x_l_start : dims%x_l_end ) :: DIST_X_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%x_u_start : dims%x_u_end ) :: DIST_X_u
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_l_start : dims%c_l_end ) :: DIST_C_l, Y_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_u_start : dims%c_u_end ) :: DIST_C_u, Y_u
      REAL ( KIND = wp ), INTENT( IN ),                                        &
        DIMENSION( dims%c_l_start : dims%c_u_end ) :: C
      REAL ( KIND = wp ), INTENT(IN ),                                         &
             DIMENSION( dims%x_free + 1 : dims%x_l_end ) ::  Z_l
      REAL ( KIND = wp ), INTENT( IN ),                                        &
             DIMENSION( dims%x_u_start : n ) :: Z_u
      TYPE ( CCQP_control_type ), INTENT( IN ) :: control
      INTEGER, INTENT( INOUT ), OPTIONAL, DIMENSION( m ) :: C_stat
      INTEGER, INTENT( INOUT ), OPTIONAL, DIMENSION( n ) :: B_stat

!  Local variables

      INTEGER :: i

!  equality constraints

      C_stat( : dims%c_equality ) = - 1

!  free variables

      B_stat( : dims%x_free ) = 0

!  Compute the required indicator

!  ----------------------------------
!  Type 1 ("primal") indicator used:
!  ----------------------------------

!    a variable/constraint will be "inactive" if
!        distance to nearest bound > indicator_p_tol
!    for some constant indicator_p_tol close-ish to zero

      IF ( control%indicator_type == 1 ) THEN
        DO i = dims%c_equality + 1, m
          IF ( ABS( C( i ) - C_l( i ) ) < control%indicator_tol_p ) THEN
            IF ( ABS( Y_l( i ) ) < control%indicator_tol_p ) THEN
              C_stat( i ) = - 2
            ELSE
              C_stat( i ) = - 1
            END IF
          ELSE IF ( ABS( C( i ) - C_u( i ) ) < control%indicator_tol_p ) THEN
            IF ( ABS( Y_u( i ) ) < control%indicator_tol_p ) THEN
              C_stat( i ) = 2
            ELSE
              C_stat( i ) = 1
            END IF
          ELSE
            C_stat( i ) = 0
          END IF
        END DO
        DO i = dims%x_free + 1, n
          IF ( ABS( X( i ) - X_l( i ) ) < control%indicator_tol_p ) THEN
            IF ( ABS( Z_l( i ) ) < control%indicator_tol_p ) THEN
              B_stat( i ) = - 2
            ELSE
              B_stat( i ) = - 1
            END IF
          ELSE IF ( ABS( X( i ) - X_u( i ) ) < control%indicator_tol_p ) THEN
            IF ( ABS( Z_u( i ) ) < control%indicator_tol_p ) THEN
              B_stat( i ) = 2
            ELSE
              B_stat( i ) = 1
            END IF
          ELSE
            B_stat( i ) = 0
          END IF
        END DO

!  --------------------------------------
!  Type 2 ("primal-dual") indicator used:
!  --------------------------------------

!    a variable/constraint will be "inactive" if
!        distance to nearest bound
!          > indicator_tol_pd * size of corresponding multiplier
!    for some constant indicator_tol_pd close-ish to one.

      ELSE IF ( control%indicator_type == 2 ) THEN

!  constraints with lower bounds

        DO i = dims%c_l_start, dims%c_u_start - 1
!         write(6,"(' cl ', I7,' c,y =', 2ES9.1)") i, DIST_C_l( i ), Y_l( i )
!         write(6,"(' cl ', I7,' i =', ES9.1)") i, DIST_C_l( i ) / Y_l( i )
          IF ( DIST_C_l( i ) > control%indicator_tol_pd * Y_l( i ) ) THEN
            C_stat( i ) = 0
          ELSE
            C_stat( i ) = - 1
          END IF
        END DO

!  constraints with both lower and upper bounds

        DO i = dims%c_u_start, dims%c_l_end
!         write(6,"(' cl ', I7,' c,y =', 2ES9.1)") i, DIST_C_l( i ), Y_l( i )
!         write(6,"(' cu ', I7,' c,y =', 2ES9.1)") i, DIST_C_u( i ), Y_u( i )
!         write(6,"(' cl ', I7,' i =', ES9.1)") i, DIST_C_l( i ) / Y_l( i )
!         write(6,"(' cu ', I7,' i =', ES9.1)") i, DIST_C_u( i ) / Y_u( i )
          IF ( DIST_C_l( i ) <= DIST_C_u( i ) ) THEN
            IF ( DIST_C_l( i ) > control%indicator_tol_pd * Y_l( i ) ) THEN
              C_stat( i ) = 0
            ELSE
              C_stat( i ) = - 1
            END IF
          ELSE
            IF ( DIST_C_u( i ) > - control%indicator_tol_pd * Y_u( i ) ) THEN
              C_stat( i ) = 0
            ELSE
              C_stat( i ) = 1
            END IF
          END IF
        END DO

!  constraints with upper bounds

        DO i = dims%c_l_end + 1, m
!         write(6,"(' cu ', I7,' c,y =', 2ES9.1)") i, DIST_C_u( i ), Y_u( i )
!         write(6,"(' cu ', I7,' i =', ES9.1)") i, DIST_C_u( i ) / Y_u( i )
          IF ( DIST_C_u( i ) > - control%indicator_tol_pd * Y_u( i ) ) THEN
            C_stat( i ) = 0
          ELSE
            C_stat( i ) = 1
          END IF
        END DO

!  simple non-negativity

        DO i = dims%x_free + 1, dims%x_l_start - 1
!         write(6,"(' bl ', I7,' x,z =', 2ES9.1)") i, X( i ), Z_l( i )
!         write(6,"(' bl ', I7,' i =', ES9.1)") i, X( i ) / Z_l( i )
          IF ( X( i ) > control%indicator_tol_pd * Z_l( i ) ) THEN
            B_stat( i ) = 0
          ELSE
            B_stat( i ) = - 1
          END IF
        END DO

!  simple bound from below

        DO i = dims%x_l_start, dims%x_u_start - 1
          write(6,"(' bl ', I7,' x,z =', 2ES9.1)") i, DIST_X_l( i ), Z_l( i )
!         write(6,"(' bl ', I7,' i =', ES9.1)") i, DIST_X_l( i ) / Z_l( i )
          IF ( DIST_X_l( i ) > control%indicator_tol_pd * Z_l( i ) ) THEN
            B_stat( i ) = 0
          ELSE
            B_stat( i ) = - 1
          END IF
        END DO

!  simple bound from below and above

        DO i = dims%x_u_start, dims%x_l_end
!         write(6,"(' bl ', I7,' x,z =', 2ES9.1)") i, DIST_X_l( i ), Z_l( i )
!         write(6,"(' bu ', I7,' x,z =', 2ES9.1)") i, DIST_X_u( i ), Z_u( i )
!         write(6,"(' bl ', I7,' i =', ES9.1)") i, DIST_X_l( i ) / Z_l( i )
!         write(6,"(' bu ', I7,' i =', ES9.1)") i, DIST_X_u( i ) / Z_u( i )
          IF ( DIST_X_l( i ) <= DIST_X_u( i ) ) THEN
            IF ( DIST_X_l( i ) > control%indicator_tol_pd * Z_l( i ) ) THEN
              B_stat( i ) = 0
            ELSE
              B_stat( i ) = - 1
            END IF
          ELSE
            IF ( DIST_x_u( i ) > - control%indicator_tol_pd * Z_u( i ) ) THEN
              B_stat( i ) = 0
            ELSE
              B_stat( i ) = 1
            END IF
          END IF
        END DO

!  simple bound from above

        DO i = dims%x_l_end + 1, dims%x_u_end
!         write(6,"(' bu ', I7,' x,z =', 2ES9.1)") i, DIST_X_u( i ), Z_u( i )
!         write(6,"(' bu ', I7,' i =', ES9.1)") i, DIST_X_u( i ) / Z_u( i )
          IF ( DIST_x_u( i ) > - control%indicator_tol_pd * Z_u( i ) ) THEN
            B_stat( i ) = 0
          ELSE
            B_stat( i ) = 1
          END IF
        END DO

!  simple non-positivity

        DO i = dims%x_u_end + 1, n
!         write(6,"(' bu ', I7,' x,z =', 2ES9.1)") i, X( i ), Z_u( i )
!         write(6,"(' bu ', I7,' i =', ES9.1 )") i, - X( i ) / Z_u( i )
          IF ( - X( i ) > - control%indicator_tol_pd * Z_u( i ) ) THEN
            B_stat( i ) = 0
          ELSE
            B_stat( i ) = 1
          END IF
        END DO

!  --------------------------------
!  Type 3 ("Tapia") indicator used:
!  --------------------------------

!    a variable/constraint will be "inactive" if
!        distance to nearest bound now
!          > indicator_tol_tapia * distance to same bound at previous iteration
!    for some constant indicator_tol_tapia close-ish to one.

      ELSE IF ( control%indicator_type == 3 ) THEN

!  constraints with lower bounds

        DO i = dims%c_l_start, dims%c_u_start - 1
          IF ( ABS( C( i ) - C_l( i ) ) > control%indicator_tol_tapia *        &
               ABS( C_last( i ) - C_l( i ) ) ) THEN
            C_stat( i ) = 0
          ELSE
            IF ( ABS( Y_l( i ) / Y_last( i ) )                                 &
                 > control%indicator_tol_tapia ) THEN
              C_stat( i ) = - 1
            ELSE
!             write(6,*) i, ABS( Y_l( i ) / Y_last( i ) )
              C_stat( i ) = - 2
            END IF
          END IF
        END DO

!  constraints with both lower and upper bounds

        DO i = dims%c_u_start, dims%c_l_end
          IF ( DIST_C_l( i ) <= DIST_C_u( i ) ) THEN
            IF ( ABS( C( i ) - C_l( i ) ) > control%indicator_tol_tapia *      &
                 ABS( C_last( i ) - C_l( i ) ) ) THEN
              C_stat( i ) = 0
            ELSE
              IF ( ABS( Y_l( i ) / Y_last( i ) )                               &
                   > control%indicator_tol_tapia ) THEN
                C_stat( i ) = - 1
              ELSE
!               write(6,*) i, ABS( Y_l( i ) / Y_last( i ) )
                C_stat( i ) = - 2
              END IF
            END IF
          ELSE
            IF ( ABS( C( i ) - C_u( i ) ) > control%indicator_tol_tapia *      &
                 ABS( C_last( i ) - C_u( i ) ) )  THEN
              C_stat( i ) = 0
            ELSE
              IF ( ABS( Y_u( i ) / Y_last( i ) )                               &
                   > control%indicator_tol_tapia ) THEN
                C_stat( i ) = 1
              ELSE
!               write(6,*) i, ABS( Y_u( i ) / Y_last( i ) )
                C_stat( i ) = 2
              END IF
            END IF
          END IF
        END DO

!  constraints with upper bounds

        DO i = dims%c_l_end + 1, m
          IF ( ABS( C( i ) - C_u( i ) ) > control%indicator_tol_tapia *        &
               ABS( C_last( i ) - C_u( i ) ) )  THEN
            C_stat( i ) = 0
          ELSE
            IF ( ABS( Y_u( i ) / Y_last( i ) )                                 &
                 > control%indicator_tol_tapia ) THEN
              C_stat( i ) = 1
            ELSE
!             write(6,*) i, ABS( Y_u( i ) / Y_last( i ) )
              C_stat( i ) = 2
            END IF
          END IF
        END DO

!  simple non-negativity

        DO i = dims%x_free + 1, dims%x_l_start - 1
          IF ( ABS( X( i ) ) > control%indicator_tol_tapia *                   &
               ABS( X_last( i ) ) ) THEN
            B_stat( i ) = 0
          ELSE
            IF ( ABS( Z_l( i ) / Z_last( i ) )                                 &
                 > control%indicator_tol_tapia ) THEN
              B_stat( i ) = - 1
            ELSE
!             write(6,*) i, ABS( Z_l( i ) / Z_last( i ) )
              B_stat( i ) = - 2
            END IF
          END IF
        END DO

!  simple bound from below

        DO i = dims%x_l_start, dims%x_u_start - 1
          IF ( ABS( X( i ) - X_l( i ) ) > control%indicator_tol_tapia *        &
               ABS( X_last( i ) - X_l( i ) ) ) THEN
            B_stat( i ) = 0
          ELSE
            IF ( ABS( Z_l( i ) / Z_last( i ) )                                 &
                 > control%indicator_tol_tapia ) THEN
              B_stat( i ) = - 1
            ELSE
!             write(6,*) i, ABS( Z_l( i ) / Z_last( i ) )
              B_stat( i ) = - 2
            END IF
          END IF
        END DO

!  simple bound from below and above

        DO i = dims%x_u_start, dims%x_l_end
          IF ( DIST_X_l( i ) <= DIST_X_u( i ) ) THEN
            IF ( ABS( X( i ) - X_l( i ) ) > control%indicator_tol_tapia *      &
                 ABS( X_last( i ) - X_l( i ) ) ) THEN
              B_stat( i ) = 0
            ELSE
              IF ( ABS( Z_l( i ) / Z_last( i ) )                               &
                   > control%indicator_tol_tapia ) THEN
                B_stat( i ) = - 1
              ELSE
!               write(6,*) i, ABS( Z_l( i ) / Z_last( i ) )
                B_stat( i ) = - 2
              END IF
            END IF
          ELSE
            IF ( ABS( X( i ) - X_u( i ) ) > control%indicator_tol_tapia *      &
                 ABS( X_last( i ) - X_u( i ) ) ) THEN
              B_stat( i ) = 0
            ELSE
              IF ( ABS( Z_u( i ) / Z_last( i ) )                               &
                   > control%indicator_tol_tapia ) THEN
                B_stat( i ) = 1
              ELSE
!               write(6,*) i, ABS( Z_u( i ) / Z_last( i ) )
                B_stat( i ) = 2
              END IF
            END IF
          END IF
        END DO

!  simple bound from above

        DO i = dims%x_l_end + 1, dims%x_u_end
            IF ( ABS( X( i ) - X_u( i ) ) > control%indicator_tol_tapia *      &
                 ABS( X_last( i ) - X_u( i ) ) ) THEN
            B_stat( i ) = 0
          ELSE
            IF ( ABS( Z_u( i ) / Z_last( i ) )                                 &
                 > control%indicator_tol_tapia ) THEN
              B_stat( i ) = 1
            ELSE
!             write(6,*) i, ABS( Z_u( i ) / Z_last( i ) )
              B_stat( i ) = 2
            END IF
          END IF
        END DO

!  simple non-positivity

        DO i = dims%x_u_end + 1, n
          IF ( ABS( X( i ) ) > control%indicator_tol_tapia *                   &
               ABS( X_last( i ) ) ) THEN
            B_stat( i ) = 0
          ELSE
            IF ( ABS( Z_u( i ) / Z_last( i ) )                                 &
                 > control%indicator_tol_tapia ) THEN
              B_stat( i ) = 1
            ELSE
!             write(6,*) i, ABS( Z_u( i ) / Z_last( i ) )
              B_stat( i ) = 2
            END IF
          END IF
        END DO
      ELSE
      END IF

!     IF ( .TRUE. ) THEN
!       WRITE(  control%out,                                                   &
!         "( /, ' Constraints : ', /, '                   ',                   &
!      &   '        <------ Bounds ------> ', /                                &
!      &   '      # name       state      Lower       Upper     Multiplier' )" )
!       DO i = dims%c_equality + 1, m
!         WRITE(  control%out,"( 2I7, 4ES12.4 )" ) i,                          &
!           C_stat( i ), C( i ), C_l( i ), C_u( i ), Y( i )
!       END DO

!       WRITE(  control%out,                                                   &
!          "( /, ' Solution : ', /,'                    ',                     &
!         &    '        <------ Bounds ------> ', /                            &
!         &    '      # name       state      Lower       Upper       Dual' )" )
!       DO i = dims%x_free + 1, n
!         WRITE(  control%out,"( 2I7, 4ES12.4 )" ) i,                          &
!           B_stat( i ), X( i ), X_l( i ), X_u( i ), Z( i )
!       END DO
!     END IF

      RETURN

!  End of CCQP_indicators

      END SUBROUTINE CCQP_indicators

!-*-*-*-*-*-*-*-*-   C C Q P _ L U N G E   S U B R O U T I N E   -*-*-*-*-*-*-*-*-

      SUBROUTINE CCQP_lunge( dims, n, m, A_val, A_col, A_ptr,                  &
                             C_l, C_u, X_l, X_u, X, C, Y, Z,                   &
                             Hessian_kind, gradient_kind, target_kind,         &
                             H_val, H_col, H_ptr, WEIGHT, X0, G,               &
                             C_stat, B_Stat, control, optimal )

!  Dummy arguments

      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      INTEGER, INTENT( IN ) :: n, m
      INTEGER, INTENT( IN ) :: Hessian_kind, gradient_kind, target_kind
      INTEGER, INTENT( IN ), DIMENSION( n + 1 ), OPTIONAL  :: H_ptr
      INTEGER, INTENT( IN ), DIMENSION( : ), OPTIONAL  :: H_col
      REAL ( KIND = wp ), INTENT( IN ),                                        &
                          DIMENSION( : ), OPTIONAL  :: H_val
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ), OPTIONAL :: WEIGHT, X0
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ), OPTIONAL :: G
      INTEGER, INTENT( IN ), DIMENSION( m + 1 ) :: A_ptr
      INTEGER, INTENT( IN ), DIMENSION( A_ptr( m + 1 ) - 1 ) :: A_col
      REAL ( KIND = wp ), INTENT( IN ),                                        &
                          DIMENSION( A_ptr( m + 1 ) - 1 ) :: A_val
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( m ) :: C_l, C_u
      REAL ( KIND = wp ), INTENT( IN ), DIMENSION( n ) :: X_l, X_u
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( n ) :: X
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( m ) :: C
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( m ) :: Y
      REAL ( KIND = wp ), INTENT( OUT ), DIMENSION( n ) :: Z
      INTEGER, INTENT( IN ), DIMENSION( m ) :: C_stat
      INTEGER, INTENT( IN ), DIMENSION( n ) :: B_stat
      TYPE ( CCQP_control_type ), INTENT( IN ) :: control
      LOGICAL, INTENT( OUT ) :: optimal

!  construct the equality-constrained QP according to the variables and
!  constraints that are predicted to be active via

!  C_stat is an INTEGER array of length m, which must have been be set to 
!   indicate the likely ultimate status of the constraints.
!   Possible values are
!   C_stat( i ) < 0, the i-th constraint is likely in the active set,
!                    on its lower bound,
!               > 0, the i-th constraint is likely in the active set
!                    on its upper bound, and
!               = 0, the i-th constraint is likely not in the active set

!  B_stat is an INTEGER array of length n, which must have been set to
!   indicate the likely ultimate status of the simple bound constraints
!   Possible values are
!   B_stat( i ) < 0, the i-th bound constraint is likely in the active set,
!                    on its lower bound,
!               > 0, the i-th bound constraint is likely in the active set
!                    on its upper bound, and
!               = 0, the i-th bound constraint is likely not in the active set

!! *** naive way ... improve later by eliminating fixed variable *** !!

!  Local variables

      INTEGER :: i, ii, j, jj, l, alloc_status
      INTEGER :: n_free, m_active, nz_a_active, nz_h_free
      REAL ( KIND = wp ) :: ci, ei
      INTEGER, ALLOCATABLE, DIMENSION( : ) :: X_free
      REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: C_active, G_free
      REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: SOL, E
      LOGICAL :: x_feas, c_feas, y_feas, z_feas
      TYPE ( SMT_type ) :: H_free, A_active, C_zero
      TYPE ( SBLS_data_type ) :: sbls_data
      TYPE ( SBLS_control_type ) :: sbls_control
      TYPE ( SBLS_inform_type ) :: sbls_inform
      REAL ( KIND = wp ) :: feas = epsmch * 100.0_wp
      LOGICAL :: reduced = .FALSE.
!     LOGICAL :: reduced = .TRUE.

!  Using the sets B = { i | B_stat( i ) = 0 }, F = { i | B_stat( i ) /= 0 } 
!  and A = { i | C_stat( i ) = 0 }, the corresponding "optimality" system 

!     (  H_BB  H_BF^T  A_AB^T  I_B^T  ) (   x_B ) = ( - g_B )
!     (  H_BF   H_FF   A_AF^T    0    ) (   x_F )   ( - g_F )    (1)
!     (  A_AB   A_AF     0       0    ) ( - y_A )   (  c_A  )
!     (  I_B     0       0       0    ) ( - z_B )   (  b_B  )

!  may either be solved "as is", or by eliminating x_B = b_B, 
!  solving the "reduced" system

!     (  H_FF   A_AF^T  ) (   x_F )   ( - g_F - H_BF x_B )       (2)
!     (  A_AF     0     ) ( - y_A )   (   c_A - A_AB x_B )

!  and then recovering

!     z_B = g_B + H_BB x_B + H_BF^T x_F - A_AB^T y_A         (3)

!  -------------------------------
!  1. solve via the reduced system
!  -------------------------------

      IF ( reduced ) THEN

!  count the number of free variables (variables in F), and flag their
!  indices in X_flag (a 0 value indicates a fixed variable). Also set
!  the active components of x to their appropriate bounds and the
!  inactive dual variables z to zero, and initialize the active dual
!  varaibles to g_B
      
        ALLOCATE( X_free( n ), STAT = alloc_status )
        n_free = 0
        DO j = 1, n
          IF ( B_stat( j ) == 0 ) THEN
            n_free = n_free + 1
            X_free( j ) = n_free
            Z( j ) = zero
          ELSE
            X_free( j ) = 0
            IF ( B_stat( j ) < 0 ) THEN
              X( j ) = X_l( j )
            ELSE
              X( j ) = X_u( j )
            END IF
            Z( j ) = G( j )
          END IF
        END DO

!  allocate space to hold the free gradient, g_F

        ALLOCATE( G_free( n_free ), STAT = alloc_status )

!  count the number of nonzeros in the (upper triangle of the) free Hessian,
!  H_FF. Also set the free gradient

        nz_h_free = 0
        DO j = 1, n
          IF ( B_stat( j ) == 0 ) THEN
            G_free( X_free( j ) ) = G( j )
            DO l = H_ptr( j ), H_ptr( j + 1 ) - 1
              IF ( X_free( H_col( l ) ) > 0 ) nz_h_free = nz_h_free + 1
            END DO
          END IF
        END DO
!       write(6,"( ' G_free ', /, ( 5ES12.4 ) )" ) G_free

!  allocate space to hold the free Hessian

        ALLOCATE( H_free%ptr( n_free + 1 ), STAT = alloc_status )
        ALLOCATE( H_free%col( nz_h_free ), STAT = alloc_status )
        ALLOCATE( H_free%val( nz_h_free ), STAT = alloc_status )

!  set up H_FF, and add H_BF x_B to g_F

        CALL SMT_put( H_free%type, 'SPARSE_BY_ROWS', alloc_status )
        n_free = 0 ; nz_h_free = 0
        H_free%ptr( 1 ) = 1
        DO j = 1, n
          IF ( B_stat( j ) == 0 ) THEN
            n_free = n_free + 1
            jj = n_free
            DO l = H_ptr( j ), H_ptr( j + 1 ) - 1
              i = H_col( l )
              ii = X_free( i )
              IF ( ii > 0 ) THEN
                nz_h_free = nz_h_free + 1
                H_free%col( nz_h_free ) = ii
                H_free%val( nz_h_free ) = H_val( l )
              ELSE
                G_free( jj ) = G_free( jj ) + H_val( l ) * X( i )
              END IF
            END DO
            H_free%ptr( n_free + 1 ) = nz_h_free + 1
          ELSE
            DO l = H_ptr( j ), H_ptr( j + 1 ) - 1
              i = H_col( l )
              ii = X_free( i )
              IF ( ii > 0 ) THEN
                G_free( ii ) = G_free( ii ) + H_val( l ) * X( j )
              END IF 
            END DO
          END IF
        END DO
!       write(6,"( ' G_free ', /, ( 5ES12.4 ) )" ) G_free

!  count the number of nonzeros in the reduced active Jacobian, A_AF

        m_active = 0 ; nz_a_active = 0
        DO i = 1, m
          IF ( C_stat( i ) /= 0 ) THEN
            m_active = m_active + 1
            DO l = A_ptr( i ), A_ptr( i + 1 ) - 1
              IF ( X_free( A_col( l ) ) > 0 ) nz_a_active = nz_a_active + 1
            END DO
          END IF
        END DO

!  allocate space to hold the active Jacobian and right-hand side vector, c_A

        ALLOCATE( C_active( m_active ), STAT = alloc_status )
        ALLOCATE( A_active%ptr( m_active + 1 ), STAT = alloc_status )
        ALLOCATE( A_active%col( nz_a_active ), STAT = alloc_status )
        ALLOCATE( A_active%val( nz_a_active ), STAT = alloc_status )

!  set up A_AF, and subtract A_AB x_B from c_A

        CALL SMT_put( A_active%type, 'SPARSE_BY_ROWS', alloc_status )
        m_active = 0 ; nz_a_active = 0
        A_active%ptr( 1 ) = 1
        DO i = 1, m
          IF ( C_stat( i ) /= 0 ) THEN
            m_active = m_active + 1
            IF ( C_stat( i ) > 0 ) THEN
              C_active( m_active ) = C_u( i )
            ELSE
              C_active( m_active ) = C_l( i )
            END IF
            DO l = A_ptr( i ), A_ptr( i + 1 ) - 1
              j = A_col( l )
              jj = X_free( j )
              IF ( jj > 0 ) THEN
                nz_a_active = nz_a_active + 1
                A_active%col( nz_a_active ) = jj
                A_active%val( nz_a_active ) = A_val( l )
              ELSE
                C_active( m_active )                                           &
                  = C_active( m_active ) - A_val( l ) * X( j )
              END IF
            END DO
            A_active%ptr( m_active + 1 ) = nz_a_active + 1
          END IF
        END DO
!       write(6,"( ' C_active ', /, ( 5ES12.4 ) )" ) C_active

!  record a zero 2,2 block, C_zero, of the augmented system

        CALL SMT_put( C_zero%type, 'ZERO', alloc_status )

!  initialize data for factorization and solve

        CALL SBLS_initialize( sbls_data, sbls_control, sbls_inform )
        sbls_control = control%sbls_control

!  factorize the reduced matrix

!     (  H_FF   A_AF^T  )
!     (  A_AF     0     )

        CALL SBLS_form_and_factorize( n_free, m_active, H_free, A_active,      &
                                      C_zero, sbls_data, sbls_control,         &
                                      sbls_inform )

!  solve the reduced system (2) with ( - g_F - H_BF x_B, c_A - A_AB x_B )
!  input in sol and (x_F, -y_A) output in the same vector

        ALLOCATE( SOL( n_free + m_active ), STAT = alloc_status )
        SOL( : n_free ) = - G_free( : n_free ) 
        SOL( n_free + 1 : ) = C_active( : m_active ) 

        CALL SBLS_solve( n_free, m_active, A_active, C_zero, sbls_data,        &
                         sbls_control, sbls_inform, SOL )

!       CALL SBLS_terminate( sbls_data, sbls_control, sbls_inform )

!  recover x_F

        n_free = 0
        DO j = 1, n
          IF ( B_stat( j ) == 0 ) THEN
            n_free = n_free + 1
            X( j ) = SOL( n_free )
          END IF
        END DO

!  recover y

        l = n_free
        DO i = 1, m
          IF ( C_stat( i ) /= 0 ) THEN
            l = l + 1
            Y( i ) = - SOL( l )
          ELSE
            Y( i ) = zero
          END IF
        END DO

!  recover z_B = g_B + H_BB x_B + H_BF^T x_F - A_AB^T y_A

!  H_BB x_B + H_BF^T x_F contributions

        DO j = 1, n
          DO l = H_ptr( j ), H_ptr( j + 1 ) - 1
            i = H_col( l )
            IF ( B_stat( j ) /= 0 ) THEN
              IF ( B_stat( i ) /= 0 ) THEN ! entry from H_BB
                Z( j ) = Z( j ) + H_val( l ) * X( i )
                IF ( j /= i ) Z( i ) = Z( i ) + H_val( l ) * X( j )
              ELSE ! entry from H_BF^T
                Z( j ) = Z( j ) + H_val( l ) * X( i )
              END IF
            ELSE
              IF ( B_stat( i ) /= 0 ) THEN  ! entry from H_BF^T
                Z( i ) = Z( i ) + H_val( l ) * X( j )
              END IF
            END IF
          END DO
        END DO

!  - A_AB^T y_A contributions

        DO i = 1, m
          IF ( C_stat( i ) /= 0 ) THEN
            DO l = A_ptr( i ), A_ptr( i + 1 ) - 1
              j = A_col( l ) 
              IF ( B_stat( j ) /= 0 ) THEN ! entry from A_AB
                Z( j ) = Z( j ) - A_val( l ) * Y( i )
              END IF
            END DO
          END IF
        END DO

!  ----------------------------
!  2. solve via the full system
!  ----------------------------

      ELSE

!  compute the number of active constraints, and the number of nonzeros 
!  in the active Jacobian A_active

        n_free = n

!  allocate space to hold the free Hessian and gradient

!  set up H_free and g_free

        ALLOCATE( G_free( n_free ), STAT = alloc_status )
        IF ( gradient_kind == 0 ) THEN
          G_free( : n_free ) = zero
        ELSE IF ( gradient_kind == 1 ) THEN
          G_free( : n_free ) = one
        ELSE
          G_free( : n_free ) = G( : n_free )
        END IF

        H_free%n = n_free
        IF ( Hessian_kind == 0 ) THEN
          nz_h_free = 0
          CALL SMT_put( H_free%type, 'ZERO', alloc_status )
        ELSE IF ( Hessian_kind == 1 ) THEN
          nz_h_free = 0
          CALL SMT_put( H_free%type, 'IDENTITY', alloc_status )
          IF ( target_kind == 1 ) THEN
            G_free( : n_free ) = G_free( : n_free ) - one
          ELSE IF ( target_kind /= 0 ) THEN
            G_free( : n_free ) = G_free( : n_free ) - X0( : n_free )
          END IF
        ELSE IF ( Hessian_kind == 2 ) THEN
          nz_h_free = n_free
          CALL SMT_put( H_free%type, 'DIAGONAL', alloc_status )
          ALLOCATE( H_free%val( n_free ), STAT = alloc_status )
          H_free%val( : n_free ) = WEIGHT( : n_free )
          IF ( target_kind == 1 ) THEN
            G_free( : n_free ) = G_free( : n_free ) - WEIGHT( : n_free )
          ELSE IF ( target_kind /= 0 ) THEN
            G_free( : n_free )                                                 &
              = G_free( : n_free ) - WEIGHT( : n_free ) * X0( : n_free )
          END IF
        ELSE IF ( hessian_kind < 0 ) THEN
          nz_h_free = H_ptr( n + 1 ) - 1
          ALLOCATE( H_free%ptr( n_free + 1 ), STAT = alloc_status )
          ALLOCATE( H_free%col( nz_h_free ), STAT = alloc_status )
          ALLOCATE( H_free%val( nz_h_free ), STAT = alloc_status )
          CALL SMT_put( H_free%type, 'SPARSE_BY_ROWS', alloc_status )
          H_free%ptr( : n_free + 1 ) = H_ptr( : n_free + 1 )
          H_free%col( : nz_h_free ) = H_col( : nz_h_free )
          H_free%val( : nz_h_free ) = H_val( : nz_h_free )
        END IF

!  compute the number of active constraints, and the number of nonzeros 
!  in the active Jacobian A_active

        m_active = 0 ; nz_a_active = 0
        DO i = 1, m
!         IF ( C_stat( i ) /= 0 ) THEN
          IF ( C_stat( i ) == 1 .OR. C_stat( i ) == - 1 ) THEN
            m_active = m_active + 1
            nz_a_active = nz_a_active + A_ptr( i + 1 ) - A_ptr( i )
          END IF
        END DO

        DO j = 1, n
!         IF ( B_stat( j ) /= 0 ) THEN
          IF ( B_stat( j ) == 1 .OR. B_stat( j ) == - 1 ) THEN
            m_active = m_active + 1 ; nz_a_active = nz_a_active + 1
          END IF
        END DO

!  allocate space to hold the active Jacobian and right-hand side vector

        ALLOCATE( C_active( m_active ), STAT = alloc_status )
        ALLOCATE( A_active%ptr( m_active + 1 ), STAT = alloc_status )
        ALLOCATE( A_active%col( nz_a_active ), STAT = alloc_status )
        ALLOCATE( A_active%val( nz_a_active ), STAT = alloc_status )

!  set up A_active and c_active

        CALL SMT_put( A_active%type, 'SPARSE_BY_ROWS', alloc_status )
        A_active%m = m_active
        A_active%n = n_free

        m_active = 0 ; nz_a_active = 0
        A_active%ptr( 1 ) = 1
        DO i = 1, m
!         IF ( C_stat( i ) /= 0 ) THEN
          IF ( C_stat( i ) == 1 .OR. C_stat( i ) == - 1 ) THEN
            m_active = m_active + 1
            IF ( C_stat( i ) > 0 ) THEN
              C_active( m_active ) = C_u( i )
            ELSE
              C_active( m_active ) = C_l( i )
            END IF
            DO l = A_ptr( i ), A_ptr( i + 1 ) - 1
              nz_a_active = nz_a_active + 1
              A_active%col( nz_a_active ) = A_col( l )
              A_active%val( nz_a_active ) = A_val( l )
            END DO
            A_active%ptr( m_active + 1 ) = nz_a_active + 1
          END IF
        END DO

        DO j = 1, n
!         IF ( B_stat( j ) /= 0 ) THEN
          IF ( B_stat( j ) == 1 .OR. B_stat( j ) == - 1 ) THEN
            m_active = m_active + 1
            IF ( B_stat( j ) > 0 ) THEN
              C_active( m_active ) = X_u( j )
            ELSE
              C_active( m_active ) = X_l( j )
            END IF
            nz_a_active = nz_a_active + 1
            A_active%col( nz_a_active ) = j
            A_active%val( nz_a_active ) = one
            A_active%ptr( m_active + 1 ) = nz_a_active + 1
          END IF
        END DO

!  record a zero 2,2 block, C_zero, of the augmented system

        CALL SMT_put( C_zero%type, 'ZERO', alloc_status )

!  initialize data for factorization and solve

        CALL SBLS_initialize( sbls_data, sbls_control, sbls_inform )
        sbls_control = control%sbls_control

!  factorize the full matrix

!     (    H      A_active^T )
!     ( A_active      0      )

        CALL SBLS_form_and_factorize( n_free, m_active, H_free, A_active,      &
                                      C_zero, sbls_data, sbls_control,         &
                                      sbls_inform )

!  solve the full system (1)

!     (    H     A_active^T ) (   x ) =  ( - g_free )
!     ( A_active     0      ) ( - y )    ( c_active )

!  with (-g_free, c_active ) input in sol and (x,-y) output in the same vector

        ALLOCATE( SOL( n_free + m_active ), STAT = alloc_status )
        SOL( : n_free ) = - G_free( : n_free ) 
        SOL( n_free + 1 : ) = C_active( : m_active ) 

        CALL SBLS_solve( n_free, m_active, A_active, C_zero, sbls_data,        &
                         sbls_control, sbls_inform, SOL )

!       CALL SBLS_terminate( sbls_data, sbls_control, sbls_inform )

!  recover x

        X( : n_free ) = SOL( : n_free )

!  recover y

        l = n_free
        DO i = 1, m
!        IF ( C_stat( i ) /= 0 ) THEN
         IF ( C_stat( i ) == 1 .OR. C_stat( i ) == - 1 ) THEN
            l = l + 1
            Y( i ) = - SOL( l )
          ELSE
            Y( i ) = zero
          END IF
        END DO

!  recover z

        DO j = 1, n
!         IF ( B_stat( j ) /= 0 ) THEN
          IF ( B_stat( j ) == 1 .OR. B_stat( j ) == - 1 ) THEN
           l = l + 1
            Z( j ) = - SOL( l )
          ELSE
            Z( j ) = zero
          END IF
        END DO
      END IF

!  compute c and an estimate e of the error in c

      ALLOCATE( E( m ), STAT = alloc_status )
      DO i = 1, m
        ci = zero
        ei = zero
        DO l = A_ptr( i ), A_ptr( i + 1 ) - 1
          ci = ci + A_val( l ) * X( A_col( l ) )
          ei = ei + ABS( A_val( l ) ) * ABS( X( A_col( l ) ) )
        END DO
        C( i ) = ci
        E( i ) = ei * epsmch
      END DO

      x_feas = .TRUE.
      c_feas = .TRUE.
      y_feas = .TRUE.
      z_feas = .TRUE.

!  check for feasibility of the general constraints

      DO i = 1, m

!  equality constraint

        ei = E( i )
        IF ( C_l( i ) == C_u( i ) ) THEN 
!write( 6, "( ' c = ', ES22.14, ' c_l = ', ES22.14 )" ) C( i ), C_l( i ) 

!  infeasible inequality constraint

        ELSE IF ( C( i ) < C_l( i ) - ei ) THEN
!write( 6, "( ' c_stat ', I0 )" ) C_stat( i )
!write( 6, "( ' c = ', ES22.14, ' c_l = ', ES22.14 )" ) C( i ), C_l( i ) 
          c_feas = .FALSE. ; EXIT
        ELSE IF ( C( i ) > C_u( i ) + ei ) THEN
!write( 6, "( ' c_stat ', I0 )" ) C_stat( i )
!write( 6, "( ' c = ', ES22.14, ' c_u = ', ES22.14 )" ) C( i ), C_u( i ) 
          c_feas = .FALSE. ; EXIT

!  incorrect Lagrange multiplier of active constraint at lower bound

        ELSE IF ( C( i ) < C_l( i ) + ei ) THEN
          IF ( Y( i ) < - feas ) THEN
!write( 6, "( ' c_stat ', I0 )" ) C_stat( i )
!write( 6, "( ' c = ', ES22.14, ' c_l = ', ES22.14 )" ) C( i ), C_l( i ) 
!write( 6, "( ' y_l = ', ES22.14 )" ) Y( i )
            y_feas = .FALSE. ; EXIT
          END IF

!  incorrect Lagrange multiplier of active counstraint at upper bound

        ELSE IF ( C( i ) > C_u( i ) - ei ) THEN
          IF ( Y( i ) > feas ) THEN
!write( 6, "( ' c_stat ', I0 )" ) C_stat( i )
!write( 6, "( ' c = ', ES22.14, ' c_u = ', ES22.14 )" ) C( i ), C_u( i ) 
!write( 6, "( ' y_u = ', ES22.14 )" ) Y( i )
            y_feas = .FALSE. ; EXIT
          END IF

!  incorrect Lagrange multiplier of inactive constraint

        ELSE
          IF ( ABS( Y( i ) ) > feas ) THEN
        write( 6, "( ' ||x||, ||a_i|| = ', 2ES12.4 )" ) MAXVAL( ABS( X ) ),    &
 MAXVAL( ABS( A_val( A_ptr( i ) :A_ptr( i + 1 ) - 1 ) ) )
!write( 6, "( ' c_stat ', I0 )" ) C_stat( i )
!write( 6, "( ' c - c_l = ', ES22.14, ' c - c_u = ', ES22.14 , &
! & ' feas = ', ES22.14 )" ) C( i ) - c_l( i ), c( i ) - C_u( i ), feas
!write( 6, "( ' y = ', ES22.14 )" ) Y( i )
            y_feas = .FALSE. ; EXIT
          END IF
        END IF
      END DO

!  check for feasibility of the simple bound constraints

      DO j = 1, n

!  fixed variable

        IF ( X_l( j ) == X_u( j ) ) THEN 

!  infeasible simple bound

        ELSE IF ( X( j ) < X_l( j ) - feas ) THEN
!write( 6, "( ' b_stat ', I0 )" ) B_stat( j )
!write( 6, "( ' x = ', ES22.14, ' x_l = ', ES22.14 )" ) X( j ), X_l( j ) 
          x_feas = .FALSE. ; EXIT
        ELSE IF ( X( j ) > X_u( j ) + feas ) THEN
!write( 6, "( ' b_stat ', I0 )" ) B_stat( j )
!write( 6, "( ' x = ', ES22.14, ' x_u = ', ES22.14 )" ) X( j ), X_u( j ) 
          x_feas = .FALSE. ; EXIT

!  incorrect dual variable of variable at lower bound

        ELSE IF ( X( j ) < X_l( j ) + feas ) THEN
          IF ( Z( j ) < - feas ) THEN
!write( 6, "( ' b_stat ', I0 )" ) B_stat( j )
!write( 6, "( ' z_l = ', ES22.14 )" ) Z( j )
            z_feas = .FALSE. ; EXIT
          END IF

!  incorrect dual variable of variable at upper bound

        ELSE IF ( X( j ) > X_u( j ) - feas ) THEN
          IF ( Z( j ) > feas ) THEN
!write( 6, "( ' b_stat ', I0 )" ) B_stat( j )
!write( 6, "( ' z_u = ', ES22.14 )" ) Z( j )
            z_feas = .FALSE. ; EXIT
          END IF

!  incorrect dual variable of inactive simple bound

        ELSE
          IF ( ABS( Z( j ) ) > feas ) THEN
!write( 6, "( ' b_stat ', I0 )" ) B_stat( j )
!write( 6, "( ' z = ', ES22.14 )" ) Z( j )
            z_feas = .FALSE. ; EXIT
          END IF
        END IF
      END DO

!write(6,*) ' x_feas, c_feas, y_feas, z_feas ', x_feas, c_feas, y_feas, z_feas
      optimal = x_feas .AND. c_feas .AND. y_feas .AND. z_feas

      RETURN

!  End of CCQP_lunge

      END SUBROUTINE CCQP_lunge

!-*-*-*-*-*-*-   C C Q P _ w o r k s p a c e   S U B R O U T I N E  -*-*-*-*-*-*-

      SUBROUTINE CCQP_workspace( m, n, dims, a_ne, h_ne, Hessian_kind,         &
                                lbfgs, stat_required, order, GRAD_L,           &
                                DIST_X_l, DIST_X_u, Z_l, Z_u, BARRIER_X,       &
                                Y_l, DIST_C_l, Y_u, DIST_C_u, C, BARRIER_C,    &
                                SCALE_C, RHS, OPT_alpha, OPT_merit,            &
                                BINOMIAL, CS_coef, COEF, ROOTS, DX_zh,         &
                                DY_zh, DC_zh, DY_l_zh, DY_u_zh, DZ_l_zh,       &
                                DZ_u_zh, X_coef, C_coef, Y_coef, Y_l_coef,     &
                                Y_u_coef, Z_l_coef, Z_u_coef, H_s, A_s,        &
                                Y_last, Z_last, A_sbls, H_sbls,                &
                                control, inform )

!  allocate workspace arrays for use in CCQP_solve_main

!  Dummy arguments

      INTEGER, INTENT( IN ) :: m, n, a_ne, h_ne, Hessian_kind
      INTEGER, INTENT( OUT ) :: order
      LOGICAL, INTENT( IN ) :: lbfgs, stat_required
      TYPE ( CCQP_dims_type ), INTENT( IN ) :: dims
      REAL ( KIND = wp ), ALLOCATABLE, INTENT( INOUT ), DIMENSION( : ) ::      &
           GRAD_L, DIST_X_l, DIST_X_u, Z_l, Z_u, BARRIER_X, Y_l, DIST_C_l,     &
           Y_u, DIST_C_u, C, BARRIER_C, SCALE_C, RHS, OPT_alpha, OPT_merit,    &
           CS_coef, COEF, ROOTS, DX_zh, DY_zh, DC_zh, DY_l_zh,                 &
           DY_u_zh, DZ_l_zh, DZ_u_zh, H_s, A_s, Y_last, Z_last
      REAL ( KIND = wp ), ALLOCATABLE, INTENT( INOUT ), DIMENSION( :, : ) ::   &
           X_coef, C_coef, Y_coef, Y_l_coef, Y_u_coef, Z_l_coef, Z_u_coef,     &
           BINOMIAL
      TYPE ( SMT_type ), INTENT( INOUT ) :: A_sbls, H_sbls
      TYPE ( CCQP_control_type ), INTENT( IN ) :: control
      TYPE ( CCQP_inform_type ), INTENT( INOUT ) :: inform

!  Local variables

      INTEGER :: A_sbls_ne, H_sbls_ne, n_sbls
      CHARACTER ( LEN = 80 ) :: array_name

!  allocate workspace arrays

      array_name = 'ccqp: GRAD_L'
      CALL SPACE_resize_array( dims%c_e, GRAD_L,                               &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DIST_X_l'
      CALL SPACE_resize_array( dims%x_l_start, dims%x_l_end, DIST_X_l,         &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DIST_X_u'
      CALL SPACE_resize_array( dims%x_u_start, dims%x_u_end, DIST_X_u,         &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Z_l'
      CALL SPACE_resize_array( dims%x_free + 1, dims%x_l_end, Z_l,             &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Z_u'
      CALL SPACE_resize_array( dims%x_u_start, n, Z_u,                         &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: BARRIER_X'
      CALL SPACE_resize_array( dims%x_free + 1, n, BARRIER_X,                  &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Y_l'
      CALL SPACE_resize_array( dims%c_l_start, dims%c_l_end, Y_l,              &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DIST_C_l'
      CALL SPACE_resize_array( dims%c_l_start, dims%c_l_end, DIST_C_l,         &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Y_u'
      CALL SPACE_resize_array( dims%c_u_start, dims%c_u_end, Y_u,              &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DIST_C_u'
      CALL SPACE_resize_array( dims%c_u_start, dims%c_u_end, DIST_C_u,         &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: C'
      CALL SPACE_resize_array( dims%c_l_start, dims%c_u_end, C,                &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: BARRIER_C'
      CALL SPACE_resize_array( dims%c_l_start, dims%c_u_end, BARRIER_C,        &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: SCALE_C'
      CALL SPACE_resize_array( dims%c_l_start, dims%c_u_end, SCALE_C,          &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: RHS'
      CALL SPACE_resize_array( dims%v_e, RHS,                                  &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      order = control%series_order

      array_name = 'ccqp: OPT_alpha'
      CALL SPACE_resize_array( order, OPT_alpha,                               &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: OPT_merit'
      CALL SPACE_resize_array( order, OPT_merit,                               &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: X_coef'
      CALL SPACE_resize_array( 1, n, 0, order, X_coef,                         &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: C_coef'
      CALL SPACE_resize_array( dims%c_l_start, dims%c_u_end, 0, order, C_coef, &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Y_coef'
      CALL SPACE_resize_array( 1, m, 0, order, Y_coef,                         &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Y_l_coef'
      CALL SPACE_resize_array(                                                 &
             dims%c_l_start, dims%c_l_end, 0, order, Y_l_coef,                 &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Y_u_coef'
      CALL SPACE_resize_array(                                                 &
             dims%c_u_start, dims%c_u_end, 0, order, Y_u_coef,                 &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Z_l_coef'
      CALL SPACE_resize_array(                                                 &
             dims%x_free + 1, dims%x_l_end, 0, order, Z_l_coef,                &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: Z_u_coef'
      CALL SPACE_resize_array(                                                 &
             dims%x_u_start, n, 0, order, Z_u_coef,                            &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: BINOMIAL'
      CALL SPACE_resize_array( 0, order - 1, order, BINOMIAL,                  &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: CS_coef'
      CALL SPACE_resize_array( 0, 2 * order, CS_coef,                          &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: COEF'
      CALL SPACE_resize_array( 0, 2 * order, COEF,                             &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: ROOTS'
      CALL SPACE_resize_array( 2 * order, ROOTS,                               &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DX_zh'
      CALL SPACE_resize_array( 1, n, DX_zh,                                    &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DC_zh'
      CALL SPACE_resize_array( dims%c_l_start, dims%c_u_end, DC_zh,            &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DY_zh'
      CALL SPACE_resize_array( 1, m, DY_zh,                                    &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DY_l_zh'
      CALL SPACE_resize_array( dims%c_l_start, dims%c_l_end, DY_l_zh,          &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DY_u_zh'
      CALL SPACE_resize_array( dims%c_u_start, dims%c_u_end, DY_u_zh,          &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DZ_l_zh'
      CALL SPACE_resize_array( dims%x_free + 1, dims%x_l_end, DZ_l_zh,         &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: DZ_u_zh'
      CALL SPACE_resize_array( dims%x_u_start, n, DZ_u_zh,                     &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

!  If H is not diagonal, it will be in coordinate form

      n_sbls = n + dims%nc
      IF ( Hessian_kind < 0 .AND. .NOT. lbfgs ) THEN
        H_sbls_ne = h_ne + n_sbls

!  allocate integer space for H

        array_name = 'ccqp: H_sbls%row'
        CALL SPACE_resize_array( H_sbls_ne, H_sbls%row,                        &
               inform%status, inform%alloc_status, array_name = array_name,    &
               deallocate_error_fatal = control%deallocate_error_fatal,        &
               exact_size = control%space_critical,                            &
               bad_alloc = inform%bad_alloc, out = control%error )
        IF ( inform%status /= GALAHAD_ok ) RETURN

        array_name = 'ccqp: H_sbls%col'
        CALL SPACE_resize_array( H_sbls_ne, H_sbls%col,                        &
               inform%status, inform%alloc_status, array_name = array_name,    &
               deallocate_error_fatal = control%deallocate_error_fatal,        &
               exact_size = control%space_critical,                            &
               bad_alloc = inform%bad_alloc, out = control%error )
        IF ( inform%status /= GALAHAD_ok ) RETURN

!  otherwise H will be in diagonal form

      ELSE
        H_sbls_ne = n_sbls
      END IF

!  allocate real space for H

      array_name = 'ccqp: H_sbls%val'
      CALL SPACE_resize_array( H_sbls_ne, H_sbls%val,                          &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN


!  allocate space for A

      A_sbls_ne = a_ne + dims%nc

      array_name = 'ccqp: A_sbls%row'
      CALL SPACE_resize_array( A_sbls_ne, A_sbls%row,                          &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: A_sbls%col'
      CALL SPACE_resize_array( A_sbls_ne, A_sbls%col,                          &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

      array_name = 'ccqp: A_sbls%val'
      CALL SPACE_resize_array( A_sbls_ne, A_sbls%val,                          &
             inform%status, inform%alloc_status, array_name = array_name,      &
             deallocate_error_fatal = control%deallocate_error_fatal,          &
             exact_size = control%space_critical,                              &
             bad_alloc = inform%bad_alloc, out = control%error )
      IF ( inform%status /= GALAHAD_ok ) RETURN

!  allocate optional extra arrays

      IF ( stat_required ) THEN
        array_name = 'ccqp: H_s'
        CALL SPACE_resize_array( n, H_s,                                       &
               inform%status, inform%alloc_status, array_name = array_name,    &
               deallocate_error_fatal = control%deallocate_error_fatal,        &
               exact_size = control%space_critical,                            &
               bad_alloc = inform%bad_alloc, out = control%error )
        IF ( inform%status /= GALAHAD_ok ) RETURN

        array_name = 'ccqp: A_s'
        CALL SPACE_resize_array( m, A_s,                                       &
               inform%status, inform%alloc_status, array_name = array_name,    &
               deallocate_error_fatal = control%deallocate_error_fatal,        &
               exact_size = control%space_critical,                            &
               bad_alloc = inform%bad_alloc, out = control%error )
        IF ( inform%status /= GALAHAD_ok ) RETURN

        array_name = 'ccqp: Y_last'
        CALL SPACE_resize_array( m, Y_last,                                    &
               inform%status, inform%alloc_status, array_name = array_name,    &
               deallocate_error_fatal = control%deallocate_error_fatal,        &
               exact_size = control%space_critical,                            &
               bad_alloc = inform%bad_alloc, out = control%error )
        IF ( inform%status /= GALAHAD_ok ) RETURN

        array_name = 'ccqp: Z_last'
        CALL SPACE_resize_array( n, Z_last,                                    &
               inform%status, inform%alloc_status, array_name = array_name,    &
               deallocate_error_fatal = control%deallocate_error_fatal,        &
               exact_size = control%space_critical,                            &
               bad_alloc = inform%bad_alloc, out = control%error )
        IF ( inform%status /= GALAHAD_ok ) RETURN
      END IF

      RETURN

!  End of subroutine CCQP_workspace

      END SUBROUTINE CCQP_workspace

! -----------------------------------------------------------------------------
! =============================================================================
! -----------------------------------------------------------------------------
!              specific interfaces to make calls from C easier
! -----------------------------------------------------------------------------
! =============================================================================
! -----------------------------------------------------------------------------

!-*-*-*-*-  G A L A H A D -  C C Q P _ i m p o r t _ S U B R O U T I N E -*-*-*-*-

     SUBROUTINE CCQP_import( control, data, status, n, m,                      &
                             H_type, H_ne, H_row, H_col, H_ptr,                &
                             A_type, A_ne, A_row, A_col, A_ptr )

!  import fixed problem data into internal storage prior to solution.
!  Arguments are as follows:

!  control is a derived type whose components are described in the leading
!   comments to CCQP_solve
!
!  data is a scalar variable of type CCQP_full_data_type used for internal data
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
!   -3. The restriction n > 0, m >= 0 or requirement that type contains
!       its relevant string 'DENSE', 'COORDINATE', 'SPARSE_BY_ROWS',
!       'DIAGONAL' 'SCALED_IDENTITY', 'IDENTITY', 'ZERO', 'NONE' or
!       'SHIFTED_LEAST_DISTANCE' has been violated.
!
!  n is a scalar variable of type default integer, that holds the number of
!   variables
!
!  m is a scalar variable of type default integer, that holds the number of
!   residuals
!
!  H_type is a character string that specifies the Hessian storage scheme
!   used. It should be one of 'coordinate', 'sparse_by_rows', 'dense'
!   'diagonal' 'scaled_identity', 'identity', 'zero', 'none' or
!   'shifted_least_distance', the latter if the Hessian is that of
!   1/2 sum_j w_j (x_j-x^0_j)^2 rather than of 1/2 x' H x
!   Lower or upper case variants are allowed.
!
!  H_ne is a scalar variable of type default integer, that holds the number of
!   entries in the  lower triangular part of H in the sparse co-ordinate
!   storage scheme. It need not be set for any of the other schemes.
!
!  H_row is a rank-one array of type default integer, that holds
!   the row indices of the  lower triangular part of H in the sparse
!   co-ordinate storage scheme. It need not be set for any of the other
!   three schemes, and in this case can be of length 0
!
!  H_col is a rank-one array of type default integer,
!   that holds the column indices of the  lower triangular part of H in either
!   the sparse co-ordinate, or the sparse row-wise storage scheme. It need not
!   be set when the dense, diagonal, scaled identity, identity or zero schemes
!   are used, and in this case can be of length 0
!
!  H_ptr is a rank-one array of dimension n+1 and type default
!   integer, that holds the starting position of  each row of the  lower
!   triangular part of H, as well as the total number of entries plus one,
!   in the sparse row-wise storage scheme. It need not be set when the
!   other schemes are used, and in this case can be of length 0
!
!  A_type is a character string that specifies the Jacobian storage scheme
!   used. It should be one of 'coordinate', 'sparse_by_rows', 'dense'
!   or 'absent', the latter if m = 0; lower or upper case variants are allowed
!
!  A_ne is a scalar variable of type default integer, that holds the number of
!   entries in J in the sparse co-ordinate storage scheme. It need not be set
!  for any of the other schemes.
!
!  A_row is a rank-one array of type default integer, that holds the row
!   indices J in the sparse co-ordinate storage scheme. It need not be set
!   for any of the other schemes, and in this case can be of length 0
!
!  A_col is a rank-one array of type default integer, that holds the column
!   indices of J in either the sparse co-ordinate, or the sparse row-wise
!   storage scheme. It need not be set when the dense scheme is used, and
!   in this case can be of length 0
!
!  A_ptr is a rank-one array of dimension n+1 and type default integer,
!   that holds the starting position of each row of J, as well as the total
!   number of entries plus one, in the sparse row-wise storage scheme.
!   It need not be set when the other schemes are used, and in this case
!   can be of length 0
!
!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( CCQP_control_type ), INTENT( INOUT ) :: control
     TYPE ( CCQP_full_data_type ), INTENT( INOUT ) :: data
     INTEGER, INTENT( IN ) :: n, m, A_ne, H_ne
     INTEGER, INTENT( OUT ) :: status
     CHARACTER ( LEN = * ), INTENT( IN ) :: H_type
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: H_row
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: H_col
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: H_ptr
     CHARACTER ( LEN = * ), INTENT( IN ) :: A_type
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: A_row
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: A_col
     INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: A_ptr

!  local variables

     INTEGER :: error
     LOGICAL :: deallocate_error_fatal, space_critical
     CHARACTER ( LEN = 80 ) :: array_name

!  copy control to data

     WRITE( control%out, "( '' )", ADVANCE = 'no') ! prevents ifort bug
     data%ccqp_control = control

     error = data%ccqp_control%error
     space_critical = data%ccqp_control%space_critical
     deallocate_error_fatal = data%ccqp_control%space_critical

!  allocate vector space if required

     array_name = 'ccqp: data%prob%X'
     CALL SPACE_resize_array( n, data%prob%X,                                  &
            data%ccqp_inform%status, data%ccqp_inform%alloc_status,            &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%ccqp_inform%bad_alloc, out = error )
     IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     array_name = 'ccqp: data%prob%X_l'
     CALL SPACE_resize_array( n, data%prob%X_l,                                &
            data%ccqp_inform%status, data%ccqp_inform%alloc_status,            &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%ccqp_inform%bad_alloc, out = error )
     IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     array_name = 'ccqp: data%prob%X_u'
     CALL SPACE_resize_array( n, data%prob%X_u,                                &
            data%ccqp_inform%status, data%ccqp_inform%alloc_status,            &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%ccqp_inform%bad_alloc, out = error )
     IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     array_name = 'ccqp: data%prob%Z'
     CALL SPACE_resize_array( n, data%prob%Z,                                  &
            data%ccqp_inform%status, data%ccqp_inform%alloc_status,            &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%ccqp_inform%bad_alloc, out = error )
     IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     array_name = 'ccqp: data%prob%C'
     CALL SPACE_resize_array( m, data%prob%C,                                  &
            data%ccqp_inform%status, data%ccqp_inform%alloc_status,            &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%ccqp_inform%bad_alloc, out = error )
     IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     array_name = 'ccqp: data%prob%C_l'
     CALL SPACE_resize_array( m, data%prob%C_l,                                &
            data%ccqp_inform%status, data%ccqp_inform%alloc_status,            &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%ccqp_inform%bad_alloc, out = error )
     IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     array_name = 'ccqp: data%prob%C_u'
     CALL SPACE_resize_array( m, data%prob%C_u,                                &
            data%ccqp_inform%status, data%ccqp_inform%alloc_status,            &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%ccqp_inform%bad_alloc, out = error )
     IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     array_name = 'ccqp: data%prob%Y'
     CALL SPACE_resize_array( m, data%prob%Y,                                  &
            data%ccqp_inform%status, data%ccqp_inform%alloc_status,            &
            array_name = array_name,                                           &
            deallocate_error_fatal = deallocate_error_fatal,                   &
            exact_size = space_critical,                                       &
            bad_alloc = data%ccqp_inform%bad_alloc, out = error )
     IF ( data%ccqp_inform%status /= 0 ) GO TO 900

!  put data into the required components of the qpt storage type

     data%prob%n = n ; data%prob%m = m

!  set H appropriately in the qpt storage type

     SELECT CASE ( H_type )
     CASE ( 'coordinate', 'COORDINATE' )
       IF ( .NOT. ( PRESENT( H_row ) .AND. PRESENT( H_col ) ) ) THEN
         data%ccqp_inform%status = GALAHAD_error_optional
         GO TO 900
       END IF
       CALL SMT_put( data%prob%H%type, 'COORDINATE',                           &
                     data%ccqp_inform%alloc_status )
       data%prob%H%n = n
       data%prob%H%ne = H_ne
       data%prob%Hessian_kind = - 1

       array_name = 'ccqp: data%prob%H%row'
       CALL SPACE_resize_array( data%prob%H%ne, data%prob%H%row,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       array_name = 'ccqp: data%prob%H%col'
       CALL SPACE_resize_array( data%prob%H%ne, data%prob%H%col,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       array_name = 'ccqp: data%prob%H%val'
       CALL SPACE_resize_array( data%prob%H%ne, data%prob%H%val,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       data%prob%H%row( : data%prob%H%ne ) = H_row( : data%prob%H%ne )
       data%prob%H%col( : data%prob%H%ne ) = H_col( : data%prob%H%ne )

     CASE ( 'sparse_by_rows', 'SPARSE_BY_ROWS' )
       IF ( .NOT. ( PRESENT( H_ptr ) .AND. PRESENT( H_col ) ) ) THEN
         data%ccqp_inform%status = GALAHAD_error_optional
         GO TO 900
       END IF
       CALL SMT_put( data%prob%H%type, 'SPARSE_BY_ROWS',                       &
                     data%ccqp_inform%alloc_status )
       data%prob%H%n = n
       data%prob%H%ne = H_ptr( n + 1 ) - 1
       data%prob%Hessian_kind = - 1

       array_name = 'ccqp: data%prob%H%ptr'
       CALL SPACE_resize_array( n + 1, data%prob%H%ptr,                        &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       array_name = 'ccqp: data%prob%H%col'
       CALL SPACE_resize_array( data%prob%H%ne, data%prob%H%col,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       array_name = 'ccqp: data%prob%H%val'
       CALL SPACE_resize_array( data%prob%H%ne, data%prob%H%val,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       data%prob%H%ptr( : n + 1 ) = H_ptr( : n + 1 )
       data%prob%H%col( : data%prob%H%ne ) = H_col( : data%prob%H%ne )

     CASE ( 'dense', 'DENSE' )
       CALL SMT_put( data%prob%H%type, 'DENSE',                                &
                     data%ccqp_inform%alloc_status )
       data%prob%H%n = n
       data%prob%H%ne = ( n * ( n + 1 ) ) / 2
       data%prob%Hessian_kind = - 1

       array_name = 'ccqp: data%prob%H%val'
       CALL SPACE_resize_array( data%prob%H%ne, data%prob%H%val,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     CASE ( 'diagonal', 'DIAGONAL' )
       CALL SMT_put( data%prob%H%type, 'DIAGONAL',                             &
                     data%ccqp_inform%alloc_status )
       data%prob%H%n = n
       data%prob%H%ne = n
       data%prob%Hessian_kind = - 1

       array_name = 'ccqp: data%prob%H%val'
       CALL SPACE_resize_array( data%prob%H%ne, data%prob%H%val,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     CASE ( 'scaled_identity', 'SCALED_IDENTITY' )
       CALL SMT_put( data%prob%H%type, 'SCALED_IDENTITY',                      &
                     data%ccqp_inform%alloc_status )
       data%prob%H%n = n
       data%prob%H%ne = 1
       data%prob%Hessian_kind = - 1

       array_name = 'ccqp: data%prob%H%val'
       CALL SPACE_resize_array( data%prob%H%ne, data%prob%H%val,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     CASE ( 'identity', 'IDENTITY' )
       CALL SMT_put( data%prob%H%type, 'IDENTITY',                             &
                     data%ccqp_inform%alloc_status )
       data%prob%H%n = n
       data%prob%H%ne = 0
       data%prob%Hessian_kind = - 1

     CASE ( 'zero', 'ZERO', 'none', 'NONE' )
       CALL SMT_put( data%prob%H%type, 'ZERO',                                 &
                     data%ccqp_inform%alloc_status )
       data%prob%H%n = n
       data%prob%H%ne = 0
       data%prob%Hessian_kind = 0
     CASE ( 'shifted_least_distance', 'SHIFTED_LEAST_DISTANCE' )
       data%prob%Hessian_kind = 2
     CASE DEFAULT
       data%ccqp_inform%status = GALAHAD_error_unknown_storage
       GO TO 900
     END SELECT

!  set A appropriately in the qpt storage type

     SELECT CASE ( A_type )
     CASE ( 'coordinate', 'COORDINATE' )
       IF ( .NOT. ( PRESENT( A_row ) .AND. PRESENT( A_col ) ) ) THEN
         data%ccqp_inform%status = GALAHAD_error_optional
         GO TO 900
       END IF
       CALL SMT_put( data%prob%A%type, 'COORDINATE',                           &
                     data%ccqp_inform%alloc_status )
       data%prob%A%n = n ; data%prob%A%m = m
       data%prob%A%ne = A_ne

       array_name = 'ccqp: data%prob%A%row'
       CALL SPACE_resize_array( data%prob%A%ne, data%prob%A%row,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       array_name = 'ccqp: data%prob%A%col'
       CALL SPACE_resize_array( data%prob%A%ne, data%prob%A%col,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       array_name = 'ccqp: data%prob%A%val'
       CALL SPACE_resize_array( data%prob%A%ne, data%prob%A%val,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       data%prob%A%row( : data%prob%A%ne ) = A_row( : data%prob%A%ne )
       data%prob%A%col( : data%prob%A%ne ) = A_col( : data%prob%A%ne )

     CASE ( 'sparse_by_rows', 'SPARSE_BY_ROWS' )
       IF ( .NOT. ( PRESENT( A_ptr ) .AND. PRESENT( A_col ) ) ) THEN
         data%ccqp_inform%status = GALAHAD_error_optional
         GO TO 900
       END IF
       CALL SMT_put( data%prob%A%type, 'SPARSE_BY_ROWS',                       &
                     data%ccqp_inform%alloc_status )
       data%prob%A%n = n ; data%prob%A%m = m
       data%prob%A%ne = A_ptr( m + 1 ) - 1
       array_name = 'ccqp: data%prob%A%ptr'
       CALL SPACE_resize_array( m + 1, data%prob%A%ptr,                        &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       array_name = 'ccqp: data%prob%A%col'
       CALL SPACE_resize_array( data%prob%A%ne, data%prob%A%col,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       array_name = 'ccqp: data%prob%A%val'
       CALL SPACE_resize_array( data%prob%A%ne, data%prob%A%val,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

       data%prob%A%ptr( : m + 1 ) = A_ptr( : m + 1 )
       data%prob%A%col( : data%prob%A%ne ) = A_col( : data%prob%A%ne )

     CASE ( 'dense', 'DENSE' )
       CALL SMT_put( data%prob%A%type, 'DENSE',                                &
                     data%ccqp_inform%alloc_status )
       data%prob%A%n = n ; data%prob%A%m = m
       data%prob%A%ne = m * n

       array_name = 'ccqp: data%prob%A%val'
       CALL SPACE_resize_array( data%prob%A%ne, data%prob%A%val,               &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal = deallocate_error_fatal,                 &
              exact_size = space_critical,                                     &
              bad_alloc = data%ccqp_inform%bad_alloc, out = error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900

     CASE DEFAULT
       data%ccqp_inform%status = GALAHAD_error_unknown_storage
       GO TO 900
     END SELECT

     status = GALAHAD_ok
     RETURN

!  error returns

 900 CONTINUE
     status = data%ccqp_inform%status
     RETURN

!  End of subroutine CCQP_import

     END SUBROUTINE CCQP_import

!-  G A L A H A D -  C C Q P _ r e s e t _ c o n t r o l   S U B R O U T I N E  -

     SUBROUTINE CCQP_reset_control( control, data, status )

!  reset control parameters after import if required.
!  See CCQP_solve for a description of the required arguments

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( CCQP_control_type ), INTENT( IN ) :: control
     TYPE ( CCQP_full_data_type ), INTENT( INOUT ) :: data
     INTEGER, INTENT( OUT ) :: status

!  set control in internal data

     data%ccqp_control = control

!  flag a successful call

     status = GALAHAD_ok
     RETURN

!  end of subroutine CCQP_reset_control

     END SUBROUTINE CCQP_reset_control

!-*-*-*-  G A L A H A D -  C C Q P _ s o l v e _ q p  S U B R O U T I N E  -*-*-*-

     SUBROUTINE CCQP_solve_qp( data, status, H_val, G, f, A_val, C_l, C_u,     &
                               X_l, X_u, X, C, Y, Z, X_stat, C_stat )

!  solve the quadratic programming problem whose structure was previously
!  imported. See CCQP_solve for a description of the required arguments.

!--------------------------------
!   D u m m y   A r g u m e n t s
!--------------------------------

!  data is a scalar variable of type CCQP_full_data_type used for internal data
!
!  status is a scalar variable of type default intege that indicates the
!   success or otherwise of the import. If status = 0, the solve was succesful.
!   For other values see, ccqp_solve above.
!
!  H_val is a rank-one array of type default real, that holds the values
!   of the  lower triangular part of the Hessian H in the storage scheme 
!   specified in ccqp_import.
!
!  G is a rank-one array of dimension n and type default
!   real, that holds the vector of linear terms of the objective, g.
!   The j-th component of G, j = 1, ... , n, contains (g)_j.
!
!  f is a scalar of type default real, that holds the constant term, f,
!   of the objective.
!
!  A_val is a rank-one array of type default real, that holds the values
!   of the Jacobian A in the storage scheme specified in ccqp_import.
!
!  C_l, C_u are rank-one arrays of dimension m, that hold the values of
!   the lower and upper bounds, c_l and c_u, on the general linear constraints.
!   Any bound c_l(i) or c_u(i) larger than or equal to control%infinity in
!   absolute value will be regarded as being infinite (see the entry
!   control%infinity). Thus, an infinite lower bound may be specified by
!   setting the appropriate component of C_l to a value smaller than
!   -control%infinity, while an infinite upper bound can be specified by
!   setting the appropriate element of C_u to a value larger than
!   control%infinity.
!
!  X_l, X_u are rank-one arrays of dimension n, that hold the values of
!   the lower and upper bounds, c_l and c_u, on the variables x.
!   Any bound x_l(i) or x_u(i) larger than or equal to control%infinity in
!   absolute value will be regarded as being infinite (see the entry
!   control%infinity). Thus, an infinite lower bound may be specified by
!   setting the appropriate component of X_l to a value smaller than
!   -control%infinity, while an infinite upper bound can be specified by
!   setting the appropriate element of X_u to a value larger than
!   control%infinity. 
!
!  X is a rank-one array of dimension n and type default
!   real, that holds the vector of the primal variables, x.
!   The j-th component of X, j = 1, ... , n, contains (x)_j.
!
!  Y is a rank-one array of dimension m and type default
!   real, that holds the vector of the Lagrange multipliers, y.
!   The i-th component of Y, i = 1, ... , m, contains (y)_i.
!
!  Z is a rank-one array of dimension n and type default
!   real, that holds the vector of the dual variables, z.
!   The j-th component of Z, j = 1, ... , n, contains (z)_j.
!
!  X_stat is a rank-one array of dimension n and type default integer, 
!   that may be set by the user on entry to indicate which of the variables
!   are to be included in the initial working set. If this facility is 
!   required, the component control%cold_start must be set to 0 on entry; 
!   X_stat need not be set if control%cold_start is nonzero. On exit,
!   X_stat will indicate which constraints are in the final working set.
!   Possible entry/exit values are
!   X_stat( i ) < 0, the i-th bound constraint is in the working set,
!                    on its lower bound,
!               > 0, the i-th bound constraint is in the working set
!                    on its upper bound, and
!               = 0, the i-th bound constraint is not in the working set
!
!  C_stat is a rank-one array of dimension m and type default integer, 
!   that may be set by the user on entry to indicate which of the constraints 
!   are to be included in the initial working set. If this facility is 
!   required, the component control%cold_start must be set to 0 on entry; 
!   C_stat need not be set if control%cold_start is nonzero. On exit,
!   C_stat will indicate which constraints are in the final working set.
!   Possible entry/exit values are
!   C_stat( i ) < 0, the i-th constraint is in the working set,
!                    on its lower bound,
!               > 0, the i-th constraint is in the working set
!                    on its upper bound, and
!               = 0, the i-th constraint is not in the working set

     INTEGER, INTENT( OUT ) :: status
     TYPE ( CCQP_full_data_type ), INTENT( INOUT ) :: data
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: H_val
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: G
     REAL ( KIND = wp ), INTENT( IN ) :: f
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: A_val
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: C_l, C_u
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: X_l, X_u
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: X, Y, Z
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: C
     INTEGER, INTENT( OUT ), OPTIONAL, DIMENSION( : ) :: C_stat, X_stat

!  local variables

     INTEGER :: m, n
     CHARACTER ( LEN = 80 ) :: array_name

!  recover the dimensions

     m = data%prob%m ; n = data%prob%n

!  save the constant term of the objective function

     data%prob%f = f

!  save the linear term of the objective function

     IF ( COUNT( G( : n ) == 0.0_wp ) == n ) THEN
       data%prob%gradient_kind = 0
     ELSE IF ( COUNT( G( : n ) == 1.0_wp ) == n ) THEN
       data%prob%gradient_kind = 1
     ELSE
       data%prob%gradient_kind = 2
       array_name = 'ccqp: data%prob%G'
       CALL SPACE_resize_array( n, data%prob%G,                                &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal =                                         &
                data%ccqp_control%deallocate_error_fatal,                      &
              exact_size = data%ccqp_control%space_critical,                   &
              bad_alloc = data%ccqp_inform%bad_alloc,                          &
              out = data%ccqp_control%error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900
       data%prob%G( : n ) = G( : n )
     END IF

!  save the lower and upper simple bounds

     data%prob%X_l( : n ) = X_l( : n )
     data%prob%X_u( : n ) = X_u( : n )

!  save the lower and upper constraint bounds

     data%prob%C_l( : m ) = C_l( : m )
     data%prob%C_u( : m ) = C_u( : m )

!  save the initial primal and dual variables and Lagrange multipliers

     data%prob%X( : n ) = X( : n )
     data%prob%Z( : n ) = Z( : n )
     data%prob%Y( : m ) = Y( : m )

!  save the Hessian entries

     IF ( data%prob%Hessian_kind /= 2 ) THEN
       IF ( data%prob%H%ne > 0 )                                               &
         data%prob%H%val( : data%prob%H%ne ) = H_val( : data%prob%H%ne )
     ELSE
       data%ccqp_inform%status = GALAHAD_error_hessian_type
       GO TO 900
     END IF

!  save the constraint Jacobian entries

     IF ( data%prob%A%ne > 0 )                                                 &
       data%prob%A%val( : data%prob%A%ne ) = A_val( : data%prob%A%ne )

!  call the solver

     CALL CCQP_solve( data%prob, data%ccqp_data, data%ccqp_control,            &
                      data%ccqp_inform, C_stat = C_stat, B_stat = X_stat )

!  recover the optimal primal and dual variables, Lagrange multipliers and
!  constraint values

     X( : n ) = data%prob%X( : n )
     Z( : n ) = data%prob%Z( : n )
     Y( : m ) = data%prob%Y( : m )
     C( : m ) = data%prob%C( : m )

     status = data%ccqp_inform%status
     RETURN

!  error returns

 900 CONTINUE
     status = data%ccqp_inform%status
     RETURN

!  End of subroutine CCQP_solve_qp

     END SUBROUTINE CCQP_solve_qp

!-*-  G A L A H A D -  C C Q P _ s o l v e _ s l d q p  S U B R O U T I N E  -*-

     SUBROUTINE CCQP_solve_sldqp( data, status, W, X0, G, f, A_val, C_l, C_u,  &
                                  X_l, X_u, X, C, Y, Z, X_stat, C_stat )

!  solve the shifted-least-distance problem whose structure was previously
!  imported. See CCQP_solve for a description of the required arguments.

!--------------------------------
!   D u m m y   A r g u m e n t s
!--------------------------------

!  data is a scalar variable of type CCQP_full_data_type used for internal data
!
!  status is a scalar variable of type default intege that indicates the
!   success or otherwise of the import. If status = 0, the solve was succesful.
!   For other values see, ccqp_solve above.
!
!  W is a rank-one array of dimension n and type default
!   real, that holds the vector of weights, w, in the objective function.
!   The j-th component of W, j = 1, ... , n, contains (W)_j.
!
!  X0 is a rank-one array of dimension n and type default
!   real, that holds the vector of shifts, x_0, in the objective function
!   The j-th component of X0, j = 1, ... , n, contains (x_0)_j.
!
!  G is a rank-one array of dimension n and type default
!   real, that holds the vector of linear terms of the objective, g.
!   The j-th component of G, j = 1, ... , n, contains (g)_j.
!
!  f is a scalar of type default real, that holds the constant term, f,
!   of the objective.
!
!  A_val is a rank-one array of type default real, that holds the values
!   of the Jacobian A in the storage scheme specified in ccqp_import.
!
!  C_l, C_u are rank-one arrays of dimension m, that hold the values of
!   the lower and upper bounds, c_l and c_u, on the general linear constraints.
!   Any bound c_l(i) or c_u(i) larger than or equal to control%infinity in
!   absolute value will be regarded as being infinite (see the entry
!   control%infinity). Thus, an infinite lower bound may be specified by
!   setting the appropriate component of C_l to a value smaller than
!   -control%infinity, while an infinite upper bound can be specified by
!   setting the appropriate element of C_u to a value larger than
!   control%infinity.
!
!  X_l, X_u are rank-one arrays of dimension n, that hold the values of
!   the lower and upper bounds, x_l and x_u, on the variables x.
!   Any bound x_l(i) or x_u(i) larger than or equal to control%infinity in
!   absolute value will be regarded as being infinite (see the entry
!   control%infinity). Thus, an infinite lower bound may be specified by
!   setting the appropriate component of X_l to a value smaller than
!   -control%infinity, while an infinite upper bound can be specified by
!   setting the appropriate element of X_u to a value larger than
!   control%infinity. 
!
!  X is a rank-one array of dimension n and type default
!   real, that holds the vector of the primal variables, x.
!   The j-th component of X, j = 1, ... , n, contains (x)_j.
!
!  Y is a rank-one array of dimension m and type default
!   real, that holds the vector of the Lagrange multipliers, y.
!   The i-th component of Y, i = 1, ... , m, contains (y)_i.
!
!  Z is a rank-one array of dimension n and type default
!   real, that holds the vector of the dual variables, z.
!   The j-th component of Z, j = 1, ... , n, contains (z)_j.
!
!  X_stat is a rank-one array of dimension n and type default integer, 
!   that may be set by the user on entry to indicate which of the variables
!   are to be included in the initial working set. If this facility is 
!   required, the component control%cold_start must be set to 0 on entry; 
!   X_stat need not be set if control%cold_start is nonzero. On exit,
!   X_stat will indicate which constraints are in the final working set.
!   Possible entry/exit values are
!   X_stat( i ) < 0, the i-th bound constraint is in the working set,
!                    on its lower bound,
!               > 0, the i-th bound constraint is in the working set
!                    on its upper bound, and
!               = 0, the i-th bound constraint is not in the working set
!
!  C_stat is a rank-one array of dimension m and type default integer, 
!   that may be set by the user on entry to indicate which of the constraints 
!   are to be included in the initial working set. If this facility is 
!   required, the component control%cold_start must be set to 0 on entry; 
!   C_stat need not be set if control%cold_start is nonzero. On exit,
!   C_stat will indicate which constraints are in the final working set.
!   Possible entry/exit values are
!   C_stat( i ) < 0, the i-th constraint is in the working set,
!                    on its lower bound,
!               > 0, the i-th constraint is in the working set
!                    on its upper bound, and
!               = 0, the i-th constraint is not in the working set

     INTEGER, INTENT( OUT ) :: status
     TYPE ( CCQP_full_data_type ), INTENT( INOUT ) :: data
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: W, X0
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: G
     REAL ( KIND = wp ), INTENT( IN ) :: f
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: A_val
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: C_l, C_u
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: X_l, X_u
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: X, Y, Z
     REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: C
     INTEGER, INTENT( OUT ), OPTIONAL, DIMENSION( : ) :: C_stat, X_stat

!  local variables

     INTEGER :: m, n
     CHARACTER ( LEN = 80 ) :: array_name

!  recover the dimensions

     m = data%prob%m ; n = data%prob%n

!  save the constant term of the objective function

     data%prob%f = f

!  save the linear term of the objective function

     IF ( COUNT( G( : n ) == 0.0_wp ) == n ) THEN
       data%prob%gradient_kind = 0
     ELSE IF ( COUNT( G( : n ) == 1.0_wp ) == n ) THEN
       data%prob%gradient_kind = 1
     ELSE
       data%prob%gradient_kind = 2
       array_name = 'ccqp: data%prob%G'
       CALL SPACE_resize_array( n, data%prob%G,                                &
              data%ccqp_inform%status, data%ccqp_inform%alloc_status,          &
              array_name = array_name,                                         &
              deallocate_error_fatal =                                         &
                data%ccqp_control%deallocate_error_fatal,                      &
              exact_size = data%ccqp_control%space_critical,                   &
              bad_alloc = data%ccqp_inform%bad_alloc,                          &
              out = data%ccqp_control%error )
       IF ( data%ccqp_inform%status /= 0 ) GO TO 900
       data%prob%G( : n ) = G( : n )
     END IF

!  save the lower and upper simple bounds

     data%prob%X_l( : n ) = X_l( : n )
     data%prob%X_u( : n ) = X_u( : n )

!  save the lower and upper constraint bounds

     data%prob%C_l( : m ) = C_l( : m )
     data%prob%C_u( : m ) = C_u( : m )

!  save the initial primal and dual variables and Lagrange multipliers

     data%prob%X( : n ) = X( : n )
     data%prob%Z( : n ) = Z( : n )
     data%prob%Y( : m ) = Y( : m )

!  save the Hessian entries

     IF ( data%prob%Hessian_kind == 2 ) THEN
       IF ( COUNT( W( : n ) == 0.0_wp ) == n ) THEN
         data%prob%Hessian_kind = 0
       ELSE IF ( COUNT( W( : n ) == 1.0_wp ) == n ) THEN
         data%prob%Hessian_kind = 1
       ELSE
         array_name = 'ccqp: data%prob%WEIGHT'
         CALL SPACE_resize_array( n, data%prob%WEIGHT,                         &
                data%ccqp_inform%status, data%ccqp_inform%alloc_status,        &
                array_name = array_name,                                       &
                deallocate_error_fatal =                                       &
                  data%ccqp_control%deallocate_error_fatal,                    &
                exact_size = data%ccqp_control%space_critical,                 &
                bad_alloc = data%ccqp_inform%bad_alloc,                        &
                out = data%ccqp_control%error )
         IF ( data%ccqp_inform%status /= 0 ) GO TO 900
         data%prob%WEIGHT( : n ) = W( : n )
       END IF

       IF ( COUNT( X0( : n ) == 0.0_wp ) == n ) THEN
         data%prob%target_kind = 0
       ELSE IF ( COUNT( X0( : n ) == 1.0_wp ) == n ) THEN
         data%prob%target_kind = 1
       ELSE
         data%prob%target_kind = 2
         array_name = 'ccqp: data%prob%X0'
         CALL SPACE_resize_array( n, data%prob%X0,                             &
                data%ccqp_inform%status, data%ccqp_inform%alloc_status,        &
                array_name = array_name,                                       &
                deallocate_error_fatal =                                       &
                  data%ccqp_control%deallocate_error_fatal,                    &
                exact_size = data%ccqp_control%space_critical,                 &
                bad_alloc = data%ccqp_inform%bad_alloc,                        &
                out = data%ccqp_control%error )
         IF ( data%ccqp_inform%status /= 0 ) GO TO 900
         data%prob%X0( : n ) = X0( : n )
       END IF
     ELSE
       data%ccqp_inform%status = GALAHAD_error_hessian_type
       GO TO 900
     END IF

!  save the constraint Jacobian entries

     data%prob%A%val( : data%prob%A%ne ) = A_val( : data%prob%A%ne )

!  call the solver

     CALL CCQP_solve( data%prob, data%ccqp_data, data%ccqp_control,            &
                      data%ccqp_inform, C_stat = C_stat, B_stat = X_stat )

!  recover the optimal primal and dual variables, Lagrange multipliers and
!  constraint values

     X( : n ) = data%prob%X( : n )
     Z( : n ) = data%prob%Z( : n )
     Y( : m ) = data%prob%Y( : m )
     C( : m ) = data%prob%C( : m )

     status = data%ccqp_inform%status
     RETURN

!  error returns

 900 CONTINUE
     status = data%ccqp_inform%status
     RETURN

!  End of subroutine CCQP_solve_sldqp

     END SUBROUTINE CCQP_solve_sldqp

!-  G A L A H A D -  C C Q P _ i n f o r m a t i o n   S U B R O U T I N E  -

     SUBROUTINE CCQP_information( data, inform, status )

!  return solver information during or after solution by CCQP
!  See CCQP_solve for a description of the required arguments

!-----------------------------------------------
!   D u m m y   A r g u m e n t s
!-----------------------------------------------

     TYPE ( CCQP_full_data_type ), INTENT( INOUT ) :: data
     TYPE ( CCQP_inform_type ), INTENT( OUT ) :: inform
     INTEGER, INTENT( OUT ) :: status

!  recover inform from internal data

     inform = data%ccqp_inform

!  flag a successful call

     status = GALAHAD_ok
     RETURN

!  end of subroutine CCQP_information

     END SUBROUTINE CCQP_information

!  End of module CCQP

    END MODULE GALAHAD_CCQP_double
