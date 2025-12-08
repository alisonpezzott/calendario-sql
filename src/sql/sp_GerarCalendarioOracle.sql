-- ==================================================================
-- Stored Procedure: Geração de Calendário Completo
-- Autor: Fabiano Fonseca
-- Compatível: Oracle 11g ou superior
-- ==================================================================
CREATE OR REPLACE PROCEDURE sp_GerarCalendarioOracle (
    p_DataInicial IN DATE DEFAULT NULL,           -- Se NULL, usa ano corrente (1º Jan)
    p_DataFinal IN DATE DEFAULT NULL,             -- Se NULL, usa 3 anos à frente (31 Dez)
    p_InicioSemana IN NUMBER DEFAULT 1,           -- 1=Dom, 2=Seg, ... 7=Sáb (Semelhante ao SQL Server/Java)
    p_MesInicioAnoFiscal IN NUMBER DEFAULT 4,     -- Mês de início do ano fiscal (Abril)
    p_DataFechamento IN NUMBER DEFAULT 15         -- Dia de fechamento do mês
)
AS
    -- Variáveis de Log e Controle
    v_Inicio DATE := SYSDATE;
    v_TotalRegistros NUMBER;
    v_Mensagem VARCHAR2(500);

    -- Variáveis de Parâmetros e Auxiliares
    v_DataInicio DATE;
    v_DataFim DATE;
    v_DataAtual DATE := TRUNC(SYSDATE);
    v_AnoAtual NUMBER := TO_CHAR(v_DataAtual, 'YYYY');
    v_MesAtual NUMBER := TO_CHAR(v_DataAtual, 'MM');
    v_DiaAtual NUMBER := TO_CHAR(v_DataAtual, 'DD'); 
    v_AnoInicial NUMBER;
    v_AnoFiscalAtual NUMBER;

    -- Tabela para Feriados Fixos (TYPE PL/SQL)
    TYPE t_FeriadosFixos IS TABLE OF VARCHAR2(100) INDEX BY VARCHAR2(5);
    v_FeriadosFixos t_FeriadosFixos;
    
    -- Coleção para iteração dinâmica de anos
    TYPE t_AnoList IS TABLE OF NUMBER;
    v_AnoList t_AnoList;

    -- Exceções
    e_DataInvalida EXCEPTION;
    e_InicioSemanaInvalido EXCEPTION;
    e_MesFiscalInvalido EXCEPTION;
    e_DataFechamentoInvalida EXCEPTION;

    PRAGMA EXCEPTION_INIT(e_DataInvalida, -20001);
    PRAGMA EXCEPTION_INIT(e_InicioSemanaInvalido, -20002);
    PRAGMA EXCEPTION_INIT(e_MesFiscalInvalido, -20003);
    PRAGMA EXCEPTION_INIT(e_DataFechamentoInvalida, -20004);

