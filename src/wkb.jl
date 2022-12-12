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
geometry_code(T) = geowkb[typeof(T)]

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
    first && push!(data, 0x01)  # endianness
    first && append!(data, reinterpret(UInt8, [geometry_code(type)]))
    for i in 1:GI.ncoord(geom)
        append!(data, reinterpret(UInt8, [GI.getcoord(geom, i)]))
    end
end

"""
Push WKB to `data` for non Pointlike `type` of `geom`.

`first` indicates whether we need to indicate the type in case this outer geometry.
`repeat` indicates whether sub geometries need to indicate their type, in case `geom` is
a geometrycollection.
"""
function _getwkb!(data::Vector{UInt8}, type, geom, first::Bool, repeat::Bool)
    first && push!(data, 0x01)  # endianness
    first && append!(data, reinterpret(UInt8, [geometry_code(type)]))
    n = GI.ngeom(geom)
    append!(data, reinterpret(UInt8, [UInt32(n)]))
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
const WKBtype = GFT.WellKnownBinary{GFT.Geom,Vector{UInt8}}
struct Point end
struct Ring end


function check_endianness(data)
    data[1] == 0x01 || error("They are big and I am little... And that's not fair. We don't (yet) support big-endian WKB.")
end

GI.isgeometry(::WKBtype) = true

function GI.geomtrait(geom::WKBtype)
    check_endianness(geom.val)
    wkbtype = reinterpret(UInt32, geom.val[2:5])[1]
    type = get(wkbgeo, wkbtype, nothing)
    if isnothing(type)
        @warn "unknown geometry type" wkbtype
        return nothing
    else
        return type()
    end
end

GI.ncoord(::GeometryTraits, geom::WKBtype) = 2

function GI.getcoord(::GI.PointTrait, geom::WKBtype, i)
    offset = (i - 1) * sizeof(Float64) + 1
    data = geom.val[headersize+offset:headersize+offset+sizeof(Float64)-1]
    reinterpret(Float64, data)[1]
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
    size = headersize + numsize
    offset = 0  # size of geom at i
    for _ in 1:i
        offset = typesize(wkbsubtype(T), geom[size+1:end], GI.ncoord(geom))
        size += offset
    end
    data = vcat(geom.val[1], reinterpret(UInt8, [geowkb[GI.PointTrait]]), geom.val[size-offset+1:size])
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
    for _ in 1:i
        offset = typesize(wkbsubtype(T), geom[size+1:end], GI.ncoord(geom))
        size += offset
    end
    data = vcat(geom.val[1], reinterpret(UInt8, [geowkb[GI.LineStringTrait]]), geom.val[size-offset+1:size])
    return GFT.WellKnownBinary(GFT.Geom(), data)
end

# pointsize = GI.ncoord(geom) * sizeof(Float64)
# wkbpointsize = 1
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
