var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = WellKnownGeometry","category":"page"},{"location":"#WellKnownGeometry","page":"Home","title":"WellKnownGeometry","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for WellKnownGeometry.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [WellKnownGeometry]","category":"page"},{"location":"#WellKnownGeometry._getwkb!-Tuple{Vector{UInt8}, Any, Any, Bool, Bool}","page":"Home","title":"WellKnownGeometry._getwkb!","text":"Push WKB to data for non Pointlike type of geom.\n\nfirst indicates whether we need to indicate the type in case this outer geometry. repeat indicates whether sub geometries need to indicate their type, in case geom is a geometrycollection.\n\n\n\n\n\n","category":"method"},{"location":"#WellKnownGeometry._getwkt!-Tuple{Vector{Char}, Any, Any, Bool, Bool}","page":"Home","title":"WellKnownGeometry._getwkt!","text":"Push WKT to data for non Pointlike type of geom.\n\nfirst indicates whether we need to print the type with brackets–like POLYGON ( )– in case this outer geometry. repeat indicates whether sub geometries need to print their type, in case geom is a geometrycollection.\n\n\n\n\n\n","category":"method"},{"location":"#WellKnownGeometry.getwkb!-Tuple{Vector{UInt8}, GeoInterface.PointTrait, Any, Bool}","page":"Home","title":"WellKnownGeometry.getwkb!","text":"getwkb!(data, type::T, geom, first::Bool)\n\nPush WKB to data for a Pointlike type of geom.\n\nfirst indicates whether we need to indicate the type in case this outer geometry or part of a GeometryCollection.\n\n\n\n\n\n","category":"method"},{"location":"#WellKnownGeometry.getwkb-Tuple{Any}","page":"Home","title":"WellKnownGeometry.getwkb","text":"getwkb(geom)\n\nRetrieve the Well Known Binary (WKB) as Vector{UInt8} for a geom that implements the GeoInterface.\n\n\n\n\n\n","category":"method"},{"location":"#WellKnownGeometry.getwkt!-Tuple{Vector{Char}, GeoInterface.AbstractPointTrait, Any, Bool}","page":"Home","title":"WellKnownGeometry.getwkt!","text":"Push WKT to data for a Pointlike type of geom.\n\nfirst indicates whether we need to print the type with brackets–like POINT ( )– in case this outer geometry or part of a geometrycollection.\n\n\n\n\n\n","category":"method"},{"location":"#WellKnownGeometry.getwkt-Tuple{Any}","page":"Home","title":"WellKnownGeometry.getwkt","text":"getwkt(geom)\n\nRetrieve the Well Known Text (WKT) as String for a geom that implements the GeoInterface.\n\n\n\n\n\n","category":"method"}]
}