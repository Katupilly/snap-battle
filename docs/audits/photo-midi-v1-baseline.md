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
  `object` também cai em C.
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
- O custo de cálculo do diagnóstico é **0,13 ms por sequência**,
  versus **7,49 ms para a geração da sequência**. A instrumentação
  adiciona ~1,7% ao tempo total observado.

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
- `meanNoteDensity`: **0,79** (notas / 128)
- `meanRestDensity`: **0,11** (steps vazios / 16)
- `meanMultiNoteStepShare`: **0,88** (steps com várias notas / steps com nota)

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

## Resultados por categoria

| Categoria | root | escala | notes | entropy | unique | max share |
| --- | --- | --- | --- | --- | --- | --- |
| `portraitDay` | C | minorPentatonic | 128 | 2,25 | 5 | 0,25 |
| `portraitNight` | C | majorPentatonic | 66 | 2,17 | 5 | 0,32 |
| `landscapeDay` | F | dorian | 128 | 2,25 | 5 | 0,25 |
| `landscapeNight` | G | majorPentatonic | 12 | 1,79 | 4 | 0,50 |
| `object` | C | minorPentatonic | 128 | 2,25 | 5 | 0,25 |
| `architecture` | C♯ | minorPentatonic | 85 | 2,25 | 5 | 0,26 |
| `nature` | D♯ | majorPentatonic | 128 | 2,25 | 5 | 0,25 |
| `lowSaturation` | G♯ | minorPentatonic | 128 | 2,25 | 5 | 0,25 |
| `highSaturation` | E | wholeTone | 128 | 2,50 | 6 | 0,25 |
| `bright` | G♯ | minorPentatonic | 128 | 2,25 | 5 | 0,25 |
| `dark` | C | minorPentatonic | **0** | 0,00 | 0 | 0,00 |
| `centralSubject` | G | wholeTone | 128 | 2,50 | 6 | 0,25 |
| `noClearSubject` | F♯ | minorPentatonic | 128 | 2,25 | 5 | 0,25 |
| `synthetic` | C | majorPentatonic | 107 | 2,19 | 5 | 0,28 |

Observações relevantes:

- `portraitDay` confirma a hipótese da spec: hue médio ~30° (pele) →
  `floor(30/30) = 1` → root C (após `min(11, max(0, ...))`, e com o
  pipeline o root final é 0).
- `dark` produz 0 notas porque a luminância muito baixa (0,05) zera o
  `significantToneCount`, e o retro processador gera uma capa
  majoritariamente vazia.
- `landscapeNight` produz apenas 12 notas em 16 steps; a
  `significantToneCount` baixa também reduz a variedade.

## Performance da instrumentação

| Métrica | Média |
| --- | --- |
| `sequenceGenerationDuration` | 7,49 ms |
| `diagnosticsCalculationDuration` | 0,13 ms |
| `totalRunDuration` | 27,45 ms |

- A instrumentação adiciona ~1,7% ao tempo total de geração.
- O cálculo de diagnóstico é puramente leitura da sequência e não
  re-executa o pipeline. Pode ser mantido em Release com `#if DEBUG`
  sem impacto perceptível.

## Resultados brutos

Os artefatos gerados pelo harness estão versionados em
`docs/audits/assets/`:

- `photo-midi-v1-baseline-procedural-v1.json` — relatório completo
  serializado em JSON (com histogramas e runs).
- `photo-midi-v1-baseline-procedural-v1-summary.txt` — saída compacta
  do console.

Estes arquivos são snapshots de uma única execução. O harness pode ser
re-executado a qualquer momento para produzir uma nova captura:

```bash
xcodebuild \
  -scheme snap-battle \
  -destination 'platform=iOS Simulator,id=<device>' \
  -configuration Debug \
  test -only-testing 'snap-battleTests/ProceduralCorpusTests/dumpBaselineReportToBundle()'
```

O caminho do relatório gerado fica dentro do data container do
test bundle. Para extrair:

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
- Não há medição de `MemorySampler` para a maioria dos runs; o campo
  `residentMemoryBytesBefore`/`After` é capturado mas não usado nas
  métricas agregadas.

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
- Nenhuma mudança em código de produção, em testes existentes, ou em
  schema persistido.

## Não regressão

Os testes `MusicalDiagnosticsEquivalenceTests` provam que a sequência
v1 produzida para cada fixture é byte-for-byte idêntica antes e
depois do cálculo de diagnóstico. A dominante e a identidade
cromática por pitch também permanecem inalteradas após o
diagnóstico rodar. O `git diff --check` retorna limpo.
