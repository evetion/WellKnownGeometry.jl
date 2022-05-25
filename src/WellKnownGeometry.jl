module WellKnownGeometry

import GeoInterface as GI
import GeoFormatTypes as GFT

const gftgeom = GFT.Geom()
const GeometryTraits = Union{
    GI.PointTrait,
    GI.MultiPointTrait,
    GI.LineStringTrait,
    GI.LinearRingTrait,
    GI.MultiLineStringTrait,
    GI.PolygonTrait,
    GI.MultiPolygonTrait,
    GI.GeometryCollectionTrait,
}

include("wkb.jl")
include("wkt.jl")

export getwkb, getwkt

end
