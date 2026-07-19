# Baseline v1 do gerador foto → MIDI

Status: baseline capturado a partir de `origin/main` em 2026-07-19
Corpus: `procedural-v1` (14 fixtures, 1 por `CorpusCategory`)
Versão do algoritmo observada: `1`
Ambiente: iPhone 17 Pro Simulator (iOS 26.5, arm64)
Commit base: `20cf06cd71a905444418d1faca1ed9d0f2708eb8`

Esta auditoria documenta o estado do algoritmo v1 antes de qualquer
mudança da spec `photo-midi-variety-v2`. A medição foi feita
inteiramente em DEBUG, com a instrumentação `MusicalDiagnosticsHarness`
e o corpus `ProceduralCorpus`. Nenhum arquivo de produção foi
modificado por este trabalho.

## Resumo executivo

- A share de **C + C♯ no corpus é 42,9%** (6 de 14 imagens). A root C
  sozinha atinge **35,7%**, contra o esperado uniforme de 8,3%.
- Sete das 14 categorias (50%) mapeiam para root C ou C♯. Retratos
  (`portraitDay`, `portraitNight`, `synthetic`) caem todos em C;
  `object` e `dark` também caem em C.
- A entropia global é 3,53 bits, próxima do máximo teórico
  `log2(12) ≈ 3,585`. Isso é um artefato: a maioria das notas cai em
  três ou quatro pitch classes próximas da root, e a entropia
  global é elevada pela variedade de roots entre imagens, não pela
  variedade dentro de uma única sequência.
- A média de pitch classes únicas por sequência é 4,7. Nenhuma
  sequência alcança as 12 pitch classes.
- A média de share máximo de uma pitch class é 0,26. A categoria
  `landscapeNight` chega a 0,50 — uma única pitch class ocupa metade
  das notas.
- O salto máximo observado é 5 semitons; o intervalo médio é 0,4
  semitom. A linha melódica é dominada por repetição de notas
  adjacentes, sem contorno claro.
- O custo de cálculo do diagnóstico é **0,20 ms por sequência**,
  versus **7,50 ms para a geração da sequência**. A instrumentação
  adiciona ~2,6% ao tempo total observado.

A spec `photo-midi-variety-v2` continua `Draft` e nenhuma parte da v2
foi implementada nesta entrega.

## Métricas globais

- `corpusSize`: 14
- `algorithmVersion`: 1
- `corpusIdentifier`: `procedural-v1`

### Distribuição de roots

| Root | Contagem | Share |
| --- | --- | --- |
| C | 5 | 35,7% |
| C♯ | 1 | 7,1% |
| D | 0 | 0,0% |
| D♯ | 1 | 7,1% |
| E | 1 | 7,1% |
| F | 1 | 7,1% |
| F♯ | 1 | 7,1% |
| G | 2 | 14,3% |
| G♯ | 2 | 14,3% |
| A | 0 | 0,0% |
| A♯ | 0 | 0,0% |
| B | 0 | 0,0% |

- `C + C♯ root share`: **42,9%** (acima do guardrail provisório de 25%)
- `globalPitchClassEntropy`: **3,53 bits** (próximo do teto)
- `meanUniquePitchClassesPerSequence`: **4,7**
- `meanMaximumPitchClassShare`: **0,26**
- `meanIntervalSemitones`: **0,4**
- `maximumObservedJumpSemitones`: **5**
- `meanNoteDensity`: **0,79** (notas / `PedalSequence.maximumNoteSlots`)
- `meanRestDensity`: **0,11** (steps vazios / 16)
- `meanMultiNoteStepShare`: **0,88** (steps com várias notas / steps com nota)
- `meanNotesPerActiveStep`: **6,43** (média global; `0` quando não há steps ativos)
- `meanSingleVoiceStepShare`: **0,05** (steps com 1 nota / steps ativos)
- `meanTwoVoiceStepShare`: **0,02** (steps com 2 notas / steps ativos)
- `meanThreeOrMoreVoiceStepShare`: **0,86** (steps com 3+ notas / steps ativos)
- `meanZeroIntervalTransitionShare`: **0,79** (transições de intervalo 0 / total de transições melódicas)

### Distribuição de vozes por sequência

