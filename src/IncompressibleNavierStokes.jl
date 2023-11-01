"""
    IncompressibleNavierStokes

Energy-conserving solvers for the incompressible Navier-Stokes equations.
"""
module IncompressibleNavierStokes

using Adapt
using ComponentArrays: ComponentArray
using FFTW
using IterativeSolvers
using KernelAbstractions
using LinearAlgebra
using Lux
using Makie
using NNlib
using Optimisers
using Printf
using Random
using SparseArrays
using Statistics
using WriteVTK: CollectionFile, paraview_collection, vtk_grid, vtk_save
using Zygote

# Workgroup size for kernels
# Let this be constant for now
const WORKGROUP = 64

# Convenience notation
const ⊗ = kron

# Easily retrieve value from Val
(::Val{x})() where {x} = x

# Boundary conditions
include("boundary_conditions.jl")

# Grid
include("grid/dimension.jl")
include("grid/grid.jl")
include("grid/stretched_grid.jl")
include("grid/cosine_grid.jl")
include("grid/max_size.jl")

# Models
include("models/viscosity_models.jl")
include("models/convection_models.jl")

# Setup
include("setup.jl")

# Pressure solvers
include("solvers/pressure/pressure_solvers.jl")
include("solvers/pressure/pressure_poisson.jl")
include("solvers/pressure/pressure_additional_solve.jl")

# Time steppers
include("time_steppers/methods.jl")
include("time_steppers/tableaux.jl")
include("time_steppers/nstage.jl")
include("time_steppers/time_stepper_caches.jl")
include("time_steppers/step.jl")
include("time_steppers/isexplicit.jl")
include("time_steppers/lambda_max.jl")

# Preprocess
include("create_initial_conditions.jl")

# Processors
include("processors/processors.jl")
include("processors/real_time_plot.jl")
include("processors/animator.jl")

# Discrete operators
include("operators.jl")
include("filter.jl")

# Solvers
include("solvers/get_timestep.jl")
include("solvers/solve_steady_state.jl")
include("solvers/solve_unsteady.jl")

# Utils
include("utils/get_lims.jl")
include("utils/plotmat.jl")

# Postprocess
include("postprocess/plot_force.jl")
include("postprocess/plot_grid.jl")
include("postprocess/plot_pressure.jl")
include("postprocess/plot_velocity.jl")
include("postprocess/plot_vorticity.jl")
include("postprocess/plot_streamfunction.jl")
include("postprocess/save_vtk.jl")

# Closure models
include("closures/cnn.jl")
include("closures/fno.jl")
include("closures/training.jl")
include("closures/create_les_data.jl")

# Boundary conditions
export PeriodicBC, DirichletBC, SymmetricBC, PressureBC

# Force
export SteadyBodyForce

# Models
export AbstractViscosityModel, LaminarModel, MixingLengthModel, SmagorinskyModel, QRModel
export NoRegConvectionModel, C2ConvectionModel, C4ConvectionModel, LerayConvectionModel

# Processors
export processor, step_logger, vtk_writer, field_saver
export field_plotter, energy_history_plotter, energy_spectrum_plotter
export animator

# Setup
export Setup

# 1D grids
export stretched_grid, cosine_grid

# Pressure solvers
export AbstractPressureSolver,
    DirectPressureSolver, CGPressureSolver, CGPressureSolverManual, SpectralPressureSolver
export pressure_poisson,
    pressure_poisson!, pressure_additional_solve, pressure_additional_solve!

# Operators
export momentum, divergence, pressuregradient, Dfield!, Qfield!

# Problems
export solve_unsteady, solve_steady_state

export create_initial_conditions, random_field, get_velocity

export plot_force,
    plot_grid, plot_pressure, plot_streamfunction, plot_velocity, plot_vorticity, save_vtk
export plotmat

# Closure models
export cnn, fno, FourierLayer
export train
export mean_squared_error, relative_error
export create_randloss, create_callback, create_les_data

# ODE methods

export AdamsBashforthCrankNicolsonMethod, OneLegMethod

# Runge Kutta methods
export ExplicitRungeKuttaMethod, ImplicitRungeKuttaMethod, runge_kutta_method

# Explicit Methods
export FE11, SSP22, SSP42, SSP33, SSP43, SSP104, rSSPs2, rSSPs3, Wray3, RK56, DOPRI6

# Implicit Methods
export BE11, SDIRK34, ISSPm2, ISSPs3

# Half explicit methods
export HEM3, HEM3BS, HEM5

# Classical Methods
export GL1, GL2, GL3, RIA1, RIA2, RIA3, RIIA1, RIIA2, RIIA3, LIIIA2, LIIIA3

# Chebyshev methods
export CHDIRK3, CHCONS3, CHC3, CHC5

# Miscellaneous Methods
export Mid22, MTE22, CN22, Heun33, RK33C2, RK33P2, RK44, RK44C2, RK44C23, RK44P2

# DSRK Methods
export DSso2, DSRK2, DSRK3

# "Non-SSP" Methods of Wong & Spiteri
export NSSP21, NSSP32, NSSP33, NSSP53

end
