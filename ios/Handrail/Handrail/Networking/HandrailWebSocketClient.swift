import Foundation

final class HandrailWebSocketClient {
    var onMessage: ((ServerMessage) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var machine: PairedMachine?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func connect(to machine: PairedMachine) {
        self.machine = machine
        let url = URL(string: "ws://\(machine.host):\(machine.port)")!
        task?.cancel(with: .goingAway, reason: nil)
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        send(.hello(token: machine.token))
        receive()
    }

    func disconnect() {
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

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.decode(text)
                }
                self.receive()
            case .failure:
                self.onConnectionChange?(false)
                self.scheduleReconnect()
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

    private func scheduleReconnect() {
        guard let machine else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.connect(to: machine)
        }
    }
}
