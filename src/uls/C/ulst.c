/* ulst.c */
/* Full test for the ULS C interface using C sparse matrix indexing */

#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <float.h>
#include "galahad_precision.h"
#include "galahad_cfunctions.h"
#include "galahad_uls.h"

ipc_ maxabsarray(real_wp_ a[], ipc_ n, real_wp_ *maxabs);

int main(void) {

    // Derived types
    void *data;
    struct uls_control_type control;
    struct uls_inform_type inform;

    // Set problem data
    ipc_ m = 5; // column dimension of A
    ipc_ n = 5; // column dimension of A
    ipc_ ne = 7; // number of entries of A
    ipc_ dense_ne = 25; // number of elements of A as a dense matrix
    ipc_ row[] = {0, 1, 1, 2, 2, 3, 4}; // row indices
    ipc_ col[] = {0, 0, 4, 1, 2, 2, 3}; // column indices
    ipc_ ptr[] = {0, 1, 3, 5, 6, 7}; // pointers to indices
    real_wp_ val[] = {2.0, 3.0, 6.0, 4.0, 1.0, 5.0, 1.0}; // values
    real_wp_ dense[] = {2.0, 0.0, 0.0, 0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 6.0,
                      0.0, 4.0, 1.0, 0.0, 0.0, 0.0, 0.0, 5.0, 0.0, 0.0,
                      0.0, 0.0, 0.0, 1.0, 0.0};
    real_wp_ rhs[] = {2.0, 33.0, 11.0, 15.0, 4.0};
    real_wp_ rhst[] = {8.0, 12.0, 23.0, 5.0, 12.0};
    real_wp_ sol[] = {1.0, 2.0, 3.0, 4.0, 5.0};
    ipc_ i, status;
    real_wp_ x[n];
    real_wp_ error[n];
    _Bool trans;

    real_wp_ norm_residual;
    real_wp_ good_x = pow( DBL_EPSILON, 0.3333 );

    printf(" C sparse matrix indexing\n\n");

    printf(" basic tests of storage formats\n\n");

    printf(" storage          RHS   refine   RHST  refine\n");

    for( ipc_ d=1; d <= 3; d++){
        // Initialize ULS - use the gls solver
        uls_initialize( "getr", &data, &control, &status );

        // Set user-defined control options
        control.f_indexing = false; // Fortran sparse matrix indexing

        switch(d){ // import matrix data and factorize
            case 1: // sparse co-ordinate storage
                printf(" coordinate     ");
                uls_factorize_matrix( &control, &data, &status, m, n,
                                    "coordinate", ne, val, row, col, NULL );
                break;
            case 2: // sparse by rows
                printf(" sparse by rows ");
                uls_factorize_matrix( &control, &data, &status, m, n,
                                    "sparse_by_rows", ne, val, NULL, col, ptr );
                break;
            case 3: // dense
                printf(" dense          ");
                uls_factorize_matrix( &control, &data, &status, m, n, "dense",
                                      dense_ne, dense, NULL, NULL, NULL );
                break;
            }

        // Set right-hand side and solve the system A x = b
        for(i=0; i<n; i++) x[i] = rhs[i];
        trans = false;
        uls_solve_system( &data, &status, m, n, x, trans );
        uls_information( &data, &inform, &status );

        if(inform.status == 0){
          for(i=0; i<n; i++) error[i] = x[i]-sol[i];
          status = maxabsarray( error, n, &norm_residual );
          if(norm_residual < good_x){
            printf("   ok  ");
          }else{
            printf("  fail ");
          }
        }else{
            printf(" ULS_solve exit status = %1i\n", inform.status);
        }
        // printf("sol: ");
        // for( ipc_ i = 0; i < n; i++) printf("%f ", x[i]);

        // resolve, this time using iterative refinement
        control.max_iterative_refinements = 1;
        uls_reset_control( &control, &data, &status );
        for(i=0; i<n; i++) x[i] = rhs[i];
        uls_solve_system( &data, &status, m, n, x, trans );
        uls_information( &data, &inform, &status );

        if(inform.status == 0){
          for(i=0; i<n; i++) error[i] = x[i]-sol[i];
          status = maxabsarray( error, n, &norm_residual );
          if(norm_residual < good_x){
            printf("    ok  ");
          }else{
            printf("   fail ");
          }
        }else{
            printf(" ULS_solve exit status = %1i\n", inform.status);
        }

        // Set right-hand side and solve the system A^T x = b
        for(i=0; i<n; i++) x[i] = rhst[i];
        trans = true;
        uls_solve_system( &data, &status, m, n, x, trans );
        uls_information( &data, &inform, &status );

        if(inform.status == 0){
          for(i=0; i<n; i++) error[i] = x[i]-sol[i];
          status = maxabsarray( error, n, &norm_residual );
          if(norm_residual < good_x){
            printf("   ok  ");
          }else{
            printf("  fail ");
          }
        }else{
            printf(" ULS_solve exit status = %1i\n", inform.status);
        }
        // printf("sol: ");
        // for( ipc_ i = 0; i < n; i++) printf("%f ", x[i]);

        // resolve, this time using iterative refinement
        control.max_iterative_refinements = 1;
        uls_reset_control( &control, &data, &status );
        for(i=0; i<n; i++) x[i] = rhst[i];
        uls_solve_system( &data, &status, m, n, x, trans );
        uls_information( &data, &inform, &status );

        if(inform.status == 0){
          for(i=0; i<n; i++) error[i] = x[i]-sol[i];
          status = maxabsarray( error, n, &norm_residual );
          if(norm_residual < good_x){
            printf("    ok  ");
          }else{
            printf("   fail ");
          }
        }else{
            printf(" ULS_solve exit status = %1i\n", inform.status);
        }

        // Delete internal workspace
        uls_terminate( &data, &control, &inform );
        printf("\n");
    }
}

ipc_ maxabsarray(real_wp_ a[], ipc_ n, real_wp_ *maxabs)
 {
    ipc_ i;
    real_wp_ b, max;
    max=abs(a[0]);
    for(i=1; i<n; i++)
    {
        b = fabs(a[i]);
	if(max<b)
          max=b;
    }
    *maxabs=max;
 }
