! THIS VERSION: GALAHAD 3.3 - 30/11/2021 AT 09:45 GMT.

!-*-*-*-*-*-*-*-  G A L A H A D _  G L S    C   I N T E R F A C E  -*-*-*-*-*-

!  Copyright reserved, Gould/Orban/Toint, for GALAHAD productions
!  Principal authors: Jaroslav Fowkes & Nick Gould

!  History -
!    originally released GALAHAD Version 3.3. November 30th 2021

!  For full documentation, see
!   http://galahad.rl.ac.uk/galahad-www/specs.html

  MODULE GALAHAD_GLS_double_ciface
    USE iso_c_binding
    USE GALAHAD_common_ciface
    USE GALAHAD_GLS_double, ONLY: &
        f_gls_control => GLS_control, &
        f_gls_ainfo => GLS_ainfo, &
        f_gls_finfo => GLS_finfo, &
        f_gls_sinfo => GLS_sinfo, &
        f_gls_full_data_type => GLS_full_data_type, &
        f_gls_initialize => GLS_initialize, &
        f_gls_read_specfile => GLS_read_specfile, &
        f_gls_import => GLS_import, &
        f_gls_reset_control => GLS_reset_control, &
        f_gls_information => GLS_information, &
        f_gls_terminate => GLS_terminate

    IMPLICIT NONE

!--------------------
!   P r e c i s i o n
!--------------------

    INTEGER, PARAMETER :: wp = C_DOUBLE ! double precision
    INTEGER, PARAMETER :: sp = C_FLOAT  ! single precision

!-------------------------------------------------
!  D e r i v e d   t y p e   d e f i n i t i o n s
!-------------------------------------------------

    TYPE, BIND( C ) :: gls_control
      LOGICAL ( KIND = C_BOOL ) :: f_indexing
      INTEGER ( KIND = C_INT ) :: lp
      INTEGER ( KIND = C_INT ) :: wp
      INTEGER ( KIND = C_INT ) :: mp
      INTEGER ( KIND = C_INT ) :: ldiag
      INTEGER ( KIND = C_INT ) :: btf
      INTEGER ( KIND = C_INT ) :: maxit
      INTEGER ( KIND = C_INT ) :: factor_blocking
      INTEGER ( KIND = C_INT ) :: solve_blas
      INTEGER ( KIND = C_INT ) :: la
      INTEGER ( KIND = C_INT ) :: la_int
      INTEGER ( KIND = C_INT ) :: maxla
      INTEGER ( KIND = C_INT ) :: pivoting
      INTEGER ( KIND = C_INT ) :: fill_in
      REAL ( KIND = wp ) :: multiplier
      REAL ( KIND = wp ) :: reduce
      REAL ( KIND = wp ) :: u
      REAL ( KIND = wp ) :: switch
      REAL ( KIND = wp ) :: drop
      REAL ( KIND = wp ) :: tolerance
      REAL ( KIND = wp ) :: cgce
      LOGICAL ( KIND = C_BOOL ) :: diagonal_pivoting
      LOGICAL ( KIND = C_BOOL ) :: struct
    END TYPE gls_control

    TYPE, BIND( C ) :: GLS_ainfo
      INTEGER ( KIND = C_INT ) :: flag
      INTEGER ( KIND = C_INT ) :: more
      INTEGER ( KIND = C_INT ) :: len_analyse
      INTEGER ( KIND = C_INT ) :: len_factorize
      INTEGER ( KIND = C_INT ) :: ncmpa
      INTEGER ( KIND = C_INT ) :: rank
      INTEGER ( KIND = C_INT ) :: drop
      INTEGER ( KIND = C_INT ) :: struc_rank
      INTEGER ( KIND = C_INT ) :: oor
      INTEGER ( KIND = C_INT ) :: dup
      INTEGER ( KIND = C_INT ) :: stat
      INTEGER ( KIND = C_INT ) :: lblock
      INTEGER ( KIND = C_INT ) :: sblock
      INTEGER ( KIND = C_INT ) :: tblock
      REAL ( KIND = wp ) :: ops
    END TYPE GLS_ainfo

    TYPE, BIND( C ) :: GLS_finfo
      INTEGER ( KIND = C_INT ) :: flag
      INTEGER ( KIND = C_INT ) :: more
      INTEGER ( KIND = C_INT ) :: size_factor
      INTEGER ( KIND = C_INT ) :: len_factorize
      INTEGER ( KIND = C_INT ) :: drop
      INTEGER ( KIND = C_INT ) :: rank
      INTEGER ( KIND = C_INT ) :: stat
      REAL ( KIND = wp ) :: ops
    END TYPE GLS_finfo

    TYPE, BIND( C ) :: GLS_sinfo
      INTEGER ( KIND = C_INT ) :: flag
      INTEGER ( KIND = C_INT ) :: more
      INTEGER ( KIND = C_INT ) :: stat
    END TYPE GLS_sinfo

