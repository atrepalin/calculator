.586
.MODEL flat, stdcall
OPTION CaseMap:None

include C:\masm32\include\windows.inc
include C:\masm32\include\user32.inc
include C:\masm32\include\kernel32.inc
include C:\masm32\include\masm32.inc
include c:\masm32\include\msvcrt.inc
include C:\masm32\include\gdi32.inc

includelib C:\masm32\lib\user32.lib
includelib C:\masm32\lib\kernel32.lib
includelib C:\masm32\lib\masm32.lib
includelib c:\masm32\lib\msvcrt.lib
includelib C:\masm32\lib\gdi32.lib

.DATA
AppName     DB "Function tabulation cos(exp(x)) - sin(x^2)",0
ClassName   DB "MainWinClass",0
ChildClass  DB "ChildWinClass",0

FormatIn    DB "%lf",0
FormatOut   DB "x = %.4lf   f(x) = %.4lf",13,10,0

OutputBuf   DB 8192 DUP(0)
LineBuf     DB 128 DUP(0)

BtnParams   DB "Parameters",0
BtnCalc     DB "Submit",0

EditClass   DB "EDIT",0
ButtonClass DB "BUTTON",0
StaticClass DB "STATIC",0

LabelA      DB "a:",0
LabelB      DB "b:",0
LabelH      DB "h:",0

ErrMsg      DB "Invalid input",0

minScreenX  REAL8 520.0
maxScreenX  REAL8 950.0
minScreenY  REAL8 20.0
maxScreenY  REAL8 450.0

.DATA?
hInstance   HINSTANCE ?
hMainWin    HWND ?
hEditOutput HWND ?

hChildWin   HWND ?
hEditA      HWND ?
hEditB      HWND ?
hEditH      HWND ?
hButtonCalc HWND ?

a           REAL8 ?
b           REAL8 ?
h           REAL8 ?
x           REAL8 ?
fx          REAL8 ?

xCoords         REAL8 512 DUP(?)
yCoords         REAL8 512 DUP(?)
pointsCount     DWORD ?

.CODE

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    call WinMain
    invoke ExitProcess, eax

WinMain PROC
    LOCAL msg:MSG
    LOCAL wc:WNDCLASSEX

    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET MainWndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInstance
    mov wc.hInstance, eax
    mov wc.hbrBackground, COLOR_BTNFACE+1
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    mov wc.lpszClassName, OFFSET ClassName
    mov wc.hIcon, 0
    mov wc.hIconSm, 0
    mov wc.lpszMenuName, 0
    invoke RegisterClassEx, ADDR wc

    mov wc.lpfnWndProc, OFFSET ChildWndProc
    mov wc.lpszClassName, OFFSET ChildClass
    invoke RegisterClassEx, ADDR wc

    invoke CreateWindowEx, 0, ADDR ClassName, ADDR AppName,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        1000, 500,
        NULL, NULL, hInstance, NULL

    mov hMainWin, eax
    invoke ShowWindow, hMainWin, SW_SHOWNORMAL
    invoke UpdateWindow, hMainWin

msg_loop:
    invoke GetMessage, ADDR msg, NULL, 0, 0
    test eax, eax
    jz end_loop

    ; Для дочернего окна
    invoke IsDialogMessage, hChildWin, ADDR msg
    test eax, eax
    jnz msg_loop 

    ; Для основного окна
    invoke IsDialogMessage, hMainWin, ADDR msg
    test eax, eax
    jnz msg_loop 

    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage, ADDR msg
    jmp msg_loop

end_loop:
    mov eax, msg.wParam
    ret
WinMain ENDP

include utils.inc

MainWndProc PROC hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
LOCAL px1, py1, px2, py2:DWORD
LOCAL ps:PAINTSTRUCT
LOCAL hdc:HDC
LOCAL hPenOld:HGDIOBJ
LOCAL hPenNew:HGDIOBJ

.DATA
    RangeFormat     DB "%lf %lf %lf %lf",13,10,0
    MappingFormat   DB "%d %d",13,10,0
    ZERO            REAL8 0.0

.DATA?
    I DWORD ?
    TMP REAL8 ?
    CURRENT_POINT REAL8 ?

    X REAL8 ?
    Y REAL8 ?

    maxX REAL8 ?
    maxY REAL8 ?
    minX REAL8 ?
    minY REAL8 ?

    maximum REAL8 2147483647.0

.CODE 
    .IF uMsg == WM_CREATE
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, 0,
            WS_CHILD or WS_VISIBLE or WS_VSCROLL or ES_MULTILINE or ES_AUTOVSCROLL or ES_READONLY,
            10, 10, 460, 380,
            hWnd, 1001, hInstance, 0
        mov hEditOutput, eax

        invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR BtnParams,
            WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,
            180, 400, 120, 30,
            hWnd, 2001, hInstance, 0
    .ELSEIF uMsg == WM_PAINT
        invoke BeginPaint, hWnd, ADDR ps
        mov hdc, eax

        lea esi, xCoords
        lea edi, yCoords
        mov I, 0
        mov ebx, pointsCount

        fld maximum
        fst maxX
        fst maxY
        fchs
        fst minX
        fstp minY

