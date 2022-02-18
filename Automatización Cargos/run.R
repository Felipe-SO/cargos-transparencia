## Autor: Felipe Scaccabarrozzi

# Cambiar a carpeta donde se encuentran los scripts
setwd("........../Automatización Cargos")

# Importamos los scripts con las funciones
source("downloader.r")
source("consolidate.r")

consolidate_exports = c("write_xlsx", "read_html", "html_table", "read_xlsx", "ref", "fwrite", "fread")
download_exports = c("ref", "descargar_2", "download_retry")

procesos = 8 # Número de procesos simultáneos
clust = makeCluster(procesos)
clusterExport(clust, download_exports)
