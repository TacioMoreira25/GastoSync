# Feature Specification: Segurança de Conta por OTP, Gestão de Boletos com Alertas Diários e Evolução Pro de Dados

**Feature Branch**: `002-pro-security-db-boletos`

**Created**: 2026-11-06

**Status**: Ready for Planning

**Input**: User description: "Implementar verificação de e-mail para criar conta (OTP 6 dígitos), revisar e evoluir a modelagem e sincronização das transações e contas (precisão monetária exata, isolamento por usuário em tabela única indexada, identificadores únicos universais e exclusão lógica), criar sistema dedicado de boletos e contas a pagar com notificações duas vezes ao dia personalizáveis (in-app, nativa e e-mail), além de recursos Pro como edição de lançamentos, boletos recorrentes com linha digitável copia-e-cola, exportação CSV e auditoria de segurança completa."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verificação de E-mail no Cadastro e Proteção de Acesso (Priority: P1)

Como um novo usuário criando uma conta no GastoSync, quero receber um código numérico de verificação de 6 dígitos no meu e-mail imediatamente após preencher o formulário de cadastro, para comprovar a titularidade do meu endereço de e-mail antes que minha conta na nuvem seja ativada para login e sincronização.

**Why this priority**: Impede a criação de contas falsas ou com e-mails de terceiros, garante que o canal de comunicação para recuperação de senha e alertas de boletos seja válido desde o primeiro acesso e fortalece a segurança de autenticação.

**Independent Test**: Pode ser testado preenchendo o formulário "Criar Conta" com nome, e-mail válido e senha forte, submetendo o cadastro, visualizando o modal de confirmação de código de 6 dígitos, inserindo o código recebido e verificando que a conta passa para o estado verificado e autenticado.

**Acceptance Scenarios**:

1. **Given** que o visitante está na aba "Criar Conta", **When** informa nome completo, e-mail válido e senha que atende a todos os critérios de complexidade e clica em criar conta, **Then** o sistema cria o registro pendente de confirmação, envia um código de 6 dígitos com validade de 10 minutos para o e-mail informado e abre imediatamente a janela de verificação de código.
2. **Given** que a janela de verificação de e-mail está aberta, **When** o usuário digita o código correto de 6 dígitos dentro do prazo de 10 minutos, **Then** a conta é marcada como verificada, a sessão é autenticada automaticamente e o usuário é direcionado à tela principal.
3. **Given** uma conta recém-cadastrada cujo e-mail ainda não foi verificado, **When** o usuário tenta fazer login com e-mail e senha corretos, **Then** o sistema informa que a conta aguarda confirmação de e-mail, envia um novo código de 6 dígitos e exibe a janela de verificação para concluir a ativação.
4. **Given** que o usuário erra o código de verificação por 5 vezes consecutivas ou o prazo de 10 minutos expira, **When** tenta validar novamente, **Then** o código anterior é invalidado por segurança e o usuário pode solicitar o reenvio de um novo código.

---

### User Story 2 - Gestão Dedicada de Boletos e Contas a Pagar com Baixa Automática (Priority: P1)

Como usuário que possui compromissos financeiros futuros (contas de consumo, mensalidades, aluguel, impostos e boletos bancários), quero cadastrar e acompanhar meus boletos separadamente das transações já realizadas, podendo copiar a linha digitável ou código PIX e, ao pagar um boleto, dar baixa com um toque para que ele gere automaticamente a despesa no meu extrato e agende o próximo mês caso seja recorrente.

**Why this priority**: Separa obrigações futuras ("contas a pagar") do saldo efetivamente realizado ("transações liquidadas"), evitando distorções no saldo atual e automatizando o ciclo mensal de contas fixas.

**Independent Test**: Pode ser testado abrindo o formulário de novo lançamento, selecionando a opção de Boleto/Conta, informando descrição, valor, data de vencimento, linha digitável e marcando como recorrente; em seguida, visualizando o boleto na sub-aba "Boletos a Pagar" em Transações (e no resumo do Dashboard) e acionando "Dar Baixa / Pagar" para confirmar a criação automática da despesa paga e do boleto do mês seguinte.

**Acceptance Scenarios**:

