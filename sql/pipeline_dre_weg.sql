
/*
7. CRIAÇÃO DO BANCO DE DADOS E TABELAS
*/

-- 7.1 Criação do banco de dados

IF DB_ID('DRE_WEG') IS NULL
BEGIN
    CREATE DATABASE DRE_WEG;
END;
GO

USE DRE_WEG;
GO

-- 7.2 Tabela Staging: DRE em PDF

IF OBJECT_ID('dbo.stg_DRE', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.stg_DRE (
        codigo VARCHAR(11),
        [descrição] NVARCHAR(300),
        [2025] BIGINT,
        [2024] BIGINT,
        [2023] BIGINT
    );
END;
GO

-- 7.3 Tabela Staging: Excel

IF OBJECT_ID('dbo.stg_PlanoContas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.stg_PlanoContas (
        [Id Conta] VARCHAR(11),
        [Descrição] NVARCHAR(300),
        [Lançamento] BIT,
        [Calculado] BIT
    );
END;
GO

-- PASSO 8: CARGA DOS DADOS REALIZADA EM PYTHON


/*
9. TRATAMENTO E TRANSFORMAÇÃO DOS DADOS
*/

-- 9.1 Inspeção inicial das tabelas de Staging

SELECT *
FROM dbo.stg_DRE;

SELECT *
FROM dbo.stg_PlanoContas;


-- 9.2 Verificação da qualidade dos dados

-- 9.2.1 Verificação de valores nulos na DRE

SELECT
    SUM(CASE WHEN codigo IS NULL THEN 1 ELSE 0 END) AS nulos_codigo,
    SUM(CASE WHEN [descrição] IS NULL THEN 1 ELSE 0 END) AS nulos_descricao,
    SUM(CASE WHEN [2025] IS NULL THEN 1 ELSE 0 END) AS nulos_2025,
    SUM(CASE WHEN [2024] IS NULL THEN 1 ELSE 0 END) AS nulos_2024,
    SUM(CASE WHEN [2023] IS NULL THEN 1 ELSE 0 END) AS nulos_2023
FROM dbo.stg_DRE;


-- 9.2.2 Verificação de valores nulos no Plano de Contas

SELECT
    SUM(CASE WHEN [Id Conta] IS NULL THEN 1 ELSE 0 END) AS nulos_id_conta,
    SUM(CASE WHEN [Descrição] IS NULL THEN 1 ELSE 0 END) AS nulos_descricao,
    SUM(CASE WHEN [Lançamento] IS NULL THEN 1 ELSE 0 END) AS nulos_lancamento,
    SUM(CASE WHEN [Calculado] IS NULL THEN 1 ELSE 0 END) AS nulos_calculado
FROM dbo.stg_PlanoContas;


-- 9.3 Verificação de códigos duplicados

-- 9.3.1 DRE

SELECT
    codigo,
    COUNT(*) AS quantidade
FROM dbo.stg_DRE
GROUP BY codigo
HAVING COUNT(*) > 1;


-- 9.3.2 Plano de Contas

SELECT
    [Id Conta],
    COUNT(*) AS quantidade
FROM dbo.stg_PlanoContas
GROUP BY [Id Conta]
HAVING COUNT(*) > 1;


-- 9.4 Verificação de correspondência entre contas

-- 9.4.1 Contas da DRE sem correspondência no Plano de Contas

SELECT
    d.codigo,
    d.[descrição]
FROM dbo.stg_DRE AS d
LEFT JOIN dbo.stg_PlanoContas AS p
    ON d.codigo = p.[Id Conta]
WHERE p.[Id Conta] IS NULL;


-- 9.4.2 Contas do Plano de Contas sem correspondência na DRE

SELECT
    p.[Id Conta],
    p.[Descrição]
FROM dbo.stg_PlanoContas AS p
LEFT JOIN dbo.stg_DRE AS d
    ON p.[Id Conta] = d.codigo
WHERE d.codigo IS NULL;


/*
10. CONSTRUÇÃO DA CAMADA MART
*/

-- 10.1 Criação da dimensão dPlanoContas

IF OBJECT_ID('dbo.dPlanoContas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dPlanoContas (
        [Id Conta] VARCHAR(20) NOT NULL PRIMARY KEY,
        [Descrição] NVARCHAR(255),
        [Lançamento] BIT,
        [Calculado] BIT,
        N1 NVARCHAR(255),
        N2 NVARCHAR(255),
        N3 NVARCHAR(255),
        CodN1 VARCHAR(4)
    );
END;
GO


-- 10.2 Criação da tabela fato fResultado

IF OBJECT_ID('dbo.fResultado', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.fResultado (
        [ID Conta] VARCHAR(20) NOT NULL,
        [Data] DATE NOT NULL,
        [Value] DECIMAL(19,2) NOT NULL,

        CONSTRAINT PK_fResultado
            PRIMARY KEY ([ID Conta], [Data]),

        CONSTRAINT FK_fResultado_dPlanoContas
            FOREIGN KEY ([ID Conta])
            REFERENCES dbo.dPlanoContas([Id Conta])
    );
END;
GO


-- 10.3 Inserção dos dados na dimensão dPlanoContas
-- Evita inserir novamente contas que já existem.

INSERT INTO dbo.dPlanoContas (
    [Id Conta],
    [Descrição],
    [Lançamento],
    [Calculado],
    N1,
    N2,
    N3,
    CodN1
)
SELECT
    p.[Id Conta],
    p.[Descrição],
    p.[Lançamento],
    p.[Calculado],

    n1.[Descrição] AS N1,
    n2.[Descrição] AS N2,
    n3.[Descrição] AS N3,

    LEFT(p.[Id Conta], 4) AS CodN1

FROM dbo.stg_PlanoContas AS p

LEFT JOIN dbo.stg_PlanoContas AS n1
    ON n1.[Id Conta] = LEFT(p.[Id Conta], 4)

LEFT JOIN dbo.stg_PlanoContas AS n2
    ON n2.[Id Conta] = LEFT(p.[Id Conta], 7)
    AND LEN(p.[Id Conta]) >= 7

LEFT JOIN dbo.stg_PlanoContas AS n3
    ON n3.[Id Conta] = p.[Id Conta]
    AND LEN(p.[Id Conta]) = 10

WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.dPlanoContas AS dim
    WHERE dim.[Id Conta] = p.[Id Conta]
);
GO


-- 10.4 Transformação e carga da tabela fato fResultado
-- UNPIVOT transforma colunas anuais em linhas.

INSERT INTO dbo.fResultado (
    [ID Conta],
    [Data],
    [Value]
)
SELECT
    d.codigo AS [ID Conta],
    DATEFROMPARTS(CAST(d.ano AS INT), 12, 31) AS [Data],
    CAST(d.valor AS DECIMAL(19,2)) AS [Value]

FROM (
    SELECT
        codigo,
        ano,
        valor
    FROM dbo.stg_DRE
    UNPIVOT (
        valor FOR ano IN ([2025], [2024], [2023])
    ) AS dre_unpivot
) AS d

INNER JOIN dbo.dPlanoContas AS p
    ON d.codigo = p.[Id Conta]

WHERE p.[Lançamento] = 1

AND NOT EXISTS (
    SELECT 1
    FROM dbo.fResultado AS f
    WHERE f.[ID Conta] = d.codigo
      AND f.[Data] = DATEFROMPARTS(CAST(d.ano AS INT), 12, 31)
);
GO


-- 10.5 Validação das tabelas da camada Mart

-- Conferência da dimensão

SELECT *
FROM dbo.dPlanoContas
ORDER BY [Id Conta];


-- Conferência da tabela fato

SELECT *
FROM dbo.fResultado
ORDER BY [ID Conta], [Data] DESC;


-- Contagem dos registros

SELECT COUNT(*) AS TotalDimensao
FROM dbo.dPlanoContas;

SELECT COUNT(*) AS TotalFato
FROM dbo.fResultado;
