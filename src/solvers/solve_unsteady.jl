"""
    solve_unsteady!(solution, setup)

Main solver file for unsteady calculations
"""
function solve_unsteady(setup, V₀, p₀)
    # Setup
    @unpack is_steady, visc = setup.case
    @unpack Nu, Nv, NV, Np, Nx, Ny = setup.grid
    @unpack G, M, yM = setup.discretization
    @unpack Jacobian_type, nPicard, Newton_factor, nonlinear_acc, nonlinear_maxit =
        setup.solver_settings
    @unpack use_rom = setup.rom
    @unpack t_start, t_end, Δt, isadaptive, method, method_startup, time_stepper = setup.time
    @unpack save_unsteady = setup.output
    @unpack do_rtp, rtp_n = setup.visualization

    # Initialize solution vectors
    # Loop index
    n = 1
    t = t_start
    V = copy(V₀)
    p = copy(p₀)

    # Temporary variables
    momentum_cache = MomentumCache(setup)

    # Runge Kutta intermediate stages
    stepper_cache = time_stepper_cache(time_stepper, setup)
    @unpack F, ∇F = stepper_cache

    # For methods that need previous solution
    Vₙ₋₁ = copy(V)
    pₙ₋₁ = copy(p)

    # Current solution
    Vₙ = copy(V)
    pₙ = copy(p)
    tₙ = t
    Δtₙ = Δt

    # Initialize BC arrays
    set_bc_vectors!(setup, t)

    # For methods that need convection from previous time step
    if method == 2
        cₙ₋₁ = convection(V, V, t, setup, false)
    end

    # For methods that need extrapolation of convective terms
    if method ∈ [62, 92, 142, 172, 182, 192]
        V_ep = zeros(NV, method_startup_no)
        V_ep[:, 1] .= V
    end

    method_temp = method

    if do_rtp
        rtp = initialize_rtp(setup, V, p, t)
    end

    # Estimate number of time steps that will be taken
    nt = ceil(Int, (t_end - t_start) / Δt)

    momentum!(F, ∇F, V, V, p, t, setup, momentum_cache)
    maxres = maximum(abs.(F))

    # record(fig, "output/vorticity.mp4", 2:nt; framerate = 60) do n
    while t < t_end
        # Advance one time step
        n += 1
        Vₙ₋₁ .= Vₙ
        pₙ₋₁ .= pₙ
        Vₙ .= V
        pₙ .= p
        tₙ = t

        # Change timestep based on operators
        if isadaptive && rem(n, n_adapt_Δt) == 0
            Δtₙ = get_timestep(setup)
        end
        t = tₙ + Δtₙ

        println("tₙ = $tₙ, maxres = $maxres")

        # For methods that need a velocity field at n-1 the first time step
        # (e.g. AB-CN, oneleg beta) use ERK or IRK
        if method_temp ∈ [2, 5] && n ≤ method_startup_no
            println("Starting up with method $method_startup")
            method = method_startup
        else
            method = method_temp
        end

        # Perform a single time step with the time integration method
        if method == 2
            c = step!(time_stepper, V, p, Vₙ, pₙ, cₙ₋₁, tₙ, Δtₙ, setup, momentum_cache)
            cₙ₋₁ .= c
        elseif method == 5
            step!(time_stepper, V, p, Vₙ, pₙ, Vₙ₋₁, pₙ₋₁, tₙ, Δtₙ, setup, momentum_cache)
        elseif method == 20
            step!(time_stepper, V, p, Vₙ, pₙ, tₙ, Δtₙ, setup, stepper_cache, momentum_cache)
        elseif method == 21
            nonlinear_its = step!(time_stepper, V, p, Vₙ, pₙ, tₙ, Δtₙ, setup, momentum_cache)
        else
            error("time integration method unknown")
        end

        # Calculate mass, momentum and energy
        maxdiv, umom, vmom, k = compute_conservation(V, t, setup)

        # Residual (in Finite Volume form)
        # For ke model residual also contains k and e terms and is computed in solver_unsteady_ke
        if use_rom
            # Get ROM residual
            F, = momentum_rom(R, 0, t, setup)
            maxres = maximum(abs.(F))
        else
            if visc != "keps"
                # Norm of residual
                momentum!(F, ∇F, V, V, p, t, setup, momentum_cache)
                maxres = maximum(abs.(F))
            end
        end

        if do_rtp && mod(n, rtp_n) == 0
            update_rtp!(rtp, setup, V, p, t)
        end
    end

    V, p
end
