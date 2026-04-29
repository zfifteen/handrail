import Foundation

final class HandrailWebSocketClient {
    var onMessage: ((ServerMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var machine: PairedMachine?
    private var connectionGeneration = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
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
        let nextTask = URLSession.shared.webSocketTask(with: url)
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
        guard let task else {
            onMessage?(.error("Handrail is not connected to the Mac."))
            return
        }
        do {
            let data = try encoder.encode(message)
            let text = String(decoding: data, as: UTF8.self)
            task.send(.string(text)) { [weak self] error in
                if let error {
                    self?.onMessage?(.error(error.localizedDescription))
                }
            }
        } catch {
            onMessage?(.error(error.localizedDescription))
        }
    }

    private func receive(on currentTask: URLSessionWebSocketTask, generation: Int) {
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
