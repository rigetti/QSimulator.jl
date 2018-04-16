# solvers for time evolution of quantum systems

using DifferentialEquations

import QSimulator.add_parametric_hamiltonians!

export unitary_propagator,
       unitary_state,
       me_state

"""
    schrodinger(cqs::CompositeQSystem, ts::Float64; u0::Matrix=Matrix{Complex128}(0,0), t0=0.0)

Compute the unitary propagator evolution of a CompositeQSystem evaluted at ts.
"""
function unitary_propagator(cqs::CompositeQSystem, ts::Vector; u0=Matrix{Complex128}(0,0), t0=0.0)
    # schrodinger differential equation for unitary with in place update
    # dU/dt = -iHU
    function ode(du, u, p, t)
        ham = p[3] # preallocated workspace array
        ham .= p[2] # start from fixed_ham
        add_parametric_hamiltonians!(ham, p[1], t)
        scale!(ham, -1im)
        A_mul_B!(du, ham, u)
    end
    # scale Hamiltonian from Hz to rad.
    fixed_ham = 2pi * hamiltonian(cqs)
    # if initial condition not passed start with identity
    if isempty(u0)
        u0 = eye(Complex128, dim(cqs))
    end
    work_ham = similar(fixed_ham) # scratch space
    prob = ODEProblem(ode, u0, (t0, float(ts[end])), (cqs, fixed_ham, work_ham))
    save_start = ts[1]==t0 ? true : false #save t0 only if asked for
    sol = solve(prob; saveat=ts, save_start=save_start, reltol=1e-6)
    sol.u
end


"""
    unitary_state(cqs::CompositeQSystem, ts::Float64, ψ0::Vector, t0=0.0)

Compute the unitary state evolution of a CompositeQSystem from initial state ψ0 evaluted at ts.
"""
function unitary_state(cqs::CompositeQSystem, ts::Vector, ψ0::Vector; t0=0.0)
    # schrodinger differential equation for state vector with in place update
    # dψ/dt = -iHψ
    function ode(dψ, ψ, p, t)
        ham = p[3] # preallocated workspace array
        ham .= p[2] # start from fixed_ham
        add_parametric_hamiltonians!(ham, p[1], t)
        scale!(ham, -1im)
        A_mul_B!(dψ, ham, ψ)
    end
    # scale Hamiltonian from Hz to rad.
    fixed_ham = 2pi * hamiltonian(cqs)
    work_ham = similar(fixed_ham)
    prob = ODEProblem(ode, ψ0, (t0, float(ts[end])), (cqs, fixed_ham, work_ham))
    save_start = ts[1]==t0 ? true : false #save t0 only if asked for
    sol = solve(prob; saveat=ts, save_start=save_start, reltol=1e-6)
    sol.u
end


"""
    me_state(cqs::CompositeQSystem, ts::Float64, ρ0::Matrix, t0=0.0)

Compute the master equation evolution of a CompositeQSystem from initial density
matrix ρ0 evaluted at ts.
"""
function me_state(cqs::CompositeQSystem, ts::Vector, ρ0::Matrix; t0=0.0)
    # schrodinger differential equation for density matrix with in place update
    # dρ/dt = -i[H, ρ]
    function ode(dρ, ρ, p, t)
        ham = p[3] # preallocated workspace array
        ham .= p[2] # start from fixed_ham
        add_parametric_hamiltonians!(ham, p[1], t)
        dρ .= -1im * (ham*ρ - ρ*ham)
        lind_mat = p[5]
        for (lind_op, idxs) = p[1].lind_op
            lind_mat .= p[4] # start with empty array
            embed_add!(lind_mat, lind_op, idxs)
            dρ .+= lind_mat*ρ*lind_mat' .- .5.*lind_mat'*lind_mat*ρ .- .5.*ρ*lind_mat'*lind_mat
        end

        for (lind_op, idxs, time_func) = p[1].time_dependent_lind_op
            lind_mat .= p[4] # start with empty array
            embed_add!(lind_mat, time_func(t) * lind_op, idxs)
            dρ .+= lind_mat*ρ*lind_mat' .- .5.*lind_mat'*lind_mat*ρ .- .5.*ρ*lind_mat'*lind_mat
        end

        for (lind_op, idxs) = p[1].functional_lind_op
            lind_mat .= p[4] # start with empty array
            embed_add!(lind_mat, [el(t) for el in lind_op], idxs)
            dρ .+= lind_mat*ρ*lind_mat' .- .5.*lind_mat'*lind_mat*ρ .- .5.*ρ*lind_mat'*lind_mat
        end
    end
    # scale Hamiltonian from Hz to rad/s.
    fixed_ham = 2pi * hamiltonian(cqs)
    work_ham = similar(fixed_ham)
    bare_lind = zeros(Complex128, size(fixed_ham))
    work_lind = similar(fixed_ham)
    prob = ODEProblem(ode, ρ0, (t0, float(ts[end])), (cqs, fixed_ham, work_ham, bare_lind, work_lind))
    save_start = ts[1]==t0 ? true : false #save t0 only if asked for
    sol = solve(prob; saveat=ts, save_start=save_start, reltol=1e-6)
    sol.u
end

# add helper functions for saving at a single point
unitary_propagator{T<:Number}(cqs::CompositeQSystem, t::T; u0=Matrix{Complex128}(0,0), t0=0.0) = unitary_propagator(cqs, [t]; u0=u0, t0=t0)[1]
unitary_state{T<:Number}(cqs::CompositeQSystem, t::T, ψ0::Vector; t0=0.0) = unitary_state(cqs, [t], ψ0; t0=t0)[1]
me_state{T<:Number}(cqs::CompositeQSystem, t::T, ρ0::Matrix; t0=0.0) = me_state(cqs, [t], ρ0; t0=t0)[1]
