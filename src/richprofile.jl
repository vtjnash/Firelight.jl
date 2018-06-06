# This file is a part of Julia. License is MIT: https://julialang.org/license

#const Profile1 = Base.root_module(Base.PkgId(Base.UUID("9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"), "Profile"))
using Profile
using Profile: StackFrameTree, LineInfoDict, LineInfoFlatDict, StackFrame

function tree_format(io::IO, dom::Vector{Node}, frame::StackFrameTree)
    li = frame.frame
    let id = startNode(dom, io, li, li.from_c ? "frame-c" : "frame")
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

function drop_shadow!(node::StackFrameTree)
    empty!(node.builder_key)
    empty!(node.builder_value)
    foreach(drop_shadow!, values(node.down))
    nothing
end

function tree(io::IO, dom::Vector{Node}, data::Vector{UInt64}, lidict::LineInfoFlatDict)
    combine = true
    if combine
        root = Profile1.tree!(StackFrameTree{StackFrame}(), data, lidict, true)
    else
        root = Profile1.tree!(StackFrameTree{UInt64}(), data, lidict, true)
    end
    drop_shadow!(root)
    let id = startNode(dom, io, root, "ProfileTree")
        tree(io, dom, root)
        endNode(dom, io, id)
    end
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
