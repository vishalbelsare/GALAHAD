/* dgotf.c */
/* Full test for the DGO C interface using Fortran sparse matrix indexing */

#include <stdio.h>
#include <math.h>
#include <string.h>
#include "galahad_precision.h"
#include "galahad_cfunctions.h"
#include "galahad_dgo.h"

// Custom userdata struct
struct userdata_type {
   rpc_ p;
   rpc_ freq;
   rpc_ mag;
};

// Function prototypes
ipc_ fun( ipc_ n, const rpc_ x[], rpc_ *f, const void * );
ipc_ grad( ipc_ n, const rpc_ x[], rpc_ g[], const void * );
ipc_ hess( ipc_ n, ipc_ ne, const rpc_ x[], rpc_ hval[], const void * );
ipc_ hess_dense( ipc_ n, ipc_ ne, const rpc_ x[], rpc_ hval[],
                 const void * );
ipc_ hessprod( ipc_ n, const rpc_ x[], rpc_ u[], const rpc_ v[],
               bool got_h, const void * );
ipc_ shessprod( ipc_ n, const rpc_ x[], ipc_ nnz_v, const ipc_ index_nz_v[],
                const rpc_ v[], ipc_ *nnz_u, ipc_ index_nz_u[], 
                rpc_ u[], bool got_h, const void * );
ipc_ prec( ipc_ n, const rpc_ x[], rpc_ u[], const rpc_ v[],
           const void * );
ipc_ fun_diag( ipc_ n, const rpc_ x[], rpc_ *f, const void * );
ipc_ grad_diag( ipc_ n, const rpc_ x[], rpc_ g[], const void * );
ipc_ hess_diag( ipc_ n, ipc_ ne, const rpc_ x[], rpc_ hval[],
               const void * );
ipc_ hessprod_diag( ipc_ n, const rpc_ x[], rpc_ u[], 
                    const rpc_ v[], bool got_h, const void * );
ipc_ shessprod_diag( ipc_ n, const rpc_ x[], ipc_ nnz_v,
                     const ipc_ index_nz_v[],
                     const rpc_ v[], ipc_ *nnz_u, ipc_ index_nz_u[],
                     rpc_ u[], bool got_h, const void * );

