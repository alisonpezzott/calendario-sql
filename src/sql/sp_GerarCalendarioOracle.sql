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

    -- CREATE TABLE (COMPLETA)
    EXECUTE IMMEDIATE '
        CREATE TABLE CALENDARIO (
            DATA DATE NOT NULL PRIMARY KEY,
            -- Campos base
            ANO NUMBER(4) NULL,
            MES_NUM NUMBER(2) NULL, 
            DIA_NUM NUMBER(2) NULL,
            MES_NOME VARCHAR2(20) NULL,
            MES_ABREV VARCHAR2(3) NULL,
            DIA_SEMANA_NOME VARCHAR2(20) NULL,
            DIA_SEMANA_ABREV VARCHAR2(3) NULL,
            -- Referências de Tempo
            DATA_INDICE NUMBER NULL,
            DIAS_PARA_HOJE NUMBER NULL,
            DATA_ATUAL VARCHAR2(20) NULL,
            ANO_INICIO DATE NULL,
            ANO_FIM DATE NULL,
            ANO_INDICE NUMBER NULL,
            ANOS_PARA_HOJE NUMBER NULL,
            ANO_ATUAL VARCHAR2(20) NULL,
            DIA_DO_ANO NUMBER NULL,
            DIA_SEMANA_NUM NUMBER NULL,
            MES_ANO_NUM NUMBER NULL,
            MES_INICIO DATE NULL,
            MES_FIM DATE NULL,
            MES_INDICE NUMBER NULL,
            MESES_PARA_HOJE NUMBER NULL,
            MES_ATUAL VARCHAR2(20) NULL,
            TRIMESTRE_NUM NUMBER NULL,
            TRIMESTRE_ANO_NUM NUMBER NULL,
            TRIMESTRE_INICIO DATE NULL,
            TRIMESTRE_FIM DATE NULL,
            TRIMESTRE_INDICE NUMBER NULL,
            TRIMESTRES_PARA_HOJE NUMBER NULL,
            TRIMESTRE_ATUAL VARCHAR2(20) NULL,
            MES_DO_TRIMESTRE NUMBER NULL,
            SEMANA_DO_ANO NUMBER NULL,
            SEMANA_DO_MES NUMBER NULL, 
            SEMANA_INICIO DATE NULL,
            SEMANA_FIM DATE NULL,
            SEMANA_INDICE NUMBER NULL,
            SEMANAS_PARA_HOJE NUMBER NULL,
            SEMANA_ATUAL VARCHAR2(20) NULL,
            SEMESTRE_NUM NUMBER NULL,
            SEMESTRE_ANO_NUM NUMBER NULL,
            SEMESTRE_INICIO DATE NULL,
            SEMESTRE_FIM DATE NULL,
            SEMESTRE_INDICE NUMBER NULL,
            SEMESTRES_PARA_HOJE NUMBER NULL,
            SEMESTRE_ATUAL VARCHAR2(20) NULL,
            BIMESTRE_NUM NUMBER NULL,
            BIMESTRE_ANO_NUM NUMBER NULL,
            BIMESTRE_INICIO DATE NULL,
            BIMESTRE_FIM DATE NULL,
            BIMESTRE_INDICE NUMBER NULL,
            BIMESTRES_PARA_HOJE NUMBER NULL,
            BIMESTRE_ATUAL VARCHAR2(20) NULL,
            QUINZENA_NUM NUMBER NULL,
            QUINZENA_INICIO DATE NULL,
            QUINZENA_FIM DATE NULL,
            QUINZENA_INDICE NUMBER NULL,
            QUINZENA_ATUAL VARCHAR2(20) NULL,
            FECHAMENTO_ANO NUMBER NULL,
            FECHAMENTO_REF DATE NULL,
            FECHAMENTO_INDICE NUMBER NULL,
            FECHAMENTO_MES_NUM NUMBER NULL,
            ISO_SEMANA_DO_ANO NUMBER NULL,
            ISO_ANO NUMBER NULL,
            ISO_SEMANA_INICIO DATE NULL,
            ISO_SEMANA_FIM DATE NULL,
            ISO_SEMANA_INDICE NUMBER NULL,
            ISO_SEMANAS_PARA_HOJE NUMBER NULL,
            ISO_SEMANA_ATUAL VARCHAR2(20) NULL,
            -- Ano Fiscal (FY - Fiscal Year)
            FY_ANO_INICIAL NUMBER NULL,
            FY_ANO_FINAL NUMBER NULL,
            FY_ANO_INICIO DATE NULL,
            FY_ANO_FIM DATE NULL,
            FY_ANOS_PARA_HOJE NUMBER NULL,
            FY_ANO_ATUAL VARCHAR2(20) NULL,
            FY_MES_NUM NUMBER NULL,  
            FY_MESES_PARA_HOJE NUMBER NULL,
            FY_MES_ATUAL VARCHAR2(20) NULL,
            FY_TRIMESTRE_NUM NUMBER NULL,
            FY_MES_DO_TRIMESTRE NUMBER NULL,
            FY_TRIMESTRE_INICIO DATE NULL,
            FY_TRIMESTRE_FIM DATE NULL,
            FY_TRIMESTRES_PARA_HOJE NUMBER NULL,
            FY_TRIMESTRE_ATUAL VARCHAR2(20) NULL,
            FY_DIA_DO_TRIMESTRE NUMBER NULL,
            -- Feriados e Utilidade
            FERIADO NUMBER(1) DEFAULT 0 NOT NULL,
            FERIADO_NOME VARCHAR2(100) NULL,
            DIA_UTIL NUMBER(1) DEFAULT 0 NOT NULL,
            PROXIMO_DIA_UTIL DATE NULL
        )';
        
    -- Gera intervalo de datas (DML DINÂMICO)
    DBMS_OUTPUT.PUT_LINE('Gerando intervalo de datas...');
    
    EXECUTE IMMEDIATE '
        INSERT INTO CALENDARIO (
            DATA, ANO, MES_NUM, DIA_NUM, MES_NOME, MES_ABREV, DIA_SEMANA_NOME, DIA_SEMANA_ABREV
        )
        SELECT 
            :1 + LEVEL - 1 AS DATA,
            TO_NUMBER(TO_CHAR(:2 + LEVEL - 1, ''YYYY'')) AS ANO,
            TO_NUMBER(TO_CHAR(:3 + LEVEL - 1, ''MM'')) AS MES_NUM,
            TO_NUMBER(TO_CHAR(:4 + LEVEL - 1, ''DD'')) AS DIA_NUM,
            TO_CHAR(:5 + LEVEL - 1, ''Month'', ''NLS_DATE_LANGUAGE=PORTUGUESE'') AS MES_NOME,
            TO_CHAR(:6 + LEVEL - 1, ''MON'', ''NLS_DATE_LANGUAGE=PORTUGUESE'') AS MES_ABREV,
            TO_CHAR(:7 + LEVEL - 1, ''Day'', ''NLS_DATE_LANGUAGE=PORTUGUESE'') AS DIA_SEMANA_NOME,
            TO_CHAR(:8 + LEVEL - 1, ''DY'', ''NLS_DATE_LANGUAGE=PORTUGUESE'') AS DIA_SEMANA_ABREV
        FROM DUAL
        CONNECT BY LEVEL <= :9 - :10 + 1
    ' USING v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataInicio, v_DataFim, v_DataInicio;
    
    v_TotalRegistros := SQL%ROWCOUNT;
    DBMS_OUTPUT.PUT_LINE('Inseridas ' || v_TotalRegistros || ' datas-base.');
    
    -- =================================================================
    -- ETAPA 2 a 6: Preencher campos (DML DINÂMICO) - ISO_SEMANA_INICIO/FIM CORRIGIDOS
    -- =================================================================
    DBMS_OUTPUT.PUT_LINE('Calculando campos de referência e períodos...');
    
    -- Combinação dos UPDATES para otimização...
    EXECUTE IMMEDIATE '
        UPDATE CALENDARIO SET
            DATA_INDICE = DATA - DATE ''' || TO_CHAR(v_DataInicio, 'YYYY-MM-DD') || ''' + 1,
            DIAS_PARA_HOJE = TRUNC(DATA) - :1,
            DATA_ATUAL = CASE WHEN DATA = :2 THEN ''Hoje'' ELSE TO_CHAR(DATA, ''DD/MM/YYYY'') END,
            ANO_INICIO = TRUNC(DATA, ''YYYY''),
            ANO_FIM = ADD_MONTHS(TRUNC(DATA, ''YYYY''), 12) - 1,
            ANO_INDICE = ANO - :3 + 1,
            ANOS_PARA_HOJE = ANO - :4,
            ANO_ATUAL = CASE WHEN ANO = :5 THEN ''Ano Atual'' ELSE TO_CHAR(ANO) END,
            DIA_DO_ANO = TO_NUMBER(TO_CHAR(DATA, ''DDD'')),
            DIA_SEMANA_NUM = MOD(TO_NUMBER(TO_CHAR(DATA, ''D'')) + 7 - :6, 7) + 1,
            MES_ANO_NUM = ANO * 100 + MES_NUM,
            MES_INICIO = TRUNC(DATA, ''MM''),
            MES_FIM = LAST_DAY(DATA),
            MES_INDICE = 12 * (ANO - :7) + MES_NUM,
            MESES_PARA_HOJE = TRUNC(MONTHS_BETWEEN(:8, DATA)),
            MES_ATUAL = CASE WHEN MES_NUM = :9 AND ANO = :10 THEN ''Mês Atual'' ELSE TRIM(MES_NOME) END,
            TRIMESTRE_NUM = TO_NUMBER(TO_CHAR(DATA, ''Q'')),
            TRIMESTRE_ANO_NUM = ANO * 10 + TO_NUMBER(TO_CHAR(DATA, ''Q'')),
            TRIMESTRE_INICIO = TRUNC(DATA, ''Q''),
            TRIMESTRE_FIM = ADD_MONTHS(TRUNC(DATA, ''Q''), 3) - 1,
            TRIMESTRE_INDICE = 4 * (ANO - :11) + TO_NUMBER(TO_CHAR(DATA, ''Q'')),
            TRIMESTRES_PARA_HOJE = TRUNC(MONTHS_BETWEEN(:12, DATA) / 3),
            TRIMESTRE_ATUAL = CASE 
                                  WHEN TO_CHAR(DATA, ''Q'') = TO_CHAR(:13, ''Q'') AND ANO = :14 
                                  THEN ''Trimestre Atual'' 
                                  ELSE ''T'' || TO_CHAR(DATA, ''Q'') 
                              END,
            MES_DO_TRIMESTRE = MES_NUM - ((TO_NUMBER(TO_CHAR(DATA, ''Q'')) - 1) * 3),
            SEMANA_DO_ANO = TO_NUMBER(TO_CHAR(DATA, ''W'')),
            SEMANA_DO_MES = TO_NUMBER(TO_CHAR(DATA, ''W'')) - TO_NUMBER(TO_CHAR(TRUNC(DATA, ''MM''), ''W'')) + 1,
            SEMANA_INICIO = DATA - MOD(TO_NUMBER(TO_CHAR(DATA, ''D'')) + 7 - :15, 7),
            SEMANA_FIM = DATA + MOD(:16 - TO_NUMBER(TO_CHAR(DATA, ''D'')), 7) + 6,
            SEMANA_INDICE = 52 * (ANO - :17) + TO_NUMBER(TO_CHAR(DATA, ''WW'')),
            SEMANAS_PARA_HOJE = TRUNC((:18 - DATA) / 7),
            SEMANA_ATUAL = CASE 
                               WHEN TO_CHAR(DATA, ''WW'') = TO_CHAR(:19, ''WW'') AND ANO = :20
                               THEN ''Semana Atual'' 
                               ELSE TO_CHAR(ANO) || '' S'' || TO_CHAR(TO_NUMBER(TO_CHAR(DATA, ''WW'')), ''FM00'') 
                           END,
            SEMESTRE_NUM = CEIL(MES_NUM / 6),
            SEMESTRE_ANO_NUM = ANO * 10 + CEIL(MES_NUM / 6),
            SEMESTRE_INICIO = CASE WHEN CEIL(MES_NUM / 6) = 1 THEN TRUNC(DATA, ''YYYY'') ELSE ADD_MONTHS(TRUNC(DATA, ''YYYY''), 6) END,
            SEMESTRE_FIM = CASE WHEN CEIL(MES_NUM / 6) = 1 THEN ADD_MONTHS(TRUNC(DATA, ''YYYY''), 6) - 1 ELSE ADD_MONTHS(TRUNC(DATA, ''YYYY''), 12) - 1 END,
            SEMESTRE_INDICE = 2 * (ANO - :21) + CEIL(MES_NUM / 6),
            SEMESTRES_PARA_HOJE = TRUNC(MONTHS_BETWEEN(:22, DATA) / 6),
            SEMESTRE_ATUAL = CASE 
                                 WHEN CEIL(MES_NUM / 6) = CEIL(:23 / 6) AND ANO = :24
                                 THEN ''Semestre Atual'' 
                                 ELSE TO_CHAR(ANO) || '' S'' || TO_CHAR(CEIL(MES_NUM / 6)) 
                             END,
            BIMESTRE_NUM = CEIL(MES_NUM / 2),
            BIMESTRE_ANO_NUM = ANO * 10 + CEIL(MES_NUM / 2),
            BIMESTRE_INICIO = TRUNC(ADD_MONTHS(TRUNC(DATA, ''YYYY''), (CEIL(MES_NUM / 2) - 1) * 2), ''MM''),
            BIMESTRE_FIM = LAST_DAY(ADD_MONTHS(TRUNC(DATA, ''YYYY''), (CEIL(MES_NUM / 2) * 2) - 1)),
            BIMESTRE_INDICE = 6 * (ANO - :25) + CEIL(MES_NUM / 2),
            BIMESTRES_PARA_HOJE = TRUNC(MONTHS_BETWEEN(:26, DATA) / 2),
            BIMESTRE_ATUAL = CASE 
                                 WHEN CEIL(MES_NUM / 2) = CEIL(:27 / 2) AND ANO = :28
                                 THEN ''Bimestre Atual'' 
                                 ELSE TO_CHAR(ANO) || '' B'' || TO_CHAR(CEIL(MES_NUM / 2)) 
                             END,
            QUINZENA_NUM = CASE WHEN DIA_NUM <= 15 THEN 1 ELSE 2 END,
            QUINZENA_INICIO = CASE WHEN DIA_NUM <= 15 THEN TRUNC(DATA, ''MM'') ELSE TRUNC(DATA, ''MM'') + 15 END,
            QUINZENA_FIM = CASE WHEN DIA_NUM <= 15 THEN TRUNC(DATA, ''MM'') + 14 ELSE LAST_DAY(DATA) END,
            QUINZENA_INDICE = (ANO - :29) * 24 + (MES_NUM - 1) * 2 + CASE WHEN DIA_NUM <= 15 THEN 1 ELSE 2 END,
            QUINZENA_ATUAL = CASE 
                                 WHEN MES_NUM = :30 AND ANO = :31 AND (CASE WHEN DIA_NUM <= 15 THEN 1 ELSE 2 END) = (CASE WHEN TO_CHAR(:32, ''DD'') <= 15 THEN 1 ELSE 2 END)
                                 THEN ''Quinzena Atual'' 
                                 ELSE TO_CHAR(ANO) || '' '' || TRIM(MES_ABREV) || '' Q'' || TO_CHAR(CASE WHEN DIA_NUM <= 15 THEN 1 ELSE 2 END) 
                             END,
            FECHAMENTO_REF = CASE 
                                 WHEN DIA_NUM <= :33
                                 THEN TRUNC(DATA, ''MM'') + :34 - 1
                                 ELSE ADD_MONTHS(TRUNC(DATA, ''MM''), 1) + :35 - 1
                             END,
            FECHAMENTO_ANO = TO_NUMBER(TO_CHAR(
                             CASE 
                                 WHEN DIA_NUM <= :36
                                 THEN TRUNC(DATA, ''MM'') + :37 - 1
                                 ELSE ADD_MONTHS(TRUNC(DATA, ''MM''), 1) + :38 - 1
                             END, ''YYYY'')),
            FECHAMENTO_MES_NUM = TO_NUMBER(TO_CHAR(
                                 CASE 
                                     WHEN DIA_NUM <= :39
                                     THEN TRUNC(DATA, ''MM'') + :40 - 1
                                     ELSE ADD_MONTHS(TRUNC(DATA, ''MM''), 1) + :41 - 1
                                 END, ''MM'')),
            FECHAMENTO_INDICE = TO_NUMBER(TO_CHAR(
                                CASE 
                                    WHEN DIA_NUM <= :42
                                    THEN TRUNC(DATA, ''MM'') + :43 - 1
                                    ELSE ADD_MONTHS(TRUNC(DATA, ''MM''), 1) + :44 - 1
                                END, ''YYYY'')) * 12 + TO_NUMBER(TO_CHAR(
                                CASE 
                                    WHEN DIA_NUM <= :45
                                    THEN TRUNC(DATA, ''MM'') + :46 - 1
                                    ELSE ADD_MONTHS(TRUNC(DATA, ''MM''), 1) + :47 - 1
                                END, ''MM'')),
            ISO_SEMANA_DO_ANO = TO_NUMBER(TO_CHAR(DATA, ''IW'')),
            ISO_ANO = TO_NUMBER(TO_CHAR(DATA, ''IYYY'')),
            ISO_SEMANA_INICIO = TRUNC(DATA, ''IW''),
            ISO_SEMANA_FIM = TRUNC(DATA, ''IW'') + 6,
            ISO_SEMANA_INDICE = TO_NUMBER(TO_CHAR(DATA, ''IYYY'')) * 52 + TO_NUMBER(TO_CHAR(DATA, ''IW'')),
            ISO_SEMANAS_PARA_HOJE = TRUNC((:48 - DATA) / 7),
            ISO_SEMANA_ATUAL = CASE 
                                   WHEN TO_CHAR(DATA, ''IW'') = TO_CHAR(:49, ''IW'') AND TO_CHAR(DATA, ''IYYY'') = TO_CHAR(:50, ''IYYY'')
                                   THEN ''Semana Atual''
                                   ELSE TO_CHAR(DATA, ''IYYY'') || '' S'' || TO_CHAR(TO_NUMBER(TO_CHAR(DATA, ''IW'')), ''FM00'')
                               END,
            FY_ANO_INICIAL = TO_NUMBER(TO_CHAR(ADD_MONTHS(DATA, -(:51 - 1)), ''YYYY'')),
            FY_ANO_FINAL = TO_NUMBER(TO_CHAR(ADD_MONTHS(DATA, -(:52 - 1)), ''YYYY'')) + 1,
            FY_ANO_INICIO = TRUNC(ADD_MONTHS(DATA, -(:53 - 1)), ''YYYY''),
            FY_ANO_FIM = ADD_MONTHS(TRUNC(ADD_MONTHS(DATA, -(:54 - 1)), ''YYYY''), 12) - 1,
            FY_ANOS_PARA_HOJE = TO_NUMBER(TO_CHAR(ADD_MONTHS(DATA, -(:55 - 1)), ''YYYY'')) - :56,
            FY_ANO_ATUAL = CASE 
                               WHEN TO_NUMBER(TO_CHAR(ADD_MONTHS(DATA, -(:57 - 1)), ''YYYY'')) = :58
                               THEN ''Ano Fiscal Atual'' 
                               ELSE TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(DATA, -(:59 - 1)), ''YYYY''))) || ''/'' || TO_CHAR(TO_NUMBER(TO_CHAR(ADD_MONTHS(DATA, -(:60 - 1)), ''YYYY'')) + 1)
                           END,
            FY_MES_NUM = MOD(MES_NUM - :61 + 12, 12) + 1,
            FY_MESES_PARA_HOJE = TRUNC(MONTHS_BETWEEN(:62, DATA)),
            FY_MES_ATUAL = CASE
                               WHEN MOD(MES_NUM - :63 + 12, 12) + 1 = MOD(:64 - :65 + 12, 12) + 1 AND
                                    TO_NUMBER(TO_CHAR(ADD_MONTHS(DATA, -(:66 - 1)), ''YYYY'')) = :67
                               THEN ''Mês Atual'' 
                               ELSE TO_CHAR(ANO) || '' '' || TRIM(MES_NOME) 
                           END,
            FY_TRIMESTRE_NUM = CEIL( (MOD(MES_NUM - :68 + 12, 12) + 1) / 3 ),
            FY_MES_DO_TRIMESTRE = MOD(MOD(MES_NUM - :69 + 12, 12) + 1 - 1, 3) + 1,
            FY_TRIMESTRE_INICIO = TRUNC(ADD_MONTHS(DATA, -(:70 - 1)), ''YYYY'') + (CEIL( (MOD(MES_NUM - :71 + 12, 12) + 1) / 3 ) - 1) * 3,
            FY_TRIMESTRE_FIM = LAST_DAY(ADD_MONTHS(TRUNC(ADD_MONTHS(DATA, -(:72 - 1)), ''YYYY''), (CEIL( (MOD(MES_NUM - :73 + 12, 12) + 1) / 3 ) * 3) - 1)),
            FY_TRIMESTRES_PARA_HOJE = TRUNC(MONTHS_BETWEEN(:74, DATA) / 3),
            FY_TRIMESTRE_ATUAL = CASE
                                     WHEN CEIL( (MOD(MES_NUM - :75 + 12, 12) + 1) / 3 ) = CEIL( (MOD(:76 - :77 + 12, 12) + 1) / 3 ) AND
                                          TO_NUMBER(TO_CHAR(ADD_MONTHS(DATA, -(:78 - 1)), ''YYYY'')) = :79
                                     THEN ''Trimestre Atual'' 
                                     ELSE TO_CHAR(ANO) || '' T'' || TO_CHAR(CEIL( (MOD(MES_NUM - :80 + 12, 12) + 1) / 3 )) 
                                 END,
            FY_DIA_DO_TRIMESTRE = DATA - (TRUNC(ADD_MONTHS(DATA, -(:81 - 1)), ''YYYY'') + (CEIL( (MOD(MES_NUM - :82 + 12, 12) + 1) / 3 ) - 1) * 3) + 1
    ' USING v_DataAtual, v_DataAtual, v_AnoInicial, v_AnoAtual, v_AnoAtual, p_InicioSemana, v_AnoInicial, v_DataAtual, v_MesAtual, v_AnoAtual, 
            v_AnoInicial, v_DataAtual, v_DataAtual, v_AnoAtual, p_InicioSemana, p_InicioSemana, v_AnoInicial, v_DataAtual, v_DataAtual, v_AnoAtual, 
            v_AnoInicial, v_DataAtual, v_MesAtual, v_AnoAtual, v_AnoInicial, v_DataAtual, v_MesAtual, v_AnoAtual, v_AnoInicial, v_MesAtual, v_AnoAtual, v_DataAtual,
            p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, p_DataFechamento, v_DataAtual, v_DataAtual, v_DataAtual,
            p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_AnoFiscalAtual, p_MesInicioAnoFiscal, v_AnoFiscalAtual, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, 
            p_MesInicioAnoFiscal, v_DataAtual, p_MesInicioAnoFiscal, v_MesAtual, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_AnoFiscalAtual, 
            p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_DataAtual, 
            p_MesInicioAnoFiscal, v_MesAtual, p_MesInicioAnoFiscal, p_MesInicioAnoFiscal, v_AnoFiscalAtual, p_MesInicioAnoFiscal, 
            p_MesInicioAnoFiscal, p_MesInicioAnoFiscal;

    -- =================================================================
    -- ETAPA 7: Feriados e dias úteis (Corrigida para ORA-06502)
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
                    FERIADO = 1,
                    FERIADO_NOME = :p_nome_feriado
                WHERE TO_CHAR(c.DATA, ''MM-DD'') = :p_data_feriado
            ' USING v_FeriadosFixos(v_index_key), v_index_key;
            
            v_index_key := v_FeriadosFixos.NEXT(v_index_key);
        END LOOP;
    END; 
    
    -- Selecionar anos distintos dinamicamente para Feriados Móveis
    EXECUTE IMMEDIATE 'SELECT DISTINCT ANO FROM CALENDARIO ORDER BY ANO' BULK COLLECT INTO v_AnoList;
    
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
            EXECUTE IMMEDIATE 'UPDATE CALENDARIO SET FERIADO = 1, FERIADO_NOME = ''Carnaval'' WHERE DATA = :p_data' USING v_DataPascoa - 47;
            EXECUTE IMMEDIATE 'UPDATE CALENDARIO SET FERIADO = 1, FERIADO_NOME = ''Sexta-Feira Santa'' WHERE DATA = :p_data' USING v_DataPascoa - 2;
            EXECUTE IMMEDIATE 'UPDATE CALENDARIO SET FERIADO = 1, FERIADO_NOME = ''Corpus Christi'' WHERE DATA = :p_data' USING v_DataPascoa + 60;
        END;
    END LOOP;
    
    -- Calcular dias úteis (DML DINÂMICO)
    DBMS_OUTPUT.PUT_LINE('Calculando dias úteis...');

    EXECUTE IMMEDIATE '
        UPDATE CALENDARIO SET
            DIA_UTIL = CASE
                WHEN TRIM(DIA_SEMANA_NOME) IN (''SÁBADO'', ''DOMINGO'') THEN 0
                WHEN FERIADO = 1 THEN 0
                ELSE 1
            END
    ';

    -- Próximo dia útil (DML DINÂMICO)
    EXECUTE IMMEDIATE '
        UPDATE CALENDARIO c1 SET
            PROXIMO_DIA_UTIL = (
                SELECT MIN(c2.DATA)
                FROM CALENDARIO c2
                WHERE c2.DATA > c1.DATA AND c2.DIA_UTIL = 1
            )
    ';
        
    -- Tornar DATA_INDICE NOT NULL (DDL DINÂMICO)
    EXECUTE IMMEDIATE 'ALTER TABLE CALENDARIO MODIFY DATA_INDICE NUMBER NOT NULL';

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