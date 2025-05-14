less MACRO a, b
    fld a
    fld b
    fcompp 
    fstsw ax
    sahf
ENDM

reset MACRO var
    mov dword ptr var, 0
    mov dword ptr var+4, 0
ENDM

floor PROC var:REAL8
.DATA 
    ControlWord   EQU 0C00h

.DATA?
    SavedCWord    WORD ?
    UsedCWord     WORD ?

.CODE
    fclex 

    fstcw SavedCWord 
    fstcw UsedCWord
    or UsedCWord, ControlWord 

    fldcw UsedCWord

    fld var
    frndint

    fstcw SavedCWord

    ret
floor ENDP

print_stack PROC USES EBX
.DATA
    Text          DB "-----FPU Stack-----",13,10,0
    Format        DB "ST(%d) = %lf",13,10,0
    NewLine       DB 13,10,0

.DATA?
    tmp           REAL8 ?

.CODE
    INVOKE crt_printf, ADDR Text
    mov EBX, 0

    .WHILE EBX < 8
        fst tmp
        INVOKE crt_printf, ADDR Format, EBX, tmp
        fincstp

        inc EBX
    .ENDW

    INVOKE crt_printf, ADDR NewLine

    ret
print_stack ENDP

pow2 PROC power:REAL8
.DATA?
    temp          REAL8 ?
    trash         REAL8 ?

.CODE
    fld power
    fld1
    fscale              ; ST(0) = 2^⌊power⌋

    fstp temp
    fstp trash
    fld temp

    fld power
    invoke floor, power
    fsub                ; d = power - ⌊power⌋

    f2xm1               ; ST(1) = 2^d - 1

    fld1
    fadd                ; ST(1) = 2^d

    fmul                ; ST(0) = 2^⌊power⌋ * 2^d = 2^power

    call print_stack

    ret
pow2 ENDP

exp PROC power:REAL8
.DATA?
    var           REAL8 ?

.CODE
    fld power
    fldl2e
    fmul                
    fstp var            ; var = power * log2(e)

    invoke pow2, var

    ret
exp ENDP

pow PROC base:REAL8, power:REAL8
.DATA?
    int_exponent  DWORD ?

.CODE
    fld power
    fld base
    fabs
    fyl2x               
    fstp temp           ; temp = log2(|base|) * power
    
    invoke pow2, temp   ; pow = |base|^power

    fld base
    fldz

    fcompp 
    fstsw ax
    sahf
    je zero_base
    jnc negative_base

    jmp proc_end        ; base > 0 => pow = pow

zero_base:              ; base = 0 => pow = 0
    fstp temp
    fldz
    jmp proc_end

negative_base:          ; base < 0
    fld power
    invoke floor, power

    fsub

    fldz
    fcompp 
    fstsw ax
    sahf
    jne domain_error    

    fld power
    fistp int_exponent

    mov     eax, int_exponent
    test    eax, 1      
    jz      even_power

    fchs                ; pow = -pow
    jmp proc_end

even_power:             ; power - четное
    jmp proc_end        ; pow = pow

domain_error:           ; power != ⌊power⌋
    fstp temp
    fldz
    fldz
    fdiv                ; pow = oo

proc_end:
    ret
pow ENDP