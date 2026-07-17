# Validação das fixtures DEBUG da Biblioteca

Status: concluída com dívida documentada<br>
Data: 2026-07-17

## Resumo executivo

A infraestrutura DEBUG e a Biblioteca foram validadas no Simulator iOS 26.5 com 50, 200 e 500 registros. Os registros válidos permaneceram disponíveis, o sentinel corrompido foi isolado, e não foi observado crash, corrupção de dados reais ou regressão funcional durante a execução disponível.

Decisão: **Phase 2: Unblocked with documented debt**.

Essa decisão não significa que profiling completo, VoiceOver extensivo ou dispositivo real foram validados. Essas pendências estão registradas como não bloqueantes.

## Interpretação da instrumentação

`galleryReload` é emitido em `PedalStore.loadCollection()`, uma vez por chamada ao store. O intervalo começa depois da criação do `runID` e cobre a preparação do diretório, limpeza de temporários, tentativa de migração legacy, enumeração dos arquivos, leitura/decodificação/validação de cada par JSON/PNG e ordenação final por data descendente e UUID ascendente.

O intervalo não cobre a aplicação de `PedalStoreLoadResult` em `GalleryViewModel.state`, nem a atualização, diff, composição ou renderização SwiftUI. Portanto, os valores não são tempo completo de renderização percebida da Biblioteca.

`GalleryViewModel.reloadAsync()` possui ainda uma medição DEBUG externa com o mesmo nome de estágio, envolvendo a chamada detached e a entrega do resultado. A métrica comparável aos valores abaixo é o evento emitido pelo store; os dois níveis devem ser distinguidos ao analisar logs por `details=` versus `stage=`. Nenhuma alteração na instrumentação foi necessária.

`pedals` representa somente registros válidos carregados. `issues` conta falhas isoladas de registros ou da preparação do store. O `issues=1` observado é inequivocamente o JSON sentinel intencional `D06B0000-0000-4000-8000-FFFFFFFFFFFF.json`, que não decodifica como `PhotoPedal`. Os demais pares continuam sendo carregados; nenhum caminho de recuperação sobrescreve o sentinel ou dados reais.

## Resultados consolidados

### 50 itens

- Mediana aproximada: **28,3 ms**.
- Faixa principal: **27–31 ms**.
- Outlier observado: **64,2 ms**.
- Resultado: **50 válidos, `issues=1`**.

### 200 itens

- Mediana aproximada: **115,3 ms**.
- Faixa observada: **111,8–123,1 ms**.
- Resultado: **200 válidos, `issues=1`**.

### 500 itens

- Mediana aproximada: **307,2 ms**.
- Faixa observada: **301–322 ms**.
- Resultado: **500 válidos, `issues=1`**.

O crescimento observado é aproximadamente linear. A persistência individual ficou tipicamente em **~3,2 ms por item**, com poucos outliers nas primeiras gravações de cada rodada e sem crescimento progressivo relevante.

## Corrupção e isolamento

Os testes DEBUG agora cobrem, para os três datasets, tanto a instalação com sentinel corrompido quanto a mesma coleção sem o sentinel:

- com sentinel: quantidade exata de válidos e exatamente um issue parcial;
- sem sentinel: quantidade exata de válidos e zero issues;
- o diretório de fixtures é separado do diretório real e a limpeza preserva dados externos.

A execução manual do launcher confirmou, no dataset de 500, `500 válidos; 22 capas simuladas indisponíveis; 1 corrupção isolada`.

## Validação manual executada

No Simulator iPhone 17 / iOS 26.5:

- abertura do launcher DEBUG;
- carregamento do dataset de 500 itens;
- confirmação visual da faixa de erro parcial;
- presença de capas indisponíveis sem interromper a grade;
- scroll para conteúdo posterior da grade;
- observação de células sem troca aparente de identidade ou capa;
- carregamento repetido do dataset de 500;
- ausência de crash ou pausa claramente impeditiva durante a carga.

Não foi possível concluir, por limitação da automação disponível, a abertura de um card individual, retorno por botão, swipe-back, troca de tab durante reload, preservação de posição após navegação e o ciclo completo para cada um dos três datasets. Esses itens permanecem não executados, não foram inferidos.

Reduce Motion, VoiceOver/Dynamic Type e acessibilidade básica não foram validados de forma extensiva nesta sessão. O comportamento básico de estados e a identificação de elementos do launcher foram expostos no snapshot de UI.

## Warnings

Os warnings observados foram:

```text
Update NavigationRequestObserver tried to update multiple times per frame.
Snapshotting a view (...) that is not in a visible window requires afterScreenUpdates:YES.
```

Não foram reproduzidos de forma direcionada com impacto funcional observável nesta rodada. Não há causa raiz confirmada. Eles permanecem warnings não bloqueantes e não houve correção em UIKit ou na arquitetura de navegação.

Durante a suíte também foram emitidos quatro warnings de Swift 6 em `CreatureAuditTests.swift` sobre `NSLock` em contexto assíncrono e mutação de propriedades isoladas. Eles não pertencem à Biblioteca DEBUG e não falharam os testes; permanecem dívida separada.

## Performance e memória

Não foi executado Instruments/Allocations/Leaks nem profiling equivalente com 500 itens. Não há evidência reproduzível nesta rodada de crescimento de memória descontrolado, retenção permanente de células, decodificação repetida com impacto relevante, hitch atribuído a imagens ou crash por pressão de memória.

Consequentemente, `StoredPedal.image` não foi alterado. Também não foram introduzidos cache, thumbnails adicionais ou refatoração estrutural.

## Testes e builds

- `LibraryDebugFixturesTests`: incluído na suíte; passou.
- Suíte completa no Simulator: **105 testes, 105 passaram, 0 falharam, 0 ignorados**.
- Build Debug para iOS Simulator: passou.
- Build Release para iOS Simulator: passou.
- `git diff --check`: passou.
- Dispositivo físico: não executado.
- Profiling de memória/Instruments: não executado.
- VoiceOver extensivo, Dynamic Type e Reduce Motion: não executados de forma completa.

## Correções realizadas

Nesta rodada, a única alteração funcional foi ampliar `LibraryDebugFixturesTests` para cobrir zero issues sem sentinel e exatamente um issue com sentinel. Não houve correção de produção: os ajustes DEBUG/isolamento existentes em `PedalStore` e `PerformanceDiagnostics` pertencem às alterações locais anteriores e foram apenas revisados.

## Riscos residuais e escopo deixado inalterado

Resta validar em dispositivo real o comportamento de memória, acessibilidade e navegação completa. Também permanece sem causa raiz confirmada a origem dos warnings internos de navegação/snapshot. A métrica de reload continua não representando renderização SwiftUI completa.

Não foram implementadas a Phase 2, otimizações de imagem, alteração de `StoredPedal.image`, schema, cache/thumbnail pipeline, redesign da Biblioteca, roadmap ou ADRs.
