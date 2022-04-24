module WellKnownGeometry

import GeoInterface as GI
import GeoFormatTypes as GFT

GeometryTraits = Union{
    GI.PointTrait,
    GI.MultiPointTrait,
    GI.LineStringTrait,
    GI.LinearRingTrait,
    GI.MultiLineStringTrait,
    GI.PolygonTrait,
    GI.MultiPolygonTrait,
    GI.GeometryCollectionTrait,
}

export getwkb, getwkt

include("wkb.jl")
include("wkt.jl")

end
