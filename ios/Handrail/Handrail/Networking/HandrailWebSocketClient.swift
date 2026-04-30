import Foundation

protocol HandrailWebSocketTask: AnyObject {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping @Sendable (Error?) -> Void)
    func receive(completionHandler: @escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void)
}

extension URLSessionWebSocketTask: HandrailWebSocketTask {}

final class HandrailWebSocketClient {
    typealias TaskFactory = (URL) -> HandrailWebSocketTask

    var onMessage: ((ServerMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private let taskFactory: TaskFactory
    private var task: HandrailWebSocketTask?
    private var machine: PairedMachine?
    private var connectionGeneration = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(taskFactory: @escaping TaskFactory = { URLSession.shared.webSocketTask(with: $0) }) {
        self.taskFactory = taskFactory
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func connect(to machine: PairedMachine) {
        self.machine = machine
        connectionGeneration += 1
        let generation = connectionGeneration
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        let url = URL(string: "ws://\(machine.host):\(machine.port)")!
        task?.cancel(with: .goingAway, reason: nil)
        let nextTask = taskFactory(url)
        task = nextTask
        nextTask.resume()
        send(.hello(token: machine.token))
        receive(on: nextTask, generation: generation)
    }

    func disconnect() {
        connectionGeneration += 1
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        onConnectionChange?(false)
    }

    func send(_ message: ClientMessage) {
        guard let currentTask = task else {
            onConnectionChange?(false)
            onMessage?(.error("Handrail is not connected to the Mac."))
            return
        }
        let generation = connectionGeneration
        do {
            let data = try encoder.encode(message)
            let text = String(decoding: data, as: UTF8.self)
            currentTask.send(.string(text)) { [weak self] error in
                guard let self, self.task === currentTask, self.connectionGeneration == generation else { return }
                guard let error else { return }
                self.onMessage?(.error(error.localizedDescription))
                self.onConnectionChange?(false)
                self.scheduleReconnect(generation: generation)
            }
        } catch {
            onMessage?(.error(error.localizedDescription))
        }
    }

    private func receive(on currentTask: HandrailWebSocketTask, generation: Int) {
        currentTask.receive { [weak self] result in
            guard let self else { return }
            guard self.task === currentTask, self.connectionGeneration == generation else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.decode(text)
                }
                self.receive(on: currentTask, generation: generation)
            case .failure:
                self.onConnectionChange?(false)
                self.scheduleReconnect(generation: generation)
            }
        }
    }

    private func decode(_ text: String) {
        do {
            let message = try decoder.decode(ServerMessage.self, from: Data(text.utf8))
            onMessage?(message)
        } catch {
            onMessage?(.error(error.localizedDescription))
        }
    }

    private func scheduleReconnect(generation: Int) {
        guard let machine else { return }
        reconnectWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.connectionGeneration == generation else { return }
            self.connect(to: machine)
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
}
