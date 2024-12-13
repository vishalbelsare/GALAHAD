export lsqp_control_type

struct lsqp_control_type{T}
  f_indexing::Bool
  error::Cint
  out::Cint
  print_level::Cint
  start_print::Cint
  stop_print::Cint
  maxit::Cint
  factor::Cint
  max_col::Cint
  indmin::Cint
  valmin::Cint
  itref_max::Cint
  infeas_max::Cint
  muzero_fixed::Cint
  restore_problem::Cint
  indicator_type::Cint
  extrapolate::Cint
  path_history::Cint
  path_derivatives::Cint
  fit_order::Cint
  sif_file_device::Cint
  infinity::T
  stop_p::T
  stop_d::T
  stop_c::T
  prfeas::T
  dufeas::T
  muzero::T
  reduce_infeas::T
  potential_unbounded::T
  pivot_tol::T
  pivot_tol_for_dependencies::T
  zero_pivot::T
  identical_bounds_tol::T
  mu_min::T
  indicator_tol_p::T
  indicator_tol_pd::T
  indicator_tol_tapia::T
  cpu_time_limit::T
  clock_time_limit::T
  remove_dependencies::Bool
  treat_zero_bounds_as_general::Bool
  just_feasible::Bool
  getdua::Bool
  puiseux::Bool
  feasol::Bool
  balance_initial_complentarity::Bool
  use_corrector::Bool
  array_syntax_worse_than_do_loop::Bool
  space_critical::Bool
  deallocate_error_fatal::Bool
  generate_sif_file::Bool
  sif_file_name::NTuple{31,Cchar}
  prefix::NTuple{31,Cchar}
  fdc_control::fdc_control_type{T}
  sbls_control::sbls_control_type{T}
end

export lsqp_time_type

struct lsqp_time_type{T}
  total::T
  preprocess::T
  find_dependent::T
  analyse::T
  factorize::T
  solve::T
  clock_total::T
  clock_preprocess::T
  clock_find_dependent::T
  clock_analyse::T
  clock_factorize::T
  clock_solve::T
end

export lsqp_inform_type

struct lsqp_inform_type{T}
  status::Cint
  alloc_status::Cint
  bad_alloc::NTuple{81,Cchar}
  iter::Cint
  factorization_status::Cint
  factorization_integer::Int64
  factorization_real::Int64
  nfacts::Cint
  nbacts::Cint
  obj::T
  potential::T
  non_negligible_pivot::T
  feasible::Bool
  time::lsqp_time_type{T}
  fdc_inform::fdc_inform_type{T}
  sbls_inform::sbls_inform_type{T}
end

export lsqp_initialize

function lsqp_initialize(::Type{Float32}, data, control, status)
  @ccall libgalahad_single.lsqp_initialize_s(data::Ptr{Ptr{Cvoid}},
                                             control::Ptr{lsqp_control_type{Float32}},
                                             status::Ptr{Cint})::Cvoid
end

function lsqp_initialize(::Type{Float64}, data, control, status)
  @ccall libgalahad_double.lsqp_initialize(data::Ptr{Ptr{Cvoid}},
                                           control::Ptr{lsqp_control_type{Float64}},
                                           status::Ptr{Cint})::Cvoid
end

function lsqp_initialize(::Type{Float128}, data, control, status)
  @ccall libgalahad_quadruple.lsqp_initialize_q(data::Ptr{Ptr{Cvoid}},
                                                control::Ptr{lsqp_control_type{Float128}},
                                                status::Ptr{Cint})::Cvoid
end

export lsqp_read_specfile

function lsqp_read_specfile(::Type{Float32}, control, specfile)
  @ccall libgalahad_single.lsqp_read_specfile_s(control::Ptr{lsqp_control_type{Float32}},
                                                specfile::Ptr{Cchar})::Cvoid
end

function lsqp_read_specfile(::Type{Float64}, control, specfile)
  @ccall libgalahad_double.lsqp_read_specfile(control::Ptr{lsqp_control_type{Float64}},
                                              specfile::Ptr{Cchar})::Cvoid
