using WellKnownGeometry
using Documenter

DocMeta.setdocmeta!(WellKnownGeometry, :DocTestSetup, :(using WellKnownGeometry); recursive=true)

makedocs(;
    modules=[WellKnownGeometry],
    authors="Maarten Pronk <git@evetion.nl>, Julia Computing and contributors.",
    repo="https://github.com/evetion/WellKnownGeometry.jl/blob/{commit}{path}#{line}",
    sitename="WellKnownGeometry.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://evetion.github.io/WellKnownGeometry.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
    warnonly=[:missing_docs],
)

deploydocs(;
    repo="github.com/evetion/WellKnownGeometry.jl",
    devbranch="main",
)
