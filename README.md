# WellKnownGeometry

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://evetion.github.io/WellKnownGeometry.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://evetion.github.io/WellKnownGeometry.jl/dev)
[![Build Status](https://github.com/evetion/WellKnownGeometry.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/evetion/WellKnownGeometry.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/evetion/WellKnownGeometry.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/evetion/WellKnownGeometry.jl)

Reading and writing Well Known Text (WKT) and Well Known Binary (WKB). See [this Wikipedia
page](https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry) for an
explanation.

This is a work in progress and relies on the new GeoInterface version being prepared in
[GeoInterface.jl#33](https://github.com/JuliaGeo/GeoInterface.jl/pull/33). For running the
tests, this additionally needs
[ArchGDAL.jl#290](https://github.com/yeesian/ArchGDAL.jl/pull/290), which implements the new
interface. Both branches can be added with:

```julia
]add GeoInterface#v1-traits
]add ArchGDAL#feat/geointerface-traits
```

We thank Julia Computing for supporting contributions to this package.
