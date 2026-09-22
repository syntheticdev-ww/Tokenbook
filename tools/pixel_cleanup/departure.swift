import Foundation
import CryptoKit

// Offline-only preservation: bake authored first-step legs into whole PNGs.
// Runtime still draws one intact sprite; no limb rig or image morphing.
@main struct DepartureArt {
 static func hash(_ url:URL) throws -> String {
  SHA256.hash(data:try Data(contentsOf:url)).map{String(format:"%02x",$0)}.joined()
 }
 static func main() throws {
  guard CommandLine.arguments.count==3 else { throw failure("Usage: departure <game folder> <new art folder containing source>") }
  let game=URL(fileURLWithPath:CommandLine.arguments[1]),root=URL(fileURLWithPath:CommandLine.arguments[2])
  let output=root.appendingPathComponent("frames")
  guard !FileManager.default.fileExists(atPath:output.path) else { throw failure("Output must be new") }
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  var manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:game.appendingPathComponent("assets/art/gardener-v19/character.json"))) as! [String:Any]
  let transition=manifest["transition"] as! [[String:Any]]
  var departure=[transition[0]]
  for i in 1...3 {
   let name=String(format:"depart-%02d.png",i)
   let old=try Raster(game.appendingPathComponent((transition[i]["file"] as! String).replacingOccurrences(of:"res://",with:"")).path)
   let raw=try Raster(root.appendingPathComponent("source/"+name).path)
   let colored=Raster(width:raw.width,height:raw.height,rgba:SkinPalette.correct(raw.rgba,from:try raw.faceMean(),to:try old.faceMean()))
   let result=try PixelPatch.apply(base:old,edited:colored){_,y in y>=768}
   let target=output.appendingPathComponent(name)
   try result.save(target.path)
   var row=transition[i]
   row["file"]="res://assets/art/"+root.lastPathComponent+"/frames/"+name
   row["sha256"]=try hash(target)
   departure.append(row)
  }
  departure.append(transition.last!)
  manifest["departure"]=departure
  try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("character.json"),options:.withoutOverwriting)
  print("Prepared three departure drawings; all walk/stop entries and upper-body pixels preserved")
 }
}
