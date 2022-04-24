import WellKnownGeometry as WKG
@time import GeoFormatTypes as GFT
import GeoInterface as GI
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
            @testset "WKB" begin
                wkb = WKG.getwkb(geom)
                wkbc = ArchGDAL.toWKB(geom)
                @test length(wkb) == length(wkbc)
                @test all(wkb .== wkbc)
                ArchGDAL.fromWKB(wkb)
                gwkb = GFT.WellKnownBinary(GFT.Geom(), wkb)
                @test all(GI.coordinates(gwkb) .== GI.coordinates(geom))
            end
            @testset "WKT" begin
                wkt = WKG.getwkt(geom)
                wktc = ArchGDAL.toWKT(geom)
                @test wkt == wktc
                # Test validity by reading it again
                ArchGDAL.fromWKT(wkt)
                gwkb = GFT.WellKnownText(GFT.Geom(), wkt)
                @test all(GI.coordinates(gwkb) .== GI.coordinates(geom))
            end
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

            @testset "WKB" begin
                wkb = WKG.getwkb(collection)
                wkbc = ArchGDAL.toWKB(collection)
                @test length(wkb) == length(wkbc)
                @test all(wkb .== wkbc)
                collection = ArchGDAL.fromWKB(wkb)
                gwkb = GFT.WellKnownBinary(GFT.Geom(), wkb)
                @test all(GI.coordinates(gwkb) .== GI.coordinates(collection))
            end
            @testset "WKT" begin
                wkt = WKG.getwkt(collection)
                wktc = ArchGDAL.toWKT(collection)
                @test wkt == wktc
                collection = ArchGDAL.fromWKT(wkt)
                gwkb = GFT.WellKnownText(GFT.Geom(), wkt)
                @test all(GI.coordinates(gwkb) .== GI.coordinates(collection))

            end
        end
    end

end
