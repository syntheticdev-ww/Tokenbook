import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct Raster {
 let width: Int
 let height: Int
 var rgba: [UInt8]
 init(width: Int, height: Int, rgba: [UInt8]) {
  precondition(rgba.count == width*height*4)
  self.width=width; self.height=height; self.rgba=rgba
 }
 init(_ path: String) throws {
  guard let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil),
        let image=CGImageSourceCreateImageAtIndex(source,0,nil) else { throw failure("Cannot read PNG: \(path)") }
  width=image.width; height=image.height
  var data=[UInt8](repeating:0,count:width*height*4)
  let w=width, h=height
  let ok=data.withUnsafeMutableBytes { pointer -> Bool in
   guard let context=CGContext(data:pointer.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
   context.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
   return true
  }
  guard ok else { throw failure("Cannot decode RGBA") }
  for i in stride(from:0,to:data.count,by:4) {
   let alpha=Int(data[i+3])
   if alpha>0 && alpha<255 {
    for c in 0..<3 { data[i+c]=UInt8(min(255,(Int(data[i+c])*255+alpha/2)/alpha)) }
   }
  }
  rgba=data
 }
 var cgImage: CGImage {
  let data=Data(rgba)
  return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:CGDataProvider(data:data as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
 }
 func enlarged(_ factor:Int) -> Raster {
  precondition(factor>=1)
  if factor==1 { return self }
  let w=width*factor,h=height*factor
  var pixels=[UInt8](repeating:0,count:w*h*4)
  for y in 0..<h { for x in 0..<w {
   let source=((y/factor)*width+x/factor)*4, target=(y*w+x)*4
   for c in 0..<4 { pixels[target+c]=rgba[source+c] }
  }}
  return Raster(width:w,height:h,rgba:pixels)
 }
 func crop(x:Int,y:Int,width w:Int,height h:Int) -> Raster {
  precondition(x>=0 && y>=0 && x+w<=width && y+h<=height)
  var pixels=[UInt8](repeating:0,count:w*h*4)
  for row in 0..<h {
   pixels.replaceSubrange(row*w*4..<(row+1)*w*4,with:rgba[((y+row)*width+x)*4..<((y+row)*width+x+w)*4])
  }
  return Raster(width:w,height:h,rgba:pixels)
 }
 func save(_ path: String) throws {
  guard !FileManager.default.fileExists(atPath:path) else { throw failure("Refusing to overwrite: \(path)") }
  guard let target=CGImageDestinationCreateWithURL(URL(fileURLWithPath:path) as CFURL,UTType.png.identifier as CFString,1,nil) else { throw failure("Cannot create PNG") }
  CGImageDestinationAddImage(target,cgImage,nil)
  guard CGImageDestinationFinalize(target) else { throw failure("Cannot finish PNG") }
 }
 func faceMean() throws -> SIMD3<Double> {
  guard width==1254 && height==1254 else { throw failure("Unexpected source canvas") }
  var total=SIMD3<Double>.zero, count=0.0
  for y in 410..<465 { for x in 480..<620 {
   let i=(y*width+x)*4
   if rgba[i+3]>229 && rgba[i]>224 && rgba[i+1]>158 && rgba[i+2]>76 {
    total += SIMD3(Double(rgba[i]),Double(rgba[i+1]),Double(rgba[i+2])); count += 1
   }
  }}
  guard count>100 else { throw failure("Missing face registration patch") }
  return total/count
 }
}

func failure(_ message: String) -> NSError { NSError(domain:"Tokenbook.PixelCleanup",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