1. **Given** que o usuário abre o modal de novo lançamento (`+`), **When** seleciona a opção "Boleto / Conta" e preenche valor, descrição, categoria, data de vencimento e opcionalmente a linha digitável e a flag de recorrência mensal, **Then** o boleto é salvo com status "Pendente" sem descontar do saldo líquido imediato até que seja pago.
2. **Given** que o usuário acessa a tela de Transações na sub-aba "Boletos a Pagar", **When** visualiza a lista de boletos, **Then** os boletos são apresentados ordenados por data de vencimento com indicadores visuais claros ("Vence hoje", "Vencido", "A vencer", "Pago"), resumo de valores pendentes e botão para copiar a linha digitável/PIX em um toque.
3. **Given** um boleto com status "Pendente" ou "Vencido", **When** o usuário clica em "Dar Baixa / Pagar", **Then** o boleto passa para o status "Pago" com registro da data de pagamento, uma despesa correspondente com forma de pagamento "Boleto" é inserida automaticamente no histórico de transações realizadas e, se o boleto for recorrente mensal, um novo boleto pendente é criado para o mesmo dia do mês subsequente.
4. **Given** uma despesa recorrente cobrada diretamente no cartão de crédito (ex.: "Academia" na categoria "Saúde") que já compõe o valor da Fatura Mensal do Cartão, **When** o usuário cadastra esse item marcando a opção "Desconta no Cartão (Incluso na Fatura)", **Then** o sistema envia os 2 lembretes diários na data do desconto (para liberação de limite), contabiliza o valor na categoria específica ("Saúde") nos gráficos e metas de orçamento (abatendo do valor genérico da fatura), mas NÃO soma esse valor em duplicidade no "Total Final a Pagar" de boletos nem desconta duas vezes do Saldo Disponível.

---

### User Story 3 - Sistema de Notificações de Boletos Duas Vezes ao Dia (Priority: P1)

Como usuário com boletos prestes a vencer ou vencidos, quero ser notificado duas vezes ao dia (em horários que eu possa personalizar, por padrão às 09:00 e às 18:00) tanto no aplicativo/dispositivo quanto por e-mail, para que eu nunca esqueça de pagar uma conta nem sofra multas e juros por atraso.

**Why this priority**: É o mecanismo proativo que transforma o controle passivo de contas em prevenção real de multas e juros, garantindo visibilidade nos dois turnos do dia (manhã e fim de tarde).

**Independent Test**: Pode ser testado cadastrando um boleto com vencimento para a data atual ou nos próximos 3 dias, configurando os dois horários diários de lembrete na aba "Mais" e verificando o disparo dos alertas na Central de Notificações, nas notificações locais do dispositivo e no serviço de envio de e-mail sem duplicações dentro do mesmo turno.

**Acceptance Scenarios**:

1. **Given** que o usuário possui boletos não pagos com vencimento nos próximos 3 dias, vencendo hoje ou em atraso, **When** o relógio atinge o primeiro horário configurado (padrão 09:00) ou o segundo horário configurado (padrão 18:00), **Then** o sistema emite um alerta destacando a quantidade e o valor total dos boletos que exigem atenção imediata.
2. **Given** que o usuário acessa a Central de Notificações do aplicativo, **When** existem boletos vencendo hoje ou atrasados, **Then** cartões de alerta prioritários são exibidos no topo da lista com ação direta para abrir a visão de "Boletos a Pagar".
3. **Given** que o usuário acessa as Configurações na aba "Mais", **When** altera o 1º horário de lembrete, o 2º horário de lembrete ou ativa/desativa o recebimento de lembretes de boletos por e-mail, **Then** as preferências são salvas localmente, sincronizadas com o perfil na nuvem e aplicadas imediatamente aos próximos ciclos de alerta.

---

### User Story 4 - Integridade Monetária, Isolamento Multi-Conta, Edição e Sincronização Fiel (Priority: P2)

Como usuário que acessa o GastoSync em múltiplos dispositivos (celular e computador) ou compartilha o dispositivo com outra conta local, quero que cada transação preserve exatamente os centavos, a forma de pagamento escolhida, as edições e exclusões realizadas em qualquer aparelho, mantendo meus dados completamente isolados de outros usuários.

**Why this priority**: Garante qualidade financeira profissional (sem perda de centavos ou perda da forma de pagamento ao sincronizar), permite corrigir erros de digitação editando lançamentos e assegura privacidade absoluta entre contas.

