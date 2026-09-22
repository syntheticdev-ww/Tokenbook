import Foundation

@main struct PatchChecks {
 static func main() throws {
  var failures=0,checks=0
  func check(_ ok:Bool,_ why:String) { checks+=1;if !ok { failures+=1;print("FAIL:",why) } }
  let base=Raster(width:2,height:2,rgba:[10,20,30,255, 40,50,60,255, 70,80,90,255, 100,110,120,255])
  let edit=Raster(width:2,height:2,rgba:[200,200,200,255, 210,210,210,255, 220,220,220,255, 0,0,0,0])
  let result=try PixelPatch.apply(base:base,edited:edit){x,y in y==1}
  check(Array(result.rgba[0..<8])==Array(base.rgba[0..<8]),"unrelated head/clothing pixels cannot drift with the generated edit")
  check(Array(result.rgba[8..<12])==[220,220,220,255],"the permitted correction is actually applied")
  check(Array(result.rgba[12..<16])==[0,0,0,0],"a concealed limb is erased, not alpha-composited over the original arm")
  do {
   _=try PixelPatch.apply(base:base,edited:Raster(width:1,height:1,rgba:[0,0,0,0])){_,_ in true}
   check(false,"mismatched canvas rejected")
  } catch { check(true,"mismatched canvas rejected") }
  print("Protected pixel edit checks: \(checks), failures: \(failures)")
  exit(failures==0 ? 0:1)
 }
}
