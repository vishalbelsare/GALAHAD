#ifdef INTEGER_64
#define GALAHAD_KINDS GALAHAD_KINDS_64
#endif

#ifdef INTEGER_64

#ifdef GALAHAD_BLAS
#define LSAME  GALAHAD_LSAME_64
#define XERBLA GALAHAD_XERBLA_64
#else
#ifdef NO_UNDERSCORE_INTEGER_64
#define XERBLA XERBLA64
#define LSAME  LSAME64
#elif DOUBLE_UNDERSCORE_INTEGER_64
#define XERBLA XERBLA__64
#define LSAME  LSAME__64
#elif NO_SYMBOL_INTEGER_64
#else
#define XERBLA XERBLA_64
#define LSAME  LSAME_64
#endif
#endif
#else
#ifdef GALAHAD_BLAS
#define LSAME  GALAHAD_LSAME
#define XERBLA GALAHAD_XERBLA
#endif
#endif

#ifdef REAL_32
#ifdef INTEGER_64
#define BLAS_LAPACK_KINDS_precision BLAS_LAPACK_KINDS_single_64
#ifdef GALAHAD_BLAS
#define DASUM  GALAHAD_SASUM_64
#define DAXPY  GALAHAD_SAXPY_64
#define DCOPY  GALAHAD_SCOPY_64
#define DDOT   GALAHAD_SDOT_64
#define DGEMM  GALAHAD_SGEMM_64
#define DGEMV  GALAHAD_SGEMV_64
#define DGER   GALAHAD_SGER_64
#define DNRM2  GALAHAD_SNRM2_64
#define DROT   GALAHAD_SROT_64
#define DROTG  GALAHAD_SROTG_64
#define DSCAL  GALAHAD_SSCAL_64
#define DSPMV  GALAHAD_SSPMV_64
#define DSWAP  GALAHAD_SSWAP_64
#define DSYMM  GALAHAD_SSYMM_64
#define DSYMV  GALAHAD_SSYMV_64
#define DSYR   GALAHAD_SSYR_64
#define DSYR2  GALAHAD_SSYR2_64
#define DSYR2K GALAHAD_SSYR2K_64
#define DSYRK  GALAHAD_SSYRK_64
#define DTBSV  GALAHAD_STBSV_64
#define DTPMV  GALAHAD_STPMV_64
#define DTPSV  GALAHAD_STPSV_64
#define DTRMM  GALAHAD_STRMM_64
#define DTRMV  GALAHAD_STRMV_64
#define DTRSM  GALAHAD_STRSM_64
#define DTRSV  GALAHAD_STRSV_64
#define IDAMAX GALAHAD_ISAMAX_64
#else
#ifdef NO_UNDERSCORE_INTEGER_64
#define DASUM  SASUM64
#define DAXPY  SAXPY64
#define DCOPY  SCOPY64
#define DDOT   SDOT64
#define DGEMM  SGEMM64
#define DGEMV  SGEMV64
#define DGER   SGER64
#define DNRM2  SNRM264
#define DROT   SROT64
#define DROTG  SROTG64
#define DSCAL  SSCAL64
#define DSPMV  SSPMV64
#define DSWAP  SSWAP64
#define DSYMM  SSYMM64
#define DSYMV  SSYMV64
#define DSYR   SSYR64
#define DSYR2  SSYR264
#define DSYR2K SSYR2K64
#define DSYRK  SSYRK64
#define DTBSV  STBSV64
#define DTPMV  STPMV64
#define DTPSV  STPSV64
#define DTRMM  STRMM64
#define DTRMV  STRMV64
#define DTRSM  STRSM64
#define DTRSV  STRSV64
#define IDAMAX ISAMAX64
#elif DOUBLE_UNDERSCORE_INTEGER_64
#define DASUM  SASUM__64
#define DAXPY  SAXPY__64
#define DCOPY  SCOPY__64
#define DDOT   SDOT__64
#define DGEMM  SGEMM__64
#define DGEMV  SGEMV__64
#define DGER   SGER__64
#define DNRM2  SNRM2__64
#define DROT   SROT__64
#define DROTG  SROTG__64
#define DSCAL  SSCAL__64
#define DSPMV  SSPMV__64
#define DSWAP  SSWAP__64
#define DSYMM  SSYMM__64
#define DSYMV  SSYMV__64
#define DSYR   SSYR__64
#define DSYR2  SSYR2__64
#define DSYR2K SSYR2K__64
#define DSYRK  SSYRK__64
#define DTBSV  STBSV__64
#define DTPMV  STPMV__64
#define DTPSV  STPSV__64
#define DTRMM  STRMM__64
#define DTRMV  STRMV__64
#define DTRSM  STRSM__64
#define DTRSV  STRSV__64
#define IDAMAX ISAMAX__64
#elif NO_SYMBOL_INTEGER_64
#define DASUM  SASUM
#define DAXPY  SAXPY
#define DCOPY  SCOPY
#define DDOT   SDOT
#define DGEMM  SGEMM
#define DGEMV  SGEMV
#define DGER   SGER
#define DNRM2  SNRM2
#define DROT   SROT
#define DROTG  SROTG
#define DSCAL  SSCAL
#define DSPMV  SSPMV
#define DSWAP  SSWAP
#define DSYMM  SSYMM
#define DSYMV  SSYMV
#define DSYR   SSYR
#define DSYR2  SSYR2
#define DSYR2K SSYR2K
#define DSYRK  SSYRK
#define DTBSV  STBSV
#define DTPMV  STPMV
#define DTPSV  STPSV
#define DTRMM  STRMM
#define DTRMV  STRMV
#define DTRSM  STRSM
#define DTRSV  STRSV
#define IDAMAX ISAMAX
#else
#define DASUM  SASUM_64
#define DAXPY  SAXPY_64
#define DCOPY  SCOPY_64
#define DDOT   SDOT_64
#define DGEMM  SGEMM_64
#define DGEMV  SGEMV_64
#define DGER   SGER_64
#define DNRM2  SNRM2_64
#define DROT   SROT_64
#define DROTG  SROTG_64
#define DSCAL  SSCAL_64
#define DSPMV  SSPMV_64
#define DSWAP  SSWAP_64
#define DSYMM  SSYMM_64
#define DSYMV  SSYMV_64
#define DSYR   SSYR_64
#define DSYR2  SSYR2_64
#define DSYR2K SSYR2K_64
#define DSYRK  SSYRK_64
#define DTBSV  STBSV_64
#define DTPMV  STPMV_64
#define DTPSV  STPSV_64
#define DTRMM  STRMM_64
#define DTRMV  STRMV_64
#define DTRSM  STRSM_64
#define DTRSV  STRSV_64
#define IDAMAX ISAMAX_64
#endif
#endif
#else
#define BLAS_LAPACK_KINDS_precision BLAS_LAPACK_KINDS_single
#ifdef GALAHAD_BLAS
#define DASUM  GALAHAD_SASUM
#define DAXPY  GALAHAD_SAXPY
#define DCOPY  GALAHAD_SCOPY
#define DDOT   GALAHAD_SDOT
#define DGEMM  GALAHAD_SGEMM
#define DGEMV  GALAHAD_SGEMV
#define DGER   GALAHAD_SGER
#define DNRM2  GALAHAD_SNRM2
#define DROT   GALAHAD_SROT
#define DROTG  GALAHAD_SROTG
#define DSCAL  GALAHAD_SSCAL
#define DSPMV  GALAHAD_SSPMV
#define DSWAP  GALAHAD_SSWAP
#define DSYMM  GALAHAD_SSYMM
#define DSYMV  GALAHAD_SSYMV
#define DSYR   GALAHAD_SSYR
#define DSYR2  GALAHAD_SSYR2
#define DSYR2K GALAHAD_SSYR2K
#define DSYRK  GALAHAD_SSYRK
#define DTBSV  GALAHAD_STBSV
#define DTPMV  GALAHAD_STPMV
#define DTPSV  GALAHAD_STPSV
#define DTRMM  GALAHAD_STRMM
#define DTRMV  GALAHAD_STRMV
#define DTRSM  GALAHAD_STRSM
#define DTRSV  GALAHAD_STRSV
#define IDAMAX GALAHAD_ISAMAX
#else
#define DASUM  SASUM
#define DAXPY  SAXPY
#define DCOPY  SCOPY
#define DDOT   SDOT
#define DGEMM  SGEMM
#define DGEMV  SGEMV
#define DGER   SGER
#define DNRM2  SNRM2
#define DROT   SROT
#define DROTG  SROTG
#define DSCAL  SSCAL
#define DSPMV  SSPMV
#define DSWAP  SSWAP
#define DSYMM  SSYMM
#define DSYMV  SSYMV
#define DSYR   SSYR
#define DSYR2  SSYR2
#define DSYR2K SSYR2K
#define DSYRK  SSYRK
#define DTBSV  STBSV
#define DTPMV  STPMV
#define DTPSV  STPSV
#define DTRMM  STRMM
#define DTRMV  STRMV
#define DTRSM  STRSM
#define DTRSV  STRSV
#define IDAMAX ISAMAX
#endif
#endif

