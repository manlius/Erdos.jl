# AEdgeMap{T} defined in newtwork_sinterface.jl

valtype{T}(m::AEdgeMap{T}) = T

"""
    mutable struct EdgeMap{G <: AGraphOrDiGraph, T, D} <: AEdgeMap{T}
        g::G
        vtype::Type{T}
        data::D
    end

Type implementing an edge map. The underlying container `data` can be a dictionary,
a matrix or a vector (for graphs with indexed edges).

    EdgeMap{T}(g, ::Type{T})

Returns a map that associates values of type `T`
to the vertices of  graph `g`. The underlying storage structures is chosen
accordingly.

    EdgeMap(g, data)

Construct a EdgeMap with `data` as underlying storage.
The storage type can be a matrix or an associative `edg => val` type or
a vector for graph with indexed edges.

    EdgeMap(g, f)

Construct an edge map with value `f(e)` for each `e` in `edges(g)`.
"""
mutable struct EdgeMap{G<:AGraphOrDiGraph, T, D} <: AEdgeMap{T}
    g::G
    vtype::Type{T}
    data::D
end
show{G,T,D}(io::IO, m::EdgeMap{G,T,D}) = print(io, "EdgeMap: $(m.data)")

EdgeMap{T}(g::AGraphOrDiGraph, d::AbstractMatrix{T}) = EdgeMap(g, T, d)
EdgeMap{T}(g::AGraphOrDiGraph, d::AbstractVector{T}) = EdgeMap(g, T, d)
EdgeMap{T}(g::AGraphOrDiGraph, d::Dict{Int, T}) = EdgeMap(g, T, d)
EdgeMap{T,E<:AEdge}(g::AGraphOrDiGraph, d::Dict{E, T}) = EdgeMap(g, T, d)

function EdgeMap{T}(g::AGraphOrDiGraph, ::Type{T})
    E = edgetype(g)
    if E <: AIndexedEdge
        # data = Vector{T}(ne(g))
        data = Dict{Int,T}()
    else
        data = Dict{E,T}()
    end
    return EdgeMap(g, T, data)
end


function EdgeMap(g::AGraphOrDiGraph, f::Function)
    E = edgetype(g)
    T = Base.return_types(f, (E,))[1]
    if E <: AIndexedEdge
        data = Vector{T}(ne(g))
        for e in edges(g)
            data[idx(e)] = f(e)
        end
    else
        data = Dict(e => f(e) for e in edges(g))
    end
    return EdgeMap(g, T, data)
end

length(m::EdgeMap) = length(m.data)

### ALL DATA
# matrix interface
getindex(m::EdgeMap, i::Integer, j::Integer) = getindex(m, edge(m.g, i, j))
setindex!(m::EdgeMap, x, i::Integer, j::Integer) = setindex!(m, x, edge(m.g, i, j))
haskey(m::EdgeMap, i::Integer, j::Integer) = haskey(m, edge(m.g, i, j))
size(m::EdgeMap) = (nv(m.g), nv(m.g))
size(m::EdgeMap, i::Integer)::Int = 1 <= i <= 2 ? nv(m.g) : error("wrong dimension")


### MATRIX DATA
_sort(i, j) = i <= j ? (i, j) : (j , i)
# Associative interface
getindex{G<:AGraphOrDiGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, e::AEdge) =
    getindex(m, src(e), dst(e))
setindex!{G<:AGraphOrDiGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, x, e::AEdge) =
    setindex!(m, x, src(e), dst(e))
get{G<:AGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, e::AEdge, x) =
    get(m.data, _sort(Int(src(e)), Int(dst(e))), x)
get{G<:ADiGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, e::AEdge, x) =
    get(m.data, (Int(src(e)), Int(dst(e))), x)
haskey{G<:AGraphOrDiGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, e::AEdge) =
     haskey(m, src(e), dst(e))
haskey{G<:AGraphOrDiGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, i::Integer, j::Integer) =
  (1 <= i <= size(m.data, 1)) && (1 <= j <= size(m.data, 1))

# matrix interface
getindex{G<:AGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, i::Integer, j::Integer) =
    getindex(m.data, _sort(i, j)...)
getindex{G<:ADiGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, i::Integer, j::Integer) =
    getindex(m.data, i, j)
setindex!{G<:AGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, x, i::Integer, j::Integer) =
    setindex!(m.data, x, _sort(i, j)...)
setindex!{G<:ADiGraph,T,D<:AbstractMatrix}(m::EdgeMap{G,T,D}, x, i::Integer, j::Integer) =
    setindex!(m.data, x, i, j)

### VECTOR DATA (only indexed edges)
# Associative interface
getindex{G<:AGraphOrDiGraph,T,D<:AbstractVector}(m::EdgeMap{G,T,D}, e::AIndexedEdge) =
    getindex(m.data, idx(e))
setindex!{G<:AGraphOrDiGraph,T,D<:AbstractVector}(m::EdgeMap{G,T,D}, x, e::AIndexedEdge) =
    setindex!(m.data, x, idx(e))
haskey{G<:AGraphOrDiGraph,T,D<:AbstractVector}(m::EdgeMap{G,T,D}, e::AIndexedEdge) =
    1 <= idx(e) <= length(m.data)
get{G<:AGraphOrDiGraph,T,D<:AbstractVector}(m::EdgeMap{G,T,D}, e::AEdge, x) =
    get(m.data, idx(e), x)

