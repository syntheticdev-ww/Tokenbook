import Foundation

// Finalize image_gen-authored poses using the project's existing protected
// pixel/palette pipeline. No optical flow, limb rescaling or runtime layers.
@main struct DenseWalk {
 static func main() throws {
  guard CommandLine.arguments.count==3 else { throw failure("Usage: dense-walk <game folder> <new output frames folder>") }
  let game=URL(fileURLWithPath:CommandLine.arguments[1]),out=URL(fileURLWithPath:CommandLine.arguments[2])
  guard !FileManager.default.fileExists(atPath:out.path) else { throw failure("Output must be new") }
  try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
  let root=game.appendingPathComponent("assets/art/gardener-v21")
  let candidates=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("candidates.json"))) as! [[String:Any]]
  let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:game.appendingPathComponent("assets/art/gardener-v20/character.json"))) as! [String:Any]
  let walk=manifest["walk"] as! [[String:Any]]
  // These intervals only make small arm changes. Preserve the corresponding
  // previous whole upper body instead of introducing unrelated redraw noise.
  let legsOnly:Set<Int>=[0,1,2,4,7,8,9,13,14,15]
  for row in candidates {
   let phase=(row["phase"] as! NSNumber).doubleValue,n=Int(phase)
   let reference=walk.last{($0["phase"] as! NSNumber).doubleValue<=phase}!
   let base=try Raster(game.appendingPathComponent((reference["file"] as! String).replacingOccurrences(of:"res://",with:"")).path)
   let name=URL(fileURLWithPath:row["file"] as! String).lastPathComponent
   let raw=try Raster(root.appendingPathComponent("source/"+name).path)
   let colored=Raster(width:raw.width,height:raw.height,rgba:SkinPalette.correct(raw.rgba,from:try raw.faceMean(),to:try base.faceMean()))
   let frame=try PixelPatch.apply(base:base,edited:colored) { x,y in
    if legsOnly.contains(n) { return y>=768 }
    if [3,11,12].contains(n) && y<768 && x>510 && x<640 { return false }
    // Keep the entire head, including the lower ponytail outside the shoulder.
    return y>=480 && !(y<550 && (x<475 || x>745))
   }
   try frame.save(out.appendingPathComponent(name).path)
  }
  print("Finalized \(candidates.count) authored in-betweens with protected identity and stable skin palette")
 }
}