#elif REAL_128

#ifdef INTEGER_64
#define BLAS_LAPACK_KINDS_precision BLAS_LAPACK_KINDS_quadruple_64
#ifdef GALAHAD_BLAS
#define DASUM  GALAHAD_QASUM_64
#define DAXPY  GALAHAD_QAXPY_64
#define DCOPY  GALAHAD_QCOPY_64
#define DDOT   GALAHAD_QDOT_64
#define DGEMM  GALAHAD_QGEMM_64
#define DGEMV  GALAHAD_QGEMV_64
#define DGER   GALAHAD_QGER_64
#define DNRM2  GALAHAD_QNRM2_64
#define DROT   GALAHAD_QROT_64
#define DROTG  GALAHAD_QROTG_64
#define DSCAL  GALAHAD_QSCAL_64
#define DSPMV  GALAHAD_QSPMV_64
#define DSWAP  GALAHAD_QSWAP_64
#define DSYMM  GALAHAD_QSYMM_64
#define DSYMV  GALAHAD_QSYMV_64
#define DSYR   GALAHAD_QSYR_64
#define DSYR2  GALAHAD_QSYR2_64
#define DSYR2K GALAHAD_QSYR2K_64
#define DSYRK  GALAHAD_QSYRK_64
#define DTBSV  GALAHAD_QTBSV_64
#define DTPMV  GALAHAD_QTPMV_64
#define DTPSV  GALAHAD_QTPSV_64
#define DTRMM  GALAHAD_QTRMM_64
#define DTRMV  GALAHAD_QTRMV_64
#define DTRSM  GALAHAD_QTRSM_64
#define DTRSV  GALAHAD_QTRSV_64
#define IDAMAX GALAHAD_IQAMAX_64
#else
#ifdef NO_UNDERSCORE_INTEGER_64
#define DASUM  QASUM64
#define DAXPY  QAXPY64
#define DCOPY  QCOPY64
#define DDOT   QDOT64
#define DGEMM  QGEMM64
#define DGEMV  QGEMV64
#define DGER   QGER64
#define DNRM2  QNRM264
#define DROT   QROT64
#define DROTG  QROTG64
#define DSCAL  QSCAL64
#define DSPMV  QSPMV64
#define DSWAP  QSWAP64
#define DSYMM  QSYMM64
#define DSYMV  QSYMV64
#define DSYR   QSYR64
#define DSYR2  QSYR264
#define DSYR2K QSYR2K64
#define DSYRK  QSYRK64
#define DTBSV  QTBSV64
#define DTPMV  QTPMV64
#define DTPSV  QTPSV64
#define DTRMM  QTRMM64
#define DTRMV  QTRMV64
#define DTRSM  QTRSM64
#define DTRSV  QTRSV64
#define IDAMAX IQAMAX64
#elif DOUBLE_UNDERSCORE_INTEGER_64
#define DASUM  QASUM__64
#define DAXPY  QAXPY__64
#define DCOPY  QCOPY__64
#define DDOT   QDOT__64
#define DGEMM  QGEMM__64
#define DGEMV  QGEMV__64
#define DGER   QGER__64
#define DNRM2  QNRM2__64
#define DROT   QROT__64
#define DROTG  QROTG__64
#define DSCAL  QSCAL__64
#define DSPMV  QSPMV__64
#define DSWAP  QSWAP__64
#define DSYMM  QSYMM__64
#define DSYMV  QSYMV__64
#define DSYR   QSYR__64
#define DSYR2  QSYR2__64
#define DSYR2K QSYR2K__64
#define DSYRK  QSYRK__64
#define DTBSV  QTBSV__64
#define DTPMV  QTPMV__64
#define DTPSV  QTPSV__64
#define DTRMM  QTRMM__64
#define DTRMV  QTRMV__64
#define DTRSM  QTRSM__64
#define DTRSV  QTRSV__64
#define IDAMAX IQAMAX__64
#elif NO_SYMBOL_INTEGER_64
#define DASUM  QASUM
#define DAXPY  QAXPY
#define DCOPY  QCOPY
#define DDOT   QDOT
#define DGEMM  QGEMM
#define DGEMV  QGEMV
#define DGER   QGER
#define DNRM2  QNRM2
#define DROT   QROT
#define DROTG  QROTG
#define DSCAL  QSCAL
#define DSPMV  QSPMV
#define DSWAP  QSWAP
#define DSYMM  QSYMM
#define DSYMV  QSYMV
#define DSYR   QSYR
#define DSYR2  QSYR2
#define DSYR2K QSYR2K
#define DSYRK  QSYRK
#define DTBSV  QTBSV
#define DTPMV  QTPMV
#define DTPSV  QTPSV
#define DTRMM  QTRMM
#define DTRMV  QTRMV
#define DTRSM  QTRSM
#define DTRSV  QTRSV
#define IDAMAX IQAMAX
#else
#define DASUM  QASUM_64
#define DAXPY  QAXPY_64
#define DCOPY  QCOPY_64
#define DDOT   QDOT_64
#define DGEMM  QGEMM_64
#define DGEMV  QGEMV_64
#define DGER   QGER_64
#define DNRM2  QNRM2_64
#define DROT   QROT_64
#define DROTG  QROTG_64
#define DSCAL  QSCAL_64
#define DSPMV  QSPMV_64
#define DSWAP  QSWAP_64
#define DSYMM  QSYMM_64
#define DSYMV  QSYMV_64
#define DSYR   QSYR_64
#define DSYR2  QSYR2_64
#define DSYR2K QSYR2K_64
#define DSYRK  QSYRK_64
#define DTBSV  QTBSV_64
#define DTPMV  QTPMV_64
#define DTPSV  QTPSV_64
#define DTRMM  QTRMM_64
#define DTRMV  QTRMV_64
#define DTRSM  QTRSM_64
#define DTRSV  QTRSV_64
#define IDAMAX IQAMAX_64
#endif
#endif
#else
#define BLAS_LAPACK_KINDS_precision BLAS_LAPACK_KINDS_quadruple
#ifdef GALAHAD_BLAS
#define DASUM  GALAHAD_QASUM
#define DAXPY  GALAHAD_QAXPY
#define DCOPY  GALAHAD_QCOPY
#define DDOT   GALAHAD_QDOT
#define DGEMM  GALAHAD_QGEMM
#define DGEMV  GALAHAD_QGEMV
#define DGER   GALAHAD_QGER
#define DNRM2  GALAHAD_QNRM2
#define DROT   GALAHAD_QROT
#define DROTG  GALAHAD_QROTG
#define DSCAL  GALAHAD_QSCAL
#define DSPMV  GALAHAD_QSPMV
#define DSWAP  GALAHAD_QSWAP
#define DSYMM  GALAHAD_QSYMM
#define DSYMV  GALAHAD_QSYMV
#define DSYR   GALAHAD_QSYR
#define DSYR2  GALAHAD_QSYR2
#define DSYR2K GALAHAD_QSYR2K
#define DSYRK  GALAHAD_QSYRK
#define DTBSV  GALAHAD_QTBSV
#define DTPMV  GALAHAD_QTPMV
#define DTPSV  GALAHAD_QTPSV
#define DTRMM  GALAHAD_QTRMM
#define DTRMV  GALAHAD_QTRMV
#define DTRSM  GALAHAD_QTRSM
#define DTRSV  GALAHAD_QTRSV
#define IDAMAX GALAHAD_IQAMAX
#else
#define DASUM  QASUM
#define DAXPY  QAXPY
#define DCOPY  QCOPY
#define DDOT   QDOT
#define DGEMM  QGEMM
#define DGEMV  QGEMV
#define DGER   QGER
#define DNRM2  QNRM2
#define DROT   QROT
#define DROTG  QROTG
#define DSCAL  QSCAL
#define DSPMV  QSPMV
#define DSWAP  QSWAP
#define DSYMM  QSYMM
#define DSYMV  QSYMV
#define DSYR   QSYR
#define DSYR2  QSYR2
#define DSYR2K QSYR2K
#define DSYRK  QSYRK
#define DTBSV  QTBSV
#define DTPMV  QTPMV
#define DTPSV  QTPSV
#define DTRMM  QTRMM
#define DTRMV  QTRMV
#define DTRSM  QTRSM
#define DTRSV  QTRSV
#define IDAMAX IQAMAX
#endif
#endif

