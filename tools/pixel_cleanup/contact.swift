import Foundation

// Read-only art QA contact sheet. The exported game PNGs are never modified.
@main struct Contact {
 static func main() throws {
  guard CommandLine.arguments.count==3 else { throw failure("Usage: contact <cycle folder> <new contact.png>") }
  let folder=URL(fileURLWithPath:CommandLine.arguments[1])
  let manifest=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("cycle.json"))) as! [String:Any]
  let records=manifest["frames"] as! [[String:Any]],cell=250,columns=5
  let width=columns*cell,height=((records.count+columns-1)/columns)*cell
  var pixels=[UInt8](repeating:255,count:width*height*4)
  for i in stride(from:0,to:pixels.count,by:4) { pixels[i]=238;pixels[i+1]=234;pixels[i+2]=221 }
  for (index,record) in records.enumerated() {
   let name=record["file"] as! String,art=try Raster(folder.appendingPathComponent(name).path)
   for y in 0..<cell { for x in 0..<cell {
    let src=(y*art.height/cell*art.width+x*art.width/cell)*4
    let dst=((index/columns*cell+y)*width+index%columns*cell+x)*4
    let alpha=Double(art.rgba[src+3])/255
    for c in 0..<3 { pixels[dst+c]=UInt8((Double(art.rgba[src+c])*alpha+Double(pixels[dst+c])*(1-alpha)).rounded()) }
   }}
   print("row",index/columns+1,"column",index%columns+1,name)
  }
  try Raster(width:width,height:height,rgba:pixels).save(CommandLine.arguments[2])
 }
}
