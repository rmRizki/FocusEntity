//
//  FocusEntity+Inner.swift
//  FocusEntity
//
//  Created by Dason Tiovino on 07/11/24.
//


import RealityKit
import SceneKit

/// An extension of FocusEntity holding the methods for the "classic" style.
internal extension FocusEntity {

    func setupInner(_ classicStyle: ClassicStyle) {
        let sphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.03))
        sphere.position = SIMD3<Float>(0, 0, 0)
        sphere.model?.materials = [UnlitMaterial(color: .white)]
        sphere.name = "CursorInnerPointer"
        
        self.positioningEntity.addChild(sphere)
        self.positioningEntity.scale = SIMD3<Float>(repeating: FocusEntity.size)
    }
}
