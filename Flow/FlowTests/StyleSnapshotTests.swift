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
            
            // 🎭 If it's a growing style, capture all stages
            if style == .livingGarden || style == .magicalForest {
                for level in 0...3 {
                    captureSnapshot(for: style, growthLevel: level)
                }
            } else {
                captureSnapshot(for: style, growthLevel: 0)
            }
        }
        
        print("🏁 ✨ ALL RESONANCES ARCHIVED AT: \(snapshotDirectory.path)")
    }
    
    private func captureSnapshot(for style: TaskStyle, growthLevel: Int) {
        // 🎭 Create a view for the style
        // We use a custom card that shows growth if applicable
        let view = StyleCard(style: style, growthLevel: growthLevel)
            .frame(width: 300, height: 250)
            .background(Color(uiColor: .systemBackground))
        
        // 📸 Render to Image
        let image = view.snapshot()
        
        // 💾 Save to disk
        var fileName = style.rawValue.replacingOccurrences(of: " ", with: "_")
        if style == .livingGarden || style == .magicalForest {
            fileName += "_Level_\(growthLevel)"
        }
        fileName += ".png"
        
        let fileURL = snapshotDirectory.appendingPathComponent(fileName)
        
        if let data = image.pngData() {
            try? data.write(to: fileURL)
            print("🎉 ✨ SNAPSHOT CRYSTALLIZED: \(fileName)")
        }
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

