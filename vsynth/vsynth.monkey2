#Import "<std>"
#Import "<mojo>"
#Import "<sdl2>"
#Import "<portmidi>"
#Import "audiopipe.monkey2"

Using std..
Using mojo..
Using sdl2..
Using portmidi..

Global AppTitle:String="VSynth 0.03"	
Global Contact:="Latest Source=github.com/nitrologic/m2"

Global About:="VSynth Control"
Global Octave1:= "Sharps=    W   E       T   Y   U      "
Global Octave0:= "Notes=A   S   D  F   G   H    J  K"
Global Controls:="Reset Keys=Space,Quit=Escape,,Scan Midi Bus=Backspace"

Global OscillatorNames:=New String[]("Square","Sine","Sawtooth","Triangle","Noise")
Global EnvelopeNames:=New String[]("None","Plain","Punchy","SlowOut","SlowIn")
Global ArpNames:=New String[]("None","Natural","Ascending","Descending","UpDown","Random1","Random2")
Global SynthNames:=New String[]("Mono1","Poly32")
Global HoldNames:=New String[]("Off","On")
Global DivisorNames:=New String[]("Whole","Half","Third","Quarter","Fifth","Sixth","Seventh","Eighth")
Global DutyNames:=New String[]("1:2","3:4","1:4","7:8","1:8","5:8","3:8")
Global DutyCycle:=New Double[](0.5,0.75,0.25,0.875,0.125,0.625,0.375)

Alias V:Double ' Voltage(volts)
Alias F:Double ' Frequency(hz)
Alias T:Double ' Time(seconds)

Alias Note:Int
Alias Tempo:Int ' BeatsPerMinute
Alias K:Key

Public

Global instance:AppInstance
Global vsynth:VSynth

Global Duration:=0
Global FragmentSize:=512
Global WriteAhead:=2048

Global AudioFrequency:=44100

Const MaxPolyphony:=32
Const MaxOctave:=12

Class Envelope
	Field p:V
	Method On:V() Virtual
		Return 1.0
	End
	Method Off:V() Virtual
		Return 0.0
	End
End

Class ADSR Extends Envelope
	Field attack:T
	Field decay:T
	Field sustain:V
	Field release:T
	
	Method New(a:T,d:T,s:V,r:T)
		attack=a
		decay=d
		sustain=s
		release=r
	End
	
	Field t:T
	Field noteOn:Bool

	Method On:V() Override
		If Not noteOn
			t=0
			noteOn=True
		Endif
		t+=1.0/AudioFrequency
		If t<attack Return t/attack
		If t-attack<decay Return 1.0-((1-sustain)*(t-attack)/decay)
		Return sustain
	End

	Method Off:V() Override
		noteOn=False
		t+=1.0/AudioFrequency
		If t<release 
			Return 1.0-t/release
		Endif
		Return 0.0
	End
End


Class Oscillator
	Field delta:T
	Method Sample:V(hz:F) Virtual
		Return 0
	End
End

Class Sine Extends Oscillator	
	Method Sample:V(hz:F) Override
		Local t:T=hz/AudioFrequency
		delta+=t
		Return Sin(Pi*delta)
	End
End

Class Sawtooth Extends Oscillator
	Method Sample:V(hz:F) Override
		Local t:T=hz/AudioFrequency
		delta+=t		
		Return ((delta+1) Mod 2)-1
	End
End

Class Triangle Extends Oscillator
	Method Sample:V(hz:F) Override
		Local t:T=2*hz/AudioFrequency
		delta+=t
		Return (Abs(delta Mod 4)-2)-1
	End
End

Class Square Extends Oscillator
	Method Sample:V(hz:F) Override
		Local t:T=hz/AudioFrequency
		delta+=t
		Return -1+2*(Int(delta)&1)
	End
End

Class Noise Extends Oscillator
	Field a:V
	Method Sample:V(hz:F) Override
		Local t:T=hz/AudioFrequency
		Local delta0:=delta
		delta+=t		
		Local f:=delta Mod 1				
		If Int(delta0)<>Int(delta)
			a=Rnd()
		Endif	
		Return 1-2*a	'(a+f*(b-a)		
	End
