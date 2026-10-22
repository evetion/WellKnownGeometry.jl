@setup_workload begin
    ring = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 0.0)]
    geoms = (
        GI.Point(1.0, 2.0),
        GI.LineString(ring),
        GI.Polygon([ring]),
        GI.MultiPoint(ring),
        GI.MultiLineString([ring]),
        GI.MultiPolygon([[ring]]),
    )
    @compile_workload begin
        for geom in geoms
            GI.coordinates(getwkb(geom))
            GI.coordinates(getwkt(geom))
        end
    end
end
