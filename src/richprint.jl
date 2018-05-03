function richprint(io::IO, dom::Vector{Node}, x::ANY)
    let id = startNode(dom, io, x, "")
        print(io, x)
        endNode(dom, io, id)
    end
    nothing
end

function richprint(io::IO, dom::Vector{Node}, ci::CodeInfo)
    io = IOContext(io, :SOURCEINFO => ci)
    if ci.slotnames !== nothing
        io = IOContext(io, :SOURCE_SLOTNAMES => Base.sourceinfo_slotnames(ci))
    end
    let id = startNode(dom, io, ci, "CodeInfo")
        let id = startNode(dom, io, ci.code, "code")
            for stmt in ci.code
                nextChild(dom, io, id)
                richprint(io, dom, stmt)
                println(io)
            end
            endNode(dom, io, id)
        end
        #let id = startNode(dom, io, ci.code, "types")
        #    for stmt in ci.code
        #        if stmt isa Expr && stmt.head === :(=) && length(stmt.args) == 2
        #            stmt = stmt.args[2]
        #        end
        #        if stmt isa Expr && stmt.head === :(return) && length(stmt.args) == 1
        #            stmt = stmt.args[1]
        #        end
        #        richprint(io, dom, Core.Inference.exprtype(stmt, ci, Main))
        #    end
        #    endNode(dom, io, id)
        #end
        endNode(dom, io, id)
    end
    nothing
end
