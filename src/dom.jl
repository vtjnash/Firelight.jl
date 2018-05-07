mutable struct Node
    #id::Int
    start::Int
    endof::Int
    class::String
    object::Any
    childstarts::Vector{Int}
end
const DELETED = Node(0, -1, "", nothing, Int[])

function startNode(shadowdom::Vector{Node}, io::IO, o::ANY, class::String)
    id = length(shadowdom) + 1
    n = Node(position(io), -1, class, o, DELETED.childstarts)
    push!(shadowdom, n)
    return id
end

function endNode(shadowdom::Vector{Node}, io::IO, id::Int)
    endof = position(io)
    for i in id:length(shadowdom)
        n = shadowdom[i]
        n.endof == -1 || return
        n.endof = endof
    end
end

function nextChild(shadowdom::Vector{Node}, io::IO, id::Int)
    n = shadowdom[id]
    n.childstarts === DELETED.childstarts && (n.childstarts = Int[])
    push!(n.childstarts, id)
    nothing
end

function richprint(o::ANY)
    dom = Vector{Node}()
    io = IOBuffer()
    richprint(convert(IOContext, io), dom, o)
    return annotate!(take!(io), dom)
end

function annotate!(out::AbstractVector{UInt8}, dom::Vector{Node})
    io = IOBuffer()
    prevstart = 0
    stack = []
    push!(dom, DELETED)
    for (id, node) in enumerate(dom)
        next = node.start
        while !isempty(stack) && (stack[end].endof <= next || id == length(dom))
            let next = pop!(stack).endof
                escapehtml(io, view(out, (prevstart + 1):next), false)
                print(io, "</span>")
                prevstart = next
            end
        end
        if node !== DELETED
            escapehtml(io, view(out, (prevstart + 1):next), false)
            print(io, "<span id=\"n-")
            print(io, id)
            print(io, "\" class=\"")
            print(io, !isempty(node.class) ? node.class : "any")
            print(io, "\">")
            push!(stack, node)
            prevstart = next
        end
    end
    write(io, view(out, (prevstart + 1):length(out)))
    pop!(dom)
    return (String(take!(io)), dom)
end

include("richprint.jl")
include("richprofile.jl")
