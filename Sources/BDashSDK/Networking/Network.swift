//
//  Network.swift
//  BDashSDK
//
//  Created by shogo.nagaoka on 2026/11/17.
//
import Network

public class Network {
    nonisolated(unsafe) public static let shared = Network()
    private let monitor = NWPathMonitor()
    init() {
        monitor.pathUpdateHandler = { _ in
        }
        let monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")
        monitor.start(queue: monitorQueue)
    }
    public func isConnectedToNetwork() -> Bool {
        return monitor.currentPath.status == .satisfied
    }
}
