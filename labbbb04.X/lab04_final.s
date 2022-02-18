; Archivo:     lab04_final.S
; Dispositivo: PIC166F887
; Autor:       Alba Rodas
; Compilador:  pic-as (v2.30), MPLABX V5.40
; 
; Programa:    Contador binario de 4bits, cada 100ms + contador de 1s + reinicio cuando DISPLAY y contador 1s sean iguales
; Hardware:    PIC, LEDs.
;
; Creado: 06 feb, 2022
; Última modificación: 18 feb, 2022
    
 PROCESSOR 16F887
 #include <xc.inc>
 
;configuration word 1
  CONFIG FOSC=INTRC_NOCLKOUT //oscilador interno --> reloj interno..
  CONFIG WDTE=OFF // WDT disables  (reinicia repetitivamente el PIC)
  CONFIG PWRTE=ON // PWRT enabled (se espera 72ms al empezar el funcionamiento)
  CONFIG MCLRE=OFF // El pin MCLR de utiliza como INPUT/OUTPUT
  CONFIG CP=OFF // Sin proteccion de codigo
  CONFIG CPD=OFF // Sin protección de datos
  CONFIG BOREN=OFF //Se desabilita/OFF para que cuando exista una baja de voltaje <4V, no haya reinicio
  CONFIG IESO=OFF // Se establece un reinicio sin cambiar del reloj interno al externo
  CONFIG FCMEN=OFF // Si existiera un fallo, se configura el cambio de reloj de externo a interno
  CONFIG LVP=ON // Se permite el desarrollo de la programacion, incluso en bajo voltaje
  
 ;configuration word 2
  CONFIG WRT=OFF // Se programa como desactivada la protección de autoescritura 
  CONFIG BOR4V=BOR40V // Se programa reinicio cuando el voltaje sea menor a 4V

// RESET:
  reset_tmr0 macro
    banksel TMR0  
    movlw 217	    ; VALOR = 256 - ((20ms*4Mhz)/4(256)) = 217
    movwf TMR0	    ; ALMACENO VALORES EN TMR0
    bcf	  T0IF	    ; LIMPIO BANDERAS PARA TMR0
    endm	    ; TERMINO EL MACRO

// EQUIVALENCIAS (VIDEO EN CLASE):
  UP EQU 0
  DOWN EQU 1
 
// VARIABLES A UTILIZAR:
 PSECT udata_bank0 ; common memory
    counter:		DS  1	; 1 byte de tamaño
    variable_unidades:	DS  1	; 1 byte de tamaño
    variable_decenas:	DS  1	; 1 byte de tamaño
    
