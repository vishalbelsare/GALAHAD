! THIS VERSION: GALAHAD 3.3 - 11/12/2020 AT 15:50 GMT.
   PROGRAM GALAHAD_BLLS_TEST_PROGRAM
   USE GALAHAD_BLLS_double         ! double precision version
   USE GALAHAD_SYMBOLS
   IMPLICIT NONE
   INTEGER, PARAMETER :: wp = KIND( 1.0D+0 ) ! set precision
   REAL ( KIND = wp ), PARAMETER :: infinity = 10.0_wp ** 20
   TYPE ( QPT_problem_type ) :: p
   TYPE ( BLLS_data_type ) :: data
   TYPE ( BLLS_control_type ) :: control
   TYPE ( BLLS_inform_type ) :: inform
   TYPE ( BLLS_reverse_type ) :: reverse
   TYPE ( NLPT_userdata_type ) :: userdata
   INTEGER, ALLOCATABLE, DIMENSION( : ) :: X_stat
   INTEGER :: i, j, k, l, nf, mode, s, status
   REAL ( KIND = wp ) :: val
   INTEGER, ALLOCATABLE, DIMENSION( : ) :: A_row, A_col, A_ptr, A_ptr_row, FLAG
   REAL ( KIND = wp ), ALLOCATABLE, DIMENSION( : ) :: A_val
   INTEGER, PARAMETER :: n = 3, m = 4, a_ne = 5
! partition userdata%integer so that it holds
!   m n nflag  flag       a_ptr          a_row
!  |1|2|  3  |4 to n+3 |n+4 to 2n+4|2n+5 to 2n+4+a_ne|
! partition userdata%real so that it holds
!     a_val
!  |1 to a_ne|
   INTEGER, PARAMETER :: nflag = 3, st_flag = 3, st_ptr = st_flag + n
   INTEGER, PARAMETER :: st_row = st_ptr + n + 1, st_val = 0
   INTEGER, PARAMETER :: len_integer = st_row + a_ne + 1, len_real = a_ne
   EXTERNAL :: APROD, ASPROD, AFPROD
   EXTERNAL :: APROD_broken, ASPROD_broken, AFPROD_broken
! set up problem data
   ALLOCATE( p%B( m ), p%X_l( n ), p%X_u( n ), p%X( n ), X_stat( n ) )
   p%n = n ; p%m = m                          ! dimensions
   p%B = (/ 0.0_wp, 2.0_wp, 1.0_wp, 2.0_wp /) ! right-hand side
   p%X_l = (/ - 1.0_wp, - infinity, 0.0_wp /) ! variable lower bound
   p%X_u = (/ infinity, 1.0_wp, 2.0_wp /)     ! variable upper bound
   p%X = 0.0_wp ! start from zero
   ALLOCATE( A_val( a_ne ), A_row( a_ne ), A_ptr( n + 1 ), A_ptr_row( m + 1 ) )
   A_val = (/ 1.0_wp, 1.0_wp, 1.0_wp, 1.0_wp, 1.0_wp /) ! Jacobian A by columns
   A_row = (/ 1, 2, 2, 3, 4 /)                     ! row indices
   A_col = (/ 1, 1, 2, 3, 3 /)                     ! column indices
   A_ptr = (/ 1, 3, 4, 6 /)                        ! pointers to column starts
   A_ptr_row = (/ 1, 2, 4, 5, 6 /)                 ! pointers to row starts
! problem data complete

!  generic runs to test each mode

   DO mode = 1, 3
     CALL BLLS_initialize( data, control, inform )
     control%infinity = infinity                   ! Set infinity
!    control%print_level = 1                       ! print one line/iteration
     control%exact_arc_search = .FALSE.
