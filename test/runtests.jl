import WellKnownGeometry as WKG
import GeoFormatTypes as GFT
import GeoInterface as GI
using Test
import ArchGDAL
import LibGEOS

@testset "WellKnownGeometry.jl" begin

    coord = [1.1, 2.2]
    coord3 = [1.1, 2.2, 3.3]
    lcoord = [3.3, 4.4]
    lcoord3 = [3.3, 4.4, 5.5]
    ring = [[0.1, 0.2], [0.3, 0.4], [0.1, 0.2]]
    ring3 = [[0.1, 0.2, 0.3], [0.3, 0.4, 0.5], [0.1, 0.2, 0.3]]
    coords = [[coord, lcoord, coord], ring]
    coords3 = [[coord3, lcoord3, coord3], ring3]

    for (type, geom, broken) in (
        ("Point", ArchGDAL.createpoint(coord), false),
        ("PointZ", ArchGDAL.createpoint(coord3), true),
        ("LineString", ArchGDAL.createlinestring([coord, lcoord]), false),
        ("LineStringZ", ArchGDAL.createlinestring([coord3, lcoord3]), true),
        ("Polygon", ArchGDAL.createpolygon(coords), false),
        ("PolygonZ", ArchGDAL.createpolygon(coords3), true),
        ("MultiPoint", ArchGDAL.createmultipoint([coord, lcoord]), false),
        ("MultiPointZ", ArchGDAL.createmultipoint([coord3, lcoord3]), true),
        ("MultiLineString", ArchGDAL.createmultilinestring([[coord, lcoord], [coord, lcoord]]), false),
        ("MultiLineStringZ", ArchGDAL.createmultilinestring([[coord3, lcoord3], [coord3, lcoord3]]), true),
        ("MultiPolygon", ArchGDAL.createmultipolygon([coords, coords]), false),
        ("MultiPolygonZ", ArchGDAL.createmultipolygon([coords3, coords3]), true),
        ("Empty", ArchGDAL.createpoint(), false),
        ("Empty Multi", ArchGDAL.createmultipolygon(), false)
    )
        @testset "$type" begin
            @testset "WKB" begin
                wkb = WKG.getwkb(geom)
                wkbc = ArchGDAL.toWKB(geom)
                @test length(wkb) == length(wkbc)
                @test all(wkb .== wkbc)
                ArchGDAL.fromWKB(wkb)
                gwkb = GFT.WellKnownBinary(GFT.Geom(), wkb)
                if !occursin("Empty", type)  # broken on ArchGDAL
                    @test GI.ncoord(gwkb) == GI.ncoord(geom)
                end
                @test GI.coordinates(gwkb) == GI.coordinates(geom)
            end
            @testset "WKT" begin
                wkt = WKG.getwkt(geom)
                wktc = ArchGDAL.toWKT(geom)
                @test wkt == wktc broken = broken
                # Test validity by reading it again
                ArchGDAL.fromWKT(wkt)
                gwkt = GFT.WellKnownText(GFT.Geom(), wkt)
                if !occursin("Empty", type)  # broken on ArchGDAL
                    @test GI.ncoord(gwkt) == GI.ncoord(geom)
                    @test GI.coordinates(gwkt) == GI.coordinates(geom)
                end
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

    @testset "GeoInterface" begin
        wkt = GFT.WellKnownText(GFT.Geom(), "wkt")
        wkb = GFT.WellKnownBinary(GFT.Geom(), [0x0])

        @test GI.isgeometry(wkt)
        @test GI.isgeometry(wkb)

    end

    @testset "LibGEOS" begin
        p = LibGEOS.readgeom("POLYGON Z ((0.5 0.5 0.5,1.5 0.5 0.5,1.5 1.5 0.5,0.5 0.5 0.5))")
        # LibGEOS has a space between points
        @test replace(WKG.getwkt(p), " " => "") == replace(LibGEOS.writegeom(p), " " => "")
        wkbwriter = LibGEOS.WKBWriter(LibGEOS._context)
        @test WKG.getwkb(p) == LibGEOS.writegeom(p, wkbwriter) broken = true  # LibGEOS doesn't provide 3D type
    end

    @testset "ZM" begin
        wkb = GFT.WellKnownBinary(GFT.Geom(),
            [
                0x01,
                0x01,
                0x00,
                0x00,
                0x80,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0xf0,
                0x3f,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0xf0,
                0x3f,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0x00,
                0xf0,
                0x3f,
            ])
        @test GI.isgeometry(wkb)
        @test GI.geomtrait(wkb) == GI.PointTrait()
        @test GI.ncoord(wkb) == 3
        @test GI.coordinates(wkb) == [1.0, 1.0, 1.0]

        wkt = GFT.WellKnownText(GFT.Geom(), "POINTM (1 1 1)")
        @test GI.isgeometry(wkt)
        @test GI.geomtrait(wkt) == GI.PointTrait()
        @test GI.ncoord(wkt) == 3
        @test GI.coordinates(wkt) == [1.0, 1.0, 1.0]

        wkt = GFT.WellKnownText(GFT.Geom(), "POINTZM (1 1 1 1)")
        @test GI.isgeometry(wkt)
        @test GI.geomtrait(wkt) == GI.PointTrait()
        @test GI.ncoord(wkt) == 4
        @test GI.coordinates(wkt) == [1.0, 1.0, 1.0, 1.0]

    end



end
