## Autor: Felipe Scaccabarrozzi
## Ultima Actualización: 11/03/2022

# Instalar y cargar bibliotecas necesarias
packages = c("readxl", "parallel", "dplyr", "pbapply")
for (package in packages){
  if (require(package, character.only = T) == F) {
    install.packages(package, dependencies = T) 
    library(package)
  }
}

# Cargar arhivo excel de referencia
ref = read_xlsx("entidad_numero.xlsx")

options(timeout=120)

## https://rdrr.io/bioc/recount/man/download_retry.html
download_retry <- function(url, destfile = basename(url), mode = "wb",
                           N.TRIES = 3L, ...) {
  ## Based on http://bioconductor.org/developers/how-to/web-query/
  ## and downloader::download()
  
  N.TRIES <- as.integer(N.TRIES)
  stopifnot(length(N.TRIES) == 1L, !is.na(N.TRIES))
  stopifnot(N.TRIES > 0L)
  
  while (N.TRIES > 0L) {
    result <- tryCatch(downloader::download(
      url = url, destfile = destfile, mode = mode, ...
    ), error = identity)
    if (!inherits(result, "error")) {
      break
    }
    ## Wait between 0 and 2 seconds between retries
    Sys.sleep(runif(n = 1, min = 2, max = 5))
    N.TRIES <- N.TRIES - 1L
  }
  
  if (N.TRIES == 0L) {
    stop(
      "'download_retry()' failed:",
      "\n  URL: ", url,
      "\n  error: ", conditionMessage(result)
    )
  }
  
  invisible(result)
}

descargar = function(filename, id, year, month){
  url = paste("http://transparencia.gob.pe/personal/pte_transparencia_personal_genera.aspx?id_entidad=",id,"&in_anno_consulta=",year,"&ch_mes_consulta=", month,"&ch_tipo_regimen=0&vc_dni_funcionario=&vc_nombre_funcionario=&ch_tipo_descarga=1", sep = "")
  dest = paste("Data/preconsolidada/",filename,".html", sep = "")
  download_retry(url, destfile = dest, N.TRIES = 7)
}

descargar_2 = function(entidad, id, year, month){
  url = paste("http://transparencia.gob.pe/personal/pte_transparencia_personal_genera.aspx?id_entidad=",id,"&in_anno_consulta=",year,"&ch_mes_consulta=", month,"&ch_tipo_regimen=0&vc_dni_funcionario=&vc_nombre_funcionario=&ch_tipo_descarga=1", sep = "")
  dest = paste("Data/preconsolidada/", paste(entidad, year, month, sep = "_"),".html", sep = "")
  download_retry(url, destfile = dest, N.TRIES = 7)
}

descargar_simple = function(filename, id, year, month){
  url = paste("http://transparencia.gob.pe/personal/pte_transparencia_personal_genera.aspx?id_entidad=",id,"&in_anno_consulta=",year,"&ch_mes_consulta=", month,"&ch_tipo_regimen=0&vc_dni_funcionario=&vc_nombre_funcionario=&ch_tipo_descarga=1", sep = "")
  dest = paste("Data/preconsolidada/",filename,".html", sep = "")
  attempt = 1
  download.file(url, dest)
}

download_group = function(entidades){
  for (i in entidades){
    for (year in getOption("years", default = 2013:2021)){
      for (month in 1:12){
        descargar(paste(ref[i,1],year,month, sep = "_"), ref[i,2], year, month)
      }
    }
  }
}

download_entity = function(cluster, entidad){
  for (year in getOption("years", default = 2013:2021)){
    descarga_temp = function(month){
      filedir = paste("Data/preconsolidada", paste(ref[entidad,1],year,month, sep = "_"),".html", sep = "")
      if(file.exists(filedir) == F | file.size(filedir) %in% c(0,1701)){
        try(descargar_2(ref[entidad,1], ref[entidad,2], year, month))
      }
    }
    pblapply(1:12, descarga_temp, cl = cluster)
  }
}

missing_files = function(){
  index_entidad = c()
  years = c()
  months = c()
  dir_temp = "Data/preconsolidada/"
  for (i in 1:length(ref$Entidades)){
    for (year in getOption("years", default = 2013:2021)){
      for (month in 1:12){
        filename = paste(paste(ref$Entidades[i],year,month, sep = "_"),".html", sep = "")
        filedir = paste(dir_temp, filename, sep ="")
        if (file.exists(filedir) == F){
          index_entidad = append(index_entidad, i)
          years = append(years, year)
          months = append(months, month)
        }
      }
    }
  }
  missing = data.frame(index_entidad, years, months)
  return(missing)
}

