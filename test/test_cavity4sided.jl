@testset "Cavity4Sided" begin
    @testset "Functions" begin
        # Test constructBChelpermat function
        #nodes = [1; 1/2; -1/2; -1] 
        D = [19/6 -4 4/3 -1/2; 1 -1/3 -1 1/3; -1/3 1 1/3 -1; 1/2 -4/3 4 -19/6]

        Minvref = [-9 3; -3 9]/32
        Minv = NS2DBenchmarkSolver.constructBChelpermat(D)

        @test Minv ≈ Minvref

        # Test boundary reconstruction Ψ when imposing derivatives at boundary
        Ψfunc(x, y) = @. sin(π*(x-1)/2) * sin(π*(y-1)/2) 
        DΨxfunc(x, y) = @. π/2 * cos(π*(x-1)/2) * sin(π*(y-1)/2) 
        DΨyfunc(x, y) = @. π/2 * sin(π*(x-1)/2) * cos(π*(y-1)/2) 

        n = 8
        mesh = SpectralMesh2D((n, n))
        Ψexact = [Ψfunc(x,y) for x in mesh.xnodes, y in mesh.ynodes] 

        Ψbcxmin(y) = DΨxfunc(-1, y)
        Ψbcxmax(y) = DΨxfunc(1, y)
        Ψbcymin(x) = DΨyfunc(x, -1)
        Ψbcymax(x) = DΨyfunc(x, 1)

        bcxmin = BCNeumann2D(Ψbcxmin(mesh.ynodes))
        bcxmax = BCNeumann2D(Ψbcxmax(mesh.ynodes))
        bcymin = BCNeumann2D(Ψbcymin(mesh.xnodes))
        bcymax = BCNeumann2D(Ψbcymax(mesh.xnodes))

        Ψint = Ψexact[3:n-1,3:n-1]  
        Ψ = NS2DBenchmarkSolver.constructΨboundary(Ψint, mesh.diffx1mat, mesh.diffy1mat, bcxmin, bcxmax, bcymin, bcymax)
        @test Ψ ≈ Ψexact atol=1e-6

        # Test right-hand-side function of equation for streamfunction 
        # in cavity flow
        n = 6
        nbcells = (n, n)
        xspan = (1, -1)
        yspan = (1, -1)
        mesh = SpectralMesh2D(nbcells, xspan, yspan)

        reynolds = 100
        probl = Cavity4Sided(mesh, reynolds)

        k0 = 10
        bcfunc(x) = ((exp(k0*(x-1)) - 1) * (exp(-k0*(x+1)) - 1))^2

        bcxmin = BCNeumann2D(-bcfunc.(probl.mesh.ynodes))
        bcxmax = BCNeumann2D(bcfunc.(probl.mesh.ynodes))
        bcymin = BCNeumann2D(bcfunc.(probl.mesh.xnodes))
        bcymax = BCNeumann2D(-bcfunc.(probl.mesh.xnodes))

        setBC2D(probl, bcxmin, bcxmax, bcymin, bcymax)

        Ψint = zeros((n-3, n-3))

        Ψ = NS2DBenchmarkSolver.constructΨboundary(Ψint, probl.mesh.diffx1mat, probl.mesh.diffy1mat, bcxmin, bcxmax, bcymin, bcymax)

        FΨ = NS2DBenchmarkSolver.rhs(probl, Ψint)
        FΨref = [-0.0624820681282460, 0.576027334953858, 0.245807608047586, -0.642691167651798, 0.0121206968541711, -0.642691167651798, 0.245807608047580, 0.576027334953857, -0.0624820681282459]
        @test FΨ ≈ FΨref

        # Test right-hand-side function with time stepping of equation for streamfunction 
        # in cavity flow
        ψint = ones((n-3)*(n-3))
        Ψold = ones((n+1, n+1))
        Δt = 1

        FΨ = NS2DBenchmarkSolver.rhstime(probl, Δt, Ψold, ψint)
        FΨref = [21.7652385080886, 7.16533446461262, 17.3663586367691, 3.45590293725733, -6.84022498215817, 3.45590293725730, 17.3663586367691, 7.16533446461265, 21.7652385080885]
        @test FΨ ≈ FΨref

        # Test to construct initial guess 
        Ψinit = NS2DBenchmarkSolver.calculateinitialguess(probl, nbtimesteps=200)
        Ψinitref = [0 0 0 0 0 0 0
                    0 0.0223534291102081 0.0655941971343996 0.0589510766581025 0.0555732229353761 0.0204248917264253 0
                    0 -0.0664329942047326 -0.0337131774973950 -0.0810657532138882 -0.0857836868595323 -0.0764539684037562 0
                    0 -0.0892424343792270 -0.150714381583066 -0.187874748844775 -0.150714381583067 -0.0892424343792272 0
                    0 -0.0764539684037564 -0.0857836868595334 -0.0810657532138900 -0.0337131774973966 -0.0664329942047329 0
                    0 0.0204248917264252 0.0555732229353758 0.0589510766581022 0.0655941971343994 0.0223534291102081 0
                    0 0 0 0 0 0 0]
        @test Ψinit ≈ Ψinitref
    end

    @testset "Setup and solve problem" begin
        nbcells = (4, 4)
        xspan = (1, -1)
        yspan = (1, -1)

        nodes = [1; 0.707106781186548; 0; -0.707106781186548; -1]
        D = [5.5 -6.82842712474619 2  -1.17157287525381 0.5
             1.70710678118655 -0.707106781186548 -1.41421356237310 0.707106781186548 -0.292893218813453
             -0.5 1.41421356237310 0 -1.41421356237310 0.5
             0.292893218813453 -0.707106781186548 1.41421356237310 0.707106781186548 -1.70710678118655
             -0.5 1.17157287525381 -2 6.82842712474619 -5.5]

        mesh = SpectralMesh2D(nbcells, xspan, yspan)

        reynolds = 500
        probl = Cavity4Sided(mesh, reynolds)

        @test probl.mesh.xnodes ≈ nodes
        @test probl.mesh.ynodes ≈ nodes
        @test probl.mesh.diffx1mat ≈ D
        @test probl.mesh.diffy1mat ≈ D

        # Test boundary construction 
        k0 =10
        bcfunc(x) = ((exp(k0*(x-1)) - 1) * (exp(-k0*(x+1)) - 1))^2

        bcxmin = BCNeumann2D(-bcfunc.(probl.mesh.ynodes))
        bcxmax = BCNeumann2D(bcfunc.(probl.mesh.ynodes))
        bcymin = BCNeumann2D(bcfunc.(probl.mesh.xnodes))
        bcymax = BCNeumann2D(-bcfunc.(probl.mesh.xnodes))

        setBC2D(probl, bcxmin, bcxmax, bcymin, bcymax)

        Ψref =  [0 0 0 0 0
                 0 0.0807493117423042 0.124977301580937 0.0807493117423042 0
                 0 -0.124977301580937 0 -0.124977301580937 0
                 0 0.0807493117423043 0.124977301580937 0.0807493117423042 0
                 0 0 0 0 0]

        Ψint = zeros((probl.mesh.xnbcells-3, probl.mesh.ynbcells-3))
        Ψ = NS2DBenchmarkSolver.constructΨboundary(Ψint, mesh.diffx1mat, mesh.diffy1mat, bcxmin, bcxmax, bcymin, bcymax)
        @test Ψ ≈ Ψref

        # Test solve 
        sol = solve(probl)

        Ψsolref = [0 0 0 0 0
                   0 0.0726743805680738 0.0926775768840154 0.0726743805680738 0
                   0 -0.157277026277859 -0.129198898787687 -0.157277026277859 0
                   0 0.0726743805680738 0.0926775768840155 0.0726743805680738 0
                   0 0 0 0 0]

        @test sol.iter == 3
        @test sol.vals ≈ Ψsolref 
    end
end
