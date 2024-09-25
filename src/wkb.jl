"""
Well Known Binary (WKB) represents `geometry` as:
- `UInt8` an endianness header
- `UInt32` a geometry type (if not known beforehand)
- `UInt32` the number of subgeometries (if any depending on the type)
- `Vector{geometry}` the subgeometries (if any depending on the type) or
- `Vector{Float64}` the coordinates of the underlying points

Knowing the type of subgeometries (and thus the Simple Features type hierarchy) is required.
For example, because a Polygon always has rings (either exterior or interior ones),
the (sub)geometry type of those rings are skipped (LinearRing). The opposite
is true for a GeometryCollection, when the subgeometry types are not known beforehand.
"""

# Map GeoInterface type traits directly to their WKB UInt32 interpretation
const PointTraitCode = UInt32(1)
geometry_code(::GI.PointTrait) = PointTraitCode
const LineStringTraitCode = UInt32(2)
geometry_code(::GI.LineStringTrait) = LineStringTraitCode
const PolygonTraitCode = UInt32(3)
geometry_code(::GI.PolygonTrait) = PolygonTraitCode
const MultiPointTraitCode = UInt32(4)
geometry_code(::GI.MultiPointTrait) = MultiPointTraitCode
const MultiLineStringTraitCode = UInt32(5)
geometry_code(::GI.MultiLineStringTrait) = MultiLineStringTraitCode
const MultiPolygonTraitCode = UInt32(6)
geometry_code(::GI.MultiPolygonTrait) = MultiPolygonTraitCode
const GeometryCollectionTraitCode = UInt32(7)
geometry_code(::GI.GeometryCollectionTrait) = GeometryCollectionTraitCode

# bitflags for EWKB
const wkbZ = 0x80000000
const wkbM = 0x40000000
const wkbSRID = 0x20000000

const geowkb = Dict{DataType,UInt32}(
    GI.PointTrait => UInt32(1),
    GI.LineStringTrait => UInt32(2),
    GI.PolygonTrait => UInt32(3),
    GI.MultiPointTrait => UInt32(4),
    GI.MultiLineStringTrait => UInt32(5),
    GI.MultiPolygonTrait => UInt32(6),
    GI.GeometryCollectionTrait => UInt32(7),
)
const wkbgeo = Dict{UInt32,DataType}(zip(values(geowkb), keys(geowkb)))


"""
    getwkb(geom)

Retrieve the Well Known Binary (WKB) as `GeoFormatTypes.WellKnownBinary` for a `geom` that implements the GeoInterface.
Use `GeoFormatTypes.val` to get the Vector{UInt8} representation.
"""
function getwkb(geom)
    data = UInt8[]
    getwkb!(data, GI.geomtrait(geom), geom, true)
    return GFT.WellKnownBinary(GFT.Geom(), data)
end

"""
    getwkb!(data, type::T, geom, first::Bool)

Push WKB to `data` for a Pointlike `type` of `geom`.

`first` indicates whether we need to indicate the type in case this outer geometry or part of a GeometryCollection.
"""
function getwkb!(data::Vector{UInt8}, type::GI.PointTrait, geom, first::Bool)
    ncoord = GI.ncoord(geom)
    if first
        sizehint!(data, 21)
        push!(data, 0x01)  # endianness
        wkbtype = geometry_code(type)
        ncoord == 3 && (wkbtype |= wkbZ)
        ncoord == 4 && (wkbtype |= wkbZM)
        # append!(data, reinterpret(UInt8, [wkbtype]))
        append_uint8!(data, wkbtype)
    end
    for i in 1:ncoord
        append_uint8!(data, Float64(GI.getcoord(geom, i)))
    end
end

append_uint8!(data::Vector{UInt8}, value::Float64) = append_uint8!(data, reinterpret(UInt64, value))
function append_uint8!(data::Vector{UInt8}, value::UInt32)
    push!(data, value >> 0 & 0xff)
    push!(data, value >> 8 & 0xff)
    push!(data, value >> 16 & 0xff)
    push!(data, value >> 24 & 0xff)
end
function append_uint8!(data::Vector{UInt8}, value::UInt64)
    push!(data, value >> 0 & 0xff)
    push!(data, value >> 8 & 0xff)
    push!(data, value >> 16 & 0xff)
    push!(data, value >> 24 & 0xff)
    push!(data, value >> 32 & 0xff)
    push!(data, value >> 40 & 0xff)
    push!(data, value >> 48 & 0xff)
    push!(data, value >> 56 & 0xff)
end

