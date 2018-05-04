richprint(io::IO, dom::Vector{Node}, x::ANY) = richprint_default(io, dom, x)

function richprint_default(io::IO, dom::Vector{Node}, x::ANY)
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

function richprint(io::IO, dom::Vector{Node}, x::Union)
    let id = startNode(dom, io, x, "Union")
        print(io, "Union")
        sorted_types = sort!(uniontypes(x); by=string)
        show_delim_array(io, dom, id, sorted_types, '{', ',', '}', false)
        endNode(dom, io, id)
    end
end

function richprint(io::IO, dom::Vector{Node}, x::UnionAll)
    let id = startNode(dom, io, x, "UnionAll")
        if Base.print_without_params(x)
            return Base.show(io, Base.unwrap_unionall(x).name)
        end
        richprint(IOContext(io, :unionall_env => x.var), dom, x.body)
        print(io, " where ")
        richprint(io, dom, x.var)
        endNode(dom, io, id)
    end
end

richprint(io::IO, dom::Vector{Node}, x::DataType) = richprint_datatype(io, dom, x)

function richprint_datatype(io::IO, dom::Vector{Node}, x::DataType)
    let id = startNode(dom, io, x, "DataType")
        istuple = x.name === Tuple.name
        if (!isempty(x.parameters) || istuple) && x !== Tuple
            n = length(x.parameters)

            # Print homogeneous tuples with more than 3 elements compactly as NTuple{N, T}
            if istuple && n > 3 && all(i -> (x.parameters[1] === i), x.parameters)
                print(io, "NTuple{", n, ", ")
                richprint(io, dom, x.parameters[1])
                print(io, "}")
            else
                Base.show(io, x.name)
                # Do not print the type parameters for the primary type if we are
                # printing a method signature or type parameter.
                # Always print the type parameter if we are printing the type directly
                # since this information is still useful.
                print(io, '{')
                for (i, p) in enumerate(x.parameters)
                    nextChild(dom, io, id)
                    richprint(io, dom, p)
                    i < n && print(io, ", ")
                end
                print(io, '}')
            end
        else
            Base.show(io, x.name)
        end
        endNode(dom, io, id)
    end
end

function richprint(io::IO, dom::Vector{Node}, p::Pair)
    let id = startNode(dom, io, p, "Pair")
        print(io, "(")
        nextChild(dom, io, id)
        richprint(io, dom, p.first)
        print(io, " => ")
        nextChild(dom, io, id)
        richprint(io, dom, p.second)
        print(io, ")")
        endNode(dom, io, id)
    end
end

function richprint(io::IO, dom::Vector{Node}, l::Core.MethodInstance)
    let id = startNode(dom, io, l, "MethodInstance")
        if isdefined(l, :def)
            if l.def.isstaged && l === l.def.generator
                print(io, "(@generated thunk)")
                richprint(io, dom, l.def)
            else
                show_tuple_as_call(io, dom, id, l.def.name, l.specTypes)
            end
        else
            print(io, "(Toplevel thunk)")
        end
        endNode(dom, io, id)
    end
end

function richprint(io::IO, dom::Vector{Node}, src::CodeInfo)
    # Fix slot names and types in function body
    lambda_io = IOContext(io, :SOURCEINFO => src)
    if src.slotnames !== nothing
        lambda_io = IOContext(io, :SOURCE_SLOTNAMES => Base.sourceinfo_slotnames(src))
    end
    let id = startNode(dom, io, src, "CodeInfo")
        print(io, "CodeInfo(")
        body = Expr(:body)
        body.args = src.code
        richprint(lambda_io, dom, body)
        print(io, ")")
        endNode(dom, io, id)
    end
    nothing
end