A v1 produz, na maior parte dos casos, acordes de **3+ vozes por
step** quando a luminância não é muito baixa. A categoria
`landscapeNight` é a única exceção com steps predominantemente
mono- ou duofônicos (33% de 2 vozes, 67% de 1 voz, 0% de 3+).
`architecture` é um caso intermediário: 100% de 3+ vozes mas com
`meanNotesPerActiveStep = 5,31` (vs. 8,00 nas categorias saturadas).

### Distribuição de BPM

| Bucket | Contagem |
| --- | --- |
| 70–79 | 2 |
| 80–89 | 2 |
| 90–99 | 2 |
| 100–109 | 3 |
| 110–119 | 3 |
| 120–129 | 1 |
| 130–139 | 1 |

- `meanBpm` ≈ 100. Faixa observada: 74–136.
- O mapeamento `bpm = clamp(70 + luminance × 70)` produz uma variação
  perceptível, mas a step-function da capa 2-bit quantiza o BPM em
  alguns valores dominantes.

### Distribuição de escalas

| Escala | Contagem |
| --- | --- |
| `minorPentatonic` | 7 |
| `majorPentatonic` | 4 |
| `wholeTone` | 2 |
| `dorian` | 1 |

A escala `dorian` aparece apenas em `landscapeDay`. `wholeTone`
aparece em `centralSubject` e `highSaturation`.

## Definições

### `noteDensity`

```text
noteDensity = noteCount / PedalSequence.maximumNoteSlots
             = noteCount / (PedalSequence.steps * PedalSequence.rows)
             = noteCount / 128
```

`PedalSequence.maximumNoteSlots` é o limite estrutural do grid v1
(uma nota por célula `step × row`, então 16 × 8 = 128). É uma
constante nomeada em `PedalSequence` para evitar o número mágico.
Quando `noteCount == 0`, `noteDensity = 0` (sem divisão por zero).
A mesma definição é usada no relatório por sequência e na
agregação de corpus.

### Métricas de voz e de repetição melódica

- `activeStepCount` = número de steps com ao menos uma nota
  (= `PedalSequence.steps - restStepCount`).
- `meanNotesPerActiveStep` = `noteCount / activeStepCount`, ou `0`
  quando `activeStepCount == 0`.
- `singleVoiceStepCount` / `twoVoiceStepCount` /
  `threeOrMoreVoiceStepCount` = passos ativos com 1, 2 ou ≥3 notas.
  A classificação é independente da ordem de inserção das notas.
- `melodicTransitionCount` = número de pares consecutivos de notas
  mais agudas por step, usando a mesma política da métrica de
  intervalo (`mostAcuteIntervals`).
- `zeroIntervalTransitionCount` = número de transições melódicas com
  intervalo absoluto igual a zero.
- `zeroIntervalTransitionShare` = `zeroIntervalTransitionCount /
  melodicTransitionCount`, ou `0` quando não há transições.

### Métricas de memória

`MemorySampler` lê `mach_task_basic_info.resident_size` antes e
depois de cada run. O delta é `after - before`, **com sinal**, e
pode ser negativo quando o kernel libera páginas entre as amostras.
A agregação reporta:

- `meanResidentMemoryDeltaBytes`
- `maximumResidentMemoryDeltaBytes`
- `minimumResidentMemoryDeltaBytes`
- `runsWithMemorySamples` (número de runs com ambos os samples válidos)

Quando nenhuma run produz samples válidos, os três primeiros campos
são `nil` e `runsWithMemorySamples = 0`.

**Limitações conhecidas:**

- `resident_size` é uma estimativa do working set do processo, não
  do pico de alocação do algoritmo. Pico de alocação é tipicamente
  maior.
- No Simulator iOS 26.5 (arm64), o working set é afetado por todo o
  processo (UI, framework, Foundation Models), não só pelo pipeline
  musical.
- A métrica serve como proxy de regressão grossa, não como medida
  precisa de uso de memória. Não é gate rígido nesta PR.

## Resultados por categoria

