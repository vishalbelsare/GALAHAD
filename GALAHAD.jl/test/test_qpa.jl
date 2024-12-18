# test_qpa.jl
# Simple code to test the Julia interface to QPA

using GALAHAD
using Test
using Printf
using Accessors
using Quadmath

function test_qpa(::Type{T}) where T
  # Derived types
  data = Ref{Ptr{Cvoid}}()
  control = Ref{qpa_control_type{T}}()
  inform = Ref{qpa_inform_type{T}}()

  # Set problem data
  n = 3 # dimension
  m = 2 # number of general constraints
  H_ne = 3 # Hesssian elements
  H_row = Cint[1, 2, 3]  # row indices, NB lower triangle
  H_col = Cint[1, 2, 3]  # column indices, NB lower triangle
  H_ptr = Cint[1, 2, 3, 4]  # row pointers
  H_val = T[1.0, 1.0, 1.0]  # values
  g = T[0.0, 2.0, 0.0]  # linear term in the objective
  f = one(T)  # constant term in the objective
  rho_g = T(0.1)  # penalty paramter for general constraints
  rho_b = T(0.1)  # penalty paramter for simple bound constraints
  A_ne = 4 # Jacobian elements
  A_row = Cint[1, 1, 2, 2]  # row indices
  A_col = Cint[1, 2, 2, 3]  # column indices
  A_ptr = Cint[1, 3, 5]  # row pointers
  A_val = T[2.0, 1.0, 1.0, 1.0]  # values
  c_l = T[1.0, 2.0]  # constraint lower bound
  c_u = T[2.0, 2.0]  # constraint upper bound
  x_l = T[-1.0, -Inf, -Inf]  # variable lower bound
  x_u = T[1.0, Inf, 2.0]  # variable upper bound

  # Set output storage
  c = zeros(T, m) # constraint values
  x_stat = zeros(Cint, n) # variable status
  c_stat = zeros(Cint, m) # constraint status
  st = ' '
  status = Ref{Cint}()

  @printf(" Fortran sparse matrix indexing\n\n")
  @printf(" basic tests of qp storage formats\n\n")

  for d in 1:7
    # Initialize QPA
    qpa_initialize(T, data, control, status)

    # Set user-defined control options
    @reset control[].f_indexing = true # Fortran sparse matrix indexing

    # Start from 0
    x = T[0.0, 0.0, 0.0]
    y = T[0.0, 0.0]
    z = T[0.0, 0.0, 0.0]

    # sparse co-ordinate storage
    if d == 1
      st = 'C'
      qpa_import(T, control, data, status, n, m,
                 "coordinate", H_ne, H_row, H_col, C_NULL,
                 "coordinate", A_ne, A_row, A_col, C_NULL)

      qpa_solve_qp(T, data, status, n, m, H_ne, H_val, g, f,
                   A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                   x_stat, c_stat)
    end

    # sparse by rows
    if d == 2
      st = 'R'
      qpa_import(T, control, data, status, n, m,
                 "sparse_by_rows", H_ne, C_NULL, H_col, H_ptr,
                 "sparse_by_rows", A_ne, C_NULL, A_col, A_ptr)

      qpa_solve_qp(T, data, status, n, m, H_ne, H_val, g, f,
                   A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                   x_stat, c_stat)
    end

    # dense
    if d == 3
      st = 'D'
      H_dense_ne = 6 # number of elements of H
      A_dense_ne = 6 # number of elements of A
      H_dense = T[1.0, 0.0, 1.0, 0.0, 0.0, 1.0]
      A_dense = T[2.0, 1.0, 0.0, 0.0, 1.0, 1.0]

      qpa_import(T, control, data, status, n, m,
                 "dense", H_ne, C_NULL, C_NULL, C_NULL,
                 "dense", A_ne, C_NULL, C_NULL, C_NULL)

      qpa_solve_qp(T, data, status, n, m, H_dense_ne, H_dense, g, f,
                   A_dense_ne, A_dense, c_l, c_u, x_l, x_u,
                   x, c, y, z, x_stat, c_stat)
    end

    # diagonal
    if d == 4
      st = 'L'
      qpa_import(T, control, data, status, n, m,
                 "diagonal", H_ne, C_NULL, C_NULL, C_NULL,
                 "sparse_by_rows", A_ne, C_NULL, A_col, A_ptr)

      qpa_solve_qp(T, data, status, n, m, H_ne, H_val, g, f,
                   A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                   x_stat, c_stat)
    end

    # scaled identity
    if d == 5
      st = 'S'
      qpa_import(T, control, data, status, n, m,
                 "scaled_identity", H_ne, C_NULL, C_NULL, C_NULL,
                 "sparse_by_rows", A_ne, C_NULL, A_col, A_ptr)

      qpa_solve_qp(T, data, status, n, m, H_ne, H_val, g, f,
                   A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                   x_stat, c_stat)
    end

    # identity
    if d == 6
      st = 'I'
      qpa_import(T, control, data, status, n, m,
                 "identity", H_ne, C_NULL, C_NULL, C_NULL,
                 "sparse_by_rows", A_ne, C_NULL, A_col, A_ptr)

      qpa_solve_qp(T, data, status, n, m, H_ne, H_val, g, f,
                   A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                   x_stat, c_stat)
    end

    # zero
    if d == 7
      st = 'Z'
      qpa_import(T, control, data, status, n, m,
                 "zero", H_ne, C_NULL, C_NULL, C_NULL,
                 "sparse_by_rows", A_ne, C_NULL, A_col, A_ptr)

      qpa_solve_qp(T, data, status, n, m, H_ne, H_val, g, f,
                   A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                   x_stat, c_stat)
    end

    qpa_information(T, data, inform, status)

    if inform[].status == 0
      @printf("%c:%6i iterations. Optimal objective value = %5.2f status = %1i\n",
              st, inform[].iter, inform[].obj, inform[].status)
    else
      @printf("%c: QPA_solve exit status = %1i\n", st, inform[].status)
    end

    # @printf("x: ")
    # for i = 1:n
    #   @printf("%f ", x[i])
    # end
    # @printf("\n")
    # @printf("gradient: ")
    # for i = 1:n
    #   @printf("%f ", g[i])
    # end
    # @printf("\n")

    # Delete internal workspace
    qpa_terminate(T, data, control, inform)
  end

  @printf("\n basic tests of l_1 qp storage formats\n\n")
  qpa_initialize(T, data, control, status)

  # Set user-defined control options
  @reset control[].f_indexing = true # Fortran sparse matrix indexing

  # Start from 0
  x = T[0.0, 0.0, 0.0]
  y = T[0.0, 0.0]
  z = T[0.0, 0.0, 0.0]

  # solve the l_1qp problem
  qpa_import(T, control, data, status, n, m,
             "coordinate", H_ne, H_row, H_col, C_NULL,
             "coordinate", A_ne, A_row, A_col, C_NULL)

  qpa_solve_l1qp(T, data, status, n, m, H_ne, H_val, g, f, rho_g, rho_b,
                 A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                 x_stat, c_stat)

  qpa_information(T, data, inform, status)

  if inform[].status == 0
    @printf("%s %6i iterations. Optimal objective value = %5.2f status = %1i\n",
            "l1qp  ", inform[].iter, inform[].obj, inform[].status)
  else
    @printf("%c: QPA_solve exit status = %1i\n", st, inform[].status)
  end

  # Start from 0
  for i in 1:n
    x[i] = 0.0
    z[i] = 0.0
  end
  for i in 1:m
    y[i] = 0.0
  end

  # solve the bound constrained l_1qp problem
  qpa_import(T, control, data, status, n, m,
             "coordinate", H_ne, H_row, H_col, C_NULL,
             "coordinate", A_ne, A_row, A_col, C_NULL)

  qpa_solve_bcl1qp(T, data, status, n, m, H_ne, H_val, g, f, rho_g,
                   A_ne, A_val, c_l, c_u, x_l, x_u, x, c, y, z,
                   x_stat, c_stat)

  qpa_information(T, data, inform, status)

  if inform[].status == 0
    @printf("%s %6i iterations. Optimal objective value = %5.2f status = %1i\n",
            "bcl1qp", inform[].iter, inform[].obj, inform[].status)
  else
    @printf("%c: QPA_solve exit status = %1i\n", st, inform[].status)
  end

  # Delete internal workspace
  qpa_terminate(T, data, control, inform)

  return 0
end

@testset "QPA" begin
  @test test_qpa(Float32) == 0
  @test test_qpa(Float64) == 0
  @test test_qpa(Float128) == 0
end
