import Foundation

private final class CoachResponseProtocol: URLProtocol {
    static let listID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let lock = NSLock()
    private static var requests = 0
    private static var partial = false

    static var requestCount: Int { lock.lock(); defer { lock.unlock() }; return requests }
    static func configure(partial: Bool) {
        lock.lock(); defer { lock.unlock() }
        requests = 0
        self.partial = partial
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        Self.lock.lock()
        Self.requests += 1
        let partial = Self.partial
        Self.lock.unlock()
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        let input = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let prompt = (input?["messages"] as? [[String: String]])?.first?["content"] ?? ""
        let listID = Self.listID.uuidString
        let value: Any
        if prompt.contains("\"pillars\"") {
            value = partial ? [:] : [["listId": listID, "pillars": [[
                "id": UUID().uuidString, "name": "Learning", "emoji": "📖", "score": 70,
                "status": "Developing", "insight": "Read regularly", "tasks": ["Read"], "advice": "Keep reading"
            ]], "overallInsight": "Keep your learning routine", "criticalPillar": "Learning"]]
        } else if prompt.contains("\"flags\"") {
            value = [["listId": listID, "flags": []]]
        } else {
            value = [["listId": listID, "headline": "Keep going", "summary": "A steady week", "highlight": "Reading",
                      "nudge": "Start small", "grade": "B", "gradeReason": "Consistent effort"]]
        }
        let content = String(data: try! JSONSerialization.data(withJSONObject: value), encoding: .utf8)!
        let response = try! JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]]])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response)
        client?.urlProtocolDidFinishLoading(self)
    }
}

@main
struct AICoachCacheTests {
    @MainActor
    static func main() async {
        let suite = "sortyd.coach-cache-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("en", forKey: "sortyd_app_language")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CoachResponseProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let coach = AICoach(defaults: defaults, session: session)
        let task = SortydTask(title: "Read", isCompleted: true, weight: 1)
        let list = TaskList(id: CoachResponseProtocol.listID, name: "Learning", tasks: [task])
        let snapshots = [DailySnapshot(date: ReminderPolicy.dayStart(Date()), listID: list.id, completionFraction: 0, completedTaskIDs: [])]
        CoachResponseProtocol.configure(partial: false)
        async let first: Void = coach.fetchAllListsBatch(lists: [list], snapshots: snapshots)
        async let second: Void = coach.fetchAllListsBatch(lists: [list], snapshots: snapshots)
        _ = await (first, second)
        precondition(CoachResponseProtocol.requestCount == 3, "Concurrent screens must share one batch")
        precondition(coach.loadBestAvailableCache(for: list.id) == (true, false))
        await coach.fetchAllListsBatch(lists: [list], snapshots: snapshots)
        precondition(CoachResponseProtocol.requestCount == 3, "A complete daily result must avoid more network requests")

        defaults.set("ar", forKey: "sortyd_app_language")
        precondition(!coach.loadBestAvailableCache(for: list.id).found, "Another language must not reuse English analysis")
        CoachResponseProtocol.configure(partial: true)
        await coach.fetchAllListsBatch(lists: [list], snapshots: snapshots)
        precondition(!coach.loadBestAvailableCache(for: list.id).found, "A recap alone is not a working coach")
        await coach.fetchAllListsBatch(lists: [list], snapshots: snapshots)
        precondition(CoachResponseProtocol.requestCount == 6, "Partial results must remain retryable")
        CoachResponseProtocol.configure(partial: false)
        await coach.fetchAllListsBatch(lists: [list], snapshots: snapshots)
        precondition(coach.loadBestAvailableCache(for: list.id) == (true, false))
        defaults.set("en", forKey: "sortyd_app_language")
        precondition(coach.loadBestAvailableCache(for: list.id) == (true, false), "Returning to English should recover its cache")
        print("Coach request coalescing, daily reuse, language isolation and partial failure recovery passed")
    }
}
