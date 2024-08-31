# test_llst.jl
# Simple code to test the Julia interface to LLST

using GALAHAD
using Test
using Printf
using Accessors

function test_llst()
  # Derived types
  data = Ref{Ptr{Cvoid}}()
  control = Ref{llst_control_type{Float64}}()
  inform = Ref{llst_inform_type{Float64}}()

  # Set problem data
  # set dimensions
  m = 100
  n = 2 * m + 1
  # A = (I : Diag(1:n) : e)
  A_ne = 3 * m
  A_row = zeros(Cint, A_ne)
  A_col = zeros(Cint, A_ne)
  A_ptr = zeros(Cint, m + 1)
  A_val = zeros(Float64, A_ne)

  # store A in sparse formats
  l = 1
  for i in 1:m
    A_ptr[i] = l
    A_row[l] = i
    A_col[l] = i
    A_val[l] = 1.0
    l = l + 1
    A_row[l] = i
    A_col[l] = m + i
    A_val[l] = i
    l = l + 1
    A_row[l] = i
    A_col[l] = n
    A_val[l] = 1.0
    l = l + 1
  end
  A_ptr[m + 1] = l

  # store A in dense format
  A_dense_ne = m * n
  A_dense_val = zeros(Float64, A_dense_ne)
  l = 0
  for i in 1:m
    A_dense_val[l + i] = 1.0
    A_dense_val[l + m + i] = i
    A_dense_val[l + n] = 1.0
    l = l + n
  end

  # S = diag(1:n)**2
  S_ne = n
  S_row = zeros(Cint, S_ne)
  S_col = zeros(Cint, S_ne)
  S_ptr = zeros(Cint, n + 1)
  S_val = zeros(Float64, S_ne)

  # store S in sparse formats
  for i in 1:n
    S_row[i] = i
    S_col[i] = i
    S_ptr[i] = i
    S_val[i] = i * i
  end
  S_ptr[n + 1] = n + 1

  # store S in dense format
  S_dense_ne = div(n * (n + 1), 2)
  S_dense_val = zeros(Float64, S_dense_ne)
  l = 0
  for i in 1:n
    S_dense_val[l + i] = i * i
    l = l + i
  end

  # b is a vector of ones
  b = ones(Float64, m) # observations

  # trust-region radius is one
  radius = 1.0

  # Set output storage
  x = zeros(Float64, n) # solution
  st = ' '
  status = Ref{Cint}()

  @printf(" Fortran sparse matrix indexing\n\n")
  @printf(" basic tests of problem storage formats\n\n")

  # loop over storage formats
  for d in 1:4

    # Initialize LLST
    llst_initialize(Float64, data, control, status)
    @reset control[].definite_linear_solver = galahad_linear_solver("potr")
    @reset control[].sbls_control.symmetric_linear_solver = galahad_linear_solver("sytr")
    @reset control[].sbls_control.definite_linear_solver = galahad_linear_solver("potr")
    # @reset control[].print_level = Cint(1)

    # Set user-defined control options
    @reset control[].f_indexing = true # Fortran sparse matrix indexing

    # use s or not (1 or 0)
    for use_s in 0:1
      # sparse co-ordinate storage
      if d == 1
        st = 'C'
        llst_import(Float64, control, data, status, m, n,
                    "coordinate", A_ne, A_row, A_col, C_NULL)

        if use_s == 0
          llst_solve_problem(Float64, data, status, m, n, radius,
                             A_ne, A_val, b, x, 0, C_NULL)
        else
          llst_import_scaling(Float64, control, data, status, n,
                              "coordinate", S_ne, S_row,
                              S_col, C_NULL)

          llst_solve_problem(Float64, data, status, m, n, radius,
                             A_ne, A_val, b, x, S_ne, S_val)
        end
      end

      # sparse by rows
      if d == 2
        st = 'R'
        llst_import(Float64, control, data, status, m, n,
                    "sparse_by_rows", A_ne, C_NULL, A_col, A_ptr)
        if use_s == 0
          llst_solve_problem(Float64, data, status, m, n, radius,
                             A_ne, A_val, b, x, 0, C_NULL)
        else
          llst_import_scaling(Float64, control, data, status, n,
                              "sparse_by_rows", S_ne, C_NULL,
                              S_col, S_ptr)

          llst_solve_problem(Float64, data, status, m, n, radius,
                             A_ne, A_val, b, x, S_ne, S_val)
        end
      end

      # dense
      if d == 3
        st = 'D'
        llst_import(Float64, control, data, status, m, n,
                    "dense", A_dense_ne, C_NULL, C_NULL, C_NULL)

        if use_s == 0
          llst_solve_problem(Float64, data, status, m, n, radius,
                             A_dense_ne, A_dense_val, b, x,
                             0, C_NULL)
        else
          llst_import_scaling(Float64, control, data, status, n,
                              "dense", S_dense_ne,
                              C_NULL, C_NULL, C_NULL)

          llst_solve_problem(Float64, data, status, m, n, radius,
                             A_dense_ne, A_dense_val, b, x,
                             S_dense_ne, S_dense_val)
        end
      end

      # diagonal
      if d == 4
        st = 'I'
        llst_import(Float64, control, data, status, m, n,
                    "coordinate", A_ne, A_row, A_col, C_NULL)
        if use_s == 0
          llst_solve_problem(Float64, data, status, m, n, radius,
                             A_ne, A_val, b, x, 0, C_NULL)
        else
          llst_import_scaling(Float64, control, data, status, n,
                              "diagonal", S_ne, C_NULL, C_NULL, C_NULL)

          llst_solve_problem(Float64, data, status, m, n, radius,
                             A_ne, A_val, b, x, S_ne, S_val)
        end
      end

      llst_information(Float64, data, inform, status)

      if inform[].status == 0
        @printf("storage type %c%1i:  status = %1i, ||r|| = %5.2f\n", st, use_s,
                inform[].status, inform[].r_norm)
      else
        @printf("storage type %c%1i: LLST_solve exit status = %1i\n", st, use_s,
                inform[].status)
      end
    end

    # @printf("x: ")
    # for i = 1:n
    #   @printf("%f ", x[i])
    # end
    # @printf("\n")

    # Delete internal workspace
    llst_terminate(Float64, data, control, inform)
  end

  return 0
end

@testset "LLST" begin
  @test test_llst() == 0
end
