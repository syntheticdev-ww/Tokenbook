import Foundation
import CryptoKit

// Bake two authored gait corrections into intact sprites. Never change
// registered head/torso/arm pixels or the existing nineteen-pose timing.
@main struct Legs {
 static func hash(_ url:URL) throws -> String { SHA256.hash(data:try Data(contentsOf:url)).map{String(format:"%02x",$0)}.joined() }
 static func main() throws {
  guard CommandLine.arguments.count==4 else { throw failure("Usage: legs <v17 frame folder> <v18 character.json> <new v19 art folder with source images>") }
  let base=URL(fileURLWithPath:CommandLine.arguments[1]),manifestURL=URL(fileURLWithPath:CommandLine.arguments[2]),root=URL(fileURLWithPath:CommandLine.arguments[3]),output=root.appendingPathComponent("frames")
  guard !FileManager.default.fileExists(atPath:output.path) else { throw failure("Output must be new") }
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  var cycle=try JSONSerialization.jsonObject(with:Data(contentsOf:base.appendingPathComponent("cycle.json"))) as! [String:Any]
  var rows=cycle["frames"] as! [[String:Any]]
  var manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:manifestURL)) as! [String:Any]
  var walk=manifest["walk"] as! [[String:Any]]
  for i in rows.indices {
   let name=rows[i]["file"] as! String,original=base.appendingPathComponent(name),target=output.appendingPathComponent(name)
   if ["front-10a.png","front-10b.png"].contains(name) {
    let old=try Raster(original.path),raw=try Raster(root.appendingPathComponent("source").appendingPathComponent(name).path)
    let colored=Raster(width:raw.width,height:raw.height,rgba:SkinPalette.correct(raw.rgba,from:try raw.faceMean(),to:try old.faceMean()))
    // Include the bottom hem: a horizontal cut through the thighs at y780
    // creates a notch when the new bent leg crosses the old silhouette.
    // Hands finish above this line; their authored swing stays untouched.
    let result=try PixelPatch.apply(base:old,edited:colored){x,y in y>=768}
    try result.save(target.path)
    rows[i]["base_sha256"]=try hash(original)
    rows[i]["sha256"]=try hash(target)
    walk[i]["file"]="res://assets/art/gardener-v19/frames/"+name
    walk[i]["sha256"]=try hash(target)
   } else { try FileManager.default.copyItem(at:original,to:target) }
  }
  cycle["frames"]=rows
  cycle["method"]="Two authored lower-body passing corrections; all upper-body pixels and gait timing preserved."
  manifest["walk"]=walk
  try JSONSerialization.data(withJSONObject:cycle,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("cycle.json"),options:.withoutOverwriting)
  try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("character.json"),options:.withoutOverwriting)
  print("Prepared two passing corrections; original nineteen-frame timing and all upper-body anchors retained")
 }
}
