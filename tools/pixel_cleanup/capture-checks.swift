import Foundation

// Validate actual engine renders, not a sprite-only synthetic animation.
// This checks fixed-timestep output, not real-time display performance.
@main struct CaptureChecks {
 static func main() throws {
  guard CommandLine.arguments.count==4 else { throw failure("Usage: capture-checks <cycle.json> <render folder> <new contact.png>") }
  let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))) as! [String:Any]
  let records=manifest["frames"] as! [[String:Any]],folder=URL(fileURLWithPath:CommandLine.arguments[2])
  let phases=records.map{($0["phase"] as! NSNumber).doubleValue}
  var seen=[Int:[UInt8]](),count=0,failed=0
  func check(_ ok:Bool,_ message:String) { count+=1;if !ok { failed+=1;print("FAIL:",message) } }
  for i in 0..<126 {
   let frame=try Raster(folder.appendingPathComponent(String(format:"%04d.png",i)).path)
   guard frame.width==1190 && frame.height==820 else { throw failure("Unexpected review viewport") }
   let pose=frame.crop(x:910,y:180,width:180,height:178).rgba
   let phase=Double(i%63)/63*16
   let index=phases.indices.min { a,b in
    let da=abs(phases[a]-phase),db=abs(phases[b]-phase)
    return min(da,16-da)<min(db,16-db)
   }!
   if let previous=seen[index] { check(previous==pose,"held/repeated drawing stays pixel-identical at rendered frame \(i)") }
   else { seen[index]=pose }
  }
  check(seen.count==records.count,"every authored drawing reached the actual renderer")
  check(Set(seen.values.map{Data($0)}).count==records.count,"added drawings are distinct in the actual rendered result")
  let width=900,height=((records.count+4)/5)*178
  var sheet=[UInt8](repeating:238,count:width*height*4)
  for i in stride(from:3,to:sheet.count,by:4) { sheet[i]=255 }
  for index in records.indices {
   guard let pose=seen[index] else { continue }
   for y in 0..<178 {
    let destination=((index/5*178+y)*width+index%5*180)*4
    sheet.replaceSubrange(destination..<destination+180*4,with:pose[y*180*4..<(y+1)*180*4])
   }
  }
  try Raster(width:width,height:height,rgba:sheet).save(CommandLine.arguments[3])
  print("Native rendered-capture checks: \(count), failures: \(failed); \(seen.count) distinct poses in 126 fixed-timestep frames")
  exit(failed==0 ? 0:1)
 }
}
