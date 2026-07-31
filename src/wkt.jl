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
const geowkt = Dict{DataType,String}(
    GI.PointTrait => "POINT",
    GI.LineStringTrait => "LINESTRING",
    GI.LinearRingTrait => "LINEARRING",
    GI.PolygonTrait => "POLYGON",
    GI.MultiPointTrait => "MULTIPOINT",
    GI.MultiLineStringTrait => "MULTILINESTRING",
    GI.MultiPolygonTrait => "MULTIPOLYGON",
    GI.GeometryCollectionTrait => "GEOMETRYCOLLECTION"
)
const wktgeo = Dict{String,DataType}(zip(values(geowkt), keys(geowkt)))
geometry_string(T) = geowkt[typeof(T)]
function geometry_suffix(type, geom)
    if GI.ncoord(type, geom) == 3
        return "Z "
    elseif GI.ncoord(type, geom) == 4
        return "ZM "
    else
        return ""
    end
end

"""
    getwkt(geom)

Retrieve the Well Known Text (WKT) as `GeoFormatTypes.WellKnownText` for a `geom` that implements the GeoInterface.
Use `GeoFormatTypes.val` to get the String representation.
"""
function getwkt(geom)
    io = IOBuffer()
    getwkt!(io, GI.geomtrait(geom), geom, true)
    return GFT.WellKnownText(GFT.Geom(), String(take!(io)))
end

function write_coordinate(io::IOBuffer, value::Union{Float16,Float32,Float64})
    Base.ensureroom(io, 24)
    io.ptr = Base.Ryu.writeshortest(io.data, io.ptr, value)
    io.size = max(io.size, io.ptr - 1)
    return nothing
end

write_coordinate(io::IO, value) = print(io, value)

"""
Write WKT to `io` for a Pointlike `type` of `geom`.

`first` indicates whether we need to print the type with brackets--like POINT ( )--
in case this outer geometry or part of a geometrycollection.
"""
function getwkt!(io::IO, type::GI.AbstractPointTrait, geom, first::Bool)
    if first
        print(io, geometry_string(type), ' ', geometry_suffix(type, geom))
    end
    if GI.isempty(type, geom)
        print(io, "EMPTY")
    else
        n = GI.ncoord(type, geom)
        first && print(io, '(')
        for i in 1:n
            write_coordinate(io, GI.getcoord(type, geom, i))
            i != n && print(io, ' ')  # Don't add a ` ` on the last item
        end
        first && print(io, ')')
    end
end

"""
Write WKT to `io` for non Pointlike `type` of `geom`.

`first` indicates whether we need to print the type with brackets--like POLYGON ( )--
in case this outer geometry. `repeat` indicates whether sub geometries need to print their type, in case `geom` is
a geometrycollection.
"""
function _getwkt!(io::IO, type, geom, first::Bool, repeat::Bool)
    if first
        print(io, geometry_string(type), ' ', geometry_suffix(type, geom))
    end
    if GI.isempty(type, geom)
        print(io, "EMPTY")
    else
        n = GI.ngeom(type, geom)
        print(io, '(')
        for i in 1:n
            sgeom = GI.getgeom(type, geom, i)
            subtype = GI.geomtrait(sgeom)
            getwkt!(io, subtype, sgeom, repeat)
            i != n && print(io, ',')  # Don't add a , on the last item
        end
        print(io, ')')
    end
end

function getwkt!(io::IO, type::GI.AbstractGeometryTrait, geom, first::Bool)
    _getwkt!(io, type, geom, first, false)
end

function getwkt!(io::IO, type::GI.GeometryCollectionTrait, geom, first::Bool)
    _getwkt!(io, type, geom, first, true)
end

# Implement GeoInterface for WKT, as wrapped by GeoFormatTypes
macro wkt_str(wkt) GFT.WellKnownText(GFT.Geom(), wkt) end
wrap(string::AbstractString) = GFT.WellKnownText(GFT.Geom(), string)

const WKTtype = GFT.WellKnownText{GFT.Geom}
GI.isgeometry(::WKTtype) = true
GI.isgeometry(::Type{<:GFT.WellKnownText{GFT.Geom}}) = true

Base.getindex(wkt::WKTtype, i) = GFT.WellKnownText(gftgeom, wkt.val[i])
Base.lastindex(wkt::WKTtype) = lastindex(wkt.val)