function show_delim_array(io::IO, dom::Vector{Node}, id::Int,
                          itr::Union{AbstractArray,SimpleVector}, op, delim, cl,
                          delim_one, i1=first(linearindices(itr)), l=last(linearindices(itr)))
    print(io, op)
    if !show_circular(io, itr)
        recur_io = IOContext(io, :SHOWN_SET => itr)
        if !haskey(io, :compact)
            recur_io = IOContext(recur_io, :compact => true)
        end
        first = true
        i = i1
        if l >= i1
            while true
                nextChild(dom, io, id)
                if !isassigned(itr, i)
                    print(io, undef_ref_str)
                else
                    x = itr[i]
                    richprint(recur_io, dom, x)
                end
                i += 1
                if i > l
                    delim_one && first && print(io, delim)
                    break
                end
                first = false
                print(io, delim)
                print(io, ' ')
            end
        end
    end
    print(io, cl)
end

function show_delim_array(io::IO, dom::Vector{Node}, id::Int, itr, op, delim, cl, delim_one, i1=1, n=typemax(Int))
    print(io, op)
    if !show_circular(io, itr)
        recur_io = IOContext(io, :SHOWN_SET => itr)
        state = start(itr)
        first = true
        while i1 > 1 && !done(itr, state)
            _, state = next(itr, state)
            i1 -= 1
        end
        if !done(itr, state)
            while true
                x, state = next(itr, state)
                nextChild(dom, io, id)
                richprint(recur_io, dom, x)
                i1 += 1
                if done(itr, state) || i1 > n
                    delim_one && first && print(io, delim)
                    break
                end
                first = false
                print(io, delim)
                print(io, ' ')
            end
        end
    end
    print(io, cl)
end

function richprint(io::IO, dom::Vector{Node}, t::Tuple)
    let id = startNode(dom, io, t, "Tuple")
        show_delim_array(io, dom, id, t, '(', ',', ')', true)
        endNode(dom, io, id)
    end
end
function richprint(io::IO, dom::Vector{Node}, v::SimpleVector)
    let id = startNode(dom, io, v, "SimpleVector")
        show_delim_array(io, dom, id, v, "svec(", ',', ')', false)
        endNode(dom, io, id)
    end
end

## Abstract Syntax Tree (AST) printing ##

const ExprNode = Base.ExprNode

#show(io::IO, ex::ExprNode)             = show_unquoted_quote_expr(io, ex, 0, -1)
#show_unquoted(io::IO, ex)              = show_unquoted(io, ex, 0, 0)
#show_unquoted(io::IO, ex, indent::Int) = show_unquoted(io, ex, indent, 0)
#show_unquoted(io::IO, ex, ::Int,::Int) = show(io, ex)

## AST printing constants ##

import Base:
    indent_width, quoted_syms, uni_ops,
    expr_infix_wide, expr_infix, expr_infix_any,
    all_ops, expr_calls, expr_parens

# AST decoding helpers ##

import Base:
    is_id_start_char, is_id_char, isidentifier, isoperator,
    operator_precedence, prec_power, prec_decl,
    is_expr, is_linenumber, is_quoted, unquoted

## AST printing helpers ##

typeemphasize(io::IO) = get(io, :TYPEEMPHASIZE, false) === true

#function show_expr_type(io::IO, ty::ANY, emph::Bool)
#    if ty === Function
#        print(io, "::F")
#    elseif ty === Core.IntrinsicFunction
#        print(io, "::I")
#    else
#        if emph && (!isleaftype(ty) || ty == Core.Box)
#            emphasize(io, "::$ty")
#        else
#            print(io, "::$ty")
#        end
#    end
#end

emphasize(io, str::AbstractString) = print(io, uppercase(str))

show_linenumber(io::IO, line)       = print(io, " # line ", line, ':')
show_linenumber(io::IO, line, file) = print(io, " # ", file, ", line ", line, ':')