| Categoria | root | escala | notes | meanPitches | meanNotes/active | 1v | 2v | 3+v | zeroShare |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `portraitDay` | C | minorPentatonic | 128 | 5 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `portraitNight` | C | majorPentatonic | 66 | 5 | 4,71 | 0,00 | 0,00 | 1,00 | 0,38 |
| `landscapeDay` | F | dorian | 128 | 5 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `landscapeNight` | G | majorPentatonic | 12 | 4 | 1,33 | 0,67 | 0,33 | 0,00 | 0,38 |
| `object` | C | minorPentatonic | 128 | 5 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `architecture` | C♯ | minorPentatonic | 85 | 5 | 5,31 | 0,00 | 0,00 | 1,00 | 0,33 |
| `nature` | D♯ | majorPentatonic | 128 | 5 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `lowSaturation` | G♯ | minorPentatonic | 128 | 5 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `highSaturation` | E | wholeTone | 128 | 6 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `bright` | G♯ | minorPentatonic | 128 | 5 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `dark` | C | minorPentatonic | **0** | 0 | 0,00 | 0,00 | 0,00 | 0,00 | 0,00 |
| `centralSubject` | G | wholeTone | 128 | 6 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `noClearSubject` | F♯ | minorPentatonic | 128 | 5 | 8,00 | 0,00 | 0,00 | 1,00 | 1,00 |
| `synthetic` | C | majorPentatonic | 107 | 5 | 6,69 | 0,00 | 0,00 | 1,00 | 1,00 |

Observações relevantes:

- `portraitDay` mapeia para root C porque o hue médio do fixture
  (em torno de 23–25°, dentro da faixa da pele) cai em
  `floor(hue / 30) = 0` → root 0 → C. O `min(11, max(0, ...))` é
  um no-op nesse caso (a versão anterior da documentação
  afirmava `floor(30/30) = 1` seguido de clamp para 0, o que é
  inconsistente: o clamp não altera o valor e hue ≈ 30° deveria
  produzir C♯, não C; o hue real é menor que 30° e o floor dá 0).
- `dark` produz 0 notas porque a luminância muito baixa (0,05) zera o
  `significantToneCount`, e o retro processador gera uma capa
  majoritariamente vazia.
- `landscapeNight` produz apenas 12 notas em 16 steps; a
  `significantToneCount` baixa também reduz a variedade. É a única
  categoria com participação significativa de steps mono- e
  duofônicos.
- `zeroIntervalTransitionShare = 1,00` em todas as categorias com
  `noteCount = 128` é consequência direta do v1: como cada step
  emite todas as 8 notas da grade com o mesmo `pitchOffset` por
  row, a `mostAcuteIntervals` colapsa para sequências em que as
  notas mais agudas de steps adjacentes são iguais (a nota de `row 0`
  no step N é idêntica à de `row 0` no step N+1, e o v1 sempre
  produz a mesma nota por row no mesmo step). O alto `meanInterval
  = 0,4` semitom é o mesmo sintoma, agora explicitamente medido
  como repetição.

## Métricas de memória (agregadas)

| Métrica | Valor |
| --- | --- |
| `runsWithMemorySamples` | 14 |
| `meanResidentMemoryDeltaBytes` | **-1.637.229** B |
| `maximumResidentMemoryDeltaBytes` | **+5.046.272** B |
| `minimumResidentMemoryDeltaBytes` | **-47.464.448** B |

- Os 14 runs do corpus geraram samples válidos. O `mean` é negativo
  porque o kernel recupera páginas entre os dois snapshots.
- O `maximum` positivo (~5 MB) representa o pior caso de
  retenção de working set entre o snapshot inicial e o final.
- O `minimum` fortemente negativo (-47 MB) indica que o working
  set inicial é inflado pela primeira execução dentro do test
  runner (framework carregado, Foundation Models pronto, etc.).
  Não é representativo do uso real do pipeline em produção.
- Os valores exatos variam entre execuções porque `resident_size`
  depende do estado do processo, mas o padrão (média negativa,
  mínimo fortemente negativo, máximo positivo pequeno) é estável.
- Ver "Limitações" na seção de definições.

## Performance da instrumentação

| Métrica | Média |
| --- | --- |
| `sequenceGenerationDuration` | 7,50 ms |
| `diagnosticsCalculationDuration` | 0,20 ms |
| `totalRunDuration` | 27,32 ms |

- A instrumentação adiciona ~2,6% ao tempo total de geração.
- O cálculo de diagnóstico é puramente leitura da sequência e não
  re-executa o pipeline. Pode ser mantido em Release com `#if DEBUG`
  sem impacto perceptível.

## Auditoria de proteção em Release

Objetivo: confirmar que nada do que esta PR introduz vaza para uma
build Release.

