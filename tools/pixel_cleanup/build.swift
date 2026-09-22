import Foundation
import CryptoKit

@main struct BuildCleanedCycle {
 static func main() throws {
  let args=CommandLine.arguments
  guard args.count==3 else { throw failure("Usage: cleanup <v14 source folder> <new output folder>") }
  let source=URL(fileURLWithPath:args[1]).standardizedFileURL
  let output=URL(fileURLWithPath:args[2]).standardizedFileURL
  guard !FileManager.default.fileExists(atPath:output.path) else { throw failure("Output must be new; original art is never overwritten") }
  let data=try Data(contentsOf:source.appendingPathComponent("provenance.json"))
  let provenance=try JSONSerialization.jsonObject(with:data) as! [String:Any]
  let assets=provenance["assets"] as! [[String:Any]]
  let selected=assets.filter { $0["selected_for_internal_inspection"] as? Bool == true }.sorted { ($0["asset"] as! String)<($1["asset"] as! String) }
  guard selected.count==16 else { throw failure("Expected sixteen selected whole-body key drawings") }
  let reference=try Raster(source.appendingPathComponent("front-00.png").path).faceMean()
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  var records=[[String:Any]]()
  for (index,record) in selected.enumerated() {
   let name=record["asset"] as! String
   let input=source.appendingPathComponent(name)
   let raw=try Data(contentsOf:input)
   let digest=SHA256.hash(data:raw).map { String(format:"%02x",$0) }.joined()
   guard digest==record["sha256"] as? String else { throw failure("Source hash changed: \(name)") }
   let image=try Raster(input.path)
   let mean=try image.faceMean()
   let corrected=SkinPalette.correct(image.rgba,from:mean,to:reference)
   guard stride(from:3,to:corrected.count,by:4).allSatisfy({ corrected[$0]==image.rgba[$0] }) else { throw failure("Silhouette changed") }
   let target=String(format:"front-%02d.png",index)
   let result=Raster(width:image.width,height:image.height,rgba:corrected)
   try result.save(output.appendingPathComponent(target).path)
   let after=try result.faceMean()
   records.append(["file":target,"source":name,"source_sha256":digest,"face_before":[mean.x,mean.y,mean.z],"face_after":[after.x,after.y,after.z],"alpha_unchanged":true])
   print("Normalized \(index+1)/16: \(name)")
  }
  let report:[String:Any]=["method":"deterministic whole-sprite skin-ramp calibration","tool":"tools/pixel_cleanup/build.swift","date":"2026-09-19","production_eligible":false,"status":"palette_calibrated_animation_not_accepted","geometry_changed":false,"reference_face":[reference.x,reference.y,reference.z],"frames":records]
  try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("provenance.json"),options:.withoutOverwriting)
 }
}