!----------------------
!   P r o c e d u r e s
!----------------------

  CONTAINS

!  copy C control parameters to fortran

    SUBROUTINE copy_control_in( ccontrol, fcontrol, f_indexing ) 
    TYPE ( gls_control_type ), INTENT( IN ) :: ccontrol
    TYPE ( f_gls_control_type ), INTENT( OUT ) :: fcontrol
    LOGICAL, optional, INTENT( OUT ) :: f_indexing
    INTEGER :: i
    
    ! C or Fortran sparse matrix indexing
    IF ( PRESENT( f_indexing ) ) f_indexing = ccontrol%f_indexing

    ! Integers
    fcontrol%lp = ccontrol%lp
    fcontrol%wp = ccontrol%wp
    fcontrol%mp = ccontrol%mp
    fcontrol%ldiag = ccontrol%ldiag
    fcontrol%btf = ccontrol%btf
    fcontrol%maxit = ccontrol%maxit
    fcontrol%factor_blocking = ccontrol%factor_blocking
    fcontrol%solve_blas = ccontrol%solve_blas
    fcontrol%la = ccontrol%la
    fcontrol%la_int = ccontrol%la_int
    fcontrol%maxla = ccontrol%maxla
    fcontrol%pivoting = ccontrol%pivoting
    fcontrol%fill_in = ccontrol%fill_in

    ! Reals
    fcontrol%multiplier = ccontrol%multiplier
    fcontrol%reduce = ccontrol%reduce
    fcontrol%u = ccontrol%u
    fcontrol%switch = ccontrol%switch
    fcontrol%drop = ccontrol%drop
    fcontrol%tolerance = ccontrol%tolerance
    fcontrol%cgce = ccontrol%cgce

    ! Logicals
    fcontrol%diagonal_pivoting = ccontrol%diagonal_pivoting
    fcontrol%struct = ccontrol%struct
    RETURN

    END SUBROUTINE copy_control_in

!  copy fortran control parameters to C

    SUBROUTINE copy_control_out( fcontrol, ccontrol, f_indexing ) 
    TYPE ( f_gls_control_type ), INTENT( IN ) :: fcontrol
    TYPE ( gls_control_type ), INTENT( OUT ) :: ccontrol
    LOGICAL, OPTIONAL, INTENT( IN ) :: f_indexing
    INTEGER :: i
    
    ! C or Fortran sparse matrix indexing
    IF ( PRESENT( f_indexing ) ) ccontrol%f_indexing = f_indexing

    ! Integers
    ccontrol%lp = fcontrol%lp
    ccontrol%wp = fcontrol%wp
    ccontrol%mp = fcontrol%mp
    ccontrol%ldiag = fcontrol%ldiag
    ccontrol%btf = fcontrol%btf
    ccontrol%maxit = fcontrol%maxit
    ccontrol%factor_blocking = fcontrol%factor_blocking
    ccontrol%solve_blas = fcontrol%solve_blas
    ccontrol%la = fcontrol%la
    ccontrol%la_int = fcontrol%la_int
    ccontrol%maxla = fcontrol%maxla
    ccontrol%pivoting = fcontrol%pivoting
    ccontrol%fill_in = fcontrol%fill_in

    ! Reals
    ccontrol%multiplier = fcontrol%multiplier
    ccontrol%reduce = fcontrol%reduce
    ccontrol%u = fcontrol%u
    ccontrol%switch = fcontrol%switch
    ccontrol%drop = fcontrol%drop
    ccontrol%tolerance = fcontrol%tolerance
    ccontrol%cgce = fcontrol%cgce

    ! Logicals
    ccontrol%diagonal_pivoting = fcontrol%diagonal_pivoting
    ccontrol%struct = fcontrol%struct
    RETURN

    END SUBROUTINE copy_control_out