End

Interface NotePlayer
	Method SetOscillator(osc:Int)
	Method SetEnvelope(env:Int)
	Method SetPan(value:V)
	Method SetGain(value:V)
	Method Stop()
	Method NoteOn(note:Int)
	Method NoteOff()
End


Class Voice Implements NotePlayer
	Field oscillator:Oscillator
	Field envelope:Envelope
	Field noteOn:Bool
	Field hz:F
	Field pan:V
	Field gain:V=0.12
	
	Method SetOscillator(osc:Int)
		Select osc
			Case 0 oscillator=New Square
			Case 1 oscillator=New Sine
			Case 2 oscillator=New Sawtooth
			Case 3 oscillator=New Triangle
			Case 4 oscillator=New Noise
		End
	End
	
	Method SetEnvelope(env:Int)
		Select env
			Case 0 
				envelope=New Envelope()
			Case 1 
				envelope=New ADSR(0.05,1.5,0.2,0.3)
			Case 2
				envelope=New ADSR(0.06,0.01,0.92,0.2)
			Case 3 
				envelope=New ADSR(0.06,2.0,0.2,1.2)
			Case 4
				envelope=New ADSR(0.2,0.2,0.92,0.4)
		End
	End

	Method SetPan(value:V)
		pan=value
	End
	
	Method SetGain(value:V)
		gain=value
	End

	Method Stop()
		NoteOff()
		envelope.Off()
	End	
	
	Method NoteOn(note:Int)
		hz=440.0*Pow(2.0,(note-67.0)/12)
		noteOn=True
	End
	
	Method NoteOff()
		noteOn=False
	End
	
	Method Mix(buffer:Double[],samples:Int,detune:V)
		Local left:=1.0
		Local right:=1.0
		If pan<0 right+=pan
		If pan>0 left-=pan		
		For Local i:=0 Until samples
			Local v:=oscillator.Sample(hz*detune)			
			Local e:V
			If noteOn e=envelope.On() Else e=envelope.Off()
			e*=gain
			buffer[i*2+0]+=e*left*v
			buffer[i*2+1]+=e*right*v
		Next
	End
End

Interface Synth
	Method SetTempo(tempo:Tempo,divisor:Int,duty:V)
	Method NoteOn(note:Int,oscillator:Int,envelope:Int)
	Method NoteOff(note:Int)
	Method FillAudioBuffer(buffer:Double[],samples:Int,detune:V)	
	Method Panic()
End

Class BeatGenerator Implements Synth

	Field bpm:=120
	Field divisor:=3
	Field dutycycle:=0.5
	Field output:Synth
	Field time:T
	Field clock:T
	Field oscillator:Int
	Field envelope:Int
	Field recent:Note
	
	Field notePeriod:T
	Field dutyPeriod:T
	
	Method SetTempo(tempo:Tempo,div:Int,duty:V)
		bpm=tempo
		divisor=div
		dutycycle=duty
		notePeriod=60.0/(bpm*divisor)
		dutyPeriod=duty*notePeriod
	End
	
	Method SetSynth(synth:Synth)
		output=synth
	End

	Method NoteOn(note:Int,osc:Int,env:Int) Virtual
		recent=note
		oscillator=osc
		envelope=env
	End
	
	Method NoteOff(note:Int) virtual
		output.NoteOff(note)
	End
	
	Method Beat() Virtual
		If recent
			NoteOn(recent,oscillator,envelope)
		Endif
	End
	
	Method Update(duration:T)
		time+=duration
		If notePeriod>0
			While clock<time
				Beat()
				clock+=notePeriod
			Wend
			StepDuration(duration)
		Endif
	end

	Field noteDuration:=new Map<Int,T>
	
	Method StepDuration(duration:T)
		For Local note:=Eachin noteDuration.Keys			
			If noteDuration[note]>0
				noteDuration[note]-=duration
				If noteDuration[note]<=0
					output.NoteOff(note)
				Endif
			Endif
		Next
	end

	Method FillAudioBuffer(buffer:Double[],samples:Int,detune:V)	
		Update(2.0*samples/AudioFrequency)
		output.FillAudioBuffer(buffer,samples,detune)
	End
	
	Method Panic()
		output.Panic()
	end

	Method TriggerNote(note:Int)	
		output.NoteOn(note,oscillator,envelope)
		noteDuration[note]=dutyPeriod
	End