#else

#ifdef INTEGER_64
#define BLAS_LAPACK_KINDS_precision BLAS_LAPACK_KINDS_double_64
#ifdef GALAHAD_BLAS
#define DASUM  GALAHAD_DASUM_64
#define DAXPY  GALAHAD_DAXPY_64
#define DCOPY  GALAHAD_DCOPY_64
#define DDOT   GALAHAD_DDOT_64
#define DGEMM  GALAHAD_DGEMM_64
#define DGEMV  GALAHAD_DGEMV_64
#define DGER   GALAHAD_DGER_64
#define DNRM2  GALAHAD_DNRM2_64
#define DROT   GALAHAD_DROT_64
#define DROTG  GALAHAD_DROTG_64
#define DSCAL  GALAHAD_DSCAL_64
#define DSPMV  GALAHAD_DSPMV_64
#define DSWAP  GALAHAD_DSWAP_64
#define DSYMM  GALAHAD_DSYMM_64
#define DSYMV  GALAHAD_DSYMV_64
#define DSYR   GALAHAD_DSYR_64
#define DSYR2  GALAHAD_DSYR2_64
#define DSYR2K GALAHAD_DSYR2K_64
#define DSYRK  GALAHAD_DSYRK_64
#define DTBSV  GALAHAD_DTBSV_64
#define DTPMV  GALAHAD_DTPMV_64
#define DTPSV  GALAHAD_DTPSV_64
#define DTRMM  GALAHAD_DTRMM_64
#define DTRMV  GALAHAD_DTRMV_64
#define DTRSM  GALAHAD_DTRSM_64
#define DTRSV  GALAHAD_DTRSV_64
#define IDAMAX GALAHAD_IDAMAX_64
#else
#ifdef NO_UNDERSCORE_INTEGER_64
#define DASUM  DASUM64
#define DAXPY  DAXPY64
#define DCOPY  DCOPY64
#define DDOT   DDOT64
#define DGEMM  DGEMM64
#define DGEMV  DGEMV64
#define DGER   DGER64
#define DNRM2  DNRM264
#define DROT   DROT64
#define DROTG  DROTG64
#define DSCAL  DSCAL64
#define DSPMV  DSPMV64
#define DSWAP  DSWAP64
#define DSYMM  DSYMM64
#define DSYMV  DSYMV64
#define DSYR   DSYR64
#define DSYR2  DSYR264
#define DSYR2K DSYR2K64
#define DSYRK  DSYRK64
#define DTBSV  DTBSV64
#define DTPMV  DTPMV64
#define DTPSV  DTPSV64
#define DTRMM  DTRMM64
#define DTRMV  DTRMV64
#define DTRSM  DTRSM64
#define DTRSV  DTRSV64
#define IDAMAX IDAMAX64
#elif DOUBLE_UNDERSCORE_INTEGER_64
#define DASUM  DASUM__64
#define DAXPY  DAXPY__64
#define DCOPY  DCOPY__64
#define DDOT   DDOT__64
#define DGEMM  DGEMM__64
#define DGEMV  DGEMV__64
#define DGER   DGER__64
#define DNRM2  DNRM2__64
#define DROT   DROT__64
#define DROTG  DROTG__64
#define DSCAL  DSCAL__64
#define DSPMV  DSPMV__64
#define DSWAP  DSWAP__64
#define DSYMM  DSYMM__64
#define DSYMV  DSYMV__64
#define DSYR   DSYR__64
#define DSYR2  DSYR2__64
#define DSYR2K DSYR2K__64
#define DSYRK  DSYRK__64
#define DTBSV  DTBSV__64
#define DTPMV  DTPMV__64
#define DTPSV  DTPSV__64
#define DTRMM  DTRMM__64
#define DTRMV  DTRMV__64
#define DTRSM  DTRSM__64
#define DTRSV  DTRSV__64
#define IDAMAX IDAMAX__64
#elif NO_SYMBOL_INTEGER_64
#else
#define DASUM  DASUM_64
#define DAXPY  DAXPY_64
#define DCOPY  DCOPY_64
#define DDOT   DDOT_64
#define DGEMM  DGEMM_64
#define DGEMV  DGEMV_64
#define DGER   DGER_64
#define DNRM2  DNRM2_64
#define DROT   DROT_64
#define DROTG  DROTG_64
#define DSCAL  DSCAL_64
#define DSPMV  DSPMV_64
#define DSWAP  DSWAP_64
#define DSYMM  DSYMM_64
#define DSYMV  DSYMV_64
#define DSYR   DSYR_64
#define DSYR2  DSYR2_64
#define DSYR2K DSYR2K_64
#define DSYRK  DSYRK_64
#define DTBSV  DTBSV_64
#define DTPMV  DTPMV_64
#define DTPSV  DTPSV_64
#define DTRMM  DTRMM_64
#define DTRMV  DTRMV_64
#define DTRSM  DTRSM_64
#define DTRSV  DTRSV_64
#define IDAMAX IDAMAX_64
#endif
#endif
#else
#define BLAS_LAPACK_KINDS_precision BLAS_LAPACK_KINDS_double
#ifdef GALAHAD_BLAS
#define DASUM  GALAHAD_DASUM
#define DAXPY  GALAHAD_DAXPY
#define DCOPY  GALAHAD_DCOPY
#define DDOT   GALAHAD_DDOT
#define DGEMM  GALAHAD_DGEMM
#define DGEMV  GALAHAD_DGEMV
#define DGER   GALAHAD_DGER
#define DNRM2  GALAHAD_DNRM2
#define DROT   GALAHAD_DROT
#define DROTG  GALAHAD_DROTG
#define DSCAL  GALAHAD_DSCAL
#define DSPMV  GALAHAD_DSPMV
#define DSWAP  GALAHAD_DSWAP
#define DSYMM  GALAHAD_DSYMM
#define DSYMV  GALAHAD_DSYMV
#define DSYR   GALAHAD_DSYR
#define DSYR2  GALAHAD_DSYR2
#define DSYR2K GALAHAD_DSYR2K
#define DSYRK  GALAHAD_DSYRK
#define DTBSV  GALAHAD_DTBSV
#define DTPMV  GALAHAD_DTPMV
#define DTPSV  GALAHAD_DTPSV
#define DTRMM  GALAHAD_DTRMM
#define DTRMV  GALAHAD_DTRMV
#define DTRSM  GALAHAD_DTRSM
#define DTRSV  GALAHAD_DTRSV
#define IDAMAX GALAHAD_IDAMAX
#endif
#endif
#endif