!  copy C ainfo parameters to fortran

    SUBROUTINE copy_ainfo_in( cainfo, fainfo, f_indexing ) 
    TYPE ( gls_ainfo ), INTENT( IN ) :: cainfo
    TYPE ( f_gls_ainfo ), INTENT( OUT ) :: fainfo
    LOGICAL, optional, INTENT( OUT ) :: f_indexing
    INTEGER :: i
    
    ! C or Fortran sparse matrix indexing
    IF ( PRESENT( f_indexing ) ) f_indexing = cainfo%f_indexing

    ! Integers
    fainfo%flag = cainfo%flag
    fainfo%more = cainfo%more
    fainfo%len_analyse = cainfo%len_analyse
    fainfo%len_factorize = cainfo%len_factorize
    fainfo%ncmpa = cainfo%ncmpa
    fainfo%rank = cainfo%rank
    fainfo%drop = cainfo%drop
    fainfo%struc_rank = cainfo%struc_rank
    fainfo%oor = cainfo%oor
    fainfo%dup = cainfo%dup
    fainfo%stat = cainfo%stat
    fainfo%lblock = cainfo%lblock
    fainfo%sblock = cainfo%sblock
    fainfo%tblock = cainfo%tblock

    ! Reals
    fainfo%ops = cainfo%ops

    RETURN

    END SUBROUTINE copy_ainfo_in

!  copy fortran ainfo parameters to C

    SUBROUTINE copy_ainfo_out( fainfo, cainfo, f_indexing ) 
    TYPE ( f_gls_ainfo ), INTENT( IN ) :: fainfo
    TYPE ( gls_ainfo ), INTENT( OUT ) :: cainfo
    LOGICAL, OPTIONAL, INTENT( IN ) :: f_indexing
    INTEGER :: i
    
    ! C or Fortran sparse matrix indexing
    IF ( PRESENT( f_indexing ) ) cainfo%f_indexing = f_indexing

    ! Integers
    cainfo%flag = fainfo%flag
    cainfo%more = fainfo%more
    cainfo%len_analyse = fainfo%len_analyse
    cainfo%len_factorize = fainfo%len_factorize
    cainfo%ncmpa = fainfo%ncmpa
    cainfo%rank = fainfo%rank
    cainfo%drop = fainfo%drop
    cainfo%struc_rank = fainfo%struc_rank
    cainfo%oor = fainfo%oor
    cainfo%dup = fainfo%dup
    cainfo%stat = fainfo%stat
    cainfo%lblock = fainfo%lblock
    cainfo%sblock = fainfo%sblock
    cainfo%tblock = fainfo%tblock

    ! Reals
    cainfo%ops = fainfo%ops

    RETURN

    END SUBROUTINE copy_ainfo_out

!  copy C finfo parameters to fortran

    SUBROUTINE copy_finfo_in( cfinfo, ffinfo, f_indexing ) 
    TYPE ( gls_finfo ), INTENT( IN ) :: cfinfo
    TYPE ( f_gls_finfo ), INTENT( OUT ) :: ffinfo
    LOGICAL, optional, INTENT( OUT ) :: f_indexing
    INTEGER :: i
    
    ! C or Fortran sparse matrix indexing
    IF ( PRESENT( f_indexing ) ) f_indexing = cfinfo%f_indexing

    ! Integers
    ffinfo%flag = cfinfo%flag
    ffinfo%more = cfinfo%more
    ffinfo%size_factor = cfinfo%size_factor
    ffinfo%len_factorize = cfinfo%len_factorize
    ffinfo%drop = cfinfo%drop
    ffinfo%rank = cfinfo%rank
    ffinfo%stat = cfinfo%stat

    ! Reals
    ffinfo%ops = cfinfo%ops

    RETURN

    END SUBROUTINE copy_finfo_in

!  copy fortran finfo parameters to C

    SUBROUTINE copy_finfo_out( ffinfo, cfinfo, f_indexing ) 
    TYPE ( f_gls_finfo ), INTENT( IN ) :: ffinfo
    TYPE ( gls_finfo ), INTENT( OUT ) :: cfinfo
    LOGICAL, OPTIONAL, INTENT( IN ) :: f_indexing
    INTEGER :: i
    
    ! C or Fortran sparse matrix indexing
    IF ( PRESENT( f_indexing ) ) cfinfo%f_indexing = f_indexing

    ! Integers
    cfinfo%flag = ffinfo%flag
    cfinfo%more = ffinfo%more
    cfinfo%size_factor = ffinfo%size_factor
    cfinfo%len_factorize = ffinfo%len_factorize
    cfinfo%drop = ffinfo%drop
    cfinfo%rank = ffinfo%rank
    cfinfo%stat = ffinfo%stat

    ! Reals
    cfinfo%ops = ffinfo%ops

    RETURN

    END SUBROUTINE copy_finfo_out