// VARIABLES DE INTERRUPCIONES:
 PSECT udata_shr ; common memory --> udata_shr vista en clase.
    W_TEMP:		DS  1	; 1 byte --> 'temporary holding registers'
    STATUS_TEMP:	DS  1	; 1 byte --> 'temporary holding registers'

 ;------------------CONFIG. VECTOR RESET--------------------
 PSECT resVect, class=CODE, abs, delta=2
 ORG 00h	; posicion 0000h para vector de reset
 resetVec:
     PAGESEL main
     goto main
      
 ;-------------CONFIG. INTERRUPCIONES--------------    
 ORG 04h    ;POSICION 0004h PARA LAS INTERRUPCIONES
 
 PUSH:			; Se guarda el 'Program Counter' en la memory
    movwf   W_TEMP	; Copio W al registro 'TEMP' 
    swapf   STATUS, w	; Swap status, se guarda en W.
    movwf   STATUS_TEMP	; Guardo el STATUS en el banco 00 del STATUS_TEMP register.
    
    // -----------------------------TÉRMINOS USADOS--------------------------  
    // w = 'working register' (accumulador).
 ISR:			; RUTINA DE INTERRUPCION
    btfsc   T0IF	; Verifico la bandera de inerrupcion del tmr0
    call    counter_tmr0
    btfsc   RBIF	; Hay salto, si la bandera de cambio de 'B' está en cero. 
			; El RBIF bit se limpia co RESET, pero se reestablece, si hay un 'mismatch'.
			; mismatch exists.
    call    int_iocb	; Llamo a subrutinas de incrementar/decrementar para los push-buttons
 
 POP:
    swapf   STATUS_TEMP, w  ; Hago un 'swap' de nibbles al STATUS
    movwf   STATUS	; Muevo W al registro de STATUS --> (Devuelve al banco a su esstado original)
    swapf   W_TEMP, F	; Swap W_TEMP
    swapf   W_TEMP, w	; Swap W_TEMP en W
    retfie  ; W HACE 'POP' CUANDO SE LLAMA A UN RETURN, RETLW O UN RETFIE.
     
    // -----------------------------TÉRMINOS USADOS--------------------------
    // RETFIE = 'Return from interrupt'
    // SWAPF = 'Swap nibbles in f'
    // MOVWF = Move W TO f
    
 ;--------------------- subrutinas de interrupcion ---------------------
 // NOTA IMPORTANTE PARA 'INTERRUPT - ON - CHANGE:
 /*For enabled interrupt-on-change pins, the present value is compared with the old value latched on the last read
of PORTB to determine which bits have changed or mismatched the old value. The ?mismatch? outputs of the last read are OR?d together to set the PORTB
Change Interrupt flag bit (RBIF) in the INTCON register.*/
 
 int_iocb:	;DISPONIBLES => BITS DEL 7-0	
    banksel PORTB
    btfss   PORTB, UP	; LE DIGO 'SALTAR' SI EL PIN 0, SIGUE EN PULLUP.
    incf    PORTA	; AL APAGAR EL PIN CERO, SE INCREMENTA EL PORTA
    
    btfss   PORTB, DOWN	; SALTO EL PIN 7, SI EL PUSH BUTTON AÚN ESTÁ EN PULLUP.
    decf    PORTA	; AL DEJAR DE ESTAR EN PULLUP EL PUSHBUTTON, EL PORTA INCREMENTA.
    
    bcf	    RBIF	; LIMPIO LA BANDERA, AL TERMINAR CON LA INTERRUPCIÓN.
    return
 
 counter_tmr0:
    reset_tmr0
    incf    counter	; INCREMENTO EL COUNTER DE 20ms
    movf    counter, W	; MUEVO LA INFORMACIÓN DEL 'COUNTER' A 'W'
    sublw   50		; RESTO LA INFORMACION CON LO QUE HAY EN 'W' => 20ms*50reps = 1000ms
    btfsc   ZERO	; VERIFICO EL ESTADO DEL PIN 2 Y SI FUE IGUAL A 0.
    goto    incremento_counter2 ; Pasamos a la subrutina del aumento del contador 2 (display)
    return

 incremento_counter2:
    clrf    counter		    ; Limpio la varile de repeticiones del tmr0
    incf    variable_unidades	    ; Aumento el contador del unidadades
    movf    variable_unidades, w    ; Muevo el valor en el contador de unidades a 'w' y lo busco en 'values'.
    call    values		    ; Busco el valor de 'variable_unidades' en 'values'
    movwf   PORTC		    ; Guardo el 'char' en 'variable_unidades'
 
    movf    variable_unidades, w	; Paso el valor de 'variable_unidades' a 'w'
    sublw   10				; Verifico si el contador mencionado llego a 10s
    btfsc   ZERO			; VERIFICO CON 'ZERO', si el resultado de mi operacion fue '0'
    call    incremento_counter_decenas	; Llamo a mi subrutina de incremento del 'counter de decenas'
    movf    variable_decenas, w		; Paso el valor de mi contador de decenas a 'w'
    call    values			; Busco el 'char' = 'caracter' de mi variable 'contador' en 'values'
    movwf   PORTD			; Guardo el 'char' en mi contador de decenas y lo muestro
    
    return
    
 incremento_counter_decenas:
    clrf    variable_unidades	    ; Le doy un reinicio a mi contador de unidades = 'variable_unidades'
    incf    variable_decenas	    ; Incremento el condaro de unidades mencionado
    movf    variable_unidades, w    ; Paso el valor de mi contador de unidades a 'w', para buscar el 'char' en 'values'
    call    values		    ; Busco el 'char' obtenido de mi contador de unidades
    movwf   PORTC		    ; Guardo el 'char'  de unidades
    
    movf    variable_decenas, w	    ; Paso el valor del contador de decenas a 'w'
    sublw   6			    ; Verifico que el contador de decenas no tenga un valor igual a '6'
    btfsc   ZERO		    ; Verifico si la operacion anterior no fue '0'
    clrf    variable_decenas	    ; Reinicio mi contador de decenas
    return
 
 ;------------------------------- TABLA DE VALORES ----------------------------------   
