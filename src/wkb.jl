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
geometry_code(::GI.AbstractPointTrait) = UInt32(1)
geometry_code(::GI.AbstractLineStringTrait) = UInt32(2)
geometry_code(::GI.AbstractPolygonTrait) = UInt32(3)
geometry_code(::GI.AbstractMultiPointTrait) = UInt32(4)
geometry_code(::GI.AbstractMultiLineStringTrait) = UInt32(5)
geometry_code(::GI.AbstractMultiPolygonTrait) = UInt32(6)
geometry_code(::GI.AbstractGeometryCollectionTrait) = UInt32(7)

"""
    getwkb(geom)

Retrieve the Well Known Binary (WKB) as `Vector{UInt8}` for a `geom` that implements the GeoInterface.
"""
function getwkb(geom)
    data = UInt8[]
    getwkb!(data, GI.geomtype(geom), geom, true)
    return data
end

"""
    getwkb!(data, type::T, geom, first::Bool)

Push WKB to `data` for a Pointlike `type` of `geom`.

`first` indicates whether we need to indicate the type in case this outer geometry or part of a GeometryCollection.
"""
function getwkb!(data, type::GI.AbstractPointTrait, geom, first::Bool)
    first && push!(data, 0x01)  # endianness
    first && push!(data, reinterpret(UInt8, [geometry_code(type)])...)
    for i in 1:GI.ncoord(geom)
        push!(data, reinterpret(UInt8, [GI.getcoord(geom, i)])...)
    end
end

"""
Push WKB to `data` for non Pointlike `type` of `geom`.

`first` indicates whether we need to indicate the type in case this outer geometry.
`repeat` indicates whether sub geometries need to indicate their type, in case `geom` is
a geometrycollection.
"""
function _getwkb!(data, type, geom, first::Bool, repeat::Bool)
    first && push!(data, 0x01)  # endianness
    first && push!(data, reinterpret(UInt8, [geometry_code(type)])...)
    n = GI.ngeom(geom)
    push!(data, reinterpret(UInt8, [UInt32(n)])...)
    for i in 1:n
        sgeom = GI.getgeom(geom, i)
        type = GI.geomtype(sgeom)
        getwkb!(data, type, sgeom, repeat)
    end
end

function getwkb!(data, type::GI.AbstractGeometryTrait, geom, first::Bool)
    _getwkb!(data, type, geom, first, false)
end

function getwkb!(data, type::GI.AbstractGeometryCollectionTrait, geom, first::Bool)
    _getwkb!(data, type, geom, first, true)
end

getwkb!(data, ::Nothing, geom, first::Bool) = nothing  # empty geometry has unknown type