!    control%exact_arc_search = .FALSE.
     p%X = 0.0_wp ! start from zero
     SELECT CASE ( mode )
     CASE ( 1 ) ! A expllicitly available
       CALL SMT_put( p%A%type, 'SPARSE_BY_COLUMNS', s )
       ALLOCATE( p%A%val( a_ne ), p%A%row( a_ne ), p%A%ptr( n + 1 ) )
       p%A%m = m ; p%A%n = n
       p%A%val( : a_ne ) = A_val( : a_ne )
       p%A%row( : a_ne ) = A_row( : a_ne )
       p%A%ptr( : n + 1 ) = A_ptr( : n + 1 )
       inform%status = 1
       CALL BLLS_solve( p, X_stat, data, control, inform, userdata )
       WRITE( 6, "( ' BLLS_solve argument mode=', I0, ', status = ', I0,       &
      &  ', objective = ', F6.4 ) " ) mode, inform%status, inform%obj
       DEALLOCATE( p%A%val, p%A%row, p%A%ptr, p%A%type )
     CASE ( 2 ) ! A available by matrix-vector products
       ALLOCATE( FLAG( n ) )
       nf = 0 ; FLAG = 0
       inform%status = 1
       DO ! Solve problem - reverse commmunication loop
         CALL BLLS_solve( p, X_stat, data, control, inform, userdata, reverse )
         SELECT CASE ( inform%status )
         CASE ( : 0 ) !  termination return
           WRITE( 6, "( ' BLLS_solve argument mode=', I0, ', status = ', I0,   &
          &  ', objective = ', F6.4 ) " ) mode, inform%status, inform%obj
           EXIT
         CASE ( 2 ) ! compute A * v
           reverse%P( : m ) = 0.0_wp
           DO j = 1, n
             val = reverse%V( j )
             DO k = A_ptr( j ), A_ptr( j + 1 ) - 1
               i = A_row( k )
               reverse%P( i ) = reverse%P( i ) + A_val( k ) * val
             END DO
           END DO
         CASE ( 3 ) ! compute A^T * v
           reverse%P( : n ) = 0.0_wp
           DO j = 1, n
             val = 0.0_wp
             DO k = A_ptr( j ), A_ptr( j + 1 ) - 1
               val = val + A_val( k ) * reverse%V( A_row( k ) )
             END DO
             reverse%P( j ) = val
           END DO
         CASE ( 4 ) ! compute A * sparse v
           reverse%P( : m ) = 0.0_wp
           DO l = reverse%nz_in_start, reverse%nz_in_end
             j = reverse%NZ_in( l )
             val = reverse%V( j )
             DO k = A_ptr( j ), A_ptr( j + 1 ) - 1
               i = A_row( k )
               reverse%P( i ) = reverse%P( i ) + A_val( k ) * val
             END DO
           END DO
         CASE ( 5 ) ! compute sparse( A * sparse v )
           nf = nf + 1
           reverse%nz_out_end = 0
           DO l = reverse%nz_in_start, reverse%nz_in_end
             j = reverse%NZ_in( l )
             val = reverse%V( j )
             DO k = A_ptr( j ), A_ptr( j + 1 ) - 1
               i = A_row( k )
               IF ( FLAG( i ) < nf ) THEN
                 FLAG( i ) = nf
                 reverse%P( i ) = A_val( k ) * val
                 reverse%nz_out_end = reverse%nz_out_end + 1
                 reverse%NZ_out( reverse%nz_out_end ) = i
               ELSE
                 reverse%P( i ) = reverse%P( i ) + A_val( k ) * val
               END IF
             END DO
           END DO
         CASE ( 6 ) ! compute sparse( A^T * v )
           reverse%P( : n ) = 0.0_wp
           DO l = reverse%nz_in_start, reverse%nz_in_end
             j = reverse%NZ_in( l )
             val = 0.0_wp
             DO k = A_ptr( j ), A_ptr( j + 1 ) - 1
               val = val + A_val( k ) * reverse%V( A_row( k ) )
             END DO
             reverse%P( j ) = val
           END DO
         END SELECT
       END DO
     CASE ( 3 ) ! A available by external subroutines
       ALLOCATE( userdata%integer( len_integer ), userdata%real( len_real ) )
       userdata%integer( 1 ) = m   ! load Jacobian data into userdata
       userdata%integer( 2 ) = n
       userdata%integer( st_ptr + 1 : st_ptr + n + 1 ) = A_ptr( : n + 1 )
       userdata%integer( st_row + 1 : st_row + a_ne ) = A_row( : a_ne )
       userdata%real( st_val + 1 : st_val + a_ne ) = A_val( : a_ne )
       userdata%integer( nflag ) = 0
       userdata%integer( st_flag + 1 : st_flag + n ) = 0
       inform%status = 1
       CALL BLLS_solve( p, X_stat, data, control, inform, userdata,            &
                        eval_APROD = APROD, eval_ASPROD = ASPROD,              &
                        eval_AFPROD = AFPROD )

       WRITE( 6, "( ' BLLS_solve argument mode=', I0, ', status = ', I0,       &
      &  ', objective = ', F6.4 ) " ) mode, inform%status, inform%obj
       DEALLOCATE( userdata%integer, userdata%real, FLAG )
     END SELECT
     CALL BLLS_terminate( data, control, inform )  !  delete workspace
   END DO

