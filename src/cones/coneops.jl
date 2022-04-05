# -----------------------------------------------------
# dispatch operators for multiple cones
# -----------------------------------------------------

function cones_all_symmetric(cones::ConeSet{T}) where {T}
    return any(is_symmetric, cones)
end

function cones_rectify_equilibration!(
    cones::ConeSet{T},
     δ::ConicVector{T},
     e::ConicVector{T}
) where{T}

    any_changed = false

    #we will update e <- δ .* e using return values
    #from this function.  default is to do nothing at all
    δ .= 1

    for i = eachindex(cones)
        any_changed |= rectify_equilibration!(cones[i],δ.views[i],e.views[i])
    end

    return any_changed
end


function cones_update_scaling!(
    cones::ConeSet{T},
    s::ConicVector{T},
    z::ConicVector{T},
	μ::T
) where {T}

    # update cone scalings by passing subview to each of
    # the appropriate cone types.
    for i = eachindex(cones)
        update_scaling!(cones[i],s.views[i],z.views[i],μ)
    end

    return nothing
end


function cones_set_identity_scaling!(
    cones::ConeSet{T}
) where {T}

    for i = eachindex(cones)
        set_identity_scaling!(cones[i])
    end

    return nothing
end


# The WtW block for each cone.
function cones_get_WtW_blocks!(
    cones::ConeSet{T},
    WtWblocks::Vector{Vector{T}}
) where {T}

    for i = eachindex(cones)
        get_WtW_block!(cones[i],WtWblocks[i])
    end
    return nothing
end

# YC:x = λ ∘ λ for symmetric cone and x = s for unsymmetric cones
function cones_λ_circ_λ!(
    cones::ConeSet{T},
    x::ConicVector{T},
    s::ConicVector{T}
) where {T}

    for i = eachindex(cones)
        # don't implement it for unsymmetric cones
        if cones.types[i] != ExponentialConeT
            λ_circ_λ!(cones[i],x.views[i])
        else
            # NB: check whether the following line is needed
            x.views[i] .= s.views[i]
        end
    end
    return nothing
end

# YC:   x = y ∘ z for symmetric cones
#       x = 0 for unsymmetric cones
function cones_circ_op!(
    cones::ConeSet{T},
    x::ConicVector{T},
    y::ConicVector{T},
    z::ConicVector{T}
) where {T}

    for i = eachindex(cones)
        # don't implement it for unsymmetric cones
        if cones.types[i] != ExponentialConeT
            circ_op!(cones[i],x.views[i],y.views[i],z.views[i])
        else
        # set unsymmtric parts of x to 0
            x.views[i] .= 0
        end
    end
    return nothing
end

# x = λ \ z,  where λ is scaled internal
# variable for each cone
function cones_λ_inv_circ_op!(
    cones::ConeSet{T},
    x::ConicVector{T},
    z::ConicVector{T}
) where {T}

    for i = eachindex(cones)
        # don't implement it for unsymmetric cones
        if cones.types[i] != ExponentialConeT
            λ_inv_circ_op!(cones[i],x.views[i],z.views[i])
        end
    end
    return nothing
end

# x = y \ z
function cones_inv_circ_op!(
    cones::ConeSet{T},
    x::ConicVector{T},
    y::ConicVector{T},
    z::ConicVector{T}
) where {T}

    for i = eachindex(cones)
        # don't implement it for unsymmetric cones
        if cones.types[i] != ExponentialConeT
            inv_circ_op!(cones[i],x.views[i],y.views[i],z.views[i])
        end
    end
    return nothing
end

# place a vector to some nearby point in the cone
# YC: only when there is no unsymmetric cone
function cones_shift_to_cone!(
    cones::ConeSet{T},
    z::ConicVector{T}
) where {T}

    for i = eachindex(cones)
        shift_to_cone!(cones[i],z.views[i])
    end
    return nothing
end

# initialization when with unsymmetric cones
function unit_initialization!(
    cones::ConeSet{T},
    s::ConicVector{T},
    z::ConicVector{T}
) where {T}

    for i = eachindex(cones)
        unsymmetric_init!(cones[i],s.views[i],z.views[i])
    end
    return nothing
end

# computes y = αWx + βy, or y = αWᵀx + βy, i.e.
# similar to the BLAS gemv interface.
#Warning: x must not alias y.
function cones_gemv_W!(
    cones::ConeSet{T},
    is_transpose::Symbol,
    x::ConicVector{T},
    y::ConicVector{T},
    α::T,
    β::T
) where {T}

    #@assert (x !== y)
    for i = eachindex(cones)
        # don't implement it for unsymmetric cones
        if cones.types[i] != ExponentialConeT
            gemv_W!(cones[i],is_transpose,x.views[i],y.views[i],α,β)
        end
    end
    return nothing
