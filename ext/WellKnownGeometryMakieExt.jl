module WellKnownGeometryMakieExt

import GeoInterface
import WellKnownGeometry
import GeoFormatTypes
import Makie

GeoInterface.@enable_makie Makie GeoFormatTypes.WellKnownText
GeoInterface.@enable_makie Makie GeoFormatTypes.WellKnownBinary

end