BEGIN
    -- Define parâmetros padrão se não fornecidos
    v_DataInicio := NVL(p_DataInicial, TRUNC(ADD_MONTHS(SYSDATE, 0), 'YYYY'));
    v_DataFim := NVL(p_DataFinal, TRUNC(ADD_MONTHS(SYSDATE, 36), 'YYYY') - 1);

    -- Validações
    IF v_DataInicio >= v_DataFim THEN
        RAISE_APPLICATION_ERROR(-20001, 'Data inicial deve ser menor que data final');
    END IF;

    IF p_InicioSemana NOT BETWEEN 1 AND 7 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Início da semana deve ser entre 1 (Domingo) e 7 (Sábado)');
    END IF;

    IF p_MesInicioAnoFiscal NOT BETWEEN 1 AND 12 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Mês de início do ano fiscal deve ser entre 1 e 12');
    END IF;

    IF p_DataFechamento NOT BETWEEN 1 AND 28 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Data de fechamento deve ser entre 1 e 28');
    END IF;

    v_AnoInicial := TO_CHAR(v_DataInicio, 'YYYY');
    v_AnoFiscalAtual := TO_NUMBER(TO_CHAR(ADD_MONTHS(v_DataAtual, -(p_MesInicioAnoFiscal - 1)), 'YYYY'));

    v_Mensagem := 'Iniciando RECRIAÇÃO do calendário de ' || TO_CHAR(v_DataInicio, 'DD/MM/YYYY') || ' até ' || TO_CHAR(v_DataFim, 'DD/MM/YYYY');
    DBMS_OUTPUT.PUT_LINE(v_Mensagem);

    -- Inicializa Feriados Fixos (Chave: 'MM-DD')
    v_FeriadosFixos('01-01') := 'Confraternização Universal';
    v_FeriadosFixos('04-21') := 'Tiradentes';
    v_FeriadosFixos('05-01') := 'Dia do Trabalhador';
    v_FeriadosFixos('09-07') := 'Independência do Brasil';
    v_FeriadosFixos('10-12') := 'Nossa Senhora Aparecida';
    v_FeriadosFixos('11-02') := 'Finados';
    v_FeriadosFixos('11-15') := 'Proclamação da República';
    v_FeriadosFixos('11-20') := 'Consciência Negra';
    v_FeriadosFixos('12-25') := 'Natal';
    
    -- =================================================================
    -- ETAPA 1: Criar tabela e popular datas base (DDL DINÂMICO)
    -- =================================================================
    DBMS_OUTPUT.PUT_LINE('Recriando tabela CALENDARIO (DROP/CREATE)...');

    -- DROP TABLE 
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE CALENDARIO CASCADE CONSTRAINTS';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN -- ORA-00942: tabela ou view não existe
                RAISE;
            END IF;
    END;

    -- CREATE TABLE (COMPLETA - PADRÃO TDM-L/SQL SERVER)
    EXECUTE IMMEDIATE '
        CREATE TABLE CALENDARIO (
            Data DATE NOT NULL PRIMARY KEY,
            -- Campos base
            Ano NUMBER(4) NULL,
            MesNum NUMBER(2) NULL, 
            DiaDoMes NUMBER(2) NULL, -- RENOMEADO de DiasNum
            MesNome VARCHAR2(20) NULL,
            MesNomeAbrev VARCHAR2(3) NULL, -- RENOMEADO de MesAbrev
            DiaDaSemanaNome VARCHAR2(20) NULL, -- RENOMEADO de DiaSemanaNome
            DiaDaSemanaAbrev VARCHAR2(3) NULL, -- RENOMEADO de DiaSemanaAbrev
            -- Referências de Tempo
            DataIndice NUMBER NULL,
            DiasParaHoje NUMBER NULL,
            DataAtual VARCHAR2(20) NULL,
            -- Campos de ano
            AnoInicio DATE NULL,
            AnoFim DATE NULL,
            AnoIndice NUMBER NULL,
            AnoDescrescenteNome VARCHAR2(20) NULL, -- ADICIONADO
            AnoDescrescenteNum NUMBER NULL, -- ADICIONADO
            AnosParaHoje NUMBER NULL,
            AnoAtual VARCHAR2(20) NULL,
            -- Campos de dia
            DiaDoAno NUMBER NULL,
            DiaDaSemanaNum NUMBER NULL, -- RENOMEADO de DiaSemanaNum
            -- Campos de mês
            MesAnoNome VARCHAR2(20) NULL, -- ADICIONADO
            MesAnoNum NUMBER NULL,
            MesDiaNum NUMBER NULL, -- ADICIONADO
            MesDiaNome VARCHAR2(20) NULL, -- ADICIONADO
            MesInicio DATE NULL,
            MesFim DATE NULL,
            MesIndice NUMBER NULL,
            MesesParaHoje NUMBER NULL,
            MesAtual VARCHAR2(20) NULL,
            MesAtualAbrev VARCHAR2(20) NULL, -- ADICIONADO
            MesAnoAtual VARCHAR2(20) NULL, -- ADICIONADO
            -- Trimestre
            TrimestreNum NUMBER NULL,
            TrimestreNome VARCHAR2(20) NULL, -- ADICIONADO
            TrimestreAnoNome VARCHAR2(20) NULL, -- ADICIONADO
            TrimestreAnoNum NUMBER NULL,
            TrimestreInicio DATE NULL,
            TrimestreFim DATE NULL, -- RENOMEADO de Trimestrefim
            TrimestreIndice NUMBER NULL,
            TrimestresParaHoje NUMBER NULL,
            TrimestreAtual VARCHAR2(20) NULL,
            TrimestreAnoAtual VARCHAR2(20) NULL, -- ADICIONADO
            MesDoTrimestre NUMBER NULL,
            -- Semana
            SemanaAno VARCHAR2(20) NULL, -- ADICIONADO
            SemanaDoAno NUMBER NULL,
            SemanaDoMes NUMBER NULL, -- RENOMEADO de SemanaDOMes
            SemanaInicio DATE NULL,
            SemanaFim DATE NULL,
            SemanaIndice NUMBER NULL,
            SemanasParaHoje NUMBER NULL, -- RENOMEADO de SemanaParaHoje
            SemanaAtual VARCHAR2(20) NULL,
            -- Semestre
            SemestreNum NUMBER NULL,
            SemestreAnoNum NUMBER NULL,
            SemestreAnoNome VARCHAR2(20) NULL, -- ADICIONADO
            SemestreInicio DATE NULL,
            SemestreFim DATE NULL,
            SemestreIndice NUMBER NULL,
            SemestresParaHoje NUMBER NULL,
            SemestreAtual VARCHAR2(20) NULL,
            -- Bimestre
            BimestreNum NUMBER NULL,
            BimestreAnoNum NUMBER NULL,
            BimestreAnoNome VARCHAR2(20) NULL, -- ADICIONADO
            BimestreInicio DATE NULL,
            BimestreFim DATE NULL, -- RENOMEADO de Bimestrefim
            BimestreIndice NUMBER NULL,
            BimestresParaHoje NUMBER NULL,
            BimestreAtual VARCHAR2(20) NULL,
            -- Quinzena
            QuinzenaNum NUMBER NULL,
            QuinzenaMesAnoNome VARCHAR2(20) NULL, -- ADICIONADO
            QuinzenaMesAnoNum NUMBER NULL, -- ADICIONADO
            QuinzenaInicio DATE NULL,
            QuinzenaFim DATE NULL,
            QuinzenaIndice NUMBER NULL,
            QuinzenaAtual VARCHAR2(20) NULL,
            -- Fechamento
            FechamentoAno NUMBER NULL,
            FechamentoRef DATE NULL,
            FechamentoIndice NUMBER NULL,
            FechamentoMesNome VARCHAR2(20) NULL, -- ADICIONADO
            FechamentoMesNomeAbrev VARCHAR2(20) NULL, -- ADICIONADO
            FechamentoMesNum NUMBER NULL,
            FechamentoMesAnoNome VARCHAR2(20) NULL, -- ADICIONADO
            FechamentoMesAnoNum NUMBER NULL, -- ADICIONADO
            -- ISO Week
            ISO_Semana VARCHAR2(20) NULL, -- ADICIONADO
            ISO_SemanaDoAno NUMBER NULL,
            ISO_Ano NUMBER NULL,
            ISO_SemanaInicio DATE NULL,
            ISO_SemanaFim DATE NULL,
            ISO_SemanaIndice NUMBER NULL,
            ISO_SemanasParaHoje NUMBER NULL, -- RENOMEADO de ISO_SemanaParaHoje
            ISO_SemanaAtual VARCHAR2(20) NULL,
            -- Ano Fiscal (FY - Fiscal Year)
            FY_AnoInicial NUMBER NULL,
            FY_AnoFinal NUMBER NULL,
            FY_Ano VARCHAR2(20) NULL, -- ADICIONADO
            FY_AnoInicio DATE NULL,
            FY_AnoFim DATE NULL,
            FY_AnosParaHoje NUMBER NULL,
            FY_AnoAtual VARCHAR2(20) NULL,
            -- Mês Fiscal
            FY_MesNum NUMBER NULL,  
            FY_MesNome VARCHAR2(20) NULL, -- ADICIONADO
            FY_MesNomeAbrev VARCHAR2(3) NULL, -- ADICIONADO
            FY_MesAnoNome VARCHAR2(20) NULL, -- ADICIONADO
            FY_MesesParaHoje NUMBER NULL,
            FY_MesAtual VARCHAR2(20) NULL,
            -- Trimestre Fiscal
            FY_TrimestreNum NUMBER NULL,
            FY_TrimestreNome VARCHAR2(20) NULL, -- ADICIONADO
            FY_MesDoTrimestre NUMBER NULL,
            FY_TrimestreAnoNome VARCHAR2(20) NULL, -- ADICIONADO
            FY_TrimestreAnoNum NUMBER NULL,
            FY_TrimestreInicio DATE NULL,
            FY_TrimestreFim DATE NULL, -- RENOMEADO de FY_Trimestrefim
            FY_TrimestresParaHoje NUMBER NULL,
            FY_TrimestreAtual VARCHAR2(20) NULL,
            FY_DiaDoTrimestre NUMBER NULL,
            -- Feriados e Utilidade
            Feriado NUMBER(1) DEFAULT 0 NOT NULL,
            FeriadoNome VARCHAR2(100) NULL,
            DiaUtil NUMBER(1) DEFAULT 0 NOT NULL,
            ProximoDiaUtil DATE NULL
        )';
        
    -- Gera intervalo de datas (DML DINÂMICO)
    DBMS_OUTPUT.PUT_LINE('Gerando intervalo de datas...');
    
    EXECUTE IMMEDIATE '
        INSERT INTO CALENDARIO (
            Data, Ano, MesNum, DiaDoMes, MesNome, MesNomeAbrev, DiaDaSemanaNome, DiaDaSemanaAbrev -- Nomes corrigidos
        )
        SELECT 
            :1 + LEVEL - 1 AS Data,
            TO_NUMBER(TO_CHAR(:2 + LEVEL - 1, ''YYYY'')) AS Ano,
            TO_NUMBER(TO_CHAR(:3 + LEVEL - 1, ''MM'')) AS MesNum,
            TO_NUMBER(TO_CHAR(:4 + LEVEL - 1, ''DD'')) AS DiaDoMes, -- Ajustado
            TO_CHAR(:5 + LEVEL - 1, ''Month'', ''NLS_DATE_LANGUAGE=PORTUGUESE'') AS MesNome,
            TO_CHAR(:6 + LEVEL - 1, ''MON'', ''NLS_DATE_LANGUAGE=PORTUGUESE'') AS MesNomeAbrev, -- Ajustado
            TO_CHAR(:7 + LEVEL - 1, ''Day'', ''NLS_DATE_LANGUAGE=PORTUGUESE'') AS DiaDaSemanaNome, -- Ajustado
            TO_CHAR(:8 + LEVEL - 1, ''DY'', ''NLS_DATE_LANGUAGE=PORTUGUESE'') AS DiaDaSemanaAbrev -- Ajustado
        FROM DUAL
        CONNECT BY LEVEL <= :9 - :10 + 1
    ' USING v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataFim, v_DataInicio;
    
    v_TotalRegistros := SQL%ROWCOUNT;
    DBMS_OUTPUT.PUT_LINE('Inseridas ' || v_TotalRegistros || ' datas-base.');
    
    -- =================================================================
    -- ETAPA 2 a 6: Preencher campos (DML DINÂMICO) - Inclui campos adicionais e renomeados
    -- =================================================================
    DBMS_OUTPUT.PUT_LINE('Calculando campos de referência e períodos...');
    
    -- Combinação dos UPDATES para otimização...
    EXECUTE IMMEDIATE '
        UPDATE CALENDARIO SET
            -- Referências de Tempo
            DataIndice = Data - DATE ''' || TO_CHAR(v_DataInicio, 'YYYY-MM-DD') || ''' + 1,
            DiasParaHoje = TRUNC(Data) - :1,
            DataAtual = CASE WHEN Data = :2 THEN ''Hoje'' ELSE TO_CHAR(Data, ''DD/MM/YYYY'') END,
            
            -- Ano
            AnoInicio = TRUNC(Data, ''YYYY''),
            AnoFim = ADD_MONTHS(TRUNC(Data, ''YYYY''), 12) - 1,
            AnoIndice = Ano - :3 + 1,
            AnoDescrescenteNome = TO_CHAR(Ano) || '' Descrescente'', -- ADICIONADO
            AnoDescrescenteNum = -Ano, -- ADICIONADO
            AnosParaHoje = Ano - :4,
            AnoAtual = CASE WHEN Ano = :5 THEN ''Ano Atual'' ELSE TO_CHAR(Ano) END,
            
            -- Dia
            DiaDoAno = TO_NUMBER(TO_CHAR(Data, ''DDD'')),
            DiaDaSemanaNum = MOD(TO_NUMBER(TO_CHAR(Data, ''D'')) + 7 - :6, 7) + 1, -- RENOMEADO
            
            -- Mês
            MesAnoNum = Ano * 100 + MesNum,
            MesAnoNome = TO_CHAR(Ano) || '' '' || TRIM(MesNome), -- ADICIONADO
            MesDiaNum = Ano * 10000 + MesNum * 100 + DiaDoMes, -- ADICIONADO
            MesDiaNome = TRIM(MesNome) || '' '' || TO_CHAR(DiaDoMes), -- ADICIONADO
            MesInicio = TRUNC(Data, ''MM''),
            MesFim = LAST_DAY(Data),
            MesIndice = 12 * (Ano - :7) + MesNum,
            MesesParaHoje = TRUNC(MONTHS_BETWEEN(:8, Data)),
            MesAtual = CASE WHEN MesNum = :9 AND Ano = :10 THEN ''Mês Atual'' ELSE TRIM(MesNome) END,
            MesAtualAbrev = MesNomeAbrev, -- ADICIONADO (Baseado no MesAbrev renomeado)
            MesAnoAtual = CASE WHEN MesNum = :11 AND Ano = :12 THEN TO_CHAR(Ano) || '' '' || TRIM(MesNome) ELSE TO_CHAR(Ano) || '' '' || TRIM(MesNome) END, -- ADICIONADO
            
            -- Trimestre
            TrimestreNum = TO_NUMBER(TO_CHAR(Data, ''Q'')),
            TrimestreNome = TO_CHAR(Ano) || '' T'' || TO_CHAR(TO_NUMBER(TO_CHAR(Data, ''Q''))), -- ADICIONADO
            TrimestreAnoNome = TO_CHAR(Ano) || '' Q'' || TO_CHAR(TO_NUMBER(TO_CHAR(Data, ''Q''))), -- ADICIONADO
            TrimestreAnoNum = Ano * 10 + TO_NUMBER(TO_CHAR(Data, ''Q'')),
            TrimestreInicio = TRUNC(Data, ''Q''),
            TrimestreFim = ADD_MONTHS(TRUNC(Data, ''Q''), 3) - 1, -- RENOMEADO
            TrimestreIndice = 4 * (Ano - :13) + TO_NUMBER(TO_CHAR(Data, ''Q'')),
            TrimestresParaHoje = TRUNC(MONTHS_BETWEEN(:14, Data) / 3),
            TrimestreAtual = CASE 
                                  WHEN TO_CHAR(Data, ''Q'') = TO_CHAR(:15, ''Q'') AND Ano = :16 
                                  THEN ''Trimestre Atual'' 
                                  ELSE ''T'' || TO_CHAR(Data, ''Q'') 
                              END,
            TrimestreAnoAtual = CASE 
                                  WHEN TO_CHAR(Data, ''Q'') = TO_CHAR(:17, ''Q'') AND Ano = :18 
                                  THEN ''Trimestre Atual'' 
                                  ELSE TO_CHAR(Ano) || '' Q'' || TO_CHAR(Data, ''Q'') 
                              END, -- ADICIONADO
            MesDoTrimestre = MesNum - ((TO_NUMBER(TO_CHAR(Data, ''Q'')) - 1) * 3),
            
            -- Semana
            SemanaAno = TO_CHAR(Ano) || '' W'' || LPAD(TO_CHAR(TO_NUMBER(TO_CHAR(Data, ''WW''))), 2, ''0''), -- ADICIONADO
            SemanaDoAno = TO_NUMBER(TO_CHAR(Data, ''W'')),
            SemanaDoMes = TO_NUMBER(TO_CHAR(Data, ''W'')) - TO_NUMBER(TO_CHAR(TRUNC(Data, ''MM''), ''W'')) + 1, -- RENOMEADO
            SemanaInicio = Data - MOD(TO_NUMBER(TO_CHAR(Data, ''D'')) + 7 - :19, 7),
            SemanaFim = Data + MOD(:20 - TO_NUMBER(TO_CHAR(Data, ''D'')), 7) + 6,
            SemanaIndice = 52 * (Ano - :21) + TO_NUMBER(TO_CHAR(Data, ''WW'')),
            SemanasParaHoje = TRUNC((:22 - Data) / 7), -- RENOMEADO
            SemanaAtual = CASE 
                               WHEN TO_CHAR(Data, ''WW'') = TO_CHAR(:23, ''WW'') AND Ano = :24
                               THEN ''Semana Atual'' 
                               ELSE TO_CHAR(Ano) || '' S'' || TO_CHAR(TO_NUMBER(TO_CHAR(Data, ''WW'')), ''FM00'') 
                           END,
                           
            -- Semestre
            SemestreNum = CEIL(MesNum / 6),
            SemestreAnoNum = Ano * 10 + CEIL(MesNum / 6),
            SemestreAnoNome = TO_CHAR(Ano) || '' S'' || TO_CHAR(CEIL(MesNum / 6)), -- ADICIONADO
            SemestreInicio = CASE WHEN CEIL(MesNum / 6) = 1 THEN TRUNC(Data, ''YYYY'') ELSE ADD_MONTHS(TRUNC(Data, ''YYYY''), 6) END,
            SemestreFim = CASE WHEN CEIL(MesNum / 6) = 1 THEN ADD_MONTHS(TRUNC(Data, ''YYYY''), 6) - 1 ELSE ADD_MONTHS(TRUNC(Data, ''YYYY''), 12) - 1 END,
            SemestreIndice = 2 * (Ano - :25) + CEIL(MesNum / 6),
            SemestresParaHoje = TRUNC(MONTHS_BETWEEN(:26, Data) / 6),
            SemestreAtual = CASE 
                                 WHEN CEIL(MesNum / 6) = CEIL(:27 / 6) AND Ano = :28
                                 THEN ''Semestre Atual'' 
                                 ELSE TO_CHAR(Ano) || '' S'' || TO_CHAR(CEIL(MesNum / 6)) 
                             END,
                             
            -- Bimestre
            BimestreNum = CEIL(MesNum / 2),
            BimestreAnoNum = Ano * 10 + CEIL(MesNum / 2),
            BimestreAnoNome = TO_CHAR(Ano) || '' B'' || TO_CHAR(CEIL(MesNum / 2)), -- ADICIONADO
            BimestreInicio = TRUNC(ADD_MONTHS(TRUNC(Data, ''YYYY''), (CEIL(MesNum / 2) - 1) * 2), ''MM''),
            BimestreFim = LAST_DAY(ADD_MONTHS(TRUNC(Data, ''YYYY''), (CEIL(MesNum / 2) * 2) - 1)), -- RENOMEADO
            BimestreIndice = 6 * (Ano - :29) + CEIL(MesNum / 2),
            BimestresParaHoje = TRUNC(MONTHS_BETWEEN(:30, Data) / 2),
            BimestreAtual = CASE 
                                 WHEN CEIL(MesNum / 2) = CEIL(:31 / 2) AND Ano = :32
                                 THEN ''Bimestre Atual'' 
                                 ELSE TO_CHAR(Ano) || '' B'' || TO_CHAR(CEIL(MesNum / 2)) 
                             END,
                             
            -- Quinzena
            QuinzenaNum = CASE WHEN DiaDoMes <= 15 THEN 1 ELSE 2 END,
            QuinzenaMesAnoNome = TO_CHAR(Ano) || '' '' || TRIM(MesNomeAbrev) || '' Q'' || TO_CHAR(CASE WHEN DiaDoMes <= 15 THEN 1 ELSE 2 END), -- ADICIONADO
            QuinzenaMesAnoNum = Ano * 1000 + MesNum * 10 + CASE WHEN DiaDoMes <= 15 THEN 1 ELSE 2 END, -- ADICIONADO
            QuinzenaInicio = CASE WHEN DiaDoMes <= 15 THEN TRUNC(Data, ''MM'') ELSE TRUNC(Data, ''MM'') + 15 END,
            QuinzenaFim = CASE WHEN DiaDoMes <= 15 THEN TRUNC(Data, ''MM'') + 14 ELSE LAST_DAY(Data) END,
            QuinzenaIndice = (Ano - :33) * 24 + (MesNum - 1) * 2 + CASE WHEN DiaDoMes <= 15 THEN 1 ELSE 2 END,
            QuinzenaAtual = CASE 
                                 WHEN MesNum = :34 AND Ano = :35 AND (CASE WHEN DiaDoMes <= 15 THEN 1 ELSE 2 END) = (CASE WHEN TO_NUMBER(:36) <= 15 THEN 1 ELSE 2 END)
                                 THEN ''Quinzena Atual'' 
                                 ELSE TO_CHAR(Ano) || '' '' || TRIM(MesNomeAbrev) || '' Q'' || TO_CHAR(CASE WHEN DiaDoMes <= 15 THEN 1 ELSE 2 END) 
                             END,
                             
            -- Fechamento
            FechamentoRef = CASE 
                                 WHEN DiaDoMes <= :37
                                 THEN TRUNC(Data, ''MM'') + :38 - 1
                                 ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :39 - 1
                             END,
            FechamentoAno = TO_NUMBER(TO_CHAR(
                             CASE 
                                 WHEN DiaDoMes <= :40
                                 THEN TRUNC(Data, ''MM'') + :41 - 1
                                 ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :42 - 1
                             END, ''YYYY'')),
            FechamentoMesNum = TO_NUMBER(TO_CHAR(
                                 CASE 
                                     WHEN DiaDoMes <= :43
                                     THEN TRUNC(Data, ''MM'') + :44 - 1
                                     ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :45 - 1
                                 END, ''MM'')),
            FechamentoIndice = TO_NUMBER(TO_CHAR(
                                CASE 
                                    WHEN DiaDoMes <= :46
                                    THEN TRUNC(Data, ''MM'') + :47 - 1
                                    ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :48 - 1
                                END, ''YYYY'')) * 12 + TO_NUMBER(TO_CHAR(
                                CASE 
                                    WHEN DiaDoMes <= :49
                                    THEN TRUNC(Data, ''MM'') + :50 - 1
                                    ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :51 - 1
                                END, ''MM'')),
            FechamentoMesNome = TO_CHAR(
                                CASE 
                                    WHEN DiaDoMes <= :52
                                    THEN TRUNC(Data, ''MM'') + :53 - 1
                                    ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :54 - 1
                                END, ''Month'', ''NLS_DATE_LANGUAGE=PORTUGUESE''), -- ADICIONADO
            FechamentoMesNomeAbrev = TO_CHAR(
                                CASE 
                                    WHEN DiaDoMes <= :55
                                    THEN TRUNC(Data, ''MM'') + :56 - 1
                                    ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :57 - 1
                                END, ''MON'', ''NLS_DATE_LANGUAGE=PORTUGUESE''), -- ADICIONADO
            FechamentoMesAnoNome = TO_CHAR(
                                CASE 
                                    WHEN DiaDoMes <= :58
                                    THEN TRUNC(Data, ''MM'') + :59 - 1
                                    ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :60 - 1
                                END, ''YYYY'') || '' '' || TO_CHAR(
                                CASE 
                                    WHEN DiaDoMes <= :61
                                    THEN TRUNC(Data, ''MM'') + :62 - 1
                                    ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :63 - 1
                                END, ''MON'', ''NLS_DATE_LANGUAGE=PORTUGUESE''), -- ADICIONADO
            FechamentoMesAnoNum = TO_NUMBER(TO_CHAR(
                                CASE 
                                    WHEN DiaDoMes <= :64
                                    THEN TRUNC(Data, ''MM'') + :65 - 1
                                    ELSE ADD_MONTHS(TRUNC(Data, ''MM''), 1) + :66 - 1
                                END, ''YYYYMM'')), -- ADICIONADO
                                
            -- ISO Week
            ISO_SemanaDoAno = TO_NUMBER(TO_CHAR(Data, ''IW'')),
            ISO_Ano = TO_NUMBER(TO_CHAR(Data, ''IYYY'')),
            ISO_Semana = TO_CHAR(TO_NUMBER(TO_CHAR(Data, ''IYYY''))) || '' IW'' || LPAD(TO_CHAR(TO_NUMBER(TO_CHAR(Data, ''IW''))), 2, ''0''), -- ADICIONADO
            ISO_SemanaInicio = TRUNC(Data, ''IW''),
            ISO_SemanaFim = TRUNC(Data, ''IW'') + 6,
            ISO_SemanaIndice = TO_NUMBER(TO_CHAR(Data, ''IYYY'')) * 52 + TO_NUMBER(TO_CHAR(Data, ''IW'')),
            ISO_SemanasParaHoje = TRUNC((:67 - Data) / 7), -- RENOMEADO
            ISO_SemanaAtual = CASE 
                                   WHEN TO_CHAR(Data, ''IW'') = TO_CHAR(:68, ''IW'') AND TO_CHAR(Data, ''IYYY'') = TO_CHAR(:69, ''IYYY'')
                                   THEN ''Semana Atual''
                                   ELSE TO_CHAR(Data, ''IYYY'') || '' S'' || TO_CHAR(TO_NUMBER(TO_CHAR(Data, ''IW'')), ''FM00'')
                               END,
                               
            -- Ano Fiscal (FY)
            FY_AnoInicial = TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:70 - 1)), ''YYYY'')),
            FY_AnoFinal = TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:71 - 1)), ''YYYY'')) + 1,
            FY_Ano = TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:72 - 1)), ''YYYY''))) || ''/'' || TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:73 - 1)), ''YYYY'')) + 1), -- ADICIONADO
            FY_AnoInicio = TRUNC(ADD_MONTHS(Data, -(:74 - 1)), ''YYYY''),
            FY_AnoFim = ADD_MONTHS(TRUNC(ADD_MONTHS(Data, -(:75 - 1)), ''YYYY''), 12) - 1,
            FY_AnosParaHoje = TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:76 - 1)), ''YYYY'')) - :77,
            FY_AnoAtual = CASE 
                               WHEN TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:78 - 1)), ''YYYY'')) = :79
                               THEN ''Ano Fiscal Atual'' 
                               ELSE TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:80 - 1)), ''YYYY''))) || ''/'' || TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:81 - 1)), ''YYYY'')) + 1)
                           END,
                           
            -- Mês Fiscal
            FY_MesNum = MOD(MesNum - :82 + 12, 12) + 1,
            FY_MesNome = TRIM(MesNome), -- ADICIONADO
            FY_MesNomeAbrev = MesNomeAbrev, -- ADICIONADO
            FY_MesAnoNome = TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:83 - 1)), ''YYYY''))) || '' '' || TRIM(MesNome), -- ADICIONADO
            FY_MesesParaHoje = TRUNC(MONTHS_BETWEEN(:84, Data)),
            FY_MesAtual = CASE
                               WHEN MOD(MesNum - :85 + 12, 12) + 1 = MOD(:86 - :87 + 12, 12) + 1 AND
                                    TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:88 - 1)), ''YYYY'')) = :89
                               THEN ''Mês Atual'' 
                               ELSE TO_CHAR(Ano) || '' '' || TRIM(MesNome) 
                           END,
                           
            -- Trimestre Fiscal
            FY_TrimestreNum = CEIL( (MOD(MesNum - :90 + 12, 12) + 1) / 3 ),
            FY_TrimestreNome = TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:91 - 1)), ''YYYY''))) || '' Q'' || TO_CHAR(CEIL( (MOD(MesNum - :92 + 12, 12) + 1) / 3 )), -- ADICIONADO
            FY_MesDoTrimestre = MOD(MOD(MesNum - :93 + 12, 12) + 1 - 1, 3) + 1,
            FY_TrimestreAnoNome = TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:94 - 1)), ''YYYY''))) || '' T'' || TO_CHAR(CEIL( (MOD(MesNum - :95 + 12, 12) + 1) / 3 )), -- ADICIONADO
            FY_TrimestreAnoNum = TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:96 - 1)), ''YYYY'')) * 10 + CEIL( (MOD(MesNum - :97 + 12, 12) + 1) / 3 ), -- ADICIONADO
            FY_TrimestreInicio = TRUNC(ADD_MONTHS(Data, -(:98 - 1)), ''YYYY'') + (CEIL( (MOD(MesNum - :99 + 12, 12) + 1) / 3 ) - 1) * 3,
            FY_TrimestreFim = LAST_DAY(ADD_MONTHS(TRUNC(ADD_MONTHS(Data, -(:100 - 1)), ''YYYY''), (CEIL( (MOD(MesNum - :101 + 12, 12) + 1) / 3 ) * 3) - 1)), -- RENOMEADO
            FY_TrimestresParaHoje = TRUNC(MONTHS_BETWEEN(:102, Data) / 3),
            FY_TrimestreAtual = CASE
                                     WHEN CEIL( (MOD(MesNum - :103 + 12, 12) + 1) / 3 ) = CEIL( (MOD(:104 - :105 + 12, 12) + 1) / 3 ) AND
                                          TO_NUMBER(TO_CHAR(ADD_MONTHS(Data, -(:106 - 1)), ''YYYY'')) = :107
                                     THEN ''Trimestre Atual'' 
                                     ELSE TO_CHAR(Ano) || '' T'' || TO_CHAR(CEIL( (MOD(MesNum - :108 + 12, 12) + 1) / 3 )) 
                                 END,
            FY_DiaDoTrimestre = Data - (TRUNC(ADD_MONTHS(Data, -(:109 - 1)), ''YYYY'') + (CEIL( (MOD(MesNum - :110 + 12, 12) + 1) / 3 ) - 1) * 3) + 1
    ' USING v_DataAtual, v_DataAtual, v_AnoInicial, v_AnoAtual, v_AnoAtual, p_InicioSemana, v_AnoInicial, v_DataAtual, v_MesAtual, v_AnoAtual, -- 1-10
            v_MesAtual, v_AnoAtual, v_AnoInicial, v_DataAtual, v_DataAtual, v_AnoAtual, v_DataAtual, v_AnoAtual, p_InicioSemana, p_InicioSemana, -- 11-20
            v_AnoInicial, v_DataAtual, v_DataAtual, v_AnoAtual, v_AnoInicial, v_DataAtual, v_MesAtual, v_AnoAtual, v_AnoInicial, v_DataAtual, -- 21-30
            v_MesAtual, v_AnoAtual, v_AnoInicial, v_MesAtual, v_AnoAtual, v_DiaAtual, -- 31-36
            p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, -- 37-51 (15 valores)
            p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, -- 52-66 (15 valores - **CORRIGIDO**)
            v_DataAtual, v_DataAtual, v_DataAtual, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, -- 67-74
            p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_AnoFiscalAtual, p_MesInicioAnoFiscal, v_AnoFiscalAtual, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, -- 75-81
            p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_DataAtual, p_MesInicioAnoFiscal, v_MesAtual, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_AnoFiscalAtual, -- 82-89
            p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, -- 90-99
            p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_DataAtual, p_MesInicioAnoFiscal, v_MesAtual, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_AnoFiscalAtual, -- 100-107
            p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal; -- 108-110

    -- =================================================================
    -- ETAPA 7: Feriados e dias úteis
    -- =================================================================
    DBMS_OUTPUT.PUT_LINE('Processando feriados...');
    
    -- Lógica para Feriados Fixos (DML DINÂMICO) 
    DECLARE
        v_index_key VARCHAR2(5); 
    BEGIN
        v_index_key := v_FeriadosFixos.FIRST;
        
        WHILE v_index_key IS NOT NULL LOOP
            EXECUTE IMMEDIATE '
                UPDATE CALENDARIO c SET
                    Feriado = 1,
                    FeriadoNome = :p_nome_feriado
                WHERE TO_CHAR(c.Data, ''MM-DD'') = :p_data_feriado
            ' USING v_FeriadosFixos(v_index_key), v_index_key;
            
            v_index_key := v_FeriadosFixos.NEXT(v_index_key);
        END LOOP;
    END; 
    
    -- Selecionar anos distintos dinamicamente para Feriados Móveis
    EXECUTE IMMEDIATE 'SELECT DISTINCT Ano FROM CALENDARIO ORDER BY Ano' BULK COLLECT INTO v_AnoList;
    
    -- Lógica para Feriados Móveis (Cálculo da Páscoa)
    FOR i IN 1..v_AnoList.COUNT LOOP
        DECLARE
            v_Ano NUMBER := v_AnoList(i);
            v_a NUMBER := MOD(v_Ano, 19);
            v_b NUMBER := MOD(v_Ano, 4);
            v_c NUMBER := MOD(v_Ano, 7);
            v_k NUMBER := FLOOR(v_Ano / 100);
            v_p NUMBER := FLOOR((13 * v_k + 8) / 25);
            v_q NUMBER := FLOOR(v_k / 4);
            v_m NUMBER := MOD(15 - v_p + v_k - v_q, 30);
            v_n NUMBER := MOD(4 + v_k - v_q, 7);
            v_d NUMBER := MOD(19 * v_a + v_m, 30);
            v_e NUMBER := MOD(2 * v_b + 4 * v_c + 6 * v_d + v_n, 7);
            v_DiaPascoa NUMBER := 22 + v_d + v_e;
            v_DataPascoa DATE;
        BEGIN
            IF v_DiaPascoa > 31 THEN
                v_DataPascoa := TO_DATE(TO_CHAR(v_Ano) || '/' || TO_CHAR(4) || '/' || TO_CHAR(v_DiaPascoa - 31), 'YYYY/MM/DD');
            ELSE
                v_DataPascoa := TO_DATE(TO_CHAR(v_Ano) || '/' || TO_CHAR(3) || '/' || TO_CHAR(v_DiaPascoa), 'YYYY/MM/DD');
            END IF;
            
            -- Feriados móveis
            EXECUTE IMMEDIATE 'UPDATE CALENDARIO SET Feriado = 1, FeriadoNome = ''Carnaval'' WHERE Data = :p_data' USING v_DataPascoa - 47;
            EXECUTE IMMEDIATE 'UPDATE CALENDARIO SET Feriado = 1, FeriadoNome = ''Sexta-Feira Santa'' WHERE Data = :p_data' USING v_DataPascoa - 2;
            EXECUTE IMMEDIATE 'UPDATE CALENDARIO SET Feriado = 1, FeriadoNome = ''Corpus Christi'' WHERE Data = :p_data' USING v_DataPascoa + 60;
        END;
    END LOOP;
    
    -- Calcular dias úteis (DML DINÂMICO)
    DBMS_OUTPUT.PUT_LINE('Calculando dias úteis...');

    EXECUTE IMMEDIATE '
        UPDATE CALENDARIO SET
            DiaUtil = CASE
                -- Usa o nome corrigido
                WHEN TRIM(DiaDaSemanaNome) IN (''SÁBADO'', ''DOMINGO'') THEN 0
                WHEN Feriado = 1 THEN 0
                ELSE 1
            END
    ';

    -- Próximo dia útil (DML DINÂMICO)
    DBMS_OUTPUT.PUT_LINE('Calculando próximo dia útil...');
    
    EXECUTE IMMEDIATE '
        UPDATE CALENDARIO c1 SET
            ProximoDiaUtil = (
                SELECT MIN(c2.Data)
                FROM CALENDARIO c2
                WHERE c2.Data > c1.Data AND c2.DiaUtil = 1
            )
    ';
        
    -- Tornar DataIndice NOT NULL (DDL DINÂMICO)
    EXECUTE IMMEDIATE 'ALTER TABLE CALENDARIO MODIFY DataIndice NUMBER NOT NULL';

    -- =================================================================
    -- ETAPA 8: Estatísticas e finalização
    -- =================================================================
    COMMIT;
    
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM CALENDARIO' INTO v_TotalRegistros;
    
    DECLARE
        v_Tempo NUMBER := (SYSDATE - v_Inicio) * 24 * 60 * 60 * 1000;
    BEGIN
        v_Mensagem := 'Calendário REGERADO com sucesso! ' || v_TotalRegistros || ' registros processados em ' || 
                      TO_CHAR(v_Tempo) || 'ms.';
        
        DBMS_OUTPUT.PUT_LINE(v_Mensagem);
    END; 
    
EXCEPTION
    WHEN OTHERS THEN
        v_Mensagem := 'Erro na geração do calendário: ' || SQLERRM;
        DBMS_OUTPUT.PUT_LINE(v_Mensagem);
        RAISE;
END sp_GerarCalendarioOracle;