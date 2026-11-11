
# Pipeline de Dados Financeiros WEG

**Python | SQL Server | Power BI**

## Sobre o Projeto

Este projeto apresenta o desenvolvimento de um pipeline ETL (Extração, Transformação e Carga) utilizando dados financeiros da WEG S.A., multinacional brasileira.

O objetivo é transformar informações provenientes de Demonstrações do Resultado do Exercício (DRE), disponibilizadas em PDF, e de um Plano de Contas em Excel em dados estruturados para análise financeira e Business Intelligence.

A solução integra Python para extração e preparação dos dados, SQL Server para armazenamento, validação, transformação e modelagem dimensional, e Power BI para análise e visualização dos resultados.

O projeto contempla informações financeiras referentes aos exercícios de 2023, 2024 e 2025.

## Tecnologias Utilizadas

| Tecnologia | Aplicação |
|------------|-----------|
| Python | Extração e preparação dos dados |
| Pandas | Manipulação e tratamento dos dados |
| PyMuPDF | Extração de informações dos PDFs |
| PyODBC | Integração com SQL Server |
| SQL Server / T-SQL | Armazenamento, validação e transformação dos dados |
| Jupyter Notebook | Desenvolvimento do pipeline Python |
| Power BI | Análise financeira e visualização dos resultados |

## Arquitetura do Pipeline

O projeto utiliza uma arquitetura de dados organizada em camadas, integrando as etapas de extração, preparação, armazenamento, transformação e análise.

![Arquitetura do Pipeline DRE WEG](images/arquitetura_pipeline.png)

O processamento é dividido em três componentes principais:

- **Python:** extração, tratamento e preparação dos dados provenientes dos arquivos PDF e Excel, além da carga nas tabelas de staging.
- **SQL Server:** armazenamento dos dados, verificações de qualidade, transformações e construção do modelo dimensional.
- **Power BI:** utilização dos dados estruturados para análise e visualização financeira.

As camadas *staging* e *mart* representam divisões lógicas dentro do banco de dados `DRE_WEG`. Todas as tabelas pertencem ao schema `dbo`.

## Desenvolvimento do Pipeline

### 1. Extração e Preparação dos Dados — Python

O processamento inicial foi desenvolvido no Jupyter Notebook `notebook/pipeline_dre_weg.ipynb`.

As principais operações incluem:

- Leitura e extração de informações financeiras dos arquivos PDF.
- Processamento do Plano de Contas disponibilizado em Excel.
- Tratamento e estruturação dos registros extraídos.
- Preparação dos dados para armazenamento relacional.
- Conexão com o SQL Server por meio do PyODBC.
- Carregamento dos dados nas tabelas de staging.

### 2. Armazenamento Inicial — Staging

Os dados preparados em Python são carregados em duas tabelas no SQL Server.

**dbo.stg_DRE**

Armazena as informações extraídas das Demonstrações do Resultado do Exercício, incluindo:

- Código da conta.
- Descrição da conta.
- Valores financeiros de 2023, 2024 e 2025.

**dbo.stg_PlanoContas**

Armazena as informações do Plano de Contas, incluindo:

- Identificador da conta.
- Descrição da conta.
- Indicador de lançamento.
- Indicador de cálculo.

Essa camada preserva os dados estruturados para as etapas seguintes de validação e transformação.

### 3. Validação da Qualidade dos Dados — SQL

Após o carregamento das tabelas de staging, foram desenvolvidas consultas em T-SQL para verificar a consistência dos registros.

As verificações incluem:

- Identificação de valores nulos.
- Verificação de códigos de contas duplicados.
- Comparação entre os códigos da DRE e do Plano de Contas.
- Identificação de contas sem correspondência entre as tabelas.

Essas consultas auxiliam na avaliação da qualidade dos dados antes da construção do modelo analítico.

### 4. Construção da Camada Mart — SQL Server

A camada Mart foi estruturada utilizando conceitos de modelagem dimensional, com uma tabela dimensão e uma tabela fato.

#### Dimensão: dbo.dPlanoContas

A tabela `dPlanoContas` organiza os atributos e a classificação hierárquica das contas contábeis.

Sua estrutura contempla:

- Identificador e descrição da conta.
- Indicadores de lançamento e cálculo.
- Níveis hierárquicos N1, N2 e N3.
- Código de agrupamento do primeiro nível (CodN1).

A hierarquia é construída por meio de operações `LEFT JOIN` da tabela de staging com ela mesma, associando as contas aos respectivos níveis.

