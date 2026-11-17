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
let root=CommandLine.arguments[1]
let rows=try! JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:root+"/inputs.json"))) as! [[String:String]]
for s in rows {let src=Raster(path:s["originalWalk"]!);var x0=0,y0=0,ww=src.w,hh=src.h
if src.w==576 {let idx=Int(s["characterIndex"]!)!;ww=src.w/4;hh=src.h/2;x0=(idx%4)*ww;y0=(idx/4)*hh}
var f=Raster(ww,hh);for y in 0..<hh{for x in 0..<ww{f.set(x,y,src.get(x+x0,y+y0))}};f.save(root+"/native/"+s["id"]!+"_original_walk.png")}
