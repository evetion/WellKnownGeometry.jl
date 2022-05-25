"""
Well Known Text (WKT) represents `geometry` as nested text by:
- Displaying the geometry type if not known beforehand (e.g `POINT `)
- Brackets open (e.g. `(`)
- Any coordinates if the geometry type is a Point, seperated by a space (e.g `1.0 2.0`)
- Or another (sub)geometry in non-Point geometry types
- Brackets close (e.g `)`)

Knowing the type of subgeometries (and thus the SF type hierarchy) is required.
For example, because a Polygon always has rings (either exterior or interior ones),
the (sub)geometry type of those rings are skipped (LinearRing) and only brackets are added.
The opposite is true for a GeometryCollection, when the subgeometry types are not known beforehand.

A few examples

POINT (30 10)
LINESTRING (30 10, 30 10)
POLYGON (((35 10, 45 45, 15 40, 10 20, 35 10),
(20 30, 35 35, 30 20, 20 30)))
"""

# Map GeoInterface type traits directly to their WKT String representation
const geowkt = Dict{DataType, String}(
    GI.PointTrait => "POINT ",
    GI.LineStringTrait => "LINESTRING ",
    GI.PolygonTrait => "POLYGON ",
    GI.MultiPointTrait => "MULTIPOINT ",
    GI.MultiLineStringTrait => "MULTILINESTRING ",
    GI.MultiPolygonTrait => "MULTIPOLYGON ",
    GI.GeometryCollectionTrait => "GEOMETRYCOLLECTION "
)
const wktgeo = Dict{String, DataType}(zip(values(geowkt), keys(geowkt)))
geometry_string(T) = geowkt[typeof(T)]

"""
    getwkt(geom)

Retrieve the Well Known Text (WKT) as `String` for a `geom` that implements the GeoInterface.
"""
function getwkt(geom)
    data = Char[]
    getwkt!(data, GI.geomtrait(geom), geom, true)
    return String(data)
end

"""
Push WKT to `data` for a Pointlike `type` of `geom`.

`first` indicates whether we need to print the type with brackets--like POINT ( )--
in case this outer geometry or part of a geometrycollection.
"""
function getwkt!(data::Vector{Char}, type::GI.AbstractPointTrait, geom, first::Bool)
    first && append!(data, collect(geometry_string(type)))
    if GI.isempty(geom)
        append!(data, collect("EMPTY"))
    else
        n = GI.ncoord(geom)
        first && push!(data, '(')
        for i in 1:n
            append!(data, collect(string(GI.getcoord(geom, i))))
            i != n && push!(data, ' ')  # Don't add a ` ` on the last item
        end
        first && push!(data, ')')
    end
end

"""
Push WKT to `data` for non Pointlike `type` of `geom`.

`first` indicates whether we need to print the type with brackets--like POLYGON ( )--
in case this outer geometry. `repeat` indicates whether sub geometries need to print their type, in case `geom` is
a geometrycollection.
"""
function _getwkt!(data::Vector{Char}, type, geom, first::Bool, repeat::Bool)
    first && append!(data, collect(geometry_string(type)))
    if GI.isempty(geom)
        append!(data, collect("EMPTY"))
    else
        n = GI.ngeom(geom)
        push!(data, '(')
        for i in 1:n
            sgeom = GI.getgeom(geom, i)
            type = GI.geomtrait(sgeom)
            getwkt!(data, type, sgeom, repeat)
            i != n && push!(data, ',')  # Don't add a , on the last item
        end
        push!(data, ')')
    end
end

function getwkt!(data::Vector{Char}, type::GI.AbstractGeometryTrait, geom, first::Bool)
    _getwkt!(data, type, geom, first, false)
end

function getwkt!(data::Vector{Char}, type::GI.GeometryCollectionTrait, geom, first::Bool)
    _getwkt!(data, type, geom, first, true)
end

# Implement GeoInterface for WKT, as wrapped by GeoFormatTypes
const WKTtype = GFT.WellKnownText{GFT.Geom}
GI.isgeometry(::WKTtype) = true

Base.getindex(wkt::WKTtype, i) = GFT.WellKnownText(gftgeom, wkt.val[i])
Base.lastindex(wkt::WKTtype) = lastindex(wkt.val)


function GI.geomtrait(geom::WKTtype)
    i = findfirst(' ', geom.val)
    type = get(wktgeo, geom.val[1:i], nothing)
    if isnothing(type)
        @warn "unknown geometry type" geom.val
        return nothing
    else
        return type()
    end
end

function GI.ncoord(::GeometryTraits, geom::WKTtype)
    if occursin("EMPTY", geom.val)
        return 0
    else
        return 2
    end
end


function GI.getcoord(::GI.PointTrait, geom::WKTtype, i)
    start = findfirst('(', geom.val)
    isnothing(start) && (start = 0)
    s = geom.val[start+1:end-1]
    index = [1, findall(' ', s)..., length(s)]
    f = parse(Float64, s[index[i]:index[i+1]])
    return f
end

GI.ngeom(::Point, geom) = 0
GI.ngeom(::GI.PointTrait, geom) = 0
function GI.ngeom(::GI.AbstractGeometryTrait, geom)
    s = geom.val
    occursin("EMPTY", s) && return 0
    ngeo = 1  # always one geometry
    nbracket = 0
    for i in 1:length(s)
        if s[i] === '('
            nbracket += 1
        elseif s[i] === ')'
            nbracket -= 1
        elseif s[i] === ',' && nbracket == 1
            ngeo += 1
        end
    end
    return ngeo
end

function GI.getgeom(
    T::GI.GeometryCollectionTrait,
    geom::WKTtype,
    i::Integer,
)
    s = geom.val
    f, l = 1, length(s) - 1
    ngeo = 1
    nbracket = 0
    for index in 1:length(s)
        if s[index] === '('
            nbracket += 1
            nbracket == 1 && ngeo == i && (f = index + 1)
        elseif s[index] === ')'
            nbracket -= 1
        elseif s[index] === ',' && nbracket == 1
            # End of current geometry
            ngeo == i && (l = index - 1; break)
            ngeo += 1
            # Or start of wanted geometry
            f = index + 1
        end
    end
    return WKTtype(gftgeom, s[f:l])
end

wktsubtype(::GI.PointTrait) = nothing
wktsubtype(::GI.LineStringTrait) = GI.PointTrait()
wktsubtype(::GI.PolygonTrait) = GI.LineStringTrait()
wktsubtype(::GI.MultiPointTrait) = GI.PointTrait()
wktsubtype(::GI.MultiLineStringTrait) = GI.LineStringTrait()
wktsubtype(::GI.MultiPolygonTrait) = GI.PolygonTrait()


function GI.getgeom(
    T::GI.AbstractGeometryTrait,
    geom::WKTtype,
    i::Integer,
)
    sub = wktsubtype(T)
    s = geom.val
    f, l = 1, length(s) - 1
    ngeo = 1
    nbracket = 0
    for index in 1:length(s)
        if s[index] === '('
            nbracket += 1
            nbracket == 1 && ngeo == i && (f = index + 1)
        elseif s[index] === ')'
            nbracket -= 1
        elseif s[index] === ',' && nbracket == 1
            # End of current geometry
            ngeo == i && (l = index - 1; break)
            ngeo += 1
            # Or start of wanted geometry
            f = index + 1
        end
    end
    if isnothing(findfirst("(", @view s[f:l]))
        data = geometry_string(sub) * "(" * s[f:l] * ")"
    else
        data = geometry_string(sub) * s[f:l]
    end
    return WKTtype(gftgeom, data)
end
