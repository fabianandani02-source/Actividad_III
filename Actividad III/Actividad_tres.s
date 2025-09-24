; stm32f103c8 - arm cortex-m3
; programa en ensamblador (keil) para:
; - leer 2 pines de gpioc (pc0, pc1) como entrada (menú)
; - controlar led en pc13 (salida)
; - generar 100 números pseudoaleatorios en sram a partir de 0x20000100
; - ordenarlos en la misma área de memoria
; - registrar banderas en sram (0x20000000: generado, 0x20000004: ordenado)
;
; notas:
; - se asume que la placa usa gpioc y que led está en pc13 (como en "main.c" provisto).
; - lcg usado: x_{n+1} = a*x + c  (a=1664525, c=1013904223)
; - ordenamiento: bubble sort (suficiente para 100 elementos en fines educativos)
; ensamblador compatible con keil (arm/thumb)

	area |.text|, code, readonly
	thumb
	export  reset_handler
	entry

; direcciones de periféricos (stm32f1)
rcc_apb2enr    equ 0x40021018
gpioc_base     equ 0x40011000
gpioc_crl      equ gpioc_base + 0x00
gpioc_crh      equ gpioc_base + 0x04
gpioc_idr      equ gpioc_base + 0x08
gpioc_odr      equ gpioc_base + 0x0c

; direcciones sram y banderas
flag_gen_addr  equ 0x20000000    ; 0 = no generado, 1 = generados
flag_sort_addr equ 0x20000004    ; 0 = no ordenado, 1 = ordenados
seed_addr      equ 0x20000008    ; seed para lcg
array_base     equ 0x20000100    ; base donde guardar los 100 uint32
count          equ 100

; constantes para lcg
lcg_a          equ 1664525
lcg_c          equ 1013904223

; ------------------------- reset / inicio ---------------------------------
reset_handler
        ; inicialización básica de la pila/arquitectura asumida por keil (startup de c)
        ; aquí solo llamamos a nuestro main_asm
	bl      main_asm

; ------------------------- main_asm ---------------------------------------
; bucle principal: inicializa gpioc, apaga led e inspecciona entradas para elegir opción
main_asm
	push    {r4-r7,lr}

        ; inicializar banderas en 0
	ldr     r0, =flag_gen_addr
	movs    r1, #0
	str     r1, [r0]
	ldr     r0, =flag_sort_addr
	str     r1, [r0]

        ; inicializar seed con valor fijo (puede cambiarse)
	ldr     r0, =seed_addr
	ldr     r1, =0xdeadbeef
	str     r1, [r0]

	bl      init_portc

        ; asegurar led apagado (pc13 = 0)
	bl      led_off

main_loop
	bl      read_inputs     ; devuelve en r0 valor 0..3 (bits: pc1 pc0)
	cmp     r0, #0
	beq     state_start     ; "00" -> inicio
	cmp     r0, #1
	beq     state_gen       ; "01" -> generar
	cmp     r0, #2
	beq     state_checksort ; "10" -> ordenar o verificar bandera
        ; otros (11) -> no definido, permanecer en inicio
	b       state_start

; ------------------------- estado: inicio (00) -----------------------------
state_start
        ; led apagado
	bl      led_off
        ; no cambiamos banderas
	b       main_loop

; ------------------------- estado: generar (01) ---------------------------
state_gen
        ; generar 100 números pseudoaleatorios y almacenarlos si no se han generado ya
	ldr     r0, =flag_gen_addr
	ldr     r1, [r0]
	cmp     r1, #1
	beq     keep_in_gen     ; si ya generados, no volver a generar pero permanecer en opcion 01

	bl      generate_randoms
        ; encender led y marcar bandera
	bl      led_on
	ldr     r0, =flag_gen_addr
	movs    r1, #1
	str     r1, [r0]

keep_in_gen
        ; si entradas se vuelven "00", regresar al inicio. en caso contrario, permanecer en opción 01.
	bl      read_inputs
	cmp     r0, #0
	beq     state_start
	b       main_loop

; ------------------------- estado: check/sort (10) ------------------------
state_checksort
        ; verificar bandera de generación
	ldr     r0, =flag_gen_addr
	ldr     r1, [r0]
	cmp     r1, #1
	bne     state_start     ; si no generados, regresar al inicio

        ; si generados, proceder a ordenar
	bl      sort_array
        ; encender led y marcar bandera de ordenado
	bl      led_on
	ldr     r0, =flag_sort_addr
	movs    r1, #1
	str     r1, [r0]

        ; permanecer en opción 10 hasta que entradas sean "00"
	bl      read_inputs
	cmp     r0, #0
	beq     state_start
	b       main_loop

