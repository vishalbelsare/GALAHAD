! THIS VERSION: GALAHAD 4.3 - 2024-01-05 AT 14:30 GMT.

      SUBROUTINE LA15ID( ICNTL, CNTL, KEEP )
      USE GALAHAD_KINDS_double
      DOUBLE PRECISION :: CNTL( 3 )
      INTEGER ( KIND = ip_ ) :: ICNTL( 3 )
      INTEGER ( KIND = ip_ ) :: KEEP( 7 )
      END SUBROUTINE LA15ID

      SUBROUTINE LA15AD( A, IND, nzero, ia, n, IP, IW, W, g, u,
     &                   ICNTL, CNTL, KEEP )
      USE GALAHAD_KINDS_double
      DOUBLE PRECISION :: g, U
      INTEGER ( KIND = ip_ ) :: ia, n, nzero
      DOUBLE PRECISION :: A( ia ),W( n )
      INTEGER ( KIND = ip_ ) :: IND( ia, 2 ),IP(N,2),IW( n, 8 )
      DOUBLE PRECISION :: CNTL( 3 )
      INTEGER ( KIND = ip_ ) :: ICNTL( 3 )
      INTEGER ( KIND = ip_ ) :: KEEP( 7 )
      END SUBROUTINE LA15AD

      SUBROUTINE LA15BD( A, IND, ia, n, IP, IW, W, g, B,
     &                   trans, ICNTL, KEEP )
      USE GALAHAD_KINDS_double
      DOUBLE PRECISION :: g
      INTEGER ( KIND = ip_ ) :: ia, n
      LOGICAL :: trans
      DOUBLE PRECISION :: A( ia ), B( n ), W( n )
      INTEGER ( KIND = ip_ ) :: IND( ia, 2 ),IP( n, 2 ), IW( n, 4 )
      INTEGER ( KIND = ip_ ) :: ICNTL( 3 )
      INTEGER ( KIND = ip_ ) :: KEEP( 7 )
      END SUBROUTINE LA15BD

      SUBROUTINE LA15CD( A, IND, ia, n, IP, IW, W, g, u, mm,
     &                   ICNTL, CNTL, KEEP )
      USE GALAHAD_KINDS_double
      DOUBLE PRECISION :: g, u
      INTEGER ( KIND = ip_ ) :: ia, mm, n
      DOUBLE PRECISION :: A( ia ),W( n )
      INTEGER ( KIND = ip_ ) :: IND( ia, 2 ), IP( n, 2 ), IW( n, 4 )
      DOUBLE PRECISION :: CNTL( 3 )
      INTEGER ( KIND = ip_ ) :: ICNTL( 3 )
      INTEGER ( KIND = ip_ ) :: KEEP( 7 )
      END SUBROUTINE LA15CD