end

Class Arpeggiator extends BeatGenerator
	Field natural:=New Stack<Note>
	Field sorted:Stack<Note>
	Field index:Int
	Field algorithm:Int
	Field hold:Bool

	Method SetArpeggiation(mode:Int)
		algorithm=mode
	End
		
	Method ReleaseAll()
		natural.Clear()
		noteDuration.Clear()
	end
	
	Method SetHold(down:Bool)
		If hold And Not down 
			ReleaseAll()
		end
		hold=down
	end
		
	Method NoteOn(note:Int,osc:Int,env:Int) Override
		If algorithm=0			
			output.NoteOn(note,osc,env)
		else		
			Super.NoteOn(note,osc,env)
			If natural.Contains(note) natural.Remove(note)
			natural.Push(note)
			sorted=New Stack<Note>(natural)
			sorted.Sort()
		endif
	End
	
	Method NoteOff(note:Int) Override
		output.NoteOff(note)
		If Not hold
			natural.Remove(note)
			sorted=New Stack<Note>(natural)
			sorted.Sort()
		endif
	End
	
	Method Beat() Override
		Local note:Int
		
		If natural.Length=0
			index=0
			return
		Endif
		
		Select algorithm
			Case 1
				index=index Mod natural.Length
				note=natural[index]
				index+=1
			Case 2			
				index=index Mod sorted.Length
				note=sorted[index]
				index+=1
			Case 3
				index=index Mod sorted.Length
				note=sorted[sorted.Length-index-1]
				index+=1
			Case 4			
				If sorted.Length>1
					Local bounce:=sorted.Length-2
					index=index Mod (sorted.Length+bounce)
					Local i:=index
					If i>bounce i=sorted.Length+bounce-index
					note=sorted[i]
				Else
					note=sorted[0]
				Endif
				index+=1
			Case 5
				index=index Mod sorted.Length
				note=sorted[index]
				if RndULong() & 1
					index+=1
				Else
					index-=1
					If index<0 index=sorted.Length-1
				Endif
			Case 6
				index=Rnd()*sorted.Length
				note=sorted[index]
		End
		If note TriggerNote(note)
	End
end

Class PolySynth Implements Synth

	Field polyList:=New List<Voice>
	Field polyMap:=New Map<Int,Voice>
	Field voices:=New Stack<Voice>
	
	Method New()
		For Local i:=0 Until MaxPolyphony
			Local tone:=New Voice
			tone.SetOscillator(0)
			tone.SetEnvelope(0)
			polyList.AddLast(tone)
		Next
	End
	
	Method SetTempo(tempo:Tempo,divisor:Int,duty:V)
	End
	
	Method Panic()
		voices.Clear()
	End

	Method NoteOn(note:Int,oscillator:Int,envelope:Int)
		NoteOff(note)
		If polyList.Empty Return
		Local voice:=polyList.RemoveFirst()
		voice.SetEnvelope(envelope)
		voice.SetOscillator(oscillator)
		voice.NoteOn(note)
		polyMap[note]=voice
		polyList.Remove(voice)
		If Not voices.Contains(voice)
			voices.Add(voice)
		Endif	
	End

	Method NoteOff(note:Int)	
		Local voice:=polyMap[note]
		If voice
			voice.Stop()
			polyMap.Remove(note)
			polyList.AddLast(voice)
		Endif
	End

	Method FillAudioBuffer(buffer:Double[],samples:Int,detune:V)	
		For Local voice:=Eachin voices
			voice.Mix(buffer,samples,detune)
		Next		
	End
	
End

