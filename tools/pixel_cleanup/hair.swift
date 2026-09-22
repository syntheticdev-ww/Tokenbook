import Foundation
import CryptoKit

// Bake the newly authored crown into complete sprites, offline. Reuse one
// crown drawing so AI redraws cannot introduce a different bun/shape per pose.
// The game continues to draw one intact PNG; no hair layer is added at runtime.
@main struct HairCycle {
 static func main() throws {
  guard CommandLine.arguments.count==4 else { throw failure("Usage: hair <base cycle folder> <authored full-character hair master.png> <new output folder>") }
  let base=URL(fileURLWithPath:CommandLine.arguments[1]),masterURL=URL(fileURLWithPath:CommandLine.arguments[2]),output=URL(fileURLWithPath:CommandLine.arguments[3])
  guard !FileManager.default.fileExists(atPath:output.path) else { throw failure("Output must be new; preserve previous art") }
  var manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:base.appendingPathComponent("cycle.json"))) as! [String:Any]
  let originals=manifest["frames"] as! [[String:Any]],master=try Raster(masterURL.path)
  guard master.width==1254 && master.height==1254 else { throw failure("Hair master must retain the original canvas") }
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  var frames=[[String:Any]]()
  for previous in originals {
   let name=previous["file"] as! String
   guard URL(fileURLWithPath:name).lastPathComponent==name && name.hasSuffix(".png") else { throw failure("Expected a PNG basename") }
   let source=base.appendingPathComponent(name),destination=output.appendingPathComponent(name)
   let original=try Raster(source.path)
   let result=try PixelPatch.apply(base:original,edited:master){x,y in x>=530 && x<718 && y>=96 && y<265}
   try result.save(destination.path)
   func hash(_ url:URL) throws -> String { SHA256.hash(data:try Data(contentsOf:url)).map{String(format:"%02x",$0)}.joined() }
   frames.append(["file":name,"phase":previous["phase"]!,"base":name,"base_sha256":try hash(source),"sha256":try hash(destination)])
   print("Updated ponytail crown:",name)
  }
  manifest["frames"]=frames
  manifest["production_eligible"]=false
  manifest["method"]="Authored natural ponytail crown, baked into the existing intact character poses. No body, gait or runtime layer change."
  manifest["hair_master_sha256"]=SHA256.hash(data:try Data(contentsOf:masterURL)).map{String(format:"%02x",$0)}.joined()
  try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("cycle.json"),options:.withoutOverwriting)
 }
}
