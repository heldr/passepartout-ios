//
//  InfrastructurePreset.swift
//  Passepartout
//
//  Created by Davide De Rosa on 8/30/18.
//  Copyright (c) 2019 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of Passepartout.
//
//  Passepartout is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Passepartout is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Passepartout.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import TunnelKit

// supports a subset of TunnelKitProvider.Configuration
// ignores new JSON keys

public struct InfrastructurePreset: Codable {
    public enum ExternalKey: String, Codable {
        case ca
        
        case client
        
        case key
        
        case wrapKeyData = "wrap.key.data"
    }
    
    public enum PresetKeys: String, CodingKey {
        case id

        case name

        case comment
        
        case configuration = "cfg"
        
        case external
    }

    public enum ConfigurationKeys: String, CodingKey {
        case endpointProtocols = "ep"

        case cipher

        case digest = "auth"

        case ca

        case clientCertificate = "client"

        case clientKey = "key"

        case compressionFraming = "frame"
        
        case compressionAlgorithm = "compression"
        
        case keepAliveSeconds = "ping"

        case renegotiatesAfterSeconds = "reneg"

        case tlsWrap = "wrap"

        case checksEKU = "eku"

        case randomizeEndpoint = "random"

        case usesPIAPatches = "pia"
    }
    
    public let id: String
    
    public let name: String
    
    public let comment: String

    public let configuration: TunnelKitProvider.Configuration
    
    public let external: [ExternalKey: String]?
    
    public func hasProtocol(_ proto: EndpointProtocol) -> Bool {
        return configuration.sessionConfiguration.endpointProtocols?.firstIndex(of: proto) != nil
    }

    public func injectExternalConfiguration(_ configuration: inout TunnelKitProvider.ConfigurationBuilder, with name: Infrastructure.Name, pool: Pool) throws {
        guard let external = external, !external.isEmpty else {
            return
        }
        
        let baseURL = name.externalURL

        var sessionBuilder = configuration.sessionConfiguration.builder()
        if let pattern = external[.ca] {
            let filename = pattern.replacingOccurrences(of: "${id}", with: pool.id)
            let caURL = baseURL.appendingPathComponent(filename)
            sessionBuilder.ca = CryptoContainer(pem: try String(contentsOf: caURL))
        }
        if let pattern = external[.wrapKeyData] {
            let filename = pattern.replacingOccurrences(of: "${id}", with: pool.id)
            let tlsKeyURL = baseURL.appendingPathComponent(filename)
            if let dummyWrap = sessionBuilder.tlsWrap {
                let file = try String(contentsOf: tlsKeyURL)
                if let staticKey = StaticKey(file: file, direction: .client) {
                    sessionBuilder.tlsWrap = SessionProxy.TLSWrap(strategy: dummyWrap.strategy, key: staticKey)
                }
            }
        }
        configuration.sessionConfiguration = sessionBuilder.build()
    }
    
    // MARK: Codable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PresetKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        comment = try container.decode(String.self, forKey: .comment)
        if let rawExternal = try container.decodeIfPresent([String: String].self, forKey: .external) {
            var remapped: [ExternalKey: String] = [:]
            for entry in rawExternal {
                guard let key = ExternalKey(rawValue: entry.key) else {
                    continue
                }
                remapped[key] = entry.value
            }
            external = remapped
        } else {
            external = nil
        }

        let cfgContainer = try container.nestedContainer(keyedBy: ConfigurationKeys.self, forKey: .configuration)

        var sessionBuilder = SessionProxy.ConfigurationBuilder()
        sessionBuilder.cipher = try cfgContainer.decode(SessionProxy.Cipher.self, forKey: .cipher)
        if let digest = try cfgContainer.decodeIfPresent(SessionProxy.Digest.self, forKey: .digest) {
            sessionBuilder.digest = digest
        }
        sessionBuilder.compressionFraming = try cfgContainer.decode(SessionProxy.CompressionFraming.self, forKey: .compressionFraming)
        sessionBuilder.compressionAlgorithm = try cfgContainer.decodeIfPresent(SessionProxy.CompressionAlgorithm.self, forKey: .compressionAlgorithm) ?? .disabled
        sessionBuilder.ca = try cfgContainer.decodeIfPresent(CryptoContainer.self, forKey: .ca)
        sessionBuilder.clientCertificate = try cfgContainer.decodeIfPresent(CryptoContainer.self, forKey: .clientCertificate)
        sessionBuilder.clientKey = try cfgContainer.decodeIfPresent(CryptoContainer.self, forKey: .clientKey)
        sessionBuilder.tlsWrap = try cfgContainer.decodeIfPresent(SessionProxy.TLSWrap.self, forKey: .tlsWrap)
        sessionBuilder.keepAliveInterval = try cfgContainer.decodeIfPresent(TimeInterval.self, forKey: .keepAliveSeconds)
        sessionBuilder.renegotiatesAfter = try cfgContainer.decodeIfPresent(TimeInterval.self, forKey: .renegotiatesAfterSeconds)
        sessionBuilder.endpointProtocols = try cfgContainer.decode([EndpointProtocol].self, forKey: .endpointProtocols)
        sessionBuilder.checksEKU = try cfgContainer.decodeIfPresent(Bool.self, forKey: .checksEKU) ?? false
        sessionBuilder.randomizeEndpoint = try cfgContainer.decodeIfPresent(Bool.self, forKey: .randomizeEndpoint) ?? false
        sessionBuilder.usesPIAPatches = try cfgContainer.decodeIfPresent(Bool.self, forKey: .usesPIAPatches) ?? false

        let builder = TunnelKitProvider.ConfigurationBuilder(sessionConfiguration: sessionBuilder.build())
        configuration = builder.build()
    }
    
    public func encode(to encoder: Encoder) throws {
        guard let ca = configuration.sessionConfiguration.ca else {
            fatalError("Could not encode nil ca")
        }
        guard let endpointProtocols = configuration.sessionConfiguration.endpointProtocols else {
            fatalError("Could not encode nil endpointProtocols")
        }

        var container = encoder.container(keyedBy: PresetKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(comment, forKey: .comment)
        try container.encodeIfPresent(external, forKey: .external)

        var cfgContainer = container.nestedContainer(keyedBy: ConfigurationKeys.self, forKey: .configuration)
        try cfgContainer.encode(configuration.sessionConfiguration.cipher, forKey: .cipher)
        try cfgContainer.encode(configuration.sessionConfiguration.digest, forKey: .digest)
        try cfgContainer.encode(configuration.sessionConfiguration.compressionFraming, forKey: .compressionFraming)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.compressionAlgorithm, forKey: .compressionAlgorithm)
        try cfgContainer.encodeIfPresent(ca, forKey: .ca)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.clientCertificate, forKey: .clientCertificate)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.clientKey, forKey: .clientKey)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.tlsWrap, forKey: .tlsWrap)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.keepAliveInterval, forKey: .keepAliveSeconds)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.renegotiatesAfter, forKey: .renegotiatesAfterSeconds)
        try cfgContainer.encode(endpointProtocols, forKey: .endpointProtocols)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.checksEKU, forKey: .checksEKU)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.randomizeEndpoint, forKey: .randomizeEndpoint)
        try cfgContainer.encodeIfPresent(configuration.sessionConfiguration.usesPIAPatches, forKey: .usesPIAPatches)
    }
}
