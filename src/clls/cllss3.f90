! THIS VERSION: GALAHAD 4.2 - 2023-10-23 AT 11:30 GMT.
   PROGRAM GALAHAD_CLLS_EXAMPLE3
   USE GALAHAD_CLLS_double         ! double precision version
   IMPLICIT NONE
   INTEGER, PARAMETER :: wp = KIND( 1.0D+0 ) ! set precision
   REAL ( KIND = wp ), PARAMETER :: infinity = 10.0_wp ** 20
   TYPE ( QPT_problem_type ) :: p
   TYPE ( CLLS_data_type ) :: data
   TYPE ( CLLS_control_type ) :: control
   TYPE ( CLLS_inform_type ) :: inform
   INTEGER :: s
   INTEGER, PARAMETER :: n = 3, o = 4, m = 2, ao_ne = 7, a_ne = 4
   REAL ( KIND = wp ), DIMENSION( o ) :: W
! start problem data
   ALLOCATE( p%B( o ), p%R( o ) )
   ALLOCATE( p%X_l( n ), p%X_u( n ) )
   ALLOCATE( p%C( m ), p%C_l( m ), p%C_u( m ) )
   ALLOCATE( p%X( n ), p%Y( m ), p%Z( n ) )
   ALLOCATE( p%C_status( m ), p%X_status( n ) )
   p%new_problem_structure = .TRUE.           ! new structure
   p%n = n ; p%o = o ; p%m = m ;              ! dimensions
   p%B = (/ 2.0_wp, 2.0_wp, 3.0_wp, 1.0_wp /) ! observations
   p%C_l = (/ 1.0_wp, 2.0_wp /)               ! constraint lower bound
   p%C_u = (/ 2.0_wp, 2.0_wp /)               ! constraint upper bound
   p%X_l = (/ - 1.0_wp, - infinity, - infinity /) ! variable lower bound
   p%X_u = (/ 1.0_wp, infinity, 2.0_wp /)     ! variable upper bound
   p%X = 0.0_wp ; p%Y = 0.0_wp ; p%Z = 0.0_wp ! start from zero
   W = (/ 1.0_wp, 1.0_wp, 1.0_wp, 1.0_wp /)   ! weights
!  dense storage format
   CALL SMT_put( p%Ao%type, 'DENSE', s ) ! Specify dense
   CALL SMT_put( p%A%type, 'DENSE', s )  ! storage for Ao and A
   ALLOCATE( p%Ao%val( o * n ) )
   ALLOCATE( p%A%val( m * n ) )
   p%Ao%val = (/ 1.0_wp, 1.0_wp, 0.0_wp, 0.0_wp, 1.0_wp, 1.0_wp,               &
                 1.0_wp, 0.0_wp, 1.0_wp, 0.0_wp, 1.0_wp, 0.0_wp  /) ! Ao
   p%A%val = (/ 2.0_wp, 1.0_wp, 0.0_wp, 0.0_wp, 1.0_wp, 1.0_wp /) ! A
! problem data complete
   CALL CLLS_initialize( data, control, inform ) ! Initialize control parameters
!  control%print_level = 1
   control%infinity = infinity                        ! Set infinity
   CALL CLLS_solve( p, data, control, inform, W = W ) ! Solve
   IF ( inform%status == 0 ) THEN                     !  Successful return
     WRITE( 6, "( ' CLLS: ', I0, ' iterations  ', /,                           &
    &     ' Optimal objective value =',                                        &
    &       ES12.4, /, ' Optimal solution = ', ( 5ES12.4 ) )" )                &
     inform%iter, inform%obj, p%X
   ELSE                                         !  Error returns
     WRITE( 6, "( ' CLLS_solve exit status = ', I6 ) " ) inform%status
   END IF
   CALL CLLS_terminate( data, control, inform )  !  delete internal workspace
   END PROGRAM GALAHAD_CLLS_EXAMPLE3