PSECT code, delta=2, abs
ORG 100h  
 
values:
    clrf    PCLATH
    bsf	    PCLATH, 0	; PCLATH = LO HAGO = 01	; PCL = LO HAGO = 02
    andlw   0x0F
    addwf   PCL		; PC = PCLATH + PCL + w
    retlw   00111111B	; VALOR = 0
    retlw   00000110B	; VALOR = 1
    retlw   01011011B	; VALOR = 2
    retlw   01001111B	; VALOR = 3
    retlw   01100110B	; VALOR = 4
    retlw   01101101B	; VALOR = 5
    retlw   01111101B	; VALOR = 6
    retlw   00000111B	; VALOR = 7
    retlw   01111111B	; VALOR = 8
    retlw   01101111B	; VALOR = 9
    retlw   01110111B	; VALOR = A
    retlw   01111100B	; VALOR = B
    retlw   00111001B	; VALOR = C
    retlw   01011110B	; VALOR = D
    retlw   01111001B	; VALOR = E
    retlw   01110001B	; VALOR = F
    
 ;-------------configuracion------------------
 main:
    call config_ins_outs
    call config_reloj
    call config_tmr0
    call enable_interruptions
    call config_iocrb

 ;-------------loop principal-----------------
 loop:
    //POR EL MOMENTO NO HAY ACCIONES QUE DEBAN REPETIRSE, SOLO CONFIGURACIONES.
    goto    loop
 ;------------sub rutinas--------------------
 
 ;-------------------------- configurar io -------------------------------
 config_ins_outs:	; INPUTS/OUTPUTS DIGITALES/ANALÓGICOS
    banksel ANSEL	;Nos movemos de banco
    clrf    ANSEL	;Se definen I/O
    clrf    ANSELH	;LAS COLOCAMOS EN 0, PARA QUE SEAN SALIDAS DIGITALES
    
    //SALIDA DIGITAL - BANCO A - PRIMER CONTADOR --> PRELAB
    banksel TRISA	    ; Me muevo al PORTA
    
    bcf	TRISA, 0	    ; DEFINO QUE LOS PINES DEL 0 - 3, SERÁN SALIDAS DIGITALES 
    bcf	TRISA, 1
    bcf	TRISA, 2
    bcf	TRISA, 3
    
    //PORTB Tri-State Control bit - ENTRADA DIGITAL - PUSH BUTTONS
    banksel TRISB	    ; Me cambio de banco al PORTB
    bsf	    TRISB, UP	    ; PORTB en 'bsf' = SE CONFIGURA EL PORTB COMO ENTRADA 'tri-estado'. 
    bsf	    TRISB, DOWN	    ; PIN 2 EN PORTB COMO ENTRADA PARA PUSHBUTTON
    
    banksel OPTION_REG
    bcf	    OPTION_REG, 7   ; bcf = bit clear --> ACTIVO LOS PULLUPS DEL PORTB
    
    banksel WPUB	    ; Establezco que PIN 0 y PIN 1, PORTB serán entradas digitales (PUSHBUTTON)
    bsf	    WPUB, UP	    ; ENCIENDO EL PULLUP DEL PORTB --> WPUB = Weak Pull-up Register bit, con BSF = LO ENCIENDO EN 1.
    bsf	    WPUB, DOWN	    ; ENCIENDO EL PULLUP DEL PORTB --> WPUB = Weak Pull-up Register bit, con BSF = LO ENCIENDO EN 1.
    
    // SEGUNDO CONTADOR, INDEPENDIENTE DEL PRIMERO --> DURANTE EL LAB
    // SALIDA DIGITAL - BANCO C - 1er 7 SEGMENTOS
    banksel TRISC	    ; Me cambio de banco al PORTC
    clrf    TRISC	    ; Limpio el banco -> Lo defino como salida digital.
    
    // SALIDA DIGITAL - BANCO D - 2do 7 SEGMENTOS
    banksel TRISD	    ; Me cambio de banco.
    clrf    TRISD	    ; Defino el PORTD como salida digital
    
    banksel PORTA	    ; Hago una limpieza de bancos --> LIMPIO TODOS MIS PUERTOS
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    
    return

 ;--------------------------CONFIGURACION RELOJ-------------------------------
 config_reloj:
    banksel OSCCON  //CONFIGURO FRECUENCIA DE OSCILADOR 1MHz
    bsf OSCCON, 0     ;Activo reloj interno, encendido.
    bsf OSCCON, 6   ;BIT 6, EN 0
    bcf OSCCON, 5   ;BIT 5, EN 0
    bsf OSCCON, 4   ;BIT 4, EN 0 --> BIT MENOS SIGNIFICATIVO.
    return
   //USO PINES 4, 5, 6 ya que me permiten configurar la frecuencia de oscilación
   //UTILIZO RELOJ INTERNO CON UNA FRECUENCIA DE 2MHz (101).
 
 config_tmr0:
    banksel OPTION_REG	; Nos camviamos de banco.
    bcf T0CS	 ; HABILITO EL RELOJ INTERNO --> COMO TEMPORIZADOR
    bcf PSA	 ; ASIGNO PRESCALER AL TMR0 --> PRESCALER = 256 BSF
    bsf PS2	 
    bsf PS1
    bsf PS0      ; CORRESPONDE AL PRESCALER 1:256
    
    reset_tmr0	 ; Aplico el MACRO generado al principio del código.
    return
 ;----------------------CONFIGURACION INTERRUPCIONES -----------------------------
 enable_interruptions:	    ; Habilito las interrupciones - configuracion.
    banksel INTCON
    bsf	    GIE		    ; Habilito interrupciones globales, con este mando. ACTIVACION Y USO VITAL.
    bsf	    RBIE	    ; Habilito interrupciones de cambio de estado, del PORTB.
    bcf	    RBIF	    ; Limpio la bandera de cambio de estado del PORTB.
    bsf	    T0IE	    ; bsf = bit set = habilito interrupciones de tmr0
    bcf	    T0IF	    ; Bandera de interrupcion del tmr0.
    return
 
 config_iocrb:		    ; Configuro los pines de interrupcion
    banksel TRISA	    ; Me cambio de puerto al PORTA.
    bsf	    IOCB, UP	    ; Activo la interrupcion al cambio de estado en para el PIN 0 y PIN 1 del PORTB
    bsf	    IOCB, DOWN	    ; activar interrupcion al cambio en pin 7 de puertob
    
    banksel PORTA	
    movf    PORTB, w	    ; AL LEER, TERMINAR CON CONDICION DE MISMATCH
    bcf	    RBIF	    ; PARTE DE CONDICIONES DE HABILITAR LA INTERRUPCION
    return

  
END