# TODO allow one dimensional indexing?
# it can be bugprone
# getindex{G<:AGraphOrDiGraph,T,D<:AbstractVector}(m::EdgeMap{G,T,D}, idx::Integer) =
#     getindex(m.data, idx)
# setindex!{G<:AGraphOrDiGraph,T,D<:AbstractVector}(m::EdgeMap{G,T,D}, x, idx::Integer) =
#     setindex!(m.data, x, idx)

### Dict{Int,T} DATA
# Associative interface
getindex{G<:AGraphOrDiGraph,T}(m::EdgeMap{G,T,Dict{Int,T}}, e::AIndexedEdge) = getindex(m.data, idx(e))
setindex!{G<:AGraphOrDiGraph,T}(m::EdgeMap{G,T,Dict{Int,T}}, x, e::AIndexedEdge) = setindex!(m.data, x, idx(e))
get{G<:AGraphOrDiGraph,T}(m::EdgeMap{G,T,Dict{Int,T}}, e::AIndexedEdge, x) = get(m.data, idx(e), x)
haskey{G<:AGraphOrDiGraph,T}(m::EdgeMap{G,T,Dict{Int,T}}, e::AIndexedEdge) = haskey(m.data, idx(e))

### Dict{E,T} DATA
# Associative interface
getindex{G<:AGraphOrDiGraph,T,E<:AEdge}(m::EdgeMap{G,T,Dict{E,T}}, e::E) = getindex(m.data, e)
setindex!{G<:AGraphOrDiGraph,T,E<:AEdge}(m::EdgeMap{G,T,Dict{E,T}}, x, e::E) = setindex!(m.data, x, e)
get{G<:AGraphOrDiGraph,T,E<:AEdge}(m::EdgeMap{G,T,Dict{E,T}}, e::E, x) = get(m.data, e, x)
haskey{G<:AGraphOrDiGraph,T,E<:AEdge}(m::EdgeMap{G,T,Dict{E,T}}, e::E) = haskey(m.data, e)

getindex{G<:AGraphOrDiGraph,T,E<:AEdge}(m::EdgeMap{G,T,Dict{E,T}}, e::AEdge) = getindex(m.data, E(src(e),dst(e)))
setindex!{G<:AGraphOrDiGraph,T,E<:AEdge}(m::EdgeMap{G,T,Dict{E,T}}, x, e::AEdge) = setindex!(m.data, x, E(src(e),dst(e)))
get{G<:AGraphOrDiGraph,T,E<:AEdge}(m::EdgeMap{G,T,Dict{E,T}}, e::AEdge, x) = get(m.data, E(src(e),dst(e)), x)
haskey{G<:AGraphOrDiGraph,T,E<:AEdge}(m::EdgeMap{G,T,Dict{E,T}}, e::AEdge) = haskey(m.data, E(src(e),dst(e)))
####
values{G,T,D<:Dict}(m::EdgeMap{G,T,D}) = values(m.data)
values{G,T,D<:Array}(m::EdgeMap{G,T,D}) = m.data
values{G,T,D<:AbstractSparseMatrix}(m::EdgeMap{G,T,D}) = nonzeros(m.data)

==(m1::EdgeMap, m2::EdgeMap) = m1.data == m2.data

"""
    struct ConstEdgeMap{T} <: SimpleEdgeMap{T}
        val::T
    end

A type representing a constant vector map.
Any attempt to change the internal value, e.g. `emap[u,v] = 4`, will
fail silently.
"""
struct ConstEdgeMap{T} <: AEdgeMap{T}
    val::T
end

ConstEdgeMap(g::AGraphOrDiGraph, x) = ConstEdgeMap(x)

length(m::ConstEdgeMap) = typemax(Int)
getindex(m::ConstEdgeMap, e::AEdge) = m.val

setindex!(m::ConstEdgeMap, x, i::Integer, j::Integer) = nothing #TODO not throwin since it is used as
                                                                # a dummy map
# setindex!(m::ConstEdgeMap, x, i::Integer, j::Integer) = error("Cannot assign to ConstEdgeMap")
getindex(m::ConstEdgeMap, i::Integer, j::Integer) = m.val
setindex!(m::ConstEdgeMap, x, e::AEdge) = nothing
# setindex!(m::ConstEdgeMap, x, e::AEdge) = error("Cannot assign to ConstEdgeMap")
get(m::ConstEdgeMap, e::AEdge, x) = m.val

values(m::ConstEdgeMap) = [m.val]

"""
    edgemap2adjlist(emap)

Returns a vector of vectors containing the values of the edge map `emap` on graph `g`
following the same ordering of [`adjacency_list`](@ref)`(g)`.
"""
edgemap2adjlist(m::AEdgeMap) = [[m[e] for e in out_edges(m.g, i)] for i=1:nv(m.g)]

function Base.Matrix(emap::EdgeMap)
    g = emap.g
    M = zeros(valtype(emap), nv(g), nv(g))
    return fill_mat_from_map!(M, g, emap)
end

function sparse(emap::EdgeMap)
    g = emap.g
    M = spzeros(valtype(emap), nv(g), nv(g))
    return fill_mat_from_map!(M, g, emap)
end

function fill_mat_from_map!(M, g::ADiGraph, emap::AEdgeMap)
    for e in edges(g)
        u, v = src(e), dst(e)
        M[u,v] = emap[e]
    end
    return M
end

function fill_mat_from_map!(M, g::AGraph, emap::AEdgeMap)
    for e in edges(g)
        u, v = src(e), dst(e)
        M[u,v] = M[v,u] = emap[e]
    end
    return M
end