## show a block, e g if/for/etc
#function show_block(io::IO, head, args::Vector, body, indent::Int)
#    print(io, head, ' ')
#    show_list(io, args, ", ", indent)
#
#    ind = head === :module || head === :baremodule ? indent : indent + indent_width
#    exs = (is_expr(body, :block) || is_expr(body, :body)) ? body.args : Any[body]
#    for ex in exs
#        if !is_linenumber(ex); print(io, '\n', " "^ind); end
#        show_unquoted(io, ex, ind, -1)
#    end
#    print(io, '\n', " "^indent)
#end
#show_block(io::IO,head,    block,i::Int) = show_block(io,head, [], block,i)
#function show_block(io::IO, head, arg, block, i::Int)
#    if is_expr(arg, :block)
#        show_block(io, head, arg.args, block, i)
#    else
#        show_block(io, head, Any[arg], block, i)
#    end
#end
#
## show an indented list
#function show_list(io::IO, items, sep, indent::Int, prec::Int=0, enclose_operators::Bool=false)
#    n = length(items)
#    if n == 0; return end
#    indent += indent_width
#    first = true
#    for item in items
#        !first && print(io, sep)
#        parens = enclose_operators && isa(item,Symbol) && isoperator(item)
#        parens && print(io, '(')
#        show_unquoted(io, item, indent, prec)
#        parens && print(io, ')')
#        first = false
#    end
#end
## show an indented list inside the parens (op, cl)
#function show_enclosed_list(io::IO, op, items, sep, cl, indent, prec=0, encl_ops=false)
#    print(io, op)
#    show_list(io, items, sep, indent, prec, encl_ops)
#    print(io, cl)
#end
#
## show a normal (non-operator) function call, e.g. f(x, y) or A[z]
#function show_call(io::IO, head, func, func_args, indent)
#    op, cl = expr_calls[head]
#    if isa(func, Symbol) || (isa(func, Expr) &&
#            (func.head == :. || func.head == :curly))
#        show_unquoted(io, func, indent)
#    else
#        print(io, '(')
#        show_unquoted(io, func, indent)
#        print(io, ')')
#    end
#    if head == :(.)
#        print(io, '.')
#    end
#    if !isempty(func_args) && isa(func_args[1], Expr) && func_args[1].head === :parameters
#        print(io, op)
#        show_list(io, func_args[2:end], ", ", indent)
#        print(io, "; ")
#        show_list(io, func_args[1].args, ", ", indent)
#        print(io, cl)
#    else
#        show_enclosed_list(io, op, func_args, ", ", cl, indent)
#    end
#end
#
### AST printing ##
#
#show_unquoted(io::IO, sym::Symbol, ::Int, ::Int)        = print(io, sym)
#show_unquoted(io::IO, ex::LineNumberNode, ::Int, ::Int) = show_linenumber(io, ex.line)
#show_unquoted(io::IO, ex::LabelNode, ::Int, ::Int)      = print(io, ex.label, ": ")
#show_unquoted(io::IO, ex::GotoNode, ::Int, ::Int)       = print(io, "goto ", ex.label)
#show_unquoted(io::IO, ex::GlobalRef, ::Int, ::Int)      = print(io, ex.mod, '.', ex.name)
#
#function show_unquoted(io::IO, ex::Slot, ::Int, ::Int)
#    typ = isa(ex,TypedSlot) ? ex.typ : Any
#    slotid = ex.id
#    src = get(io, :SOURCEINFO, false)
#    if isa(src, CodeInfo)
#        slottypes = (src::CodeInfo).slottypes
#        if isa(slottypes, Array) && slotid <= length(slottypes::Array)
#            slottype = slottypes[slotid]
#            # The Slot in assignment can somehow have an Any type
#            if isa(slottype, Type) && isa(typ, Type) && slottype <: typ
#                typ = slottype
#            end
#        end
#    end
#    slotnames = get(io, :SOURCE_SLOTNAMES, false)
#    if (isa(slotnames, Vector{String}) &&
#        slotid <= length(slotnames::Vector{String}))
#        print(io, (slotnames::Vector{String})[slotid])
#    else
#        print(io, "_", slotid)
#    end
#    emphstate = typeemphasize(io)
#    if emphstate || (typ !== Any && isa(ex,TypedSlot))
#        show_expr_type(io, typ, emphstate)
#    end
#end
#
#function show_unquoted(io::IO, ex::QuoteNode, indent::Int, prec::Int)
#    if isa(ex.value, Symbol)
#        show_unquoted_quote_expr(io, ex.value, indent, prec)
#    else
#        print(io, "\$(QuoteNode(")
#        show(io, ex.value)
#        print(io, "))")
#    end
#end
#
#function show_unquoted_quote_expr(io::IO, value, indent::Int, prec::Int)
#    if isa(value, Symbol) && !(value in quoted_syms)
#        s = string(value)
#        if isidentifier(s) || isoperator(value)
#            print(io, ":")
#            print(io, value)
#        else
#            print(io, "Symbol(\"", escape_string(s), "\")")
#        end
#    else
#        if isa(value,Expr) && value.head === :block
#            show_block(io, "quote", value, indent)
#            print(io, "end")
#        else
#            print(io, ":(")
#            show_unquoted(io, value, indent+indent_width, -1)
#            print(io, ")")
#        end
#    end
#end
#
#function show_generator(io, ex, indent)
#    if ex.head === :flatten
#        fg = ex
#        ranges = Any[]
#        while isa(fg, Expr) && fg.head === :flatten
#            push!(ranges, fg.args[1].args[2:end])
#            fg = fg.args[1].args[1]
#        end
#        push!(ranges, fg.args[2:end])
#        show_unquoted(io, fg.args[1], indent)
#        for r in ranges
#            print(io, " for ")
#            show_list(io, r, ", ", indent)
#        end
#    else
#        show_unquoted(io, ex.args[1], indent)
#        print(io, " for ")
#        show_list(io, ex.args[2:end], ", ", indent)
#    end
#end
#
## TODO: implement interpolated strings
#function show_unquoted(io::IO, ex::Expr, indent::Int, prec::Int)
#    head, args, nargs = ex.head, ex.args, length(ex.args)
#    emphstate = typeemphasize(io)
#    show_type = true
#    if (ex.head == :(=) || ex.head == :line ||
#        ex.head == :boundscheck ||
#        ex.head == :gotoifnot ||
#        ex.head == :return)
#        show_type = false
#    end
#    if !emphstate && ex.typ === Any
#        show_type = false
#    end
#    # dot (i.e. "x.y"), but not compact broadcast exps
#    if head === :(.) && !is_expr(args[2], :tuple)
#        show_unquoted(io, args[1], indent + indent_width)
#        print(io, '.')
#        if is_quoted(args[2])
#            show_unquoted(io, unquoted(args[2]), indent + indent_width)
#        else
#            print(io, '(')
#            show_unquoted(io, args[2], indent + indent_width)
#            print(io, ')')
#        end
#
#    # infix (i.e. "x <: y" or "x = y")
#    elseif (head in expr_infix_any && nargs==2) || (head === :(:) && nargs==3)
#        func_prec = operator_precedence(head)
#        head_ = head in expr_infix_wide ? " $head " : head
#        if func_prec <= prec
#            show_enclosed_list(io, '(', args, head_, ')', indent, func_prec, true)
#        else
#            show_list(io, args, head_, indent, func_prec, true)
#        end
#
#    # list (i.e. "(1, 2, 3)" or "[1, 2, 3]")
#    elseif haskey(expr_parens, head)               # :tuple/:vcat
#        op, cl = expr_parens[head]
#        if head === :vcat
#            sep = "; "
#        elseif head === :hcat || head === :row
#            sep = " "
#        else
#            sep = ", "
#        end
#        head !== :row && print(io, op)
#        show_list(io, args, sep, indent)
#        if nargs == 1
#            if head === :tuple
#                print(io, ',')
#            elseif head === :vcat
#                print(io, ';')
#            end
#        end
#        head !== :row && print(io, cl)
#
#    # function call
#    elseif head === :call && nargs >= 1
#        func = args[1]
#        fname = isa(func,GlobalRef) ? func.name : func
#        func_prec = operator_precedence(fname)
#        if func_prec > 0 || fname in uni_ops
#            func = fname
#        end
#        func_args = args[2:end]
#
#        if (in(ex.args[1], (GlobalRef(Base, :bitcast), :throw)) ||
#            ismodulecall(ex))
#            show_type = false
#        end
#        if show_type
#            prec = prec_decl
#        end
#
#        # scalar multiplication (i.e. "100x")
#        if (func === :* &&
#            length(func_args)==2 && isa(func_args[1], Real) && isa(func_args[2], Symbol))
#            if func_prec <= prec
#                show_enclosed_list(io, '(', func_args, "", ')', indent, func_prec)
#            else
#                show_list(io, func_args, "", indent, func_prec)
#            end
#
#        # unary operator (i.e. "!z")
#        elseif isa(func,Symbol) && func in uni_ops && length(func_args) == 1
#            show_unquoted(io, func, indent)
#            if isa(func_args[1], Expr) || func_args[1] in all_ops
#                show_enclosed_list(io, '(', func_args, ", ", ')', indent, func_prec)
#            else
#                show_unquoted(io, func_args[1])
#            end
#
#        # binary operator (i.e. "x + y")
#        elseif func_prec > 0 # is a binary operator
#            na = length(func_args)
#            if (na == 2 || (na > 2 && func in (:+, :++, :*))) &&
#                    all(!isa(a, Expr) || a.head !== :... for a in func_args)
#                sep = " $func "
#                if func_prec <= prec
#                    show_enclosed_list(io, '(', func_args, sep, ')', indent, func_prec, true)
#                else
#                    show_list(io, func_args, sep, indent, func_prec, true)
#                end
#            elseif na == 1
#                # 1-argument call to normally-binary operator
#                op, cl = expr_calls[head]
#                print(io, "(")
#                show_unquoted(io, func, indent)
#                print(io, ")")
#                show_enclosed_list(io, op, func_args, ", ", cl, indent)
#            else
#                show_call(io, head, func, func_args, indent)
#            end
#
#        # normal function (i.e. "f(x,y)")
#        else
#            show_call(io, head, func, func_args, indent)
#        end
#
#    # other call-like expressions ("A[1,2]", "T{X,Y}", "f.(X,Y)")
#    elseif haskey(expr_calls, head) && nargs >= 1  # :ref/:curly/:calldecl/:(.)
#        funcargslike = head == :(.) ? ex.args[2].args : ex.args[2:end]
#        show_call(io, head, ex.args[1], funcargslike, indent)
#
#    # comprehensions
#    elseif head === :typed_comprehension && length(args) == 2
#        show_unquoted(io, args[1], indent)
#        print(io, '[')
#        show_generator(io, args[2], indent)
#        print(io, ']')
#
#    elseif head === :comprehension && length(args) == 1
#        print(io, '[')
#        show_generator(io, args[1], indent)
#        print(io, ']')
#
#    elseif (head === :generator && length(args) >= 2) || (head === :flatten && length(args) == 1)
#        print(io, '(')
#        show_generator(io, ex, indent)
#        print(io, ')')
#
#    elseif head === :filter && length(args) == 2
#        show_unquoted(io, args[2], indent)
#        print(io, " if ")
#        show_unquoted(io, args[1], indent)
#
#    # comparison (i.e. "x < y < z")
#    elseif head === :comparison && nargs >= 3 && (nargs&1==1)
#        comp_prec = minimum(operator_precedence, args[2:2:end])
#        if comp_prec <= prec
#            show_enclosed_list(io, '(', args, " ", ')', indent, comp_prec)
#        else
#            show_list(io, args, " ", indent, comp_prec)
#        end
#
#    # function calls need to transform the function from :call to :calldecl
#    # so that operators are printed correctly
#    elseif head === :function && nargs==2 && is_expr(args[1], :call)
#        show_block(io, head, Expr(:calldecl, args[1].args...), args[2], indent)
#        print(io, "end")
#
#    elseif head === :function && nargs == 1
#        print(io, "function ", args[1], " end")
#
#    # block with argument
#    elseif head in (:for,:while,:function,:if) && nargs==2
#        show_block(io, head, args[1], args[2], indent)
#        print(io, "end")
#
#    elseif head === :module && nargs==3 && isa(args[1],Bool)
#        show_block(io, args[1] ? :module : :baremodule, args[2], args[3], indent)
#        print(io, "end")
#
#    # type declaration
#    elseif head === :type && nargs==3
#        show_block(io, args[1] ? Symbol("mutable struct") : Symbol("struct"), args[2], args[3], indent)
#        print(io, "end")
#
#    elseif head === :bitstype && nargs == 2
#        print(io, "primitive type ")
#        show_list(io, reverse(args), ' ', indent)
#        print(io, " end")
#
#    elseif head === :abstract && nargs == 1
#        print(io, "abstract type ")
#        show_list(io, args, ' ', indent)
#        print(io, " end")
#
#    # empty return (i.e. "function f() return end")
#    elseif head === :return && nargs == 1 && args[1] === nothing
#        print(io, head)
#
#    # type annotation (i.e. "::Int")
#    elseif head === Symbol("::") && nargs == 1
#        print(io, "::")
#        show_unquoted(io, args[1], indent)
#
#    # var-arg declaration or expansion
#    # (i.e. "function f(L...) end" or "f(B...)")
#    elseif head === :(...) && nargs == 1
#        show_unquoted(io, args[1], indent)
#        print(io, "...")
#
#    elseif (nargs == 0 && head in (:break, :continue))
#        print(io, head)
#
#    elseif (nargs == 1 && head in (:return, :const)) ||
#                          head in (:local,  :global, :export)
#        print(io, head, ' ')
#        show_list(io, args, ", ", indent)
#
#    elseif head === :macrocall && nargs >= 1
#        # Use the functional syntax unless specifically designated with prec=-1
#        if prec >= 0
#            show_call(io, :call, ex.args[1], ex.args[2:end], indent)
#        else
#            show_list(io, args, ' ', indent)
#        end
#
#    elseif head === :line && 1 <= nargs <= 2
#        show_linenumber(io, args...)
#
#    elseif head === :if && nargs == 3     # if/else
#        show_block(io, "if",   args[1], args[2], indent)
#        show_block(io, "else", args[3], indent)
#        print(io, "end")
#
#    elseif head === :try && 3 <= nargs <= 4
#        show_block(io, "try", args[1], indent)
#        if is_expr(args[3], :block)
#            show_block(io, "catch", args[2] === false ? Any[] : args[2], args[3], indent)
#        end
#        if nargs >= 4 && is_expr(args[4], :block)
#            show_block(io, "finally", Any[], args[4], indent)
#        end
#        print(io, "end")
#
#    elseif head === :let && nargs >= 1
#        show_block(io, "let", args[2:end], args[1], indent); print(io, "end")
#
#    elseif head === :block || head === :body
#        show_block(io, "begin", ex, indent); print(io, "end")
#
#    elseif head === :quote && nargs == 1 && isa(args[1],Symbol)
#        show_unquoted_quote_expr(io, args[1], indent, 0)
#
#    elseif head === :gotoifnot && nargs == 2
#        print(io, "unless ")
#        show_list(io, args, " goto ", indent)
#
#    elseif head === :string && nargs == 1 && isa(args[1], AbstractString)
#        show(io, args[1])
#
#    elseif head === :null
#        print(io, "nothing")
#
#    elseif head === :kw && length(args)==2
#        show_unquoted(io, args[1], indent+indent_width)
#        print(io, '=')
#        show_unquoted(io, args[2], indent+indent_width)
#
#    elseif head === :string
#        print(io, '"')
#        for x in args
#            if !isa(x,AbstractString)
#                print(io, "\$(")
#                if isa(x,Symbol) && !(x in quoted_syms)
#                    print(io, x)
#                else
#                    show_unquoted(io, x)
#                end
#                print(io, ")")
#            else
#                escape_string(io, x, "\"\$")
#            end
#        end
#        print(io, '"')
#
#    elseif (head === :&#= || head === :$=#) && length(args) == 1
#        print(io, head)
#        a1 = args[1]
#        parens = (isa(a1,Expr) && a1.head !== :tuple) || (isa(a1,Symbol) && isoperator(a1))
#        parens && print(io, "(")
#        show_unquoted(io, a1)
#        parens && print(io, ")")
#
#    # transpose
#    elseif (head === Symbol('\'') || head === Symbol(".'")) && length(args) == 1
#        if isa(args[1], Symbol)
#            show_unquoted(io, args[1])
#        else
#            print(io, "(")
#            show_unquoted(io, args[1])
#            print(io, ")")
#        end
#        print(io, head)
#
#    # `where` syntax
#    elseif head === :where && length(args) > 1
#        parens = 1 <= prec
#        parens && print(io, "(")
#        show_unquoted(io, args[1], indent, operator_precedence(:(::)))
#        print(io, " where ")
#        if nargs == 2
#            show_unquoted(io, args[2], indent, 1)
#        else
#            print(io, "{")
#            show_list(io, args[2:end], ", ", indent)
#            print(io, "}")
#        end
#        parens && print(io, ")")
#
#    elseif head === :import || head === :importall || head === :using
#        print(io, head)
#        first = true
#        for a = args
#            if first
#                print(io, ' ')
#                first = false
#            else
#                print(io, '.')
#            end
#            if a !== :.
#                print(io, a)
#            end
#        end
#    elseif head === :meta && length(args) >= 2 && args[1] === :push_loc
#        print(io, "# meta: location ", join(args[2:end], " "))
#        show_type = false
#    elseif head === :meta && length(args) == 1 && args[1] === :pop_loc
#        print(io, "# meta: pop location")
#        show_type = false
#    # print anything else as "Expr(head, args...)"
#    else
#        show_type = false
#        if emphstate && ex.head !== :lambda && ex.head !== :method
#            io = IOContext(io, :TYPEEMPHASIZE => false)
#            emphstate = false
#        end
#        print(io, "\$(Expr(")
#        show(io, ex.head)
#        for arg in args
#            print(io, ", ")
#            show(io, arg)
#        end
#        print(io, "))")
#    end
#    show_type && show_expr_type(io, ex.typ, emphstate)
#    nothing
#end

