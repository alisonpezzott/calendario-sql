EXECUTE dbo.sp_GerarCalendario
   @DataInicial			= '2023-01-01', -- se omitido, início do ano atual
   @DataFinal			= '2025-12-31', -- se omitido, três ano para frente
   @InicioSemana        = 1,            -- se omitido, 1-domingo
   @MesInicioAnoFiscal  = 4,            -- se omitido, 4-abril
   @DataFechamento		= 15            -- se omitido, 15