end

function lsqp_read_specfile(::Type{Float128}, control, specfile)
  @ccall libgalahad_quadruple.lsqp_read_specfile_q(control::Ptr{lsqp_control_type{Float128}},
                                                   specfile::Ptr{Cchar})::Cvoid
end

export lsqp_import

function lsqp_import(::Type{Float32}, control, data, status, n, m, A_type, A_ne, A_row,
                     A_col, A_ptr)
  @ccall libgalahad_single.lsqp_import_s(control::Ptr{lsqp_control_type{Float32}},
                                         data::Ptr{Ptr{Cvoid}}, status::Ptr{Cint}, n::Cint,
                                         m::Cint, A_type::Ptr{Cchar}, A_ne::Cint,
                                         A_row::Ptr{Cint}, A_col::Ptr{Cint},
                                         A_ptr::Ptr{Cint})::Cvoid
end

function lsqp_import(::Type{Float64}, control, data, status, n, m, A_type, A_ne, A_row,
                     A_col, A_ptr)
  @ccall libgalahad_double.lsqp_import(control::Ptr{lsqp_control_type{Float64}},
                                       data::Ptr{Ptr{Cvoid}}, status::Ptr{Cint}, n::Cint,
                                       m::Cint, A_type::Ptr{Cchar}, A_ne::Cint,
                                       A_row::Ptr{Cint}, A_col::Ptr{Cint},
                                       A_ptr::Ptr{Cint})::Cvoid
end

function lsqp_import(::Type{Float128}, control, data, status, n, m, A_type, A_ne, A_row,
                     A_col, A_ptr)
  @ccall libgalahad_quadruple.lsqp_import_q(control::Ptr{lsqp_control_type{Float128}},
                                            data::Ptr{Ptr{Cvoid}}, status::Ptr{Cint},
                                            n::Cint, m::Cint, A_type::Ptr{Cchar},
                                            A_ne::Cint, A_row::Ptr{Cint}, A_col::Ptr{Cint},
                                            A_ptr::Ptr{Cint})::Cvoid
end

export lsqp_reset_control

function lsqp_reset_control(::Type{Float32}, control, data, status)
  @ccall libgalahad_single.lsqp_reset_control_s(control::Ptr{lsqp_control_type{Float32}},
                                                data::Ptr{Ptr{Cvoid}},
                                                status::Ptr{Cint})::Cvoid
end

function lsqp_reset_control(::Type{Float64}, control, data, status)
  @ccall libgalahad_double.lsqp_reset_control(control::Ptr{lsqp_control_type{Float64}},
                                              data::Ptr{Ptr{Cvoid}},
                                              status::Ptr{Cint})::Cvoid
end

function lsqp_reset_control(::Type{Float128}, control, data, status)
  @ccall libgalahad_quadruple.lsqp_reset_control_q(control::Ptr{lsqp_control_type{Float128}},
                                                   data::Ptr{Ptr{Cvoid}},
                                                   status::Ptr{Cint})::Cvoid
end

export lsqp_solve_qp

function lsqp_solve_qp(::Type{Float32}, data, status, n, m, w, x0, g, f, a_ne, A_val, c_l,
                       c_u, x_l, x_u, x, c, y, z, x_stat, c_stat)
  @ccall libgalahad_single.lsqp_solve_qp_s(data::Ptr{Ptr{Cvoid}}, status::Ptr{Cint},
                                           n::Cint, m::Cint, w::Ptr{Float32},
                                           x0::Ptr{Float32}, g::Ptr{Float32}, f::Float32,
                                           a_ne::Cint, A_val::Ptr{Float32},
                                           c_l::Ptr{Float32}, c_u::Ptr{Float32},
                                           x_l::Ptr{Float32}, x_u::Ptr{Float32},
                                           x::Ptr{Float32}, c::Ptr{Float32},
                                           y::Ptr{Float32}, z::Ptr{Float32},
                                           x_stat::Ptr{Cint}, c_stat::Ptr{Cint})::Cvoid
