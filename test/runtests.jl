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
    ring = [(0.1, 0.2), (0.3, 0.4), (0.1, 0.2)]
    ring3 = [(0.1, 0.2, 0.3), (0.3, 0.4, 0.5), (0.1, 0.2, 0.3)]
    coords = [[Tuple(coord), Tuple(lcoord), Tuple(coord)], ring]
    coords3 = [[Tuple(coord3), Tuple(lcoord3), Tuple(coord3)], ring3]

    for (type, geom, broken, threed) in (
        ("Point", ArchGDAL.createpoint(coord), false, false),
        ("PointZ", ArchGDAL.createpoint(coord3), true, true),
        ("LineString", ArchGDAL.createlinestring(coord, lcoord), false, false),
        ("LineStringZ", ArchGDAL.createlinestring(coord3, lcoord3, lcoord3), true, true),
        ("Polygon", ArchGDAL.createpolygon(coords), false, false),
        ("PolygonZ", ArchGDAL.createpolygon(coords3), true, true),
        ("MultiPoint", ArchGDAL.createmultipoint([coord, lcoord]), false, false),
        ("MultiPointZ", ArchGDAL.createmultipoint([coord3, lcoord3]), true, true),
        ("MultiLineString", ArchGDAL.createmultilinestring([[coord, lcoord], [coord, lcoord]]), false, false),
        ("MultiLineStringZ", ArchGDAL.createmultilinestring([[coord3, lcoord3], [coord3, lcoord3]]), true, true),
        ("MultiPolygon", ArchGDAL.createmultipolygon([coords, coords]), false, false),
        ("MultiPolygonZ", ArchGDAL.createmultipolygon([coords3, coords3]), true, true),
        ("Empty", ArchGDAL.createpoint(), false, false),
        ("Empty Multi", ArchGDAL.createmultipolygon(), false, false)
    )
        ArchGDAL.is3d(geom) == threed || (@warn "Creation of $type is broken"; continue)
        @testset "$type" begin
            @testset "WKB" begin
                wkb = GFT.val(WKG.getwkb(geom))
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
                gwkt = WKG.getwkt(geom)
                wkt = GFT.val(gwkt)
                wktc = ArchGDAL.toWKT(geom)
                if broken
                    @test_broken wkt == wktc
                else
                    @test wkt == wktc
                end
                # Test validity by reading it again
                ArchGDAL.fromWKT(wkt)
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
                @test length(GFT.val(wkb)) == length(wkbc)
                @test all(GFT.val(wkb) .== wkbc)
                collection = ArchGDAL.fromWKB(GFT.val(wkb))
                @test all(GI.coordinates(wkb) .== GI.coordinates(collection))
            end
            @testset "WKT" begin
                wkt = WKG.getwkt(collection)
                wktc = ArchGDAL.toWKT(collection)
                @test GFT.val(wkt) == wktc
                collection = ArchGDAL.fromWKT(GFT.val(wkt))
                @test all(GI.coordinates(wkt) .== GI.coordinates(collection))

            end
        end
    end

    @testset "GeoInterface" begin
        wkt = GFT.WellKnownText(GFT.Geom(), "wkt")
        wkb = GFT.WellKnownBinary(GFT.Geom(), [0x0])

        @test GI.isgeometry(wkt)
        @test GI.isgeometry(wkb)

        wkt = GFT.WellKnownText(GFT.Geom(), "POINT (30 10)")
        @test GI.testgeometry(wkt)
        @test GI.coordinates(wkt) == [30.0, 10.0]

        wkt = GFT.WellKnownText(GFT.Geom(), "POINT Z (30 10 1)")
        @test GI.testgeometry(wkt)
        @test GI.coordinates(wkt) == [30.0, 10.0, 1.0]

        wkt = GFT.WellKnownText(GFT.Geom(), "POINTZ (30 10 1)")
        @test GI.testgeometry(wkt)
        @test GI.coordinates(wkt) == [30.0, 10.0, 1.0]

        wkt = GFT.WellKnownText(GFT.Geom(), "POINT M (30 10 1)")
        @test GI.testgeometry(wkt)
        @test GI.coordinates(wkt) == [30.0, 10.0, 1.0]

        wkt = GFT.WellKnownText(GFT.Geom(), "POINT ZM (30 10 1 2)")
        @test GI.testgeometry(wkt)
        @test GI.coordinates(wkt) == [30.0, 10.0, 1.0, 2.0]

        wkt = GFT.WellKnownText(GFT.Geom(), "POINTZM (30 10 1 2)")
        @test GI.testgeometry(wkt)
        @test GI.coordinates(wkt) == [30.0, 10.0, 1.0, 2.0]

        wkt = GFT.WellKnownText(GFT.Geom(), "LINESTRING (30.0 10.0, 10.0 30.0, 40.0 40.0)")
        @test GI.testgeometry(wkt)
        @test GI.coordinates(wkt) == [[30.0, 10.0], [10.0, 30.0], [40.0, 40.0]]
    end

    @testset "LibGEOS" begin
        p = LibGEOS.readgeom("POLYGON Z ((0.5 0.5 0.5,1.5 0.5 0.5,1.5 1.5 0.5,0.5 0.5 0.5))")
        # LibGEOS has a space between points
        @test replace(GFT.val(WKG.getwkt(p)), " " => "") == replace(LibGEOS.writegeom(p), " " => "")
        wkbwriter = LibGEOS.WKBWriter(LibGEOS.get_global_context())
        @test_broken WKG.getwkb(p) == LibGEOS.writegeom(p, wkbwriter)  # LibGEOS doesn't provide 3D type
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

    @testset "Number types" begin
        @test GFT.val(WKG.getwkb((1.0, 2.0))) == GFT.val(WKG.getwkb((1.0f0, 2.0f0)))
    end

    @testset "Oddities" begin
        # Without a space
        wkt = GFT.WellKnownText(GFT.Geom(), "POINT(30 10)")
        @test GI.testgeometry(wkt)
    end

    @testset "GeoInterface piracy" begin
        @test GI.astext((1.0, 2.0)) == GFT.WellKnownText(GFT.Geom(), "POINT (1.0 2.0)")
        @test GI.asbinary((1.0, 2.0)).val == UInt8[
            0x01,
            0x01,
            0x00,
            0x00,
            0x00,
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
            0x00,
            0x40]
    end

    @testset "Simple wrapper Polygon #37" begin
        GI.astext(GI.Polygon([GI.LinearRing([(50, 60), (50, 61), (51, 61), (51, 60), (50, 60)])]))
        GI.asbinary(GI.Polygon([GI.LinearRing([(50, 60), (50, 61), (51, 61), (51, 60), (50, 60)])]))
    end

    @testset "LinearRing #36" begin
        rings = GI.astext(GI.LinearRing([(50, 60), (50, 61), (51, 61), (51, 60), (50, 60)]))
        @test GI.geomtrait(rings) == GI.LinearRingTrait()
        ringb = GI.asbinary(GI.LinearRing([(50, 60), (50, 61), (51, 61), (51, 60), (50, 60)]))
        @test GI.geomtrait(ringb) == GI.LineStringTrait()
    end
end
