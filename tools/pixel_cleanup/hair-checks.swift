import Foundation
import CryptoKit

@main struct HairChecks {
 static func main() throws {
  guard CommandLine.arguments.count==3 else { throw failure("Usage: hair-checks <original cycle folder> <new cycle folder>") }
  let base=URL(fileURLWithPath:CommandLine.arguments[1]),candidate=URL(fileURLWithPath:CommandLine.arguments[2])
  func records(_ folder:URL) throws -> [[String:Any]] {
   let data=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("cycle.json"))) as! [String:Any]
   return data["frames"] as! [[String:Any]]
  }
  let originals=try records(base),outputs=try records(candidate)
  var count=0,failed=0
  func check(_ ok:Bool,_ message:String) { count+=1;if !ok { failed+=1;print("FAIL:",message) } }
  check(outputs.count==originals.count,"hair edit retains every walking pose")
  guard outputs.count==originals.count else { exit(1) }
  for (index,record) in outputs.enumerated() {
   let name=record["file"] as! String
   check(name==originals[index]["file"] as? String && record["phase"] as? NSNumber==originals[index]["phase"] as? NSNumber,"pose sequence and timing unchanged: \(name)")
   let a=try Raster(base.appendingPathComponent(name).path),b=try Raster(candidate.appendingPathComponent(name).path)
   check(a.width==b.width && a.height==b.height,"canvas and body scale retained: \(name)")
   var preserved=true,clearBun=true
   for y in 0..<a.height { for x in 0..<a.width {
    let p=(y*a.width+x)*4
    if !(x>=530 && x<718 && y>=96 && y<265) {
     if a.rgba[p+3] != b.rgba[p+3] || (a.rgba[p+3]==255 && a.rgba[p..<p+4] != b.rgba[p..<p+4]) { preserved=false }
    }
    if x>=635 && x<680 && y>=145 && y<177 && b.rgba[p+3]>12 { clearBun=false }
   }}
   check(preserved,"face, ponytail, bow, body and gait pixels outside the crown remain intact: \(name)")
   check(clearBun,"the protruding bun is absent, not hidden under an opaque patch: \(name)")
   var contour=Set<Int>()
   for x in stride(from:545,to:676,by:5) {
    if let y=(100..<240).first(where:{b.rgba[($0*b.width+x)*4+3]>230}) { contour.insert(y) }
   }
   check(contour.count>=7,"crown outline is curved rather than a straight cut: \(name)")
   let hash=SHA256.hash(data:try Data(contentsOf:base.appendingPathComponent(name))).map{String(format:"%02x",$0)}.joined()
   check(hash==originals[index]["sha256"] as? String,"the previous authored frame remains recoverable: \(name)")
  }
  print("Ponytail source checks: \(count), failures: \(failed)")
  exit(failed==0 ? 0:1)
 }
}
