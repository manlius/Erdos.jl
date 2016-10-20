include("../src/FatGraphs.jl")
using FatGraphs
using Base.Test

tests = [
    "core/edge",
    "core/interface",
    "core/core",
    "core/edgeiter",
    "core/operators",
    "core/connectivity",
    "factory/graphdigraph",
    "distances/distance",
    "distances/edit_distance",
    "linalg/spectral",
    "persistence/persistence",
    "generators/randgraphs",
    "generators/staticgraphs",
    "generators/smallgraphs",
    "generators/euclideangraphs",
    "generators/matrixdepot",
    "shortestpaths/astar",
    "shortestpaths/bellman-ford",
    "shortestpaths/dijkstra",
    "shortestpaths/floyd-warshall",
    "traversals/bfs",
    "traversals/dfs",
    "traversals/maxadjvisit",
    "traversals/graphvisit",
    "traversals/randomwalks",
    "community/core-periphery",
    "community/cliques",
    "community/modularity",
    "community/clustering",
    "community/detection",
    "centrality/betweenness",
    "centrality/closeness",
    "centrality/degree",
    "centrality/katz",
    "centrality/pagerank",
    "flow/edmonds_karp",
    "flow/dinic",
    "flow/boykov_kolmogorov",
    "flow/push_relabel",
    "flow/maximum_flow",
    "flow/multiroute_flow",
    "spanningtrees/kruskal",
    "matching/matching",
    "interdiction/interdiction",
    "utils"
]


testdir = dirname(@__FILE__)
(G, DG) = (Graph, DiGraph)

@testset "FatGraphs Testing" begin
    for t in tests
        tp = joinpath(testdir,"$(t).jl")
        # (G, DG) = (Graph, DiGraph)
        print("running $t.jl ...")
        @testset "$t" begin
            include(tp)
        end
        println(" done")
    end
end
