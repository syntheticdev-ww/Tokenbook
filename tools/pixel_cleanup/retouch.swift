import Foundation
import CryptoKit

// Offline paint corrections only. Each exported frame is still one full
// character image. No limb layers, rig, optical flow, or runtime compositing.
@main struct RetouchCycle {
 static func allowed(_ name:String,_ x:Int,_ y:Int) -> Bool {
  switch name {
   case "front-09": return x>=694 && x<805 && y>=550 && y<729
   case "front-10": return x>=699 && x<800 && y>=555 && y<737
   case "front-11": return x>=430 && x<544 && y>=550 && y<785
   default:
    // Preserve only the solid buckle, not the surrounding belt silhouette:
    // its right edge can be occluded by the OLD arm at another pose.
    if x>=540 && x<598 && y>=629 && y<667 { return false }
    return y>=480 && y<1140 && x>=425 && x<905 && !(y<560 && x>715)
  }
 }
 static func main() throws {
  guard CommandLine.arguments.count==4 else { throw failure("Usage: retouch <v15 base folder> <v16 source folder> <new output folder>") }
  let baseURL=URL(fileURLWithPath:CommandLine.arguments[1]),sourceURL=URL(fileURLWithPath:CommandLine.arguments[2]),output=URL(fileURLWithPath:CommandLine.arguments[3])
  guard !FileManager.default.fileExists(atPath:output.path) else { throw failure("Output must be new") }
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  var sequence=[(String,Double)]()
  for i in 0..<16 {
   sequence.append((String(format:"front-%02d",i),Double(i)))
   if i==4 { sequence.append(("front-04a",4.5)) }
   if i==10 { sequence.append(("front-10a",10+1.0/3));sequence.append(("front-10b",10+2.0/3)) }
  }
  var records=[[String:Any]]()
  for (name,phase) in sequence {
   let baseName=name=="front-04a" ? "front-04" : (name=="front-10a" || name=="front-10b" ? "front-10":name)
   let baseFile=baseURL.appendingPathComponent(baseName+".png")
   let destination=output.appendingPathComponent(name+".png")
   let correction=sourceURL.appendingPathComponent(name+".png")
   var record:[String:Any]=["file":name+".png","phase":phase,"base":baseName+".png"]
   if FileManager.default.fileExists(atPath:correction.path) {
    let original=try Raster(baseFile.path),raw=try Raster(correction.path)
    let colored=Raster(width:raw.width,height:raw.height,rgba:SkinPalette.correct(raw.rgba,from:try raw.faceMean(),to:try original.faceMean()))
    let result=try PixelPatch.apply(base:original,edited:colored){x,y in allowed(name,x,y)}
    for y in 0..<original.height { for x in 0..<original.width where !allowed(name,x,y) {
     let i=(y*original.width+x)*4
     guard result.rgba[i..<i+4]==original.rgba[i..<i+4] else { throw failure("Protected pixels changed") }
    }}
    try result.save(destination.path)
    record["edit_source"]=correction.lastPathComponent
    record["edit_sha256"]=SHA256.hash(data:try Data(contentsOf:correction)).map{String(format:"%02x",$0)}.joined()
    record["protected_pixels_exact"]=true
   } else { try FileManager.default.copyItem(at:baseFile,to:destination) }
   record["sha256"]=SHA256.hash(data:try Data(contentsOf:destination)).map{String(format:"%02x",$0)}.joined()
   records.append(record)
   print("Exported",name,"phase",phase)
  }
  let report:[String:Any]=["period_seconds":1.05,"phase_units":16,"production_eligible":false,"method":"Localized authored paint corrections with protected original pixels; no temporal blending or runtime limb assembly","frames":records]
  try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("cycle.json"),options:.withoutOverwriting)
 }
}
