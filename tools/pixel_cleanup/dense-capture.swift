import Foundation
import ImageIO
import UniformTypeIdentifiers

// Read-only QA of paired engine captures. Does not edit character assets.
@main struct DenseCapture {
 static func main() throws {
  guard CommandLine.arguments.count==2 else { throw failure("Usage: dense-capture <audit folder>") }
  let folder=URL(fileURLWithPath:CommandLine.arguments[1])
  var frames=[Raster]()
  for i in 0..<63 { frames.append(try Raster(folder.appendingPathComponent(String(format:"frames/%03d.png",i)).path)) }
  var report=[[String:Any]]()
  for side in 0...1 {
   var entry:[String:Any]=["side":side==0 ? "before":"after"]
   let sprites=frames.map{ $0.crop(x:65+side*240,y:48,width:110,height:142) }
   entry["distinct_rendered_poses"]=Set(sprites.map{Data($0.rgba)}).count
   for (label,start,end) in [("legs",88,142),("upper_body",0,88)] {
    var jumps=[Double]()
    for i in sprites.indices {
     let a=sprites[i],b=sprites[(i+1)%sprites.count]
     var difference=0.0
     for y in start..<end { for x in 0..<a.width { for c in 0..<3 {
      difference+=Double(abs(Int(a.rgba[(y*a.width+x)*4+c])-Int(b.rgba[(y*a.width+x)*4+c])))
     }}}
     jumps.append(difference/255/3)
    }
    entry[label+"_largest_jump"]=jumps.max()!
    entry[label+"_largest_jump_frame"]=jumps.firstIndex(of:jumps.max()!)!
    entry[label+"_mean_jump"]=jumps.reduce(0,+)/Double(jumps.count)
   }
   report.append(entry)
  }
  try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("render-metrics.json"))
  // APNG retains a 1/60-second timeline, avoiding GIF's centisecond rounding.
  guard let destination=CGImageDestinationCreateWithURL(folder.appendingPathComponent("walk-comparison.png") as CFURL,UTType.png.identifier as CFString,frames.count,nil) else { throw failure("Cannot create APNG") }
  CGImageDestinationSetProperties(destination,[kCGImagePropertyPNGDictionary:[kCGImagePropertyAPNGLoopCount:0]] as CFDictionary)
  for (index,frame) in frames.enumerated() {
   // ImageIO stores integer milliseconds. A 17/17/16 ms cadence preserves
   // the exact 1.05-second cycle instead of truncating every frame to 16 ms.
   let delay=index%3==2 ? 0.016 : 0.017
   CGImageDestinationAddImage(destination,frame.cgImage,[kCGImagePropertyPNGDictionary:[kCGImagePropertyAPNGDelayTime:delay,kCGImagePropertyAPNGUnclampedDelayTime:delay]] as CFDictionary)
  }
  guard CGImageDestinationFinalize(destination) else { throw failure("Cannot finish APNG") }
  print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
 }
}
