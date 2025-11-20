-- ==================================================================
-- Stored Procedure: Geração de Calendário Completo
-- Autor: Alison Pezzott
-- Compatível: SQL Server, Azure SQL Database, MS Fabric SQL Database
-- ==================================================================

CREATE OR ALTER PROCEDURE dbo.sp_GerarCalendario
    @DataInicial DATE = NULL,           -- Se NULL, usa ano corrente
    @DataFinal DATE = NULL,             -- Se NULL, usa 3 anos à frente
    @InicioSemana INT = 1,              -- 1=Dom, 2=Seg, ... 7=Sáb
    @MesInicioAnoFiscal INT = 4,        -- Mês de início do ano fiscal
    @DataFechamento INT = 15            -- Dia de fechamento do mês
AS
BEGIN
    SET NOCOUNT ON;
    SET LANGUAGE 'Brazilian';
    
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @TotalRegistros INT;
    DECLARE @Mensagem NVARCHAR(500);
    
    BEGIN TRY
        -- Define parâmetros padrão se não fornecidos
        IF @DataInicial IS NULL
            SET @DataInicial = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);
            
        IF @DataFinal IS NULL
            SET @DataFinal = DATEFROMPARTS(YEAR(GETDATE()) + 3, 12, 31);
        
        -- Validações
        IF @DataInicial >= @DataFinal
            THROW 50001, 'Data inicial deve ser menor que data final', 1;
            
        IF @InicioSemana NOT BETWEEN 1 AND 7
            THROW 50002, 'Início da semana deve ser entre 1 (Domingo) e 7 (Sábado)', 1;
            
        IF @MesInicioAnoFiscal NOT BETWEEN 1 AND 12
            THROW 50003, 'Mês de início do ano fiscal deve ser entre 1 e 12', 1;
            
        IF @DataFechamento NOT BETWEEN 1 AND 28
            THROW 50004, 'Data de fechamento deve ser entre 1 e 28', 1;
        
        -- Log início
        SET @Mensagem = CONCAT('Iniciando geração do calendário de ', 
                               CONVERT(VARCHAR(10), @DataInicial, 103), ' até ', 
                               CONVERT(VARCHAR(10), @DataFinal, 103));
        PRINT @Mensagem;
        
        -- Variáveis auxiliares para otimização
        DECLARE @DataAtual DATE = CAST(GETDATE() AS DATE);
        DECLARE @AnoAtual INT = YEAR(@DataAtual);
        DECLARE @MesAtual INT = MONTH(@DataAtual);
        DECLARE @AnoInicial INT = YEAR(@DataInicial);
        DECLARE @AnoFiscalAtual INT = YEAR(DATEADD(MONTH, 12 - @MesInicioAnoFiscal + 1, @DataAtual));
        
        -- Cria tabela de feriados fixos
        DECLARE @FeriadosFixos TABLE (Dia INT, Mes INT, Feriado VARCHAR(100));
        INSERT INTO @FeriadosFixos (Dia, Mes, Feriado) VALUES
            ( 1,  1, 'Confraternização Universal'),
            (21,  4, 'Tiradentes'),
            ( 1,  5, 'Dia do Trabalhador'),
            ( 7,  9, 'Independência do Brasil'),
            (12, 10, 'Nossa Senhora Aparecida'),
            ( 2, 11, 'Finados'),
            (15, 11, 'Proclamação da República'),
            (20, 11, 'Consciência Negra'),
            (25, 12, 'Natal');
        
        -- =================================================================
        -- ETAPA 1: Criar tabela e popular datas base
        -- =================================================================
        PRINT 'Recriando tabela dbo.Calendario...';
        
        DROP TABLE IF EXISTS dbo.CalendarioStaging;
        
        CREATE TABLE dbo.CalendarioStaging (
            Data DATE NOT NULL PRIMARY KEY,
            -- Campos base
            Ano INT NULL,
            Mes INT NULL, 
            Dia INT NULL,
            MesNome VARCHAR(20) NULL,
            MesNomeAbrev VARCHAR(3) NULL,
            DiaDaSemanaNome VARCHAR(20) NULL,
            DiaDaSemanaAbrev VARCHAR(3) NULL
        );
        
        -- Gera intervalo de datas
        PRINT 'Gerando intervalo de datas...';
        
        ;WITH Numbers AS (
            SELECT 0 AS n
            UNION ALL
            SELECT n + 1
            FROM Numbers
            WHERE n < DATEDIFF(DAY, @DataInicial, @DataFinal)
        )
        INSERT INTO dbo.CalendarioStaging (Data, Ano, Mes, Dia, MesNome, MesNomeAbrev, DiaDaSemanaNome, DiaDaSemanaAbrev)
        SELECT 
            DATEADD(DAY, n, @DataInicial) AS Data,
            YEAR(DATEADD(DAY, n, @DataInicial)) AS Ano,
            MONTH(DATEADD(DAY, n, @DataInicial)) AS Mes,
            DAY(DATEADD(DAY, n, @DataInicial)) AS Dia,
            DATENAME(MONTH, DATEADD(DAY, n, @DataInicial)) AS MesNome,
            LEFT(DATENAME(MONTH, DATEADD(DAY, n, @DataInicial)), 3) AS MesNomeAbrev,
            DATENAME(WEEKDAY, DATEADD(DAY, n, @DataInicial)) AS DiaDaSemanaNome,
            LEFT(DATENAME(WEEKDAY, DATEADD(DAY, n, @DataInicial)), 3) AS DiaDaSemanaAbrev
        FROM Numbers
        OPTION (MAXRECURSION 0);
        
        SET @TotalRegistros = @@ROWCOUNT;
        PRINT CONCAT('Inseridas ', @TotalRegistros, ' datas-base.');
        
        -- =================================================================
        -- ETAPA 2: Adicionar colunas restantes
        -- =================================================================
        PRINT 'Adicionando colunas calculadas...';
        
        ALTER TABLE dbo.CalendarioStaging ADD
            -- Índices e referências
            DataIndice INT NULL,
            DiasParaHoje INT NULL,
            DataAtual VARCHAR(20) NULL,
            
            -- Campos de ano
            AnoInicio DATE NULL,
            AnoFim DATE NULL,
            AnoIndice INT NULL,
            AnoDescrescenteNome VARCHAR(20) NULL,
            AnoDescrescenteNum INT NULL,
            AnosParaHoje INT NULL,
            AnoAtual VARCHAR(20) NULL,
            
            -- Campos de dia
            DiaDoMes INT NULL,
            DiaDoAno INT NULL,
            DiaDaSemanaNum INT NULL,
            
            -- Campos de mês
            MesNum INT NULL,
            MesAnoNome VARCHAR(20) NULL,
            MesAnoNum INT NULL,
            MesDiaNum INT NULL,
            MesDiaNome VARCHAR(20) NULL,
            MesInicio DATE NULL,
            MesFim DATE NULL,
            MesIndice INT NULL,
            MesesParaHoje INT NULL,
            MesAtual VARCHAR(20) NULL,
            MesAtualAbrev VARCHAR(20) NULL,
            MesAnoAtual VARCHAR(20) NULL,
            
            -- Trimestre
            TrimestreNum INT NULL,
            TrimestreNome VARCHAR(20) NULL,
            TrimestreAnoNome VARCHAR(20) NULL,
            TrimestreAnoNum INT NULL,
            TrimestreInicio DATE NULL,
            TrimestreFim DATE NULL,
            TrimestreIndice INT NULL,
            TrimestresParaHoje INT NULL,
            TrimestreAtual VARCHAR(20) NULL,
            TrimestreAnoAtual VARCHAR(20) NULL,
            MesDoTrimestre INT NULL,
            
            -- Semana
            SemanaAno VARCHAR(20) NULL, 
            SemanaDoAno INT NULL,
            SemanaDoMes INT NULL, 
            SemanaInicio DATE NULL,
            SemanaFim DATE NULL,
            SemanaIndice INT NULL,
            SemanasParaHoje INT NULL,
            SemanaAtual VARCHAR(20) NULL,
            
            -- Semestre
            SemestreNum INT NULL,
            SemestreAnoNome VARCHAR(20) NULL,
            SemestreAnoNum INT NULL,
            SemestreInicio DATE NULL,
            SemestreFim DATE NULL,
            SemestreIndice INT NULL,
            SemestresParaHoje INT NULL,
            SemestreAtual VARCHAR(20) NULL,
            
            -- Bimestre
            BimestreNum INT NULL,
            BimestreAnoNome VARCHAR(20) NULL,
            BimestreAnoNum INT NULL,
            BimestreInicio DATE NULL,
            BimestreFim DATE NULL,
            BimestreIndice INT NULL,
            BimestresParaHoje INT NULL,
            BimestreAtual VARCHAR(20) NULL,
            
            -- Quinzena
            QuinzenaNum INT NULL,
            QuinzenaMesAnoNome VARCHAR(20) NULL,
            QuinzenaMesAnoNum INT NULL,
            QuinzenaInicio DATE NULL,
            QuinzenaFim DATE NULL,
            QuinzenaIndice INT NULL,
            QuinzenaAtual VARCHAR(20) NULL,
            
            -- Fechamento
            FechamentoAno INT NULL,
            FechamentoRef DATE NULL,
            FechamentoIndice INT NULL,
            FechamentoMesNome VARCHAR(20) NULL,
            FechamentoMesNomeAbrev VARCHAR(20) NULL,
            FechamentoMesNum INT NULL,
            FechamentoMesAnoNome VARCHAR(20) NULL,
            FechamentoMesAnoNum INT NULL,
            
            -- ISO Week
            ISO_Semana VARCHAR(20) NULL,
            ISO_SemanaDoAno INT NULL,
            ISO_Ano INT NULL,
            ISO_SemanaInicio DATE NULL,
            ISO_SemanaFim DATE NULL,
            ISO_SemanaIndice INT NULL,
            ISO_SemanasParaHoje INT NULL,
            ISO_SemanaAtual VARCHAR(20) NULL,
            
            -- Campos fiscais
            FY_AnoInicial INT NULL,
            FY_AnoFinal INT NULL,
            FY_Ano VARCHAR(20) NULL,
            FY_AnoInicio DATE NULL,
            FY_AnoFim DATE NULL,
            FY_AnosParaHoje INT NULL,
            FY_AnoAtual VARCHAR(20) NULL,
            FY_MesNum INT NULL,  
            FY_MesNome VARCHAR(20) NULL,
            FY_MesNomeAbrev VARCHAR(3) NULL,
            FY_MesAnoNome VARCHAR(20) NULL,
            FY_MesAnoNum INT NULL,
            FY_MesesParaHoje INT NULL,
            FY_MesAtual VARCHAR(20) NULL,
            FY_TrimestreNum INT NULL,
            FY_TrimestreNome VARCHAR(20) NULL,  
            FY_MesDoTrimestre INT NULL,
            FY_TrimestreAnoNome VARCHAR(20) NULL,
            FY_TrimestreAnoNum INT NULL,
            FY_TrimestreInicio DATE NULL,
            FY_TrimestreFim DATE NULL,
            FY_TrimestresParaHoje INT NULL,
            FY_TrimestreAtual VARCHAR(20) NULL,
            FY_DiaDoTrimestre INT NULL,
            
            -- Feriados e dias úteis
            Feriado INT NULL,
            FeriadoNome VARCHAR(100) NULL,
            DiaUtil INT NULL,
            ProximoDiaUtil DATE NULL;
        
        -- =================================================================
        -- ETAPA 3: Preencher campos básicos
        -- =================================================================
        PRINT 'Calculando campos básicos...';
        
        -- Primeiro, preencher o DataIndice usando CTE
        ;WITH IndiceCTE AS (
            SELECT Data, ROW_NUMBER() OVER (ORDER BY Data) as RowNum
            FROM dbo.CalendarioStaging
        )
        UPDATE c SET
            DataIndice = i.RowNum
        FROM dbo.CalendarioStaging c
        INNER JOIN IndiceCTE i ON c.Data = i.Data;
        
        -- Depois, preencher os demais campos
        UPDATE dbo.CalendarioStaging SET
            -- Campos de referência temporal
            DiasParaHoje = DATEDIFF(DAY, Data, @DataAtual),
            DataAtual = IIF(Data = @DataAtual, 'Hoje', CONVERT(VARCHAR(20), Data, 103)),
            
            -- Campos de ano
            AnoInicio = DATEFROMPARTS(Ano, 1, 1),
            AnoFim = DATEFROMPARTS(Ano, 12, 31),
            AnoIndice = Ano - @AnoInicial + 1,
            AnoDescrescenteNome = CAST(Ano AS VARCHAR(20)),
            AnoDescrescenteNum = -Ano,
            AnosParaHoje = Ano - @AnoAtual,
            AnoAtual = IIF(Ano = @AnoAtual, 'Ano Atual', CAST(Ano AS VARCHAR(4))),
            
            -- Campos de dia
            DiaDoMes = Dia,
            DiaDoAno = DATEPART(DAYOFYEAR, Data),
            DiaDaSemanaNum = ((DATEPART(WEEKDAY, Data) + 7 - @InicioSemana) % 7) + 1,
            
            -- Campos de mês
            MesNum = Mes,
            MesAnoNome = CONCAT(Ano, ' ', MesNomeAbrev),
            MesAnoNum = Ano * 100 + Mes,
            MesDiaNum = Mes * 100 + Dia,
            MesDiaNome = CONCAT(MesNomeAbrev, ' ', Dia),
            MesInicio = DATEFROMPARTS(Ano, Mes, 1),
            MesFim = EOMONTH(Data),
            MesIndice = 12 * (Ano - @AnoInicial) + Mes,
            MesesParaHoje = DATEDIFF(MONTH, Data, @DataAtual),
            MesAtual = IIF(Mes = @MesAtual AND Ano = @AnoAtual, 'Mês Atual', MesNome),
            MesAtualAbrev = IIF(Mes = @MesAtual AND Ano = @AnoAtual, 'Mês Atual', MesNomeAbrev),
            MesAnoAtual = IIF(Mes = @MesAtual AND Ano = @AnoAtual, 'Mês Atual', CONCAT(Ano, ' ', MesNomeAbrev));
        
        -- =================================================================
        -- ETAPA 4: Preencher campos de períodos
        -- =================================================================
        PRINT 'Calculando períodos (trimestre, semestre, etc.)...';
        
        UPDATE dbo.CalendarioStaging SET
            -- Trimestre
            TrimestreNum = DATEPART(QUARTER, Data),
            TrimestreNome = CONCAT('T', DATEPART(QUARTER, Data)),
            TrimestreAnoNome = CONCAT(Ano, ' T', DATEPART(QUARTER, Data)),
            TrimestreAnoNum = Ano * 10 + DATEPART(QUARTER, Data),
            TrimestreInicio = DATEFROMPARTS(Ano, (DATEPART(QUARTER, Data) - 1) * 3 + 1, 1),
            TrimestreFim = EOMONTH(DATEFROMPARTS(Ano, DATEPART(QUARTER, Data) * 3, 1)),
            TrimestreIndice = 4 * (Ano - @AnoInicial) + DATEPART(QUARTER, Data),
            TrimestresParaHoje = (Ano * 4 + DATEPART(QUARTER, Data)) - (@AnoAtual * 4 + DATEPART(QUARTER, @DataAtual)),
            TrimestreAtual = IIF(DATEPART(QUARTER, Data) = DATEPART(QUARTER, @DataAtual) AND Ano = @AnoAtual, 'Trimestre Atual', CONCAT('T', DATEPART(QUARTER, Data))),
            TrimestreAnoAtual = IIF(DATEPART(QUARTER, Data) = DATEPART(QUARTER, @DataAtual) AND Ano = @AnoAtual, 'Trimestre Atual', CONCAT(Ano, ' T', DATEPART(QUARTER, Data))),
            MesDoTrimestre = Mes - (DATEPART(QUARTER, Data) - 1) * 3,
            
            -- Semana
            SemanaDoAno = DATEPART(WEEK, Data),
            SemanaAno = CONCAT(Ano, ' S', RIGHT('00' + CAST(DATEPART(WEEK, Data) AS VARCHAR(2)), 2)),
            SemanaDoMes = DATEPART(WEEK, Data) - DATEPART(WEEK, DATEFROMPARTS(Ano, Mes, 1)) + 1,
            SemanaInicio = DATEADD(DAY, 1 - ((DATEPART(WEEKDAY, Data) + 7 - @InicioSemana) % 7), Data),
            SemanaFim = DATEADD(DAY, 7 - ((DATEPART(WEEKDAY, Data) + 7 - @InicioSemana) % 7), Data),
            SemanaIndice = 52 * (Ano - @AnoInicial) + DATEPART(WEEK, Data),
            SemanasParaHoje = (Ano * 52 + DATEPART(WEEK, Data)) - (@AnoAtual * 52 + DATEPART(WEEK, @DataAtual)),
            SemanaAtual = IIF(Ano = @AnoAtual AND DATEPART(WEEK, Data) = DATEPART(WEEK, @DataAtual), 'Semana Atual', CONCAT(Ano, ' S', RIGHT('00' + CAST(DATEPART(WEEK, Data) AS VARCHAR(2)), 2))),
            
            -- Semestre
            SemestreNum = ((Mes - 1) / 6) + 1,
            SemestreAnoNome = CONCAT(Ano, ' S', ((Mes - 1) / 6) + 1),
            SemestreAnoNum = Ano * 10 + (((Mes - 1) / 6) + 1),
            SemestreInicio = DATEFROMPARTS(Ano, (((Mes - 1) / 6)) * 6 + 1, 1),
            SemestreFim = EOMONTH(DATEFROMPARTS(Ano, (((Mes - 1) / 6) + 1) * 6, 1)),
            SemestreIndice = 2 * (Ano - @AnoInicial) + (((Mes - 1) / 6) + 1),
            SemestresParaHoje = (Ano * 2 + (((Mes - 1) / 6) + 1)) - (@AnoAtual * 2 + (((@MesAtual - 1) / 6) + 1)),
            SemestreAtual = IIF(Ano = @AnoAtual AND (((Mes - 1) / 6) + 1) = (((@MesAtual - 1) / 6) + 1), 'Semestre Atual', CONCAT(Ano, ' S', ((Mes - 1) / 6) + 1)),
            
            -- Bimestre
            BimestreNum = (Mes + 1) / 2,
            BimestreAnoNome = CONCAT(Ano, ' B', (Mes + 1) / 2),
            BimestreAnoNum = Ano * 10 + (Mes + 1) / 2,
            BimestreInicio = DATEFROMPARTS(Ano, ((Mes + 1) / 2 - 1) * 2 + 1, 1),
            BimestreFim = EOMONTH(DATEFROMPARTS(Ano, ((Mes + 1) / 2) * 2, 1)),
            BimestreIndice = 6 * (Ano - @AnoInicial) + (Mes + 1) / 2,
            BimestresParaHoje = (Ano * 6 + (Mes + 1) / 2) - (@AnoAtual * 6 + (@MesAtual + 1) / 2),
            BimestreAtual = IIF(Ano = @AnoAtual AND (Mes + 1) / 2 = (@MesAtual + 1) / 2, 'Bimestre Atual', CONCAT(Ano, ' B', (Mes + 1) / 2)),
            
            -- Quinzena
            QuinzenaNum = IIF(Dia <= 15, 1, 2),
            QuinzenaMesAnoNome = CONCAT(Ano, ' ', MesNomeAbrev, ' Q', IIF(Dia <= 15, 1, 2)),
            QuinzenaMesAnoNum = Ano * 100 + Mes * 10 + IIF(Dia <= 15, 1, 2),
            QuinzenaInicio = IIF(Dia <= 15, DATEFROMPARTS(Ano, Mes, 1), DATEFROMPARTS(Ano, Mes, 16)),
            QuinzenaFim = IIF(Dia <= 15, DATEFROMPARTS(Ano, Mes, 15), EOMONTH(Data)),
            QuinzenaIndice = (Ano - @AnoInicial) * 24 + (Mes - 1) * 2 + IIF(Dia <= 15, 1, 2),
            QuinzenaAtual = IIF(Mes = @MesAtual AND Ano = @AnoAtual AND IIF(Dia <= 15, 1, 2) = IIF(DAY(@DataAtual) <= 15, 1, 2), 'Quinzena Atual', CONCAT(Ano, ' ', MesNomeAbrev, ' Q', IIF(Dia <= 15, 1, 2)));
        
        -- =================================================================
        -- ETAPA 5: Campos de fechamento e ISO Week
        -- =================================================================
        PRINT 'Calculando fechamentos e semanas ISO...';
        
        -- Variável para fechamento (evitando recalcular)
        DECLARE @FechamentoCalc TABLE (
            Data DATE PRIMARY KEY,
            FechamentoData DATE,
            FechamentoAno INT,
            FechamentoMes INT
        );
        
        INSERT INTO @FechamentoCalc (Data, FechamentoData, FechamentoAno, FechamentoMes)
        SELECT 
            Data,
            IIF(Dia <= @DataFechamento, 
                DATEFROMPARTS(Ano, Mes, @DataFechamento), 
                DATEADD(MONTH, 1, DATEFROMPARTS(Ano, Mes, @DataFechamento))) AS FechamentoData,
            YEAR(IIF(Dia <= @DataFechamento, 
                DATEFROMPARTS(Ano, Mes, @DataFechamento), 
                DATEADD(MONTH, 1, DATEFROMPARTS(Ano, Mes, @DataFechamento)))) AS FechamentoAno,
            MONTH(IIF(Dia <= @DataFechamento, 
                DATEFROMPARTS(Ano, Mes, @DataFechamento), 
                DATEADD(MONTH, 1, DATEFROMPARTS(Ano, Mes, @DataFechamento)))) AS FechamentoMes
        FROM dbo.CalendarioStaging;
        
        UPDATE c SET
            -- Fechamento (usando tabela auxiliar para otimização)
            FechamentoAno = f.FechamentoAno,
            FechamentoRef = f.FechamentoData,
            FechamentoIndice = (f.FechamentoAno - @AnoInicial) * 12 + f.FechamentoMes,
            FechamentoMesNome = CONCAT(DATENAME(MONTH, f.FechamentoData), ' ', f.FechamentoAno),
            FechamentoMesNomeAbrev = CONCAT(LEFT(DATENAME(MONTH, f.FechamentoData), 3), ' ', f.FechamentoAno),
            FechamentoMesNum = f.FechamentoAno * 100 + f.FechamentoMes,
            FechamentoMesAnoNome = CONCAT(f.FechamentoAno, ' ', LEFT(DATENAME(MONTH, f.FechamentoData), 3)),
            FechamentoMesAnoNum = f.FechamentoAno * 100 + f.FechamentoMes,
            
            -- ISO Week (segunda-feira como início)
            ISO_SemanaDoAno = DATEPART(ISO_WEEK, c.Data),
            ISO_Ano = CASE
                WHEN DATEPART(ISO_WEEK, c.Data) > 50 AND c.Mes = 1  THEN c.Ano - 1
                WHEN DATEPART(ISO_WEEK, c.Data) = 1  AND c.Mes = 12 THEN c.Ano + 1
                ELSE c.Ano END,
            ISO_Semana = CONCAT(CASE
                                    WHEN DATEPART(ISO_WEEK, c.Data) > 50 AND c.Mes = 1  THEN c.Ano - 1
                                    WHEN DATEPART(ISO_WEEK, c.Data) = 1  AND c.Mes = 12 THEN c.Ano + 1
                                    ELSE c.Ano END,
                                ' S', RIGHT('00' + CAST(DATEPART(ISO_WEEK, c.Data) AS VARCHAR(2)), 2)),
            ISO_SemanaInicio = DATEADD(DAY, 1 - ((DATEPART(WEEKDAY, c.Data) + 5) % 7 + 1), c.Data),
            ISO_SemanaFim = DATEADD(DAY, 7 - ((DATEPART(WEEKDAY, c.Data) + 5) % 7 + 1), c.Data),
            ISO_SemanaIndice = 52 * ((CASE
                                        WHEN DATEPART(ISO_WEEK, c.Data) > 50 AND c.Mes = 1  THEN c.Ano - 1
                                        WHEN DATEPART(ISO_WEEK, c.Data) = 1  AND c.Mes = 12 THEN c.Ano + 1
                                        ELSE c.Ano
                                      END) - @AnoInicial) + DATEPART(ISO_WEEK, c.Data),
            ISO_SemanasParaHoje = ((CASE
                                        WHEN DATEPART(ISO_WEEK, c.Data) > 50 AND c.Mes = 1  THEN c.Ano - 1
                                        WHEN DATEPART(ISO_WEEK, c.Data) = 1  AND c.Mes = 12 THEN c.Ano + 1
                                        ELSE c.Ano
                                    END) * 52 + DATEPART(ISO_WEEK, c.Data))
                                  - (@AnoAtual * 52 + DATEPART(ISO_WEEK, @DataAtual)),
            ISO_SemanaAtual = IIF(
                DATEPART(ISO_WEEK, c.Data) = DATEPART(ISO_WEEK, @DataAtual) AND
                (CASE
                    WHEN DATEPART(ISO_WEEK, c.Data) > 50 AND c.Mes = 1  THEN c.Ano - 1
                    WHEN DATEPART(ISO_WEEK, c.Data) = 1  AND c.Mes = 12 THEN c.Ano + 1
                    ELSE c.Ano
                 END) = @AnoAtual,
                'Semana Atual',
                CONCAT(
                    CASE
                        WHEN DATEPART(ISO_WEEK, c.Data) > 50 AND c.Mes = 1  THEN c.Ano - 1
                        WHEN DATEPART(ISO_WEEK, c.Data) = 1  AND c.Mes = 12 THEN c.Ano + 1
                        ELSE c.Ano
                    END, ' S', RIGHT('00' + CAST(DATEPART(ISO_WEEK, c.Data) AS VARCHAR(2)), 2)
                )
            )
        FROM dbo.CalendarioStaging c
        INNER JOIN @FechamentoCalc f ON c.Data = f.Data;
        
        -- =================================================================
        -- ETAPA 6: Campos fiscais
        -- =================================================================
        PRINT 'Calculando campos fiscais...';
        
        -- Tabela auxiliar para cálculos fiscais
        DECLARE @FiscalCalc TABLE (
            Data DATE PRIMARY KEY,
            FY_AnoInicial INT,
            FY_AnoFinal INT,
            FY_MesNumFiscal INT,
            FY_TrimestreNumFiscal INT,
            FY_MesDoTrimestreFiscal INT
        );
        
        INSERT INTO @FiscalCalc (Data, FY_AnoInicial, FY_AnoFinal, FY_MesNumFiscal, FY_TrimestreNumFiscal, FY_MesDoTrimestreFiscal)
        SELECT 
            Data,
            YEAR(DATEADD(MONTH, -(@MesInicioAnoFiscal - 1), Data)) AS FY_AnoInicial,
            YEAR(DATEADD(MONTH, -(@MesInicioAnoFiscal - 1), Data)) + 1 AS FY_AnoFinal,
            DATEPART(MONTH, DATEADD(MONTH, -(@MesInicioAnoFiscal - 1), Data)) AS FY_MesNumFiscal,
            CASE 
                WHEN Mes >= @MesInicioAnoFiscal 
                    THEN ((Mes - @MesInicioAnoFiscal) / 3) + 1
                ELSE ((Mes + (12 - @MesInicioAnoFiscal)) / 3) + 1 
            END AS FY_TrimestreNumFiscal,
            ((Mes - @MesInicioAnoFiscal + 12) % 3) + 1 AS FY_MesDoTrimestreFiscal
        FROM dbo.CalendarioStaging;
        
        -- Calcular trimestre fiscal atual para comparações
        DECLARE @CurrentFYTrimNum INT = CASE 
            WHEN @MesAtual >= @MesInicioAnoFiscal 
                THEN (@AnoAtual - @AnoInicial) * 4 + ((@MesAtual - @MesInicioAnoFiscal) / 3) + 1
            ELSE (@AnoAtual - @AnoInicial - 1) * 4 + ((@MesAtual + (12 - @MesInicioAnoFiscal)) / 3) + 1
        END;
        
        UPDATE c SET
            -- Ano Fiscal
            FY_AnoInicial = f.FY_AnoInicial,
            FY_AnoFinal = f.FY_AnoFinal,
            FY_Ano = CONCAT(f.FY_AnoInicial, '/', f.FY_AnoFinal),
            FY_AnoInicio = DATEFROMPARTS(f.FY_AnoInicial, @MesInicioAnoFiscal, 1),
            FY_AnoFim = DATEADD(DAY, -1, DATEFROMPARTS(f.FY_AnoFinal, @MesInicioAnoFiscal, 1)),
            FY_AnosParaHoje = f.FY_AnoInicial - @AnoAtual,
            FY_AnoAtual = IIF(f.FY_AnoInicial = @AnoFiscalAtual, 'Ano Fiscal Atual', CONCAT(f.FY_AnoInicial, '/', f.FY_AnoFinal)),
            
            -- Mês Fiscal
            FY_MesNum = f.FY_MesNumFiscal,
            FY_MesNome = c.MesNome,
            FY_MesNomeAbrev = c.MesNomeAbrev,
            FY_MesAnoNome = CONCAT(c.Ano, ' ', c.MesNome),
            FY_MesAnoNum = c.Ano * 100 + c.Mes,
            FY_MesesParaHoje = (CASE 
                WHEN c.Mes >= @MesInicioAnoFiscal 
                    THEN (c.Ano * 12 + c.Mes) 
                ELSE ((c.Ano-1) * 12 + c.Mes + 12 - @MesInicioAnoFiscal)
            END) - (@AnoAtual * 12 + @MesAtual),
            FY_MesAtual = IIF(
                (CASE 
                    WHEN c.Mes >= @MesInicioAnoFiscal 
                    THEN (c.Ano * 12 + c.Mes) 
                ELSE ((c.Ano-1) * 12 + c.Mes + 12 - @MesInicioAnoFiscal)
                END) - (@AnoAtual * 12 + @MesAtual) = 0,
                'Mês Atual', 
                CONCAT(c.Ano, ' ', c.MesNome)
            ),
            
            -- Trimestre Fiscal
            FY_TrimestreNum = CASE 
                WHEN c.Mes >= @MesInicioAnoFiscal 
                    THEN (c.Ano - @AnoInicial) * 4 + f.FY_TrimestreNumFiscal
                ELSE (c.Ano - @AnoInicial - 1) * 4 + f.FY_TrimestreNumFiscal
            END,
            FY_TrimestreNome = CONCAT('T', f.FY_TrimestreNumFiscal),
            FY_MesDoTrimestre = f.FY_MesDoTrimestreFiscal,
            FY_TrimestreAnoNome = CONCAT(c.Ano, ' T', f.FY_TrimestreNumFiscal),
            FY_TrimestreAnoNum = c.Ano * 100 + f.FY_TrimestreNumFiscal,
            FY_TrimestreInicio = DATEADD(MONTH, ((f.FY_TrimestreNumFiscal - 1) * 3),
                DATEFROMPARTS(CASE WHEN c.Mes >= @MesInicioAnoFiscal THEN c.Ano ELSE c.Ano - 1 END, @MesInicioAnoFiscal, 1)),
            FY_TrimestreFim = DATEADD(DAY, -1, DATEADD(MONTH, 3,
                              DATEADD(MONTH, ((f.FY_TrimestreNumFiscal - 1) * 3),
                                DATEFROMPARTS(CASE WHEN c.Mes >= @MesInicioAnoFiscal THEN c.Ano ELSE c.Ano - 1 END, @MesInicioAnoFiscal, 1)))),
            FY_TrimestresParaHoje = CASE 
                WHEN c.Mes >= @MesInicioAnoFiscal 
                    THEN (c.Ano - @AnoInicial) * 4 + f.FY_TrimestreNumFiscal
                ELSE (c.Ano - @AnoInicial - 1) * 4 + f.FY_TrimestreNumFiscal
            END - @CurrentFYTrimNum,
            FY_TrimestreAtual = IIF(
                (CASE 
                    WHEN c.Mes >= @MesInicioAnoFiscal 
                    THEN (c.Ano - @AnoInicial) * 4 + f.FY_TrimestreNumFiscal
                ELSE (c.Ano - @AnoInicial - 1) * 4 + f.FY_TrimestreNumFiscal
                END) - @CurrentFYTrimNum = 0, 
                'Trimestre Atual', 
                CONCAT(c.Ano, ' T', f.FY_TrimestreNumFiscal)
            ),
            FY_DiaDoTrimestre = DATEDIFF(DAY,
                DATEADD(MONTH, ((f.FY_TrimestreNumFiscal - 1) * 3),
                    DATEFROMPARTS(CASE WHEN c.Mes >= @MesInicioAnoFiscal THEN c.Ano ELSE c.Ano - 1 END, @MesInicioAnoFiscal, 1)),
                c.Data
            ) + 1
        FROM dbo.CalendarioStaging c
        INNER JOIN @FiscalCalc f ON c.Data = f.Data;
        
        -- =================================================================
        -- ETAPA 7: Feriados e dias úteis
        -- =================================================================
        PRINT 'Processando feriados...';
        
        -- Tabela de feriados
        DECLARE @Feriados TABLE (Data DATE PRIMARY KEY, Nome VARCHAR(100) NOT NULL);
        
        -- Feriados fixos
        ;WITH Anos AS (
            SELECT DISTINCT Ano FROM dbo.CalendarioStaging
        )
        INSERT INTO @Feriados (Data, Nome)
        SELECT DATEFROMPARTS(a.Ano, f.Mes, f.Dia), f.Feriado
        FROM Anos a
        CROSS JOIN @FeriadosFixos f;
        
        -- Feriados móveis (Páscoa)
        ;WITH Anos AS (
            SELECT DISTINCT Ano FROM dbo.CalendarioStaging
        ),
        Pascoa AS (
            SELECT 
                Ano,
                DATEADD(DAY,
                    ((19 * (Ano % 19) + 24) % 30) + ((2 * (Ano % 4) + 4 * (Ano % 7) + 6 * ((19 * (Ano % 19) + 24) % 30) + 5) % 7),
                    DATEFROMPARTS(Ano, 3, 22)
                ) AS DataPascoa
            FROM Anos
        )
        INSERT INTO @Feriados (Data, Nome)
        SELECT DATEADD(DAY, -47, DataPascoa), 'Carnaval' FROM Pascoa
        UNION ALL
        SELECT DATEADD(DAY, -2, DataPascoa), 'Sexta-Feira Santa' FROM Pascoa
        UNION ALL
        SELECT DATEADD(DAY, 60, DataPascoa), 'Corpus Christi' FROM Pascoa;
        
        -- Marcar feriados
        UPDATE c SET
            c.Feriado = 1,
            c.FeriadoNome = f.Nome
        FROM dbo.CalendarioStaging c
        INNER JOIN @Feriados f ON f.Data = c.Data;
        
        -- Calcular dias úteis
        PRINT 'Calculando dias úteis...';
        
        UPDATE dbo.CalendarioStaging SET
            DiaUtil = CASE
                WHEN DiaDaSemanaNome IN (N'sábado', N'domingo') THEN 0
                WHEN ISNULL(Feriado, 0) = 1 THEN 0
                ELSE 1
            END;
        
        -- Próximo dia útil (otimizado com OUTER APPLY)
        UPDATE c SET
            ProximoDiaUtil = prox.Data
        FROM dbo.CalendarioStaging c
        OUTER APPLY (
            SELECT TOP 1 Data
            FROM dbo.CalendarioStaging c2
            WHERE c2.Data > c.Data AND c2.DiaUtil = 1
            ORDER BY c2.Data
        ) prox;
        
        -- Tornar DataIndice NOT NULL
        ALTER TABLE dbo.CalendarioStaging ALTER COLUMN DataIndice INT NOT NULL;

        -- =================================================================
        -- ETAPA 8: Gerar tabela final dbo.Calendario sem Dia/Mes
        -- =================================================================
        PRINT 'Gerando tabela final dbo.Calendario sem colunas Dia e Mes...';

        DROP TABLE IF EXISTS dbo.Calendario;

        SELECT 
            Data,
            Ano,
            MesNome,
            MesNomeAbrev,
            DiaDaSemanaNome,
            DiaDaSemanaAbrev,
            DataIndice,
            DiasParaHoje,
            DataAtual,
            AnoInicio,
            AnoFim,
            AnoIndice,
            AnoDescrescenteNome,
            AnoDescrescenteNum,
            AnosParaHoje,
            AnoAtual,
            DiaDoMes,
            DiaDoAno,
            DiaDaSemanaNum,
            MesNum,
            MesAnoNome,
            MesAnoNum,
            MesDiaNum,
            MesDiaNome,
            MesInicio,
            MesFim,
            MesIndice,
            MesesParaHoje,
            MesAtual,
            MesAtualAbrev,
            MesAnoAtual,
            TrimestreNum,
            TrimestreNome,
            TrimestreAnoNome,
            TrimestreAnoNum,
            TrimestreInicio,
            TrimestreFim,
            TrimestreIndice,
            TrimestresParaHoje,
            TrimestreAtual,
            TrimestreAnoAtual,
            MesDoTrimestre,
            SemanaDoAno,
            SemanaAno,
            SemanaDoMes,
            SemanaInicio,
            SemanaFim,
            SemanaIndice,
            SemanasParaHoje,
            SemanaAtual,
            SemestreNum,
            SemestreAnoNome,
            SemestreAnoNum,
            SemestreInicio,
            SemestreFim,
            SemestreIndice,
            SemestresParaHoje,
            SemestreAtual,
            BimestreNum,
            BimestreAnoNome,
            BimestreAnoNum,
            BimestreInicio,
            BimestreFim,
            BimestreIndice,
            BimestresParaHoje,
            BimestreAtual,
            QuinzenaNum,
            QuinzenaMesAnoNome,
            QuinzenaMesAnoNum,
            QuinzenaInicio,
            QuinzenaFim,
            QuinzenaIndice,
            QuinzenaAtual,
            FechamentoAno,
            FechamentoRef,
            FechamentoIndice,
            FechamentoMesNome,
            FechamentoMesNomeAbrev,
            FechamentoMesNum,
            FechamentoMesAnoNome,
            FechamentoMesAnoNum,
            ISO_Semana,
            ISO_SemanaDoAno,
            ISO_Ano,
            ISO_SemanaInicio,
            ISO_SemanaFim,
            ISO_SemanaIndice,
            ISO_SemanasParaHoje,
            ISO_SemanaAtual,
            FY_AnoInicial,
            FY_AnoFinal,
            FY_Ano,
            FY_AnoInicio,
            FY_AnoFim,
            FY_AnosParaHoje,
            FY_AnoAtual,
            FY_MesNum,
            FY_MesNome,
            FY_MesNomeAbrev,
            FY_MesAnoNome,
            FY_MesAnoNum,
            FY_MesesParaHoje,
            FY_MesAtual,
            FY_TrimestreNum,
            FY_TrimestreNome,
            FY_MesDoTrimestre,
            FY_TrimestreAnoNome,
            FY_TrimestreAnoNum,
            FY_TrimestreInicio,
            FY_TrimestreFim,
            FY_TrimestresParaHoje,
            FY_TrimestreAtual,
            FY_DiaDoTrimestre,
            Feriado,
            FeriadoNome,
            DiaUtil,
            ProximoDiaUtil
        INTO dbo.Calendario
        FROM dbo.CalendarioStaging;

        -- Garantir DataIndice NOT NULL e PK na tabela final
        ALTER TABLE dbo.Calendario ALTER COLUMN DataIndice INT NOT NULL;
        ALTER TABLE dbo.Calendario ADD CONSTRAINT PK_Calendario PRIMARY KEY CLUSTERED (Data);

        -- =================================================================
        -- ETAPA 9: Estatísticas e finalização
        -- =================================================================
        SELECT @TotalRegistros = COUNT(*) FROM dbo.Calendario;
        
        DECLARE @Tempo INT = DATEDIFF(MILLISECOND, @Inicio, GETDATE());
        
        SET @Mensagem = CONCAT('Calendário gerado com sucesso! ', 
                              @TotalRegistros, ' registros processados em ', 
                              @Tempo, 'ms (', 
                              CASE WHEN @Tempo > 0 THEN CAST((@TotalRegistros * 1000 / @Tempo) AS VARCHAR(20)) ELSE '∞' END, 
                              ' registros/segundo)');
        
        PRINT @Mensagem;
        
        -- Retorna estatísticas
        SELECT 
            TempoExecucao_ms = @Tempo,
            TotalRegistros = @TotalRegistros,
            RegistrosPorSegundo = CASE WHEN @Tempo > 0 THEN (@TotalRegistros * 1000 / @Tempo) ELSE NULL END,
            DataInicial = @DataInicial,
            DataFinal = @DataFinal,
            Mensagem = @Mensagem;

        -- Exemplo de consulta para verificação (10 primeiras e 10 últimas)
        WITH primeiras AS (
            SELECT TOP 10 * FROM dbo.Calendario ORDER BY Data ASC
        ),
        ultimas AS (
            SELECT TOP 10 * FROM dbo.Calendario ORDER BY Data DESC
        )
        SELECT * FROM primeiras
        UNION
        SELECT * FROM ultimas
        ORDER BY Data ASC;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        SET @Mensagem = CONCAT('Erro na geração do calendário: ', @ErrorMessage);
        PRINT @Mensagem;
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        
    END CATCH
END;