function show_tuple_as_call(io::IO, dom::Vector{Node}, id::Int, name::Symbol, sig::Type)
    # print a method signature tuple for a lambda definition
    if sig === Tuple
        Base.print_with_color(color, io, name, "(...)")
        return
    end
    sig = unwrap_unionall(sig).parameters
    ft = sig[1]
    uw = unwrap_unionall(ft)
    nextChild(dom, io, id)
    if ft <: Function && isa(uw,DataType) && isempty(uw.parameters) &&
            isdefined(uw.name.module, uw.name.mt.name) &&
            ft == typeof(getfield(uw.name.module, uw.name.mt.name))
        print(io, uw.name.mt.name)
    elseif isa(ft, DataType) && ft.name === Type.body.name && isleaftype(ft)
        f = ft.parameters[1]
        print(io, f)
    else
        print(io, "(::", ft, ")")
    end
    first = true
    print(io, "(")
    for i = 2:length(sig)
        nextChild(dom, io, id)
        first || print(io, ", ")
        first = false
        print(io, "::", sig[i])
    end
    print(io, ")")
    nothing
end

import Base: ismodulecall

function richprint(io::IO, dom::Vector{Node}, tv::TypeVar)
    # If we are in the `unionall_env`, the type-variable is bound
    # and the type constraints are already printed.
    # We don't need to print it again.
    # Otherwise, the lower bound should be printed if it is not `Bottom`
    # and the upper bound should be printed if it is not `Any`.
    let id = startNode(dom, io, tv, "TypeVar")
        in_env = (:unionall_env => tv) in io
        function show_bound(io::IO, b::ANY)
            parens = isa(b,UnionAll) && !print_without_params(b)
            parens && print(io, "(")
            richprint(io, dom, b)
            parens && print(io, ")")
        end
        lb, ub = tv.lb, tv.ub
        if !in_env && lb !== Union{}
            if ub === Any
                write(io, tv.name)
                print(io, ">:")
                show_bound(io, lb)
            else
                show_bound(io, lb)
                print(io, "<:")
                write(io, tv.name)
            end
        else
            write(io, tv.name)
        end
        if !in_env && ub !== Any
            print(io, "<:")
            show_bound(io, ub)
        end
        endNode(dom, io, id)
    end