download_missing = function(cluster){
  missing_list <<- missing_files()
  download_item = function(index){
    downloaded = 0
    try({
      descargar_2(ref$Entidades[missing_list[index,1]], ref$ID[missing_list[index,1]], missing_list[index,2], missing_list[index,3])
      downloaded = 1
    })
    if (downloaded == 0) print(paste(missing_list[index, 1],missing_list[index, 2],missing_list[index, 3], sep = "_"))
  }
  clusterExport(cluster, c("ref", "descargar_2", "download_retry", "missing_list"))
  pblapply(1:nrow(missing_list), download_item, cl = cluster)
}

empty_files = function(){
  index_entidad = c()
  years = c()
  months = c()
  dir_temp = "Data/preconsolidada/"
  for (i in 1:length(ref$Entidades)){
    for (year in getOption("years", default = 2013:2021)){
      for (month in 1:12){
        filename = paste(paste(ref$Entidades[i],year,month, sep = "_"),".html", sep = "")
        filedir = paste(dir_temp, filename, sep ="")
        if (file.size(filedir) %in% c(0,1701)){
          index_entidad = append(index_entidad, i)
          years = append(years, year)
          months = append(months, month)
        }
      }
    }
  }
  empty = data.frame(index_entidad, years, months)
  return(empty)
}

empty_entity = function(){
  index = c()
  empty_list = empty_files()
  for (i in 1:nrow(ref)){
    if ((nrow(empty_list %>% filter(index_entidad == i))) == 12*{length(getOption("years", default = 2013:2021))}){
      index = append(index, i)
    }
  }
  return(index)
}

download_empty = function(cluster){
  empty_list <<- empty_files()
  download_item = function(index){
    downloaded = 0
    try({
      descargar_2(ref$Entidades[empty_list[index,1]], ref$ID[empty_list[index,1]], empty_list[index,2], empty_list[index,3])
      downloaded = 1
    })
    if (downloaded == 0) {
      print(paste(empty_list[index, 1],empty_list[index, 2],empty_list[index, 3], sep = "_"))
      file.create(paste("Data/preconsolidada/",paste(ref$Entidades[empty_list[index,1]],empty_list[index,2], empty_list[index,3], sep = "_"),".html", sep = ""))
    }
  }
  clusterExport(cluster, c("ref", "descargar_2", "download_retry", "empty_list"))
  pblapply(1:nrow(empty_list), download_item, cl = cluster)
}

download_empty_2 = function(cluster){
  empty_list <<- empty_files() %>% filter(!(index_entidad %in% empty_entity()))
  download_item = function(index){
    downloaded = 0
    try({
      descargar_2(ref$Entidades[empty_list[index,1]], ref$ID[empty_list[index,1]], empty_list[index,2], empty_list[index,3])
      downloaded = 1
    })
    if (downloaded == 0) {
      print(paste(empty_list[index, 1],empty_list[index, 2],empty_list[index, 3], sep = "_"))
      file.create(paste("Data/preconsolidada/",paste(ref$Entidades[empty_list[index,1]],empty_list[index,2], empty_list[index,3], sep = "_"),".html", sep = ""))
    }
  }
  clusterExport(cluster, c("ref", "descargar_2", "download_retry", "empty_list"))
  pblapply(1:nrow(empty_list), download_item, cl = cluster)
}

download_emptyties = function(cluster){
  empty_list <<- empty_files() %>% filter(index_entidad %in% empty_entity())
  download_item = function(index){
    downloaded = 0
    try({
      descargar_2(ref$Entidades[empty_list[index,1]], ref$ID[empty_list[index,1]], empty_list[index,2], empty_list[index,3])
      downloaded = 1
    })
    if (downloaded == 0) {
      print(paste(empty_list[index, 1],empty_list[index, 2],empty_list[index, 3], sep = "_"))
      file.create(paste("Data/preconsolidada/",paste(ref$Entidades[empty_list[index,1]],empty_list[index,2], empty_list[index,3], sep = "_"),".html", sep = ""))
    }
  }
  clusterExport(cluster, c("ref", "descargar_2", "download_retry", "empty_list"))
  pblapply(1:nrow(empty_list), download_item, cl = cluster)
}

download_december = function(cluster){
  clusterExport(cluster, c("ref", "descargar_2", "download_retry", "empty_list"))
  descarga_dec_temp = function(index){
    downloaded = 0
    try({
      descargar_2(ref$Entidades[index], ref$ID[index],2021,12)
      downloaded = 1
    })
    if (downloaded == 0){
      file.create(paste("Data/preconsolidada/",paste(ref$Entidades[index],2021, 12, sep = "_"),".html", sep = ""))
    }
  }
  entities = empty_entity()
  parLapply(cluster, entities, descarga_dec_temp)
}

