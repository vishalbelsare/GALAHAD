# test_blls.jl
# Simple code to test the Julia interface to BLLS

using GALAHAD
using Test
using Printf
using Accessors

# Custom userdata struct
mutable struct userdata_blls
  scale::Float64
end

# Apply preconditioner
function prec(n::Int, x::Vector{Float64}, p::Vector{Float64}, userdata::userdata_blls)
  scale = userdata.scale
  for i in 1:n
    p[i] = scale * x[i]
  end
  return 0
end

function test_blls()
  # Derived types
  data = Ref{Ptr{Cvoid}}()
  control = Ref{blls_control_type{Float64}}()
  inform = Ref{blls_inform_type{Float64}}()

  # Set user data
  userdata = userdata_blls(1.0)

  # Set problem data
  n = 10 # dimension
  o = n + 1 # number of residuals
  Ao_ne = 2 * n # sparse Jacobian elements
  Ao_dense_ne = o * n # dense Jacobian elements
  # row-wise storage
  Ao_row = zeros(Cint, Ao_ne) # row indices,
  Ao_col = zeros(Cint, Ao_ne) # column indices
  Ao_ptr_ne = o + 1 # number of row pointers
  Ao_ptr = zeros(Cint, Ao_ptr_ne)  # row pointers
  Ao_val = zeros(Float64, Ao_ne) # values
  Ao_dense = zeros(Float64, Ao_dense_ne) # dense values
  # column-wise storage
  Ao_by_col_row = zeros(Cint, Ao_ne) # row indices,
  Ao_by_col_ptr_ne = n + 1 # number of column pointers
  Ao_by_col_ptr = zeros(Cint, Ao_by_col_ptr_ne)  # column pointers
  Ao_by_col_val = zeros(Float64, Ao_ne) # values
  Ao_by_col_dense = zeros(Float64, Ao_dense_ne) # dense values
  b = zeros(Float64, o)  # linear term in the objective
  x_l = zeros(Float64, n) # variable lower bound
  x_u = zeros(Float64, n) # variable upper bound
  x = zeros(Float64, n) # variables
  z = zeros(Float64, n) # dual variables
  r = zeros(Float64, o) # residual
  g = zeros(Float64, n) # gradient
  w = zeros(Float64, o) # weights

  # Set output storage
  x_stat = zeros(Cint, n) # variable status
  st = ' '
  status = Ref{Cint}()

  x_l[1] = -1.0
  for i in 2:n
    x_l[i] = -Inf
  end
  x_u[1] = 1.0
  x_u[2] = Inf
  for i in 3:n
    x_u[i] = 2.0
  end

  #   A = ( I )  and b = (i * e)
  #       (e^T)          (n + 1)

  for i in 1:n
    b[i] = i
  end
  b[n + 1] = n + 1

  w[1] = 2.0
  w[2] = 1.0
  for i in 3:o
    w[i] = 1.0
  end

  # # A by rows
  for i in 1:n
    Ao_ptr[i] = i
    Ao_row[i] = i
    Ao_col[i] = i
    Ao_val[i] = 1.0
  end
  Ao_ptr[n + 1] = n + 1
  for i in 1:n
    Ao_row[n + i] = o
    Ao_col[n + i] = i
    Ao_val[n + i] = 1.0
  end
  Ao_ptr[o + 1] = Ao_ne + 1
  l = 0
  for i in 1:n
    for j in 1:n
      l = l + 1
      if i == j
        Ao_dense[l] = 1.0
      else
        Ao_dense[l] = 0.0
      end
    end
  end
  for j in 1:n
    l = l + 1
    Ao_dense[l] = 1.0
  end

  # # A by columns
  l = 0
  for j in 1:n
    l = l + 1
    Ao_by_col_ptr[j] = l
    Ao_by_col_row[l] = j
    Ao_by_col_val[l] = 1.0
    l = l + 1
    Ao_by_col_row[l] = o
    Ao_by_col_val[l] = 1.0
  end
  Ao_by_col_ptr[n + 1] = Ao_ne + 1
  l = 0
  for j in 1:n
    for i in 1:n
      l = l + 1
      if i == j
        Ao_by_col_dense[l] = 1.0
      else
        Ao_by_col_dense[l] = 0.0
      end
    end
    l = l + 1
    Ao_by_col_dense[l] = 1.0
  end

  @printf(" fortran sparse matrix indexing\n\n")
  @printf(" tests reverse-communication options\n\n")

  # reverse-communication input/output
  on = max(o, n)
  eval_status = Ref{Cint}()
  nz_v_start = Ref{Cint}()
  nz_v_end = Ref{Cint}()
  nz_v = zeros(Cint, on)
  nz_p = zeros(Cint, o)
  mask = zeros(Cint, o)
  v = zeros(Float64, on)
  p = zeros(Float64, on)
  nz_p_end = 1

  # Initialize BLLS
  blls_initialize(Float64, data, control, status)

  # Set user-defined control options
  @reset control[].f_indexing = true # fortran sparse matrix indexing

  # Start from 0
  for i in 1:n
    x[i] = 0.0
    z[i] = 0.0
  end

  st = "RC"
  for i in 1:o
    mask[i] = 0
  end
  blls_import_without_a(Float64, control, data, status, n, o)

  terminated = false
  while !terminated # reverse-communication loop
    blls_solve_reverse_a_prod(Float64, data, status, eval_status, n, o, b,
                              x_l, x_u, x, z, r, g, x_stat, v, p,
                              nz_v, nz_v_start, nz_v_end,
                              nz_p, nz_p_end, w)

    if status[] == 0 # successful termination
      terminated = true
    elseif status[] < 0 # error exit
      terminated = true
    elseif status[] == 2 # evaluate p = Av
      p[o] = 0.0
      for i in 1:n
        p[i] = v[i]
        p[o] = p[o] + v[i]
      end
    elseif status[] == 3 # evaluate p = A^Tv
      for i in 1:n
        p[i] = v[i] + v[o]
      end
    elseif status[] == 4 # evaluate p = Av for sparse v
      for i in 1:o
        p[i] = 0.0
      end
      for l in nz_v_start[]:nz_v_end[]
        i = nz_v[l]
        p[i] = v[i]
        p[o] = p[o] + v[i]
      end
    elseif status[] == 5 # evaluate p = sparse Av for sparse v
      nz_p_end = 0
      for l in nz_v_start[]:nz_v_end[]
        i = nz_v[l]
        nz_p_end = nz_p_end + 1
        nz_p[nz_p_end] = i
        p[i] = v[i]
        if mask[i] == 0
          mask[i] = 1
          nz_p_end = nz_p_end + 1
          nz_p[nz_p_end] = o
          p[o] = v[i]
        else
          p[o] = p[o] + v[i]
        end
      end
      for l in 1:nz_p_end
        mask[nz_p[l]] = 0
      end
    elseif status[] == 6 # evaluate p = sparse A^Tv
      for l in nz_v_start[]:nz_v_end[]
        i = nz_v[l]
        p[i] = v[i] + v[o]
      end
    elseif status[] == 7 # evaluate p = P^{-}v
      for i in 1:n
        p[i] = userdata.scale * v[i]
      end
    else
      @printf(" the value %1i of status should not occur\n", status)
    end
    eval_status[] = 0
  end

  # Record solution information
  blls_information(Float64, data, inform, status)

  # Print solution details
  if inform[].status == 0
    @printf("%s:%6i iterations. Optimal objective value = %5.2f status = %1i\n",
            st, inform[].iter, inform[].obj, inform[].status)
  else
    @printf("%s: BLLS_solve exit status = %1i\n", st, inform[].status)
  end

  # @printf("x: ")
  # for i = 1:n
  #   @printf("%f ", x[i])
  # @printf("\n")
  # @printf("gradient: ")
  # for i = 1:n
  #   @printf("%f ", g[i])
  # @printf("\n")

  # Delete internal workspace
  blls_terminate(Float64, data, control, inform)

  return 0
end

@testset "BLLS" begin
  @test test_blls() == 0
end
