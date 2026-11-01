import Foundation
import Network

// Registers the GitHub App that release-please runs as (.github/workflows/release.yml),
// through GitHub's App manifest flow. The browser opens a prefilled "Create GitHub App"
// page; the user clicks Create, then Install. The App's client ID goes into the variable
// RELEASE_APP_CLIENT_ID, its private key straight into the release environment's secret
// RELEASE_APP_PRIVATE_KEY: never printed, never on disk. Needs gh signed in with admin
// rights on the repository, and the release environment (release-environment.sh).
// usage: xcrun swift create-app.swift

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func log(_ message: String) {
    FileHandle.standardError.write(Data("==> \(message)\n".utf8))
}

// Runs gh; stdin carries input, so a secret never appears in an argument list.
func gh(_ args: [String], input: String? = nil) -> (status: Int32, output: String, error: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["gh"] + args
    let output = Pipe()
    let error = Pipe()
    let stdin = Pipe()
    process.standardOutput = output
    process.standardError = error
    process.standardInput = stdin
    do {
        try process.run()
    } catch {
        fail("gh does not run (\(error)); brew install gh")
    }
    stdin.fileHandleForWriting.write(Data((input ?? "").utf8))
    stdin.fileHandleForWriting.closeFile()
    let out = output.fileHandleForReading.readDataToEndOfFile()
    let err = error.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let trim = { (data: Data) in String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
    return (process.terminationStatus, trim(out), trim(err))
}

func ghOrFail(_ args: [String], input: String? = nil) -> String {
    let result = gh(args, input: input)
    guard result.status == 0 else { fail("gh \(args.prefix(2).joined(separator: " ")) failed: \(result.error)") }
    return result.output
}

let repo = ghOrFail(["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"])
let owner = String(repo.split(separator: "/")[0])
let name = String(repo.split(separator: "/")[1])
guard gh(["api", "repos/\(repo)/environments/release", "--silent"]).status == 0 else {
    fail("\(repo) has no release environment; run release-environment.sh first")
}
let newAppURL =
    ghOrFail(["api", "repos/\(repo)", "--jq", ".owner.type"]) == "Organization"
    ? "https://github.com/organizations/\(owner)/settings/apps/new"
    : "https://github.com/settings/apps/new"
let state = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()

// Only this Mac can reach the callbacks.
let parameters = NWParameters.tcp
parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
let listener: NWListener
do {
    listener = try NWListener(using: parameters)
} catch {
    fail("cannot listen on 127.0.0.1: \(error)")
}
let queue = DispatchQueue(label: "create-app")
let ready = DispatchSemaphore(value: 0)
let installed = DispatchSemaphore(value: 0)
listener.stateUpdateHandler = { state in
    switch state {
    case .ready: ready.signal()
    case .failed(let error): fail("the local callback server stopped: \(error)")
    default: break
    }
}
listener.start(queue: queue)
ready.wait()
let base = "http://127.0.0.1:\(listener.port!.rawValue)"

// Contents: release-please's changelog commits and tags; pull requests: the release PR
// and its labels. Nothing else, and no webhook.
let manifest: [String: Any] = [
    "name": "\(name)-release",
    "url": "https://github.com/\(repo)",
    "hook_attributes": ["url": "https://github.com/\(repo)", "active": false],
    "redirect_url": "\(base)/created",
    "setup_url": "\(base)/installed",
    "public": false,
    "default_permissions": ["contents": "write", "pull_requests": "write"],
    "default_events": [String](),
]
let manifestJSON: String
do {
    manifestJSON = String(
        decoding: try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys]), as: UTF8.self)
} catch {
    fail("cannot encode the App manifest: \(error)")
}

func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
}

struct App: Decodable {
    let slug: String
    let client_id: String
    let pem: String
    let html_url: String
}

// The code from the redirect is the proof; the conversion endpoint takes no token.
func convert(_ code: String) -> App {
    var request = URLRequest(url: URL(string: "https://api.github.com/app-manifests/\(code)/conversions")!)
    request.httpMethod = "POST"
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    let done = DispatchSemaphore(value: 0)
    var result: Result<Data, Error> = .failure(URLError(.unknown))
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
            result = .failure(error)
        } else if let status = (response as? HTTPURLResponse)?.statusCode, status != 201 {
            result = .failure(
                NSError(
                    domain: "HTTP \(status)", code: status,
                    userInfo: [NSLocalizedDescriptionKey: String(decoding: data ?? Data(), as: UTF8.self)]))
        } else {
            result = .success(data ?? Data())
        }
        done.signal()
    }.resume()
    done.wait()
    do {
        return try JSONDecoder().decode(App.self, from: result.get())
    } catch {
        fail("the manifest conversion failed: \(error)")
    }
}

func respond(_ connection: NWConnection, _ status: String, _ headers: String = "", body: String) {
    let response =
        "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\n\(headers)"
        + "Content-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
    connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
}

listener.newConnectionHandler = { connection in
    connection.start(queue: queue)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
        let line = String(decoding: data ?? Data(), as: UTF8.self).split(separator: "\r\n").first ?? ""
        let target = line.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
        let url = URLComponents(string: "\(base)\(target)")
        let query = { (key: String) in url?.queryItems?.first { $0.name == key }?.value }
        switch url?.path {
        case "/":
            respond(
                connection, "200 OK",
                body: """
                    <!doctype html><form method="post" action="\(newAppURL)?state=\(state)">
                    <input type="hidden" name="manifest" value="\(escapeHTML(manifestJSON))">
                    <p>Creating the release App for \(escapeHTML(repo))…</p><button>Continue to GitHub</button></form>
                    <script>document.forms[0].submit()</script>
                    """)
        case "/created":
            guard query("state") == state, let code = query("code") else {
                respond(connection, "400 Bad Request", body: "State mismatch or no code.")
                return
            }
            let app = convert(code)
            _ = ghOrFail(["variable", "set", "RELEASE_APP_CLIENT_ID", "--repo", repo, "--body", app.client_id])
            _ = ghOrFail(
                ["secret", "set", "RELEASE_APP_PRIVATE_KEY", "--env", "release", "--repo", repo], input: app.pem)
            log(
                "created \(app.html_url); stored RELEASE_APP_CLIENT_ID and the release environment's RELEASE_APP_PRIVATE_KEY"
            )
            log("now install it on \(repo) only: Only select repositories → \(name)")
            respond(
                connection, "302 Found", "Location: https://github.com/apps/\(app.slug)/installations/new\r\n",
                body: "")
        case "/installed" where query("installation_id") != nil:
            respond(connection, "200 OK", body: "Installed. Return to the terminal.")
            log("installed (installation \(query("installation_id")!))")
            installed.signal()
        default:
            respond(connection, "404 Not Found", body: "")
        }
    }
}

log("opening \(base)/ to create the App")
do {
    try Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: ["\(base)/"])
} catch {
    log("cannot open a browser (\(error)); open \(base)/ yourself")
}
guard installed.wait(timeout: .now() + 900) == .success else {
    fail("no install within 15 minutes; finish it on the App's page, under Install App")
}