RANGE_LOOP_START:
            fld qword ptr [esi]
            fstp TMP

            invoke max, TMP, maxX
            fstp maxX

            invoke min, TMP, minX
            fstp minX

            fld qword ptr [edi]
            fstp TMP

            invoke max, TMP, maxY
            fstp maxY

            invoke min, TMP, minY
            fstp minY

            add esi, SIZEOF REAL8
            add edi, SIZEOF REAL8
            inc I

            cmp I, ebx
            jl RANGE_LOOP_START

        invoke crt_printf, addr RangeFormat, minX, maxX, minY, maxY

        lea esi, xCoords
        lea edi, yCoords
        mov I, 0
        mov ebx, pointsCount
        dec ebx

        invoke CreatePen, PS_DASH, 1, 0000000h
        mov hPenNew, eax
        invoke SelectObject, hdc, hPenNew

        invoke floor, minX
        fstp CURRENT_POINT

X_LOOP_START:
            invoke map, CURRENT_POINT, minX, maxX, minScreenX, maxScreenX
            fstp TMP
            invoke to_int, TMP
            mov px1, eax
            mov px2, eax
            mov py1, 20
            mov py2, 450

            invoke MoveToEx, hdc, px1, py1, NULL
            invoke LineTo, hdc, px2, py2

            fld CURRENT_POINT
            fld1
            fadd
            fstp CURRENT_POINT

            less CURRENT_POINT, maxX
            jnc X_LOOP_START


        invoke floor, minY
        fstp CURRENT_POINT

Y_LOOP_START:
            invoke map, CURRENT_POINT, minY, maxY, maxScreenY, minScreenY
            fstp TMP
            invoke to_int, TMP
            mov py1, eax
            mov py2, eax
            mov px1, 520
            mov px2, 950

            invoke MoveToEx, hdc, px1, py1, NULL
            invoke LineTo, hdc, px2, py2

            fld CURRENT_POINT
            fld1
            fadd
            fstp CURRENT_POINT

            less CURRENT_POINT, maxY
            jnc Y_LOOP_START

        invoke DeleteObject, hPenNew
        invoke CreatePen, PS_SOLID, 2, 0000000h
        mov hPenNew, eax
        invoke SelectObject, hdc, hPenNew

        invoke map, ZERO, minX, maxX, minScreenX, maxScreenX
        fstp TMP
        invoke to_int, TMP
        mov px1, eax
        mov px2, eax
        mov py1, 10
        mov py2, 460

        invoke MoveToEx, hdc, px1, py1, NULL
        invoke LineTo, hdc, px2, py2

        invoke map, ZERO, minY, maxY, maxScreenY, minScreenY
        fstp TMP
        invoke to_int, TMP
        mov py1, eax
        mov py2, eax
        mov px1, 510
        mov px2, 960

        invoke MoveToEx, hdc, px1, py1, NULL
        invoke LineTo, hdc, px2, py2


        invoke DeleteObject, hPenNew
        invoke CreatePen, PS_SOLID, 2, 0FF0000h
        mov hPenNew, eax
        invoke SelectObject, hdc, hPenNew

MAPPING_LOOP_START:
            fld qword ptr [esi]
            fstp TMP

            invoke map, TMP, minX, maxX, minScreenX, maxScreenX
            fstp TMP
            invoke to_int, TMP
            mov px1, eax

            fld qword ptr [edi]
            fstp TMP

            invoke map, TMP, minY, maxY, maxScreenY, minScreenY
            fstp TMP
            invoke to_int, TMP
            mov py1, eax

            add esi, SIZEOF REAL8
            add edi, SIZEOF REAL8

            fld qword ptr [esi]
            fstp TMP

            invoke map, TMP, minX, maxX, minScreenX, maxScreenX
            fstp TMP
            invoke to_int, TMP
            mov px2, eax

            fld qword ptr [edi]
            fstp TMP

            invoke map, TMP, minY, maxY, maxScreenY, minScreenY
            fstp TMP
            invoke to_int, TMP
            mov py2, eax

            inc I
            
            invoke crt_printf, addr MappingFormat, px1, py1
            invoke crt_printf, addr MappingFormat, px2, py2

            invoke MoveToEx, hdc, px1, py1, NULL
            invoke LineTo, hdc, px2, py2

            cmp I, ebx
            jl MAPPING_LOOP_START

        invoke SelectObject, hdc, hPenOld
        invoke DeleteObject, hPenNew
        invoke EndPaint, hWnd, ADDR ps
    .ELSEIF uMsg == WM_COMMAND
        mov eax, wParam
        and eax, 0FFFFh

        .IF eax == 2001
            invoke CreateWindowEx, WS_EX_DLGMODALFRAME, ADDR ChildClass, ADDR BtnParams,
                WS_VISIBLE or WS_POPUPWINDOW or WS_CAPTION,
                100, 100, 300, 220,
                hWnd, NULL, hInstance, NULL
            mov hChildWin, eax
        .ENDIF

    .ELSEIF uMsg == WM_CLOSE
        invoke DestroyWindow, hWnd
    .ELSEIF uMsg == WM_DESTROY
        invoke PostQuitMessage, 0
    .ELSE
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .ENDIF
    xor eax, eax
    ret
