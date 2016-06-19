#Import "<std>"
#Import "<mojo>"

Using std..
Using mojo..

Global instance:AppInstance


Class VPane Extends Image
	Field canvas:Canvas

	Method New(w:Int,h:Int,bg:Color)		
		Super.New(w,h,TextureFlags.Dynamic)		
		canvas=New Canvas(Self)	
		canvas.Clear(bg)
	End
	
	Method Draw(display:Canvas)
		canvas.Flush()
		display.DrawImage( Self, 0,0)
	End

	Method FatLine(x:Int,y:Int,x1:Int,y1:Int)
		Local fat:Int=7

		If Not canvas Return
		
		Local verts:=New Float[8]
		
		Local dy:Int=y1-y
		Local dx:Int=x1-x
				
		Local len:Float=Sqrt(dx*dx+dy*dy) 
		Local q:Float=fat/len
				
		verts[0]=x+dy*q
		verts[1]=y-dx*q
		
		verts[2]=x1+dy*q
		verts[3]=y1-dx*q

		verts[4]=x1-dy*q
		verts[5]=y1+dx*q

		verts[6]=x-dy*q
		verts[7]=y+dx*q
		
		canvas.DrawPoly(verts)
	End
	

	Method FatCurve(x0:Int,y0:Int,x1:Int,y1:Int,x2:Int,y2:Int,x3:Int,y3:Int)
		If Not canvas Return
		Local fat:Int=3
		Local seg:Int=8
		Local verts:=New Float[(seg+1)*2]		
		For Local i:Int=0 To seg		
			Local mu:Float=i*1.0/seg			    
        	Local x:Float=CubicInterpolate(x0,x1,x2,x3,mu)
        	Local y:Float=CubicInterpolate(y0,y1,y2,y3,mu)
          	verts[i*2+0]=x
        	verts[i*2+1]=y
		Next		
		For Local i:Int=0 Until seg		
			FatLine(verts[i*2+0],verts[i*2+1],verts[i*2+2],verts[i*2+3])
		Next
	End

 	Function CubicInterpolate:Float(y0:Float,y1:Float,y2:Float,y3:Float,mu:Float)
    	Local a0:Float
    	Local a1:Float
    	Local a2:Float
    	Local a3:Float
    	Local mu2:Float
	    mu2=mu*mu
	    a0=y3-y2-y0+y1
	    a1=y0-y1-a0
	    a2=y2-y0
	    a3=y1
	    Return a0*mu*mu2+a1*mu2+a2*mu+a3
	End
	    
End

Class VPaint Extends Window

	Field pane:VPane
	Field ink:Color

	Field mousex:Int
	Field mousey:Int
	Field framecount:Int
	Field drawcount:Int

	Method New(title:String)
		Super.New(title,800,600)		
		pane=New VPane(2048,2048,Color.Black)
		ink=New Color
	End
		
	Method OnRender( display:Canvas ) Override	
		App.RequestRender()				
		pane.Draw(display)		
		framecount+=1				
		ink.r=(framecount&255)/255.0
		ink.g=(framecount&1023)/1023.0
		ink.b=(framecount&511)/511.0
		pane.canvas.Color=ink
	End

	Method OnKeyEvent( event:KeyEvent ) Override	
		Select event.Type
		Case EventType.KeyDown
			Select event.Key
			Case Key.Escape
				instance.Terminate()
			Case Key.F1
				Fullscreen = Not Fullscreen
			End
		End
		
	End
	
	Field linetool:Bool
	Field mx:=New Int[4]
	Field my:=New Int[4]
			
	Method OnMouseEvent(event:MouseEvent ) Override
		Local x:Int=event.Location.X
		Local y:Int=event.Location.Y
		Local b:Int=event.Button
		
		mx[0]=mx[1]
		my[0]=my[1]
		mx[1]=mx[2]
		my[1]=my[2]
		mx[2]=mx[3]
		my[2]=my[3]
		mx[3]=x
		my[3]=y

If linetool
		If drawcount	
			pane.FatLine(mousex,mousey,x,y)		
		Endif
Else
		If drawcount>2 And Not b
			pane.FatCurve(mx[0],my[0],mx[1],my[1],mx[2],my[2],mx[3],my[3])				
		Endif
Endif
		mousex=x
		mousey=y
		drawcount+=1
	End	
End

Global title:String="VPaint 0.0"	

Function Main()
	Print title
	instance = New AppInstance	
	New VPaint(title)
	App.Run()	
End

'Method DrawIndexedPrimitives : Void ( order:Int, count:Int, vertices:Float[], texcoords:Float[], indices:Int[], material:Material=Null )