const http = require('http')

arguments = new URLSearchParams(document.location.search)
session = arguments.get("session-id")
server = arguments.get("server")

window.onload = function() {
    var editor = document.getElementById("editor");
    //editor.setAttribute('display', 'none')
    //editor = CodeMirror(editor, {
    //  value: "",
    //  mode:  "julia",
    //  lineNumbers: true,
    //  lineWrapping: true,
    //})
    var viewer = document.getElementById("viewer")
    req_response('GET', '/', '', function(res, data) {
        viewer.innerHTML = data
    })

    function refresh_history() {
        req_response('GET', '/reason', '', function(res, data) {
            var history = document.getElementById("history")
            history.innerHTML = `<ol><li>${data}</li></ol>`
        })
    }
    refresh_history()

    var current_highlight;
    viewer.onclick = function(evt) {
        if (current_highlight !== undefined)
            current_highlight.classList.remove("highlight")
        current_highlight = undefined
        // find the click target
        var target = evt.target
        while (target.id === undefined || !target.id.match(/n-\d+/)) {
            if (target === viewer)
                return
            target = target.parentNode
        }
        var detail = document.getElementById("detail")
        detail.innerText = ""
        var id = target.id.substring(2, target.id.length)
        current_highlight = target
        // now style it
        current_highlight.classList.add("highlight")
        req_response('GET', `/dump/${id}`, '', function(res, data) {
            detail.innerText = data;
        })
        var parents = []
        while (target !== viewer) {
            if (target.id !== undefined && target.id.match(/n-\d+/)) {
                parents.push(target.classList[0])
            }
            target = target.parentNode
        }
        console.log(parents)
    }
}

function req_response(method, path, data, cb, errcb) {
    var options = {
        protocol: "http:",
        socketPath: server,
        path: path,
        method: method,
        headers: {
            'Content-Type': 'text/plain',
            'Connection': 'keep-alive',
            // 'Content-Length': Buffer.byteLength(data),
            'Session-id': session,
        }
    }
    var req = http.request(options, function(res) {
        if (!errcb) {
            errcb = function(e, msg) {
                if (!(msg instanceof String)) {
                    if (msg instanceof Error) {
                        msg = msg.message
                    } else {
                        msg = msg.toString()
                    }
                }
                console.log(`ERROR: status: ${res.statusCode}, data: ${msg}`)
            }
        }
        var chunks = [];
        res.on('data', function(chunk) {
            chunks.push(chunk);
        });
        res.on('end', () => {
            data = chunks.toString('utf8')
            if (res.statusCode == 200)
                cb(res, data)
            else
                errcb(res, data)
        })
        res.on('error', (e) => {
            errcb(res, e)
        })
    })
    if (data)
        req.write(data);
    req.end();
}
