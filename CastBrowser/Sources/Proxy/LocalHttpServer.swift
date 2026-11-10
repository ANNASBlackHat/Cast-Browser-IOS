//
//  LocalHttpServer.swift
//  CastBrowser
//

import Foundation
import Network

public actor LocalHttpServer {
    public static let shared = LocalHttpServer()

    private var listener: NWListener?
    private var isRunning: Bool = false
    private let port: UInt16 = 8888
    private let urlSession = URLSession.shared

    private init() {}

    public func start() async {
        guard !isRunning else { return }

        do {
            let parameters = NWParameters.tcp
            self.listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            await ProxyStreamManager.shared.setProxyPort(port)

            listener?.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task {
                    await self.handleConnection(connection)
                }
            }

            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[LocalHttpServer] Running on port \(self.port)")
                case .failed(let error):
                    print("[LocalHttpServer] Failed with error: \(error)")
                default:
                    break
                }
            }

            listener?.start(queue: .global(qos: .userInitiated))
            self.isRunning = true
        } catch {
            print("[LocalHttpServer] Could not start server: \(error)")
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 4, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil,
                  let requestText = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            Task {
                await self.processHttpRequest(requestText, connection: connection)
            }
        }
    }

    private func processHttpRequest(_ requestText: String, connection: NWConnection) async {
        let lines = requestText.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, status: "400 Bad Request", body: Data())
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: "400 Bad Request", body: Data())
            return
        }

        let method = parts[0]
        let path = parts[1]

        // Parse path: /stream/{token}/master.m3u8 OR /segment/{token}?upstream={url}
        if path.contains("/stream/") {
            await handleMasterPlaylistRequest(path: path, connection: connection)
        } else if path.contains("/segment/") {
            await handleSegmentRequest(path: path, connection: connection)
        } else {
            sendResponse(connection: connection, status: "404 Not Found", body: "Unknown endpoint".data(using: .utf8)!)
        }
    }

    private func handleMasterPlaylistRequest(path: String, connection: NWConnection) async {
        // Extract token
        let components = path.components(separatedBy: "/")
        guard components.count >= 3 else {
            sendResponse(connection: connection, status: "404 Not Found", body: Data())
            return
        }
        let token = components[2]

        guard let session = await ProxyStreamManager.shared.getSession(token: token) else {
            sendResponse(connection: connection, status: "404 Session Not Found", body: Data())
            return
        }

        var request = URLRequest(url: session.originalUrl)
        if let referer = session.referer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
        request.setValue(session.userAgent, forHTTPHeaderField: "User-Agent")
        if let cookies = session.cookies {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let content = String(data: data, encoding: .utf8) else {
                sendResponse(connection: connection, status: "502 Bad Gateway", body: Data())
                return
            }

            let localIp = NetworkIpHelper.getLocalIpAddress() ?? "127.0.0.1"
            let proxyBase = URL(string: "http://\(localIp):\(port)")!
            let rewritten = HlsPlaylistRewriter.rewrite(
                playlistContent: content,
                originalBaseUrl: session.originalUrl,
                proxyEndpointBase: proxyBase,
                sessionToken: token
            )

            sendResponse(
                connection: connection,
                status: "200 OK",
                contentType: "application/vnd.apple.mpegurl",
                body: rewritten.data(using: .utf8) ?? data
            )
        } catch {
            sendResponse(connection: connection, status: "500 Internal Error", body: Data())
        }
    }

    private func handleSegmentRequest(path: String, connection: NWConnection) async {
        guard let urlComponents = URLComponents(string: "http://localhost\(path)"),
              let upstreamStr = urlComponents.queryItems?.first(where: { $0.name == "upstream" })?.value,
              let upstreamUrl = URL(string: upstreamStr) else {
            sendResponse(connection: connection, status: "400 Missing Upstream", body: Data())
            return
        }

        // Extract token
        let pathParts = urlComponents.path.components(separatedBy: "/")
        let token = pathParts.count >= 3 ? pathParts[2] : ""
        let session = await ProxyStreamManager.shared.getSession(token: token)

        var request = URLRequest(url: upstreamUrl)
        if let referer = session?.referer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
        if let userAgent = session?.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        if let cookies = session?.cookies {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)
            let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? "video/MP2T"
            sendResponse(
                connection: connection,
                status: "200 OK",
                contentType: contentType,
                body: data
            )
        } catch {
            sendResponse(connection: connection, status: "502 Bad Gateway", body: Data())
        }
    }

    private func sendResponse(
        connection: NWConnection,
        status: String,
        contentType: String = "text/plain",
        body: Data
    ) {
        let headers = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, HEAD, OPTIONS\r
        Connection: close\r
        \r\n
        """

        var fullData = headers.data(using: .utf8) ?? Data()
        fullData.append(body)

        connection.send(content: fullData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
