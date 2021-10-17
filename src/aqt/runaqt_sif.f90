! THIS VERSION: GALAHAD 3.3 - 08/10/2021 AT 09:45 GMT.

!-*-*-*-*-*-*-  G A L A H A D   R U N A Q T _ S I F  *-*-*-*-*-*-*-*-

!  Nick Gould, Dominique Orban and Philippe Toint, for GALAHAD productions
!  Copyright reserved
!  October 8th 2021

   PROGRAM RUNAQT_SIF
   USE GALAHAD_USEAQT_double

!  Main program for the SIF interface to AQT, an approximate solver for the 
!  quadratic trust-region subproblem

!  Problem insif characteristics

   INTEGER, PARAMETER :: errout = 6
   INTEGER, PARAMETER :: insif = 55
   CHARACTER ( LEN = 16 ) :: prbdat = 'OUTSDIF.d'
   INTEGER :: iostat

!  Open the data input file

   OPEN( insif, FILE = prbdat, FORM = 'FORMATTED', STATUS = 'OLD',             &
         IOSTAT = iostat )
   IF ( iostat > 0 ) THEN
     WRITE( errout,                                                            &
       "( ' ERROR: could not open file OUTSDIF.d on unit ', I2 )" ) insif
     STOP
   END IF
   REWIND insif

!  Call the SIF interface

   CALL USE_AQT( insif )

!  Close the data input file

   CLOSE( insif )
   STOP

!  End of RUNAQT_SIF

   END PROGRAM RUNAQT_SIF