end

import Base: alignment, undef_ref_str, undef_ref_alignment, replace_with_centered_mark, replace_in_print_matrix
import Base: dims2string, inds2string, summary, array_eltype_show_how

"""
`richprint_matrix_repr(io, X)` prints matrix X with opening and closing square brackets.
"""
function richprint_matrix_repr(io::IO, dom::Vector{Node}, id::Int, X::AbstractArray)
    compact, prefix = array_eltype_show_how(X)
    if compact && !haskey(io, :compact)
        io = IOContext(io, :compact => compact)
    end
    indr, indc = indices(X, 1), indices(X, 2)
    nr, nc = length(indr), length(indc)
    rr1, rr2 = UnitRange{Int}(indr), 1:0
    cr1, cr2 = UnitRange{Int}(indc), 1:0
    print(io, prefix, "[")
    for rr in (rr1, rr2)
        for i in rr
            for cr in (cr1, cr2)
                for j in cr
                    nextChild(dom, io, id)
                    j > first(cr) && print(io, " ")
                    if !isassigned(X, i, j)
                        print(io, undef_ref_str)
                    else
                        el = X[i, j]
                        richprint(io, dom, el)
                    end
                end
                if last(cr) == last(indc)
                    i < last(indr) && print(io, "; ")
                end
            end
        end
    end
    print(io, "]")
