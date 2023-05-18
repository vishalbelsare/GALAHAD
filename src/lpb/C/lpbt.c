/* lpbt.c */
/* Full test for the LPB C interface using C sparse matrix indexing */

#include <stdio.h>
#include <math.h>
#include "galahad_precision.h"
#include "galahad_cfunctions.h"
#include "galahad_lpb.h"

int main(void) {

    // Derived types
    void *data;
    struct lpb_control_type control;
    struct lpb_inform_type inform;

    // Set problem data
    int n = 3; // dimension
    int m = 2; // number of general constraints
    real_wp_ g[] = {0.0, 2.0, 0.0};   // linear term in the objective
    real_wp_ f = 1.0;  // constant term in the objective
    int A_ne = 4; // Jacobian elements
    int A_row[] = {0, 0, 1, 1}; // row indices
    int A_col[] = {0, 1, 1, 2}; // column indices
    int A_ptr[] = {0, 2, 4}; // row pointers
    real_wp_ A_val[] = {2.0, 1.0, 1.0, 1.0 }; // values
    real_wp_ c_l[] = {1.0, 2.0};   // constraint lower bound
    real_wp_ c_u[] = {2.0, 2.0};   // constraint upper bound
    real_wp_ x_l[] = {-1.0, - INFINITY, - INFINITY}; // variable lower bound
    real_wp_ x_u[] = {1.0, INFINITY, 2.0}; // variable upper bound

    // Set output storage
    real_wp_ c[m]; // constraint values
    int x_stat[n]; // variable status
    int c_stat[m]; // constraint status
    char st;
    int status;

    printf(" C sparse matrix indexing\n\n");

    printf(" basic tests of lp storage formats\n\n");

    for( int d=1; d <= 3; d++){

        // Initialize LPB
        lpb_initialize( &data, &control, &status );

        // Set user-defined control options
        control.f_indexing = false; // C sparse matrix indexing

        // Start from 0
        real_wp_ x[] = {0.0,0.0,0.0};
        real_wp_ y[] = {0.0,0.0};
        real_wp_ z[] = {0.0,0.0,0.0};

        switch(d){
            case 1: // sparse co-ordinate storage
                st = 'C';
                lpb_import( &control, &data, &status, n, m,
                           "coordinate", A_ne, A_row, A_col, NULL );
                lpb_solve_lp( &data, &status, n, m, g, f,
                              A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                              x_stat, c_stat );
                break;
            printf(" case %1i break\n",d);
            case 2: // sparse by rows
                st = 'R';
                lpb_import( &control, &data, &status, n, m,
                            "sparse_by_rows", A_ne, NULL, A_col, A_ptr );
                lpb_solve_lp( &data, &status, n, m, g, f,
                              A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                              x_stat, c_stat );
                break;
            case 3: // dense
                st = 'D';
                int A_dense_ne = 6; // number of elements of A
                real_wp_ A_dense[] = {2.0, 1.0, 0.0, 0.0, 1.0, 1.0};
                lpb_import( &control, &data, &status, n, m,
                            "dense", A_ne, NULL, NULL, NULL );
                lpb_solve_lp( &data, &status, n, m, g, f,
                              A_dense_ne, A_dense, c_l, c_u, x_l, x_u,
                              x, c, y, z, x_stat, c_stat );
                break;
            }
        lpb_information( &data, &inform, &status );

        if(inform.status == 0){
            printf("%c:%6i iterations. Optimal objective value = %5.2f status = %1i\n",
                   st, inform.iter, inform.obj, inform.status);
        }else{
            printf("%c: LPB_solve exit status = %1i\n", st, inform.status);
        }
        //printf("x: ");
        //for( int i = 0; i < n; i++) printf("%f ", x[i]);
        //printf("\n");
        //printf("gradient: ");
        //for( int i = 0; i < n; i++) printf("%f ", g[i]);
        //printf("\n");

        // Delete internal workspace
        lpb_terminate( &data, &control, &inform );
    }
}
