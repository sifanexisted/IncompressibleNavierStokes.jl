function ke_diffusion!(setup)
    # Nu_T = C_mu*(Akx*k)^2/(Aex*e)
    # Dkx*(Anu*nu+C_mu*(Akx*k)^2/(Aex*e)).*Skx*k

    ## X-direction

    ## Differencing from faces to centers
    diag1 = ones(Npx) # Nkx = Npx
    D1D = spdiagm(Npx, Npx + 1, 0 => -diag1, 1 => diag1)
    # No BC
    Dkx = kron(mat_hy, D1D)


    ## Averaging from centers to faces
    diag2 = fill(1 / 2, Npx + 1)
    A1D = spdiagm(Npx + 1, Npx + 2, 0 => diag2, 1 => diag2)

    # BCs for k
    # Ak_kx is already constructed in ke_convection
    B1Dk, Btempk, ybcl, ybcr =
        bc_general_stag(Npx + 2, Npx, 2, bck.left, bck.right, hx[1], hx[end])
    ybck = kron(kLe, ybcl) + kron(kRi, ybcr)
    yAk_kx = kron(sparse(I, Npy, Npy), A1D * Btempk) * ybck
    Ak_kx = kron(sparse(I, Npy, Npy), A1D * B1Dk)

    # BCs for e
    B1De, Btempe, ybcl, ybcr =
        bc_general_stag(Npx + 2, Npx, 2, bce.left, bce.right, hx[1], hx[end])
    ybce = kron(eLe, ybcl) + kron(eRi, ybcr)
    yAe_ex = kron(sparse(I, Npy, Npy), A1D * Btempe) * ybce
    Ae_ex = kron(sparse(I, Npy, Npy), A1D * B1De)


    ## Differencing from centers to faces
    diag3 = 1 ./ gxd
    S1D = spdiagm(Npx + 1, Npx + 2, 0 => -diag3, 1 => diag3)

    # Re-use BC generated for averaging k
    Skx = kron(sparse(I, Npy, Npy), S1D * B1Dk)
    ySkx = kron(sparse(I, Npy, Npy), S1D * Btempk) * ybck

    # Re-use BC generated for averaging e
    Sex = kron(sparse(I, Npy, Npy), S1D * B1De)
    ySex = kron(sparse(I, Npy, Npy), S1D * Btempe) * ybce


    ## Y-direction

    ## Differencing from faces to centers
    diag1 = ones(Npy) # Nky = Npy
    D1D = spdiagm(Npy, Npy + 1, 0 => -diag1, 1 => diag1)
    # No BC
    Dky = kron(D1D, mat_hx)


    ## Averaging
    diag2 = fill(1 / 2, Npy + 1)
    A1D = spdiagm(Npy + 1, Npy + 2, 0 => diag2, 1 => diag2)

    # BCs for k:
    # K is already constructed in ke_convection
    B1Dk, Btempk, ybcl, ybcu =
        bc_general_stag(Npy + 2, Npy, 2, bck.low, bck.up, hy[1], hy[end])
    ybck = kron(ybcl, kLo) + kron(ybcu, kUp)
    yAk_ky = kron(A1D * Btempk, sparse(I, Npx, Npx)) * ybck
    Ak_ky = kron(A1D * B1Dk, sparse(I, Npx, Npx))

    # BCs for e:
    B1De, Btempe, ybcl, ybcu =
        bc_general_stag(Npy + 2, Npy, 2, bce.low, bce.up, hy[1], hy[end])
    ybce = kron(ybcl, eLo) + kron(ybcu, eUp)
    yAe_ey = kron(A1D * Btempe, sparse(I, Npx, Npx)) * ybce
    Ae_ey = kron(A1D * B1De, sparse(I, Npx, Npx))


    ## Differencing from centers to faces
    diag3 = 1 ./ gyd
    S1D = spdiagm(Npy + 1, Npy + 2, 0 => -diag3, 1 => diag3)

    # Re-use BC generated for averaging k
    Sky = kron(S1D * B1Dk, sparse(I, Npx, Npx))
    ySky = kron(S1D * Btempk, sparse(I, Npx, Npx)) * ybck

    # Re-use BC generated for averaging e
    Sey = kron(S1D * B1De, sparse(I, Npx, Npx))
    ySey = kron(S1D * Btempe, sparse(I, Npx, Npx)) * ybce

    setup
end
