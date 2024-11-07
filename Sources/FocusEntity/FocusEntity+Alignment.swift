//
//  FocusEntity.swift
//  FocusEntity
//
//  Created by Max Cobb on 8/26/19.
//  Copyright © 2019 Max Cobb. All rights reserved.
//

import RealityKit
#if canImport(ARKit)
import ARKit
#endif
import Combine

extension FocusEntity {
    
    // MARK: Helper Methods
    /// Update the position of the focus square.
    internal func updatePosition() {
        guard let arView = self.arView else { return }
        
        // Get the center point of the screen
        let centerPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // Perform the raycast
        let results = arView.raycast(from: centerPoint, allowing: .estimatedPlane, alignment: .any)
        
        var focusPosition: SIMD3<Float>
        
        if let result = results.first {
            if let cursorEntity = self.positioningEntity.children.first as? ModelEntity, var innerDotEntity = arView.scene.findEntity(named: "CursorInnerPointer") as? ModelEntity{
                
                var material = UnlitMaterial(color: .white)
                material.blending = .opaque
                innerDotEntity.model?.materials = [material]
                
                if var material = cursorEntity.model?.materials.first as? UnlitMaterial {
                    material.blending = .transparent(opacity: 1.0)
                    cursorEntity.model?.materials[0] = material
                }
            }
            // Get the camera's transform
            let cameraTransform = arView.cameraTransform
            let cameraPosition = cameraTransform.translation
            
            // Get the position of the hit test result in world space
            let hitPosition = result.worldTransform.translation
            
            // Calculate the distance from the camera to the hit point
            let direction = hitPosition - cameraPosition
            let distance = simd_length(direction)
            
            // Extract the forward vector from the camera's transform
            let forwardVector = -simd_float3(cameraTransform.matrix.columns.2.x,
                                             cameraTransform.matrix.columns.2.y,
                                             cameraTransform.matrix.columns.2.z)
            
            // Position the focus entity at fixed X and Y, dynamic Z
            focusPosition = cameraPosition + (forwardVector * distance)
            
            // Set the position
            self.position = focusPosition
            
        } else {
            // No hit result - set to default distance
            if let cursorEntity = self.positioningEntity.children.first as? ModelEntity, var innerDotEntity = arView.scene.findEntity(named: "CursorInnerPointer") as? ModelEntity{
                
                var material = UnlitMaterial(color: .white)
                material.blending = .transparent(opacity: 0.0)
                innerDotEntity.model?.materials = [material]
                
                if var material = cursorEntity.model?.materials.first as? UnlitMaterial {
                    material.blending = .transparent(opacity: 0.0)
                    cursorEntity.model?.materials[0] = material
                }
            }
            
            let defaultDistance: Float = 1.0 // Adjust this value as needed
            
            let cameraTransform = arView.cameraTransform
            let cameraPosition = cameraTransform.translation
            let forwardVector = -simd_float3(cameraTransform.matrix.columns.2.x,
                                             cameraTransform.matrix.columns.2.y,
                                             cameraTransform.matrix.columns.2.z)
            focusPosition = cameraPosition + (forwardVector * defaultDistance)
            self.position = focusPosition
        }
        
        var tempIsLocked = false
        if arView.scene.anchors.count > 5 {
            if let cursorEntity = arView.scene.findEntity(named: "CursorInnerPointer") as? ModelEntity{
                if let pointEntity = arView.scene.findEntity(named: "Point"){
                    let focusWorldPosition = self.convert(position: .zero, to: nil)
                    let pointWorldPosition = pointEntity.convert(position: .zero, to: nil)
                    
                    let focusXY = SIMD2<Float>(focusWorldPosition.x, focusWorldPosition.y)
                    let pointXY = SIMD2<Float>(pointWorldPosition.x, pointWorldPosition.y)
                    
                    let deltaXYZ = focusWorldPosition - pointWorldPosition
                    let distanceXYZ = simd_length(deltaXYZ)
                    
                    let threshold: Float = 0.05
                    
                    if distanceXYZ < threshold {
                        cursorEntity.position = pointEntity.convert(position: .zero, to: self.positioningEntity)
                        tempIsLocked = true
                    } else {
                        cursorEntity.position = SIMD3(0,0,0)
                        tempIsLocked = false
                    }
                } else {
                    cursorEntity.position = SIMD3(0,0,0)
                    tempIsLocked = false
                }
            }
        }
        
        if(tempIsLocked != self.isLocked){
            self.isLocked = tempIsLocked
            self.triggerHapticFeedback()
        }
    }
    
#if canImport(ARKit)
    /// Update the transform of the focus square to be aligned with the camera.
    internal func updateTransform(raycastResult: ARRaycastResult) {
        self.updatePosition()
        
        if state != .initializing {
            updateAlignment(for: raycastResult)
        }
    }
    
