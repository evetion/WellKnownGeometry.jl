```@meta
CurrentModule = WellKnownGeometry
```
[![Build Status](https://github.com/evetion/WellKnownGeometry.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/evetion/WellKnownGeometry.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/evetion/WellKnownGeometry.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/evetion/WellKnownGeometry.jl)

# WellKnownGeometry

Reading and writing Well Known Text (WKT) and Well Known Binary (WKB) based on [GeoInterface.jl](https://github.com/JuliaGeo/GeoInterface.jl/). See [this Wikipedia page](https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry) for an explanation of Well-known text and binary geometry.

Given a GeoInterface compatible geometry, this package can generate the WKT and WKB representation of it.
It also does the reverse, as it implements GeoInterface for WKT or WKB strings.

## WellKnownText
Given a WKT string, we can retrieve the type and underlying coordinates, and thus convert it to other geometries using GeoInterface.
Note that WKT strings are wrapped by GeoFormatTypes so we can distinguish them from any other strings.

```julia
using ArchGDAL
using GeoFormatTypes
using WellKnownGeometry
using GeoInterface

wkts = "POINT (30 10)"
wkt = GeoFormatTypes.WellKnownText(GeoFormatTypes.Geom(), wkts)

GeoInterface.geomtrait(wkt)  # PointTrait()
GeoInterface.ncoord(wkt)  # 2
GeoInterface.coordinates(wkt)  # 2-element Vector{Float64}: 30.0 10.0

p = convert(ArchGDAL.IGeometry{ArchGDAL.wkbPoint}, wkt)  # Geometry: POINT (30 10)
```

As ArchGDAL geometries implement GeoInterface, we can generate the WKT for it.
```julia
wkt = WellKnownGeometry.getwkt(p)  # WellKnownText{GeoFormatTypes.Geom}(GeoFormatTypes.Geom(), "POINT (30.0 10.0)")
GeoFormatTypes.val(wkt)  # "POINT (30.0 10.0)"
```

```@docs
getwkt
```


## WellKnownBinary
Given a WKB byte string, we can retrieve the type and underlying coordinates, and thus convert it to other geometries using GeoInterface.
Note that WKB byte strings are wrapped by GeoFormatTypes so we can distinguish them from any other byte strings.

```julia
using ArchGDAL
using GeoFormatTypes
using WellKnownGeometry
using GeoInterface

wkbs = [0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3e, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x24, 0x40]
wkb = GeoFormatTypes.WellKnownBinary(GeoFormatTypes.Geom(), wkbs)

GeoInterface.geomtrait(wkb)  # PointTrait()
GeoInterface.ncoord(wkb)  # 2
GeoInterface.coordinates(wkb)  # 2-element Vector{Float64}: 30.0 10.0

p = convert(ArchGDAL.IGeometry{ArchGDAL.wkbPoint}, wkb)  # Geometry: POINT (30 10)
```

As ArchGDAL geometries implement GeoInterface, we can generate the WKB for it.
```julia
wkb = WellKnownGeometry.getwkb(p)  # WellKnownText{GeoFormatTypes.Geom}(GeoFormatTypes.Geom(), "POINT (30.0 10.0)")
GeoFormatTypes.val(wkb)  # "POINT (30.0 10.0)"
```

```@docs
getwkb
```

We thank Julia Computing for supporting contributions to this package.