Class MonoSynth Implements Synth
	Field tone:Voice
	Field monoNote:Int
	Field notes:=New Stack<Int>
	Field oscillator:int

	Method New()
		tone=New Voice
		tone.SetOscillator(0)
		tone.SetEnvelope(0)
	End
	
	Method SetTempo(tempo:Tempo,divisor:Int,duty:V)
	end
	
	Method Panic()
		tone.NoteOff()
	End

	Method NoteOn(note:Int,osc:Int,envelope:Int)
		monoNote=note
		If Not notes.Contains(note)
			notes.Push(note)
		Endif
		If osc<>oscillator
			oscillator=osc
			tone.SetOscillator(oscillator)
		endif
		tone.SetEnvelope(envelope)
		tone.NoteOn(note)
	End

	Method NoteOff(note:Int)
		notes.Remove(note)
		If notes.Empty
			tone.NoteOff()		
		Else
			note=notes.Pop()
			monoNote=note
			notes.Push(note)
			tone.NoteOn(note)
		Endif
	End

	Method FillAudioBuffer(buffer:Double[],samples:Int,detune:V)	
		tone.Mix(buffer,samples,detune)
	End

End

Class VSynth
	Field audioSpec:SDL_AudioSpec
	Field audioPipe:=AudioPipe.Create()
	Field detune:V
	Field poly:Synth=New PolySynth()
	Field mono:Synth=New MonoSynth()
	Field root:Synth
	Field arpeggiator:=New Arpeggiator()
	
	Method New()
		OpenAudio()
		arpeggiator.SetSynth(mono)
		arpeggiator.SetArpeggiation(1)
		root=arpeggiator
	End

	Method NoteOn(note:Int,oscillator:Int,envelope:Int)
		root.NoteOn(note,oscillator,envelope)
	End

	Method NoteOff(note:Int)	
		root.NoteOff(note)
	End
	
	Method SetSynth(synth:Int)
		Select synth
			Case 0
				arpeggiator.SetSynth(mono)
			Case 1
				arpeggiator.SetSynth(poly)
		End
	End
	
	Method SetTempo(tempo:Tempo,divisor:Int,duty:V)
		arpeggiator.SetTempo(tempo,divisor,duty)
	End
	
	Method SetArp(arpmode:Int)
		arpeggiator.SetArpeggiation(arpmode)
	End
	
	Method SetHold(hold:Bool)
		arpeggiator.SetHold(hold)
	End

	Method Detune(bend:V)
		detune=bend
	End
	
	Method ClearKeys()
		root.Panic()
	End

	Field buffer:=New Double[FragmentSize*2]

	Method UpdateAudio()
		While True
			Local buffered:=audioPipe.writePointer-audioPipe.readPointer
			If buffered>=WriteAhead Exit
			For Local i:=0 Until FragmentSize*2
				buffer[i]=0
			Next	

			Local samples:=FragmentSize
			vsynth.root.FillAudioBuffer(buffer,samples,detune)			
			Duration+=samples

			Local pointer:=Varptr buffer[0]
			audioPipe.WriteSamples(pointer,FragmentSize*2)
		Wend
	End
			
	Method OpenAudio()
		Local spec:SDL_AudioSpec
		spec.freq=AudioFrequency	
		spec.format = AUDIO_S16
		spec.channels = 2
		spec.samples = FragmentSize
		spec.callback = AudioPipe.Callback
		spec.userdata = audioPipe.Handle()
		
		Mix_CloseAudio()		
		Local error:Int = SDL_OpenAudio(Varptr spec,Varptr audioSpec)		
		If error
			Print "error="+error+" "+String.FromCString(SDL_GetError())
		Else
			Print "Audio Open freq="+audioSpec.freq
			AudioFrequency=audioSpec.freq
		Endif
						
		SDL_PauseAudio(0)
	End

End	

Class VSynthWindow Extends Window

	Const MusicKeys:=New Key[]( Key.Q,Key.A,Key.W,Key.S,Key.E,Key.D,  Key.F,Key.T,Key.G,Key.Y,Key.H,Key.U,Key.J,  Key.K,Key.O,Key.L,Key.P,Key.Semicolon)',Key.Apostrophe )

	Field frame:Int
	Field tick:Int
	Field mousex:Int
	Field mousey:Int
	
	Field synth:Int
	Field oscillator:Int
	Field envelope:Int
	Field octave:Int=5
	
	Field mousebend:V
	Field pitchbend:V=1.0

	Field arp:Int
	Field hold:Bool
	Field div:Int
	Field duty:Int
	Field tempo:Tempo=96
	
	Field keyNoteMap:=New Map<Key,Int>
	
	Field midiInputs:Int
	Field midiOutputs:int

	Method New(title:String)
		Super.New(title,1280,720,WindowFlags.Resizable)				
		For Local i:=0 Until MusicKeys.Length
			keyNoteMap.Set(MusicKeys[i],i-1)
		Next
		vsynth=New VSynth