!  generic runs to test each storage mode

   DO mode = 1, 4
     CALL BLLS_initialize( data, control, inform )
     control%infinity = infinity                   ! Set infinity
!    control%print_level = 1                       ! print one line/iteration
     control%exact_arc_search = .FALSE.
!    control%exact_arc_search = .FALSE.
     p%X = 0.0_wp ! start from zero
     SELECT CASE ( mode )
     CASE ( 1 ) ! A by columns
       CALL SMT_put( p%A%type, 'SPARSE_BY_COLUMNS', s )
       ALLOCATE( p%A%val( a_ne ), p%A%row( a_ne ), p%A%ptr( n + 1 ) )
       p%A%m = m ; p%A%n = n
       p%A%val( : a_ne ) = A_val( : a_ne )
       p%A%row( : a_ne ) = A_row( : a_ne )
       p%A%ptr( : n + 1 ) = A_ptr( : n + 1 )
     CASE ( 2 ) ! A by rows
       CALL SMT_put( p%A%type, 'SPARSE_BY_ROWS', s )
       ALLOCATE( p%A%val( a_ne ), p%A%col( a_ne ), p%A%ptr( m + 1 ) )
       p%A%m = m ; p%A%n = n
       p%A%val( : a_ne ) = A_val( : a_ne )
       p%A%col( : a_ne ) = A_col( : a_ne )
       p%A%ptr( : m + 1 ) = A_ptr_row( : m + 1 )
     CASE ( 3 ) ! A coordinate
       CALL SMT_put( p%A%type, 'COORDINATE', s )
       ALLOCATE( p%A%val( a_ne ), p%A%row( a_ne ), p%A%col( a_ne ) )
       p%A%m = m ; p%A%n = n ; p%A%ne = a_ne
       p%A%val( : a_ne ) = A_val( : a_ne )
       p%A%row( : a_ne ) = A_row( : a_ne )
       p%A%col( : a_ne ) = A_col( : a_ne )
     CASE ( 4 ) ! A dense
       CALL SMT_put( p%A%type, 'DENSE', s )
       ALLOCATE( p%A%val( m * n ) )
       p%A%m = m ; p%A%n = n
       p%A%val( : m * n ) = (/ 1.0_wp, 1.0_wp, 0.0_wp, 0.0_wp,                 &
                              0.0_wp, 1.0_wp, 0.0_wp, 0.0_wp,                  &
                              0.0_wp, 0.0_wp, 1.0_wp, 1.0_wp /)
     END SELECT
     inform%status = 1
     CALL BLLS_solve( p, X_stat, data, control, inform, userdata )
     WRITE( 6, "( ' BLLS_solve argument storage=', I0, ', status = ', I0,      &
    &  ', objective = ', F6.4 ) " ) mode, inform%status, inform%obj
     SELECT CASE ( mode )
     CASE ( 1 ) ! A by columns
       DEALLOCATE( p%A%val, p%A%row, p%A%ptr, p%A%type )
     CASE ( 2 ) ! A by rows
       DEALLOCATE( p%A%val, p%A%col, p%A%ptr, p%A%type )
     CASE ( 3 ) ! A coordinate
       DEALLOCATE( p%A%val, p%A%row, p%A%col, p%A%type )
     CASE ( 4 ) ! A dense
       DEALLOCATE( p%A%val, p%A%type )
     END SELECT
     CALL BLLS_terminate( data, control, inform )  !  delete workspace
   END DO
   DEALLOCATE( p%B, p%X, p%X_l, p%X_u, p%Z, X_stat )

!  ================
!  error exit tests
!  ================

   WRITE( 6, "( /, ' error exit tests ', / )" )

   ALLOCATE( p%B( m ), p%X_l( n ), p%X_u( n ), p%X( n ), X_stat( n ) )
   p%n = n ; p%m = m
   p%B = (/ 0.0_wp, 2.0_wp, 1.0_wp, 2.0_wp /)
   p%X_l = (/ - 1.0_wp, - infinity, 0.0_wp /)
   p%X_u = (/ infinity, 1.0_wp, 2.0_wp /)
   CALL SMT_put( p%A%type, 'COORDINATE', s )
   ALLOCATE( p%A%val( a_ne ), p%A%row( a_ne ), p%A%col( a_ne ) )
   p%A%m = m ; p%A%n = n ; ; p%A%ne = a_ne
   p%A%val( : a_ne ) = A_val( : a_ne )
   p%A%row( : a_ne ) = A_row( : a_ne )
   p%A%col( : a_ne ) = A_col( : a_ne )

