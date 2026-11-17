import AppKit
import Foundation
struct Raster {
 var w:Int; var h:Int; var p:[UInt8]
 init(_ w:Int,_ h:Int){self.w=w;self.h=h;p=[UInt8](repeating:0,count:w*h*4)}
 init(path:String){let r=NSBitmapImageRep(data:try! Data(contentsOf:URL(fileURLWithPath:path)))!;w=r.pixelsWide;h=r.pixelsHigh;p=[UInt8](repeating:0,count:w*h*4);for y in 0..<h {for x in 0..<w {let c=r.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!;let j=(y*w+x)*4;p[j]=UInt8((c.redComponent*255).rounded());p[j+1]=UInt8((c.greenComponent*255).rounded());p[j+2]=UInt8((c.blueComponent*255).rounded());p[j+3]=UInt8((c.alphaComponent*255).rounded())}}}
 func get(_ x:Int,_ y:Int)->[UInt8]{if x<0 || y<0 || x>=w || y>=h{return [0,0,0,0]};let j=(y*w+x)*4;return Array(p[j..<j+4])}
 mutating func set(_ x:Int,_ y:Int,_ c:[UInt8]){if x<0 || y<0 || x>=w || y>=h{return};let j=(y*w+x)*4;for k in 0..<4{p[j+k]=c[k]}}
 func save(_ path:String){let r=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:.alphaNonpremultiplied,bytesPerRow:w*4,bitsPerPixel:32)!;p.withUnsafeBytes{r.bitmapData!.update(from:$0.baseAddress!.assumingMemoryBound(to:UInt8.self),count:p.count)};try! r.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))}
 mutating func paste(_ f:Raster,_ x:Int,_ y:Int){for yy in 0..<f.h{for xx in 0..<f.w{set(x+xx,y+yy,f.get(xx,yy))}}}
 func scaled(_ n:Int)->Raster{var f=Raster(w*n,h*n);for y in 0..<f.h{for x in 0..<f.w{f.set(x,y,get(x/n,y/n))}};return f}
 mutating func clean(){// remove disconnected one-pixel edge noise, never relocate anatomy
  var seen=Set<Int>();for y in 0..<h{for x in 0..<w{let start=y*w+x;if p[start*4+3]==0 || seen.contains(start){continue};var q=[start];seen.insert(start);var i=0;while i<q.count{let v=q[i];i+=1;for dy in -1...1{for dx in -1...1{let xx=v%w+dx,yy=v/w+dy;if xx<0 || yy<0 || xx>=w || yy>=h{continue};let k=yy*w+xx;if p[k*4+3]>0 && !seen.contains(k){seen.insert(k);q.append(k)}}}};if q.count<3{for k in q{for c in 0..<4{p[k*4+c]=0}}}}}
 }
}
extension Raster {
 func crop(_ x:Int,_ y:Int,_ ww:Int,_ hh:Int)->Raster{var a=Raster(ww,hh);for yy in 0..<hh{for xx in 0..<ww{a.set(xx,yy,get(x+xx,y+yy))}};return a}
 func box()->[Int]{var a=w,b=h,c=0,d=0;for y in 0..<h{for x in 0..<w{if get(x,y)[3]>200{a=min(a,x);b=min(b,y);c=max(c,x);d=max(d,y)}}};return [a,b,c-a+1,d-b+1]}
 func fitted(_ b:[Int],_ size:[Int])->Raster{let bb=box();var f=Raster(size[0],size[1]);for y in 0..<b[3]{for x in 0..<b[2]{var c=get(bb[0]+min(bb[2]-1,x*bb[2]/b[2]),bb[1]+min(bb[3]-1,y*bb[3]/b[3]));if c[3]<235{c=[0,0,0,0]}else{c[3]=255;for k in 0..<3{c[k]=UInt8(min(248,Int((Double(c[k])/8).rounded())*8))}};f.set(b[0]+x,b[1]+y,c)}};f.clean();return f}
}
let root=CommandLine.arguments[1]
let rows=try! JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:root+"/inputs.json"))) as! [[String:String]]
var reports=[[String:Any]]()
for s in rows{
 let id=s["id"]!,src=Raster(path:s["source"]!),raw=Raster(path:s["raw"]!)
 try? FileManager.default.copyItem(atPath:s["raw"]!,toPath:root+"/raw/"+id+".png")
 let sheet=["anon","kotori","yomi","toji","sukuna","gojo"].contains(id)
 let ww=sheet ? src.w/9:src.w, hh=sheet ? src.h/6:src.h
 let orig=src.crop(0,0,ww,hh),b=orig.box()
 let base=raw.crop(0,0,raw.w/3,raw.h).fitted(b,[ww,hh])
 let cut=b[1]+Int(Double(b[3]) * (id == "garou" ? 0.27 : 0.51))
 var strip=Raster(ww*3,hh)
 for phase in 0..<3{
  var f=base
  if phase==1{
   if id == "tusu_bow" { // stationary grip/orientation, restrained string glint
    for y in (b[1]+b[3]/4)..<(b[1]+b[3]/4+3){let x=b[0]+b[2]-5;var c=f.get(x,y);if c[3]>0{c[0]=min(255,c[0]&+16);f.set(x,y,c)}}
   }else{
    // Head/neck pose rig; preserve arms, lower body and support pixels.
    let xmin=id == "cat" ? b[0]+b[2]/4 : 0
    for y in 0...cut{for x in xmin..<ww{f.set(x,y,[0,0,0,0])}}
    for y in 0..<cut{for x in xmin..<ww{let c=base.get(x,y);if c[3]>0{f.set(x,y+1,c)}}}
   }
  }
  f.save(root+"/native/"+id+"_idle_\(phase).png");strip.paste(f,phase*ww,0)
 }
 strip.save(root+"/native/"+id+"_Idle.png");strip.scaled(4).save(root+"/native/"+id+"_idle_4x.png")
 orig.save(root+"/native/"+id+"_original.png")
 reports.append(["id":id,"cell":[ww,hh],"source_bbox":b,"head_cut":cut,"head_x_shift":0,"breath_y":id == "tusu_bow" ? 0:1])
 if let path=s["walkRaw"],let oldpath=s["walkSource"]{
  let wr=Raster(path:path),old=Raster(path:oldpath),cw=old.w/3,ch=old.h/4
  try? FileManager.default.copyItem(atPath:path,toPath:root+"/raw/"+id+"_walk.png")
  var walk=Raster(cw*3,ch*4)
  for row in 0..<4{
   let ob=old.crop(cw,row*ch,cw,ch).box()
   for col in 0..<3{let piece=wr.crop(col*wr.w/3,row*wr.h/4,wr.w/3,wr.h/4)
    let f=piece.fitted(ob,[cw,ch]);f.save(root+"/native/"+id+"_walk_\(row)_\(col).png");walk.paste(f,col*cw,row*ch)
   }
  }
  walk.save(root+"/native/"+id+"_Walk.png");walk.scaled(4).save(root+"/native/"+id+"_walk_4x.png")
 }
 print(id,ww,hh,cut)
}
try! JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:root+"/native_report.json"))
