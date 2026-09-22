import Foundation
import CryptoKit

@main struct SourceChecks {
 static func main() throws {
  guard CommandLine.arguments.count==3 else { throw failure("Usage: source-checks <v14 source folder> <calibrated folder>") }
  let source=URL(fileURLWithPath:CommandLine.arguments[1]),output=URL(fileURLWithPath:CommandLine.arguments[2])
  let original=try JSONSerialization.jsonObject(with:Data(contentsOf:source.appendingPathComponent("provenance.json"))) as! [String:Any]
  let result=try JSONSerialization.jsonObject(with:Data(contentsOf:output.appendingPathComponent("provenance.json"))) as! [String:Any]
  var count=0,failed=0
  func check(_ condition:Bool,_ message:String) { count+=1;if !condition { failed+=1;print("FAIL:",message) } }
  for record in original["assets"] as! [[String:Any]] {
   let name=record["asset"] as! String
   let hash=SHA256.hash(data:try Data(contentsOf:source.appendingPathComponent(name))).map{String(format:"%02x",$0)}.joined()
   check(hash==record["sha256"] as? String,"original art preserved: \(name)")
  }
  var means=[SIMD3<Double>]()
  for record in result["frames"] as! [[String:Any]] {
   let a=try Raster(source.appendingPathComponent(record["source"] as! String).path)
   let b=try Raster(output.appendingPathComponent(record["file"] as! String).path)
   check(a.width==b.width && a.height==b.height,"calibration retains complete source canvas")
   check(stride(from:3,to:a.rgba.count,by:4).allSatisfy{a.rgba[$0]==b.rgba[$0]},"PNG round-trip retains the exact alpha silhouette")
   means.append(try b.faceMean())
  }
  var worst=0.0
  for i in means.indices {
   let delta=means[i]-means[(i+1)%means.count]
   worst=max(worst,sqrt(delta.x*delta.x+delta.y*delta.y+delta.z*delta.z))
  }
  check(worst<2,"actual saved PNGs share a stable skin ramp, including the loop seam")
  check(result["production_eligible"] as? Bool==false,"color-only changes cannot approve unreviewed poses")
  print("Saved-source checks: \(count), failures: \(failed); worst face delta: \(worst)")
  exit(failed==0 ? 0:1)
 }
}