!  copy C sinfo parameters to fortran

    SUBROUTINE copy_sinfo_in( csinfo, fsinfo, f_indexing ) 
    TYPE ( gls_sinfo ), INTENT( IN ) :: csinfo
    TYPE ( f_gls_sinfo ), INTENT( OUT ) :: fsinfo
    LOGICAL, optional, INTENT( OUT ) :: f_indexing
    INTEGER :: i
    
    ! C or Fortran sparse matrix indexing
    IF ( PRESENT( f_indexing ) ) f_indexing = csinfo%f_indexing

    ! Integers
    fsinfo%flag = csinfo%flag
    fsinfo%more = csinfo%more
    fsinfo%stat = csinfo%stat

    RETURN

    END SUBROUTINE copy_sinfo_in

!  copy fortran sinfo parameters to C

    SUBROUTINE copy_sinfo_out( fsinfo, csinfo, f_indexing ) 
    TYPE ( f_gls_sinfo ), INTENT( IN ) :: fsinfo
    TYPE ( gls_sinfo ), INTENT( OUT ) :: csinfo
    LOGICAL, OPTIONAL, INTENT( IN ) :: f_indexing
    INTEGER :: i
    
    ! C or Fortran sparse matrix indexing
    IF ( PRESENT( f_indexing ) ) csinfo%f_indexing = f_indexing

    ! Integers
    csinfo%flag = fsinfo%flag
    csinfo%more = fsinfo%more
    csinfo%stat = fsinfo%stat

    RETURN

    END SUBROUTINE copy_sinfo_out

  END MODULE GALAHAD_GLS_double_ciface

!  -------------------------------------
!  C interface to fortran gls_initialize
!  -------------------------------------

  SUBROUTINE gls_initialize( cdata, ccontrol, cinform ) BIND( C ) 
  USE GALAHAD_GLS_double_ciface
  IMPLICIT NONE

!  dummy arguments

  TYPE ( C_PTR ), INTENT( OUT ) :: cdata ! data is a black-box
  TYPE ( gls_control_type ), INTENT( OUT ) :: ccontrol
  TYPE ( gls_inform_type ), INTENT( OUT ) :: cinform

!  local variables

  TYPE ( f_gls_full_data_type ), POINTER :: fdata
  TYPE ( f_gls_control_type ) :: fcontrol
  TYPE ( f_gls_inform_type ) :: finform
  LOGICAL :: f_indexing 

!  allocate fdata

  ALLOCATE( fdata ); cdata = C_LOC( fdata )

!  initialize required fortran types

  CALL f_gls_initialize( fdata, fcontrol, finform )

!  C sparse matrix indexing by default

  f_indexing = .FALSE.
  fdata%f_indexing = f_indexing

!  copy control out 

  CALL copy_control_out( fcontrol, ccontrol, f_indexing )

!  copy inform out

  CALL copy_inform_out( finform, cinform )
  RETURN

  END SUBROUTINE gls_initialize

!  ----------------------------------------
!  C interface to fortran gls_read_specfile
!  ----------------------------------------

  SUBROUTINE gls_read_specfile( ccontrol, cspecfile ) BIND( C )
  USE GALAHAD_GLS_double_ciface
  IMPLICIT NONE

!  dummy arguments

  TYPE ( gls_control_type ), INTENT( INOUT ) :: ccontrol
  TYPE ( C_PTR ), INTENT( IN ), VALUE :: cspecfile

!  local variables

  TYPE ( f_gls_control_type ) :: fcontrol
  CHARACTER ( KIND = C_CHAR, LEN = strlen( cspecfile ) ) :: fspecfile
  LOGICAL :: f_indexing

!  device unit number for specfile

  INTEGER ( KIND = C_INT ), PARAMETER :: device = 10

!  convert C string to Fortran string

  fspecfile = cstr_to_fchar( cspecfile )

!  copy control in

  CALL copy_control_in( ccontrol, fcontrol, f_indexing )
  
!  open specfile for reading

  OPEN( UNIT = device, FILE = fspecfile )
  
!  read control parameters from the specfile

  CALL f_gls_read_specfile( fcontrol, device )

!  close specfile

  CLOSE( device )

!  copy control out

  CALL copy_control_out( fcontrol, ccontrol, f_indexing )
  RETURN

  END SUBROUTINE gls_read_specfile

!  ---------------------------------
!  C interface to fortran gls_inport
!  ---------------------------------

  SUBROUTINE gls_import( ccontrol, cdata, status ) BIND( C )
  USE GALAHAD_GLS_double_ciface
  IMPLICIT NONE