**Independent Test**: Pode ser testado criando uma transação com forma de pagamento "Cartão de Crédito" e valor quebrado (ex.: R$ 47,89), editando sua descrição e valor, sincronizando com a nuvem, recuperando os dados e validando que forma de pagamento, valor exato e exclusões são preservados integralmente e invisíveis para outra conta de usuário.

**Acceptance Scenarios**:

1. **Given** uma transação criada com forma de pagamento "Crédito", "Débito", "PIX", "Dinheiro", "Transferência" ou "Boleto", **When** é salva localmente e sincronizada com a nuvem, **Then** a forma de pagamento e o valor exato com duas casas decimais são preservados tanto no dispositivo quanto no servidor sem serem sobrescritos por valores padrão.
2. **Given** uma transação ou boleto já cadastrado, **When** o usuário aciona a opção de editar e altera descrição, valor, categoria, data ou forma de pagamento, **Then** o registro existente é atualizado sem duplicação tanto localmente quanto na nuvem.
3. **Given** uma transação ou boleto excluído pelo usuário no dispositivo, **When** ocorre a sincronização com a nuvem, **Then** a exclusão é propagada para o servidor para que o item removido não reapareça em novas sincronizações.
4. **Given** dois usuários distintos utilizando o mesmo aplicativo ou o banco na nuvem, **When** alternam entre suas contas, **Then** transações, boletos, metas orçamentárias, métricas e insights de cada usuário permanecem 100% isolados.

---

### User Story 5 - Gestão de Cartões de Crédito (Principal e Secundário) e Teto Saudável de Relacionamento Bancário (Priority: P1)

Como usuário que utiliza cartão de crédito principal e secundário e deseja manter um excelente relacionamento e score com o banco (utilizando, por exemplo, entre 50% e 80% de um limite de R$ 1.500,00, ou seja, entre R$ 750,00 e R$ 1.200,00), quero cadastrar meus cartões (apenas nome, limite, dia de vencimento e faixa ideal de uso, sem dados sensíveis), vincular a eles minhas assinaturas fixas (ex.: academia) e compras do dia a dia no crédito (ex.: mercado), e acompanhar em "Planejamento > Cartões & Limite" e no Dashboard quanto já consumi, quanto falta para atingir meu teto saudável de 70%–80% e quanto resta do limite total.

**Why this priority**: Permite gerenciar não apenas entradas e saídas à vista, mas também o uso estratégico do crédito e o relacionamento bancário, separando claramente gastos fixos de cartão (assinaturas) e gastos variáveis recorrentes (mercado) dentro da meta saudável do limite.

**Independent Test**: Pode ser testado cadastrando um "Cartão Principal" com limite de R$ 1.500,00 e meta saudável de 50% a 80% (R$ 750 a R$ 1.200) e um "Cartão Secundário", lançando uma assinatura fixa no cartão (Academia R$ 120) e uma compra de Mercado no crédito (R$ 680) vinculadas ao Cartão Principal, e conferindo na aba "Planejamento > Cartões & Limite" que o uso total mostra R$ 800,00 (53,3%, dentro da faixa ideal), decompondo Fixas (R$ 120) + Compras/Mercado (R$ 680) e exibindo R$ 400,00 de margem restante até o teto saudável de 80% (R$ 1.200,00).

**Acceptance Scenarios**:

1. **Given** que o usuário acessa a aba "Planejamento" na seção "Cartões & Limite", **When** cadastra um cartão informando nome (ex.: "Nubank Principal" ou "Inter Secundário"), limite total (ex.: R$ 1.500,00), faixa ideal de uso (mínimo 50% e máximo saudável 80%), dia de vencimento e se é o cartão principal, **Then** o cartão é salvo localmente e sincronizado na nuvem sem exigir número de cartão, CVV ou dados bancários sensíveis.
2. **Given** que o usuário possui cartões cadastrados, **When** registra uma despesa com forma de pagamento "Crédito" ou um boleto/assinatura marcado como "Desconta no Cartão (Incluso na Fatura)", **Then** pode selecionar a qual cartão (Principal ou Secundário) aquele gasto pertence.
3. **Given** movimentações e assinaturas vinculadas a um cartão no mês vigente, **When** o usuário visualiza o card do cartão em "Planejamento > Cartões & Limite" ou o resumo no Dashboard, **Then** o sistema apresenta:
   - Valor gasto em **Fixas / Assinaturas** (ex.: Academia, Streaming);
   - Valor gasto em **Compras / Consumo do Mês** (ex.: Mercado, Farmácia);
   - **Uso Total Atual (R$ e %)** comparado à **Faixa Saudável (ex.: 50%–80% / R$ 750 a R$ 1.200)** e ao **Limite Total (R$ 1.500)**;
   - **Margem Saudável Disponível** (quanto ainda pode gastar sem passar dos 80%) e alerta na Central de Notificações caso ultrapasse o teto saudável configurado.

