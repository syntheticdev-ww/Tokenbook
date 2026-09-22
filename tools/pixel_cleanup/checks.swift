import Foundation

@main struct CleanupChecks {
 static func main() {
  var failed = 0
  var checked = 0
  func check(_ value: Bool, _ message: String) {
   checked += 1
   if !value { failed += 1; print("FAIL: \(message)") }
  }
  // Literal colors, not an expectation calculated by the normalizer itself.
  let source: [UInt8] = [250, 204, 160, 255, 36, 24, 20, 255, 65, 141, 132, 255, 0, 0, 0, 0]
  let corrected = SkinPalette.correct(source, from: SIMD3<Double>(250,204,160), to: SIMD3<Double>(250,200,150))
  check(Array(corrected[0..<4]) == [250,200,150,255], "a pale frame matches the reference skin ramp")
  check(Array(corrected[4..<8]) == [36,24,20,255], "palette correction does not recolor dark outlines")
  check(Array(corrected[8..<12]) == [65,141,132,255], "palette correction does not recolor the teal shirt")
  check(stride(from:3,to:source.count,by:4).allSatisfy { corrected[$0] == source[$0] }, "alpha and silhouette stay byte-identical")
  check(SkinPalette.correct(source,from:SIMD3(250,204,160),to:SIMD3(250,204,160)) == source, "the reference drawing is an exact no-op")
  check(corrected.count == source.count, "no limb or body pixels are cropped or resized")
  print("Pixel cleanup checks: \(checked), failures: \(failed)")
  exit(failed == 0 ? 0 : 1)
 }
}