end

function lsqp_solve_qp(::Type{Float64}, data, status, n, m, w, x0, g, f, a_ne, A_val, c_l,
                       c_u, x_l, x_u, x, c, y, z, x_stat, c_stat)
  @ccall libgalahad_double.lsqp_solve_qp(data::Ptr{Ptr{Cvoid}}, status::Ptr{Cint}, n::Cint,
                                         m::Cint, w::Ptr{Float64}, x0::Ptr{Float64},
                                         g::Ptr{Float64}, f::Float64, a_ne::Cint,
                                         A_val::Ptr{Float64}, c_l::Ptr{Float64},
                                         c_u::Ptr{Float64}, x_l::Ptr{Float64},
                                         x_u::Ptr{Float64}, x::Ptr{Float64},
                                         c::Ptr{Float64}, y::Ptr{Float64}, z::Ptr{Float64},
                                         x_stat::Ptr{Cint}, c_stat::Ptr{Cint})::Cvoid
end

function lsqp_solve_qp(::Type{Float128}, data, status, n, m, w, x0, g, f, a_ne, A_val, c_l,
                       c_u, x_l, x_u, x, c, y, z, x_stat, c_stat)
  @ccall libgalahad_quadruple.lsqp_solve_qp_q(data::Ptr{Ptr{Cvoid}}, status::Ptr{Cint},
                                              n::Cint, m::Cint, w::Ptr{Float128},
                                              x0::Ptr{Float128}, g::Ptr{Float128},
                                              f::Float128, a_ne::Cint, A_val::Ptr{Float128},
                                              c_l::Ptr{Float128}, c_u::Ptr{Float128},
                                              x_l::Ptr{Float128}, x_u::Ptr{Float128},
                                              x::Ptr{Float128}, c::Ptr{Float128},
                                              y::Ptr{Float128}, z::Ptr{Float128},
                                              x_stat::Ptr{Cint}, c_stat::Ptr{Cint})::Cvoid
end

export lsqp_information

function lsqp_information(::Type{Float32}, data, inform, status)
  @ccall libgalahad_single.lsqp_information_s(data::Ptr{Ptr{Cvoid}},
                                              inform::Ptr{lsqp_inform_type{Float32}},
                                              status::Ptr{Cint})::Cvoid
end

function lsqp_information(::Type{Float64}, data, inform, status)
  @ccall libgalahad_double.lsqp_information(data::Ptr{Ptr{Cvoid}},
                                            inform::Ptr{lsqp_inform_type{Float64}},
                                            status::Ptr{Cint})::Cvoid
end

function lsqp_information(::Type{Float128}, data, inform, status)
  @ccall libgalahad_quadruple.lsqp_information_q(data::Ptr{Ptr{Cvoid}},
                                                 inform::Ptr{lsqp_inform_type{Float128}},
                                                 status::Ptr{Cint})::Cvoid
end

export lsqp_terminate

function lsqp_terminate(::Type{Float32}, data, control, inform)
  @ccall libgalahad_single.lsqp_terminate_s(data::Ptr{Ptr{Cvoid}},
                                            control::Ptr{lsqp_control_type{Float32}},
                                            inform::Ptr{lsqp_inform_type{Float32}})::Cvoid
end

function lsqp_terminate(::Type{Float64}, data, control, inform)
  @ccall libgalahad_double.lsqp_terminate(data::Ptr{Ptr{Cvoid}},
                                          control::Ptr{lsqp_control_type{Float64}},
                                          inform::Ptr{lsqp_inform_type{Float64}})::Cvoid
end

function lsqp_terminate(::Type{Float128}, data, control, inform)
  @ccall libgalahad_quadruple.lsqp_terminate_q(data::Ptr{Ptr{Cvoid}},
                                               control::Ptr{lsqp_control_type{Float128}},
                                               inform::Ptr{lsqp_inform_type{Float128}})::Cvoid
end
