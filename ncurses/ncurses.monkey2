' ncurses.monkey2

' linux console control for monkey2
' sudo apt-get install ncurses-dev
' http://www.tldp.org/HOWTO/html_single/NCURSES-Programming-HOWTO/

#Import "<libc>"
#Import "<libncurses.a>"

#Import "<ncurses.h>"

Extern

struct mmask_t
end

struct MEVENT
	field id:short
	field x:int
	field y:int
	field z:int
	field bstate:mmask_t
end

class WINDOW extends void
end

const ALL_MOUSE_EVENTS:mmask_t

const OK:int

const A_STANDOUT:int
const A_UNDERLINE:int
const A_REVERSE:int
const A_PROTECT:int
const A_INVIS:int
const A_DIM:int
const A_BOLD:int
const A_BLINK:int
const A_ALTCHARSET:int

const A_ATTRIBUTES:int
const A_CHARTEXT:int
const A_COLOR:int

global COLS:int
global LINES:int

const KEY_MOUSE:int
const KEY_DOWN:int
const KEY_UP:int
const KEY_LEFT:int
const KEY_RIGHT:int
const KEY_HOME:int
const KEY_BACKSPACE:int
const KEY_DC:int
const KEY_IC:int
const KEY_ENTER:int
const KEY_F1:int
const KEY_F2:int
const KEY_F3:int

const COLOR_BLACK:int
const COLOR_BLUE:int
const COLOR_GREEN:int
const COLOR_CYAN:int
const COLOR_RED:int
const COLOR_MAGENTA:int
const COLOR_YELLOW:int
const COLOR_WHITE:int

Function initscr()
Function noecho()
Function echo()
Function raw()
Function noraw()
Function printw:Int(text:CString)
Function refresh:Int()
function clear:int()
Function getch:Int()
function curs_set(cursor:int)

function use_default_colors:int()
function assume_default_colors:int(fg:int, bg:int)
function has_colors:bool()
function start_color:int()
function init_pair:int(pair:short, fg:short, bg:short)
function can_change_color:bool()
function init_color(color:Short, r:short, g:short, b:short)

function newwin:WINDOW(w:int,h:int,x:int,y:int)
function wclear(window:WINDOW)
function wrefresh(window:WINDOW)
function box(window:WINDOW,a:int,b:int)
function wprintw(window:WINDOW,text:CString)
function mvwprintw(window:WINDOW,x:int,y:int,text:CString)
function delwin(window:WINDOW)
Function wgetch:Int(window:WINDOW)
Function endwin:Int()

function wattron(window:WINDOW,attribute:int)
function wattroff(window:WINDOW,attribute:int)

function keypad(window:WINDOW,enable:bool)

function getmouse:int(event:MEVENT ptr)

function mousemask:mmask_t(events:mmask_t, oldmask:mmask_t ptr)

function COLOR_PAIR:int(pair:short)

Public

Function Main()

	initscr()
	noecho()
	curs_set(0)

	start_color()
'	assume_default_colors(8,-1)
'	use_default_colors()	

	local w:=newwin(10,32,4,(COLS-32)/2)
	local p:=init_pair(1, COLOR_GREEN, COLOR_BLACK)

	wattron(w,COLOR_PAIR(0))

	local oldmask:mmask_t
	local newmask:=mousemask(ALL_MOUSE_EVENTS, varptr oldmask)



	box(w,0,0)
	mvwprintw(w,3,2,"ncurses test has_colors="+(has_colors()?"true"else"false"))
	mvwprintw(w,4,2,"can_change_colors="+(can_change_color()?"true"else"false"))
	wattron(w,A_BOLD)
	mvwprintw(w,6,2,"("+LINES+","+COLS+")")
	wattroff(w,A_BOLD)
	mvwprintw(w,8,2,"Escape To Quit")

	wrefresh(w)

	keypad(w,true)

	local e:MEVENT
	
	while true
		local key:=wgetch(w)
		mvwprintw(w,6,2,"key="+key)
		if key=27 exit
		if key=113 exit
		if key=KEY_MOUSE
			local r:=getmouse(varptr e)
			if r=OK
				local bits:int'=e.bstate
				mvwprintw(w,6,2,"mouse="+e.id+","+e.x+","+e.y+","+e.z+","+bits)
'				mvwprintw(w,6,2,"mouse="+e.id)
			endif
		endif
	wend
	endwin()
End
