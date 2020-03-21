# export
#     Traj,
# 	states,
# 	controls,
# 	set_states!,
# 	set_controls!

traj_size(Z::Vector{<:KnotPoint{T,N,M}}) where {T,N,M} = N,M,length(Z)

function Base.copy(Z::Vector{KnotPoint{T,N,M}}) where {T,N,M}
    [KnotPoint((@SVector ones(N+M)) .* z.z, z._x, z._u, z.dt, z.t) for z in Z]
end

function Traj(n::Int, m::Int, dt::AbstractFloat, N::Int, equal=false)
    x = NaN*@SVector ones(n)
    u = @SVector zeros(m)
    Traj(x,u,dt,N,equal)
end

function Traj(x::SVector, u::SVector, dt::AbstractFloat, N::Int, equal=false)
    equal ? uN = N : uN = N-1
    Z = [KnotPoint(x,u,dt,(k-1)*dt) for k = 1:uN]
    if !equal
        m = length(u)
        push!(Z, KnotPoint(x,m,(N-1)*dt))
    end
    return Z
end

function Traj(X::Vector, U::Vector, dt::Vector, t=cumsum(dt) .- dt[1])
    Z = [KnotPoint(X[k], U[k], dt[k], t[k]) for k = 1:length(U)]
    if length(U) == length(X)-1
        push!(Z, KnotPoint(X[end],length(U[1]),t[end]))
    end
    return Z
end

@inline states(Z::Traj) = state.(Z)
@inline controls(Z::Traj) = control.(Z[1:end-1])

states(Z::Traj, i::Int) = [state(z)[i] for z in Z]

function set_states!(Z::Traj, X)
    for k in eachindex(Z)
        Z[k].z = [X[k]; control(Z[k])]
    end
end

function set_controls!(Z::Traj, U)
    for k in 1:length(Z)-1
        Z[k].z = [state(Z[k]); U[k]]
    end
end

function set_controls!(Z::Traj, u::SVector)
    for k in 1:length(Z)-1
        Z[k].z = [state(Z[k]); u]
    end
end

function set_times!(Z::Traj, ts)
    for k in eachindex(ts)
        Z[k].t = ts[k]
    end
end

function get_times(Z::Traj)
    [z.t for z in Z]
end

function shift_fill!(Z::Traj)
    N = length(Z)
    for k in eachindex(Z)
        Z[k].t += Z[k].dt
        if k < N
            Z[k].z = Z[k+1].z
        else
            Z[k].t += Z[k-1].dt
        end
    end
end



#~~~~~~~~~~~~~~~~~~~~~~~~~~ FUNCTIONS ON TRAJECTORIES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

"Evaluate the discrete dynamics for all knot points"
function discrete_dynamics!(f, model, Z::Traj)
    for k in eachindex(Z)
        f[k] = discrete_dynamics(model, Z[k])
    end
end

@inline error_expansion!(D::Vector{<:DynamicsExpansion}, model::AbstractModel, G) = nothing

function error_expansion!(D::Vector{<:DynamicsExpansion}, model::RigidBody, G)
	for k in eachindex(D)
		error_expansion!(D[k], G[k], G[k+1])
	end
end

function state_diff_jacobian!(G, model::RigidBody, Z::Traj)
    for k in eachindex(Z)
        G[k] .= state_diff_jacobian(model, state(Z[k]))
    end
end

function rollout!(model::AbstractModel, Z::Traj, x0)
    Z[1].z = [x0; control(Z[1])]
    for k = 2:length(Z)
        RobotDynamics.propagate_dynamics(DEFAULT_Q, model, Z[k], Z[k-1])
    end
end
