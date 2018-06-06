__precompile__()
module Firelight

# using Sockets
using Electron
using Electron: URI_file
import HTTP
import JSON
# import FunctionalCollections

"""
    @LOCAL(filespec)

Construct an absolute URI to `filespec` relative to the source file containing the macro call.
"""
macro LOCAL(filespec)
    # v0.7: base = String(__source__.file)
    #       filespec isa String && return URI_file(base, filespec) # can construct eagerly
    #       return :(URI_file($base, $(esc(filespec))))
    return :(URI_file(@__DIR__, $(esc(filespec))))
end


application() = Electron.default_application()
#let app
#    global function application()
#        if !@isdefined(app) || !app.exists
#            app = Application()
#        end
#        return app::Application
#    end
#end

function escapehtml(io::IO, bytes::AbstractVector{UInt8}, attribute::Bool=true)
    for b in bytes
        if b == UInt8('&')
            write(io, "&amp;")
        elseif b == UInt8('<')
            write(io, "&lt;")
        elseif b == UInt8('>')
            write(io, "&gt;")
        elseif attribute && b == UInt8('\'')
            write(io, "&#39;")
        elseif attribute && b == UInt8('"')
            write(io, "&quot;")
        else
            write(io, b)
        end
    end
end

Base.position(io::IOContext) = position(io.io)

include("dom.jl")

mutable struct ServerState
    key::UInt64
    content::String
    shadowdom::Vector{Node}
    reason::String
    exists::Bool
    function ServerState(key::UInt64, reason::String)
        state = new(key, "", Vector{Node}(), reason, true)
        sessions[key] = state
        return state
    end
end

global sessions = Dict{UInt64, ServerState}()

function start_server()
    process_id = getpid()
    local server_name
    id = UInt(1)
    while true
        server_name = Electron.generate_pipe_name("firelight-$process_id-$id")
        ispath(server_name) || break
        id += 1
    end
    let server = listen(server_name)
        @schedule HTTP.listen(server_name, tcpref=Ref(server)) do request::HTTP.Request
            key = tryparse(UInt64, HTTP.header(request, "Session-id", ""), 16)
            key === nothing && return HTTP.Response(400, "Session-id header missing")
            session = get(sessions, key, nothing)
            session === nothing && return HTTP.Response(410, "Session non-existant")
            return invokelatest(render, request, session)
        end
    end
    return server_name
end

function invokelatest(f, args...)
    return eval(Expr(:body, Expr(:return, Expr(:call, Core._apply, QuoteNode(f), QuoteNode(args)))))
end

function start_session()
    key = rand(UInt64)
    while haskey(sessions, key)
        key += 1
    end
    session = ServerState(key, "ans")
    return session
end

function start_session(server_name::String)
    app = application()
    session = start_session()
    keystr = hex(session.key, 16)
    w = Window(app, @LOCAL("views/main.html?session-id=$keystr&server=$(HTTP.escapeuri(server_name))"))
    return session
end

function end_session(key::UInt64)
    session = pop!(sessions, key)
    session.exists = false
    nothing
end

function render(req::HTTP.Request, session::ServerState)
    rep = req.response
    HTTP.setheader(rep, "Content-Type" => "text/plain;charset=utf-8")
    target = req.target
    if target == "/"
        rep.body = session.content
    elseif target == "/fork"
        session = start_session()
        keystr = hex(session.key, 16)
        rep.body = keystr
    elseif target == "/history"
        rep.body = session.reason
    elseif ismatch(r"/dump/(\d+)", target)
        id = tryparse(Int, match(r"/dump/(\d+)", target)[1])
        if id === nothing || id < 1 || id > length(session.shadowdom)
            return HTTP.Response(404, "Id not found in shadowdom")
        end
        rep.body = sprint(session.shadowdom[id].object) do io, r
            dump(io, r, maxdepth=1)
        end
    else
        return HTTP.Response(404)
    end
    return rep
end

end # module