end

# computes y = αW^{-1}x + βy, or y = αW⁻ᵀx + βy, i.e.
# similar to the BLAS gemv interface.
#Warning: x must not alias y.
function cones_gemv_Winv!(
    cones::ConeSet{T},
    is_transpose::Symbol,
    x::ConicVector{T},
    y::ConicVector{T},
    α::T,
    β::T
) where {T}

    #@assert x !== y
    for i = eachindex(cones)
        # don't implement it for unsymmetric cones
        if cones.types[i] != ExponentialConeT
            gemv_Winv!(cones[i],is_transpose,x.views[i],y.views[i],α,β)
        end
    end
    return nothing
end

#computes y = y + αe
# YC: one is for symmetric initialization and the symmetric combined step;
#       one is for unsymmetric centralling in the combined step
function cones_add_scaled_e!(
    cones::ConeSet{T},
    x::ConicVector{T},
    α::T
) where {T}

    for i = eachindex(cones)
        # don't implement it for unsymmetric cones
        if cones.types[i] != ExponentialConeT
            add_scaled_e!(cones[i],x.views[i],α)
        else
            add_grad!(cones[i],x.views[i],α)    # nonsymmetric centralling
        end
    end
    return nothing
end

# maximum allowed step length over all cones
function cones_step_length(
    cones::ConeSet{T},
    dz::ConicVector{T},
    ds::ConicVector{T},
    dτ::T,
    dκ::T,
     z::ConicVector{T},
     s::ConicVector{T},
     τ::T,
     κ::T,
    α::T
) where {T}
    dz    = dz.views
    ds    = ds.views
    z     = z.views
    s     = s.views


    # YC: implement step search for symmetric cones first
    # NB: split the step search for symmetric and unsymmtric cones due to the complexity of the latter
    for i = eachindex(cones)
        if cones.types[i] != ExponentialConeT
            (nextαz,nextαs) = step_length(cones[i],dz[i],ds[i],z[i],s[i])
            α = min(α,nextαz,nextαs)
        end
    end

    # feasible step_size for unsymmetric cones
    for i = eachindex(cones)
        # don't implement it for unsymmetric cones
            if cones.types[i] == ExponentialConeT
            αzs = unsymmetric_step_length(cones[i],dz[i],ds[i],z[i],s[i],α,cones.scaling)
            α = min(α,αzs)
        end
    end

    return α
end

# check the distance to the boundary for unsymmetric cones
function check_exp_μ_and_centrality(cones::ConeSet{T},
    dz::ConicVector{T},
    ds::ConicVector{T},
    dτ::T,
    dκ::T,
     z::ConicVector{T},
     s::ConicVector{T},
     τ::T,
     κ::T,
     zs::T,dzs::T,s_dz::T,z_ds::T,α::T
) where {T}

    dz    = dz.views
    ds    = ds.views
    z     = z.views
    s     = s.views

    length_exp = cones.type_counts[ExponentialConeT]
    ind_exp = cones.ind_exp
    scaling = cones.scaling

    for j = 1:20
        #Initialize μ
        central_coef = cones.degree + 1
        μ = (zs + τ*κ + α*(s_dz + z_ds + dτ*κ + τ*dκ) + α^2*(dzs + dτ*dκ))/central_coef
        upper = cones.minDist*μ     #bound for boundary distance

        #balance global and local μ
        for i = 1:length_exp
            μi = dot(z[ind_exp[i]] + α*dz[ind_exp[i]],s[ind_exp[i]] + α*ds[ind_exp[i]])/3
            # if too close to boundary
            if μi < upper
                println("too close to boundary")
                α *= scaling
                μ = (zs + τ*κ + α*(s_dz + z_ds + dτ*κ + τ*dκ) + α^2*(dzs + dτ*dκ))/(cones.degree + 1)

                i = 0   #restart from the first exponential cone
            end
        end

        # check centrality, functional proximity measure
        barrier = central_coef*log(μ) - log(τ) - log(κ)
        for i = eachindex(cones)
            barrier += f_sum(cones[i], s[i], z[i])
        end

        if barrier < 1.
            return α
        else
            α *= scaling    #backtrack line search
        end
        println("centrality quite bad: ", barrier, " with ", central_coef)
    end

    return α
end