!  dummy arguments

  INTEGER ( KIND = C_INT ), INTENT( OUT ) :: status
  TYPE ( gls_control_type ), INTENT( INOUT ) :: ccontrol
  TYPE ( C_PTR ), INTENT( INOUT ) :: cdata

!  local variables

  TYPE ( f_gls_control_type ) :: fcontrol
  TYPE ( f_gls_full_data_type ), POINTER :: fdata
  LOGICAL :: f_indexing

!  copy control and inform in

  CALL copy_control_in( ccontrol, fcontrol, f_indexing )

!  associate data pointer

  CALL C_F_POINTER( cdata, fdata )

!  is fortran-style 1-based indexing used?

  fdata%f_indexing = f_indexing

!  handle C sparse matrix indexing

  IF ( .NOT. f_indexing ) THEN

!  import the problem data into the required GLS structure

    CALL f_gls_import( fcontrol, fdata, status )
  ELSE
    CALL f_gls_import( fcontrol, fdata, status )
  END IF

!  copy control out

  CALL copy_control_out( fcontrol, ccontrol, f_indexing )
  RETURN

  END SUBROUTINE gls_import

!  ---------------------------------------
!  C interface to fortran gls_reset_control
!  ----------------------------------------

  SUBROUTINE gls_reset_control( ccontrol, cdata, status ) BIND( C )
  USE GALAHAD_GLS_double_ciface
  IMPLICIT NONE

!  dummy arguments

  INTEGER ( KIND = C_INT ), INTENT( OUT ) :: status
  TYPE ( gls_control_type ), INTENT( INOUT ) :: ccontrol
  TYPE ( C_PTR ), INTENT( INOUT ) :: cdata

!  local variables

  TYPE ( f_gls_control_type ) :: fcontrol
  TYPE ( f_gls_full_data_type ), POINTER :: fdata
  LOGICAL :: f_indexing

!  copy control in

  CALL copy_control_in( ccontrol, fcontrol, f_indexing )

!  associate data pointer

  CALL C_F_POINTER( cdata, fdata )

!  is fortran-style 1-based indexing used?

  fdata%f_indexing = f_indexing

!  import the control parameters into the required structure

  CALL f_GLS_reset_control( fcontrol, fdata, status )
  RETURN

  END SUBROUTINE gls_reset_control

!  --------------------------------------
!  C interface to fortran gls_information
!  --------------------------------------

  SUBROUTINE gls_information( cdata, cinform, status ) BIND( C ) 
  USE GALAHAD_GLS_double_ciface
  IMPLICIT NONE

!  dummy arguments

  TYPE ( C_PTR ), INTENT( INOUT ) :: cdata
  TYPE ( gls_inform_type ), INTENT( INOUT ) :: cinform
  INTEGER ( KIND = C_INT ), INTENT( OUT ) :: status

!  local variables

  TYPE ( f_gls_full_data_type ), pointer :: fdata
  TYPE ( f_gls_inform_type ) :: finform

!  associate data pointer

  CALL C_F_POINTER( cdata, fdata )

!  obtain GLS solution information

  CALL f_gls_information( fdata, finform, status )

!  copy inform out

  CALL copy_inform_out( finform, cinform )
  RETURN

  END SUBROUTINE gls_information

!  ------------------------------------
!  C interface to fortran gls_terminate
!  ------------------------------------

  SUBROUTINE gls_terminate( cdata, ccontrol, cinform ) BIND( C ) 
  USE GALAHAD_GLS_double_ciface
  IMPLICIT NONE

!  dummy arguments

  TYPE ( C_PTR ), INTENT( INOUT ) :: cdata
  TYPE ( gls_control_type ), INTENT( IN ) :: ccontrol
  TYPE ( gls_inform_type ), INTENT( INOUT ) :: cinform

!  local variables

  TYPE ( f_gls_full_data_type ), pointer :: fdata
  TYPE ( f_gls_control_type ) :: fcontrol
  TYPE ( f_gls_inform_type ) :: finform
  LOGICAL :: f_indexing

!  copy control in

  CALL copy_control_in( ccontrol, fcontrol, f_indexing )

!  copy inform in

  CALL copy_inform_in( cinform, finform )

!  associate data pointer

  CALL C_F_POINTER( cdata, fdata )

!  deallocate workspace

  CALL f_gls_terminate( fdata, fcontrol, finform )

!  copy inform out

  CALL copy_inform_out( finform, cinform )

!  deallocate data

  DEALLOCATE( fdata ); cdata = C_NULL_PTR 
  RETURN

  END SUBROUTINE gls_terminate
