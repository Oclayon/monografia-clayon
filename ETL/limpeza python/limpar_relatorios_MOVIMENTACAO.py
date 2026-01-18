import pandas as pd
import openpyxl
# Carrega o arquivo Excel
open_xlsx=pd.read_excel('/home/clayon/Dados-TCC/MOVIMENTAÇÃO DE ESTOQUE/movimentacoes_agosto_novembro.xlsx', sheet_name='Planilha1')
df=pd.DataFrame(open_xlsx)

# Remove linhas em que todas as colunas estão em branco
df = df.dropna(axis=1, how='all')
print(df)

df = df.drop(columns=['Unnamed: 1', 'Unnamed: 3', 'Unnamed: 10', 'Unnamed: 11', 'Unnamed: 11', 
                      'Unnamed: 12'], axis=1)

indices_para_remover = []

for i in range(len(df)):
    if df.iloc[i, 0] != 'SESMT':
        indices_para_remover.append(df.index[i])

# Remove as linhas fora do loop
df = df.drop(indices_para_remover)

# o cabecalho está na linha 5, então vamos remover as 4 primeiras linhas
#df=df.iloc[4:]


# Renomeia a coluna 'Unnamed: 2' para 'coluna'
df=df.rename(columns={'Movimentacao de Estoques' : 'grupo',
                      'Unnamed: 2' : 'local',
                   'Unnamed: 4' : 'item',
                   'Unnamed: 5' : 'especie',
                   'Unnamed: 6' : 'codigo',
                   'Unnamed: 7' : 'data',
                   'Unnamed: 8' : 'tipo',
                   'Unnamed: 9' : 'referencia',
                   'Unnamed: 13' : 'saidas',
                   'Unnamed: 14' : 'valor_total',
                   'Unnamed: 15' : 'valor_unitario',
                   'Unnamed: 16' : 'estoque',
                   'Unnamed: 17' : 'custo',
                    'Unnamed: 18' : 'custo_unitario'})
                   
print(df.columns)

# Remove o traço de 'Almoxarifado geral'
df['local'] = df['local'].str.replace('-', '', regex=False)

# Salva o DataFrame em um novo arquivo Excel
df.to_excel('/home/clayon/Dados-TCC/DADOS LIMPOS/MOVIMENTACAO_2025_ATE_AGO_NOV_LIMPO.xlsx', index=False)