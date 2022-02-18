## Autor: Felipe Scaccabarrozzi

# Instalar y cargar bibliotecas necesarias
packages = c("readxl", "rvest", "data.table", "xlsx", "writexl")
for (package in packages){
  if (require(package, character.only = T) == F) {
    install.packages(package, dependencies = T) 
    library(package)
  }
}

# Cargar archivo excel de referencia
ref = read_xlsx("entidad_numero.xlsx")

convert_csv = function(entity){
  entidad = ref$Entidades[entity]
  for (year in 2013:2021){
    for (month in 1:12){
      html_file = paste("Data/preconsolidada/", 
                        paste(entidad, year, month, sep = "_"),
                        ".html", sep="")
      if (file.size(html_file) != 0 & file.exists(html_file)){
        html_temp = read_html(paste("Data/preconsolidada/", 
                                    paste(entidad, year, month, sep = "_"),
                                    ".html", sep=""))
        data_temp = html_table(html_temp, header = T)
        fwrite(as.data.table(data_temp), file = paste("Data/preconsolidada_csv/", 
                                           paste(entidad, year, month, sep = "_"),
                                           ".csv", sep=""))
      }
      else{
        file.create(paste("Data/preconsolidada_csv/", 
                          paste(entidad, year, month, sep = "_"),
                          ".txt", sep=""))
      }
    }
  }
}


consolidate_entity = function(entity){
  entidad = ref$Entidades[entity]
  df = data.frame()
  for (year in 2013:2021){
    for (month in 1:12){
      filename = paste("Data/preconsolidada_csv/", 
                   paste(entidad, year, month, sep = "_"),
                   ".csv", sep="")
      if (file.exists(filename)){
        df_temp = fread(filename)
        df = rbind(df, df_temp)
      }
    }
  }
  fwrite(df, file = paste("Data/Cargos/", entidad, ".csv", sep = ""))
}