!  tests for status = - 1 ... - 24

   DO status = 1, 24

     CALL BLLS_initialize( data, control, inform )
     SELECT CASE ( status )
     CASE ( - GALAHAD_error_allocate,                                          &
            - GALAHAD_error_deallocate,                                        &
            - GALAHAD_error_dual_infeasible,                                   &
            - GALAHAD_error_unbounded,                                         &
            - GALAHAD_error_primal_infeasible,                                 &
            - GALAHAD_error_no_center,                                         &
            - GALAHAD_error_analysis,                                          &
            - GALAHAD_error_factorization,                                     &
            - GALAHAD_error_solve,                                             &
            - GALAHAD_error_uls_analysis,                                      &
            - GALAHAD_error_uls_factorization,                                 &
            - GALAHAD_error_uls_solve,                                         &
            - GALAHAD_error_preconditioner,                                    &
            - GALAHAD_error_ill_conditioned,                                   &
            - GALAHAD_error_inertia,                                           &
            - GALAHAD_error_file,                                              &
            - GALAHAD_error_io,                                                &
            - GALAHAD_error_sort,                                              &
            - GALAHAD_error_tiny_step,                                         &
            - GALAHAD_error_upper_entry )
       CYCLE
     CASE ( - GALAHAD_error_restrictions )
       p%n = 0 ; p%m = - 1
     CASE ( - GALAHAD_error_bad_bounds )
       p%X_u( 3 ) = - 2.0_wp
     CASE ( - GALAHAD_error_max_iterations )
       control%maxit = 0
!      control%print_level = 1
     CASE ( - GALAHAD_error_cpu_limit )
       control%cpu_time_limit = 0.0
!      control%print_level = 1
     END SELECT

     p%X = 0.0_wp
     inform%status = 1
     CALL BLLS_solve( p, X_stat, data, control, inform, userdata )
     WRITE( 6, "( ' BLLS_solve exit status = ', I0 ) " ) inform%status

     SELECT CASE ( status )
     CASE ( - GALAHAD_error_restrictions )
       p%n = n ; p%m = m
     CASE ( - GALAHAD_error_bad_bounds )
       p%X_u( 3 ) = 2.0_wp
     CASE ( - GALAHAD_error_max_iterations )
       control%maxit = 100
!      control%print_level = 1
     CASE ( - GALAHAD_error_cpu_limit )
       control%cpu_time_limit = 100.0
!      control%print_level = 1
     END SELECT
     CALL BLLS_terminate( data, control, inform )  !  delete workspace
   END DO

   ALLOCATE( userdata%integer( len_integer ), userdata%real( len_real ) )
   userdata%integer( 1 ) = m   ! load Jacobian data into userdata
   userdata%integer( 2 ) = n
   userdata%integer( st_ptr + 1 : st_ptr + n + 1 ) = A_ptr( : n + 1 )
   userdata%integer( st_row + 1 : st_row + a_ne ) = A_row( : a_ne )
   userdata%real( st_val + 1 : st_val + a_ne ) = A_val( : a_ne )
   userdata%integer( nflag ) = 0
   userdata%integer( st_flag + 1 : st_flag + n ) = 0

   p%X = 0.0_wp
   inform%status = 1
   CALL BLLS_solve( p, X_stat, data, control, inform, userdata,                &
                    eval_APROD = APROD_broken, eval_ASPROD = ASPROD,           &
                    eval_AFPROD = AFPROD )
   WRITE( 6, "( ' BLLS_solve exit status = ', I0 ) " ) inform%status

   p%X = 0.0_wp
   inform%status = 1
   CALL BLLS_solve( p, X_stat, data, control, inform, userdata,                &
                    eval_APROD = APROD, eval_ASPROD = ASPROD_broken,           &
                    eval_AFPROD = AFPROD )
   WRITE( 6, "( ' BLLS_solve exit status = ', I0 ) " ) inform%status

   p%X = 0.0_wp
   inform%status = 1
   CALL BLLS_solve( p, X_stat, data, control, inform, userdata,                &
                    eval_APROD = APROD, eval_ASPROD = ASPROD,                  &
                    eval_AFPROD = AFPROD_broken )
   WRITE( 6, "( ' BLLS_solve exit status = ', I0 ) " ) inform%status
   DEALLOCATE( userdata%integer, userdata%real )


   DEALLOCATE( p%B, p%X, p%X_l, p%X_u, p%Z, X_stat )
   DEALLOCATE( p%A%val, p%A%row, p%A%col, p%A%type )

   END PROGRAM GALAHAD_BLLS_TEST_PROGRAM

   SUBROUTINE APROD( status, userdata, transpose, V, P )
   USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
   INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
   INTEGER, INTENT( OUT ) :: status
   TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
   LOGICAL, INTENT( IN ) :: transpose
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: V
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: P
   INTEGER :: i, j, k
   REAL ( KIND = wp ) :: val
