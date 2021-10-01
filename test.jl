using IncompressibleNavierStokes
using GLMakie

## Load input parameters and constants
# Case_name = "LDC"
case_name = "BFS_unsteady"
include("case_files/$case_name.jl")
setup = eval(:($(Symbol(case_name))()));

##
V, p, setup, totaltime, solution = main(setup);

##
@profview main(setup)

##
# Turbulence constants
 if setup.case.visc == "keps"
    constants_ke()
end

# Construct mesh
create_mesh!(setup)

# Boundary conditions
create_boundary_conditions!(setup)

# Construct operators (matrices) which are time-independent
build_operators!(setup)

# Initialization of solution vectors
V_start, p_start, t = create_initial_conditions(setup)

# Boundary conditions
set_bc_vectors!(setup, t)

# Input checking
solution = check_input!(setup, V_start, p_start, t)

## Choose between steady and unsteady
if setup.case.is_steady
    # Steady
    if setup.case.visc == "keps"
        # Steady flow with k-epsilon model, 2nd order
        V, p = solve_steady_ke!(solution, setup)
    elseif setup.case.visc == "laminar"
        if setup.discretization.order4
            # Steady flow with laminar viscosity model, 4th order
            V, p = solve_steady!(solution, setup)
        else
            if setup.ibm.ibm
                # Steady flow with laminar viscosity model and immersed boundary method, 2nd order
                V, p = solve_steady_ibm!(solution, setup)
            else
                # Steady flow with laminar viscosity model, 2nd order
                V, p = solve_steady!(solution, setup)
            end
        end
    elseif setup.case.visc == "ML"
        # Steady flow with mixing length, 2nd order
        V, p = solve_steady!(solution, setup)
    else
        error("wrong value for visc parameter")
    end
else
    # Unsteady
    if setup.case.visc == "keps"
        # Unsteady flow with k-eps model, 2nd order
        V, p = solve_unsteady_ke!(solution, setup)
    elseif setup.case.visc ∈ ["laminar", "qr", "LES", "ML"]
        if setup.rom.use_rom
            # Unsteady flow with reduced order model with $(setup.rom.M) modes
            V, p = solve_unsteady_rom!(solution, setup)
        else
            # Unsteady flow with laminar or LES model
            V, p = solve_unsteady!(solution, setup)
        end
    else
        error("wrong value for visc parameter")
    end
    println("simulated time: $t")
end

## Post-processing
postprocess(solution, setup)
plot_vorticity(solution, setup)
plot_pressure(solution, setup)
plot_streamfunction(solution, setup)