#### Tabela Fato: dbo.fResultado

A tabela `fResultado` armazena os resultados financeiros organizados por conta contábil e data de referência.

Sua estrutura contém:

- ID da conta.
- Data de referência.
- Valor financeiro.

O modelo utiliza chaves primárias e uma chave estrangeira para estabelecer a integridade referencial entre a tabela fato e a dimensão.

### 5. Transformação dos Dados — SQL

A transformação dos dados financeiros utiliza operações SQL para adequar os registros ao modelo analítico.

**Hierarquização das contas**

Operações `LEFT JOIN` permitem associar as contas aos diferentes níveis do Plano de Contas.

**Transformação dos valores anuais**

A operação `UNPIVOT` converte as colunas correspondentes aos anos de 2023, 2024 e 2025 em registros organizados por conta, período e valor.

**Padronização das datas**

A função `DATEFROMPARTS` constrói as datas de referência, utilizando o dia 31 de dezembro de cada exercício.

**Relacionamento entre dimensão e fato**

A operação `INNER JOIN` relaciona os registros financeiros às contas presentes na dimensão.

O carregamento da tabela fato considera os registros classificados como contas de lançamento.

### 6. Validação da Camada Mart

Após a construção das tabelas analíticas, foram realizadas consultas para:

- Conferir os registros da dimensão `dPlanoContas`.
- Conferir os registros da tabela fato `fResultado`.
- Verificar a quantidade de registros em cada tabela.

Essas consultas permitem inspecionar os resultados da transformação e da carga.

### 7. Análise e Visualização — Power BI

Os dados estruturados no SQL Server são utilizados no Power BI para análise financeira.

A organização dimensional permite relacionar os resultados financeiros às classificações do Plano de Contas, facilitando a exploração dos dados referentes aos diferentes exercícios.

## Estrutura do Repositório

O projeto está organizado em diretórios destinados aos arquivos de origem, processamento, consultas SQL e dados estruturados.

Os principais componentes incluem:

- `notebook/pipeline_dre_weg.ipynb` — Notebook com o processamento Python.
- `sql/` — Consultas SQL utilizadas na criação, validação, transformação e modelagem das tabelas.
- `data/raw/` — Diretório destinado aos arquivos de origem.
- `data/staging/` — Exportações CSV das tabelas de staging.
- `data/mart/` — Exportações CSV das tabelas da camada Mart.
- `images/` — Imagens utilizadas na documentação do projeto.
- `requirements.txt` — Dependências Python.
- `.gitignore` — Configuração dos arquivos excluídos do versionamento.
- `README.md` — Documentação do projeto.

## Requisitos

Para executar o projeto, são necessários:

- Python 3
- Jupyter Notebook
- Microsoft SQL Server
- Driver ODBC compatível com SQL Server
- Power BI Desktop

As bibliotecas Python estão relacionadas no arquivo `requirements.txt`.

Para instalar as dependências:

`pip install -r requirements.txt`

## Execução do Projeto

A reprodução do pipeline requer os arquivos financeiros de origem e uma instância configurada do SQL Server.

A sequência de processamento é:

1. Configurar o ambiente Python e as dependências.
2. Criar o banco de dados e as tabelas de staging utilizando o script SQL.
3. Executar o notebook Python para extrair, preparar e carregar os dados.
4. Executar as consultas SQL de validação da camada staging.
5. Construir e popular as tabelas da camada Mart por meio das transformações SQL.
6. Conferir os resultados das tabelas analíticas.
7. Utilizar os dados estruturados no Power BI.

As consultas SQL foram mantidas em arquivo separado para documentação e controle de versão, sendo executadas no SQL Server durante o desenvolvimento.

As configurações de conexão devem ser adaptadas ao ambiente de execução.

## Competências Aplicadas

- Desenvolvimento de pipelines ETL.
- Extração e processamento de dados em Python.
- Manipulação de arquivos PDF e Excel.
- Integração entre Python e SQL Server.
- Validação da qualidade dos dados.
- Consultas e transformações em T-SQL.
- Modelagem de bancos de dados relacionais.
- Modelagem dimensional.
- Construção de tabelas dimensão e fato.
- Operações JOIN e UNPIVOT.
- Preparação de dados para Business Intelligence.
- Análise de dados financeiros.

## Autora

**Carolina Muro Gomes**

[LinkedIn](https://www.linkedin.com/in/carolinamurogomes/) | [Portfólio](https://carolmurogomes.github.io/)
