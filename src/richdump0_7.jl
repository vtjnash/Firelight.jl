import Base: undef_ref_str

const dump_indent = "    "

richdump(io::IO, dom::Vector{Node}, @nospecialize(x)) = richdump(IOContext(io), dom, x)

function richdump(io::IOContext, dom::Vector{Node}, @nospecialize(x))
    let id = startNode(dom, io, x, "")
        T = typeof(x)
        isa(x, Function) && print(io, " (function of type ")
        richprint(io, dom, T)
        isa(x, Function) && print(io, ")")
        nf = nfields(x)
        if nf > 0
            if !Base.show_circular(io, x)
                recur_io = IOContext(io, Pair{Symbol,Any}(:SHOWN_SET, x))
                for field in 1:nf
                    println(io)
                    nextChild(dom, io, id)
                    fname = string(fieldname(T, field))
                    print(io, dump_indent, fname, ": ")
                    if isdefined(x, field)
                        richprint(recur_io, dom, getfield(x, field))
                    else
                        print(io, undef_ref_str)
                    end
                end
            end
        else
            if !isa(x, Function)
                print(io, dump_indent)
                richprint(io, dom, x)
            end
        end
        endNode(dom, io, id)
    end
end

function richdump(io::IOContext, dom::Vector{Node}, x::Core.SimpleVector)
    let id = startNode(dom, io, x, "SimpleVector")
        if isempty(x)
            print(io, "empty SimpleVector")
        else
            print(io, "SimpleVector")
            for i = 1:length(x)
                println(io)
                nextChild(dom, io, id)
                print(io, dump_indent, i, ": ")
                if isassigned(x, i)
                    richprint(io, dom, x[i])
                else
                    print(io, undef_ref_str)
                end
            end
        end
        endNode(dom, io, id)
    end
end

richdump(io::IOContext, dom::Vector{Node}, x::Module) =
    let id = startNode(dom, io, x, "Module")
        print(io, "Module ", x)
        endNode(dom, io, id)
    end
richdump(io::IOContext, dom::Vector{Node}, x::String) =
    let id = startNode(dom, io, x, "String")
        print(io, "String ")
        show(io, x)
        endNode(dom, io, id)
    end
richdump(io::IOContext, dom::Vector{Node}, x::Symbol) =
    let id = startNode(dom, io, x, "Symbol")
        print(io, "Symbol ", x)
        endNode(dom, io, id)
    end
richdump(io::IOContext, dom::Vector{Node}, x::Ptr) =
    let id = startNode(dom, io, x, "Ptr")
        print(io, x) # this avoids print the type twice
        endNode(dom, io, id)
    end

function dump_elts(io::IOContext, dom::Vector{Node}, id::Int, x::Array, i0, i1)
    for i in i0:i1
        println(io)
        nextChild(dom, io, id)
        print(io, dump_indent, i, ": ")
        if !isassigned(x, i)
            print(io, undef_ref_str)
        else
            richprint(io, dom, x[i])
        end
    end
end

function richdump(io::IOContext, dom::Vector{Node}, x::Array{T}) where {T}
    let id = startNode(dom, io, x, "Array")
        print(io, "Array{")
        richprint(io, dom, T)
        print(io, "}(", string(size(x)), ")")
        if isprimitivetype(T) # was T <: Number
            print(io, " ")
            richprint(io, dom, x)
        else
            if !isempty(x) && !Base.show_circular(io, x)
                recur_io = IOContext(io, :SHOWN_SET => x)
                lx = length(x)
                if get(io, :limit, false) && lx > 10
                    dump_elts(recur_io, dom, id, x, 1, 5)
                    println(io)
                    print(io, "  ...")
                    dump_elts(recur_io, dom, id, x, lx - 4, lx)
                else
                    dump_elts(recur_io, dom, id, x, 1, lx)
                end
            end
        end
        endNode(dom, io, id)
    end
end

# Types
function richdump(io::IOContext, dom::Vector{Node}, x::DataType)
    let id = startNode(dom, io, x, "DataType")
        richprint(io, dom, x)
        if x !== Any
            print(io, " <: ")
            richprint(io, dom, supertype(x))
        end
        if !(x <: Tuple) && !x.abstract
            tvar_io::IOContext = io
            for tparam in x.parameters
                # approximately recapture the list of tvar parameterization
                # that may be used by the internal fields
                if isa(tparam, TypeVar)
                    tvar_io = IOContext(tvar_io, :unionall_env => tparam)
                end
            end
            fieldtypes = x.types
            for idx in 1:length(fieldtypes)
                println(io)
                nextChild(dom, io, id)
                print(io, dump_indent, fieldname(x, idx), "::")
                richprint(tvar_io, dom, fieldtypes[idx])
            end
        end
        endNode(dom, io, id)
    end
end

function richdump(io::IOContext, dom::Vector{Node}, x::UnionAll)
    let id = startNode(dom, io, x, "UnionAll")
        print(io, "UnionAll where var: {")
        tvar_io::IOContext = io
        while true
            println(io)
            nextChild(dom, io, id)
            print(io, dump_indent)
            richprint(tvar_io, dom, x.var)
            tvar_io = IOContext(tvar_io, :unionall_env => x.var)
            x = x.body
            if x isa UnionAll
                print(io, ",")
            else
                break
            end
        end
        println(io)
        println(io, "}")
        print(io, "body: ")
        nextChild(dom, io, id)
        richdump(tvar_io, dom, x)
        endNode(dom, io, id)
    end
end

function richdump(io::IOContext, dom::Vector{Node}, x::Union)
    let id = startNode(dom, io, x, "Union")
        richprint(io, dom, x)
        endNode(dom, io, id)
    end
end