"""
Push WKB to `data` for non Pointlike `type` of `geom`.

`first` indicates whether we need to indicate the type in case this outer geometry.
`repeat` indicates whether sub geometries need to indicate their type, in case `geom` is
a geometrycollection.
"""
function _getwkb!(data::Vector{UInt8}, type, geom, first::Bool, repeat::Bool)
    if first
        sizehint!(data, 42)  # smallest non-point geometry is a line with 2 points
        push!(data, 0x01)  # endianness
        wkbtype = geometry_code(type)
        ncoord = GI.ncoord(geom)
        ncoord == 3 && (wkbtype |= wkbZ)
        ncoord == 4 && (wkbtype |= wkbZM)
        # append!(data, reinterpret(UInt8, [wkbtype]))
        append_uint8!(data, wkbtype)
    end
    n = GI.ngeom(geom)
    append_uint8!(data, UInt32(n))
    for i in 1:n
        sgeom = GI.getgeom(geom, i)
        type = GI.geomtrait(sgeom)
        getwkb!(data, type, sgeom, repeat)
    end
end

function getwkb!(data::Vector{UInt8}, type::GI.AbstractGeometryTrait, geom, first::Bool)
    _getwkb!(data, type, geom, first, false)
end

function getwkb!(data::Vector{UInt8}, type::GI.AbstractGeometryCollectionTrait, geom, first::Bool)
    _getwkb!(data, type, geom, first, true)
end

getwkb!(data, ::Nothing, geom, first::Bool) = nothing  # empty geometry has unknown type

# Implement GeoInterface for WKB, as wrapped by GeoFormatTypes
const WKBtype = GFT.WellKnownBinary{GFT.Geom,<:AbstractVector{UInt8}}
struct Point end
struct Ring end


function check_endianness(data)
    first(data) == 0x01 || error("They are big and I am little... And that's not fair. We don't (yet) support big-endian WKB.")
end

GI.isgeometry(::WKBtype) = true

function GI.geomtrait(geom::WKBtype)
    check_endianness(geom.val)
    ewkbtype = only(reinterpret(UInt32, @view geom.val[2:2+sizeof(UInt32)-1]))
    wkbtype = (ewkbtype & 0xffff) % 1000

    type = get(wkbgeo, wkbtype, nothing)
    if isnothing(type)
        @warn "unknown geometry type" wkbtype
        return nothing
    else
        return type()
    end
end

function GI.ncoord(::GeometryTraits, geom::WKBtype)
    check_endianness(geom.val)
    wkbtype = only(reinterpret(UInt32, @view geom.val[2:5]))
    n = 2

    # ISO WKB adds thousands to wkbtype
    isoTypeRange = (wkbtype & 0xffff) ÷ 1000
    n += (isoTypeRange == 1) + (isoTypeRange == 2)  # 1000 is Z, 2000 is M
    n += (isoTypeRange == 3) * 2  # 3000 is ZM

    # EWKB add bit flags to wkbtype
    n += (wkbtype & wkbZ) != 0
    n += (wkbtype & wkbM) != 0
    n
end

function GI.getcoord(::GI.PointTrait, geom::WKBtype, i)
    offset = (i - 1) * sizeof(Float64) + 1
    data = @view geom.val[headersize+offset:headersize+offset+sizeof(Float64)-1]
    only(reinterpret(Float64, data))
end

function GI.getcoord(::GI.PointTrait, geom::WKBtype)
    offset = 1
    data = @view geom.val[headersize+offset:headersize+offset+sizeof(Float64)*GI.ncoord(geom)-1]
    reinterpret(Float64, data)
end

GI.ngeom(::Point, geom::WKBtype) = 0
GI.ngeom(::Ring, geom::WKBtype) = reinterpret(UInt32, geom.val[1:4])[1]
GI.ngeom(::GI.PointTrait, geom::WKBtype) = 0
GI.ngeom(::GI.AbstractGeometryTrait, geom::WKBtype) = reinterpret(UInt32, geom.val[headersize+1:headersize+1+sizeof(UInt32)-1])[1]


# Two issues to solve, subgeometries in WKB & WKT are not "complete".
# They forego their TYPE in WKT, or skip the endianness and type in WKB.
# So here we need to add that to LinearRings and Points.
# Otherwise, there's an issue with finding the `i`th geometry.
function GI.getgeom(
    T::GI.AbstractGeometryCollectionTrait,
    geom::WKBtype,
    i::Integer,
)
    size = headersize + numsize
    offset = 0  # size of geom at i
    for _ in 1:i
        offset = typesize(GI.geomtrait(geom[size+1:end]), geom[size+1:end], GI.ncoord(geom))
        size += offset
    end
    return geom[size-offset+1:size]
