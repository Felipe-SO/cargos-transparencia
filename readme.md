
### Preparación
1. El código está en lenguaje R, por lo cual recomiendo utilizar RStudio.
    + Todo está preparado para empezar a correr las funciones desde el script "run.R".
2. Para el funcionamiento del código, se necesita un archivo excel que siga el formato de "referencia_ejemplo.xlsx". La variable ID es el número de identificación de cada entidad según el portal de transparencia (este se puede encontrar en el link de cada entidad).
    + Es necesario que el archivo de referencia tenga el nombre "entidad_numero.xlsx" y se encuentre en la misma carpeta que los scripts.
    + Casi todas las funciones dependen del archivo de referencia. Asegurarse de que el formato sea exactamente el mismo (incluyendo mayúsculas y minúsculas y el orden de las columnas).
3. Dentro del script "run.R" hay que cambiar la dirección de trabajo a la dirección donde se encuentren los scripts.
4. No cambiar el nombre de las carpetas ni eliminarlas hasta que todo esté listo para entregar.
5. Por default, el programa está configurado para utilizar los años 2013-2021. Si se desean utilizar otros años, estos se pueden definir mediante la opción "years".
    + E.g. `options(years = 2015:2020)`

### Descarga
*Nota: En el script de descargas hay varias funciones que no serán utilizadas.*

*Como mencioné antes, el código debe correrse desde __run.R__, donde ya están las líneas de código que deben correrse antes de poder usar cualquier función. Esto incluye cargar las bibliotecas necesarias y la instalación de estas si es necesario.*

##### Preparación del "Cluster"
Para agilizar las descargas, se hará uso de procesamiento paralelo (la biblioteca utilizada incluso implementa una barra de progreso); recomiendo usar 4 procesos simultáneos (8 como máx), pues parece que intentar hacer más descargas simultáneas resulta ser contraproducente al incrementar la probabilidad de obtener un archivo vacío cuando en realidad sí existe la data de dicho periodo.

Para hacer uso de las funciones, hay que preparar un *cluster* de la siguiente manera:
```
procesos = 4 # Número de procesos simultáneos
clust = makeCluster(procesos)
clusterExport(clust, download_exports)
```
De forma tal que nos queda un cluster llamado `clust`. 

*Nota: Si se intenta detener alguna función desde la consola antes de que termine, esta seguirá corriendo en segundo plano y la única forma de detenerlo será terminando cada proceso desde el Administrador de Tareas (Task Manager).*

##### Cómo descargar
*Los archivos descargados se encontrarán en la carpeta "preconsolidada".*

Recomiendo empezar las descargas con la función `download_missing`. Esta función intentará descargar todos los archivos que hasta el momento no existan en la carpeta "preconsolidada". El uso de esta función es bastante simple; después del código de preparación solo hay que correr el siguiente comando:
```
download_missing(clust)
```
Recomiendo repetir este comando una y otra vez hasta que no falte ningún archivo, lo cual podrá revisarse con el siguiente comando:
```
nrow(missing_files())
```
que retornará el número de archivos que todavía faltan descargar.

Uno podría pensar que una vez que faltan 0 archivos, ya está todo descargado, pero esto no es así. Un archivo solo figurará en la lista de archivos faltantes si no se logró establecer una conexión con el url de la descarga; sin embargo, una gran parte de lo descargado estará completamente vacía (descarga archivos de 0 bytes o una página de error de 1701 bytes).

Sabiendo esto, una vez que `nrow(missing_files())` retorne 0, se debe hacer uso de la función `download_empty`, que intentará descargar cada archivo vacío o que haya devuelto la página de error. Esta función se usa de manera parecida a la anterior:
```
download_empty(clust)
```
Y si se quiere revisar cuantos archivos vacíos se encuentran en la base de datos, solo hay que correr:
```
nrow(empty(files))
```
A diferencia de los archivos faltantes, la cantidad de archivos vacíos nunca va a llegar a 0, pues hay periodos para los cuales simplemente no existen datos. Recomiendo repetir la función `download_empty` unas cuantas veces antes de pasar a la siguiente etapa.

Ya que algunas entidades no siguen el mismo estándar o simplemente no tienen datos, se implementó la función `empty_entity`, que devuelve el índice (número de orden en el excel de referencia) de cada entidad para la cual todos sus archivos están vacíos. Si se desea una lista con los nombres de estas entidades "vacías", solo hay que correr el siguiente comando:
```
ref$Entidades[empty_entity,]
```
Y asumiendo que nunca se encontrarán datos en el portal para estas entidades, se puede empezar a correr la función
```
download_empty_2(clust) # No incluye entidades vacías
```
hasta que el número de archivos vacíos no cambie entre el antes y el después de que se corra esta función.

Si se desea revisar que las entidades "vacías" verdaderamente estén vacías, se puede correr la siguiente función:
```
download_emptyties(clust)
```
que solo intentará descargar archivos de entidades "vacías".

Si se desea descargar archivos para una entidad en específico, se puede utilizar la siguiente función:
```
download_entity(clust, index_entidad)
# Donde index_entidad sería el número de orden de la entidad dentro del archivo excel de referencia
```

### Consolidación
Una vez que se han descargado los datos mensuales, estos pueden ser procesados para generar un solo archivo para cada entidad.

##### Conversión
Antes de consolidar los datos, es conveniente pasarlos a un tipo de archivo que sea más manejable que html, por lo cual creé una función que convierte estos archivos a csv antes de consolidarlos. La forma de usar esta función es:
```
## Convertir una sola entidad
convert_csv(index_entidad) 
# Donde index_entidad sería el número de orden de la entidad dentro del archivo excel de referencia

## Convertir todas las entidades
entities = 1:{nrow(ref)}
entities = entities[!entities %in% empty_entity]
lapply(entities, convert_csv)
```
Los archivos convertidos se encontrarán en la carpeta "preconsolidada_csv"

##### Consolidación
Una vez que los archivos hayan sido convertidos a formato csv, se podrán consolidar de la siguiente manera:
```
## Consolidar una sola entidad
consolidate_entity(index_entidad)

## Consolidar todas las entidades
entities = 1:{nrow(ref)}
entities = entities[!entities %in% empty_entity]
lapply(entities, consolidate_entity)
```
Los archivos generados estarán en la carpeta "Cargos"