#If __HOSTOS__="pi"
		ResetMidi()
#endif
	End

	Field portMidi:PortMidi
	
	Method ResetMidi()
		if portMidi portMidi.CloseAll()
		Print "Scanning Midi Bus, please wait."
		portMidi=New PortMidi()
		midiInputs=portMidi.inputDevices.Length
		midiOutputs=portMidi.outputDevices.Length
		Print "Midi bus found "+midiInputs+" inputs and "+midiOutputs+" outputs"
		For Local i:=0 Until midiInputs
			portMidi.OpenInput(i)
		next
	End

	method PollMidi()
		Const NoteOn:=144
		Const NoteOff:=128
		Const Controller:=176
		Const PitchWheel:=224

		While portMidi and portMidi.HasEvent()
			Local b:=portMidi.EventDataBytes()
			Local note:=b[1]
			Local velocity:=b[2]
			Local word:Int=note+(velocity Shl 7)
			Select b[0]
				Case NoteOn
					vsynth.NoteOn(note,oscillator,envelope)
				Case NoteOff
					vsynth.NoteOff(note)
				Case PitchWheel
					pitchbend=1.0+(word-8192)/8192.0
				Case Controller
					OnControl(b[1],b[2])
				default
					Print b[0]+" "+b[1]+" "+b[2]+" "+b[3]
			End					
		Wend
'		portMidi.Sleep(1.0/60)
	End
	
	Method OnRender( display:Canvas ) Override	
	
		PollMidi()
	
		App.RequestRender()	

		vsynth.Detune(pitchbend)
		vsynth.SetArp(arp)
		vsynth.SetHold(hold)
		vsynth.SetTempo(tempo,1+div,DutyCycle[duty])
		vsynth.UpdateAudio()

		Local text:String = About+",,"+Octave1+","+Octave0
		text+=",,Octave=< >="+octave
		text+=",Oscillator=1-5="+OscillatorNames[oscillator]
		text+=",Envelope=[]="+EnvelopeNames[envelope]
		text+=",PitchBend=Mouse Wheel="+FloatString(pitchbend)		
		text+=",,Arpeggiator=F5-F11="+ArpNames[arp]
		text+=",Hold=Tab="+HoldNames[hold]
		text+=",Note Divisor=/="+DivisorNames[div]
		text+=",DutyCycle=Insert="+DutyNames[duty]
		text+=",,Tempo=- +="+tempo
		text+=",,Synth=Enter Key="+SynthNames[synth]
		text+=",,"+Controls		
		text+=",,Midi Inputs "+midiInputs
		text+= ",Midi Outputs "+midiOutputs
		text+=",,"+Contact
		
		display.Color=Color.Black
		display.DrawRect(0,0,400,Height)
		display.Color=Color.Grey

		Local cy:=40
		For Local line:=Eachin text.Split(",")
			Local cx:=50
			For Local tab:=Eachin line.Split("=")
				display.DrawText(tab,cx,cy)
				cx+=100
			Next
			cy+=20
		Next

	End				
	
	Field noteMap:=New IntMap<Bool>
		
	Method KeyDown(key:Key)
		If keyNoteMap.Contains(key)
			KeyUp(key)
			Local note:=keyNoteMap[key]+octave*12
			noteMap[note]=True
			vsynth.NoteOn(note,oscillator,envelope)
		Endif
	End

	Method KeyUp(key:Key)		
		If keyNoteMap.Contains(key)
			For Local octave:=0 Until MaxOctave
				Local note:=keyNoteMap[key]+octave*12
				If noteMap.Contains(note)	
					vsynth.NoteOff(note)
					noteMap.Remove(note)
				Endif
			Next
		Endif
	End

	Method UpdateSequence()
		frame+=1
		Local t:Int=(frame/20)	
		If t<>tick
			Local note:=((t Shr 1)&15)*3+40
			If t&1
				vsynth.NoteOn(note,oscillator,envelope)
			Else
				vsynth.NoteOff(note)			
			Endif
			tick=t
		Endif				
