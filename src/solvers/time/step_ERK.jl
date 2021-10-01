"""
    step_ERK()

Perform one time step for the general explicit Runge-Kutta method (ERK).

Dirichlet boundary points are not part of solution vector but are prescribed in a strong manner via the `ubc` and `vbc` functions.
"""
function step_ERK!(V, p, Vₙ, pₙ, tₙ, f, kV, kp, Vtemp, Vtemp2, Δt, setup, cache, F, ∇F)
    @unpack Nu, Nv, Np, Ω⁻¹ = setup.grid
    @unpack G, M, yM = setup.discretization

    ## Get coefficients of RK method
    A, b, c, = tableau(setup.time.rk_method)

    # Number of stages
    nstage = length(b)

    # We work with the following "shifted" Butcher tableau, because A[1, :]
    # Is always zero for explicit methods
    A = [A[2:end, :]; b']

    # Vector with time instances (1 is the time level of final step)
    c = [c[2:end]; 1]

    # Reset RK arrays
    kV .= 0
    kp .= 0

    # Store variables at start of time step
    V .= Vₙ
    p .= pₙ

    if setup.bc.bc_unsteady
        set_bc_vectors!(setup, tₙ)
    end

    tᵢ = tₙ

    ## Start looping over stages

    # At i = 1 we calculate F₁, p₂ and u₂
    # ⋮
    # At i = s we calculate Fₛ, pₙ₊₁, and uₙ₊₁
    for i = 1:nstage
        # Right-hand side for tᵢ based on current velocity field uₕ, vₕ at, level i
        # This includes force evaluation at tᵢ and pressure gradient
        # Boundary conditions will be set through set_bc_vectors! inside momentum
        # The pressure p is not important here, it will be removed again in the
        # Next step
        momentum!(F, ∇F, V, V, p, tᵢ, setup, cache)

        # Store right-hand side of stage i
        # By adding G*p we effectively REMOVE the pressure contribution Gx*p and Gy*p (but not the vectors y_px and y_py)
        kVi = @view kV[:, i]
        mul!(kVi, G, p)
        @. kVi = Ω⁻¹ * (F + kVi)
        # kVi = Ω⁻¹ .* (F + G * p)

        # Update velocity current stage by sum of Fᵢ's until this stage,
        # Weighted with Butcher tableau coefficients
        # This gives uᵢ₊₁, and for i=s gives uᵢ₊₁
        mul!(Vtemp, kV, A[i, :])

        # Boundary conditions at tᵢ₊₁
        tᵢ = tₙ + c[i] * Δt
        if setup.bc.bc_unsteady
            set_bc_vectors!(setup, tᵢ)
        end

        # Divergence of intermediate velocity field
        @. Vtemp2 = Vₙ / Δt + Vtemp
        mul!(f, M, Vtemp2)
        @. f = (f + yM / Δt) / c[i]
        # F = (M * (Vₙ / Δt + Vtemp) + yM / Δt) / c[i]

        # Solve the Poisson equation, but not for the first step if the boundary conditions are steady
        if setup.bc.bc_unsteady || i > 1
            # The time tᵢ below is only for output writing
            Δp = pressure_poisson(f, tᵢ, setup)
        else
            # Bc steady AND i = 1
            Δp = pₙ
        end

        # Store pressure
        kp[:, i] .= Δp

        mul!(Vtemp2, G, Δp)

        # Update velocity current stage, which is now divergence free
        @. V = Vₙ + Δt * (Vtemp - c[i] * Ω⁻¹ * Vtemp2)
    end

    if setup.bc.bc_unsteady
        if setup.solversettings.p_add_solve
            pressure_additional_solve!(V, p, tₙ + Δt, setup, cache, F)
        else
            # Standard method
            p .= kp[:, end]
        end
    else
        # For steady bc we do an additional pressure solve
        # That saves a pressure solve for i = 1 in the next time step
        pressure_additional_solve!(V, p, tₙ + Δt, setup, cache, F)
    end

    V, p
end
