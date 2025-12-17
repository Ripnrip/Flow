/**
 * 🧪 Style Snapshot Generator - The Digital Paparazzi
 * 
 * "Capturing the essence of every digital resonance we have crystallized.
 * It ensures that our alchemy remains consistent across all dimensions."
 * 
 * - The Cosmic Image Archivist
 */

import XCTest
import SwiftUI
@testable import Flow

final class StyleSnapshotTests: XCTestCase {
    
    // 🌟 The sanctuary where our snapshots will be preserved
    private var snapshotDirectory: URL {
        let path = ProcessInfo.processInfo.environment["SNAPSHOT_PATH"] ?? "/Users/admin/Developer/SuperProductivityDynamicIsland/Snapshots"
        return URL(fileURLWithPath: path)
    }
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        print("📸 ✨ SNAPSHOT SANCTUARY PREPARED AT: \(snapshotDirectory.path)")
    }
    
    func testGenerateAllStyleSnapshots() {
        let allStyles = TaskStyle.allCases
        
        for style in allStyles {
            print("🎨 ✨ CAPTURING RESONANCE: \(style.rawValue)")
            
            // 🎭 Create a view for the style
            let view = StyleCard(style: style)
                .frame(width: 300, height: 250)
                .background(Color(uiColor: .systemBackground))
            
            // 📸 Render to Image
            let image = view.snapshot()
            
            // 💾 Save to disk
            let fileName = style.rawValue.replacingOccurrences(of: " ", with: "_") + ".png"
            let fileURL = snapshotDirectory.appendingPathComponent(fileName)
            
            if let data = image.pngData() {
                try? data.write(to: fileURL)
                print("🎉 ✨ SNAPSHOT CRYSTALLIZED: \(fileName)")
            }
        }
        
        print("🏁 ✨ ALL \(allStyles.count) RESONANCES ARCHIVED AT: \(snapshotDirectory.path)")
    }
}

// MARK: - 📸 Snapshot Helper

extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

