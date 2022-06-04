# from https://github.com/JuliaLang/julia/pull/38675/files avaible in julia 1.7

@static if VERSION < v"1.7"
    Base.findall(c::AbstractChar, s::AbstractString) = findall(isequal(c), s)
end
