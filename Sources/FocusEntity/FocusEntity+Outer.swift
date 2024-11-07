//
//  FocusEntity+Outer.swift
//  
//
//  Created by Dason Tiovino on 07/11/24.
//


import RealityKit

/// An extension of FocusEntity holding the methods for the "classic" style.
internal extension FocusEntity {
    
    // MARK: - Initialization
    func setupOuter(_ classicStyle: ClassicStyle) {
        //    opacity = 0.0
        /*
         The focus square consists of eight segments as follows, which can be individually animated.

             s0  s1
             _   _
         s2 |     | s3

         s4 |     | s5
             -   -
             s6  s7
         */

        let segCorners: [(Corner, Alignment)] = [
            (.topLeft, .horizontal), (.topRight, .horizontal),
            (.topLeft, .vertical), (.topRight, .vertical),
            (.bottomLeft, .vertical), (.bottomRight, .vertical),
            (.bottomLeft, .horizontal), (.bottomRight, .horizontal)
        ]
        self.segments = segCorners.enumerated().map { (index, cornerAlign) -> Segment in
            Segment(
                name: "s\(index)",
                corner: cornerAlign.0,
                alignment: cornerAlign.1,
                color: classicStyle.color
            )
        }

        let sl: Float = 0.5  // segment length
        let c: Float = FocusEntity.thickness / 2 // correction to align lines perfectly
        segments[0].position += [-(sl / 2 - c), 0, -(sl - c)]
        segments[1].position += [sl / 2 - c, 0, -(sl - c)]
        segments[2].position += [-sl, 0, -sl / 2]
        segments[3].position += [sl, 0, -sl / 2]
        segments[4].position += [-sl, 0, sl / 2]
        segments[5].position += [sl, 0, sl / 2]
        segments[6].position += [-(sl / 2 - c), 0, sl - c]
        segments[7].position += [sl / 2 - c, 0, sl - c]

        for segment in segments {
            self.positioningEntity.addChild(segment)
            segment.open()
        }

        self.positioningEntity.scale = SIMD3<Float>(repeating: FocusEntity.size * FocusEntity.scaleForClosedSquare)
    }
}
