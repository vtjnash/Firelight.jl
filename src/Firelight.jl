__precompile__()
module Firelight

using Electron
import HTTP
import JSON

application() = Electron.default_application()
#let app
#    global function application()
#        if !@isdefined(app) || !app.exists
#            app = Application()
#        end
#        return app::Application
#    end
#end

mutable struct ServerState
    key::UInt64
    content::String
    exists::Bool
    function ServerState(key::UInt64)
        state = new(key, "", true)
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
            isnull(key) && return HTTP.Response(400, "Session-id header missing")
            key = get(key)
            session = get(sessions, key, nothing)
            session === nothing && return HTTP.Response(410, "Session non-existant")
            return invokelatest(render, request, session)
        end
    end
    return server_name
end

function start_session(server_name::String)
    app = application()
    key = rand(UInt64)
    while haskey(sessions, key)
        key += 1
    end
    keystr = hex(key, 16)
    session = ServerState(key)
    session.content = "Hello World!"
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
    rep.body = session.content
    return rep
end

end # module