end

# LineStrings do have multiple points without their endianess and type prefix set
function GI.getgeom(
    T::GI.LineStringTrait,
    geom::WKBtype,
    i::Integer,
)
    ncoord = GI.ncoord(geom)
    GI.getgeom(T, geom, i, ncoord)
end

function GI.getgeom(
    T::GI.LineStringTrait,
    geom::WKBtype,
    i::Integer,
    ncoord::Integer,
)
    size = headersize + numsize
    offset = 0  # size of geom at i
    ncoord = GI.ncoord(geom)
    for _ in 1:i
        offset = typesize(wkbsubtype(T), geom[size+1:end], ncoord)
        size += offset
    end
    wkbtype = geometry_code(GI.PointTrait())
    ncoord == 3 && (wkbtype |= wkbZ)
    ncoord == 4 && (wkbtype |= wkbZM)

    data = vcat(geom.val[1], reinterpret(UInt8, [wkbtype]), geom.val[size-offset+1:size])
    return GFT.WellKnownBinary(GFT.Geom(), data)
end

# Polygons do have multiple rings without their endianess and type prefix set
function GI.getgeom(
    T::GI.PolygonTrait,
    geom::WKBtype,
    i::Integer,
)
    size = headersize + numsize
    offset = 0  # size of geom at i
    ncoord = GI.ncoord(geom)
    for _ in 1:i
        offset = typesize(wkbsubtype(T), geom[size+1:end], ncoord)
        size += offset
    end
    wkbtype = geometry_code(GI.LineStringTrait())
    ncoord == 3 && (wkbtype |= wkbZ)
    ncoord == 4 && (wkbtype |= wkbZM)

    data = vcat(geom.val[1], reinterpret(UInt8, [wkbtype]), geom.val[size-offset+1:size])
    return GFT.WellKnownBinary(GFT.Geom(), data)
end

Base.getindex(wkb::GFT.WellKnownBinary{GFT.Geom,T}, i) where {T} = GFT.WellKnownBinary(gftgeom, wkb.val[i])
Base.lastindex(wkb::GFT.WellKnownBinary{GFT.Geom,T}) where {T} = lastindex(wkb.val)

wkbsubtype(::Ring) = Point()
wkbsubtype(::GI.PointTrait) = Point()
wkbsubtype(::GI.LineStringTrait) = Point()
wkbsubtype(::GI.PolygonTrait) = Ring()
wkbsubtype(::GI.MultiPointTrait) = GI.PointTrait()
wkbsubtype(::GI.MultiLineStringTrait) = GI.LineStringTrait()
wkbsubtype(::GI.MultiPolygonTrait) = GI.PolygonTrait()

const headersize = 1 + 4
const numsize = 4
typesize(::Point, geom, n=2) = sizeof(Float64) * n
typesize(T::Ring, geom, n::Integer) = numsize + GI.ngeom(T, geom) * typesize(wkbsubtype(T), geom, n)
typesize(T::GI.PointTrait, geom) = headersize + typesize(wkbsubtype(T), geom, GI.ncoord(geom))
typesize(T::GI.PointTrait, geom, n::Integer) = headersize + typesize(wkbsubtype(T), geom, n)
typesize(T::GI.LineStringTrait, geom) = headersize + numsize + GI.ngeom(T, geom) * typesize(wkbsubtype(T), geom, GI.ncoord(geom))
typesize(T::GI.LineStringTrait, geom, n::Integer) = headersize + numsize + GI.ngeom(T, geom) * typesize(wkbsubtype(T), geom, n)
function typesize(T::GI.AbstractGeometryTrait, geom)
    size = headersize + numsize
    for _ in 1:GI.ngeom(T, geom)
        size += typesize(wkbsubtype(T), geom[size+1:end], GI.ncoord(geom))
    end
    return size
end
function typesize(T::GI.AbstractGeometryTrait, geom, n::Integer)
    size = headersize + numsize
    for _ in 1:GI.ngeom(T, geom)
        size += typesize(wkbsubtype(T), geom[size+1:end], n)
    end
    return size
end
function typesize(T::GI.GeometryCollectionTrait, geom, n::Integer)
    size = headersize + numsize
    for _ in 1:GI.ngeom(T, geom)
        size += typesize(GI.geomtrait(geom[size+1:end]), geom[size+1:end], n)
    end
    return size
end
