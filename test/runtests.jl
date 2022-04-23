import WellKnownGeometry as WKG
using Test
import ArchGDAL

@testset "WellKnownGeometry.jl" begin

    coord = [1.1, 2.2]
    lcoord = [3.3, 4.4]
    ring = [[0.1, 0.2], [0.3, 0.4], [0.1, 0.2]]
    coords = [[coord, lcoord, coord], ring]

    for (type, geom) in (
        ("Point", ArchGDAL.createpoint(coord)),
        ("LineString", ArchGDAL.createlinestring([coord, lcoord])),
        ("Polygon", ArchGDAL.createpolygon(coords)),
        ("MultiPoint", ArchGDAL.createmultipoint([coord, lcoord])),
        ("MultiLineString", ArchGDAL.createmultilinestring([[coord, lcoord], [coord, lcoord]])),
        ("MultiPolygon", ArchGDAL.createmultipolygon([coords, coords])),
        ("Empty", ArchGDAL.createpoint()),
        ("Empty Multi", ArchGDAL.createmultipolygon())
    )
        @testset "$type" begin
            # Well known binary
            wkb = WKG.getwkb(geom)
            wkbc = ArchGDAL.toWKB(geom)
            @test all(wkb .== wkbc)

            # Well known text
            wkt = WKG.getwkt(geom)
            wktc = ArchGDAL.toWKT(geom)
            @test wkt == wktc

            # Test validity by reading it again
            ArchGDAL.fromWKB(wkb)
            ArchGDAL.fromWKT(wkt)
        end
    end

    @testset "GeometryCollection" begin
        ArchGDAL.creategeomcollection() do collection
            for g in [
                ArchGDAL.createpoint(-122.23, 47.09),
                ArchGDAL.createlinestring([(-122.60, 47.14), (-122.48, 47.23)]),
            ]
                ArchGDAL.addgeom!(collection, g)
            end
            wkb = WKG.getwkb(collection)
            wkbc = ArchGDAL.toWKB(collection)
            @test all(wkb .== wkbc)

            wkt = WKG.getwkt(collection)
            wktc = ArchGDAL.toWKT(collection)
            @test wkt == wktc

            collection = ArchGDAL.fromWKB(wkb)
            collection = ArchGDAL.fromWKT(wkt)
        end
    end

end
