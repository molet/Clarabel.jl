## ------------------------------------
# Nonnegative Cone
# -------------------------------------

function rectify_equilibration!(
    K::NonnegativeCone{T},
    δ::AbstractVector{T},
    e::AbstractVector{T}
) where{T}

    #allow elementwise equilibration scaling
    δ .= e
    return false
end

# place vector into nn cone
function shift_to_cone!(
    K::NonnegativeCone{T},
    z::AbstractVector{T}
) where{T}

    thresh = sqrt(eps(T))

    # do this elementwise, otherwise splitting a nonnegative cone 
    # into multiple small cones will give us a different solution 
    for i in eachindex(z) 
        z[i] = z[i] < thresh ? one(T) : z[i]
    end

    return nothing
end

# unit initialization for asymmetric solves
function unit_initialization!(
   K::NonnegativeCone{T},
   z::AbstractVector{T},
   s::AbstractVector{T}
) where{T}

    s .= one(T)
    z .= one(T)

   return nothing
end

#configure cone internals to provide W = I scaling
function set_identity_scaling!(
    K::NonnegativeCone{T}
) where {T}

    K.w .= 1

    return nothing
end

function update_scaling!(
    K::NonnegativeCone{T},
    s::AbstractVector{T},
    z::AbstractVector{T},
    μ::T,
    scaling_strategy::ScalingStrategy
) where {T}

    @. K.λ = sqrt(s*z)
    @. K.w = sqrt(s/z)

    return nothing
end

function get_Hs!(
    K::NonnegativeCone{T},
    Hsblock::AbstractVector{T}
) where {T}

    #this block is diagonal, and we expect here
    #to receive only the diagonal elements to fill
    @. Hsblock = K.w^2

    return nothing
end

# compute the product y = WᵀWx
function mul_Hs!(
    K::NonnegativeCone{T},
    y::AbstractVector{T},
    x::AbstractVector{T},
    work::AbstractVector{T}
) where {T}

    #NB : seemingly sensitive to order of multiplication
    @. y = (K.w * (K.w * x))

end

# returns ds = λ∘λ for the nn cone
function affine_ds!(
    K::NonnegativeCone{T},
    ds::AbstractVector{T},
    s::AbstractVector{T}
) where {T}

    @. ds = K.λ^2

    return nothing
end

function combined_ds_shift!(
    K::NonnegativeCone{T},
    dz::AbstractVector{T},
    step_z::AbstractVector{T},
    step_s::AbstractVector{T},
    σμ::T
) where {T}

    _combined_ds_shift_symmetric!(K,dz,step_z,step_s,σμ);

end

function Δs_from_Δz_offset!(
    K::NonnegativeCone{T},
    out::AbstractVector{T},
    rs::AbstractVector{T},
    work::AbstractVector{T}
) where {T}

    _Δs_from_Δz_offset_symmetric!(K,out,rs,work);
end

#return maximum allowable step length while remaining in the nn cone
function step_length(
    K::NonnegativeCone{T},
    dz::AbstractVector{T},
    ds::AbstractVector{T},
     z::AbstractVector{T},
     s::AbstractVector{T},
     settings::Settings{T},
     αmax::T
) where {T}

    αz = αmax
    αs = αmax

    for i in eachindex(ds)
        αz = dz[i] < 0 ? (min(αz,-z[i]/dz[i])) : αz
        αs = ds[i] < 0 ? (min(αs,-s[i]/ds[i])) : αs
    end

    return (αz,αs)
end

function compute_barrier(
    K::NonnegativeCone{T},
    z::AbstractVector{T},
    s::AbstractVector{T},
    dz::AbstractVector{T},
    ds::AbstractVector{T},
    α::T
) where {T}

    barrier = T(0)
    @inbounds for i = 1:K.dim
        si = s[i] + α*ds[i]
        zi = z[i] + α*dz[i]
        barrier -= logsafe(si * zi)
    end

    return barrier
end

# ---------------------------------------------
# operations supported by symmetric cones only 
# ---------------------------------------------

# implements y = y + αe for the nn cone
function add_scaled_e!(
    K::NonnegativeCone{T},
    x::AbstractVector{T},α::T
) where {T}

    #e is a vector of ones, so just shift
    @. x += α

    return nothing
end

# implements y = αWx + βy for the nn cone
function mul_W!(
    K::NonnegativeCone{T},
    is_transpose::Symbol,
    y::AbstractVector{T},
    x::AbstractVector{T},
    α::T,
    β::T
) where {T}

  #W is diagonal so ignore transposition
  #@. y = α*(x*K.w) + β*y
  @inbounds for i = eachindex(y)
      y[i] = α*(x[i]*K.w[i]) + β*y[i]
  end

  return nothing
end

# implements y = αW^{-1}x + βy for the nn cone
function mul_Winv!(
    K::NonnegativeCone{T},
    is_transpose::Symbol,
    y::AbstractVector{T},
    x::AbstractVector{T},
    α::T,
    β::T
) where {T}

  #W is diagonal, so ignore transposition
  #@. y = α*(x/K.w) + β.*y
  @inbounds for i = eachindex(y)
      y[i] = α*(x[i]/K.w[i]) + β*y[i]
  end

  return nothing
end

# implements x = λ \ z for the nn cone, where λ
# is the internally maintained scaling variable.
function λ_inv_circ_op!(
    K::NonnegativeCone{T},
    x::AbstractVector{T},
    z::AbstractVector{T}
) where {T}

    inv_circ_op!(K, x, K.λ, z)

end

# ---------------------------------------------
# Jordan algebra operations for symmetric cones 
# ---------------------------------------------

# implements x = y ∘ z for the nn cone
function circ_op!(
    K::NonnegativeCone{T},
    x::AbstractVector{T},
    y::AbstractVector{T},
    z::AbstractVector{T}
) where {T}

    @. x = y*z

    return nothing
end

# implements x = y \ z for the nn cone
function inv_circ_op!(
    K::NonnegativeCone{T},
    x::AbstractVector{T},
    y::AbstractVector{T},
    z::AbstractVector{T}
) where {T}

    @. x = z/y

    return nothing
end