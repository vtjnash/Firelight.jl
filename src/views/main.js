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
    req_response('GET', '', function(res, data) {
        editor.getDoc().setValue(data)
    })
}

function req_response(method, data, cb, errcb) {
    var options = {
        protocol: "http:",
        socketPath: server,
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