---

### User Story 6 - Exportação de Relatório Financeiro em CSV (Priority: P2)

Como usuário que deseja analisar minhas finanças em planilhas externas ou guardar comprovantes mensais de movimentação, quero exportar minhas transações e boletos em formato CSV padronizado diretamente pela tela de Transações ou pela aba "Mais".

**Why this priority**: Entrega portabilidade de dados e transparência profissional para prestação de contas pessoal ou familiar.

**Independent Test**: Pode ser testado clicando no botão "Exportar CSV" na tela de Transações ou na aba "Mais" e verificando que o arquivo/conteúdo gerado contém cabeçalhos claros e todas as colunas de transações e boletos formatadas corretamente.

**Acceptance Scenarios**:

1. **Given** que o usuário possui transações e boletos registrados, **When** aciona "Exportar Relatório CSV", **Then** o sistema gera um arquivo/relatório estruturado contendo data, tipo, descrição, categoria, forma de pagamento, status, valor e identificador do lançamento.

---

### Edge Cases

- **Tentativa de cadastro com e-mail já registrado mas ainda não verificado**: O sistema deve atualizar os dados de cadastro pendente, gerar um novo código de 6 dígitos e reenviar o e-mail de confirmação sem bloquear permanentemente o endereço do usuário.
- **Tentativa de cadastro ou redefinição com senha fraca enviada diretamente à API**: Mesmo que uma requisição contorne a interface visual, o servidor deve validar todos os requisitos de complexidade de senha (mínimo de 8 caracteres, letra maiúscula, minúscula, número e caractere especial) e rejeitar senhas fracas.
- **Excesso de requisições nos endpoints de código de verificação (Força Bruta)**: Tentativas repetidas de envio ou validação de códigos em curto intervalo devem ser bloqueadas por limite de taxa por endereço de origem e pelo limite máximo de 5 tentativas por código.
- **Boleto recorrente com vencimento no dia 31**: Ao dar baixa em um boleto recorrente que vence no dia 31 (ex.: 31 de janeiro), o vencimento gerado para o mês seguinte deve ajustar-se automaticamente para o último dia válido daquele mês (ex.: 28 ou 29 de fevereiro) sem gerar datas inválidas.
- **Disparo das 2 notificações diárias com aplicativo reaberto várias vezes no mesmo turno**: O sistema deve registrar o último turno notificado no dia (manhã vs. noite) para que o usuário receba exatamente uma notificação por turno configurado e não seja bombardeado a cada abertura de tela.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema DEVE exigir verificação de e-mail por código numérico de uso único (6 dígitos, validade de 10 minutos, máximo de 5 tentativas) no fluxo de criação de novas contas.
- **FR-002**: O sistema DEVE disponibilizar rota e interface para validação do código de verificação de e-mail e para reenvio de código caso o anterior tenha expirado.
- **FR-003**: O sistema DEVE impedir o login na nuvem de contas com e-mail não verificado, redirecionando o usuário para a etapa de confirmação de código com envio automático de novo código.
- **FR-004**: O servidor DEVE aplicar validação estrita de senha forte (mínimo de 8 caracteres, ao menos uma letra maiúscula, uma minúscula, um dígito numérico e um caractere especial) tanto na criação de conta quanto na redefinição de senha.
- **FR-005**: Todos os endpoints sensíveis de autenticação e código de verificação (login, registro, esqueci a senha, validação de código, redefinição de senha, verificação de e-mail e reenvio) DEVEM ser protegidos por controle de limite de requisições contra força bruta.
- **FR-006**: Todos os valores monetários armazenados no banco de dados em nuvem (renda mensal, valor de transações, limites de orçamento e valor de boletos) DEVEM utilizar tipo numérico decimal exato de duas casas decimais, eliminando imprecisões de ponto flutuante.
- **FR-007**: A modelagem de banco de dados na nuvem DEVE manter uma única tabela relacional por entidade (`users`, `transactions`, `bills`, `budgets`) com chave estrangeira obrigatória para o usuário proprietário (`ON DELETE CASCADE`) e índices compostos iniciados pelo identificador do usuário.
- **FR-008**: A entidade de Transações local e em nuvem DEVE armazenar o identificador único universal do cliente (`client_uuid`), a forma de pagamento selecionada (`PIX`, `Débito`, `Crédito`, `Dinheiro`, `Transferência`, `Boleto`), a data de atualização (`updated_at`) e a marcação de exclusão lógica (`deleted_at`).
- **FR-009**: Todas as tabelas locais do dispositivo (Transações, Boletos, Orçamentos, Métricas e Insights de IA) DEVEM isolar os registros pelo endereço de e-mail da conta ativa.
- **FR-010**: O sistema DEVE possuir uma entidade dedicada de Boletos e Contas a Pagar (`bills` / `LocalBills`) separada das transações liquidadas, contendo descrição, valor, data de vencimento, categoria, linha digitável/código PIX opcional, indicador de recorrência mensal (`is_recurring`), indicador de cobrança embutida na fatura do cartão (`is_credit_card_charge`), status (`pending`, `paid`, `overdue`), data de pagamento e vínculo com a transação gerada.
- **FR-011**: Ao marcar um boleto convencional (`is_credit_card_charge = false`) como pago ("Dar Baixa"), o sistema DEVE atualizar o status do boleto para pago, inserir automaticamente uma despesa liquidada correspondente na tabela de transações com forma de pagamento "Boleto" e, quando o boleto for marcado como recorrente, criar automaticamente o boleto pendente do mês seguinte.
- **FR-011b**: Para itens marcados como "Desconta no Cartão / Incluso na Fatura" (`is_credit_card_charge = true`), o sistema DEVE: (a) disparar os 2 lembretes diários na data de cobrança para que o usuário libere o limite do cartão; (b) NÃO somar o valor em duplicidade no "Total Final a Pagar" de boletos nem reduzir o Saldo Disponível duas vezes ao confirmar o desconto; e (c) alocar o valor na categoria vinculada (ex.: `Saúde`, `Lazer`) para fins de gráficos e metas de orçamento em `Planejamento`, deduzindo-o proporcionalmente do lançamento geral da Fatura do Cartão para manter a soma total inalterada.
- **FR-012**: A tela de Transações DEVE oferecer alternância clara entre "Lançamentos" (receitas e despesas realizadas) e "Boletos a Pagar" (obrigações pendentes, vencidas e pagas), além de exibir um resumo dos próximos boletos no Dashboard principal.
- **FR-013**: O modal de lançamento (`+`) DEVE permitir tanto o cadastro quanto a edição de Despesas, Receitas e Boletos/Contas, incluindo botão de cópia rápida para a linha digitável ou código PIX de boletos.
- **FR-014**: O sistema DEVE executar verificação e disparo de lembretes de boletos duas vezes ao dia (nos dois horários configurados pelo usuário, por padrão `09:00` e `18:00`) para boletos que vencem em até 3 dias, vencem na data atual ou estão vencidos.
- **FR-015**: Os lembretes de boletos DEVEM ser apresentados na Central de Notificações interna do aplicativo, em notificações locais do dispositivo/navegador e, quando habilitado pelo usuário, enviados por e-mail pelo servidor.
- **FR-016**: O sistema DEVE permitir ao usuário atualizar e sincronizar com a nuvem suas preferências de perfil financeiro (nome, renda base mensal, meta percentual de poupança, os dois horários diários de lembrete de boletos e a preferência de alerta por e-mail).
- **FR-017**: O sistema DEVE permitir a exportação das transações, boletos e resumo de cartões do usuário em formato CSV padronizado.
- **FR-018**: Ao término da implementação, todo o código-fonte DEVE passar por auditoria estruturada de segurança utilizando a skill `security-audit` da Cloudflare instalada no projeto.
- **FR-019**: O sistema DEVE possuir uma entidade de Cartões de Crédito (`credit_cards` / `LocalCreditCards`) contendo exclusivamente dados não sensíveis de gestão: nome do cartão, limite total, percentual mínimo e máximo da faixa saudável de relacionamento bancário (padrão `50%` a `80%`), dia de vencimento e flag de cartão principal (`is_primary`).
- **FR-020**: O sistema DEVE permitir vincular transações na modalidade `Crédito` e cobranças recorrentes no cartão (`is_credit_card_charge = true`) a um cartão cadastrado (`credit_card_uuid`), exibindo na aba `Planejamento` (seção `Cartões & Limite`) e no `Dashboard` o termômetro de utilização do limite dividido entre **Fixas/Assinaturas** e **Compras/Mercado**, a margem disponível até o teto saudável (70%–80%) e alertas quando o uso exceder o teto saudável.

