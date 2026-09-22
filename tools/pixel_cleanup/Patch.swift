import Foundation

enum PixelPatch {
 static func apply(base:Raster,edited:Raster,allows:(Int,Int)->Bool) throws -> Raster {
  guard base.width==edited.width && base.height==edited.height else { throw failure("Patch canvases must match") }
  var result=base
  for y in 0..<base.height { for x in 0..<base.width where allows(x,y) {
   let i=(y*base.width+x)*4
   for channel in 0..<4 { result.rgba[i+channel]=edited.rgba[i+channel] }
  }}
  return result
 }
}