int main(void) {

    // Derived types
    void *data;
    struct dgo_control_type control;
    struct dgo_inform_type inform;

    // Set user data
    struct userdata_type userdata;
    userdata.p = 4.0;
    userdata.freq = 10;
    userdata.mag = 1000;

    // Set problem data
    ipc_ n = 3; // dimension
    ipc_ ne = 5; // Hesssian elements
    rpc_ x_l[] = {-10,-10,-10};
    rpc_ x_u[] = {0.5,0.5,0.5};
    ipc_ H_row[] = {1, 2, 3, 3, 3}; // Hessian H
    ipc_ H_col[] = {1, 2, 1, 2, 3}; // NB lower triangle
    ipc_ H_ptr[] = {1, 2, 3, 6};    // row pointers

    // Set storage
    rpc_ g[n]; // gradient
    char st = ' ';
    ipc_ status;

    printf(" Fortran sparse matrix indexing\n\n");

    printf(" tests options for all-in-one storage format\n\n");

    for(ipc_ d=1; d <= 5; d++){

        // Initialize DGO
        dgo_initialize( &data, &control, &status );
        strcpy(control.trb_control.trs_control.symmetric_linear_solver,"sytr ");
        strcpy(control.trb_control.trs_control.definite_linear_solver,"potr ");
        strcpy(control.trb_control.psls_control.definite_linear_solver,"potr ");

        // Set user-defined control options
        control.f_indexing = true; // Fortran sparse matrix indexing
        control.maxit = 2500;
        // control.trb_control.maxit = 100;
        //control.print_level = 1;

        // Start from 0
        rpc_ x[] = {0,0,0};

        switch(d){
            case 1: // sparse co-ordinate storage
                st = 'C';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "coordinate", ne, H_row, H_col, NULL );
                dgo_solve_with_mat( &data, &userdata, &status, n, x, g,
                                    ne, fun, grad, hess, hessprod, prec );
                break;
            case 2: // sparse by rows
                st = 'R';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "sparse_by_rows", ne, NULL, H_col, H_ptr );
                dgo_solve_with_mat( &data, &userdata, &status, n, x, g,
                                    ne, fun, grad, hess, hessprod, prec );
                break;
            case 3: // dense
                st = 'D';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "dense", ne, NULL, NULL, NULL );
                dgo_solve_with_mat( &data, &userdata, &status, n, x, g,
                                    ne, fun, grad, hess_dense, hessprod, prec );
                break;
            case 4: // diagonal
                st = 'I';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "diagonal", ne, NULL, NULL, NULL );
                dgo_solve_with_mat( &data, &userdata, &status, n, x, g,
                                    ne, fun_diag, grad_diag, hess_diag,
                                    hessprod_diag, prec );
                break;
            case 5: // access by products
                st = 'P';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "absent", ne, NULL, NULL, NULL );
                dgo_solve_without_mat( &data, &userdata, &status, n, x, g,
                                       fun, grad, hessprod, shessprod, prec );
                break;
        }

        // Record solution information
        dgo_information( &data, &inform, &status );

        if(inform.status == 0){
            printf("%c:%6" i_ipc_ " evaluations. Optimal objective value = %5.2f"
              " status = %1" i_ipc_ "\n", st, inform.f_eval, inform.obj, inform.status);
        }else if(inform.status == -18){
            printf("%c:%6" i_ipc_ " evaluations. Best objective value = %5.2f"
              " status = %1" i_ipc_ "\n", st, inform.f_eval, inform.obj, inform.status);
        }else{
            printf("%c: DGO_solve exit status = %1" i_ipc_ "\n", st, inform.status);
        }
        //printf("x: ");
        //for(ipc_ i = 0; i < n; i++) printf("%f ", x[i]);
        //printf("\n");
        //printf("gradient: ");
        //for(ipc_ i = 0; i < n; i++) printf("%f ", g[i]);
        //printf("\n");

        // Delete internal workspace
        dgo_terminate( &data, &control, &inform );
    }

    printf("\n tests reverse-communication options\n\n");

    // reverse-communication input/output
    ipc_ eval_status, nnz_u, nnz_v;
    rpc_ f = 0.0;
    rpc_ u[n], v[n];
    ipc_ index_nz_u[n], index_nz_v[n];
    rpc_ H_val[ne], H_dense[n*(n+1)/2], H_diag[n];

    for(ipc_ d=1; d <= 5; d++){

        // Initialize DGO
        dgo_initialize( &data, &control, &status );
        strcpy(control.trb_control.trs_control.symmetric_linear_solver,"sytr ");
        strcpy(control.trb_control.trs_control.definite_linear_solver,"potr ");
        strcpy(control.trb_control.psls_control.definite_linear_solver,"potr ");

        // Set user-defined control options
        control.f_indexing = true; // Fortran sparse matrix indexing
        control.maxit = 2500;
        // control.trb_control.maxit = 100;
        //control.print_level = 1;

        // Start from 0
        rpc_ x[] = {0,0,0};
        switch(d){
            case 1: // sparse co-ordinate storage
                st = 'C';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "coordinate", ne, H_row, H_col, NULL );
                while(true){ // reverse-communication loop
                    dgo_solve_reverse_with_mat( &data, &status, &eval_status,
                                                n, x, f, g, ne, H_val, u, v );
                    if(status == 0){ // successful termination
                        break;
                    }else if(status < 0){ // error exit
                        break;
                    }else if(status == 2){ // evaluate f
                        eval_status = fun( n, x, &f, &userdata );
                    }else if(status == 3){ // evaluate g
                        eval_status = grad( n, x, g, &userdata );
                    }else if(status == 4){ // evaluate H
                        eval_status = hess( n, ne, x, H_val, &userdata );
                    }else if(status == 5){ // evaluate Hv product
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 6){ // evaluate the product with P
                        eval_status = prec( n, x, u, v, &userdata );
                    }else if(status == 23){ // evaluate f and g
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = grad( n, x, g, &userdata );
                    }else if(status == 25){ // evaluate f and Hv product
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 35){ // evaluate g and Hv product
                        eval_status = grad( n, x, g, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 235){ // evaluate f, g and Hv product
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = grad( n, x, g, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else{
                        printf(" the value %1" i_ipc_ " of status should not occur\n",
                               status );
                        break;
                    }
                }
                break;
            case 2: // sparse by rows
                st = 'R';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "sparse_by_rows", ne, NULL, H_col, H_ptr );
                while(true){ // reverse-communication loop
                    dgo_solve_reverse_with_mat( &data, &status, &eval_status,
                                                n, x, f, g, ne, H_val, u, v );
                    if(status == 0){ // successful termination
                        break;
                    }else if(status < 0){ // error exit
                        break;
                    }else if(status == 2){ // evaluate f
                        eval_status = fun( n, x, &f, &userdata );
                    }else if(status == 3){ // evaluate g
                        eval_status = grad( n, x, g, &userdata );
                    }else if(status == 4){ // evaluate H
                        eval_status = hess( n, ne, x, H_val, &userdata );
                    }else if(status == 5){ // evaluate Hv product
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 6){ // evaluate the product with P
                        eval_status = prec( n, x, u, v, &userdata );
                    }else if(status == 23){ // evaluate f and g
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = grad( n, x, g, &userdata );
                    }else if(status == 25){ // evaluate f and Hv product
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 35){ // evaluate g and Hv product
                        eval_status = grad( n, x, g, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 235){ // evaluate f, g and Hv product
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = grad( n, x, g, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else{
                        printf(" the value %1" i_ipc_ " of status should not occur\n",
                               status);
                        break;
                    }
                }
                break;
            case 3: // dense
                st = 'D';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "dense", ne, NULL, NULL, NULL );
                while(true){ // reverse-communication loop
                    dgo_solve_reverse_with_mat( &data, &status, &eval_status,
                                                n, x, f, g, n*(n+1)/2,
                                                H_dense, u, v );
                    if(status == 0){ // successful termination
                        break;
                    }else if(status < 0){ // error exit
                        break;
                    }else if(status == 2){ // evaluate f
                        eval_status = fun( n, x, &f, &userdata );
                    }else if(status == 3){ // evaluate g
                        eval_status = grad( n, x, g, &userdata );
                    }else if(status == 4){ // evaluate H
                        eval_status = hess_dense( n, n*(n+1)/2, x, H_dense,
                                                  &userdata );
                    }else if(status == 5){ // evaluate Hv product
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 6){ // evaluate the product with P
                        eval_status = prec( n, x, u, v, &userdata );
                    }else if(status == 23){ // evaluate f and g
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = grad( n, x, g, &userdata );
                    }else if(status == 25){ // evaluate f and Hv product
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 35){ // evaluate g and Hv product
                        eval_status = grad( n, x, g, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 235){ // evaluate f, g and Hv product
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = grad( n, x, g, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else{
                        printf(" the value %1" i_ipc_ " of status should not occur\n",
                               status);
                        break;
                    }
                }
                break;
            case 4: // diagonal
                st = 'I';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "diagonal", ne, NULL, NULL, NULL );
                while(true){ // reverse-communication loop
                    dgo_solve_reverse_with_mat( &data, &status, &eval_status,
                                                n, x, f, g, n, H_diag, u, v );
                    if(status == 0){ // successful termination
                        break;
                    }else if(status < 0){ // error exit
                        break;
                    }else if(status == 2){ // evaluate f
                        eval_status = fun_diag( n, x, &f, &userdata );
                    }else if(status == 3){ // evaluate g
                        eval_status = grad_diag( n, x, g, &userdata );
                    }else if(status == 4){ // evaluate H
                        eval_status = hess_diag( n, n, x, H_diag, &userdata );
                    }else if(status == 5){ // evaluate Hv product
                        eval_status = hessprod_diag( n, x, u, v, false,
                                                     &userdata );
                    }else if(status == 6){ // evaluate the product with P
                        eval_status = prec( n, x, u, v, &userdata );
                    }else if(status == 23){ // evaluate f and g
                        eval_status = fun_diag( n, x, &f, &userdata );
                        eval_status = grad_diag( n, x, g, &userdata );
                    }else if(status == 25){ // evaluate f and Hv product
                        eval_status = fun_diag( n, x, &f, &userdata );
                        eval_status = hessprod_diag( n, x, u, v, false,
                                                     &userdata );
                    }else if(status == 35){ // evaluate g and Hv product
                        eval_status = grad_diag( n, x, g, &userdata );
                        eval_status = hessprod_diag( n, x, u, v, false,
                                                     &userdata );
                    }else if(status == 235){ // evaluate f, g and Hv product
                        eval_status = fun_diag( n, x, &f, &userdata );
                        eval_status = grad_diag( n, x, g, &userdata );
                        eval_status = hessprod_diag( n, x, u, v, false,
                                                     &userdata );
                    }else{
                        printf(" the value %1" i_ipc_ " of status should not occur\n",
                               status);
                        break;
                    }
                }
                break;
            case 5: // access by products
                st = 'P';
                dgo_import( &control, &data, &status, n, x_l, x_u,
                            "absent", ne, NULL, NULL, NULL );
                nnz_u = 0;
                while(true){ // reverse-communication loop
                    dgo_solve_reverse_without_mat( &data, &status, &eval_status,
                                                   n, x, f, g, u, v, index_nz_v,
                                                   &nnz_v, index_nz_u, nnz_u );
                    if(status == 0){ // successful termination
                        break;
                    }else if(status < 0){ // error exit
                        break;
                    }else if(status == 2){ // evaluate f
                        eval_status = fun( n, x, &f, &userdata );
                    }else if(status == 3){ // evaluate g
                        eval_status = grad( n, x, g, &userdata );
                    }else if(status == 5){ // evaluate Hv product
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 6){ // evaluate the product with P
                        eval_status = prec( n, x, u, v, &userdata );
                    }else if(status == 7){ // evaluate sparse Hess-vect product
                        eval_status = shessprod( n, x, nnz_v, index_nz_v, v,
                                                 &nnz_u, index_nz_u, u,
                                                 false, &userdata );
                    }else if(status == 23){ // evaluate f and g
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = grad( n, x, g, &userdata );
                    }else if(status == 25){ // evaluate f and Hv product
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 35){ // evaluate g and Hv product
                        eval_status = grad( n, x, g, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else if(status == 235){ // evaluate f, g and Hv product
                        eval_status = fun( n, x, &f, &userdata );
                        eval_status = grad( n, x, g, &userdata );
                        eval_status = hessprod( n, x, u, v, false, &userdata );
                    }else{
                        printf(" the value %1" i_ipc_ " of status should not occur\n",
                               status);
                        break;
                    }
                }
                break;
        }

        // Record solution information
        dgo_information( &data, &inform, &status );

        if(inform.status == 0){
            printf("%c:%6" i_ipc_ " evaluations. Optimal objective value = %5.2f"
              " status = %1" i_ipc_ "\n", st, inform.f_eval, inform.obj, inform.status);
        }else if(inform.status == -18){
            printf("%c:%6" i_ipc_ " evaluations. Best objective value = %5.2f"
              " status = %1" i_ipc_ "\n", st, inform.f_eval, inform.obj, inform.status);
        }else{
            printf("%c: DGO_solve exit status = %1" i_ipc_ "\n", st, inform.status);
        }
        //printf("x: ");
        //for(ipc_ i = 0; i < n; i++) printf("%f ", x[i]);
        //printf("\n");
        //printf("gradient: ");
        //for(ipc_ i = 0; i < n; i++) printf("%f ", g[i]);
        //printf("\n");

        // Delete internal workspace
        dgo_terminate( &data, &control, &inform );
    }

}

// Objective function
ipc_ fun( ipc_ n,
         const rpc_ x[],
         rpc_ *f,
         const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ p = myuserdata->p;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    *f = pow(x[0] + x[2] + p, 2) + pow(x[1] + x[2], 2) + mag * cos(freq*x[0])
         + x[0] + x[1] + x[2];
    return 0;
}

// Gradient of the objective
ipc_ grad( ipc_ n,
          const rpc_ x[],
          rpc_ g[],
          const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ p = myuserdata->p;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    g[0] = 2.0 * ( x[0] + x[2] + p ) - mag * freq * sin(freq*x[0]) + 1;
    g[1] = 2.0 * ( x[1] + x[2] ) + 1;
    g[2] = 2.0 * ( x[0] + x[2] + p ) + 2.0 * ( x[1] + x[2] ) + 1;
    return 0;
}

// Hessian of the objective
ipc_ hess( ipc_ n,
          ipc_ ne,
          const rpc_ x[],
          rpc_ hval[],
          const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    hval[0] = 2.0 - mag * freq * freq * cos(freq*x[0]);
    hval[1] = 2.0;
    hval[2] = 2.0;
    hval[3] = 2.0;
    hval[4] = 4.0;
    return 0;
}

// Dense Hessian
ipc_ hess_dense( ipc_ n,
                ipc_ ne,
                const rpc_ x[],
                rpc_ hval[],
                const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    hval[0] = 2.0 - mag * freq * freq * cos(freq*x[0]);
    hval[1] = 0.0;
    hval[2] = 2.0;
    hval[3] = 2.0;
    hval[4] = 2.0;
    hval[5] = 4.0;
    return 0;
}

// Hessian-vector product
ipc_ hessprod( ipc_ n,
              const rpc_ x[],
              rpc_ u[],
              const rpc_ v[],
              bool got_h,
              const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    u[0] = u[0] + 2.0 * ( v[0] + v[2] )
           - mag * freq * freq * cos(freq*x[0]) * v[0];
    u[1] = u[1] + 2.0 * ( v[1] + v[2] );
    u[2] = u[2] + 2.0 * ( v[0] + v[1] + 2.0 * v[2] );
    return 0;
}

// Sparse Hessian-vector product
ipc_ shessprod( ipc_ n,
               const rpc_ x[],
               ipc_ nnz_v,
               const ipc_ index_nz_v[],
               const rpc_ v[],
               ipc_ *nnz_u,
               ipc_ index_nz_u[],
               rpc_ u[],
               bool got_h,
               const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    rpc_ p[] = {0., 0., 0.};
    bool used[] = {false, false, false};
    for(ipc_ i = 0; i < nnz_v; i++){
        ipc_ j = index_nz_v[i];
        switch(j){
            case 1:
                p[0] = p[0] + 2.0 * v[0]
                     - mag * freq * freq * cos(freq*x[0]) * v[0];
                used[0] = true;
                p[2] = p[2] + 2.0 * v[0];
                used[2] = true;
                break;
            case 2:
                p[1] = p[1] + 2.0 * v[1];
                used[1] = true;
                p[2] = p[2] + 2.0 * v[1];
                used[2] = true;
                break;
            case 3:
                p[0] = p[0] + 2.0 * v[2];
                used[0] = true;
                p[1] = p[1] + 2.0 * v[2];
                used[1] = true;
                p[2] = p[2] + 4.0 * v[2];
                used[2] = true;
                break;
        }
    }
    *nnz_u = 0;
    for(ipc_ j = 0; j < 3; j++){
        if(used[j]){
        u[j] = p[j];
        *nnz_u = *nnz_u + 1;
        index_nz_u[*nnz_u-1] = j+1;
        }
    }
    return 0;
}

// Apply preconditioner
ipc_ prec( ipc_ n,
          const rpc_ x[],
          rpc_ u[],
          const rpc_ v[],
          const void *userdata ){
   u[0] = 0.5 * v[0];
   u[1] = 0.5 * v[1];
   u[2] = 0.25 * v[2];
   return 0;
}

// Objective function
ipc_ fun_diag( ipc_ n,
              const rpc_ x[],
              rpc_ *f,
              const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ p = myuserdata->p;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    *f = pow(x[2] + p, 2) + pow(x[1], 2) + mag * cos(freq*x[0])
         + x[0] + x[1] + x[2];
    return 0;
}

// Gradient of the objective
ipc_ grad_diag( ipc_ n,
               const rpc_ x[],
               rpc_ g[],
               const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ p = myuserdata->p;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    g[0] = -mag * freq * sin(freq*x[0]) + 1;
    g[1] = 2.0 * x[1] + 1;
    g[2] = 2.0 * ( x[2] + p ) + 1;
    return 0;
}

// Hessian of the objective
ipc_ hess_diag( ipc_ n,
               ipc_ ne,
               const rpc_ x[],
               rpc_ hval[],
               const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    hval[0] = -mag * freq * freq * cos(freq*x[0]);
    hval[1] = 2.0;
    hval[2] = 2.0;
    return 0;
}

// Hessian-vector product
ipc_ hessprod_diag( ipc_ n,
                   const rpc_ x[],
                   rpc_ u[],
                   const rpc_ v[],
                   bool got_h,
                   const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    u[0] = u[0] + -mag * freq * freq * cos(freq*x[0]) * v[0];
    u[1] = u[1] + 2.0 * v[1];
    u[2] = u[2] + 2.0 * v[2];
    return 0;
}

// Sparse Hessian-vector product
ipc_ shessprod_diag( ipc_ n,
                    const rpc_ x[],
                    ipc_ nnz_v,
                    const ipc_ index_nz_v[],
                    const rpc_ v[],
                    ipc_ *nnz_u,
                    ipc_ index_nz_u[],
                    rpc_ u[],
                    bool got_h,
                    const void *userdata ){
    struct userdata_type *myuserdata = (struct userdata_type *) userdata;
    rpc_ freq = myuserdata->freq;
    rpc_ mag = myuserdata->mag;

    rpc_ p[] = {0., 0., 0.};
    bool used[] = {false, false, false};
    for(ipc_ i = 0; i < nnz_v; i++){
        ipc_ j = index_nz_v[i];
        switch(j){
            case 1:
                p[0] = p[0] - mag * freq * freq * cos(freq*x[0]) * v[0];
                used[0] = true;
                break;
            case 2:
                p[1] = p[1] + 2.0 * v[1];
                used[1] = true;
                break;
            case 3:
                p[2] = p[2] + 2.0 * v[2];
                used[2] = true;
                break;
        }
    }
    *nnz_u = 0;
    for(ipc_ j = 0; j < 3; j++){
        if(used[j]){
        u[j] = p[j];
        *nnz_u = *nnz_u + 1;
        index_nz_u[*nnz_u-1] = j+1;
        }
    }
    return 0;
}
