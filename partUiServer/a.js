// node.js server

const http = require('http');


// connect to mediator computeNode !

global.distributedClientTextBuffer = ""; //& buffer for our distributed NAR system where we store received text which isn't terminated with \n
global.queueSentencesFromDistributed = new Array(); //& array of dictionary "objects" of received sentences , size is limited to a value which makes sense

var net = require('net');

var client = new net.Socket();
client.connect(1237, '127.0.0.1', function() {
	console.log('Connected to mediator computeNode');
	//client.write('A\r\n'); // DBG
});

client.on('data', function(data) {
	console.log('Received: ' + data);

    global.distributedClientTextBuffer += data.toString();

    if (global.distributedClientTextBuffer.indexOf("\n") >= 0) {
        var idxSplit = global.distributedClientTextBuffer.indexOf("\n");

        //console.log("");
        //console.log("");
        //console.log("");
        //console.log(idxSplit);
        //console.log("===");
        //console.log(global.distributedClientTextBuffer);

        var curMsg = global.distributedClientTextBuffer.substring(0, idxSplit);
        global.distributedClientTextBuffer = global.distributedClientTextBuffer.substring(idxSplit+1); // skip \n


        var curMsgObj = JSON.parse(curMsg); // interpret text we received from the Mediator-NetworkNode as JSON and convert to "real" object
        console.log(">>>");
        console.log(curMsg);
        console.log(curMsgObj);
        //console.log("---");
        //console.log(global.distributedClientTextBuffer);

        global.queueSentencesFromDistributed.push(curMsgObj);

        // TODO MID< limit size of global.queueSentencesFromDistributed ! >
    }

    console.log('distributedClientTextBuffer: ' +  global.distributedClientTextBuffer);
    

	//client.destroy(); // kill client after server's response
});

client.on('close', function() {
	console.log('Connection closed');
});






var qs = require('querystring');
var fs = require('fs');

http.createServer(function (request, response) {

    if (request.method === "GET") {
        var whitelistedFiles = {};
        whitelistedFiles[""] = true;
        whitelistedFiles["buttons0.css"] = true;
        whitelistedFiles["jquery-3.6.0.min.js"] = true;
        whitelistedFiles["narseseOut"] = true; // "GET" fetch for output retrieved by 'HTTP client' with polling


        var correctUrlStart = "http://localhost:8080/"; // is the correct start of the URL!
        correctUrlStart = "/"

        if(false) { // DEBUG
            console.log("GET "+request.url);
            console.log(request.url.substring(0, correctUrlStart.length));
        }

        if (request.url.substring(0, correctUrlStart.length) == correctUrlStart) {
            //console.log(request); // DBG

            var urlRem = request.url.substring(correctUrlStart.length); // remaining url

            //console.log(urlRem); // DBG

            if (whitelistedFiles[urlRem] !== undefined) { // is allowed?
                if (urlRem == "narseseOut") { // case for pulling of narsese output
                    //var payload = "";
                    // NOTANYMORE TODO< keep track of the unique id of the sentence which we have last sent to this client! >
                    //payload = "{todo:\"fill JSON response with sentences not yet transmitted to the client \"}";
                    
                    response.writeHead(200, { "Content-Type": "text/plain" });
                    
                    for(var idx=0;idx<global.queueSentencesFromDistributed.length;idx++) {
                        var iVal = global.queueSentencesFromDistributed[idx];
                        var v = JSON.stringify(iVal) + "\n";
                        //console.log("------->>>>>>>>>"); // DBG
                        //console.log(v); // DBG
                        response.write(v);
                    }
                    
                    response.end();
                }
                else {

                    var fileToRetrieve = null;
                    if (urlRem == "") {
                        fileToRetrieve = "PROTO-i0.htm"; // special case
                    }
                    else {
                        fileToRetrieve = urlRem;
                    }
    
                    var mimetype = null;
                    if (fileToRetrieve.endsWith(".htm")) {
                        mimetype = "text/html";
                    }
                    else if(fileToRetrieve.endsWith(".css")) {
                        mimetype = "text/css";
                    }
                    else if(fileToRetrieve.endsWith(".js")) {
                        mimetype = "text/javascript";
                    }
    
                    response.writeHead(200, { "Content-Type": mimetype });
                    fs.createReadStream("./PROTOhtml/"+fileToRetrieve, "UTF-8").pipe(response);
                }
            }


        }


    }
    else if (request.method == 'POST') {
        var body = '';
        request.on('data', function (data) {
            body += data;
            if (body.length > 1e5) { // ~ 100kb
                // FLOOD ATTACK OR FAULTY CLIENT, NUKE REQUEST
                request.connection.destroy();
            }
        });
        request.on('end', function () {

            //var POST = qs.parse(body);
            // use POST

            console.log('POST DATA: ', body);

            // send as message to our mediator computeNode server of the NAR

            // TODO< do propper conversion of UTF-8 string to binary array! >
            var msg2 = body+'\r\n';
            var len = msg2.length+1; // length of the transmitted message, we add one because we transfer also the type

            ///client.write(new Uint8Array([1,len >> 8,len % 256,0]));
            client.write(msg2);
        });
    }
}).listen(8080);

