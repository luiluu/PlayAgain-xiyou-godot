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
for id in ["toji","yomi"]{
 var sheet=Raster(144,192)
 for row in 0..<4{
  let sourceRow = id == "toji" && row == 2 ? 1:row
  let center=Raster(path:root+"/native/"+id+"_walk_\(sourceRow)_1.png")
  var phases=[Raster]()
  for phase in 0..<3{
   var f=Raster(path:root+"/native/"+id+"_walk_\(sourceRow)_\(phase).png")
   // Preserve a coherent head silhouette; actual gait remains in arms and legs.
   let headCut=id == "toji" ? 26:29
   for y in 0..<headCut{for x in 0..<48{f.set(x,y,center.get(x,y))}}
   if phase == 2 { // opposite leg support, anchored at the same hip axis
    let limbStart=38
    let first=phases[0]
    for y in limbStart..<48{for x in 0..<48{f.set(x,y,first.get(47-x,y))}}
   }
   if id == "toji" && row == 2 {var flipped=Raster(48,48);for y in 0..<48{for x in 0..<48{flipped.set(x,y,f.get(47-x,y))}};f=flipped}
   // Keep empty atlas borders without translating the whole frame.
   for k in 0..<48{f.set(k,0,[0,0,0,0]);f.set(k,47,[0,0,0,0]);f.set(0,k,[0,0,0,0]);f.set(47,k,[0,0,0,0])}
   phases.append(f);f.save(root+"/native/"+id+"_walk_\(row)_\(phase).png");sheet.paste(f,phase*48,row*48)
  }
 }
 sheet.save(root+"/native/"+id+"_Walk.png");sheet.scaled(4).save(root+"/native/"+id+"_walk_4x.png")
}
