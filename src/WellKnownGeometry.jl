module WellKnownGeometry

import GeoInterface as GI

include("wkb.jl")
include("wkt.jl")

export getwkb, getwkt
end
