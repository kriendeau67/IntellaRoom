//
//  RealityKitMeshExporter.swift
//  IntellaRoom
//
//  Created by Kenneth Riendeau on 12/24/25.
//

import RealityKit
import ARKit

extension MeshResource {

    static func from(meshAnchors: [ARMeshAnchor]) throws -> MeshResource {
        var descriptors: [MeshDescriptor] = []

        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let vertices = geometry.vertices
            let faces = geometry.faces

            var desc = MeshDescriptor()

            // --- Positions ---
            var positions: [SIMD3<Float>] = []
            positions.reserveCapacity(vertices.count)

            let vBuffer = vertices.buffer.contents()
            for i in 0..<vertices.count {
                let offset = vertices.offset + i * vertices.stride
                let ptr = vBuffer.advanced(by: offset)
                    .bindMemory(to: Float.self, capacity: 3)
                positions.append(SIMD3(ptr[0], ptr[1], ptr[2]))
            }

            desc.positions = .init(positions)

            // --- Indices ---
            let indexCount = faces.count * 3
            let iBuffer = faces.buffer.contents()

            if faces.bytesPerIndex == 2 {
                let ptr = iBuffer.bindMemory(to: UInt16.self, capacity: indexCount)
                desc.primitives = .triangles(
                    (0..<indexCount).map { UInt32(ptr[$0]) }
                )
            } else {
                let ptr = iBuffer.bindMemory(to: UInt32.self, capacity: indexCount)
                desc.primitives = .triangles(
                    (0..<indexCount).map { ptr[$0] }
                )
            }

            descriptors.append(desc)
        }

        return try MeshResource.generate(from: descriptors)
    }
}