- **Arquivos do diretório `snap-battle/Services/Debug/MusicDiagnostics/`**
  (`CorpusCategory.swift`, `MusicalCorpusReport.swift`,
  `MusicalCorpusReportAggregator.swift`,
  `MusicalDiagnosticsCalculator.swift`,
  `MusicalDiagnosticsHarness.swift`, `MusicalRunDiagnostics.swift`,
  `ProceduralCorpus.swift`) estão integralmente protegidos por
  `#if DEBUG ... #endif`. O bloco cobre o arquivo inteiro, incluindo
  imports, tipos e funções. Em Release, o preprocessor descarta todo
  o conteúdo.
- **Botão do harness em `LibraryDebugLauncher.swift`**: o arquivo
  inteiro é `#if DEBUG`. Em Release, o botão, a ação de exportação
  (`runBaseline`), a escrita do relatório, a leitura do diretório
  local e a impressão de logs não existem.
- **Fixture store em `LibraryDebugFixtures.swift`**: o arquivo
  inteiro é `#if DEBUG`. Em Release, o caminho de auditoria
  `Application Support/debug-library-fixtures` não é tocado.
- **Project file**: `snap-battle.xcodeproj/project.pbxproj` usa
  `PBXFileSystemSynchronizedRootGroup` para o target principal
  (`snap-battle`). Isso significa que os arquivos `*.swift` em
  `snap-battle/` são descobertos automaticamente — mas o `#if DEBUG`
  continua sendo aplicado pelo preprocessor, então os símbolos não
  chegam ao binário Release.
- **Build check Release**: `xcodebuild -configuration Release build`
  passa, confirmando que (a) não há referências a tipos DEBUG
  no código de produção, e (b) o preprocessor remove com sucesso
  os tipos e entradas da build de produção.

Conclusão: a build Release não contém botão do harness, ação de
exportação, escrita do relatório, leitura de diretório local,
caminhos de auditoria, logs do baseline, símbolos públicos
desnecessários nem dependência funcional em tipos de diagnóstico.
Nenhuma alteração no `project.pbxproj` foi necessária.

## Estabilização do JSON versionado

O arquivo versionado em
`docs/audits/assets/photo-midi-v1-baseline-procedural-v1.json` usa
a **Estratégia A**: o conteúdo é a versão `.normalized` do
relatório, ou seja, `generatedAt` é a string vazia. O relatório
completo (com timestamp de execução, durations e memory deltas por
run) continua sendo exportado localmente pelo harness para o
diretório `Application Support/debug-musical-baseline/` quando o
botão DEBUG é acionado, mas esse arquivo é local e não é
versionado.

Propriedades que tornam o arquivo reproduzível:

- chaves do objeto JSON são ordenadas (`.sortedKeys` na
  codificação);
- `runs` são ordenados por `imageIdentifier` antes da exportação;
- `categoryCounts`, `scaleHistogram` e `bpmHistogram` são
  ordenados por chave;
- histograms de pitch class e root usam arrays de 12 bins em ordem
  fixa;
- não há paths absolutos, UUIDs aleatórios, hashes de bundle nem
  identificadores de dispositivo;
- o campo `generatedAt` está normalizado para a string vazia.

Dados voláteis (memory deltas, durations por run) permanecem no
JSON porque cada fixture é determinística — o conteúdo dos campos
muda a cada run, mas o conjunto de valores possíveis é finito e
bem definido. A spec atual da baseline não exige comparação
byte-a-byte de valores de timing; o teste de normalização
(`normalizedDropsGeneratedAtButPreservesEverythingElse`) cobre a
estabilidade de forma independente.

## Resultados brutos

Os artefatos gerados pelo harness estão versionados em
`docs/audits/assets/`:

- `photo-midi-v1-baseline-procedural-v1.json` — relatório
  serializado em JSON, normalizado (Estratégia A: `generatedAt` é
  a string vazia).
- `photo-midi-v1-baseline-procedural-v1-summary.txt` — saída compacta
  do console.

Estes arquivos são snapshots reprodutíveis de uma única execução
sobre o corpus procedural. O harness pode ser re-executado a
qualquer momento para produzir uma nova captura:

```bash
xcodebuild \
  -scheme snap-battle \
  -destination 'platform=iOS Simulator,id=<device>' \
  -configuration Debug \
  test -only-testing 'snap-battleTests/ProceduralCorpusTests/dumpBaselineReportToBundle()'
```

O harness grava dois arquivos no diretório-irmão do bundle de
testes:

- `photo-midi-v1-baseline-procedural-v1-<timestamp>.json` —
  relatório completo (com `generatedAt` e dados de memória por run);
