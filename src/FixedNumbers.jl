module FixedNumbers

export Fixed, FixedInteger, FixedReal, FixedNumber, @fixednumbers, fix

const FixedError = ErrorException("Illegal type parameter for Fixed.")

"""
A `FixedInteger` is an `Integer` whose value is stored in the type, and which
contains no runtime data.
"""
struct FixedInteger{X} <: Integer
    function FixedInteger{X}() where {X}
        X isa Integer && !(X isa Fixed) && isimmutable(X) || throw(FixedError)
        new{X}()
    end
end

FixedInteger(x::Integer) = FixedInteger{x}()

"""
A `FixedReal` is a `Real` whose value is stored in the type, and which
contains no runtime data.
"""
struct FixedReal{X} <: Real
    function FixedReal{X}() where {X}
        X isa Real && !(X isa Integer) && !(X isa Fixed) && isimmutable(X) || throw(FixedError)
        new{X}()
    end
end

FixedReal(x::Real) = FixedReal{x}()

"""
A `FixedNumber` is a `Number` whose value is stored in the type, and which
contains no runtime data.
"""
struct FixedNumber{X} <: Number
    function FixedNumber{X}() where {X}
        X isa Number && !(X isa Real) && !(X isa Fixed) && isimmutable(X) || throw(FixedError)
        new{X}()
    end
end

FixedNumber(x::Number) = FixedNumber{x}()

"""
`Fixed{X}` is short-hand for the `Union` of `FixedInteger{X}`, `FixedReal{X}`
and `FixedNumber{X}`.
"""
const Fixed{X} = Union{FixedInteger{X}, FixedReal{X}, FixedNumber{X}}

# We'll allow this constructor, but not recommend it.
Fixed{X}() where X = Fixed(X)

# This is the recommended constructor.
"""
`Fixed(X)` is shorthand for `FixedInteger{X}()`, `FixedReal{X}()` or `FixedNumber{X}()`,
depending on the type of `X`.
"""
Base.@pure Fixed(X::Fixed) = X
Base.@pure Fixed(X::Integer) = FixedInteger{X}()
Base.@pure Fixed(X::Real) = FixedReal{X}()
Base.@pure Fixed(X::Number) = FixedNumber{X}()

Base.promote_rule(::Type{<:Fixed{X}}, ::Type{<:Fixed{X}}) where {X} =
    typeof(X)
# We need to override promote and promote_typeof because they don't even call
# promote_rule for all-same types.
for T in (FixedInteger, FixedReal, FixedNumber)
    @eval Base.promote(::$T{X}, ys::$T{X}...) where {X} = ntuple(i->X, 1+length(ys))
    @eval Base.promote_typeof(::$T{X}, ::$T{X}...) where {X} = typeof(X)
end

Base.promote_rule(::Type{<:Fixed{X}}, ::Type{<:Fixed{Y}}) where {X,Y} =
    promote_type(typeof(X),typeof(Y))

Base.promote_rule(::Type{<:Fixed{X}}, ::Type{T}) where {X,T<:Number} =
    promote_type(typeof(X), T)

Base.convert(T::Type{<:Fixed{X}}, y::Number) where {X} = X == y ? T() : InexactError(:convert, T, y)

Base.convert(::Type{T}, ::Fixed{X}) where {T<:Number,X} = convert(T, X)

# TODO: Constructors to avoid Fixed{Fixed}

# Some of the more common constructors that do not default to `convert`
for T in (:Bool, :Int32, :UInt32, :Int64, :UInt64, :Int128, :Integer)
    @eval Base.$T(::FixedInteger{X}) where X = $T(X)
end
for T in (:Float32, :Float64, :AbstractFloat, :Rational)
    @eval Base.$T(::Union{FixedInteger{X}, FixedReal{X}}) where X = $T(X)
end
for T in (:ComplexF32, :ComplexF64, :Complex)
    @eval Base.$T(::Fixed{X}) where X = $T(X)
end
Rational{T}(::Union{FixedInteger{X}, FixedReal{X}}) where {T,X} = Rational{T}(X)
Complex{T}(::Fixed{X}) where {T,X} = Rational{T}(X)
# big(x) still defaults to convert.

# Single-argument functions that do not already work.
for fun in (:-, :zero, :one, :oneunit, :trailing_zeros, :widen)
    @eval Base.$fun(::Fixed{X}) where X = $fun(X)
end

# Other functions that do not already work
Base.:(<<)(::FixedInteger{X}, y::UInt64) where {X} = X << y
Base.:(>>)(::FixedInteger{X}, y::UInt64) where {X} = X >> y

# Two-argument functions that have methods in promotion.jl that give no_op_err:
for f in (:+, :*, :/, :^)
    @eval Base.$f(::Fixed{X}, ::Fixed{X}) where {X} = $f(X,X)
end
# ...where simplifications are possible:
Base.:-(::Fixed{X}, ::Fixed{X}) where {X} = zero(X)
Base.:&(::Fixed{X}, ::Fixed{X}) where {X} = X
Base.:|(::Fixed{X}, ::Fixed{X}) where {X} = X
Base.:xor(::Fixed{X}, ::Fixed{X}) where {X} = zero(X)
Base.:<(::Fixed{X}, ::Fixed{X}) where {X} = false
Base.:<=(::Fixed{X}, ::Fixed{X}) where {X} = true
Base.:rem(::Fixed{X}, ::Fixed{X}) where {X} = zero(X)
Base.:mod(::Fixed{X}, ::Fixed{X}) where {X} = zero(X)

# Three-argument function that gives no_op_err
fma(x::Fixed{X}, y::Fixed{X}, z::Fixed{X}) where {X} = fma(X,X,X)

# For brevity, all `Fixed` numbers are displayed as `Fixed(X)`, rather than, for
# example, `FixedInteger{X}()`. It is possible to discern between the different
# types of `Fixed` by looking at `X`.
# To get the default behaviour back, run:
#   methods(Base.show, (IO, Fixed{X} where X)) |> first |> Base.delete_method
function Base.show(io::IO, x::Fixed{X}) where X
    print(io, "Fixed(")
    show(io, X)
    print(io, ")")
end

"""
fix(x, y1, y2, ...)
Test if a number `x` is equal to any of the `Fixed` numbers `y1`, `y2`, ...,
and in that case return the fixed number. Otherwise, `x` is returned unchanged.
"""
@inline fix(x::Number) = x
@inline fix(x::Number, y::Fixed, ys::Fixed...) = x == y ? y : fix(x, ys...)
@inline fix(x::Fixed, ys::Fixed...) = x # shortcut
@inline fix(x::Number, ys::Number...) = fix(x, map(Fixed, ys)...)
# TODO: Use a tree search for long, sorted lists.

include("macros.jl")

end # module
