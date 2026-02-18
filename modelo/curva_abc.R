# instalacao e importacao dos pacotes necessarios
install.packages("RPostgres")
install.packages("DBI")
install.packages("lubridate")
install.packages("dplyr")
install.packages("tidyr")
install.packages("ggplot2")
install.packages("scales")
library(DBI)
library(lubridate)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

#criando um objeto de conexao com o banco, nossos dados serao acessados atraves dessa conexao
con=dbConnect(RPostgres::Postgres(), 
              dbname="postgres",
              host='localhost',
              port=5432,
              user='postgres',
              password='XXXXX')

query = dbGetQuery(con, "
  SELECT 
    item,
    SUM(saidas) as total_movimentacao,
    SUM (saidas * valor_unitario) as valor_total
  FROM movimentacao
  GROUP BY item
"
)


# realiza os calculos necessarios para tracar a curva
df_abc = query %>%
  arrange(desc(valor_total)) %>%
  mutate(
    valor_acumulado = cumsum(valor_total),
    porc_acumulada = (valor_acumulado / sum(valor_total)) * 100,
    # Aqui criamos a coluna 'classe' que estava faltando
    classe = case_when(
      porc_acumulada <= 80 ~ "A",
      porc_acumulada <= 95 ~ "B",
      TRUE ~ "C"
    )
  )


#plotagem da curva, com configurações de cores, títulos e rótulos
grafico_abc <- ggplot(df_abc, aes(x = reorder(item, -valor_total), y = valor_total, fill = classe)) +
  geom_col(width = 1) + 
  scale_fill_manual(values = c("A" = "#333333", "B" = "#808080", "C" = "#d9d9d9")) +
  scale_y_continuous(labels = scales::label_dollar(prefix = "R$ ", big.mark = ".", decimal.mark = ",")) +
  labs(
    x = "Itens",
    y = "Valor Total Movimentado",
    fill = "Classe ABC"
  ) +
  theme_bw() +
  theme(
    axis.text.x = element_blank(), 
    axis.ticks.x = element_blank(),
    panel.grid.major.x = element_blank(),
    legend.position = "top"
  )

# Exibir
print(grafico_abc)

# Cria a tabela resumo
resumo_abc <- df_abc %>%
  group_by(classe) %>%
  summarise(
    # Conta quantos itens tem em cada classe
    quantidade_itens = n(),
    
    # Soma quanto dinheiro tem em cada classe
    valor_total_classe = sum(valor_total)
  ) %>%
  ungroup() %>%
  mutate(
    # Calcula a % de ITENS (Ex: 10% dos produtos são A)
    porc_itens = round((quantidade_itens / sum(quantidade_itens)) * 100, 2),
    
    # Calcula a % de VALOR (Ex: 80% do dinheiro está em A)
    porc_valor = round((valor_total_classe / sum(valor_total_classe)) * 100, 2)
  )

# Visualizar a tabela 
print(resumo_abc)
View(df_abc)