DECLARE @DataInicial DATE = '2023-01-01';      -- Data inicial padrão
DECLARE @DataFinal DATE = GETDATE();           -- Data atual
DECLARE @QuantidadeLinhas INT = 2000000;       -- 2 milhões de linhas padrão
DECLARE @ValorInicial DECIMAL(10,2) = 200.00;  -- Valor mínimo padrão
DECLARE @ValorFinal DECIMAL(10,2) = 5000.00;   -- Valor máximo padrão

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Vendas]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[Vendas] (
        [Data] DATE NOT NULL,
        [ValorVenda] DECIMAL(10,2) NOT NULL,
        INDEX IX_Vendas_Data CLUSTERED ([Data])
    );
    PRINT 'Tabela Vendas criada com sucesso.';
END
ELSE
BEGIN
    PRINT 'Tabela Vendas já existe.';
END

BEGIN
    TRUNCATE TABLE [dbo].[Vendas];
    PRINT 'Dados existentes removidos da tabela Vendas.';
END


-- ==============================================================================
-- Geração dos Dados Aleatórios
-- ==============================================================================

PRINT 'Iniciando geração de ' + CAST(@QuantidadeLinhas AS VARCHAR(20)) + ' registros...';
PRINT 'Período: ' + CAST(@DataInicial AS VARCHAR(10)) + ' até ' + CAST(@DataFinal AS VARCHAR(10));
PRINT 'Valores: ' + CAST(@ValorInicial AS VARCHAR(20)) + ' até ' + CAST(@ValorFinal AS VARCHAR(20));

-- Calcula a diferença em dias entre as datas
DECLARE @DiferencaDias INT = DATEDIFF(DAY, @DataInicial, @DataFinal) + 1;

-- Usa CTE recursiva para gerar números sequenciais e depois gerar dados aleatórios
WITH NumeroSequencial AS (
    -- Caso base
    SELECT 1 AS Numero
    
    UNION ALL
    
    -- Caso recursivo
    SELECT Numero + 1
    FROM NumeroSequencial
    WHERE Numero < @QuantidadeLinhas
),
DadosAleatorios AS (
    SELECT 
        -- Gera data aleatória dentro do intervalo especificado
        DATEADD(DAY, 
            ABS(CHECKSUM(NEWID())) % @DiferencaDias, 
            @DataInicial
        ) AS Data,
        
        -- Gera valor aleatório dentro do intervalo especificado
        ROUND(
            @ValorInicial + 
            (ABS(CHECKSUM(NEWID())) % 1000000 / 1000000.0) * 
            (@ValorFinal - @ValorInicial), 
            2
        ) AS ValorVenda
        
    FROM NumeroSequencial
)
INSERT INTO [dbo].[Vendas] (Data, ValorVenda)
SELECT Data, ValorVenda
FROM DadosAleatorios
OPTION (MAXRECURSION 0); -- Remove limite de recursão

-- ==============================================================================
-- Estatísticas e Verificação dos Dados Gerados
-- ==============================================================================

PRINT 'Geração concluída com sucesso!';
PRINT '';
PRINT '=== ESTATÍSTICAS DOS DADOS GERADOS ===';

SELECT 
    'Total de Registros' AS Estatistica,
    FORMAT(COUNT(*), 'N0', 'pt-BR') AS Valor
FROM [dbo].[Vendas]

UNION ALL

SELECT 
    'Período - Data Inicial' AS Estatistica,
    CAST(MIN(Data) AS VARCHAR(10)) AS Valor
FROM [dbo].[Vendas]

UNION ALL

SELECT 
    'Período - Data Final' AS Estatistica,
    CAST(MAX(Data) AS VARCHAR(10)) AS Valor
FROM [dbo].[Vendas]

UNION ALL

SELECT 
    'Valor Mínimo' AS Estatistica,
    'R$ ' + FORMAT(MIN(ValorVenda), 'N2', 'pt-BR') AS Valor
FROM [dbo].[Vendas]

UNION ALL

SELECT 
    'Valor Máximo' AS Estatistica,
    'R$ ' + FORMAT(MAX(ValorVenda), 'N2', 'pt-BR') AS Valor
FROM [dbo].[Vendas]

UNION ALL

SELECT 
    'Valor Médio' AS Estatistica,
    'R$ ' + FORMAT(AVG(ValorVenda), 'N2', 'pt-BR') AS Valor
FROM [dbo].[Vendas]

UNION ALL

SELECT 
    'Soma Total' AS Estatistica,
    'R$ ' + FORMAT(SUM(ValorVenda), 'N2', 'pt-BR') AS Valor
FROM [dbo].[Vendas];

-- ==============================================================================
-- FIM DO SCRIPT
-- ==============================================================================