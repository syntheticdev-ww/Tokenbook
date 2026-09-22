import Foundation

enum SkinPalette {
 static func correct(_ rgba: [UInt8], from source: SIMD3<Double>, to reference: SIMD3<Double>) -> [UInt8] {
  precondition(rgba.count % 4 == 0)
  let delta = reference - source
  if delta == .zero { return rgba }
  func ramp(_ value: Double, _ low: Double, _ high: Double) -> Double {
   let t = max(0, min(1, (value-low)/(high-low)))
   return t*t*(3-2*t)
  }
  var result = rgba
  for i in stride(from:0,to:rgba.count,by:4) {
   // Preserve alpha and antialiased contours exactly. This is a small change
   // of the warm skin ramp, not histogram equalization of the entire image.
   if rgba[i+3] < 230 { continue }
   let r = Double(rgba[i]), g = Double(rgba[i+1]), b = Double(rgba[i+2])
   let weight = ramp(r,190,230)*ramp(g,115,170)*ramp(b,65,110)*ramp(r-g,15,30)*ramp(g-b,12,25)
   if weight == 0 { continue }
   for c in 0..<3 { result[i+c] = UInt8(max(0,min(255,(Double(rgba[i+c])+delta[c]*weight).rounded()))) }
  }
  return result
 }
}
