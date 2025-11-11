;============================================================
; STM32F103C8 - ARM Cortex-M3 (Thumb-2)
; Proyecto: Generación y ordenamiento de números aleatorios
; Autor: Cabrera Aguilar Fabián
;============================================================
; Funcionalidad:
;  - PC0, PC1: Entradas de menú
;  - PC13: LED indicador
;  - Genera 100 números aleatorios (LCG)
;  - Ordena arreglo en SRAM (Bubble Sort)
;  - Usa banderas en SRAM:
;       0x20000000 -> FLAG_GEN
;       0x20000004 -> FLAG_SORT
;============================================================

        AREA |.text|, CODE, READONLY
        THUMB
        EXPORT  reset_handler
        EXPORT  main

;------------------------------------------------------------
; --- Direcciones de periféricos ---
RCC_APB2ENR     EQU    0x40021018
GPIOC_BASE      EQU    0x40011000
GPIOC_CRL       EQU    GPIOC_BASE + 0x00
GPIOC_CRH       EQU    GPIOC_BASE + 0x04
GPIOC_IDR       EQU    GPIOC_BASE + 0x08
GPIOC_ODR       EQU    GPIOC_BASE + 0x0C

;------------------------------------------------------------
; --- Direcciones de SRAM ---
FLAG_GEN_ADDR   EQU    0x20000000
FLAG_SORT_ADDR  EQU    0x20000004
SEED_ADDR       EQU    0x20000008
ARRAY_BASE      EQU    0x20000100
COUNT           EQU    100

;------------------------------------------------------------
; --- Constantes LCG ---
LCG_A           EQU    1664525
LCG_C           EQU    1013904223

;------------------------------------------------------------
reset_handler
        BL      main_asm
        B       .

main
        B       reset_handler

;============================================================
; --- Rutina principal ---
;============================================================
main_asm
        PUSH    {r4-r7, lr}

        ; Inicializa banderas
        LDR     r0, =FLAG_GEN_ADDR
        MOVS    r1, #0
        STR     r1, [r0]
        LDR     r0, =FLAG_SORT_ADDR
        STR     r1, [r0]

        ; Semilla inicial fija
        LDR     r0, =SEED_ADDR
        LDR     r1, =0xDEADBEEF
        STR     r1, [r0]

        ; Configurar GPIOC
        BL      init_portc
        BL      led_off

main_loop
        BL      read_inputs         ; r0 = 0..3 (PC1:PC0)
        CMP     r0, #0
        BEQ     state_idle
        CMP     r0, #1
        BEQ     state_generate
        CMP     r0, #2
        BEQ     state_sort
        B       state_idle

;------------------------------------------------------------
; Estado 00: IDLE (Inicio)
;------------------------------------------------------------
state_idle
        BL      led_off
        B       main_loop

;------------------------------------------------------------
; Estado 01: Generar aleatorios
;------------------------------------------------------------
state_generate
        LDR     r0, =FLAG_GEN_ADDR
        LDR     r1, [r0]
        CMP     r1, #1
        BEQ     gen_wait_input

        BL      generate_randoms
        BL      led_on
        MOVS    r1, #1
        STR     r1, [r0]            ; FLAG_GEN = 1

gen_wait_input
        BL      read_inputs
        CMP     r0, #0
        BEQ     state_idle
        B       main_loop

;------------------------------------------------------------
; Estado 10: Ordenar (Bubble Sort)
;------------------------------------------------------------
state_sort
        LDR     r0, =FLAG_GEN_ADDR
        LDR     r1, [r0]
        CMP     r1, #1
        BNE     state_idle

        BL      sort_array
        BL      led_on
        LDR     r0, =FLAG_SORT_ADDR
        MOVS    r1, #1
        STR     r1, [r0]

wait_sort
        BL      read_inputs
        CMP     r0, #0
        BEQ     state_idle
        B       wait_sort

;============================================================
; --- Configura GPIOC ---
; PC0, PC1 = entrada pull-down
; PC13 = salida push-pull
;============================================================
init_portc
        LDR     r0, =RCC_APB2ENR
        LDR     r1, [r0]
        ORR     r1, r1, #(1 << 4)       ; Habilita GPIOC
        STR     r1, [r0]

        ; PC0 y PC1 -> Input pull-down
        LDR     r0, =GPIOC_CRL
        MOVS    r1, #0x88
        STR     r1, [r0]

        ; PC13 -> Output push-pull
        LDR     r0, =GPIOC_CRH
        LDR     r1, [r0]
        BIC     r1, r1, #(0xF << 20)
        ORR     r1, r1, #(0x1 << 20)
        STR     r1, [r0]

        ; Asegurar pull-downs
        LDR     r0, =GPIOC_ODR
        BIC     r1, r1, #0x03
        STR     r1, [r0]
        BX      lr

;============================================================
; --- Lectura de entradas PC0-PC1 ---
; Devuelve en r0: valor 0..3
;============================================================
read_inputs
        LDR     r1, =GPIOC_IDR
        LDR     r0, [r1]
        ANDS    r0, r0, #0x03
        BX      lr

;============================================================
; --- LED Control ---
;============================================================
led_on
        LDR     r1, =GPIOC_ODR
        LDR     r2, [r1]
        ORR     r2, r2, #(1 << 13)
        STR     r2, [r1]
        BX      lr

led_off
        LDR     r1, =GPIOC_ODR
        LDR     r2, [r1]
        BIC     r2, r2, #(1 << 13)
        STR     r2, [r1]
        BX      lr

;============================================================
; --- Generador LCG de 100 números aleatorios ---
; x_{n+1} = (a*x + c)
;============================================================
generate_randoms
        PUSH    {r4-r7, lr}
        LDR     r4, =ARRAY_BASE
        MOVS    r5, #0

gen_loop
        LDR     r0, =SEED_ADDR
        LDR     r1, [r0]
        LDR     r2, =LCG_A
        MUL     r1, r1, r2
        LDR     r2, =LCG_C
        ADD     r1, r1, r2
        STR     r1, [r0]           ; Actualiza semilla

        ADD     r6, r4, r5, LSL #2
        STR     r1, [r6]           ; Guarda en arreglo

        ADDS    r5, r5, #1
        CMP     r5, #COUNT
        BLT     gen_loop
        POP     {r4-r7, pc}

;============================================================
; --- Bubble Sort Optimizado ---
; Ordena ARRAY_BASE[COUNT]
;============================================================
sort_array
        PUSH    {r4-r11, lr}
        LDR     r4, =ARRAY_BASE

        MOVS    r5, #0              ; i = 0
outer_loop
        CMP     r5, #COUNT
        BGE     sort_done

        MOVS    r6, #0              ; j = 0
        MOVS    r7, #COUNT
        SUBS    r7, r7, r5
        SUBS    r7, r7, #1          ; n-i-1

inner_loop
        CMP     r6, r7
        BGE     next_outer

        ADD     r8, r4, r6, LSL #2  ; addr[j]
        LDR     r9, [r8]            ; val1
        LDR     r10, [r8, #4]       ; val2

        CMP     r9, r10
        BLE     no_swap

        STR     r10, [r8]
        STR     r9, [r8, #4]

no_swap
        ADDS    r6, r6, #1
        B       inner_loop

next_outer
        ADDS    r5, r5, #1
        B       outer_loop

sort_done
        POP     {r4-r11, pc}

        END
