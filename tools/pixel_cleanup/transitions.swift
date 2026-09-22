import Foundation
import CryptoKit

@main struct TransitionArt {
 static func main() throws {
  guard CommandLine.arguments.count==4 else { throw failure("Usage: transitions <passing pose.png> <source folder> <new output folder>") }
  let base=try Raster(CommandLine.arguments[1]),source=URL(fileURLWithPath:CommandLine.arguments[2]),output=URL(fileURLWithPath:CommandLine.arguments[3])
  guard !FileManager.default.fileExists(atPath:output.path) else { throw failure("Output must be new") }
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  var records=[[String:Any]]()
  for name in ["idle","depart-01","depart-02"] {
   let raw=try Raster(source.appendingPathComponent(name+".png").path)
   let colored=Raster(width:raw.width,height:raw.height,rgba:SkinPalette.correct(raw.rgba,from:try raw.faceMean(),to:try base.faceMean()))
   let result=try PixelPatch.apply(base:base,edited:colored){x,y in
    if x>=540 && x<598 && y>=629 && y<667 { return false }
    return y>=480 && y<1140 && x>=380 && x<905 && !(y<560 && x>715)
   }
   let target=output.appendingPathComponent(name+".png")
   try result.save(target.path)
   records.append(["file":name+".png","sha256":SHA256.hash(data:try Data(contentsOf:target)).map{String(format:"%02x",$0)}.joined()])
   print("Prepared intact transition:",name)
  }
  try JSONSerialization.data(withJSONObject:["production_eligible":false,"frames":records],options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("transitions.json"),options:.withoutOverwriting)
 }
}
