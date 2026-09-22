import Foundation

// Finalize authored cels with the established protected-pixel pipeline.
@main struct SmoothWalk {
 static func main() throws {
  guard [3,4].contains(CommandLine.arguments.count) else { throw failure("Usage: smooth-walk <game folder> <new output frames folder> [art version]") }
  let game=URL(fileURLWithPath:CommandLine.arguments[1]),out=URL(fileURLWithPath:CommandLine.arguments[2])
  guard !FileManager.default.fileExists(atPath:out.path) else { throw failure("Output must be new") }
  try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
  let version=CommandLine.arguments.count==4 ? CommandLine.arguments[3] : "gardener-v22"
  let root=game.appendingPathComponent("assets/art/"+version)
  let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("candidates.json"))) as! [[String:Any]]
  for row in rows {
   let base=try Raster(game.appendingPathComponent((row["parent_file"] as! String).replacingOccurrences(of:"res://",with:"")).path)
   let raw=try Raster(root.appendingPathComponent(row["source"] as! String).path)
   let colored=Raster(width:raw.width,height:raw.height,rgba:SkinPalette.correct(raw.rgba,from:try raw.faceMean(),to:try base.faceMean()))
   let legsOnly=row["mode"] as! String == "legs"
   let frame=try PixelPatch.apply(base:base,edited:colored) { x,y in
    if legsOnly { return y>=768 }
    return y>=480 && !(y<550 && (x<475 || x>745))
   }
   try frame.save(out.appendingPathComponent(URL(fileURLWithPath:row["file"] as! String).lastPathComponent).path)
  }
  print("Finalized \(rows.count) targeted whole-character cels")
 }
}