; ------------------------- inicializar gpioc -------------------------------
; configura pc0, pc1 como entradas con pull-down (modo 00 con cnf=10 no pushpull).
; configura pc13 como salida push-pull (modo 01 cnf=00 -> 0x2).
init_portc
        ; habilitar reloj para gpioc: apb2enr bit iopcen = bit 4
	ldr     r0, =rcc_apb2enr
	ldr     r1, [r0]
	movs    r2, #1
	lsl     r2, r2, #4          ; r2 = 1<<4
	orr     r1, r1, r2
	str     r1, [r0]

        ; configurar crl (pc0-pc7) para pc0 y pc1 (bits 0..7)
        ; para entradas con pull-down: mode=00 cnf=10 -> 0b10 -> value 0x8 for 4-bit field? let's compute:
        ; para input pull-down: mode=00, cnf=10 -> bits = 0b1000 = 8
	ldr     r0, =gpioc_crl
	ldr     r1, [r0]
        ; clear fields for pc0 and pc1 (4 bits each)
	movs    r2, #0xff
	bic     r1, r1, r2
        ; set pc0 and pc1 to 0b1000 each -> combine 0x88
	orr     r1, r1, #0x88
	str     r1, [r0]

        ; configurar crh para pc13 (pin 13 -> field at bits (13-8)*4 = 20..23)
	ldr     r0, =gpioc_crh
	ldr     r1, [r0]
        ; clear bits 20..23
	movs    r2, #(0xf << 20)
	bic     r1, r1, r2
        ; set mode=01 (output 10mhz) cnf=00 -> 0b0001 -> value 0x1 for field
	orr     r1, r1, #(0x1 << 20)
	str     r1, [r0]

        ; asegurar pull-down para pc0, pc1: escribir en odr = 0 para indicar pull-down when input pull-up/down
	ldr     r0, =gpioc_odr
	ldr     r1, [r0]
	bic r1, r1, #0x03
	str     r1, [r0]

	bx      lr

; ------------------------- leer entradas ----------------------------------
; devuelve en r0 el valor combinado: bit1 = pc1, bit0 = pc0 -> 0..3
read_inputs
	push    {r4,lr}
	ldr     r1, =gpioc_idr
	ldr     r2, [r1]
        ; extraer bit0 y bit1
	ands    r2, r2, #0x3
	mov     r0, r2
	pop     {r4,pc}

; ------------------------- led on/off ------------------------------------
led_on
	push    {r4,lr}
	ldr     r1, =gpioc_odr
	ldr     r2, [r1]
	orr     r2, r2, #(1<<13)
	str     r2, [r1]
	pop     {r4,pc}

led_off
	push    {r4,lr}
	ldr     r1, =gpioc_odr
	ldr     r2, [r1]
	bic     r2, r2, #(1<<13)
	str     r2, [r1]
	pop     {r4,pc}

; ------------------------- generar 100 números pseudoaleatorios -------------
; usa lcg y almacena 100 uint32 a partir de array_base
generate_randoms
	push    {r4-r6,lr}
	ldr     r4, =array_base   ; base ptr
	movs    r5, #0            ; contador i = 0

gen_loop
        ; cargar seed
	ldr     r0, =seed_addr
	ldr     r1, [r0]
        ; r1 = seed
        ; multiplicar por a: r1 = r1 * lcg_a
	ldr r2, =1664525
	mul     r1, r1, r2        ; r1 = seed * a
        ; sumar c
	ldr     r2, =lcg_c
	ldr     r2, [r2]
	adds    r1, r1, r2
        ; guardar nuevo seed
	str     r1, [r0]
        ; almacenar en memoria: *(base + i*4) = r1
	mov     r0, r4
	mov     r2, r5
	lsls    r2, r2, #2        ; r2 = i*4
	adds    r0, r0, r2
	str     r1, [r0]

        ; incrementar i
	adds    r5, r5, #1
	cmp     r5, #count
	blt     gen_loop

	pop     {r4-r6,pc}

; ------------------------- ordenar arreglo (bubble sort) -------------------
; ordena count elementos (100) en base array_base, inplace
sort_array
	push    {r4-r11,lr}
	ldr     r4, =array_base   ; base
	movs    r5, #0            ; i = 0

outer_loop
        ; if i >= count-1 -> done
	movs    r6, #1
	ldr     r7, =count
	ldr     r7, [r7]
	subs    r7, r7, r6       ; count-1
	cmp     r5, r7
	bge     sort_done

        ; j = 0
	movs    r6, #0

inner_loop
        ; if j >= count - i - 1 -> break
	ldr     r7, =count
	ldr     r7, [r7]
	subs    r7, r7, r5
	subs    r7, r7, #1       ; count - i - 1
	cmp     r6, r7
	bge     end_inner

        ; addr1 = base + j*4
	mov     r0, r4
	mov     r1, r6
	lsls    r1, r1, #2
	adds    r0, r0, r1
	ldr     r8, [r0]         ; val1

        ; addr2 = base + (j+1)*4
	adds    r1, r1, #4
	adds    r9, r4, r1
	ldr     r9, [r9]         ; val2

        ; comparar val1 y val2
	cmp     r8, r9
	ble     no_swap

        ; swap
        ; store val2 at addr1
	mov     r2, r4
	mov     r3, r6
	lsls    r3, r3, #2
	adds    r2, r2, r3
	str     r9, [r2]
        ; store val1 at addr2
	adds    r2, r2, #4
	str     r8, [r2]

no_swap
        ; j++
	adds    r6, r6, #1
	b       inner_loop

end_inner
        ; i++
	adds    r5, r5, #1
	b       outer_loop

sort_done
	pop     {r4-r11,pc}

	b reset_handler
	
	end
