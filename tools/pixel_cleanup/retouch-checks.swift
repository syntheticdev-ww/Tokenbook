import Foundation

@main struct RetouchChecks {
 static func main() throws {
  guard CommandLine.arguments.count==3 else { throw failure("Usage: retouch-checks <base folder> <candidate folder>") }
  let base=URL(fileURLWithPath:CommandLine.arguments[1]),candidate=URL(fileURLWithPath:CommandLine.arguments[2])
  let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:candidate.appendingPathComponent("cycle.json"))) as! [String:Any]
  let records=manifest["frames"] as! [[String:Any]]
  var count=0,failed=0
  func check(_ ok:Bool,_ message:String) { count+=1;if !ok { failed+=1;print("FAIL:",message) } }
  for record in records {
   let name=record["file"] as! String,baseName=record["base"] as! String
   let originalURL=base.appendingPathComponent(baseName),resultURL=candidate.appendingPathComponent(name)
   if record["edit_source"]==nil {
    check(try Data(contentsOf:originalURL)==Data(contentsOf:resultURL),"untouched drawing remains byte-identical: \(name)")
    continue
   }
   let a=try Raster(originalURL.path),b=try Raster(resultURL.path)
   check(a.width==b.width && a.height==b.height,"whole-character canvas: \(name)")
   var headExact=true,beltExact=true
   for y in 0..<a.height { for x in 0..<a.width {
    let i=(y*a.width+x)*4
    if y<480 && a.rgba[i+3]==255 && a.rgba[i..<i+4] != b.rgba[i..<i+4] { headExact=false }
    if x>=540 && x<598 && y>=629 && y<667 && a.rgba[i+3]==255 && a.rgba[i..<i+4] != b.rgba[i..<i+4] { beltExact=false }
   }}
   check(headExact,"opaque face and hair pixels are not repainted: \(name)")
   if name.contains("a.") || name.contains("b.") { check(beltExact,"passing pose retains its established solid buckle: \(name)") }
   check(InterpolationQuality.translucentShare(b)<=InterpolationQuality.translucentShare(a)+0.02,"new poses have no translucent interpolation ghosts: \(name)")
  }
  check(records.count==19,"all nineteen authored whole-body poses are present")
  check(manifest["production_eligible"] as? Bool==false,"source checks alone cannot approve production artwork")
  print("Retouched-source checks: \(count), failures: \(failed)")
  exit(failed==0 ? 0:1)
 }
}