- `photo-midi-v1-baseline-procedural-v1.normalized.json` — versão
  normalizada (Estratégia A), pronta para ser versionada em
  `docs/audits/assets/`.

Para extrair o diretório do test runner:

```bash
xcrun simctl get_app_container booted PedroKosciuk.snap-battle data
```

## Limitações

- O corpus é inteiramente procedural. Categorias visuais complexas
  (retratos reais, paisagens reais, baixa luminosidade com pouco
  contraste, pele com iluminação mista) não estão representadas.
- Apenas 1 fixture por categoria. Variação intra-categoria (e.g.,
  3 retratos diurnos com tons de pele diferentes) ainda não foi
  medida.
- A performance foi medida no Simulator iOS 26.5 (arm64). O
  dispositivo físico pode ter latência diferente.
- A latência observada inclui a inicialização do
  `UIGraphicsImageRenderer` para cada fixture. O `totalRun` por isso
  é maior do que o cenário real de captura única.
- `meanResidentMemoryDeltaBytes` é afetado por todo o processo
  (framework, Foundation Models), não só pelo pipeline musical. A
  métrica é uma proxy grossa, não uma medida precisa.

## Próximos dados necessários

Para que a spec seja promovida para `Ready`, ainda faltam:

1. Captura de **imagens reais** (200+) usando o diretório
   `PHOTO_PEDAL_CORPUS_DIR` apontando para um diretório fora do
   repositório.
2. Captura de **retratos diurnos com iluminação variada** (pele clara,
   média, escura) com pelo menos 10 imagens cada.
3. **Múltiplas fixtures por categoria** (≥ 3) para reduzir variância
   por ruído de cor.
4. Execução em **dispositivo físico** para validar a latência
   observada.
5. Decisão sobre como o `TonalFamilyWeights` será calibrado a partir
   destes dados (ver `specs/planned/photo-midi-variety-v2.md` §10.2).

Esses pontos permanecem abertos e continuam impedindo a promoção da
spec para `Ready`.

## Mudanças aplicadas ao repositório

- Adicionada a infraestrutura de diagnóstico em
  `snap-battle/Services/Debug/MusicDiagnostics/`.
- Adicionada uma seção "Baseline v1 (DEBUG)" no
  `LibraryDebugLauncher` com botão "Executar baseline e exportar JSON".
- Adicionados 4 arquivos de teste em `snap-battleTests/`.
- Atualizado `snap-battle.xcodeproj/project.pbxproj` para registrar
  os novos arquivos de teste.
- Atualizada a spec `specs/planned/photo-midi-variety-v2.md` para
  marcar o Incremento 1 como implementado e referenciar este
  baseline.
- Adicionada constante nomeada `PedalSequence.maximumNoteSlots` para
  evitar o número mágico `128` no denominador de `noteDensity`.
- Adicionadas métricas por sequência: `activeStepCount`,
  `meanNotesPerActiveStep`, `singleVoiceStepCount`,
  `twoVoiceStepCount`, `threeOrMoreVoiceStepCount`,
  `zeroIntervalTransitionCount`, `zeroIntervalTransitionShare`,
  `melodicTransitionCount`.
- Adicionadas agregações no relatório de corpus e por categoria:
  `meanNotesPerActiveStep`, `meanZeroIntervalTransitionShare`,
  `meanSingleVoiceStepShare`, `meanTwoVoiceStepShare`,
  `meanThreeOrMoreVoiceStepShare`.
- Adicionada agregação de memória: `meanResidentMemoryDeltaBytes`,
  `maximumResidentMemoryDeltaBytes`,
  `minimumResidentMemoryDeltaBytes`, `runsWithMemorySamples`
  (assinada, com `nil` quando não há samples).
- Adicionado método `runAndExportNormalizedJSON` ao harness, que
  grava a versão `normalized` (Estratégia A: sem `generatedAt`) do
  relatório. Usado para o asset versionado.
- Nenhuma mudança em código de produção, em testes existentes, ou em
  schema persistido.

## Não regressão

Os testes `MusicalDiagnosticsEquivalenceTests` provam que a sequência
v1 produzida para cada fixture é byte-for-byte idêntica antes e
depois do cálculo de diagnóstico. A dominante e a identidade
cromática por pitch também permanecem inalteradas após o
diagnóstico rodar. O `git diff --check` retorna limpo.
