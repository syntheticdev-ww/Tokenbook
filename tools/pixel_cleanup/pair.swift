import Foundation

@main struct InspectPair {
 static func main() throws {
  let args=CommandLine.arguments
  guard args.count==4 else { throw failure("Usage: pair <first.png> <next.png> <new-output-folder>") }
  let output=URL(fileURLWithPath:args[3])
  guard !FileManager.default.fileExists(atPath:output.path) else { throw failure("Pair output must be new") }
  let a=try Raster(args[1]), b=try Raster(args[2])
  let forward=try DenseFlow.calculate(from:a,to:b)
  let backward=try DenseFlow.calculate(from:b,to:a)
  print("Near hand flow:",forward.at(604,739),backward.at(684,721))
  print("Near boot flow:",forward.at(530,1060),backward.at(610,1060))
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  var strip=[UInt8](repeating:0,count:5*260*260*4)
  var records=[[String:Any]]()
  var rejected=false
  for frame in 0..<5 {
   let image=DenseFlow.inbetween(a,b,forward:forward,backward:backward,t:Float(frame)/4)
   let ghost=InterpolationQuality.hasGhosting(image,between:a,and:b)
   rejected = rejected || ghost
   records.append(["frame":frame,"translucent_share":InterpolationQuality.translucentShare(image),"ghosting_rejected":ghost])
   try image.save(output.appendingPathComponent(String(format:"%02d.png",frame)).path)
   for y in 0..<260 { for x in 0..<260 {
    let src=(min(image.height-1,y*image.height/260)*image.width+min(image.width-1,x*image.width/260))*4
    let dst=(y*1300+frame*260+x)*4
    let alpha=Double(image.rgba[src+3])/255
    for c in 0..<3 { strip[dst+c]=UInt8((Double(image.rgba[src+c])*alpha+Double([238,234,221][c])*(1-alpha)).rounded()) }
    strip[dst+3]=255
   }}
   print("Pair frame",frame,"alpha area",stride(from:3,to:image.rgba.count,by:4).reduce(0.0){$0+Double(image.rgba[$1])/255})
  }
  try Raster(width:1300,height:260,rgba:strip).save(output.appendingPathComponent("contact.png").path)
  let report:[String:Any]=["source":[args[1],args[2]],"production_eligible":false,"ghosting_rejected":rejected,"visual_review_required":true,"frames":records]
  try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("qa.json"),options:.withoutOverwriting)
  print("Ghosting gate:",rejected ? "REJECTED — do not use in game":"passed screening; visual review still required")
  exit(rejected ? 2:0)
 }
}
