import Foundation

enum InterpolationQuality {
 static func translucentShare(_ image:Raster) -> Double {
  var visible=0,translucent=0
  for i in stride(from:3,to:image.rgba.count,by:4) {
   let alpha=image.rgba[i]
   if alpha<13 { continue }
   visible+=1
   if alpha<242 { translucent+=1 }
  }
  return Double(translucent)/Double(max(1,visible))
 }
 static func hasGhosting(_ image:Raster,between a:Raster,and b:Raster) -> Bool {
  translucentShare(image)>max(translucentShare(a),translucentShare(b))+0.02
 }
}
