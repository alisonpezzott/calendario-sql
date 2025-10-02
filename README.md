# Gerar tabela dimensão calendário com SQL

## Compatibilidade

Testado com:
- SQL Server
- Azure SQL Database 
- Microsoft Fabric SQL Database
  
## Uso  

1. Copie o código em [**sp_GerarCalendario.sql**](./src/sql/sp_GerarCalendario.sql) e cole no editor de consultas do seu SGBD e execute. Isto irá criar o procedimento armazenado no banco de dados.

2. Execute o procedimento armazenado fornecendo os parâmetros ou omitindo para gerar com os parâmetros padrão. Por exemplo, copie o código em [**src/exec_GerarCalendario.sql**](./src/sql/exec_GerarCalendario.sql) e cole no editor de consultas do seu SGBD e execute. Isto irá criar a tabela **dbo.Calendario** em seu banco de dados.

3. Crie a partir do Power BI Desktop um novo modelo semântico e conecte a tabela **dbo.Calendario** seja no modo import ou no modo Direct Lake.

4. No Power Desktop na guia de visualização TMDL arraste a tabela **Calendario** para o editor. Apague todas as linhas **exceto o trecho que contém a tag `partition`**. Copie o script contido [**src/tmdl/Passo_1_Classico.tmdl**](./src/tmdl/Passo_1_Classico.tmdl) e cole logo acima do trecho `partition`. Aplique. Neste momento sua tabela **Calendario** estará pronta para utilização com a inteligência de tempo clássica. Se não quiser a inteligência de tempo aprimorada pode para nesta etapa. 

5. Habilitar o recurso em **Opções > Global > Recursos de visualização > Inteligência de Tempo DAX aprimorada**. Crie uma nova aba do TMDL view e arraste a tabela **Calendario** para o editor. Role até o final. Copie o script contido [**src/tmdl/Passo_1_Aprimorado.tmdl**](./src/tmdl/Passo_1_Aprimorado.tmdl) e cole abaixo de tudo. Aplique. Pronto agora seu modelo está pronto para utlizar a inteligência de tempo aprimorada. Confira a documentação em:   https://learn.microsoft.com/pt-br/power-bi/transform-model/desktop-time-intelligence#calendar-based-time-intelligence-preview 

Instrução em vídeo aqui: em breve
