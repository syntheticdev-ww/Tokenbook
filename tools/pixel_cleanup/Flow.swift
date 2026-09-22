import Foundation
import Vision
import CoreVideo

// Offline experiment only, not a game renderer. Translation tests validate
// units and sampling; real limb occlusions must also pass Quality + visual QA.
// The current front-10 -> front-11 pair is NOT eligible for production.
struct DenseFlow {
 let width: Int
 let height: Int
 var values: [SIMD2<Float>]
 func at(_ x: Float,_ y: Float) -> SIMD2<Float> {
  let x=max(0,min(Float(width-1),x)), y=max(0,min(Float(height-1),y))
  let ix=Int(x), iy=Int(y), jx=min(width-1,ix+1), jy=min(height-1,iy+1)
  let u=x-Float(ix), v=y-Float(iy)
  return (values[iy*width+ix]*(1-u)+values[iy*width+jx]*u)*(1-v)
    + (values[jy*width+ix]*(1-u)+values[jy*width+jx]*u)*v
 }
 static func calculate(from: Raster,to: Raster,trim:Bool=true) throws -> DenseFlow {
  guard from.width==to.width && from.height==to.height else { throw failure("Flow canvases must match") }
  if trim {
   var left=from.width,top=from.height,right=0,bottom=0
   for y in 0..<from.height { for x in 0..<from.width {
    if max(from.rgba[(y*from.width+x)*4+3],to.rgba[(y*from.width+x)*4+3])<128 { continue }
    left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
   }}
   if left<=right && top<=bottom {
    left=max(0,left-48);top=max(0,top-48);right=min(from.width-1,right+48);bottom=min(from.height-1,bottom+48)
    let w=right-left+1,h=bottom-top+1
    if w<from.width || h<from.height {
     let field=try calculate(from:from.crop(x:left,y:top,width:w,height:h),to:to.crop(x:left,y:top,width:w,height:h),trim:false)
     var vectors=[SIMD2<Float>]();vectors.reserveCapacity(from.width*from.height)
     for y in 0..<from.height { for x in 0..<from.width { vectors.append(field.at(Float(x-left),Float(y-top))) }}
     return DenseFlow(width:from.width,height:from.height,values:vectors)
    }
   }
  }
  // Vision's multiscale estimator is unreliable on tiny sprite canvases.
  // Estimate on an enlarged canvas, then return vectors in source-pixel units.
  let factor=max(1,Int(ceil(512.0/Double(min(from.width,from.height)))))
  if factor>1 {
   let large=try calculate(from:from.enlarged(factor),to:to.enlarged(factor),trim:false)
   var vectors=[SIMD2<Float>](); vectors.reserveCapacity(from.width*from.height)
   for y in 0..<from.height { for x in 0..<from.width {
    vectors.append(large.at((Float(x)+0.5)*Float(factor)-0.5,(Float(y)+0.5)*Float(factor)-0.5)/Float(factor))
   }}
   return DenseFlow(width:from.width,height:from.height,values:vectors)
  }
  return try autoreleasepool {
   let request=VNGenerateOpticalFlowRequest(targetedCGImage:to.cgImage,options:[:])
   request.revision=VNGenerateOpticalFlowRequestRevision2
   request.computationAccuracy = .veryHigh
   request.outputPixelFormat=kCVPixelFormatType_TwoComponent32Float
   request.keepNetworkOutput=true
   let handler=VNImageRequestHandler(cgImage:from.cgImage,options:[:])
   try handler.perform([request])
   guard let buffer=request.results?.first?.pixelBuffer else { throw failure("Missing optical flow") }
   let w=CVPixelBufferGetWidth(buffer),h=CVPixelBufferGetHeight(buffer)
   let format=CVPixelBufferGetPixelFormatType(buffer)
   guard format==kCVPixelFormatType_TwoComponent32Float || format==kCVPixelFormatType_TwoComponent16Half else { throw failure("Unexpected optical-flow pixel format: \(format)") }
   print("Flow grid",w,h,"source",from.width,from.height)
   CVPixelBufferLockBaseAddress(buffer,.readOnly)
   defer { CVPixelBufferUnlockBaseAddress(buffer,.readOnly) }
   guard let base=CVPixelBufferGetBaseAddress(buffer) else { throw failure("Unreadable optical flow") }
   var values=[SIMD2<Float>](); values.reserveCapacity(w*h)
   let stride=CVPixelBufferGetBytesPerRow(buffer)
   for y in 0..<h {
    let row=base.advanced(by:y*stride)
    for x in 0..<w {
     let vector:SIMD2<Float>
     if format==kCVPixelFormatType_TwoComponent16Half {
      let values=row.assumingMemoryBound(to:UInt16.self)
      vector=SIMD2(Float(Float16(bitPattern:values[x*2])),Float(Float16(bitPattern:values[x*2+1])))
     } else {
      let values=row.assumingMemoryBound(to:Float.self)
      vector=SIMD2(values[x*2],values[x*2+1])
     }
     guard vector.x.isFinite && vector.y.isFinite else { throw failure("Non-finite optical flow") }
     values.append(vector)
    }
   }
   let raw=DenseFlow(width:w,height:h,values:values)
   let scale=SIMD2(Float(from.width)/Float(w),Float(from.height)/Float(h))
   var full=[SIMD2<Float>](); full.reserveCapacity(from.width*from.height)
   for y in 0..<from.height { for x in 0..<from.width {
    full.append(raw.at((Float(x)+0.5)/scale.x-0.5,(Float(y)+0.5)/scale.y-0.5)*scale)
   }}
   return DenseFlow(width:from.width,height:from.height,values:full)
  }
 }
 static func inbetween(_ a: Raster,_ b: Raster,forward: DenseFlow,backward: DenseFlow,t: Float) -> Raster {
  if t<=0 { return a }; if t>=1 { return b }
  precondition(a.width==b.width && a.height==b.height)
  precondition(forward.width==a.width && forward.height==a.height && backward.width==b.width && backward.height==b.height)
  let left=meshWarp(a,flow:forward,amount:t),right=meshWarp(b,flow:backward,amount:1-t)
  var output=[UInt8](repeating:0,count:a.rgba.count)
  for y in 0..<a.height { for x in 0..<a.width {
   let color=left[y*a.width+x]*(1-t)+right[y*a.width+x]*t
   let i=(y*a.width+x)*4
   if color.w>0.001 {
    for c in 0..<3 { output[i+c]=UInt8(max(0,min(255,(color[c]/color.w*255).rounded()))) }
    output[i+3]=UInt8(max(0,min(255,(color.w*255).rounded())))
   }
  }}
  return Raster(width:a.width,height:a.height,rgba:output)
 }
 private static func meshWarp(_ image:Raster,flow:DenseFlow,amount:Float) -> [SIMD4<Float>] {
  var output=[SIMD4<Float>](repeating:.zero,count:image.width*image.height)
  let step=4
  func mapped(_ p:SIMD2<Float>) -> SIMD2<Float> { p+flow.at(p.x,p.y)*amount }
  func cross(_ a:SIMD2<Float>,_ b:SIMD2<Float>) -> Float { a.x*b.y-a.y*b.x }
  func triangle(_ a:SIMD2<Float>,_ b:SIMD2<Float>,_ c:SIMD2<Float>) {
   let p=mapped(a),q=mapped(b),r=mapped(c),den=cross(q-p,r-p)
   if den<=0.0001 { return }
   let minX=max(0,Int(floor(min(p.x,min(q.x,r.x))))),maxX=min(image.width-1,Int(ceil(max(p.x,max(q.x,r.x)))))
   let minY=max(0,Int(floor(min(p.y,min(q.y,r.y))))),maxY=min(image.height-1,Int(ceil(max(p.y,max(q.y,r.y)))))
   if minX>maxX || minY>maxY { return }
   for y in minY...maxY { for x in minX...maxX {
    let at=SIMD2(Float(x),Float(y))-p
    let u=cross(at,r-p)/den,v=cross(q-p,at)/den
    if u < -0.0001 || v < -0.0001 || u+v>1.0001 { continue }
    let color=sample(image,a*(1-u-v)+b*u+c*v)
    let i=y*image.width+x
    if color.w>=output[i].w { output[i]=color }
   }}
  }
  for y in stride(from:0,to:image.height-1,by:step) { for x in stride(from:0,to:image.width-1,by:step) {
   let a=SIMD2(Float(x),Float(y)),b=SIMD2(Float(min(image.width-1,x+step)),Float(y))
   let c=SIMD2(b.x,Float(min(image.height-1,y+step))),d=SIMD2(a.x,c.y)
   triangle(a,b,c); triangle(a,c,d)
  }}
  return output
 }
 // Interpolate premultiplied color so transparent margins cannot tint the skin.
 private static func sample(_ image:Raster,_ p:SIMD2<Float>) -> SIMD4<Float> {
  let ix=Int(floor(p.x)), iy=Int(floor(p.y)), u=p.x-Float(ix), v=p.y-Float(iy)
  func pixel(_ x:Int,_ y:Int) -> SIMD4<Float> {
   guard x>=0 && y>=0 && x<image.width && y<image.height else { return .zero }
   let i=(y*image.width+x)*4, alpha=Float(image.rgba[i+3])/255
   return SIMD4(Float(image.rgba[i])/255*alpha,Float(image.rgba[i+1])/255*alpha,Float(image.rgba[i+2])/255*alpha,alpha)
  }
  return (pixel(ix,iy)*(1-u)+pixel(ix+1,iy)*u)*(1-v)
    + (pixel(ix,iy+1)*(1-u)+pixel(ix+1,iy+1)*u)*v
 }
}