    internal func updateAlignment(for raycastResult: ARRaycastResult) {
        
        var targetAlignment = raycastResult.worldTransform.orientation
        
        // Determine current alignment
        var alignment: ARPlaneAnchor.Alignment?
        if let planeAnchor = raycastResult.anchor as? ARPlaneAnchor {
            alignment = planeAnchor.alignment
            // Catching case when looking at ceiling
            if targetAlignment.act([0, 1, 0]).y < -0.9 {
                targetAlignment *= simd_quatf(angle: .pi, axis: [0, 1, 0])
            }
        } else if raycastResult.targetAlignment == .horizontal {
            alignment = .horizontal
        } else if raycastResult.targetAlignment == .vertical {
            alignment = .vertical
        }
        
        // add to list of recent alignments
        if alignment != nil {
            self.recentFocusEntityAlignments.append(alignment!)
        }
        
        // Average using several most recent alignments.
        self.recentFocusEntityAlignments = Array(self.recentFocusEntityAlignments.suffix(20))
        
        let alignCount = self.recentFocusEntityAlignments.count
        let horizontalHistory = recentFocusEntityAlignments.filter({ $0 == .horizontal }).count
        let verticalHistory = recentFocusEntityAlignments.filter({ $0 == .vertical }).count
        
        // Alignment is same as most of the history - change it
        if alignment == .horizontal && horizontalHistory > alignCount * 3/4 ||
            alignment == .vertical && verticalHistory > alignCount / 2 ||
            raycastResult.anchor is ARPlaneAnchor {
            if alignment != self.currentAlignment ||
                (alignment == .vertical && self.shouldContinueAlignAnim(to: targetAlignment)
                ) {
                isChangingAlignment = true
                self.currentAlignment = alignment
            }
        } else {
            // Alignment is different than most of the history - ignore it
            return
        }
        
        // Change the focus entity's alignment
        if isChangingAlignment {
            // Uses interpolation.
            // Needs to be called on every frame that the animation is desired, Not just the first frame.
            performAlignmentAnimation(to: targetAlignment)
        } else {
            orientation = targetAlignment
        }
    }
#endif
    
    internal func normalize(_ angle: Float, forMinimalRotationTo ref: Float) -> Float {
        // Normalize angle in steps of 90 degrees such that the rotation to the other angle is minimal
        var normalized = angle
        while abs(normalized - ref) > .pi / 4 {
            if angle > ref {
                normalized -= .pi / 2
            } else {
                normalized += .pi / 2
            }
        }
        return normalized
    }
    
    internal func getCamVector() -> (position: SIMD3<Float>, direciton: SIMD3<Float>)? {
        guard let camTransform = self.arView?.cameraTransform else {
            return nil
        }
        let camDirection = camTransform.matrix.columns.2
        return (camTransform.translation, -[camDirection.x, camDirection.y, camDirection.z])
    }
    
#if canImport(ARKit)
    /// - Parameters:
    /// - Returns: ARRaycastResult if an existing plane geometry or an estimated plane are found, otherwise nil.
    internal func smartRaycast() -> ARRaycastResult? {
        // Perform the hit test.
        guard let (camPos, camDir) = self.getCamVector() else {
            return nil
        }
        for target in self.allowedRaycasts {
            let rcQuery = ARRaycastQuery(
                origin: camPos, direction: camDir,
                allowing: target, alignment: .any
            )
            let results = self.arView?.session.raycast(rcQuery) ?? []
            
            // Check for a result matching target
            if let result = results.first(
                where: { $0.target == target }
            ) { return result }
        }
        return nil
    }
#endif
    
    /// Uses interpolation between orientations to create a smooth `easeOut` orientation adjustment animation.
    internal func performAlignmentAnimation(to newOrientation: simd_quatf) {
        // Interpolate between current and target orientations.
        orientation = simd_slerp(orientation, newOrientation, 0.15)
        // This length creates a normalized vector (of length 1) with all 3 components being equal.
        self.isChangingAlignment = self.shouldContinueAlignAnim(to: newOrientation)
    }
    
    func shouldContinueAlignAnim(to newOrientation: simd_quatf) -> Bool {
        let testVector = simd_float3(repeating: 1 / sqrtf(3))
        let point1 = orientation.act(testVector)
        let point2 = newOrientation.act(testVector)
        let vectorsDot = simd_dot(point1, point2)
        // Stop interpolating when the rotations are close enough to each other.
        return vectorsDot < 0.999
    }
    
#if canImport(ARKit)
    /**
     Reduce visual size change with distance by scaling up when close and down when far away.
     
     These adjustments result in a scale of 1.0x for a distance of 0.7 m or less
     (estimated distance when looking at a table), and a scale of 1.2x
     for a distance 1.5 m distance (estimated distance when looking at the floor).
     */
    internal func scaleBasedOnDistance(camera: ARCamera?) -> Float {
        //        guard let camera = camera else { return 1.0 }
        //
        //        let distanceFromCamera = simd_length(self.convert(position: .zero, to: nil) - camera.transform.translation)
        //        if distanceFromCamera < 0.7 {
        //            return distanceFromCamera / 0.7
        //        } else {
        //            return 0.25 * distanceFromCamera + 0.825
        //        }
        
        guard let camera = camera else { return 1.0 }
        
        // Define scaling parameters
        let minDistance: Float = 0.2   // Minimum distance for scaling
        let maxDistance: Float = 1.5   // Maximum distance for scaling
        let minScale: Float = 1.2      // Maximum scale (when close)
        let maxScale: Float = 0.8      // Minimum scale (when far)
        
        // Calculate the distance from the camera to the focus entity
        let distanceFromCamera = simd_length(self.position - camera.transform.translation)
        
        // Clamp the distance between minDistance and maxDistance
        let clampedDistance = max(min(distanceFromCamera, maxDistance), minDistance)
        
        // Normalize the distance to a 0–1 range
        let normalizedDistance = (clampedDistance - minDistance) / (maxDistance - minDistance)
        
        // Calculate the smooth scale using a cosine function for smooth transition
        let smoothScale = minScale + (maxScale - minScale) * (1 - cos(normalizedDistance * .pi)) / 2
        
        return smoothScale
    }
#endif
}