!  recover problem data from userdata
   INTEGER :: m, n, nflag, st_flag, st_ptr, st_row, st_val
   m = userdata%integer( 1 )
   n = userdata%integer( 2 )
   nflag = 3
   st_flag = 3
   st_ptr = st_flag + n
   st_row = st_ptr + n + 1
   st_val = 0
   IF ( transpose ) THEN
     DO j = 1, n
       DO k = userdata%integer( st_ptr + j ),                                  &
              userdata%integer( st_ptr + j + 1 ) - 1
         P( j ) = P( j ) + userdata%real( st_val + k ) *                       &
                     V( userdata%integer( st_row + k ) )
       END DO
     END DO
   ELSE
     DO j = 1, n
       val = V( j )
       DO k = userdata%integer( st_ptr + j ),                                  &
              userdata%integer( st_ptr + j + 1 ) - 1
         i = userdata%integer( st_row + k )
         P( i ) = P( i ) + userdata%real( st_val + k ) * val
       END DO
     END DO
   END IF
   status = 0
   RETURN
   END SUBROUTINE APROD

   SUBROUTINE ASPROD( status, userdata, V, P, NZ_in, nz_in_start, nz_in_end,   &
                      NZ_out, nz_out_end )
   USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
   INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
   INTEGER, INTENT( OUT ) :: status
   TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: V
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: P
   INTEGER, OPTIONAL, INTENT( IN ) :: nz_in_start, nz_in_end
   INTEGER, OPTIONAL, INTENT( INOUT ) :: nz_out_end
   INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: NZ_in
   INTEGER, DIMENSION( : ), OPTIONAL, INTENT( INOUT ) :: NZ_out
   INTEGER :: i, j, k, l
   REAL ( KIND = wp ) :: val
!  recover problem data from userdata
   INTEGER :: m, n, nflag, st_flag, st_ptr, st_row, st_val
   IF ( .NOT. ( PRESENT( NZ_in ) .AND. PRESENT( nz_in_start ) .AND.            &
                PRESENT( nz_in_end ) ) ) THEN
     status = - 1 ; RETURN
   END IF
   m = userdata%integer( 1 )
   n = userdata%integer( 2 )
   nflag = 3
   st_flag = 3
   st_ptr = st_flag + n
   st_row = st_ptr + n + 1
   st_val = 0
   IF ( PRESENT( NZ_out ) ) THEN
     IF ( .NOT. PRESENT( nz_out_end ) ) THEN
       status = - 1 ; RETURN
     END IF
     userdata%integer( nflag ) = userdata%integer( nflag ) + 1
     nz_out_end = 0
     DO l = nz_in_start, nz_in_end
       j = NZ_in( l )
       val = V( j )
       DO k = userdata%integer( st_ptr + j ),                                  &
              userdata%integer( st_ptr + j + 1 ) - 1
         i = userdata%integer( st_row + k )
         IF ( userdata%integer( st_flag + i ) < nflag ) THEN
           userdata%integer( st_flag + i ) = userdata%integer( nflag )
           P( i ) = userdata%real( st_val + k ) * val
           nz_out_end = nz_out_end + 1
           NZ_out( nz_out_end ) = i
         ELSE
           P( i ) = P( i ) + userdata%real( st_val + k ) * val
         END IF
       END DO
     END DO
   ELSE
     P( : m ) = 0.0_wp
     DO l = nz_in_start, nz_in_end
       j = NZ_in( l )
       val = V( j )
       DO k = userdata%integer( st_ptr + j ),                                  &
              userdata%integer( st_ptr + j + 1 ) - 1
         i = userdata%integer( st_row + k )
         P( i ) = P( i ) + userdata%real( st_val + k ) * val
       END DO
     END DO
   END IF
   status = 0
   RETURN
   END SUBROUTINE ASPROD

   SUBROUTINE AFPROD( status, userdata, transpose, V, P, FREE, n_free )
   USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
   INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
   INTEGER, INTENT( OUT ) :: status
   TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
   LOGICAL, INTENT( IN ) :: transpose
   INTEGER, INTENT( IN ) :: n_free
   INTEGER, INTENT( IN ), DIMENSION( : ) :: FREE
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: V
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: P
   INTEGER :: i, j, k, l
   REAL ( KIND = wp ) :: val