end

richprint(io::IO, dom::Vector{Node}, X::AbstractArray) = richprintarray(io, dom, X)
richprint(io::IO, dom::Vector{Node}, X::AbstractVector) = richprintvector(io, dom, X)

function richprintarray(io::IO, dom::Vector{Node}, X::AbstractArray)
    N = ndims(X)
    let id = startNode(dom, io, X, "Array-$N")
        if !haskey(io, :compact)
            io = IOContext(io, :compact => true)
        end
        if !isempty(X)
            if N == 0
                if isassigned(X)
                    return richprint(io, dom, X[])
                else
                    return print(io, undef_ref_str)
                end
            end
            if N <= 2
                richprint_matrix_repr(io, dom, id, X)
            else
                tailinds = tail(tail(indices(X)))
                nd = N - 2
                for I in CartesianRange(tailinds)
                    idxs = I.I
                    slice = view(X, indices(X, 1), indices(X, 2), idxs...)
                    richprint_matrix_repr(io, dom, id, slice)
                    print(io, idxs == map(last, tailinds) ? "" : "\n\n")
                end
            end
        else
            Base.repremptyarray(io, X)
        end
        endNode(dom, io, id)
    end
end

function richprintvector(io::IO, dom::Vector{Node}, v)
    let id = startNode(dom, io, v, "Vector")
        compact, prefix = array_eltype_show_how(v)
        if compact && !haskey(io, :compact)
            io = IOContext(io, :compact => compact)
        end
        print(io, prefix)
        show_delim_array(io, dom, id, v, '[', ',', ']', false)
        endNode(dom, io, id)
    end
end
