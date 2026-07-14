# Plano de teste manual em dispositivo

## Preparação e registro comum

Usar um iPhone compatível, build Debug, gerador real (sem `--mock-generator`) e anotar modelo do aparelho, versão do iOS, idioma/região, idioma da Siri, estado do Apple Intelligence e condições de energia/rede. Para cada execução registrar run id, estado/detalhe/locale do modelo, fingerprint curto, dimensões original/processada, resultado do subject lifting, labels com confidences, material/confidence, identidade gerada, stats, durações por etapa/total, memória aproximada e erro completo. Confirmar no Console os eventos estruturados sem imagem nem lore.

## 1. Caneca em fundo neutro

- Resultado esperado: sujeito extraído; labels relacionadas a caneca/recipiente; criatura e stats válidos.
- Dados a registrar: todos os campos comuns, com atenção a labels e subject lifting.
- Critério de sucesso: pipeline conclui e stats totalizam 240.
- Falhas aceitáveis: label genérica ou material desconhecido.
- Falhas bloqueadoras: crash, imagem errada, stats fora dos limites ou dado ausente no painel.

## 2. Caneca em fundo complexo

- Resultado esperado: pipeline conclui; subject lifting pode escolher a caneca ou usar fallback.
- Dados a registrar: comparação com o cenário 1, especialmente sujeito, labels e tempo de extração.
- Critério de sucesso: escolha/fallback fica explícito e não bloqueia a geração.
- Falhas aceitáveis: classificação influenciada pelo fundo.
- Falhas bloqueadoras: fundo silenciosamente tratado como sujeito sem diagnóstico ou travamento.

## 3. Controle de videogame

- Resultado esperado: labels coerentes com controle/dispositivo e criatura válida.
- Dados a registrar: labels/confidences, material e resultado gerado.
- Critério de sucesso: execução completa e dados auditáveis.
- Falhas aceitáveis: label eletrônica genérica; material desconhecido.
- Falhas bloqueadoras: erro não mostrado por completo ou stats inválidos.

## 4. Planta

- Resultado esperado: labels botânicas; heurística possivelmente `botanical`.
- Dados a registrar: termos que acionaram o material e confidence.
- Critério de sucesso: material condiz com a regra documentada ou permanece `unknown` de forma explicável.
- Falhas aceitáveis: material desconhecido com labels sem termos da regra.
- Falhas bloqueadoras: material não rastreável às labels.

## 5. Objeto metálico

- Resultado esperado: `metallic` somente se uma label contiver termo da regra.
- Dados a registrar: labels, material e distribuição dos stats.
- Critério de sucesso: modificador de defesa ocorre apenas quando a heurística casa.
- Falhas aceitáveis: `unknown` por limitação do classificador.
- Falhas bloqueadoras: afirmação de metal sem regra correspondente.

## 6. Objeto de tecido

- Resultado esperado: `textile` quando labels contiverem cloth/fabric/wool.
- Dados a registrar: labels, confidence da heurística e agility.
- Critério de sucesso: regra e efeito nos stats são auditáveis.
- Falhas aceitáveis: material desconhecido.
- Falhas bloqueadoras: confidence apresentada como medição física real.

## 7. Objeto transparente

- Resultado esperado: pipeline conclui; transparência física pode não ser identificada pela classificação.
- Dados a registrar: labels, material, alpha do sujeito no depurador/log de desenvolvimento se necessário.
- Critério de sucesso: não inventa material; `unknown` é válido.
- Falhas aceitáveis: subject lifting/fallback e labels genéricas.
- Falhas bloqueadoras: crash no recorte ou PNG.

## 8. Objeto desconhecido

- Resultado esperado: labels genéricas ou vazias, material `unknown`, mas geração válida ou erro completo.
- Dados a registrar: contagem de labels e resposta do gerador.
- Critério de sucesso: degradação controlada e observável.
- Falhas aceitáveis: identidade pouco específica.
- Falhas bloqueadoras: dado fabricado apresentado como observação direta.