!  recover problem data from userdata
   INTEGER :: m, n, nflag, st_flag, st_ptr, st_row, st_val
   m = userdata%integer( 1 )
   n = userdata%integer( 2 )
   nflag = 3
   st_flag = 3
   st_ptr = st_flag + n
   st_row = st_ptr + n + 1
   st_val = 0
   IF ( transpose ) THEN
     DO l = 1, n_free
       j = FREE( l )
       val = 0.0_wp
       DO k = userdata%integer( st_ptr + j ),                                  &
              userdata%integer( st_ptr + j + 1 ) - 1
         val = val + userdata%real( st_val + k ) *                             &
                 V( userdata%integer( st_row + k ) )
       END DO
       P( j ) = val
     END DO
   ELSE
     P( : m ) = 0.0_wp
     DO l = 1, n_free
       j = FREE( l )
       val = V( j )
       DO k = userdata%integer( st_ptr + j ),                                  &
              userdata%integer( st_ptr + j + 1 ) - 1
         i = userdata%integer( st_row + k )
         P( i ) = P( i ) + userdata%real( st_val + k ) * val
       END DO
     END DO
   END IF
   status = 0
   RETURN
   END SUBROUTINE AFPROD











   SUBROUTINE APROD_broken( status, userdata, transpose, V, P )
   USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
   INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
   INTEGER, INTENT( OUT ) :: status
   TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
   LOGICAL, INTENT( IN ) :: transpose
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: V
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( INOUT ) :: P
   INTEGER :: i, j, k
   REAL ( KIND = wp ) :: val
   status = - 1
   RETURN
   END SUBROUTINE APROD_broken

   SUBROUTINE ASPROD_broken( status, userdata, V, P, NZ_in, nz_in_start,       &
                             nz_in_end, NZ_out, nz_out_end )
   USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
   INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
   INTEGER, INTENT( OUT ) :: status
   TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: V
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: P
   INTEGER, OPTIONAL, INTENT( IN ) :: nz_in_start, nz_in_end
   INTEGER, OPTIONAL, INTENT( INOUT ) :: nz_out_end
   INTEGER, DIMENSION( : ), OPTIONAL, INTENT( IN ) :: NZ_in
   INTEGER, DIMENSION( : ), OPTIONAL, INTENT( INOUT ) :: NZ_out
   INTEGER :: i, j, k, l
   REAL ( KIND = wp ) :: val
!  recover problem data from userdata
   INTEGER :: m, n, nflag, st_flag, st_ptr, st_row, st_val
   P( 1 ) = 0.0_wp
   status = - 1
   RETURN
   END SUBROUTINE ASPROD_broken

   SUBROUTINE AFPROD_broken( status, userdata, transpose, V, P, FREE, n_free )
   USE GALAHAD_NLPT_double, ONLY: NLPT_userdata_type
   INTEGER, PARAMETER :: wp = KIND( 1.0D+0 )
   INTEGER, INTENT( OUT ) :: status
   TYPE ( NLPT_userdata_type ), INTENT( INOUT ) :: userdata
   LOGICAL, INTENT( IN ) :: transpose
   INTEGER, INTENT( IN ) :: n_free
   INTEGER, INTENT( IN ), DIMENSION( : ) :: FREE
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( IN ) :: V
   REAL ( KIND = wp ), DIMENSION( : ), INTENT( OUT ) :: P
   P( 1 ) = 0.0_wp
   status = - 1
   RETURN
   END SUBROUTINE AFPROD_broken