function GI.geomtrait(geom::WKTtype)
    m = match(r"^(\S+?)(?: )?(?:Z|ZM|M)?(?: |\()", geom.val)
    if isnothing(m)
        @warn "unknown geometry type" geom.val
        return nothing
    else
        type = get(wktgeo, String(m[1]), nothing)
        return type()
    end
end

function GI.ncoord(::GeometryTraits, geom::WKTtype)
    if occursin("EMPTY", geom.val)
        return 0
    elseif occursin(r"(.| )ZM( |\()", geom.val)
        return 4
    elseif occursin(r"(.| )Z( |\()", geom.val)
        return 3
    elseif occursin(r"(.| )M( |\()", geom.val)
        return 3
    else
        return 2
    end
end


function wktcoords(geom::WKTtype)
    start = findfirst('(', geom.val)
    isnothing(start) && (start = 0)
    s = geom.val[start+1:end-1]
    return parse.(Float64, split(s; keepempty=false))
end

function GI.getcoord(::GI.PointTrait, geom::WKTtype, i)
    start = findfirst('(', geom.val)
    isnothing(start) && (start = 0)
    s = geom.val[start+1:end-1]
    return parse(Float64, split(s; keepempty=false)[i])
end
GI.getcoord(::GI.PointTrait, geom::WKTtype) = wktcoords(geom)
GI.coordinates(::GI.PointTrait, geom::WKTtype) = wktcoords(geom)

GI.ngeom(::Point, geom::WKTtype) = 0
GI.ngeom(::GI.PointTrait, geom::WKTtype) = 0
function GI.ngeom(::GI.AbstractGeometryTrait, geom::WKTtype)
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

function wktgeomrange(s::String, i::Integer)
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
    return f:l
end

function wktchild(::GI.GeometryCollectionTrait, geom::WKTtype, range)
    return WKTtype(gftgeom, geom.val[range])
end

wktsubtype(::GI.PointTrait) = nothing
wktsubtype(::GI.LineStringTrait) = GI.PointTrait()
wktsubtype(::GI.PolygonTrait) = GI.LineStringTrait()
wktsubtype(::GI.MultiPointTrait) = GI.PointTrait()
wktsubtype(::GI.MultiLineStringTrait) = GI.LineStringTrait()
wktsubtype(::GI.MultiPolygonTrait) = GI.PolygonTrait()

function wktchild(T::GI.AbstractGeometryTrait, geom::WKTtype, range)
    sub = wktsubtype(T)
    s = geom.val
    suff = geometry_suffix(T, geom)
    if isnothing(findfirst("(", @view s[range]))
        data = geometry_string(sub) * suff * " (" * s[range] * ")"
    else
        data = geometry_string(sub) * suff * s[range]
    end
    return WKTtype(gftgeom, data)
end

function GI.getgeom(T::GI.AbstractGeometryTrait, geom::WKTtype, i::Integer)
    return wktchild(T, geom, wktgeomrange(geom.val, i))
end

struct WKTGeometries{T}
    type::T
    geom::WKTtype
    ncoord::Int
end

Base.IteratorSize(::Type{<:WKTGeometries}) = Base.SizeUnknown()

function Base.iterate(iter::WKTGeometries)
    start = findfirst('(', iter.geom.val)
    isnothing(start) && return nothing
    return iterate(iter, nextind(iter.geom.val, start))
end

function Base.iterate(iter::WKTGeometries, first::Int)
    s = iter.geom.val
    depth = 1
    index = first
    while index <= lastindex(s)
        char = s[index]
        if char === '('
            depth += 1
        elseif char === ')'
            depth -= 1
            depth == 0 && return wktchild(iter.type, iter.geom, first:prevind(s, index)), nothing
        elseif char === ',' && depth == 1
            return wktchild(iter.type, iter.geom, first:prevind(s, index)), nextind(s, index)
        end
        index = nextind(s, index)
    end
    return nothing
end

Base.iterate(::WKTGeometries, ::Nothing) = nothing

GI.getgeom(::GI.PointTrait, ::WKTtype) = nothing
GI.getgeom(T::GI.AbstractGeometryTrait, geom::WKTtype) =
    WKTGeometries(T, geom, Int(GI.ncoord(T, geom)))

GI.astext(::GI.AbstractGeometryTrait, geom) = getwkt(geom)

# coordtype implementation - WellKnownGeometry always uses Float64
if :coordtype in names(GI; all = true)
    GI.coordtype(::GI.AbstractGeometryTrait, geom::WKTtype) = Float64
end
