richprint(io::IO, dom::Vector{Node}, @nospecialize(x)) = richprint_default(io, dom, x)

function richprint_default(io::IO, dom::Vector{Node}, @nospecialize(x))
    t = typeof(x)
    isbits(t) && Base.show_circular(io, x) && return
    let id = startNode(dom, io, x, "")
        if which(Base.show, (typeof(io), typeof(x))).sig === Tuple{typeof(Base.show), IO, ANY}
            # override Base.default_show behavior
            nf = nfields(t)
            nb = sizeof(x)
            if nf != 0 || nb == 0
                Base.show(io, t)
                print(io, '(')
                recur_io = IOContext(io, :SHOWN_SET => x)
                for i in 1:nf
                    nextChild(dom, io, id)
                    f = fieldname(t, i)
                    if !isdefined(x, f)
                        print(io, undef_ref_str)
                    else
                        richprint(recur_io, dom, getfield(x, f))
                    end
                    if i < nf
                        print(io, ", ")
                    end
                end
                print(io, ')')
            else
                Base.show_default(io, x)
            end
        else
            Base.show(io, x)
        end
        endNode(dom, io, id)
    end
end
