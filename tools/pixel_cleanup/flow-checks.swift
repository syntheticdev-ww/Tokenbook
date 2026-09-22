import Foundation

@main struct FlowChecks {
 static func main() throws {
  var count=0, failed=0
  func check(_ ok: Bool,_ text: String) { count+=1; if !ok { failed+=1; print("FAIL: \(text)") } }
  var pixels=[UInt8](repeating:0,count:96*96*4)
  for y in 20..<60 { for x in 20..<60 {
   let i=(y*96+x)*4
   pixels[i]=UInt8(100+(x*17+y*31)%150); pixels[i+1]=UInt8(90+(x*13+y*7)%150); pixels[i+2]=170; pixels[i+3]=255
  }}
  let a=Raster(width:96,height:96,rgba:pixels)
  var moved=[UInt8](repeating:0,count:pixels.count)
  for y in 20..<60 { for x in 20..<60 { for c in 0..<4 { moved[((y+4)*96+x+8)*4+c]=pixels[(y*96+x)*4+c] } } }
  let b=Raster(width:96,height:96,rgba:moved)
  let forward=try DenseFlow.calculate(from:a,to:b)
  var xs=[Float](), ys=[Float]()
  for y in 28..<52 { for x in 28..<52 { let v=forward.at(Float(x),Float(y)); xs.append(v.x); ys.append(v.y) } }
  xs.sort(); ys.sort()
  print("Measured translation:",xs[xs.count/2],ys[ys.count/2])
  check(abs(xs[xs.count/2]-8)<1 && abs(ys[ys.count/2]-4)<1,"flow direction and pixel units follow the source-to-target translation")
  let backward=try DenseFlow.calculate(from:b,to:a)
  let middle=DenseFlow.inbetween(a,b,forward:forward,backward:backward,t:0.5)
  var total=SIMD2<Double>.zero, mass=0.0
  for y in 0..<96 { for x in 0..<96 {
   let alpha=Double(middle.rgba[(y*96+x)*4+3])/255
   total += SIMD2(Double(x),Double(y))*alpha; mass += alpha
  }}
  let center=total/max(1,mass)
  print("Midpoint center and mass:",center,mass)
  check(abs(center.x-43.5)<0.8 && abs(center.y-41.5)<0.8,"an in-between moves the whole silhouette halfway, not a dissolve between unmoved poses")
  check(abs(mass-1600)<40,"interpolation preserves opaque body volume rather than making limbs translucent")
  check(DenseFlow.inbetween(a,b,forward:forward,backward:backward,t:0).rgba==a.rgba,"the first authored endpoint is exact")
  check(DenseFlow.inbetween(a,b,forward:forward,backward:backward,t:1).rgba==b.rgba,"the last authored endpoint is exact")
  check(!InterpolationQuality.hasGhosting(a,between:a,and:b),"authored opaque silhouettes pass the ghost screen")
  var ghostPixels=a.rgba
  for i in stride(from:3,to:ghostPixels.count,by:4) { if ghostPixels[i]>0 { ghostPixels[i]=128 } }
  let ghost=Raster(width:96,height:96,rgba:ghostPixels)
  check(InterpolationQuality.hasGhosting(ghost,between:a,and:b),"faded limbs are rejected even when their centroid and timing look correct")
  print("Whole-body correspondence checks: \(count), failures: \(failed)")
  exit(failed==0 ? 0:1)
 }
}
