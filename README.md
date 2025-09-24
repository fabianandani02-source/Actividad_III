# Actividad_III
Un programa en ensamblador para el núcleo ARM Cortex-M3del MCU STM32F103C8

Indicaciones: Escriba un programa en ensamblador para el núcleo ARM Cortex-M3del MCU STM32F103C8 que haga lo siguiente:

•De un puerto, configurar 2 pinescomo entradas.

•Configurar el pin, que se conecta al LED de su tarjeta, como salidae iniciar con el LED apagado.

•Si en la combinación de los pines de entrada, tenemos “00”, el programa está en “inicio”y el LED estáapagado.

•Si en la combinación de las entradasenviamos “01”, generar 100 números pseudo aleatorios y almacenarlos en memoria SRAM a partir de la dirección 0x20000100.

  -Encender el LEDy registrar en una bandera (variable que indicará “1” cuando se ha realizado la operación).
  
  -Si en la combinación de las entradas enviamos “00”, el programa regresa al “inicio”y apagamos el LED, de lo contrario, permanece en la opción “01”.
  
•Si en la combinación de las entradas enviamos “10”, hacer lo siguiente:

  ▪Verificar el estado de la bandera, que indica si se han generado los números aleatorios (opción “01”).
  
  •Si la bandera indica que nose han generado los números aleatorios, permanecer en el menú de “inicio”.
    
  •Si la bandera indica que se han generado los números aleatorios, proceder ordenarlosde menor a mayor. Los números deben permanecer en la misma área de memoria, es decir, a partir de la dirección 0x20000100.oEncender el LED y registrar en una bandera (variable que indicará “1” cuando se ha realizado la operación).
    
  oSi en la combinación de las entradas enviamos “00”, el programa regresa al “inicio” y apagamos el LED, de lo contrario, permanece en la opción “10”