MainWndProc ENDP

ChildWndProc PROC hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
.DATA
    two         REAL8 2.0
    zero        REAL8 0.0
    buffer      DB 64 DUP(0)

.CODE
    .IF uMsg == WM_CREATE
        invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelA,
            WS_CHILD or WS_VISIBLE,
            20, 20, 20, 20,
            hWnd, 0, hInstance, 0
        invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelB,
            WS_CHILD or WS_VISIBLE,
            20, 60, 20, 20,
            hWnd, 0, hInstance, 0
        invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelH,
            WS_CHILD or WS_VISIBLE,
            20, 100, 20, 20,
            hWnd, 0, hInstance, 0

        invoke CreateWindowEx, 0, ADDR EditClass, 0,
            WS_CHILD or WS_VISIBLE or WS_BORDER or WS_TABSTOP or ES_AUTOHSCROLL,
            50, 20, 100, 20,
            hWnd, 3001, hInstance, 0
        mov hEditA, eax

        invoke CreateWindowEx, 0, ADDR EditClass, 0,
            WS_CHILD or WS_VISIBLE or WS_BORDER or WS_TABSTOP or ES_AUTOHSCROLL,
            50, 60, 100, 20,
            hWnd, 3002, hInstance, 0
        mov hEditB, eax

        invoke CreateWindowEx, 0, ADDR EditClass, 0,
            WS_CHILD or WS_VISIBLE or WS_BORDER or WS_TABSTOP or ES_AUTOHSCROLL,
            50, 100, 100, 20,
            hWnd, 3003, hInstance, 0
        mov hEditH, eax

        invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR BtnCalc,
            WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,
            100, 140, 80, 30,
            hWnd, 4001, hInstance, 0
        mov hButtonCalc, eax

        invoke SendMessage, hWnd, DM_SETDEFID, 4001, 0
    .ELSEIF uMsg == WM_COMMAND
        mov eax, wParam
        and eax, 0FFFFh
        .IF eax == 4001
            reset a
            reset b
            reset h

            invoke GetWindowText, hEditA, ADDR buffer, 64
            invoke crt_sscanf, ADDR buffer, ADDR FormatIn, ADDR a

            invoke GetWindowText, hEditB, ADDR buffer, 64
            invoke crt_sscanf, ADDR buffer, ADDR FormatIn, ADDR b

            invoke GetWindowText, hEditH, ADDR buffer, 64
            invoke crt_sscanf, ADDR buffer, ADDR FormatIn, ADDR h
            
            less h, zero
            jnc error
            less b, a
            jnc error

            mov byte ptr OutputBuf, 0
        
            ; x = a(h)b+h/2
            fld a
            fstp x

            fld b
            fld h
            fld two
            fdiv
            fadd
            fstp b ; b = b + h/2

            lea esi, xCoords
            lea edi, yCoords
            mov pointsCount, 0
tab_loop:
            ; f(x) = cos(exp(x)) - sin(x^2)
            invoke exp, x

            fcos

            invoke pow, x, two

            fsin 

            fsub 
            fstp fx

            fld x
            fstp qword ptr [esi]

            fld fx
            fstp qword ptr [edi]

            add esi, SIZEOF REAL8
            add edi, SIZEOF REAL8

            inc pointsCount

            invoke crt_sprintf, ADDR LineBuf, ADDR FormatOut, x, fx
            invoke lstrcat, ADDR OutputBuf, ADDR LineBuf

            fld x
            fld h
            fadd
            fstp x

            ; x < b + h/2
            less x, b
            jnc tab_loop

            invoke SetWindowText, hEditOutput, ADDR OutputBuf
            invoke DestroyWindow, hWnd
            invoke InvalidateRect, hMainWin, NULL, TRUE

            jmp tab_end
error:
            invoke MessageBox, hWnd, ADDR ErrMsg, ADDR AppName, MB_OK
tab_end:
        .ENDIF

    .ELSEIF uMsg == WM_CLOSE
        invoke DestroyWindow, hWnd
    .ELSE
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .ENDIF
    xor eax, eax
    ret
ChildWndProc ENDP

END start
