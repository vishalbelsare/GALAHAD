//* \file galahad.h */

/*! \mainpage GALAHAD C packages

  \section main_intro Introduction

  GALAHAD is foremost a modern fortran library of packages designed
  to solve continuous optimization problems, with a particular
  emphasis on those that involve a large number of unknowns.
  Since many application programs or applications are written in 
  other languages, of late there has been a considerable effort to
  provide interfaces to GALAHAD. Thus there are Matlab interfaces,
  and here we provide details of those to C using the standardized
  ISO C support now provided within fortran.

  \subsection main_authors Main authors
  N. I. M. Gould, STFC-Rutherford Appleton Laboratory, England, \n
  D. Orban, Ecole Polytechnique de Montreal, Canada, \n
  D. P. Robinson, Leheigh University, USA, and \n
  Ph. L. Toint, The University of Namur, Belgium.

  C interfaces, additionally J. Fowkes, STFC-Rutherford Appleton Laboratory.
  \section main_scope Scope

  GALAHAD provides packages as named for the following problems:

  \li lpa - linear programming using an active-set method
  \li lpb - linear programming using an interior-point method
  \li bqp - bound-constrained convex quadratic programming using 
      a gradient-projection method
  \li bqpb - bound-constrained convex quadratic programming using 
      an interor-point method
  \li \link cqp \endlink - convex quadratic programming using 
      an interor-point method
      \latexonly \href{cqp_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/cqp/cqp.html">(link)</a> \endhtmlonly
  \li dqp - convex quadratic programming using a dual active-set method
  \li \link trs \endlink - the trust-region subproblem using 
       matrix factorization
      \latexonly \href{trs_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/trs/trs.html">(link)</a> \endhtmlonly
  \li \link gltr  \endlink - the trust-region subproblem using 
       matrix-vector products
      \latexonly \href{gltr_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/gltr/gltr.html">(link)</a> \endhtmlonly
  \li \link rqs \endlink - the regularized quadratic subproblem 
      using matrix factorization
      \latexonly \href{rqs_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/rqs/rqs.html">(link)</a> \endhtmlonly
  \li \link glrt  \endlink - the regularized quadratic subproblem using 
       matrix-vector products
      \latexonly \href{glrt_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/glrt/glrt.html">(link)</a> \endhtmlonly
  \li qpb - general quadratic programming using an active-set method
  \li qpa - general quadratic programming using an interor-point method
  \li blls - bound-constrained linear-least-squares using
      a gradient-projection method
  \li bllsb - bound-constrained linear-least-squares using
      an interior-point method (in preparation)
  \li \link tru \endlink - unconstrained optimization using a trust-region 
      method 
      \latexonly \href{tru_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/tru/tru.html">(link)</a> \endhtmlonly
  \li \link arc \endlink - unconstrained optimization using a regularization 
      method 
      \latexonly \href{arc_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/arc/arc.html">(link)</a> \endhtmlonly
  \li \link nls \endlink - least-squares optimization using a regularization 
      method 
      \latexonly \href{nls_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/nls/nls.html">(link)</a> \endhtmlonly
  \li \link trb \endlink - bound-constrained optimization using a 
      gradient-projection trust-region method
      \latexonly \href{trb_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/trb/trb.html">(link)</a> \endhtmlonly
  \li nlsb - bound-constrained least-squares optimization 
      using a gradient-projection regularization method  (in preparation)
  \li lancelot - general constrained optimization using 
      an augmented Lagrangian method
  \li fisqp - general constrained optimization using an SQP method

  In addition, there are packages for solving a variety of required
  sub tasks, and most specifically interface routines to external
  solvers for solving linear equations:

  \li \link uls \endlink - unsymetric linear systems
      \latexonly \href{uls_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/uls/uls.html">(link)</a> \endhtmlonly
  \li \link sls \endlink - symetric linear systems
      \latexonly \href{sls_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/sls/sls.html">(link)</a> \endhtmlonly
  \li \link sbls \endlink - symetric block linear systems
      \latexonly \href{sbls_c.pdf}{(link)} \endlatexonly
      \htmlonly <a href="../../../html/C/sbls/sbls.html">(link)</a> \endhtmlonly

  C interfaces to all of these are underway, and each will be released 
  once it is ready. If \b you have a particular need, please let us know,
  and we will raise its priority!

  \section main_topics Further topics

  \subsection main_unsymmetric_matrices Unsymmetric matrix storage formats

  An unsymmetric \f$m\f$ by \f$n\f$ matrix \f$A\f$ may be presented and 
  stored in a variety of convenient input formats.

  Both C-style (0 based)  and fortran-style (1-based) indexing is allowed.
  Choose \c control.f_indexing as \c false for C style and \c true for 
  fortran style; the discussion below presumes C style, but add 1 to
  indices for the corresponding fortran version.

  Wrappers will automatically convert between 0-based (C) and 1-based
  (fortran) array indexing, so may be used transparently from C. This
  conversion involves both time and memory overheads that may be avoided
  by supplying data that is already stored using 1-based indexing. 

  \subsubsection unsymmetric_matrix_dense Dense storage format
  The matrix \f$A\f$ is stored as a compact  dense matrix by rows, that is, 
  the values of the entries of each row in turn are
  stored in order within an appropriate real one-dimensional array.
  In this case, component \f$n \ast i + j\f$  of the storage array A_val
  will hold the value \f$A_{ij}\f$ for \f$0 \leq i \leq m-1\f$, 
  \f$0 \leq j \leq n-1\f$.

  \subsubsection unsymmetric_matrix_dense Dense by columns storage format
  The matrix \f$A\f$ is stored as a compact  dense matrix by columns, that is, 
  the values of the entries of each column in turn are
  stored in order within an appropriate real one-dimensional array.
  In this case, component \f$m \ast j + i\f$  of the storage array A_val
  will hold the value \f$A_{ij}\f$ for \f$0 \leq i \leq m-1\f$, 
  \f$0 \leq j \leq n-1\f$.

  \subsubsection unsymmetric_matrix_coordinate Sparse co-ordinate storage format
  Only the nonzero entries of the matrices are stored.
  For the \f$l\f$-th entry, \f$0 \leq l \leq ne-1\f$, of \f$A\f$,
  its row index i, column index j 
  and value \f$A_{ij}\f$, 
  \f$0 \leq i \leq m-1\f$,  \f$0 \leq j \leq n-1\f$,  are stored as
  the \f$l\f$-th components of the integer arrays A_row and
  A_col and real array A_val, respectively, while the number of nonzeros
  is recorded as A_ne = \f$ne\f$.

  \subsubsection unsymmetric_matrix_row_wise Sparse row-wise storage format
  Again only the nonzero entries are stored, but this time
  they are ordered so that those in row i appear directly before those
  in row i+1. For the i-th row of \f$A\f$ the i-th component of the
  integer array A_ptr holds the position of the first entry in this row,
  while A_ptr(m) holds the total number of entries plus one.
  The column indices j, \f$0 \leq j \leq n-1\f$, and values 
  \f$A_{ij}\f$ of the  nonzero entries in the i-th row are stored in components
  l = A_ptr(i), \f$\ldots\f$, A_ptr(i+1)-1,  \f$0 \leq i \leq m-1\f$,
  of the integer array A_col, and real array A_val, respectively.
  For sparse matrices, this scheme almost always requires less storage than
  its predecessor.

  \subsubsection unsymmetric_matrix_column_wise Sparse column-wise storage format
  Once again only the nonzero entries are stored, but this time
  they are ordered so that those in column j appear directly before those
  in column j+1. For the j-th column of \f$A\f$ the j-th component of the
  integer array A_ptr holds the position of the first entry in this column,
  while A_ptr(n) holds the total number of entries plus one.
  The row indices i, \f$0 \leq i \leq m-1\f$, and values \f$A_{ij}\f$ 
  of the  nonzero entries in the j-th columnsare stored in components
  l = A_ptr(j), \f$\ldots\f$, A_ptr(j+1)-1, \f$0 \leq j \leq n-1\f$,
  of the integer array A_row, and real array A_val, respectively.
  As before, for sparse matrices, this scheme almost always requires less 
  storage than the co-ordinate format.

  \subsection main_symmetric_matrices Symmetric matrix storage formats

  Likewise, a symmetric \f$n\f$ by \f$n\f$ matrix \f$H\f$ may be presented 
  and stored in a variety of formats. But crucially symmetry is exploited 
  by only storing values from the lower triangular part 
  (i.e, those entries that lie on or below the leading diagonal).

  \subsubsection symmetric_matrix_dense Dense storage format
  The matrix \f$H\f$ is stored as a compact  dense matrix by rows, that is, 
  the values of the entries of each row in turn are
  stored in order within an appropriate real one-dimensional array.
  Since \f$H\f$ is symmetric, only the lower triangular part (that is the part
  \f$H_{ij}\f$ for \f$0 \leq j \leq i \leq n-1\f$) need be held. 
  In this case the lower triangle should be stored by rows, that is
  component \f$i \ast i / 2 + j\f$  of the storage array H_val
  will hold the value \f$H_{ij}\f$ (and, by symmetry, \f$h_{ji}\f$)
  for \f$0 \leq j \leq i \leq n-1\f$.

  \subsubsection symmetric_matrix_coordinate Sparse co-ordinate storage format
  Only the nonzero entries of the matrices are stored.
  For the \f$l\f$-th entry, \f$0 \leq l \leq ne-1\f$, of \f$H\f$,
  its row index i, column index j 
  and value \f$h_{ij}\f$, \f$0 \leq j \leq i \leq n-1\f$,  are stored as
  the \f$l\f$-th components of the integer arrays H_row and
  H_col and real array H_val, respectively, while the number of nonzeros
  is recorded as H_ne = \f$ne\f$.
  Note that only the entries in the lower triangle should be stored.

  \subsubsection symmetric_matrix_row_wise Sparse row-wise storage format
  Again only the nonzero entries are stored, but this time
  they are ordered so that those in row i appear directly before those
  in row i+1. For the i-th row of \f$H\f$ the i-th component of the
  integer array H_ptr holds the position of the first entry in this row,
  while H_ptr(n) holds the total number of entries plus one.
  The column indices j, \f$0 \leq j \leq i\f$, and values 
  \f$H_{ij}\f$ of the  entries in the i-th row are stored in components
  l = H_ptr(i), \f$\ldots\f$, H_ptr(i+1)-1 of the
  integer array H_col, and real array H_val, respectively.
  Note that as before only the entries in the lower triangle should be stored.
  For sparse matrices, this scheme almost always requires less storage than
  its predecessor.

  \subsubsection symmetric_matrix_diagonal Diagonal storage format
  If \f$H\f$ is diagonal (i.e., \f$h_{ij} = 0\f$ for all 
  \f$0 \leq i \neq j \leq n-1\f$) only the diagonals entries 
  \f$h_{ii}\f$, \f$0 \leq i \leq n-1\f$ need
  be stored, and the first n components of the array H_val may be
  used for the purpose.

  \subsubsection symmetric_matrix_scaled_identity Multiples of the identity storage format

  If \f$H\f$ is a multiple of the identity matrix, (i.e., \f$H = \alpha I\f$
  where \f$I\f$ is the n by n identity matrix and \f$\alpha\f$ is a scalar),
  it suffices to store \f$\alpha\f$ as the first component of H_val.

  \subsubsection symmetric_matrix_identity The identity matrix format

  If \f$H\f$ is the identity matrix, no values need be stored.

  \subsubsection symmetric_matrix_zero The zero matrix format

  The same is true if \f$H\f$ is the zero matrix.
*/