'		Print "tick d="+d
	End
			
	Function Limit:Int(value:Int, lo:Int, hi:Int)
		If value<lo Return lo
		If value>hi Return hi
		Return value
	End
				
	Method OnKeyEvent( event:KeyEvent ) Override	
		Select event.Type
		Case EventType.KeyDown
			Select event.Key
			Case Key.Slash						
				div=Wrap(div+1,0,DivisorNames.Length)				
			Case Key.Insert
				duty=Wrap(duty+1,0,DutyNames.Length)				
			Case Key.Minus
				tempo-=1
			Case Key.Key0
				tempo+=1
			Case Key.F5
				arp=0
			Case Key.F6
				arp=1
			Case Key.F7
				arp=2
			Case Key.F8
				arp=3
			Case Key.F9
				arp=4
			Case Key.F10
				arp=5
			Case Key.F11
				arp=6
			Case Key.Backspace
				ResetMidi()
			Case Key.Tab
				hold=Not hold
			Case Key.Key1
				oscillator=0
			Case Key.Key2
				oscillator=1
			Case Key.Key3
				oscillator=2
			Case Key.Key4
				oscillator=3
			Case Key.Key5
				oscillator=4
			Case Key.Escape
				instance.Terminate()
			Case Key.LeftBracket
				envelope=Wrap(envelope-1,0,EnvelopeNames.Length)
			Case Key.RightBracket
				envelope=Wrap(envelope+1,0,EnvelopeNames.Length)				
			Case Key.Enter
				synth=Wrap(synth+1,0,SynthNames.Length)				
				vsynth.SetSynth(synth)
			Case Key.Comma
				octave=Clamp(octave-1,0,MaxOctave)
			Case Key.Period
				octave=Clamp(octave+1,0,MaxOctave)
			Case Key.Space
				vsynth.ClearKeys()
			Default
				KeyDown(event.Key)
			End
		Case EventType.KeyUp
			Select event.Key
			Case Key.Escape
			Default
				KeyUp(event.Key)
			End
		End
	End

	Field control:=New Int[128]
	
	Method OnControl(index:Int, value:Int)	
	
		local f:=value/128.0
		value-=64

		control[index]=value
		Select index
		Case 14
			tempo=f*256
		Case 16
			ClearColor=New Color(f,ClearColor.G,ClearColor.B)
		Case 17
			ClearColor=New Color(ClearColor.R,f,ClearColor.B)
		Case 18
			ClearColor=New Color(ClearColor.R,ClearColor.G,f)
		case 84
			if value>0 oscillator=Wrap(oscillator+1,0,OscillatorNames.Length)
		case 85
			if value>0 oscillator=Wrap(oscillator-1,0,OscillatorNames.Length)
		Case 3
'			zoom=f/8
		Default
			Print "OnControl:"+index+" "+value
		end
	End
	
	Method OnMouseEvent( event:MouseEvent ) Override	
		mousex=event.Location.X
		mousey=event.Location.Y
		mousebend+=event.Wheel.Y/48.0
		pitchbend=Pow(2,mousebend)
	End
	
End

Function FloatString:String(value:Float,dp:Int=2)
	Local sign:String
	Local integral:=Int(value*(Pow(10,dp)))
	If integral<0 
		sign="-"
		integral=-integral
	Endif
	Local a:String=integral
	Local l:=dp+1-a.Length
	If l>0 a="0000000000000".Slice(0,l)+a
	Local r:=a.Length 
	Return sign+a.Slice(0,r-dp)+"."+a.Slice(r-dp,r)
End

Function Wrap:Int(value:Int,lower:Int,upper:Int)
	If value<lower value=upper-1
	If value>=upper value=lower
	Return value
End

Function Main()
	instance = New AppInstance	
	New VSynthWindow(AppTitle)	
	App.Run()	
End
