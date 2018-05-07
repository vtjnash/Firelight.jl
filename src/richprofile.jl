# This file is a part of Julia. License is MIT: https://julialang.org/license

module Profile1

import Base.Profile
import .Profile: btskip, UNKNOWN, StackFrame

const LineInfoDict = Dict{UInt64, Vector{StackFrame}}
const LineInfoFlatDict = Dict{UInt64, StackFrame}

# Construct a prefix trie of backtrace counts
mutable struct StackFrameTree{T} # where T <: Union{UInt64, StackFrame}
    frame::StackFrame
    count::Int
    down::Dict{T, StackFrameTree{T}}
    StackFrameTree{T}(frame::StackFrame) where {T} = new(frame, 0, Dict{T, StackFrameTree{T}}())
end


# turn a list of backtraces into a tree (implicitly separated by NULL markers)
function tree!(root::StackFrameTree{T}, all::Vector{UInt64}, lidict::LineInfoFlatDict) where {T}
    toskip = btskip
    parent = root
    for ip in reverse(all)
        if ip == 0
            toskip = btskip
            parent = root
            parent.count += 1
        elseif toskip > 0
            toskip -= 1
        else
            let frame = lidict[ip]
                key = (T === UInt64 ? ip : frame)
                parent = get!(parent.down, key) do
                    return StackFrameTree{T}(frame)
                end
                parent.count += 1
            end
        end
    end
    return root
end

# Order alphabetically (file, function) and then by line number
function liperm(lilist::Vector{StackFrame})
    function lt(a::StackFrame, b::StackFrame)
        a == UNKNOWN && return false
        b == UNKNOWN && return true
        fcmp = cmp(a.file, b.file)
        fcmp < 0 && return true
        fcmp > 0 && return false
        fcmp = cmp(a.func, b.func)
        fcmp < 0 && return true
        fcmp > 0 && return false
        fcmp = cmp(a.line, b.line)
        fcmp < 0 && return true
        return false
    end
    return sortperm(lilist, lt = lt)
end

end # module

using .Profile1: StackFrameTree, LineInfoDict, LineInfoFlatDict

function tree_format(io::IO, dom::Vector{Node}, frame::StackFrameTree)
    li = frame.frame
    let id = startNode(dom, io, li, li.from_c ? "frame-c": "frame")
        print(io, frame.count)
        print(io, ' ')
        show(io, li; full_path = true)
        #if li == Profile.UNKNOWN
        #    print(io, " unknown stackframe")
        #else
        #    if li.line == li.pointer
        #        print(io, " unknown function (pointer: 0x",
        #            string(li.pointer, base = 16, pad = 2*sizeof(Ptr{Cvoid})),
        #            ")")
        #    else
        #        fname = string(li.func)
        #        if !li.from_c && li.linfo !== nothing
        #            fname = sprint(Profile.show_spec_linfo, li)
        #        end
        #        print(io, " ", string(li.file), ":",
        #            li.line == -1 ? "?" : string(li.line),
        #            "; ", fname)
        #    end
        #end
        endNode(dom, io, id)
    end
end

# Print a "branch" starting at a particular level. This gets called recursively.
function tree(io::IO, dom::Vector{Node}, bt::StackFrameTree)
    isempty(bt.down) && return
    let id = startNode(dom, io, bt, "level")
        # Order the line information
        nexts = collect(values(bt.down))
        lilist = collect(frame.frame for frame in nexts)
        # Generate the string for each line
        # Recurse to the next level
        for i in Profile1.liperm(lilist)
            nextChild(dom, io, id)
            down = nexts[i]
            tree_format(io, dom, down)
            tree(io, dom, down)
        end
        endNode(dom, io, id)
    end
end

function tree(io::IO, dom::Vector{Node}, data::Vector{UInt64}, lidict::LineInfoFlatDict)
    combine = true
    if combine
        root = Profile1.tree!(StackFrameTree{StackFrame}(Profile.UNKNOWN), data, lidict)
    else
        root = Profile1.tree!(StackFrameTree{UInt64}(Profile.UNKNOWN), data, lidict)
    end
    let id = startNode(dom, io, root, "ProfileTree")
        tree(io, dom, root)
        endNode(dom, io, id)
    end
    nothing
end

function tree(io::IO, dom::Vector{Node}, data::Vector{UInt64}, lidict::LineInfoDict)
    newdata, newdict = Profile.flatten(data, lidict)
    tree(io, dom, newdata, newdict)
    nothing
end

function richprofile(data::Vector{<:Unsigned} = Profile.fetch(), lidict::LineInfoDict = Profile.getdict(data))
    dom = Vector{Node}()
    io = IOBuffer()
    tree(convert(IOContext, io), dom, data, lidict)
    return annotate!(take!(io), dom)
end
