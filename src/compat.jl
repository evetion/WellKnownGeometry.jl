# from https://github.com/JuliaLang/julia/pull/31834/files backported to Julia 1.6

@static if VERSION < v"1.7"
    """
        findall(pattern::Union{AbstractString,Regex}, string::AbstractString; overlap::Bool=false)

    Return a `Vector{UnitRange{Int}}` of all the matches for `pattern` in `string`.
    Each element of the returned vector is a range of indices where the
    matching sequence is found, like the return value of [`findnext`](@ref).

    If `overlap=true`, the matching sequences are allowed to overlap indices in the
    original string, otherwise they must be from distinct character ranges.
    """
    function Base.findall(t::Union{AbstractString,Regex}, s::AbstractString; overlap::Bool=false)
        found = UnitRange{Int}[]
        i, e = firstindex(s), lastindex(s)
        while true
            r = findnext(t, s, i)
            isnothing(r) && return found
            push!(found, r)
            j = overlap || isempty(r) ? first(r) : last(r)
            j > e && return found
            @inbounds i = nextind(s, j)
        end
    end
end
