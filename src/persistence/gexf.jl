function writegexf(f::IO, g::AGraphOrDiGraph)
    xdoc = XMLDocument()
    xroot = setroot!(xdoc, ElementNode("gexf"))
    xroot["xmlns"] = "http://www.gexf.net/1.2draft"
    xroot["version"] = "1.2"
    xroot["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
    xroot["xsi:schemaLocation"] = "http://www.gexf.net/1.2draft/gexf.xsd"

    xmeta = addelement!(xroot, "meta")
    xg = addelement!(xroot, "graph")
    xg["defaultedgetype"] = is_directed(g) ? "directed" : "undirected"
    xnodes = addelement!(xg, "nodes")
    for i in 1:nv(g)
        xv = addelement!(xnodes, "node")
        xv["id"] = "$(i-1)"
    end

    xedges = addelement!(xg, "edges")
    m = 0
    for e in edges(g)
        xe = addelement!(xedges, "edge")
        xe["id"] = "$m"
        xe["source"] = "$(src(e)-1)"
        xe["target"] = "$(dst(e)-1)"
        m += 1
    end

    prettyprint(f, xdoc)
    return 1
end

function gexf_read_one_graph!{G}(el::EzXML.Node, ::Type{G})
    elnodes = getchild(el, "nodes")
    nodes = Dict{String,Int}()
    for (i,f) in enumerate(eachelement(elnodes))
        nodes[f["id"]] = i
    end

    g = G(length(nodes))

    eledges = getchild(el, "edges")
    for f in eachelement(eledges)
        n1 = f["source"]
        n2 = f["target"]
        add_edge!(g, nodes[n1], nodes[n2])
    end

    return g
end

function readgexf{G<:AGraphOrDiGraph}(io::IO, ::Type{G})
    xdoc = parsexml(readstring(io))
    xroot = root(xdoc)  # an instance of XMLElement
    name(xroot) == "gexf" || error("Not a Gexf file")
    xg = getchild(xroot, "graph")
    isdir = false
    if haskey(xg, "defaultedgetype")
        isdir = xg["defaultedgetype"] == "directed"  ? true  : false
    end
    H = isdir ? digraphtype(G) : graphtype(G)
    return gexf_read_one_graph!(xg, H)
end

function readnetgexf{G<:AGraphOrDiGraph}(io::IO, ::Type{G})
    xdoc = parsexml(readstring(io))
    xroot = root(xdoc)  # an instance of XMLElement
    name(xroot) == "gexf" || error("Not a Gexf file")
    xg = getchild(xroot, "graph")
    isdir = false
    if haskey(xg, "defaultedgetype")
        isdir = xg["defaultedgetype"] == "directed"  ? true  : false
    end

    gpropkeys=Dict{String, Tuple{String, DataType}}();
    vpropkeys=Dict{String, Tuple{String, DataType}}();
    epropkeys=Dict{String, Tuple{String, DataType}}();

    # Reading attributes
    # Note: if no default value is specified for an attribute
    # each node/edge has to implement it
    for xattr in elements(xg)
        name(xattr) != "attributes" && continue
        pk =  xattr["class"] == "node" ? vpropkeys :
              xattr["class"] == "edge" ? epropkeys : error("attr")

        for el in elements(xattr)
            pk[el["id"]] = (el["title"],  gexf_types_rev[el["type"]])
            #TODO eventually read default value
            #TODO grab namespace : namespace(el) (e.g. viz:)
        end
    end

    H = isdir ? digraphtype(G) : graphtype(G)
    return gexf_read_one_net!(xg, H, gpropkeys, vpropkeys, epropkeys)
end


const gexf_types = Dict( Int32 => "integer",
                            Int64 => "integer",
                            Bool => "boolean",
                            Float32 => "float",
                            Float64 => "double",
                            String => "string",
                            )

const gexf_types_rev = Dict("integer"  =>  Int,
                            "boolean" =>  Bool,
                            "float"   =>  Float32,
                            "double"  =>  Float64,
                            "string"  =>  String,
                        )

gexfstring(x) = string(x)
gexfstring(v::Vector) = join((@sprintf("%.10g",x) for x in v), ", ")


gexfparse(T, x::String) = parse(T, x)
gexfparse(::Type{String}, x::String) = x

#TODO implement Vector support
if VERSION < v"0.6.0-dev.693" # julia PR #16986
gexfparse{T}(::Type{Vector{T}}, x::String) =
    map(v->parse(T,v),  split(x, ','))
else
gexfparse{T}(::Type{Vector{T}}, x::String) = parse.(T, split(x, ','))
end


function gexf_read_one_net!{G}(xg::EzXML.Node, ::Type{G},
                        gpropkeys, vpropkeys, epropkeys)
    nodes = Dict{String,Int}()
    nodeid = 1
    # traverse the tree to map id to 1:n
    for el in eachelement(getchild(xg,"nodes"))
        name(el) != "node" && continue #TODO can be removed
        nodes[el["id"]] = nodeid
        nodeid += 1
    end

    g = G(length(nodes))
    for (pname,T) in values(vpropkeys); vprop!(g, pname, T); end
    for (pname,T) in values(epropkeys); eprop!(g, pname, T); end

    for f in eachelement(getchild(xg,"nodes"))
        @assert name(f) == "node"
        v = nodes[f["id"]]
        for xattr in eachattribute(f)
            nattr = name(xattr)
            nattr == "id" && continue
            !has_vprop(g, nattr) && vprop!(g, nattr, String)
            vprop(g, nattr)[v] = f[nattr]
        end
        for el in eachelement(f)
            if name(el) == "attvalues"
                for xattr in eachelement(el)
                    pname, T = vpropkeys[xattr["for"]]
                    vprop(g, pname)[v] = gexfparse(T, xattr["value"])
                end
            else
                pname = name(el)
                attr = name.(attributes(el))
                if "value" in attr && length(attr) == 1
                    !has_vprop(g, pname) && vprop!(g, pname, String)
                    vprop(g, pname)[v] = el["value"]
                else
                    #TODO parse to vector of floats properties under viz namespace
                    !has_vprop(g, pname) && vprop!(g, pname, Dict{String,String})
                    vprop(g, pname)[v] = Dict{String,String}(a=>el[a] for a in attr)
                end
            end
        end
    end

    for f in eachelement(getchild(xg,"edges"))
        @assert name(f) == "edge"
        u = nodes[f["source"]]
        v = nodes[f["target"]]
        ok, e = add_edge!(g, u, v)
        for xattr in eachattribute(f)
            nattr = name(xattr)
            nattr ∈ ["id","source","target"] && continue
            Tattr = nattr == "weight" ? Float64 : String
            !has_eprop(g, nattr) && eprop!(g, nattr, Tattr)
            eprop(g, nattr)[e] = Tattr == String ? f[nattr] : parse(Tattr, f[nattr])
        end
        for el in eachelement(f)
            if name(el) == "attvalues"
                for xattr in eachelement(el)
                    pname, T = epropkeys[xattr["for"]]
                    eprop(g, pname)[e] = gexfparse(T, xattr["value"])
                end
            else
                pname = name(el)
                attr = name.(attributes(el))
                if "value" in attr && length(attr) == 1
                    !has_eprop(g, pname) && eprop!(g, pname, String)
                    eprop(g, pname)[e] = el["value"]
                else
                    !has_eprop(g, pname) && eprop!(g, pname, Dict{String,String})
                    eprop(g, pname)[e] = Dict{String,String}(a=>el[a] for a in attr)
                end
            end
        end
        # for el in eachelement(f)
        #     pname, T = epropkeys[el["key"]]
        #     m = eprop(g, pname)
        #     m[e] = gexfparse(T, content(el))
        # end
    end
    return g
end

function writenetgexf(f::IO, g::ANetOrDiNet)
    xdoc = XMLDocument()
    xroot = setroot!(xdoc, ElementNode("gexf"))
    xroot["version"]="1.3"
    xroot["xmlns"] = "http://www.gexf.net/1.3"
    xroot["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
    xroot["xsi:schemaLocation"]="http://www.gexf.net/1.3/gexf.xsd"

    xmeta = addelement!(xroot, "meta")
    xmeta["lastmodifieddate"] = string(Base.Dates.today())
    xg = addelement!(xroot, "graph")
    xg["defaultedgetype"] = is_directed(g) ? "directed" : "undirected"
    xg["mode"] = "static"


    vattrnames = String[]
    if length(vprop(g)) > 0
        xa = addelement!(xg, "attributes")
        xa["class"] = "node"
        xa["mode"] = "static"
        for (pname, m) in vprop(g)
            pname == "label" && continue
            T = valtype(m)
            if T ∈ keys(gexf_types)
                xaa = addelement!(xa, "attribute")
                push!(vattrnames, pname)
                xaa["id"] = pname
                xaa["title"] = pname
                xaa["type"] = gexf_types[T]
            end
        end
    end

    eattrnames = String[]
    if length(eprop(g)) > 0
        xa = addelement!(xg, "attributes")
        xa["class"] = "node"
        xa["mode"] = "static"
        for (pname, m) in eprop(g)
            pname == "weight" && continue
            T = valtype(m)
            xaa = addelement!(xa, "attribute")
            push!(eattrnames, pname)
            xaa["id"] = pname
            xaa["title"] = pname
            xaa["type"] = gexf_types[T]
        end
    end

    xnodes = addelement!(xg, "nodes")
    xnodes["count"] = nv(g)
    for i in 1:nv(g)
        xv = addelement!(xnodes, "node")
        xv["id"] = "$(i-1)"
        if has_vprop(g, "label", i)
            xv["label"] = vprop(g,"label")[i]
        end
    end


    xedges = addelement!(xg, "edges")
    xedges["count"] = ne(g)
    m = 0
    for e in edges(g)
        xe = addelement!(xedges, "edge")
        xe["id"] = "$m"
        xe["source"] = "$(src(e)-1)"
        xe["target"] = "$(dst(e)-1)"
        if has_eprop(g, "weight", e)
            xe["weight"] = eprop(g,"weight")[e]
        end
        m += 1
    end

    prettyprint(f, xdoc)
    return 1
end

filemap[:gexf] = (readgexf, writegexf, readnetgexf, writenetgexf)