## 9. Dois objetos na mesma imagem

- Resultado esperado: VisionKit escolhe um sujeito ou usa fallback; não há promessa de seleção pelo usuário.
- Dados a registrar: objeto efetivamente recortado, labels e fingerprint.
- Critério de sucesso: comportamento real fica claro no painel e não há crash.
- Falhas aceitáveis: escolher qualquer um dos objetos ou classificar a cena.
- Falhas bloqueadoras: painel afirmar sucesso de lifting quando o fallback foi usado.

## 10. Foto escura

- Resultado esperado: confidences menores/labels genéricas são possíveis; pipeline permanece controlado.
- Dados a registrar: confidences, tempos e erro, se houver.
- Critério de sucesso: conclusão ou falha explicada sem travamento.
- Falhas aceitáveis: material desconhecido e identidade genérica.
- Falhas bloqueadoras: loop, UI presa ou erro perdido.

## 11. Foto desfocada

- Resultado esperado: comportamento semelhante ao cenário escuro, com baixa qualidade de labels possível.
- Dados a registrar: labels/confidences e lifting.
- Critério de sucesso: degradação observável.
- Falhas aceitáveis: classificação incorreta de baixa confidence.
- Falhas bloqueadoras: confidence não associada à label correta.

## 12. Mesma foto executada duas vezes

- Resultado esperado: usar `Run Again With Same Image`; fingerprints e dimensões iguais; Vision tende a repetir; Foundation Models pode variar; primeira criatura permanece na tela.
- Dados a registrar: toda a comparação automática.
- Critério de sucesso: fingerprint idêntico, duas execuções completas e diferenças marcadas.
- Falhas aceitáveis: nome/arquétipo/texto/stats e durações diferentes.
- Falhas bloqueadoras: fingerprint diferente, nova leitura do arquivo, substituição automática da primeira criatura ou fingerprint enviado ao modelo.

## 13. Câmera com permissão negada

- Resultado esperado: tela informa permissão negada e captura fica desabilitada; seleção da biblioteca continua possível.
- Dados a registrar: status da câmera e mensagem.
- Critério de sucesso: sem crash e sem nova solicitação em loop.
- Falhas aceitáveis: usuário precisar abrir Ajustes manualmente.
- Falhas bloqueadoras: preview/captura ativo sem autorização ou ausência do texto de uso no prompt do sistema.

## 14. Foundation Models indisponível

- Resultado esperado: reproduzir desativando Apple Intelligence ou usando aparelho inelegível; painel distingue `deviceNotEligible`, `appleIntelligenceNotEnabled` e `modelNotReady` quando aplicável.
- Dados a registrar: estado, detalhe completo, locale e idiomas reportados.
- Critério de sucesso: geração não começa e erro completo chega ao painel.
- Falhas aceitáveis: motivo temporário genérico fornecido pelo sistema.
- Falhas bloqueadoras: assumir disponibilidade pelo modelo do aparelho, criar sessão indisponível ou travar.

## 15. Geração cancelada durante cada etapa

Executar quatro rodadas e tocar em Cancel durante extração do sujeito, Vision, Foundation Models e cálculo de stats quando houver janela observável.

- Resultado esperado: task cancelada, nenhum resultado parcial promovido e nova captura possível; logs/painel retêm etapa, duração parcial e erro de cancelamento.
- Dados a registrar: etapa, tempo até cancelar, run id, último evento e memória.
- Critério de sucesso: cancelamento cooperativo sem crash, criatura parcial ou regeneração automática.
- Falhas aceitáveis: stats ser rápido demais para cancelar manualmente; registrar como não reproduzível e usar teste automatizado para cancelamento básico.
- Falhas bloqueadoras: resultado aparecer após cancelamento, sessão continuar indefinidamente, UI ficar bloqueada ou cancelamento disparar nova geração.
