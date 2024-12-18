# test_tru.jl
# Simple code to test the Julia interface to TRU

using GALAHAD
using Test
using Printf
using Accessors
using Quadmath

# Custom userdata struct
mutable struct userdata_tru{T}
  p::T
end

function test_tru(::Type{T}) where T

  # Objective function
  function fun(n::Int, x::Vector{T}, f::Ref{T}, userdata::userdata_tru{T})
    p = userdata.p
    f[] = (x[1] + x[3] + p)^2 + (x[2] + x[3])^2 + cos(x[1])
    return 0
  end

  # Gradient of the objective
  function grad(n::Int, x::Vector{T}, g::Vector{T}, userdata::userdata_tru{T})
    p = userdata.p
    g[1] = 2.0 * (x[1] + x[3] + p) - sin(x[1])
    g[2] = 2.0 * (x[2] + x[3])
    g[3] = 2.0 * (x[1] + x[3] + p) + 2.0 * (x[2] + x[3])
    return 0
  end

  # Hessian of the objective
  function hess(n::Int, ne::Int, x::Vector{T}, hval::Vector{T},
                userdata::userdata_tru)
    hval[1] = 2.0 - cos(x[1])
    hval[2] = 2.0
    hval[3] = 2.0
    hval[4] = 2.0
    hval[5] = 4.0
    return 0
  end

  # Dense Hessian
  function hess_dense(n::Int, ne::Int, x::Vector{T}, hval::Vector{T},
                      userdata::userdata_tru{T})
    hval[1] = 2.0 - cos(x[1])
    hval[2] = 0.0
    hval[3] = 2.0
    hval[4] = 2.0
    hval[5] = 2.0
    hval[6] = 4.0
    return 0
  end

  # Hessian-vector product
  function hessprod(n::Int, x::Vector{T}, u::Vector{T}, v::Vector{T},
                    got_h::Bool, userdata::userdata_tru{T})
    u[1] = u[1] + 2.0 * (v[1] + v[3]) - cos(x[1]) * v[1]
    u[2] = u[2] + 2.0 * (v[2] + v[3])
    u[3] = u[3] + 2.0 * (v[1] + v[2] + 2.0 * v[3])
    return 0
  end

  # Apply preconditioner
  function prec(n::Int, x::Vector{T}, u::Vector{T}, v::Vector{T},
                userdata::userdata_tru{T})
    u[1] = 0.5 * v[1]
    u[2] = 0.5 * v[2]
    u[3] = 0.25 * v[3]
    return 0
  end

  # Objective function
  function fun_diag(n::Int, x::Vector{T}, f::Ref{T}, userdata::userdata_tru{T})
    p = userdata.p
    f[] = (x[3] + p)^2 + x[2]^2 + cos(x[1])
    return 0
  end

  # Gradient of the objective
  function grad_diag(n::Int, x::Vector{T}, g::Vector{T}, userdata::userdata_tru{T})
    p = userdata.p
    g[1] = -sin(x[1])
    g[2] = 2.0 * x[2]
    g[3] = 2.0 * (x[3] + p)
    return 0
  end

  # Hessian of the objective
  function hess_diag(n::Int, ne::Int, x::Vector{T}, hval::Vector{T},
                     userdata::userdata_tru{T})
    hval[1] = -cos(x[1])
    hval[2] = 2.0
    hval[3] = 2.0
    return 0
  end

  # Hessian-vector product
  function hessprod_diag(n::Int, x::Vector{T}, u::Vector{T}, v::Vector{T},
                         got_h::Bool, userdata::userdata_tru{T})
    u[1] = u[1] + -cos(x[1]) * v[1]
    u[2] = u[2] + 2.0 * v[2]
    u[3] = u[3] + 2.0 * v[3]
    return 0
  end

  # Derived types
  data = Ref{Ptr{Cvoid}}()
  control = Ref{tru_control_type{T}}()
  inform = Ref{tru_inform_type{T}}()

  # Set user data
  userdata = userdata_tru(4.0 |> T)

  # Set problem data
  n = 3 # dimension
  ne = 5 # Hesssian elements
  H_row = Cint[1, 2, 3, 3, 3]  # Hessian H
  H_col = Cint[1, 2, 1, 2, 3]  # NB lower triangle
  H_ptr = Cint[1, 2, 3, 6]  # row pointers

  # Set storage
  g = zeros(T, n) # gradient
  st = ' '
  status = Ref{Cint}()

  @printf(" Fortran sparse matrix indexing\n\n")
  @printf(" tests reverse-communication options\n\n")

  # reverse-communication input/output
  eval_status = Ref{Cint}()
  f = Ref{T}(0.0)
  u = zeros(T, n)
  v = zeros(T, n)
  index_nz_u = zeros(Cint, n)
  index_nz_v = zeros(Cint, n)
  H_val = zeros(T, ne)
  H_dense = zeros(T, div(n * (n + 1), 2))
  H_diag = zeros(T, n)

  for d in 1:5
    # Initialize TRU
    tru_initialize(T, data, control, status)

    # Set user-defined control options
    @reset control[].f_indexing = true # Fortran sparse matrix indexing
    @reset control[].print_level = Cint(1)
    # @reset control[].maxit = Cint(1)

    # Start from 1.5
    x = T[1.5, 1.5, 1.5]

    # sparse co-ordinate storage
    if d == 1
      st = 'C'
      tru_import(T, control, data, status, n, "coordinate",
                 ne, H_row, H_col, C_NULL)

      terminated = false
      while !terminated # reverse-communication loop
        tru_solve_reverse_with_mat(T, data, status, eval_status, n, x, f[], g, ne, H_val, u, v)
        if status[] == 0 # successful termination
          terminated = true
        elseif status[] < 0 # error exit
          terminated = true
        elseif status[] == 2 # evaluate f
          eval_status[] = fun(n, x, f, userdata)
        elseif status[] == 3 # evaluate g
          eval_status[] = grad(n, x, g, userdata)
        elseif status[] == 4 # evaluate H
          eval_status[] = hess(n, ne, x, H_val, userdata)
        elseif status[] == 6 # evaluate the product with P
          eval_status[] = prec(n, x, u, v, userdata)
        else
          @printf(" the value %1i of status should not occur\n", status)
        end
      end
    end

    # sparse by rows
    if d == 2
      st = 'R'
      tru_import(T, control, data, status, n, "sparse_by_rows", ne,
                 C_NULL, H_col, H_ptr)

      terminated = false
      while !terminated # reverse-communication loop
        tru_solve_reverse_with_mat(T, data, status, eval_status, n, x, f[], g, ne, H_val, u, v)
        if status[] == 0 # successful termination
          terminated = true
        elseif status[] < 0 # error exit
          terminated = true
        elseif status[] == 2 # evaluate f
          eval_status[] = fun(n, x, f, userdata)
        elseif status[] == 3 # evaluate g
          eval_status[] = grad(n, x, g, userdata)
        elseif status[] == 4 # evaluate H
          eval_status[] = hess(n, ne, x, H_val, userdata)
        elseif status[] == 6 # evaluate the product with P
          eval_status[] = prec(n, x, u, v, userdata)
        else
          @printf(" the value %1i of status should not occur\n", status)
        end
      end
    end

    # dense
    if d == 3
      st = 'D'
      tru_import(T, control, data, status, n, "dense",
                 ne, C_NULL, C_NULL, C_NULL)

      terminated = false
      while !terminated # reverse-communication loop
        tru_solve_reverse_with_mat(T, data, status, eval_status, n, x, f[], g,
                                   div(n * (n + 1), 2), H_dense, u, v)
        if status[] == 0 # successful termination
          terminated = true
        elseif status[] < 0 # error exit
          terminated = true
        elseif status[] == 2 # evaluate f
          eval_status[] = fun(n, x, f, userdata)
        elseif status[] == 3 # evaluate g
          eval_status[] = grad(n, x, g, userdata)
        elseif status[] == 4 # evaluate H
          eval_status[] = hess_dense(n, div(n * (n + 1), 2), x, H_dense, userdata)
        elseif status[] == 6 # evaluate the product with P
          eval_status[] = prec(n, x, u, v, userdata)
        else
          @printf(" the value %1i of status should not occur\n", status)
        end
      end
    end

    # diagonal
    if d == 4
      st = 'I'
      tru_import(T, control, data, status, n, "diagonal", ne, C_NULL, C_NULL, C_NULL)

      terminated = false
      while !terminated # reverse-communication loop
        tru_solve_reverse_with_mat(T, data, status, eval_status, n, x, f[], g, n, H_diag, u, v)
        if status[] == 0 # successful termination
          terminated = true
        elseif status[] < 0 # error exit
          terminated = true
        elseif status[] == 2 # evaluate f
          eval_status[] = fun_diag(n, x, f, userdata)
        elseif status[] == 3 # evaluate g
          eval_status[] = grad_diag(n, x, g, userdata)
        elseif status[] == 4 # evaluate H
          eval_status[] = hess_diag(n, n, x, H_diag, userdata)
        elseif status[] == 6 # evaluate the product with P
          eval_status[] = prec(n, x, u, v, userdata)
        else
          @printf(" the value %1i of status should not occur\n", status)
        end
      end
    end

    # access by products
    if d == 5
      st = 'P'
      tru_import(T, control, data, status, n, "absent",
                 ne, C_NULL, C_NULL, C_NULL)

      terminated = false
      while !terminated # reverse-communication loop
        tru_solve_reverse_without_mat(T, data, status, eval_status, n, x, f[], g, u, v)
        if status[] == 0 # successful termination
          terminated = true
        elseif status[] < 0 # error exit
          terminated = true
        elseif status[] == 2 # evaluate f
          eval_status[] = fun(n, x, f, userdata)
        elseif status[] == 3 # evaluate g
          eval_status[] = grad(n, x, g, userdata)
        elseif status[] == 5 # evaluate H
          eval_status[] = hessprod(n, x, u, v, false, userdata)
        elseif status[] == 6 # evaluate the product with P
          eval_status[] = prec(n, x, u, v, userdata)
        else
          @printf(" the value %1i of status should not occur\n", status)
        end
      end
    end

    tru_information(T, data, inform, status)

    if inform[].status == 0
      @printf("%c:%6i iterations. Optimal objective value = %5.2f status = %1i\n", st,
              inform[].iter, inform[].obj, inform[].status)
    else
      @printf("%c: TRU_solve exit status = %1i\n", st, inform[].status)
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
    tru_terminate(T, data, control, inform)
  end

  return 0
end

@testset "TRU" begin
  @test test_tru(Float32) == 0
  @test test_tru(Float64) == 0
  @test test_tru(Float128) == 0
end
