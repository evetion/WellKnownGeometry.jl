
GeometryString = Dict(
    GI.PointTrait => "POINT ",
    GI.LineStringTrait => "LINESTRING ",
    GI.PolygonTrait => "POLYGON ",
    GI.MultiPointTrait => "MULTIPOINT ",
    GI.MultiLineStringTrait => "MULTILINESTRING ",
    GI.MultiPolygonTrait => "MULTIPOLYGON ",
    GI.GeometryCollectionTrait => "GEOMETRYCOLLECTION "
)

"""
    getwkt(geom)

Retrieve the Well Known Text (WKT) as `String` for a `geom` that implements the GeoInterface.
"""
function getwkt(geom)
    data = Char[]
    getwkt!(data, GI.geomtype(geom), geom, true)
    return String(data)
end

"""
Push WKT to `data` for a Pointlike `type` of `geom``.

`first` indicates whether we need to print the type with brackets--like POINT ( )--
in case this outer geometry or part of a geometrycollection.
"""
function getwkt!(data, type::T, geom, first) where {T<:GI.AbstractPointTrait}
    first && push!(data, collect(GeometryString[typeof(type)])...)
    if GI.isempty(geom)
        push!(data, collect("EMPTY")...)
    else
        n = GI.ncoord(geom)
        first && push!(data, '(')
        for i in 1:n-1
            push!(data, collect(string(GI.getcoord(geom, i)))...)
            push!(data, ' ')
        end
        push!(data, collect(string(GI.getcoord(geom, n)))...)
        first && push!(data, ')')
    end
end

"""
Push WKT to `data` for non Pointlike `type` of `geom`.

`first` indicates whether we need to print the type with brackets--like POLYGON ( )--
in case this outer geometry. `repeat` indicates whether sub geometries need to print their type, in case `geom` is
a geometrycollection.
"""
function _getwkt!(data, type, geom, first, repeat)
    first && push!(data, collect(GeometryString[typeof(type)])...)
    if GI.isempty(geom)
        push!(data, collect("EMPTY")...)
    else
        n = GI.ngeom(geom)
        push!(data, '(')
        for i in 1:n-1
            sgeom = GI.getgeom(geom, i)
            type = GI.geomtype(sgeom)
            getwkt!(data, type, sgeom, repeat)
            push!(data, ',')
        end
        sgeom = GI.getgeom(geom, n)
        type = GI.geomtype(sgeom)
        getwkt!(data, type, sgeom, repeat)
        push!(data, ')')
    end
end

function getwkt!(data, type::T, geom, first) where {T<:GI.AbstractGeometryTrait}
    _getwkt!(data, type, geom, first, false)
end

function getwkt!(data, type::T, geom, first) where {T<:GI.GeometryCollectionTrait}
    _getwkt!(data, type, geom, first, true)
end
