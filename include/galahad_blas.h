#ifdef INTEGER_64
#define GALAHAD_KINDS GALAHAD_KINDS_64
#define GALAHAD_BLAS_interface GALAHAD_BLAS_interface_64
#endif

#ifdef GALAHAD_BLAS
#ifdef INTEGER_64
#define DASUM  GALAHAD_DASUM_64
#define DCABS1 GALAHAD_DCABS1_64
#define DDOT   GALAHAD_DDOT_64
#define DNRM2  GALAHAD_DNRM2_64
#define DZNRM2 GALAHAD_DZNRM2_64
#define IDAMAX GALAHAD_IDAMAX_64
#define ISAMAX GALAHAD_ISAMAX_64
#define LSAME  GALAHAD_LSAME_64
#define SASUM  GALAHAD_SASUM_64
#define SDOT   GALAHAD_SDOT_64
#define SNRM2  GALAHAD_SNRM2_64
#define DAXPY  GALAHAD_DAXPY_64
#define DCOPY  GALAHAD_DCOPY_64
#define DGEMM  GALAHAD_DGEMM_64
#define DGEMV  GALAHAD_DGEMV_64
#define DGER   GALAHAD_DGER_64
#define DROT   GALAHAD_DROT_64
#define DROTG  GALAHAD_DROTG_64
#define DSCAL  GALAHAD_DSCAL_64
#define DSWAP  GALAHAD_DSWAP_64
#define DSYMM  GALAHAD_DSYMM_64
#define DSYMV  GALAHAD_DSYMV_64
#define DSYR   GALAHAD_DSYR_64
#define DSYR2  GALAHAD_DSYR2_64
#define DSYR2K GALAHAD_DSYR2K_64
#define DSYRK  GALAHAD_DSYRK_64
#define DSPMV  GALAHAD_DSPMV_64
#define DTBSV  GALAHAD_DTBSV_64
#define DTPMV  GALAHAD_DTPMV_64
#define DTPSV  GALAHAD_DTPSV_64
#define DTRMM  GALAHAD_DTRMM_64
#define DTRMV  GALAHAD_DTRMV_64
#define DTRSM  GALAHAD_DTRSM_64
#define DTRSV  GALAHAD_DTRSV_64
#define SAXPY  GALAHAD_SAXPY_64
#define SCOPY  GALAHAD_SCOPY_64
#define SGEMM  GALAHAD_SGEMM_64
#define SGEMV  GALAHAD_SGEMV_64
#define SGER   GALAHAD_SGER_64
#define SROT   GALAHAD_SROT_64
#define SROTG  GALAHAD_SROTG_64
#define SSCAL  GALAHAD_SSCAL_64
#define SSWAP  GALAHAD_SSWAP_64
#define SSYMM  GALAHAD_SSYMM_64
#define SSYMV  GALAHAD_SSYMV_64
#define SSYR   GALAHAD_SSYR_64
#define SSYR2  GALAHAD_SSYR2_64
#define SSYR2K GALAHAD_SSYR2K_64
#define SSYRK  GALAHAD_SSYRK_64
#define SSPMV  GALAHAD_SSPMV_64
#define STBSV  GALAHAD_STBSV_64
#define STPMV  GALAHAD_STPMV_64
#define STPSV  GALAHAD_STPSV_64
#define STRMM  GALAHAD_STRMM_64
#define STRMV  GALAHAD_STRMV_64
#define STRSM  GALAHAD_STRSM_64
#define STRSV  GALAHAD_STRSV_64
#define XERBLA GALAHAD_XERBLA_64
#define ZCOPY  GALAHAD_ZCOPY_64
#define ZDOTC  GALAHAD_ZDOTC_64
#define ZDSCAL GALAHAD_ZDSCAL_64
#define ZGEMM  GALAHAD_ZGEMM_64
#define ZGEMV  GALAHAD_ZGEMV_64
#define ZGERC  GALAHAD_ZGERC_64
#define ZGERU  GALAHAD_ZGERU_64
#define ZHER   GALAHAD_ZHER_64
#define ZSCAL  GALAHAD_ZSCAL_64
#define ZSWAP  GALAHAD_ZSWAP_64
#define ZTRMM  GALAHAD_ZTRMM_64
#define ZTRMV  GALAHAD_ZTRMV_64
#define ZTRSM  GALAHAD_ZTRSM_64
#else
#define DASUM  GALAHAD_DASUM
#define DCABS1 GALAHAD_DCABS1
#define DDOT   GALAHAD_DDOT
#define DNRM2  GALAHAD_DNRM2
#define DZNRM2 GALAHAD_DZNRM2
#define IDAMAX GALAHAD_IDAMAX
#define ISAMAX GALAHAD_ISAMAX
#define LSAME  GALAHAD_LSAME
#define SASUM  GALAHAD_SASUM
#define SDOT   GALAHAD_SDOT
#define SNRM2  GALAHAD_SNRM2
#define DAXPY  GALAHAD_DAXPY
#define DCOPY  GALAHAD_DCOPY
#define DGEMM  GALAHAD_DGEMM
#define DGEMV  GALAHAD_DGEMV
#define DGER   GALAHAD_DGER
#define DROT   GALAHAD_DROT
#define DROTG  GALAHAD_DROTG
#define DSCAL  GALAHAD_DSCAL
#define DSWAP  GALAHAD_DSWAP
#define DSYMM  GALAHAD_DSYMM
#define DSYMV  GALAHAD_DSYMV
#define DSYR   GALAHAD_DSYR
#define DSYR2  GALAHAD_DSYR2
#define DSYR2K GALAHAD_DSYR2K
#define DSYRK  GALAHAD_DSYRK
#define DSPMV  GALAHAD_DSPMV
#define DTBSV  GALAHAD_DTBSV
#define DTPMV  GALAHAD_DTPMV
#define DTPSV  GALAHAD_DTPSV
#define DTRMM  GALAHAD_DTRMM
#define DTRMV  GALAHAD_DTRMV
#define DTRSM  GALAHAD_DTRSM
#define DTRSV  GALAHAD_DTRSV
#define SAXPY  GALAHAD_SAXPY
#define SCOPY  GALAHAD_SCOPY
#define SGEMM  GALAHAD_SGEMM
#define SGEMV  GALAHAD_SGEMV
#define SGER   GALAHAD_SGER
#define SROT   GALAHAD_SROT
#define SROTG  GALAHAD_SROTG
#define SSCAL  GALAHAD_SSCAL
#define SSWAP  GALAHAD_SSWAP
#define SSYMM  GALAHAD_SSYMM
#define SSYMV  GALAHAD_SSYMV
#define SSYR   GALAHAD_SSYR
#define SSYR2  GALAHAD_SSYR2
#define SSYR2K GALAHAD_SSYR2K
#define SSYRK  GALAHAD_SSYRK
#define SSPMV  GALAHAD_SSPMV
#define STBSV  GALAHAD_STBSV
#define STPMV  GALAHAD_STPMV
#define STPSV  GALAHAD_STPSV
#define STRMM  GALAHAD_STRMM
#define STRMV  GALAHAD_STRMV
#define STRSM  GALAHAD_STRSM
#define STRSV  GALAHAD_STRSV
#define XERBLA GALAHAD_XERBLA
#define ZCOPY  GALAHAD_ZCOPY
#define ZDOTC  GALAHAD_ZDOTC
#define ZDSCAL GALAHAD_ZDSCAL
#define ZGEMM  GALAHAD_ZGEMM
#define ZGEMV  GALAHAD_ZGEMV
#define ZGERC  GALAHAD_ZGERC
#define ZGERU  GALAHAD_ZGERU
#define ZHER   GALAHAD_ZHER
#define ZSCAL  GALAHAD_ZSCAL
#define ZSWAP  GALAHAD_ZSWAP
#define ZTRMM  GALAHAD_ZTRMM
#define ZTRMV  GALAHAD_ZTRMV
#define ZTRSM  GALAHAD_ZTRSM
#endif
#else
#ifdef INTEGER_64
#ifdef NO_UNDERSCORE_INTEGER_64
#define DASUM  DASUM64
#define DCABS1 DCABS164
#define DDOT   DDOT64
#define DNRM2  DNRM264
#define DZNRM2 DZNRM264
#define IDAMAX IDAMAX64
#define ISAMAX ISAMAX64
#define LSAME  LSAME64
#define SASUM  SASUM64
#define SDOT   SDOT64
#define SNRM2  SNRM264
#define DAXPY  DAXPY64
#define DCOPY  DCOPY64
#define DGEMM  DGEMM64
#define DGEMV  DGEMV64
#define DGER   DGER64
#define DROT   DROT64
#define DROTG  DROTG64
#define DSCAL  DSCAL64
#define DSWAP  DSWAP64
#define DSYMM  DSYMM64
#define DSYMV  DSYMV64
#define DSYR   DSYR64
#define DSYR2  DSYR264
#define DSYR2K DSYR2K64
#define DSYRK  DSYRK64
#define DSPMV  DSPMV64
#define DTBSV  DTBSV64
#define DTPMV  DTPMV64
#define DTPSV  DTPSV64
#define DTRMM  DTRMM64
#define DTRMV  DTRMV64
#define DTRSM  DTRSM64
#define DTRSV  DTRSV64
#define SAXPY  SAXPY64
#define SCOPY  SCOPY64
#define SGEMM  SGEMM64
#define SGEMV  SGEMV64
#define SGER   SGER64
#define SROT   SROT64
#define SROTG  SROTG64
#define SSCAL  SSCAL64
#define SSWAP  SSWAP64
#define SSYMM  SSYMM64
#define SSYMV  SSYMV64
#define SSYR   SSYR64
#define SSYR2  SSYR264
#define SSYR2K SSYR2K64
#define SSYRK  SSYRK64
#define SSPMV  SSPMV64
#define STBSV  STBSV64
#define STPMV  STPMV64
#define STPSV  STPSV64
#define STRMM  STRMM64
#define STRMV  STRMV64
#define STRSM  STRSM64
#define STRSV  STRSV64
#define XERBLA XERBLA64
#define ZCOPY  ZCOPY64
#define ZDOTC  ZDOTC64
#define ZDSCAL ZDSCAL64
#define ZGEMM  ZGEMM64
#define ZGEMV  ZGEMV64
#define ZGERC  ZGERC64
#define ZGERU  ZGERU64
#define ZHER   ZHER64
#define ZSCAL  ZSCAL64
#define ZSWAP  ZSWAP64
#define ZTRMM  ZTRMM64
#define ZTRMV  ZTRMV64
#define ZTRSM  ZTRSM64
#elif DOUBLE_UNDERSCORE_INTEGER_64
#define DASUM  DASUM__64
#define DCABS1 DCABS1__64
#define DDOT   DDOT__64
#define DNRM2  DNRM2__64
#define DZNRM2 DZNRM2__64
#define IDAMAX IDAMAX__64
#define ISAMAX ISAMAX__64
#define LSAME  LSAME__64
#define SASUM  SASUM__64
#define SDOT   SDOT__64
#define SNRM2  SNRM2__64
#define DAXPY  DAXPY__64
#define DCOPY  DCOPY__64
#define DGEMM  DGEMM__64
#define DGEMV  DGEMV__64
#define DGER   DGER__64
#define DROT   DROT__64
#define DROTG  DROTG__64
#define DSCAL  DSCAL__64
#define DSWAP  DSWAP__64
#define DSYMM  DSYMM__64
#define DSYMV  DSYMV__64
#define DSYR   DSYR__64
#define DSYR2  DSYR2__64
#define DSYR2K DSYR2K__64
#define DSYRK  DSYRK__64
#define DSPMV  DSPMV__64
#define DTBSV  DTBSV__64
#define DTPMV  DTPMV__64
#define DTPSV  DTPSV__64
#define DTRMM  DTRMM__64
#define DTRMV  DTRMV__64
#define DTRSM  DTRSM__64
#define DTRSV  DTRSV__64
#define SAXPY  SAXPY__64
#define SCOPY  SCOPY__64
#define SGEMM  SGEMM__64
#define SGEMV  SGEMV__64
#define SGER   SGER__64
#define SROT   SROT__64
#define SROTG  SROTG__64
#define SSCAL  SSCAL__64
#define SSWAP  SSWAP__64
#define SSYMM  SSYMM__64
#define SSYMV  SSYMV__64
#define SSYR   SSYR__64
#define SSYR2  SSYR2__64
#define SSYR2K SSYR2K__64
#define SSYRK  SSYRK__64
#define SSPMV  SSPMV__64
#define STBSV  STBSV__64
#define STPMV  STPMV__64
#define STPSV  STPSV__64
#define STRMM  STRMM__64
#define STRMV  STRMV__64
#define STRSM  STRSM__64
#define STRSV  STRSV__64
#define XERBLA XERBLA__64
#define ZCOPY  ZCOPY__64
#define ZDOTC  ZDOTC__64
#define ZDSCAL ZDSCAL__64
#define ZGEMM  ZGEMM__64
#define ZGEMV  ZGEMV__64
#define ZGERC  ZGERC__64
#define ZGERU  ZGERU__64
#define ZHER   ZHER__64
#define ZSCAL  ZSCAL__64
#define ZSWAP  ZSWAP__64
#define ZTRMM  ZTRMM__64
#define ZTRMV  ZTRMV__64
#define ZTRSM  ZTRSM__64
#elif NO_SYMBOL_INTEGER_64
#else
#define DASUM  DASUM_64
#define DCABS1 DCABS1_64
#define DDOT   DDOT_64
#define DNRM2  DNRM2_64
#define DZNRM2 DZNRM2_64
#define IDAMAX IDAMAX_64
#define ISAMAX ISAMAX_64
#define LSAME  LSAME_64
#define SASUM  SASUM_64
#define SDOT   SDOT_64
#define SNRM2  SNRM2_64
#define DAXPY  DAXPY_64
#define DCOPY  DCOPY_64
#define DGEMM  DGEMM_64
#define DGEMV  DGEMV_64
#define DGER   DGER_64
#define DROT   DROT_64
#define DROTG  DROTG_64
#define DSCAL  DSCAL_64
#define DSWAP  DSWAP_64
#define DSYMM  DSYMM_64
#define DSYMV  DSYMV_64
#define DSYR   DSYR_64
#define DSYR2  DSYR2_64
#define DSYR2K DSYR2K_64
#define DSYRK  DSYRK_64
#define DSPMV  DSPMV_64
#define DTBSV  DTBSV_64
#define DTPMV  DTPMV_64
#define DTPSV  DTPSV_64
#define DTRMM  DTRMM_64
#define DTRMV  DTRMV_64
#define DTRSM  DTRSM_64
#define DTRSV  DTRSV_64
#define SAXPY  SAXPY_64
#define SCOPY  SCOPY_64
#define SGEMM  SGEMM_64
#define SGEMV  SGEMV_64
#define SGER   SGER_64
#define SROT   SROT_64
#define SROTG  SROTG_64
#define SSCAL  SSCAL_64
#define SSWAP  SSWAP_64
#define SSYMM  SSYMM_64
#define SSYMV  SSYMV_64
#define SSYR   SSYR_64
#define SSYR2  SSYR2_64
#define SSYR2K SSYR2K_64
#define SSYRK  SSYRK_64
#define SSPMV  SSPMV_64
#define STBSV  STBSV_64
#define STPMV  STPMV_64
#define STPSV  STPSV_64
#define STRMM  STRMM_64
#define STRMV  STRMV_64
#define STRSM  STRSM_64
#define STRSV  STRSV_64
#define XERBLA XERBLA_64
#define ZCOPY  ZCOPY_64
#define ZDOTC  ZDOTC_64
#define ZDSCAL ZDSCAL_64
#define ZGEMM  ZGEMM_64
#define ZGEMV  ZGEMV_64
#define ZGERC  ZGERC_64
#define ZGERU  ZGERU_64
#define ZHER   ZHER_64
#define ZSCAL  ZSCAL_64
#define ZSWAP  ZSWAP_64
#define ZTRMM  ZTRMM_64
#define ZTRMV  ZTRMV_64
#define ZTRSM  ZTRSM_64
#endif
#endif
#endif
