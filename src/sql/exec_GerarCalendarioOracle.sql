BEGIN
    sp_GerarCalendario_ORACLE(
        p_DataInicial            => TO_DATE('2023-01-01', 'YYYY-MM-DD'), -- Inicia em 2023
        p_DataFinal              => ADD_MONTHS(TRUNC(SYSDATE, 'YYYY'), 36) - 1, -- Ultimo dia três anos a frente
        p_InicioSemana           => 1,  -- 1 = Domingo (SUNDAY)
        p_MesInicioAnoFiscal     => 4,  -- Ano Fiscal começa em Abril
        p_DataFechamento         => 25  -- Fechamento no dia 25 do mês
    );
END;