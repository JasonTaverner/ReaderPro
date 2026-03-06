import Foundation

/// Protocolo base para todos los eventos de dominio
/// Los eventos representan algo que ha ocurrido en el pasado
protocol DomainEvent {
    var occurredAt: Date { get }
}
