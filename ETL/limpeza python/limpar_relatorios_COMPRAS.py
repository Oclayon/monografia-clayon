import pandas as pd
import openpyxl
# Carrega o arquivo Excel
open_xlsx=pd.read_excel('/home/clayon/Dados-TCC/COMPRAS/compras_agosto_novembro.xlsx', sheet_name='Planilha1')
df=pd.DataFrame(open_xlsx)

# Remove linhas em que todas as colunas estão em branco
df = df.dropna(axis=1, how='all')
print(df)

# Excluindo as duas primeiras linhas
df=df.drop(index=[0,1])


#Remove colunas especificando quais colunas remover
df = df.drop(columns=["Unnamed: 31", "Unnamed: 32", "Unnamed: 33", "Unnamed: 34", "Unnamed: 35", 
                      "Unnamed: 36", "Unnamed: 40", "Unnamed: 41", "Unnamed: 42"], axis=1)


#Bloco a seguir está comentado porque não é necessário para o arquivo atual mas pode ser útil futuramente
""""
indices_para_remover = []

for i in range(len(df)):
    if df.iloc[i, 0] != 'SESMT':
        indices_para_remover.append(df.index[i])

# Remove as linhas fora do loop
df = df.drop(indices_para_remover)

# o cabecalho está na linha 5, então vamos remover as 4 primeiras linhas
#df=df.iloc[4:]

"""
# Renomeia as colunas
df=df.rename(columns={'Acompanhamento RC Completo' : 'unidade',
                      'Unnamed: 1' : 'data_requisicao',
                    'Unnamed: 2' : 'n_requisicao',
                    'Unnamed: 3' : 'situacao_requisicao',
                    'Unnamed: 4' : 'situacao_aprovacao',
                    'Unnamed: 5' : 'data_ap_rep',
                    'Unnamed: 6' : 'aprov_rc',
                    'Unnamed: 7' : 'tipo',
                    'Unnamed: 8' : 'grupo_item',
                    "Unnamed: 9" : 'codigo_item',
                    'Unnamed: 10' : 'nome_item',
                    'Unnamed: 11' : 'quantidade',
                    'Unnamed: 12' : 'valor_unitario',
                    'Unnamed: 13' : 'valor_total',
                    'Unnamed: 14' : 'sit_item_req',
                    "Unnamed: 15" : 'n_oc',
                    "Unnamed: 16" : 'situacao',
                    "Unnamed: 17" : 'data_oc',
                    "Unnamed: 18" : 'sit_aprovacao_oc',
                    "Unnamed: 19" : 'qtd_oc',
                    "Unnamed: 20" : 'qtd_cancelada_oc',
                    "Unnamed: 21" : 'aprovador_oc',  
                    "Unnamed: 22" : 'data_aprovacao_oc',
                    "Unnamed: 23" : 'data_ap_final_oc',
                    "Unnamed: 24" : 'data_doc',
                    "Unnamed: 25" : 'ref_nfe',
                    "Unnamed: 26" : 'n_nfe',
                    "Unnamed: 27" : 'data_registro_nfe',
                    "Unnamed: 28" : 'data_emissao_nfe',
                    "Unnamed: 29" : 'qtd_nf',
                    "Unnamed: 30" : 'saldo_pendente_entrega',
                    "Unnamed: 37" : 'comprador',
                    "Unnamed: 38" : 'codigo_fornecedor',
                    "Unnamed: 39" : 'fornecedor',
                    "Unnamed: 43" : 'previsao_entrega',
                    "Unnamed: 44" : 'situacao_item_oc'})    
                   
print(df.columns)
 

# Remove o traço de 'Almoxarifado geral'
#df['local'] = df['local'].str.replace('-', '', regex=False)


# Salva o DataFrame em um novo arquivo Excel
df.to_excel('/home/clayon/Dados-TCC/DADOS LIMPOS/COMPRAS/COMPRAS-AGO_NOV-2025.xlsx', index=False)