### Key Entities

- **User**: Conta registrada do usuário, contendo identificador único, nome, e-mail, hash de senha, status e data de verificação de e-mail, renda mensal base, meta percentual de poupança, dois horários diários de lembrete de boletos e preferência de notificação por e-mail.
- **EmailVerificationToken**: Código temporário de uso único para confirmação de titularidade de e-mail no cadastro, associado ao endereço de e-mail, com hash criptográfico do código de 6 dígitos, data de expiração e contador de tentativas.
- **Transaction**: Movimentação financeira efetivamente realizada (receita ou despesa), contendo identificador universal (`client_uuid`), vínculo com o usuário, descrição, valor decimal exato, data da operação, tipo, categoria, forma de pagamento, status de sincronização e controle de atualização/exclusão lógica.
- **Bill (Boleto / Conta a Pagar)**: Obrigação financeira com vencimento programado, contendo identificador universal (`client_uuid`), vínculo com o usuário, descrição, valor decimal exato, data de vencimento, categoria, linha digitável/PIX copia-e-cola, flag de recorrência mensal, status (`pending`, `paid`, `overdue`), data de pagamento, referência à transação gerada na baixa e registro do último lembrete enviado.
- **Budget**: Meta de limite mensal de gastos por categoria pertencente ao usuário.
- **CreditCard**: Cartão de crédito gerenciado pelo usuário (Principal ou Secundário), contendo identificador universal (`client_uuid`), nome/apelido, limite total, faixa percentual de uso saudável para relacionamento bancário (`min_target_percent` padrão 50%, `max_target_percent` padrão 80%), dia de vencimento e flag `is_primary`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das novas contas criadas exigem validação do código de 6 dígitos antes de liberar autenticação na nuvem, e o fluxo completo de cadastro + verificação pode ser concluído pelo usuário em menos de 90 segundos.
- **SC-002**: 100% das somas, saldos e sincronizações de transações, orçamentos e boletos preservam exatidão absoluta de centavos (0,00 de desvio por arredondamento) e mantêm a forma de pagamento original escolhida pelo usuário.
- **SC-003**: Dar baixa em um boleto pendente atualiza a lista de boletos, registra a despesa correspondente no extrato, recalcula as 9 métricas financeiras e gera o boleto do mês seguinte (quando recorrente) em menos de 200 milissegundos localmente.
- **SC-004**: Usuários com boletos vencendo em até 3 dias ou atrasados recebem até 2 lembretes diários exatamente nos dois turnos configurados (padrão 09:00 e 18:00), sem disparos duplicados dentro do mesmo turno.
- **SC-005**: 0 vazamentos de dados entre contas distintas no mesmo dispositivo ou na API em nuvem, confirmado por testes automatizados e pela auditoria de segurança de 6 fases ao final do ciclo.

## Assumptions

- O envio de e-mails de verificação de conta e de lembretes de boletos utilizará a mesma infraestrutura de mensageria já configurada no servidor (Brevo HTTP API, Resend HTTP API ou SMTP/Mailpit), mantendo fallback de visualização de código em ambiente de desenvolvimento/teste (`dev_preview_code`).
- Contas previamente existentes antes desta atualização e a conta de demonstração padrão são consideradas já verificadas para preservar retrocompatibilidade imediata.
- Um boleto cadastrado na tabela de boletos não reduz o Saldo Disponível imediato enquanto estiver com status "Pendente" ou "Vencido"; ele passa a compor as despesas realizadas no momento em que o usuário confirma o pagamento ("Dar Baixa").
