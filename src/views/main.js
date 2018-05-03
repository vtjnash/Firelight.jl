const http = require('http')

arguments = new URLSearchParams(document.location.search)
session = arguments.get("session-id")
server = arguments.get("server")

window.onload = function() {
    var editor = CodeMirror(document.getElementById("editor"), {
      value: "",
      mode:  "julia",
      lineNumbers: true,
      lineWrapping: true,
    })
    var viewer = document.getElementById("viewer")
    req_response('GET', '/', '', function(res, data) {
        editor.getDoc().setValue(data)
        viewer.innerHTML = data
    })

    var current_highlight;
    viewer.onclick = function(evt) {
        if (current_highlight !== undefined)
            current_highlight.classList.remove("highlight")
        // find the click target
        var target = evt.target
        while (!target.id.match(/n-\d+/)) {
            target = target.parentNode
            if (target === viewer)
                return
        }
        var id = target.id.substring(2, target.id.length)
        current_highlight = target
        // now style it
        current_highlight.classList.add("highlight")
        req_response('GET', `/dump/${id}`, '', function(res, data) {
            editor.getDoc().setValue(data)
        })
        while (target !== viewer) {
            if (target.id.match(/n-\d+/)) {
                console.log(target.classList[0]);
            }
            target = target.parentNode
        }
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
