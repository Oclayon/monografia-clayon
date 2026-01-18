
#Instalacao e importacao de pacotes
# Se já estiverem instalados, pode comentar as linhas de install.packages
install.packages("RPostgres")
install.packages("DBI")
install.packages("lubridate")
install.packages("dplyr")
install.packages("forecast")
install.packages("xgboost")
install.packages("tseries")
install.packages("tidyr")

library(DBI)
library(lubridate)
library(dplyr)
library(forecast)
library(xgboost)
library(tseries)
library(tidyr)

#conexao com o banco de dados 
con = dbConnect(RPostgres::Postgres(), 
                 dbname="postgres",
                 host='localhost',
                 port=5432,
                 user='postgres',
                 password='XXXXX')


#query que será realizada no banco, posso filtar por item e data por exemplo
query = dbGetQuery(con, "
  SELECT
    codigo,
    data,
    saidas
  FROM movimentacao
  WHERE codigo IN (373, 461, 432, 377, 11665)
  AND data::date >= '2024-01-01' AND data::date <= '2025-10-31'
")


#atribuo a query a um data frame, faco a conversao da coluna data para o tipo date
#agregacao por item e total de saidas diaria, dia sem saida recebe o valor 0
df = query %>%
  mutate(data = as.Date(data)) %>%
  rename(data_registro = data) %>% 
  group_by(codigo, data_registro) %>%
  summarise(demanda = sum(saidas), .groups = "drop") %>%
  group_by(codigo) %>%
  complete(
    data_registro = seq.Date(min(data_registro), max(data_registro), by = "day"),
    fill = list(demanda = 0)
  ) %>%
  ungroup() %>%
  rename(data = data_registro) %>% 
  arrange(codigo, data)


#aplicacao do ARIMA
dados_arima = df %>%
  group_by(codigo) %>%
  arrange(data, .by_group = TRUE) %>%
  group_modify(~ {
    
    # Frequência 7 para capturar padrão semanal
    serie <- ts(.x$demanda, frequency = 7)
    modelo <- auto.arima(serie)
    
    res <- residuals(modelo)
    
    tibble(
      codigo  = .x$codigo,
      data    = .x$data,
      demanda = .x$demanda,
      residuo = as.numeric(res)
    )
    
  }) %>%
  ungroup() %>%
  mutate(residuo = as.numeric(residuo))


# LAGS do modelo, alguns ensinamentos 
dados_ml = dados_arima %>%
  arrange(codigo, data) %>%
  mutate(
    residuo    = as.numeric(residuo),
    dia_semana = wday(data), # 1=Dom, 7=Sáb
    dia_mes    = day(data),
    mes        = month(data),
    # Feature extra para ajudar o modelo a entender dias úteis
    eh_dia_util = if_else(dia_semana %in% c(1,7), 0, 1), 
    lag_1      = dplyr::lag(residuo, 1),
    lag_7      = dplyr::lag(residuo, 7)
  ) %>%
  drop_na()


# funcao treino XGBOOST

treinar_xgb_produto = function(dados_produto) {
  
  y <- dados_produto$residuo
  
  # Adicionei 'eh_dia_util' nas features
  X <- dados_produto %>%
    select(dia_semana, dia_mes, mes, eh_dia_util, lag_1, lag_7)
  
  dtrain <- xgb.DMatrix(
    data  = as.matrix(X),
    label = y
  )
  
  params <- list(
    objective = "reg:squarederror",
    max_depth = 5,
    learning_rate = 0.1
  )
  
  xgb.train(
    params  = params,
    data    = dtrain,
    nrounds = 100,
    verbose = 0
  )
}


# treino dos modelos

modelos_xgb <- dados_ml %>%
  group_by(codigo) %>%
  group_modify(~{
    tibble(
      modelo_xgb = list(treinar_xgb_produto(.x))
    )
  }) %>%
  ungroup()


# funcao de previsao
prever_meta_modelo_custom <- function(dados_produto, modelo_xgb, data_inicio, dias_previsao = 30) {
  
  ultima_data_hist <- max(dados_produto$data)
  data_inicio <- as.Date(data_inicio)
  
  if (data_inicio <= ultima_data_hist) {
    stop("A data de início deve ser posterior ao histórico.")
  }
  
  dias_gap <- as.numeric(data_inicio - ultima_data_hist) - 1
  h_total  <- dias_gap + dias_previsao
  
  # ARIMA na série completa
  serie <- ts(dados_produto$demanda, frequency = 7)
  modelo_arima <- auto.arima(serie)
  
  # Previsao base
  prev_arima_obj <- forecast(modelo_arima, h = h_total)
  valores_arima  <- as.numeric(prev_arima_obj$mean)
  
  residuos_historicos <- as.numeric(residuals(modelo_arima))
  
  datas_futuras <- seq(from = ultima_data_hist + 1, by = "day", length.out = h_total)
  correcoes_xgb <- numeric(h_total) 
  
  # Loop Recursivo
  for (i in 1:h_total) {
    
    data_atual <- datas_futuras[i]
    ds <- wday(data_atual)
    
    feat_lag_1 <- tail(residuos_historicos, 1)
    feat_lag_7 <- tail(residuos_historicos, 7)[1]
    
    X_atual <- tibble(
      dia_semana = ds,
      dia_mes    = day(data_atual),
      mes        = month(data_atual),
      eh_dia_util = if_else(ds %in% c(1,7), 0, 1),
      lag_1      = feat_lag_1,
      lag_7      = feat_lag_7
    )
    
    dmatrix  <- xgb.DMatrix(as.matrix(X_atual))
    pred_res <- predict(modelo_xgb, dmatrix)
    
    correcoes_xgb[i] <- pred_res
    residuos_historicos <- c(residuos_historicos, pred_res)
  }
  
  tibble(
    codigo   = unique(dados_produto$codigo),
    data     = datas_futuras,
    arima    = valores_arima,
    xgb_adj  = correcoes_xgb,
    previsao = valores_arima + correcoes_xgb
  ) %>%
    filter(data >= data_inicio)
}

# execucao
DATA_ALVO <- "2025-11-01" 
QTD_DIAS  <- 30           

previsoes_finais <- df %>%
  group_by(codigo) %>%
  group_modify(~{
    mod_xgb <- modelos_xgb %>% filter(codigo == .y$codigo) %>% pull(modelo_xgb) %>% .[[1]]
    prever_meta_modelo_custom(.x, mod_xgb, data_inicio = DATA_ALVO, dias_previsao = QTD_DIAS)
  }) %>%
  ungroup()

previsoes_finais <- previsoes_finais %>%
  mutate(
    dia_semana = wday(data),
    # Zera Sábado (7) e Domingo (1)
    previsao_final = if_else(dia_semana %in% c(1, 7), 0, previsao),
    # Arredonda para cima para evitar falta de estoque (opcional)
    pedido_sugerido = ceiling(previsao_final)
  )


#visualizae e salvar

View(previsoes_finais)

write.csv(
  previsoes_finais,
  file = "~/Dados-TCC/modelo/previsoes_finais_novembro.csv",
  row.names = FALSE
)