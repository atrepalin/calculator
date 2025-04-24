.586
.MODEL flat, stdcall
OPTION CaseMap:None

include C:\masm32\include\windows.inc
include C:\masm32\include\user32.inc
include C:\masm32\include\kernel32.inc
include C:\masm32\include\masm32.inc
include c:\masm32\include\msvcrt.inc

includelib C:\masm32\lib\user32.lib
includelib C:\masm32\lib\kernel32.lib
includelib C:\masm32\lib\masm32.lib
includelib c:\masm32\lib\msvcrt.lib

.DATA
ClassName     DB "CalcClass",0
EditClass     DB "EDIT",0
ButtonClass   DB "BUTTON",0

AppName       DB "FPU Calculator",0

DisplayStr    DB 256 DUP(0)
TmpInput      DB 64 DUP(0)

FormatFloat   DB "%f",0
FormatParse   DB "%lf",0

Buttons       DB "0123456789.+-*/=",0
Clear         DB "Clear",0

.DATA?
hInstance     HINSTANCE ?
hWndEdit      HWND ?
Operand1      REAL8 ?
Operand2      REAL8 ?
LastOp        BYTE ?
X             DWORD ?
Y             DWORD ?

.CODE
start:
    INVOKE GetModuleHandle, NULL
    MOV hInstance, EAX
    call WinMain
    INVOKE ExitProcess, EAX

PrintStack PROC USES EBX
.DATA
    Text          DB "-----FPU Stack-----",13,10,0
    Format        DB "ST(%d) = %lf",13,10,0
    NewLine       DB 13,10,0
    ControlWord   EQU 3F00h

.DATA?
    Tmp           REAL8 ?
    SavedCWord    WORD ?
    UsedCWord     WORD ?

.CODE
    INVOKE crt_printf, ADDR Text

    fclex 
    fstcw SavedCWord 
    fstcw UsedCWord
    or UsedCWord, ControlWord
    fldcw UsedCWord

    mov EBX, 0

    .WHILE EBX < 8
        fstp Tmp
        INVOKE crt_printf, ADDR Format, EBX, Tmp
        fld Tmp
        fincstp

        inc EBX
    .ENDW

    fclex
    fstcw SavedCWord

    INVOKE crt_printf, ADDR NewLine

    ret
PrintStack ENDP

WinMain PROC
    LOCAL msg:MSG
    LOCAL wc:WNDCLASSEX

    MOV wc.cbSize, SIZEOF WNDCLASSEX
    MOV wc.style, CS_HREDRAW or CS_VREDRAW
    MOV wc.lpfnWndProc, OFFSET WndProc
    MOV wc.cbClsExtra, 0
    MOV wc.cbWndExtra, 0
    MOV EAX, hInstance
    MOV wc.hInstance, EAX
    MOV wc.hbrBackground, COLOR_BTNFACE+1
    INVOKE LoadCursor, NULL, IDC_ARROW
    MOV wc.hCursor, EAX
    MOV wc.lpszClassName, OFFSET ClassName
    MOV wc.hIcon, 0
    MOV wc.hIconSm, 0
    MOV wc.lpszMenuName, 0
    INVOKE RegisterClassEx, ADDR wc

    INVOKE CreateWindowEx, 0, ADDR ClassName, ADDR AppName,
           WS_SYSMENU or WS_CLIPCHILDREN or WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT,
           300, 350, 0, 0, hInstance, 0

    INVOKE ShowWindow, EAX, SW_SHOWNORMAL
    INVOKE UpdateWindow, EAX

msg_loop:
    INVOKE GetMessage, ADDR msg, 0, 0, 0
    TEST EAX, EAX
    JZ end_loop
    INVOKE TranslateMessage, ADDR msg
    INVOKE DispatchMessage, ADDR msg
    JMP msg_loop
end_loop:
    MOV EAX, msg.wParam
    RET
WinMain ENDP

CreateButton MACRO txt, id, x, y
    push ECX

    INVOKE CreateWindowEx, 0, ADDR ButtonClass, txt,
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON,
           x, y, 30, 30, hWin, id, hInstance, 0

    pop ECX
ENDM

WndProc PROC hWin:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL buffer[2]:BYTE
    mov buffer[1], 0

    .IF uMsg == WM_CREATE
        INVOKE CreateWindowEx, 0, ADDR EditClass, 0,
               WS_CHILD or WS_VISIBLE or ES_RIGHT or ES_READONLY,
               10, 10, 260, 25, hWin, 1000, hInstance, 0
        MOV hWndEdit, EAX

        lea ESI, Buttons
        mov Y, 50
        mov ECX, 0

        .WHILE Y < 250
            mov X, 50
            .WHILE X < 250
                mov AH, [ESI]
                mov buffer, AH

                CreateButton ADDR buffer, ECX, X, Y

                add X, 50
                inc ESI
                inc ECX
            .ENDW
            add Y, 50
        .ENDW

        INVOKE CreateWindowEx, 0, ADDR ButtonClass, ADDR Clear,
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON,
           50, 250, 180, 30, hWin, 16, hInstance, 0

    .ELSEIF uMsg == WM_COMMAND
        mov EAX, wParam
        and EAX, 0FFFFh

        cmp EAX, 16
        je clear
        cmp EAX, 0
        jl @F
        cmp EAX, 15
        jg @F

        lea ESI, Buttons
        add ESI, EAX
        mov AL, [ESI]
        mov buffer, AL

        cmp AL, '='
        je do_equals

        cmp AL, '+'
        je save_op
        cmp AL, '-'
        je save_op
        cmp AL, '*'
        je save_op
        cmp AL, '/'
        je save_op

        lea EDI, TmpInput
        INVOKE lstrcat, EDI, ADDR buffer
        INVOKE SetWindowText, hWndEdit, EDI
        jmp end_command

clear:
        mov LastOp, 0

        fldz
        fldz
        fstp Operand1
        fstp Operand2

        mov byte ptr TmpInput, 0

        INVOKE SetWindowText, hWndEdit, ADDR TmpInput
        jmp end_command

save_op:
        push EAX
        INVOKE crt_sscanf, ADDR TmpInput, ADDR FormatParse, ADDR Operand1
        pop EAX

        mov LastOp, AL
        mov byte ptr TmpInput, 0

        INVOKE SetWindowText, hWndEdit, ADDR TmpInput
        jmp end_command

do_equals:
        INVOKE crt_sscanf, ADDR TmpInput, ADDR FormatParse, ADDR Operand2

        fld Operand1
        fld Operand2

        call PrintStack

        mov AL, LastOp
        cmp AL, '+'
        je fadd_
        cmp AL, '-'
        je fsub_
        cmp AL, '*'
        je fmul_
        cmp AL, '/'
        je fdiv_

        jmp end_fpu

fadd_:
        fadd
        jmp end_fpu
fsub_:
        fsub
        jmp end_fpu
fmul_:
        fmul
        jmp end_fpu
fdiv_:
        fdiv

end_fpu:
        fstp Operand1
        INVOKE crt_sprintf, ADDR DisplayStr, ADDR FormatFloat, Operand1
        INVOKE lstrcpy, ADDR TmpInput, ADDR DisplayStr
        INVOKE SetWindowText, hWndEdit, ADDR TmpInput

end_command:
@@:

    .ELSEIF uMsg == WM_CLOSE
        INVOKE PostQuitMessage, 0
    .ELSE
        INVOKE DefWindowProc, hWin, uMsg, wParam, lParam
        RET
    .ENDIF
    XOR EAX, EAX
    RET
WndProc ENDP

END start
