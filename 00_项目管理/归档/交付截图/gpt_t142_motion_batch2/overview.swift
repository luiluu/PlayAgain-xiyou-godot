import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers
let root=CommandLine.arguments[1]
let rows=try! JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:root+"/inputs.json"))) as! [[String:String]]
let report=try! JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:root+"/native_report.json"))) as! [[String:Any]]
let heights=report.map{r in max(430,(r["cell"] as! [Int])[1]*3+100)}
let width=1200,height=130+heights.reduce(0,+)
let canvas=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:width*4,bitsPerPixel:32)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:canvas);NSGraphicsContext.current!.imageInterpolation = .none
func rect(_ x:Int,_ y:Int,_ w:Int,_ h:Int)->NSRect{NSRect(x:x,y:height-y-h,width:w,height:h)}
func text(_ s:String,_ x:Int,_ y:Int,_ size:CGFloat=20){(s as NSString).draw(in:rect(x,y,width-x,45),withAttributes:[.font:NSFont.systemFont(ofSize:size),.foregroundColor:NSColor.white])}
func draw(_ path:String,_ x:Int,_ y:Int,_ scale:Int=1){let im=NSImage(contentsOfFile:path)!;let rep=im.representations[0];im.draw(in:rect(x,y,rep.pixelsWide*scale,rep.pixelsHigh*scale),from:.zero,operation:.sourceOver,fraction:1)}
NSColor(calibratedRed:0.07,green:0.09,blue:0.13,alpha:1).setFill();rect(0,0,width,height).fill()
text("T142  待机重画 · 原版 / 新稿",24,15,30);text("左：原版战斗＋行走   右：新稿原生三帧＋2倍首帧",24,58,23);text("未接入 · 形象与动作待定稿 · 全帧4倍图及动图见附件",24,94,18)
var y=130
for (i,s) in rows.enumerated(){let id=s["id"]!,hh=(report[i]["cell"] as! [Int])[1]
 NSColor(calibratedWhite:i%2==0 ? 0.14:0.18,alpha:1).setFill();rect(0,y,width,heights[i]-2).fill()
 text(s["name"]!,20,y+8,24);text("原版",20,y+45,18);text("新稿 1× · 三帧",540,y+45,18)
 draw(root+"/native/"+id+"_original.png",20,y+80)
 draw(root+"/native/"+id+"_original_walk.png",220,y+80)
 draw(root+"/native/"+id+"_Idle.png",540,y+80)
 text("新稿 2× · 首帧",540,y+90+hh,18);draw(root+"/native/"+id+"_idle_0.png",540,y+125+hh,2)
 if s["walkRaw"] != nil {draw(root+"/native/"+id+"_Walk.png",990,y+205);text("新行走 1×",990,y+175,18)}
 let gif=CGImageDestinationCreateWithURL(URL(fileURLWithPath:root+"/native/"+id+"_idle.gif") as CFURL,UTType.gif.identifier as CFString,4,nil)!
 CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
 for phase in [0,1,2,1]{let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:root+"/native/"+id+"_idle_\(phase).png") as CFURL,nil)!;CGImageDestinationAddImageFromSource(gif,source,0,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.25]] as CFDictionary)};CGImageDestinationFinalize(gif)
 y+=heights[i]
}
NSGraphicsContext.restoreGraphicsState()
try! canvas.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:root+"/手机总览_原版对照_原生与放大.png"))
