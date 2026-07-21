# Photo MIDI Variety V2

Status: Draft
Last updated: 2026-07-22
Feature: Algoritmo foto → MIDI v2 com maior variedade e musicalidade
Platform: iOS 26+
Framework: Swift (pipeline determinístico local)

> Esta especificação é investigação e proposta. Ela não autoriza implementação.
> Nenhum código de produção, teste ou pipeline real é alterado por esta entrega.

## 0. Histórico desta revisão

Esta é a segunda passagem editorial desta spec. As mudanças desta rodada corrigem decisões arquiteturais ainda frágeis antes de qualquer promoção para `Ready`. As decisões revistas são:

- a estratégia de root deixa de excluir pitch classes por família visual e passa a ser uma distribuição ponderada determinística;
- o contrato de seed é formalizado (SHA-256, bytes, endianness, sub-seeds, função de mistura);
- a representação de escala é resolvida: a v2 inicial **não** introduz novas escalas; `ExtendedScale` é removido;
- métricas se separam formalmente em variedade global e variedade interna;
- thresholds finais só são fixados depois de uma fase de baseline real;
- guardrails provisórios calibráveis são incluídos;
- família tonal deixa de depender apenas de hue dominante;
- identidade cromática permanece saída da música (sem ciclos de retroalimentação);
- o contrato de `generationAlgorithmVersion` é detalhado;
- a estratégia A/B em DEBUG é especificada sem persistência;
- validação subjetiva leve é exigida;
- uma seção `Open Decisions Before Ready` lista o que ainda impede a promoção.

A spec permanece `Draft` até que `Open Decisions Before Ready` esteja vazio.

## 1. Contexto

O Dap transforma uma foto em uma capa 2-bit, uma sequência MIDI determinística, um perfil sonoro e metadados opcionais. O pipeline essencial (`PhotoPedalPipeline.runEssential`) consome:

1. `ImageInputPreparer.makePixelBuffer` e `ImagePreparationExecutor.prepare` para normalizar e gerar um pixel buffer;
2. `RetroImageProcessor.process` para a capa 2-bit;
3. `PhotoColorAnalyzer.analyze` para um `PhotoColorProfile` (hue, saturação, luminância, hue variance, edge density);
4. `ImageSequenceGenerator.makeSequence` para o `PedalSequence`;
5. `PitchColorIdentity.tonalPalette` para a paleta tonal da capa, usando a `dominantPitchClass` derivada da sequência.

A feature de identidade cromática por pitch (`specs/current/pitch-color-identity.md`, integrada pelo squash `20cf06c`) é a única mudança observável no pipeline desde a última especificação publicada. Essa feature derivou a cor da pitch class predominante, **não** alterou a geração musical e **não** introduziu versionamento de algoritmo.

A especificação anterior de evolução musical (`specs/planned/music-generation-v2.md`) já reconhece o problema e propõe direções macro. Esta spec aprofunda, organiza e detalha uma proposta implementável para a próxima versão do gerador, com instrumentação, métricas, versionamento e compatibilidade com a identidade cromática.

## 2. Problema Observado

Testes com fotos reais e a análise estática do pipeline indicam:

- fotos de pessoas, especialmente durante o dia, frequentemente resultam em tonalidade C;
- C♯ é a alternativa mais próxima em muitos casos;
- imagens visualmente diferentes podem produzir conjuntos de notas parecidos;
- a distribuição de pitch classes aparece concentrada na diagonal próxima à tonalidade escolhida;
- o algoritmo parece dar peso desproporcional a cor média, hue médio e luminância global.

Esses sintomas não são achismo. Eles são consequência direta de três decisões concentradas no `ImageSequenceGenerator.makeSequence` atual:

1. **Mapeamento único e linear de hue para root**: `floor(hue / 30)`, com 12 bins de 30°. A faixa 0°–59° (laranja a amarelo) cobre pele, vegetação seca, areia e iluminação quente interna, o que concentra raízes em C e C♯.
2. **Escala e oitava derivadas de pouquíssimos sinais agregados** (`hueVarianceDegrees`, `saturation`, `significantToneCount`).
3. **Estrutura de notas derivada de cada pixel da capa individualmente** (`gridLevels[step]`) e mapeada para uma altura de escala local via `pitchOffset`, sem nenhuma camada intermediária que represente motivo, contorno, ritmo ou variação determinística.

A especificação `music-generation-v2.md` já apontava que fotos diferentes podem produzir sequências similares. O que esta spec adiciona é: localização precisa da causa provável, plano de instrumentação, separação entre análise visual e composição, e estratégia concreta para reduzir a concentração sem introduzir aleatoriedade.

A causa provável do viés é o mapeamento `root = floor(hue / 30)`, conforme confirmado no `apêndice A`. Esta spec resolve o viés na raiz, sem proibir pitch classes por família visual.

## 3. Evidências no Código Atual

### 3.1 Onde a imagem vira descritores visuais

`snap-battle/Services/Pedal/PhotoColorAnalyzer.swift`:

- `analyze(_:side:)` produz `PhotoColorProfile` com `hue`, `saturation`, `luminance`, `hueVarianceDegrees`, `edgeDensity` a partir de uma amostragem RGBA em sRGB 64×64 (`PedalHeuristics.analysisSide = 64`).
- `sobelEdgeDensity` é calculada a partir de uma única matriz grayscale e contabiliza arestas com gradiente ≥ `0.18`.
- `circularVarianceDegrees` é a variância circular do hue para pixels com `saturation ≥ 0.10`.
- Não há histograma de hue exposto, nem histograma de luminância, nem histograma de saturação, nem estatística espacial por região, nem entropia, nem descrição do sujeito ou da distribuição espacial de tons.

### 3.2 Onde root, pitch class, escala, oitava, duração, densidade e rests são definidos

`snap-battle/Services/Pedal/ImageSequenceGenerator.swift`:

```swift
let harmony = PedalHarmony(
    rootPitchClass: min(11, max(0, Int((colorProfile.hue / 360 * 12).rounded(.down)))),
    scale: scale(for: colorProfile),
    bpm: min(140, max(70, Int((70 + colorProfile.luminance * 70).rounded())))
)
```

- Root = `floor(hue / 30)` com 12 bins lineares.
- Escala: `wholeTone` se `hueVarianceDegrees > 70`, `dorian` se `≥ 30`, senão `majorPentatonic` quando `saturation ≥ 0.45` ou `minorPentatonic`.
- BPM: linear 70–140 a partir de `luminance`.
- `octaveRange`: 1, 1.5 ou 2 a partir de `significantToneCount` (1–3 ou ≥4).
- Velocidade: `level / 3` por célula do grid 16×8.
- Rests: somente quando `level == 0`.
- Cada `gridLevels[step]` mapeia diretamente para uma `PedalNote` cuja `midiNote` é `60 + root + pitchOffset(row, scale, octaveRange)`. Não há determinismo baseado em fingerprint e nenhuma camada que represente motivo, contorno, repetição controlada, variação seeded ou regra de densidade.

### 3.3 Onde o fingerprint é calculado

`snap-battle/Services/ImageInputPreparer.swift`:

- `fingerprint(of:runID:)` calcula SHA-256 sobre um reescalonamento 32×32 da imagem normalizada.
- O fingerprint é uma string hexadecimais minúsculos (64 caracteres).
- O fingerprint é armazenado em `PreparedImage.fingerprint` e `PreparedImageValue.fingerprint`.
- `docs/IMAGE_TO_MUSIC.md` declara explicitamente: “The fingerprint currently has no confirmed product responsibility. Future use requires a separate approved spec.”
- O pipeline atual nunca consome o fingerprint como seed, identidade, cache, fixture ou contrato de teste. O uso do fingerprint como fonte de desempate determinístico **precisa** de aprovação desta spec.

### 3.4 Como o grid MIDI atual é estruturado

- `PedalSequence.steps = 16`, `PedalSequence.rows = 8`.
- `analyzeTones` reescala a capa 2-bit para 16×8 e calcula luminância por célula, quantizada em 4 níveis (`0`–`3`).
- Cada célula `level > 0` produz uma `PedalNote(step, row, midiNote, velocity)`. Rests são apenas a ausência de evento.
- A ordem de varredura é `for row in 0..<8 { for step in 0..<16 }`. Não há ordenação por step antes da dominante.
- Não há `duration` modelada no domínio (`Domain/Pedal/Pedal.swift`). A duração efetiva de cada nota é controlada pelo `gate` do `PedalSoundProfile`, e o sequenciador (`PhotoPedalSynth.renderSequence`) cobre o step inteiro com attack/decay/release fixos.

### 3.5 Como notas repetidas, acordes e silêncios são produzidos

- Acordes: várias `PedalNote` no mesmo `step` com `row` diferente. Não há limite de vozes e não há regra para harmonização vertical.
- Repetição: padrão espacial de níveis na capa é o único fator. A repetição global é, portanto, função direta do conteúdo visual.
- Silêncios: apenas quando o nível quantizado é zero. Não há regra de “pelo menos N rests em sequências longas” nem “primeiro step opcionalmente mudo”.

### 3.6 Componentes que dependem diretamente da tonalidade gerada

- `ImageSequenceGenerator.makeSequence` define `rootPitchClass` na harmonia.
- `PedalSequence.harmony.rootName` e `PedalSequence.dominantPitchClass` (via `DominantPitchClassResolver`) são expostos em `PedalResultView`, `PedalDetailView`, `PedalboardDetailView`, `PedalPickerView`, `LibraryGridView` e `LibraryPresentation` (acessibilidade).
- `PhotoPedalPipeline` usa `dominantPitchClass` para selecionar `PitchColorIdentity.tonalPalette`, que por sua vez é passada para `RetroImageProcessor.recolor`.
- Foundation Models (`FoundationModelsPedalGenerator`) consome `harmony.rootName`, `harmony.scale.rawValue` e `harmony.bpm` no prompt semântico, mas apenas como **contexto textual**, não para controlar a geração musical (`docs/FOUNDATION_MODELS.md`).

A identidade cromática por pitch é, portanto, uma função determinística do conteúdo da sequência, e qualquer mudança no algoritmo musical pode alterar a cor. Esta spec trata isso explicitamente.

### 3.7 Testes já existentes

- `snap-battleTests/PhotoPedalStabilizationTests.swift`:
  - `identicalNormalizedInputProducesEqualMusicalData`
  - `boundaryPreparationPreservesColorCoverAndSequence`
  - `gridLevelsProduceCurrentRestsAndVelocitiesInOrder`
  - `sequenceBoundsThresholdsAndSoundProfileRemainCurrent`
- `snap-battleTests/CreatureAuditTests.swift`:
  - `circularHueVarianceTreatsRedBoundaryAsConcentrated`
  - `sobelDensitySeparatesFlatAndHardEdges`
  - `imageParametersChooseModesAndRanges`
  - `fourSignificantRetroTonesCreateWideRange`
- `snap-battleTests/DominantPitchClassResolverTests.swift` cobre a resolução da pitch class predominante a partir de sequências arbitrárias.
- `snap-battleTests/PitchClassDomainTests.swift` cobre domínio cromático, normalização MIDI e identidade cromática.
- Não há testes de distribuição estatística, corpus de imagens, golden fixtures de seed ou regressão de sequências com fixtures extensas.

### 3.8 Fixtures DEBUG reutilizáveis

- `snap-battle/Features/Library/Debug/LibraryDebugFixtures.swift` instala 50/200/500 pedais sintéticos com root determinístico baseado em `index % 12`. Útil para validar UI/galeria, **não** para validar geração, porque os pedais são construídos diretamente sem passar pelo pipeline.
- `BattleDebugFixtures` cobre criaturas, não geração musical.
- `snap-battleTests/.../PhotoPedalStabilizationTests.swift` define `Fixtures.patternImage` e `Fixtures.levelPatternImage`, ambos sintéticos em `UIGraphicsImageRenderer`. Podem ser usados como seeds do corpus, mas não cobrem categorias visuais.

### 3.9 Métricas, logs e diagnósticos existentes

- `PerformanceDiagnostics.measure` cobre tempos por estágio (`imagePreparation`, `retroProcessing`, `colorAnalysis`, `sequenceGeneration`, `retroRecolor`, `fingerprint`, `totalPipeline`, `semanticEnrichment*`, `persistence*`, `galleryReload`).
- Não há coleta de distribuição de pitch classes, root, scale, intervalos ou contornos.
- `PipelineDiagnostics.swift` define `PixelSize`, `DiagnosticRun` e `MemorySampler`, mas `DiagnosticRun` é voltado ao pipeline legado de criaturas.

### 3.10 Como a identidade cromática por pitch está conectada

`specs/current/pitch-color-identity.md` e `snap-battle/Domain/Music/PitchColorIdentity.swift`:

- `PitchColorIdentity.tonalPalette(for: dominantPitchClass)` produz `shadow/dark/base/highlight`.
- A paleta é persistida indiretamente porque é a capa recolorida que é salva; não há migração destrutiva.
- A pitch class predominante **não** é persistida: é derivada de `PedalSequence.notes` via `DominantPitchClassResolver` toda vez que a capa é renderizada.
- Foundation Models não participa da identidade cromática.

A spec atual **não pode** quebrar esta cadeia. A `dominantPitchClass` deve continuar sendo determinística a partir da sequência, e a paleta deve continuar sendo única por pitch class.

### 3.11 Contratos de persistência afetáveis

- `PedalHarmony`, `PedalSequence`, `PedalNote`, `PedalSoundProfile`, `PhotoPedal` (`Domain/Pedal/Pedal.swift`).
- O `PedalSequence` é decodificado com fallback de `PedalSoundProfile.legacy` se ausente, mas não há fallback equivalente para `harmony` ou `notes`.
- `PedalStore` (`snap-battle/Services/Persistence/PedalStore.swift`) persiste JSON por UUID e PNG por UUID. A coleção cresce com novos pedais; registros antigos permanecem decodificáveis.
- Não existe `generatorVersion` no JSON. `docs/DATA_MODEL.md` e `docs/ROADMAP.md` reconhecem isso como dívida planejada.
- Não existe migração automática para pedais antigos além do legacy `latest-pedal.json/png` → `pedals/<uuid>.json/png`.

## 4. Objetivos

1. Aumentar a diversidade de pitch classes, escalas, intervalos, ritmos e contornos melódicos entre pedais.
2. Preservar determinismo bit-a-bit para a mesma imagem normalizada.
3. Preservar relação perceptível entre foto e música.
4. Reduzir concentração acidental em C e C♯ sem impor uniformidade forçada e sem proibir pitch classes por família visual.
5. Evitar que a busca por variedade vire aleatoriedade sem significado.
6. Manter o pipeline rápido o suficiente para o fluxo essencial on-device.
7. Permitir medição objetiva antes e depois da mudança via DEBUG-only.
8. Tratar Core ML como possibilidade experimental posterior, **não** como dependência desta versão.

## 5. Não Objetivos

- Game Center, multiplayer, Group Activities, MultipeerConnectivity, CloudKit, Jam/session sync, recomendações harmônicas multiplayer.
- UI redesign, integração com DialKit, exportação MIDI.
- Edição manual de notas, escala ou cor.
- Geração musical por Foundation Models.
- Treinamento de modelo Core ML.
- Migração em massa de pedais antigos.
- Alteração do motor de áudio sem necessidade direta.
- Enriquecimento semântico de nome e descrição.
- Correção de `semanticEnrichmentFailed`.
- Inclusão de imagens licenciadas inadequadamente no repositório.
- Promoção automática desta spec para `Ready`.
- Introduzir novas escalas (`PedalScale`) no primeiro rollout.
- Proibir pitch classes por família visual.
- Alterar o contrato de `dominantPitchClass` ou da identidade cromática por pitch.
- Tornar a geração dependente de Core ML, Vision embeddings ou Foundation Models.
- Forçar uniformidade perfeita na distribuição de roots.
- Recolorir capas de pedais antigos.
- Regenerar automaticamente pedais persistidos.
- Adicionar dependências de terceiros.

## 6. Arquitetura Atual

```text
Captured/imported image
  → ImageInputPreparer + ImagePreparationExecutor
  → RetroImageProcessor.process    (capa 2-bit)
  → PhotoColorAnalyzer.analyze     (hue, saturação, luminância, hue variance, edge density)
  → ImageSequenceGenerator.makeSequence   (root + escala + grid 16×8 + sound profile)
  → DominantPitchClassResolver     (deriva cor)
  → RetroImageProcessor.recolor    (paleta tonal por pitch)
  → PhotoPedal  →  PedalStore  →  PedalResultView / Pedalboard / Library
```

Pontos fracos relevantes:

- O `PhotoColorProfile` é o único descritor visual; ele é, em si, um agregado de 5 números.
- O mapping root/scale/octave/grid é totalmente síncrono, sem camada intermediária.
- A repetição de notas é função direta do conteúdo espacial da capa.
- Não há nenhuma fonte de variação estável por foto além do próprio `PhotoColorProfile`.
- O viés de root está localizado em uma única expressão (`floor(hue / 30)`), o que torna a correção viável sem alterar a arquitetura.

## 7. Arquitetura Proposta

A versão 2 do gerador separa explicitamente três camadas:

```text
Imagem normalizada + fingerprint
        ↓
1. VisualAnalysis   (descritores independentes da música)
        ↓
2. MusicalProfile   (perfil intermediário determinístico)
        ↓
3. Compositor       (gera PedalSequence a partir do perfil)
```

Nenhuma camada conversa diretamente com a próxima via API não testada. Cada camada é `Sendable`, determinística e unit-testável isoladamente.

### 7.1 `VisualAnalysis`

Novo tipo no domínio:

```swift
struct VisualAnalysis: Sendable, Equatable {
    let colorProfile: PhotoColorProfile          // base existente
    let fingerprint: String                      // SHA-256 hex 64 chars
    let hueHistogram: [Double]                   // 12 bins normalizados
    let luminanceHistogram: [Double]             // 8 bins
    let saturationHistogram: [Double]            // 4 bins
    let meanLuminance: Double
    let meanSaturation: Double
    let luminanceContrast: Double                // desvio padrão
    let edgeDensity: Double                      // já existe
    let spatialEnergy: [Double]                  // 4 quadrantes
    let verticalBalance: Double                  // razão superior/inferior
    let horizontalBalance: Double                // razão esquerda/direita
    let subjectPresence: Double                  // 0...1
    let visualEntropy: Double                    // 0...1
    let isLowSaturation: Bool
    let isHighSaturation: Bool
    let isBright: Bool
    let isDark: Bool
    let tonalFamily: TonalFamily                 // ver 7.4
    let tonalFamilyWeights: TonalFamilyWeights   // ver 10
}
```

Regras:

- `VisualAnalysis` é construída por um novo `VisualAnalyzer` (ou versão estendida de `PhotoColorAnalyzer`).
- Buffers intermediários são reaproveitados. Não há segunda passagem completa do pixel buffer.
- A função é pura: mesma `PreparedImage` + mesmo `fingerprint` → mesma `VisualAnalysis`.
- O histograma de hue usa os mesmos critérios atuais (`saturation ≥ 0.10`) e soma 1 (normalizado).
- O histograma de luminância é construído em 8 bins de 32 níveis (0–255).
- `spatialEnergy` é a energia quadrante: `4 regiões` × `média de luminância por região`. Substitui a necessidade de um histograma espacial maior.
- `visualEntropy` é calculada sobre o histograma de luminância: `H = -Σ p × log2(p)`.
- `subjectPresence` é 0 quando o pipeline de subject extraction **não** rodou ainda. No momento da criação, ela pode ser 0 sem prejuízo. A spec não depende de Vision/Foundation Models para esta camada.
- `tonalFamily` e `tonalFamilyWeights` são derivados da própria `VisualAnalysis` (ver 7.4 e 10).

### 7.2 `MusicalProfile`

```swift
struct MusicalProfile: Sendable, Equatable {
    let rootPitchClass: PitchClass                // 0...11
    let scale: PedalScale                         // mesmo enum do domínio atual
    let register: ClosedRange<Int>                // semitones acima do C0
    let density: Double                           // 0...1, fração esperada de steps com nota
    let syncopation: Double                       // 0...1
    let intervalRange: ClosedRange<Int>           // máx salto permitido em semitones
    let repetitionFactor: Double                  // 0...1
    let tension: Double                           // 0...1
    let contour: MelodicContour                   // .ascending | .descending | .arched | .stable | .meandering
    let bpm: Int                                  // 70...140
    let baseOctave: Int                           // 4 ou 5, derivado
    let timeSignatureSteps: Int                   // 16 (fixo nesta versão)
    let generationSeed: UInt64                    // ver 12
    let tonalFamily: TonalFamily                  // rastreabilidade
}
```

A spec **não** introduz `ExtendedScale` nem nenhum outro tipo de escala intermediário. O `scale` é o `PedalScale` já existente (`majorPentatonic`, `minorPentatonic`, `dorian`, `wholeTone`). A escolha de escala continua sendo uma das quatro opções do domínio atual.

A decisão de não introduzir novas escalas é deliberada e é justificada em 10.6. Introduzir `ExtendedScale` apenas para traduzi-lo para `PedalScale` na persistência cria inconsistência semântica: a UI, a acessibilidade, os logs e futuras regras descreveriam uma escala diferente da realmente usada.

### 7.3 `MelodicContour`

```swift
enum MelodicContour: Sendable, Equatable, CaseIterable {
    case ascending
    case descending
    case arched
    case stable
    case meandering
}
```

### 7.4 `TonalFamily`

Família tonal é uma **categoria discreta** derivada de `VisualAnalysis`. Ela é usada pela estratégia de root (10) e pela escolha de escala.

```swift
enum TonalFamily: String, Sendable, Equatable, CaseIterable, Codable {
    case warm
    case cool
    case green
    case purple
    case neutral
    case lowSaturation
    case highSaturation
}
```

Cálculo (resumo; detalhes em 10.2):

- `lowSaturation` quando `meanSaturation < thresholdLow` e a variância circular de hue é alta;
- `highSaturation` quando `meanSaturation ≥ thresholdHigh` e a distribuição de hue é ampla;
- `warm` quando o histograma de hue concentra massa em 0°–60° e 300°–360°;
- `cool` quando o histograma de hue concentra massa em 180°–270°;
- `green` quando o histograma de hue concentra massa em 80°–160°;
- `purple` quando o histograma de hue concentra massa em 270°–320°;
- `neutral` quando nenhuma das anteriores vence por margem calibrada.

Família tonal **não é equivalente a root**. Família tonal influencia pesos, não proíbe pitch classes.

### 7.5 `TonalFamilyWeights`

```swift
struct TonalFamilyWeights: Sendable, Equatable {
    let warm: [Double]            // 12 doubles, soma = 1
    let cool: [Double]
    let green: [Double]
    let purple: [Double]
    let neutral: [Double]
    let lowSaturation: [Double]
    let highSaturation: [Double]
}
```

Os vetores são calibrados pelo baseline (17.4) e podem ser ajustados sem alterar a arquitetura. A spec inicial define valores de **partida** (hipóteses calibráveis, ver 10.3) e exige que todos os pesos sejam estritamente positivos para que toda pitch class permaneça alcançável.

## 8. Descritores Visuais Selecionados

A spec recomenda **incluir nesta entrega** apenas os descritores com:

- custo baixo (uma ou duas passagens adicionais sobre o pixel buffer já coletado por `PhotoColorAnalyzer`);
- ganho claro de variância na sequência;
- compatibilidade com on-device sem chamadas a Vision/Foundation Models.

Incluir:

- histograma de hue (12 bins) e histograma de luminância (8 bins) — reuso de buffers.
- histograma de saturação (4 bins) — reuso de buffers.
- estatísticas de luminância: média, desvio padrão, contraste local.
- `spatialEnergy` por quadrante (4 números).
- `verticalBalance` e `horizontalBalance` derivados de `spatialEnergy`.
- `visualEntropy` (H sobre histograma de luminância).
- `subjectPresence` sempre 0 nesta entrega (placeholder para uso futuro, sem chamar Vision).
- `fingerprint` já existe; é exposto como `analysis.fingerprint`.

Não incluir nesta entrega:

- detecção explícita de sujeito com Vision/Foundation Models.
- embeddings visuais profundos.
- histogramas 2D.
- características semânticas de Vision.

A spec pode evoluir para usar Vision/Foundation Models em iteração futura, mas isso pertence a outra especificação.

## 9. Modelo de Perfil Musical

### 9.1 Regras determinísticas

`MusicalProfile` é uma função pura `(VisualAnalysis, fingerprint) → MusicalProfile`. Sem `Date()`, sem `UUID()`, sem fontes externas.

```swift
func musicalProfile(from analysis: VisualAnalysis) -> MusicalProfile {
    let rootSeed   = subSeed(analysis.generationSeed, domain: .root)
    let scaleSeed  = subSeed(analysis.generationSeed, domain: .scale)
    let rhythmSeed = subSeed(analysis.generationSeed, domain: .rhythm)
    let contourSeed = subSeed(analysis.generationSeed, domain: .contour)
    let motifSeed  = subSeed(analysis.generationSeed, domain: .motif)

    let root    = pickRoot(weights: analysis.tonalFamilyWeights, family: analysis.tonalFamily, rootSeed: rootSeed)
    let scale   = pickScale(analysis: analysis, scaleSeed: scaleSeed)
    let contour = pickContour(contourSeed: contourSeed, analysis: analysis)
    let density = clamp(0.30 + analysis.verticalBalance * 0.20 + (analysis.luminanceContrast * 0.20), 0.20, 0.95)
    let tension = clamp(analysis.luminanceContrast, 0, 1)
    let register = registerRange(for: scale, baseOctave: baseOctave(for: analysis))
    let intervalRange = 1...max(7, min(12, Int(tension * 12) + 5))
    let repetition = 1 - density * 0.5
    let syncopation = clamp(analysis.edgeDensity * 2, 0, 1)
    let bpm = bpm(from: analysis)
    return MusicalProfile(
        rootPitchClass: root,
        scale: scale,
        register: register,
        density: density,
        syncopation: syncopation,
        intervalRange: intervalRange,
        repetitionFactor: repetition,
        tension: tension,
        contour: contour,
        bpm: bpm,
        baseOctave: baseOctave(for: analysis),
        timeSignatureSteps: 16,
        generationSeed: analysis.generationSeed,
        tonalFamily: analysis.tonalFamily
    )
}
```

Os valores de `density`, `intervalRange`, `contour` etc. são sugeridos. A implementação final pode calibrar com base em métricas reais, **mas** as regras de monotonicidade e os limites precisam ser respeitados.

`generationSeed` é o `UInt64` derivado do fingerprint (ver 12). Ele é exposto no `MusicalProfile` para permitir reprodução e diagnóstico.

### 9.2 Invariantes do perfil

- `0 ≤ rootPitchClass.rawValue ≤ 11`.
- `scale` é sempre um `PedalScale` válido (`majorPentatonic`, `minorPentatonic`, `dorian`, `wholeTone`).
- `register.lowerBound ≥ 0` (C0).
- `register.upperBound ≤ 96` (C8).
- `register.upperBound - register.lowerBound ≥ 12` (pelo menos uma oitava útil).
- `0.10 ≤ density ≤ 0.95` (nunca vazio, nunca saturado).
- `0 ≤ syncopation ≤ 1`.
- `intervalRange.lowerBound ≥ 1` (passo mínimo = 1 semitom).
- `intervalRange.upperBound ≤ 24` (limite de salto).
- `tension ∈ [0, 1]`.
- `bpm ∈ [70, 140]`.

## 10. Estratégia de Root e Escala

### 10.1 Princípio

> Famílias visuais podem alterar pesos, preferências ou permutações, mas não devem tornar uma pitch class impossível exclusivamente por causa da família visual.

A estratégia principal é **distribuição ponderada determinística**. Cada família tonal define um vetor de 12 pesos sobre as 12 pitch classes. Os pesos são estritamente positivos, garantindo que toda pitch class permaneça alcançável. O fingerprint determina o índice da seleção dentro do vetor, sem usar probabilidade não determinística em runtime.

Esta escolha é justificada contra as alternativas:

- **Permutação balanceada** (cada família usa uma permutação diferente das 12 pitch classes): preserva alcance total e introduz variabilidade, mas a "preferência" da família é ofuscada pela permutação. O usuário ouve notas espalhadas sem relação clara com a foto.
- **Offset calibrado** (família define região tonal, fingerprint produz offset que atravessa as 12 classes): atinge alcance total, mas distribui demais e enfraquece a coerência perceptual.
- **Distribuição ponderada** (cada família tem pesos sobre 12 classes, fingerprint escolhe deterministicamente): preserva a relação perceptual (algumas notas são claramente mais prováveis para a família) e mantém todas as 12 alcançáveis. É a opção mais explícita e mais testável.

A spec recomenda **distribuição ponderada**.

### 10.2 Família tonal e pesos

Pesos iniciais (hipóteses calibráveis, ver 17.4 e 29). Cada vetor soma 1.0 e é estritamente positivo em todos os 12 bins:

| Família | Pesos (C, C♯, D, D♯, E, F, F♯, G, G♯, A, A♯, B) |
| --- | --- |
| `warm` | 0.10, 0.10, 0.12, 0.08, 0.13, 0.06, 0.06, 0.07, 0.07, 0.10, 0.06, 0.05 |
| `cool` | 0.06, 0.06, 0.07, 0.08, 0.06, 0.13, 0.10, 0.10, 0.07, 0.10, 0.10, 0.07 |
| `green` | 0.07, 0.05, 0.12, 0.06, 0.13, 0.07, 0.05, 0.14, 0.06, 0.10, 0.05, 0.10 |
| `purple` | 0.07, 0.13, 0.06, 0.13, 0.05, 0.07, 0.08, 0.06, 0.12, 0.06, 0.12, 0.05 |
| `neutral` | 0.10, 0.08, 0.09, 0.08, 0.09, 0.09, 0.08, 0.09, 0.08, 0.09, 0.08, 0.05 |
| `lowSaturation` | 0.09, 0.08, 0.09, 0.08, 0.09, 0.09, 0.08, 0.09, 0.08, 0.09, 0.08, 0.06 |
| `highSaturation` | 0.08, 0.09, 0.08, 0.09, 0.08, 0.09, 0.08, 0.09, 0.08, 0.09, 0.08, 0.07 |

Estes valores são apenas uma estimativa inicial. A calibração real acontece depois do baseline (ver 17.4). As restrições inegociáveis são:

- todos os 12 pesos são estritamente positivos;
- a soma de cada vetor é 1.0;
- nenhuma família tem peso zero em qualquer pitch class;
- a soma dos pesos de C e C♯ em `warm` é **menor** que a soma de pesos da família mais balanceada, mas **não é zero**;
- ajustes após o baseline não podem zerar pesos sem reprovar os testes de alcance.

A família `lowSaturation` é praticamente uniforme; ela existe para garantir que fotos dessaturadas não sejam penalizadas nem privilegiadas.

### 10.3 Cálculo da família tonal

A família é uma função pura de `VisualAnalysis`. A decisão usa o **histograma de hue** (12 bins), não apenas o hue dominante.

Algoritmo (pseudocódigo):

```text
bins = hueHistogram                      // soma 1, 12 bins
let totalMass = 1.0
let massByRegion = [
  warm:   bins[11] + bins[0] + bins[1] + bins[2],   // 330°–60°
  green:  bins[3] + bins[4],                        // 60°–120°  (verde)
  cool:   bins[5] + bins[6] + bins[7],              // 120°–210°
  purple: bins[8] + bins[9] + bins[10]              // 210°–330°
]
let winner = argmax(massByRegion)
let margin = (massByRegion[winner] - massByRegion[second]) / max(massByRegion[winner], 0.01)

if meanSaturation < thresholdLow AND circularHueVarianceDegrees > varianceHigh {
  family = .lowSaturation
} else if meanSaturation >= thresholdHigh AND circularHueVarianceDegrees > varianceHigh {
  family = .highSaturation
} else if margin < marginFloor {
  family = .neutral
} else {
  family = winner
}
```

Casos especiais e desempate:

- **Imagem quase monocromática** (`meanSaturation < thresholdLow` e `luminanceContrast < contrastLow`): `lowSaturation` ou `neutral` conforme a luminância média.
- **Imagem de baixa saturação com hue confiável** (`meanSaturation ≥ thresholdLow` e `luminanceContrast ≥ contrastLow` mas bins planos): `neutral`.
- **Imagem com múltiplos clusters fortes** (dois bins com massa > 0.20): se a margem entre o primeiro e o segundo for menor que `marginFloor`, usar `neutral`. Caso contrário, vencedor por margem calibrada.
- **Imagem sem hue confiável** (todos os bins quase vazios e `meanSaturation < thresholdLow`): `lowSaturation`.
- **Imagem com tons de pele e fundo azul**: o histograma terá massa em `warm` (pele) e em `cool` (fundo). Se a margem entre `warm` e `cool` for menor que `marginFloor`, `neutral`. Caso contrário, vencedor.
- **Imagem quente com pequena região altamente saturada**: o histograma é dominado por bins warm, mesmo que exista um pico isolado. O vencedor é `warm`.
- **Imagem neutra** (luminância média e saturação média): `neutral` direto, sem disputa.

Se a classificação for ambígua mesmo após aplicar as regras acima, a spec prefere `neutral` a desempate arbitrário. Família ambígua resulta em pesos aproximadamente uniformes, o que é a escolha mais segura.

A spec **não** depende apenas do hue dominante (`colorProfile.hue`) para classificar família. O histograma é a fonte primária; o hue médio é apenas uma estatística derivada usada para diagnóstico.

### 10.4 Cálculo do root final

```text
weights  = tonalFamilyWeights[family]            // 12 doubles
total    = 1.0                                    // soma garantida
cumulative[i] = sum(weights[0..<i])
target   = rootSeed mod 1_000_000 / 1_000_000    // 0 ≤ target < 1
let index = first i where cumulative[i] >= target
root     = PitchClass(rawValue: index) ?? .c
```

`rootSeed` é o `UInt64` derivado do fingerprint via o contrato de sub-seed (ver 12). A divisão modular inteira e a busca linear produzem um índice determinístico entre 0 e 11. Como todos os pesos são estritamente positivos, o `cumulative` é estritamente crescente e a busca sempre termina antes de 12.

A operação `rootSeed mod 1_000_000 / 1_000_000` é puramente inteira (sem `Double` intermediário): `rootSeed % 1_000_000` é um `UInt64` em `[0, 1_000_000)`, comparado a `cumulative[i] * 1_000_000` (também `UInt64`). Isso evita arredondamento de ponto flutuante.

A invariante "toda pitch class alcançável" é verificada por golden test: para cada família, a busca de exaustão sobre `rootSeed` em `[0, 1_000_000)` cobre os 12 valores.

### 10.5 Por que esta estratégia reduz o viés

- O vetor de pesos da família `warm` atribui peso 0.10 a C e 0.10 a C♯ (vs. 0.13 a E, 0.12 a D). O viés é reduzido sem proibição.
- A média global do corpus tende a refletir a média ponderada das famílias, em vez do mapeamento linear `floor(hue / 30)`.
- O fingerprint, ao controlar a posição dentro do vetor, distribui o "acaso" da seleção entre as 12 pitch classes proporcionalmente aos pesos.
- A combinação `family + fingerprint` substitui o `floor(hue / 30)` por um modelo que trata família e identidade como sinais complementares.

### 10.6 Por que esta estratégia mantém relação perceptual

- Famílias "quentes" (warm, purple) favorecem weights em C, C♯, D, D♯, E, G♯, A, A♯ (regiões "brilhantes" e "quentes" do círculo de quintas).
- Famílias "frias" (cool, green) favorecem F, F♯, G, A, B, D (regiões "escuras" e "frias").
- O usuário continua percebendo que fotos quentes tendem a gerar roots em regiões brilhantes, e fotos frias em regiões escuras. A diferença é que a relação é probabilística-com-pesos, não determinística-com-proibição.

### 10.7 Por que esta estratégia evita uniformidade artificial

- Os vetores não são todos iguais; a diferença entre famílias produz a coerência perceptual.
- A escolha não é forçada: fotos de famílias diferentes continuam tendendo a roots diferentes, só não exclusivamente.
- A meta não é uniformidade perfeita (`H = log2(12)`); é diversidade calibrada (ver 17.4 e 29).

### 10.8 Como esta estratégia será calibrada contra o corpus

A calibração é responsabilidade da fase de baseline (ver 17.4). A spec não congela os pesos antes do baseline.

Após o baseline:

- medir a distribuição global de roots para o corpus;
- medir a distribuição por categoria visual;
- medir a entropia por categoria;
- ajustar os pesos de cada família usando um método documentado (e.g., busca em grade restrita, ou maximização de entropia sujeita a constraints de coerência);
- congelar os pesos finais em uma spec interna de Incremento 3 (ver 20).

A spec atual define apenas os valores de partida; o congelamento é um ato separado.

### 10.9 Como esta estratégia fica protegida por testes

- Golden tests (18.1) verificam que, para fingerprints conhecidos, o root é o esperado.
- Teste de alcance (18.2) varre `rootSeed` em `[0, 1_000_000)` e garante que as 12 pitch classes aparecem para cada família.
- Teste de invariante (18.3) garante que a soma dos pesos é 1.0 e nenhum peso é ≤ 0.
- Teste de mudança de endianness / função de mistura (12.4) detecta regressões de determinismo.

### 10.10 Não usar probabilidade não determinística em runtime

A seleção do root é **inteiramente determinística**: dado o vetor de pesos, o `rootSeed` e a busca linear, o resultado é único. Não há `Double.random`, `SystemRandomNumberGenerator`, nem `Int.random(in:)`. A "aleatoriedade" emerge da combinação `family + fingerprint`, ambos determinísticos.

### 10.11 Escala

A escolha de `PedalScale` continua sendo uma das quatro opções atuais. A função `pickScale(analysis:, scaleSeed:)` é determinística e usa `scaleSeed` para escolher entre `majorPentatonic`, `minorPentatonic`, `dorian` e `wholeTone`. As regras de monotonicidade atuais (e.g., `wholeTone` quando a variância é alta) são preservadas como vieses, mas o `scaleSeed` introduz variação controlada.

A spec **não** introduz `suspended`, `majorBlues`, `minorBlues` ou `darkPentatonic` no primeiro rollout. Adicionar novas escalas exigiria expandir `PedalScale`, o que é uma decisão de schema separada (ver 10.12).

### 10.12 Sobre `ExtendedScale`

A revisão anterior desta spec propunha um enum interno `ExtendedScale` com tradução para `PedalScale` na persistência. Esta revisão **rejeita** essa abordagem pelos seguintes motivos:

- A tradução silenciosa entre escalas musicalmente diferentes produz inconsistência semântica. UI, acessibilidade, logs e regras futuras descreveriam uma escala diferente da realmente usada.
- O domínio musical persistido e a geração divergem, criando um acoplamento frágil entre duas representações da mesma coisa.
- O ganho de variedade que motivaria a introdução de novas escalas é melhor obtido por variação dentro das escalas existentes (e.g., transposições, contornos, motivos) e por melhorias no compositor (ver 11).

A spec reserva a evolução de `PedalScale` para uma spec futura, que deverá tratar:

- expansão retrocompatível de `PedalScale` (e.g., novo `case blues` com `Int` raw value bem definido);
- codificação/decodificação tolerante a valores desconhecidos;
- migração opcional e não destrutiva;
- impacto em UI e acessibilidade;
- impacto em metadata updates;
- testes de persistência;
- rollout gradual.

A spec atual não autoriza essa evolução.

## 11. Estratégia de Composição

A versão 2 do gerador introduz um **compositor determinístico** que recebe um `MusicalProfile` e produz um `PedalSequence`. Os princípios:

1. **Motivo principal**: 2–4 notas geradas a partir de `root`, `scale` e `register` usando o `contour` escolhido.
2. **Repetição controlada**: o motivo é repetido `repetitionFactor × 4` vezes com pequenas variações permitidas (deslocamento de oitava, transposição local).
3. **Variação de motivo**: aplicada via `motifSeed` (ver 12), sem randomness global.
4. **Contorno**: `ascending`, `descending`, `arched`, `stable` ou `meandering`. O `contour` define a tendência macro; o compositor permite exceções controladas.
5. **Limites para saltos consecutivos**: `intervalRange.upperBound` é respeitado entre notas adjacentes. Se o compositor precisar violar, ele reescala via `register` ou repete.
6. **Alternância de duração**: o compositor determina, por step, se o step é `strong`, `weak`, ou `rest` com base em `density`, `syncopation` e `tension`.
7. **Rests coerentes**: densidade-alvo em `MusicalProfile.density`. Ajustes locais para garantir que nenhuma sequência tenha 0 ou 128 notas.
8. **Resolução ocasional**: todo `arched` e `ascending` termina no `register.lowerBound` ou em `root`.
9. **Acordes ou múltiplas notas**: apenas se `density > 0.5` e `tension < 0.4` (caso raro, controlado).
10. **Variação seeded pelo fingerprint**: `motifSeed`, `rhythmSeed` e `contourSeed` (ver 12) são usados em todas as escolhas estocásticas internas.

A composição continua emitindo `PedalNote(step, row, midiNote, velocity)`. A diferença é que `row` deixa de ser a única fonte de altura: ele se torna um **slot** dentro de `register`/`intervalRange`.

## 12. Determinismo

### 12.1 Fonte de seed

O `fingerprint` produzido por `ImageInputPreparer.fingerprint(of:runID:)` é uma string hexadecimais minúsculos de 64 caracteres. A spec define como esse fingerprint vira o `seed64` usado pelo gerador.

### 12.2 Contrato de `seed64`

```text
seed64 = UInt64(bigEndianBytes: fingerprintHex[0..<16])
```

Regras:

- O fingerprint é uma string hex de 64 caracteres. Os primeiros 16 caracteres representam os primeiros 8 bytes do SHA-256.
- A conversão usa o construtor `UInt64(bigEndian:)` (Swift) ou `UInt64(bigEndianBytes: [UInt8])` equivalente: bytes 0..<8 lidos como big-endian.
- `endianness` é **explícito** e é **big-endian**. O contrato é fixo e congelado pelo golden test.
- A conversão é puramente inteira; nenhum `Double` intermediário.
- O resultado é um `UInt64` em `[UInt64.min, UInt64.max]`.

O tipo é `UInt64`, não `Int`, para evitar variação de largura entre plataformas.

### 12.3 Sub-seeds

A v2 precisa de mais de uma variável pseudoaleatória. A spec define cinco sub-seeds derivados de `seed64` por uma **função de mistura estável**.

```text
rootSeed    = subSeed(seed64, .root)
scaleSeed   = subSeed(seed64, .scale)
rhythmSeed  = subSeed(seed64, .rhythm)
contourSeed = subSeed(seed64, .contour)
motifSeed   = subSeed(seed64, .motif)
```

A função `subSeed` é especificada usando o algoritmo **SplitMix64 finalizer**, que é determinístico, estável, platform-independent e bem conhecido:

```text
func splitMix64(_ x: UInt64) -> UInt64 {
    var z = x &+ 0x9E3779B97F4A7C15
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return z ^ (z >> 31)
}

func subSeed(_ seed: UInt64, _ domain: SeedDomain) -> UInt64 {
    return splitMix64(seed ^ domain.tag)
}
```

Onde `SeedDomain` é um enum com `tag` fixo e congelado pelo golden test:

```swift
enum SeedDomain: UInt64 {
    case root    = 0xA1B2C3D4E5F60718
    case scale   = 0x1234567890ABCDEF
    case rhythm  = 0xFEDCBA0987654321
    case contour = 0xDEADBEEFCAFEBABE
    case motif   = 0x0123456789ABCDEF
}
```

Regras inegociáveis:

- `&+`, `&*` e `>>` operam sobre `UInt64`. Operadores com overflow são proibidos (`+` e `*` são proibidos).
- As constantes mágicas são documentadas como parte do contrato e não podem mudar sem reprovar os golden tests.
- `SeedDomain.tag` é um valor `UInt64` literal, codificado diretamente no enum. Mudar a ordem dos casos **não** muda os tags.
- `subSeed` é puro, sem estado, sem dependência de `Date`, `UUID` ou RNG.

### 12.4 Proibições explícitas

A spec proíbe na v2:

- `Swift.Hasher` (qualquer uso de `hash(into:)` ou `Hasher`).
- `hashValue` (qualquer leitura, em qualquer tipo).
- Iteração sobre `Dictionary` ou `Set` cujo resultado determine uma decisão.
- `Date()`, `UUID()`, `arc4random`, `SystemRandomNumberGenerator`, `Int.random`, `Double.random`.
- Operações de ponto flutuante como intermediárias em cálculo de seed.

O golden test (18.1) detecta qualquer violação dessas regras por mudança acidental de output.

### 12.5 Coleções e ordem

Todas as operações internas do compositor usam índices explícitos, não `Set` ou `Dictionary` com iteração não ordenada. Quando uma estrutura ordenada for usada, ela é `Array` ou `Stride`. Coleções desordenadas exigem uma ordenação explícita antes de qualquer decisão.

### 12.6 Reuso de buffers

`PhotoColorAnalyzer` já percorre o pixel buffer 64×64 uma vez. A versão 2:

- reaproveita esse pixel buffer para calcular `hueHistogram`, `luminanceHistogram`, `saturationHistogram`, `meanLuminance`, `luminanceContrast`, `spatialEnergy`, `verticalBalance`, `horizontalBalance`, `visualEntropy`;
- não adiciona nova passagem completa sobre os pixels;
- expõe todos os descritores como `let` no `VisualAnalysis` final, com a `PhotoColorProfile` original ainda presente para compatibilidade.

## 13. Persistência e Versionamento

### 13.1 Decisão

A spec introduz `generatorVersion: Int?` em `PhotoPedal` (não em `PedalSequence`, para evitar que pequenas variações do contrato musical quebrem `PedalSequence` por si só). O valor inicial é `1` para a versão atual do gerador (sem mudança). A versão 2 do algoritmo incrementa para `2`.

### 13.2 Contrato de `generatorVersion`

| Valor (JSON) | Significado |
| --- | --- |
| campo ausente ou `null` | tratado como `1` (algoritmo legado) |
| `1` | algoritmo legado (`ImageSequenceGenerator.makeSequence` atual) |
| `2` | algoritmo v2 determinístico |
| valor desconhecido (e.g., `3`, `99`, `-1`) | explícito: **reproduzir a sequência persistida**, nunca regenerar |

Comportamento em runtime:

- `decodificar` um pedal com `generatorVersion == nil` ou ausente: tratar como `1`.
- `decodificar` um pedal com `generatorVersion == 1`: usar a sequência persistida.
- `decodificar` um pedal com `generatorVersion == 2`: usar a sequência persistida.
- `decodificar` um pedal com `generatorVersion == 3` (futuro): usar a sequência persistida; nunca regenerar automaticamente.
- `gerar` um novo pedal: gravar `generatorVersion = 2` no JSON.

A spec **não** regenera automaticamente um pedal apenas porque a versão do app mudou. Pedais existentes são reproduzidos literalmente.

### 13.3 Compatibilidade com pedais existentes

- Pedais com `generatorVersion == nil` (campo ausente) são tratados como `1`.
- `PhotoPedal` continua decodificando sem migração destrutiva.
- A geração **só** é reexecutada para novos pedais. Pedais antigos não são regenerados, recoloridos ou atualizados silenciosamente.
- A capa persistida de um pedal antigo não é alterada pela introdução da v2.

### 13.4 Migração

A spec **não** autoriza migração em massa. O campo `generatorVersion` é apenas metadado, opcional na decodificação.

### 13.5 Schema

```swift
struct PhotoPedal: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let sequence: PedalSequence
    let effect: PedalEffect
    let createdAt: Date
    let coverFilename: String
    let generatorVersion: Int?     // novo; default 1 quando ausente
}
```

`PedalStore.validateMetadataUpdateTemporaryJSON` precisa continuar verificando apenas `id`, `createdAt`, `sequence`, `effect`, `coverFilename` (sem exigir igualdade de `generatorVersion`, pois o campo é somente leitura na atualização de metadados).

### 13.6 Codificação e decodificação

- Codificação: novos pedais sempre gravam `generatorVersion = 2`.
- Decodificação: aceita ausente, `1`, `2` e valores desconhecidos.
- Valores desconhecidos: o pedal é decodificado normalmente; a versão é exposta como `Int?` para diagnóstico.
- Nenhum `fatalError` ou exceção é lançada para valores fora de `[1, 2]`.

### 13.7 DEBUG A/B

A spec não altera a persistência em DEBUG. O modo A/B (ver 15) usa um sink em memória e nunca grava JSON com `generatorVersion = 1` por engano.

### 13.8 Metadata update

`PhotoPedal.updatingMetadata(name:description:)` preserva `generatorVersion`. `PhotoPedal.updating(effect:soundProfile:)` também. Nenhum desses helpers pode alterar o valor persistido.

### 13.9 Logs

- `PerformanceDiagnostics` ganha um evento `generatorVersion` com o valor inteiro ou `nil`.
- `MusicalRunDiagnostics.algorithmVersion` reflete o valor (1 ou 2) usado durante a geração.
- Logs antigos continuam exibindo `root`, `scale`, `bpm`; a versão é apenas uma coluna adicional.

### 13.10 Testes de versionamento

- Decodificar JSON sem `generatorVersion` produz `PhotoPedal.generatorVersion == nil`.
- Decodificar JSON com `generatorVersion: 1` produz `PhotoPedal.generatorVersion == 1`.
- Decodificar JSON com `generatorVersion: 2` produz `PhotoPedal.generatorVersion == 2`.
- Decodificar JSON com `generatorVersion: 99` produz `PhotoPedal.generatorVersion == 99` sem erro.
- Codificar um novo pedal com `generatorVersion: 2` produz JSON contendo `"generatorVersion": 2`.
- Recodificar um pedal antigo (`generatorVersion: nil`) preserva a ausência do campo.
- `updatingMetadata` e `updating(effect:soundProfile:)` não alteram `generatorVersion`.

### 13.11 Identidade cromática por pitch

- `dominantPitchClass` continua sendo derivada de `PedalSequence.notes` via `DominantPitchClassResolver`.
- A identidade cromática por pitch **não** muda. Capas persistidas não são recoloridas.
- A nova geração produz sequências cuja `dominantPitchClass` será distribuída de forma menos enviesada. Isso é **consequência esperada** da v2 e é desejável.

## 14. Identidade Cromática

A integração com `PitchColorIdentity` permanece:

- `PhotoPedalPipeline` continua resolvendo `dominantPitchClass` após a geração da sequência;
- a paleta tonal continua sendo aplicada por `RetroImageProcessor.recolor`;
- a persistência continua guardando apenas a capa recolorida, não a paleta.

A v2 pode alterar a distribuição de `dominantPitchClass` (provavelmente para melhor), o que **muda** a paleta tonal média da biblioteca. Esta mudança é automática, esperada e intencional. Capas antigas não são regeradas; a nova paleta aparece apenas em novos pedais.

A spec proíbe explicitamente o ciclo:

```text
photo color → root → pitch color → alteração da música
```

Após a sequência existir, a cor de pitch não retroalimenta a geração musical. O fluxo é unidirecional:

```text
PedalSequence
    → DominantPitchClassResolver
    → PitchColorIdentity
    → retro recolor
```

A identidade cromática final é derivada da sequência musical efetivamente gerada, e nunca do caminho inverso.

## 15. Instrumentação DEBUG e Estratégia A/B

### 15.1 Novos eventos

`PerformanceDiagnostics.event` (já existente) ganha novas chamadas, todas sob `#if DEBUG`:

- `musicAnalysis` (detalhes: `side`, `fingerprint16`, `meanLuminance`, `luminanceContrast`, `edgeDensity`, `tonalFamily`, `visualEntropy`).
- `musicalProfileBuilt` (detalhes: `root`, `scale`, `bpm`, `contour`, `density`, `intervalRange`, `generatorVersion`).
- `sequenceComposed` (detalhes: `noteCount`, `restCount`, `uniquePitches`, `pitchClassEntropy`, `generatorVersion`).
- `pitchClassHistogram` (detalhes: `bins=0..11` como `Int` por bin, separados por vírgula).
- `generatorVersion` (detalhes: valor inteiro ou `nil`).

### 15.2 Novo tipo de instrumentação

`MusicalRunDiagnostics: Sendable, Equatable`:

```swift
struct MusicalRunDiagnostics: Sendable, Equatable {
    let fingerprint16: String
    let root: Int
    let scale: String
    let bpm: Int
    let contour: String
    let noteCount: Int
    let restCount: Int
    let uniquePitches: Int
    let pitchClassHistogram: [Int]   // 12 bins
    let maxPitchShare: Double
    let pitchClassEntropy: Double
    let meanIntervalSemitones: Double
    let maxJumpSemitones: Int
    let durationDistinctCount: Int
    let chordStepCount: Int
    let algorithmVersion: Int
    let tonalFamily: String
    let corpusIdentifier: String?
}
```

`PhotoPedalPipeline` produz esse diagnóstico em `#if DEBUG` e o anexa a um sink opcional, configurável para testes e para o launcher DEBUG.

### 15.3 A/B DEBUG

O modo DEBUG permite comparar v1 e v2 sem modificar pedais persistidos. O contrato é:

- Entrada: a mesma `UIImage` (ou `PreparedImage`) e o mesmo `runID`.
- Processamento: o pipeline é invocado **uma vez** com `generatorVersion = 1` e **uma vez** com `generatorVersion = 2`, reaproveitando o mesmo `ImagePixelBuffer` já preparado. Não há nova normalização ou nova passada sobre os pixels para o mesmo run.
- Saída: dois `MusicalRunDiagnostics` lado a lado, ambos em memória, com os mesmos identificadores (`runID`, `fingerprint`, `corpusIdentifier`).
- Persistência: nenhum dos dois resultados é gravado. Não há substituição de capa, recoloração ou atualização de `latest-pedal.json/png`.
- Release: o A/B é estritamente `#if DEBUG`. Em Release, a única chamada é a do `generatorVersion = 2`.
- Exportação: o sink pode serializar o par como CSV em `tmp` para inspeção manual. O arquivo é volátil.
- Corpus: cada A/B recebe um `corpusIdentifier` (e.g., "procedural-v1", "real-200-v1", "real-200-v2") que aparece no CSV e em `MusicalRunDiagnostics`.
- Inspeção individual: a spec suporta um `case` DEBUG em `LibraryDebugLauncher` para rodar o A/B em uma única imagem, com side-by-side de `MusicalRunDiagnostics` e a capa renderizada para v1 e v2.

### 15.4 Não-recorrência de processamento

O reaproveitamento do `ImagePixelBuffer` é obrigatório: o A/B não pode normalizar a imagem duas vezes. A spec aceita o custo de duas chamadas a `ImageSequenceGenerator.makeSequence` (uma v1, uma v2) porque ambas operam sobre a capa 2-bit já processada; nenhuma nova passada de pixel completa é introduzida.

### 15.5 Launchers

A spec **não** redesenha UI. Apenas adiciona, no `LibraryDebugLauncher` existente, uma nova opção DEBUG para rodar o A/B sobre um conjunto de imagens sintéticas e exportar um CSV. A exportação é local (`tmp`).

## 16. Corpus de Validação

### 16.1 Fonte

A spec **não** introduz imagens licenciadas no repositório. O corpus é dividido em:

1. **Síntese procedural** (em testes), com pelo menos 12 cenários visuais reproduzíveis:
   - pele diurna com céu;
   - pele noturna com luz quente;
   - paisagem verde;
   - paisagem azul;
   - paisagem noturna;
   - pôr-do-sol;
   - objeto isolado neutro;
   - objeto isolado saturado;
   - arquitetura urbana;
   - natureza morta;
   - imagem clara;
   - imagem escura.
2. **Imagens reais DEBUG-only** carregadas pelo launcher a partir de um diretório configurável fora do repositório (`PHOTO_PEDAL_CORPUS_DIR`). Quando o diretório não existe, o launcher cai no modo procedural. Quando existe, o launcher indexa até 200 imagens. Esta estratégia evita versionar imagens no repositório.
3. **Pequeno conjunto embutido** (≤ 12 imagens pequenas geradas via `UIGraphicsImageRenderer`) para testes reproduzíveis dentro do alvo de testes. Esses ativos são sintéticos e não licenciados.

### 16.2 Categorias obrigatórias

- retratos durante o dia;
- retratos à noite;
- paisagens durante o dia;
- paisagens à noite;
- objetos;
- arquitetura;
- natureza;
- imagens de baixa saturação;
- imagens de alta saturação;
- imagens claras;
- imagens escuras;
- imagens com sujeito central;
- imagens sem sujeito evidente.

### 16.3 Como o corpus é usado

- Em testes, um `CorpusRunner` itera as 12 imagens sintéticas, roda a geração e coleta `MusicalRunDiagnostics` por imagem.
- Em DEBUG, o launcher opcional processa o diretório externo e gera o CSV.
- O corpus não substitui o teste de equivalência pixel-a-pixel. Esse continua sendo provido por `PhotoPedalStabilizationTests`.

## 17. Métricas

### 17.1 Duas dimensões de variedade

A spec separa formalmente duas dimensões. Atingir uma não garante a outra.

#### Variedade global

Diversidade entre diferentes fotos do corpus:

- `rootHistogram[0..<12]`: histograma de 12 bins sobre `rootPitchClass`.
- `pitchClassHistogramGlobal[0..<12]`: histograma de 12 bins sobre todos os `midiNote % 12` emitidos.
- `scaleHistogram`: histograma de `PedalScale` finais.
- `registerHistogram`: histograma de `baseOctave`.
- `tonalFamilyHistogram`: histograma de famílias.
- `pitchClassEntropyGlobal`:
  ```text
  H = -Σ p_c × log2(p_c),  c = 0...11
  ```
  Máximo teórico: `log2(12) ≈ 3.585 bits`.
- `categoryDistribution`: histograma de categorias do corpus.
- `familyToRootDistribution`: matriz `family × root` mostrando a fração de cada root dentro de cada família.

#### Variedade interna

Diversidade dentro de uma única sequência:

- `uniquePitchClasses`: número de `midiNote % 12` distintos na sequência.
- `intervalSemitones[i] = |midiNote[i] - midiNote[i-1]|` para `i > 0`; reporta média, mediana, máximo, distribuição por bucket.
- `restDensity = restCount / 128`.
- `noteDensity = noteCount / PedalSequence.maximumNoteSlots`
  (com `maximumNoteSlots = steps * rows = 16 * 8 = 128`).
  A constante nomeada em `PedalSequence` substitui o número
  mágico `128`. Retorna `0` quando `noteCount == 0`.
- `activeStepCount = steps - restStepCount`.
- `meanNotesPerActiveStep = noteCount / activeStepCount` (0 quando
  não há steps ativos).
- `singleVoiceStepCount` / `twoVoiceStepCount` /
  `threeOrMoreVoiceStepCount` = passos ativos com 1, 2 ou ≥3 notas.
- `durationDistinctCount = count(velocity distintos)`.
- `patternRepetition = taxa de PedalNote repetidas em steps adjacentes`.
- `zeroIntervalTransitionShare = zeroIntervalTransitionCount /
  melodicTransitionCount` (0 quando não há transições).
- `chordStepCount = steps com mais de uma nota`.
- `contourEmpirical`: classificação observada do contorno (ascending, descending, etc.) versus `MelodicContour` declarado.
- `registerUtilization`: distribuição do `midiNote` dentro do `register` declarado.
- `resolutionPresence`: presença ou ausência de resolução final no `register.lowerBound` ou `root`.

### 17.2 Métricas operacionais

Independentes de variedade, mas exigidas:

- `generationLatency`: tempo de `ImageSequenceGenerator.makeSequence`.
- `peakMemory`: pico de alocação durante a geração.
- `determinismCheck`: hash SHA-256 de `PedalSequence.notes + harmony` rodado N vezes, comparando byte-a-byte.

### 17.3 Como interpretar `log2(12)`

A spec define explicitamente:

- `H` próxima de `log2(12)` é evidência de uso de todas as 12 pitch classes.
- `H` baixa é evidência de concentração em poucas pitch classes.
- A meta **não** é `H = log2(12)`; é `H` razoável para a natureza do produto (16 notas por sequência).

A interpretação é feita em duas escalas:

- por sequência: `uniquePitchClasses`, `intervalSemitones` e `restDensity` medem uso local.
- por corpus: `H` mede uso global.

### 17.4 Fase de Baseline

A spec **não** fixa thresholds finais antes do baseline. Antes de qualquer decisão de promoção para `Ready`, a fase de baseline deve:

1. Rodar o algoritmo atual (v1) sobre o corpus procedural completo e o corpus real DEBUG (quando disponível).
2. Produzir um relatório versionado (JSON + CSV) contendo, no mínimo:

```text
algorithmVersion: Int
corpusIdentifier: String
corpusSize: Int
categoryCounts: [String: Int]
rootHistogram: [Int]            // 12 bins
pitchClassHistogram: [Int]      // 12 bins
scaleHistogram: [String: Int]
registerHistogram: [Int]
tonalFamilyHistogram: [String: Int]
familyToRootDistribution: [[Double]]  // family × root
pitchClassEntropyGlobal: Double
meanUniquePitchClassesPerSequence: Double
maxSinglePitchClassShare: Double
meanIntervalSemitones: Double
maxJumpDistribution: [Int]      // bucketizada
noteDensity: Double
restDensity: Double
durationDiversity: Double
patternRepetition: Double
multiNoteStepShare: Double
generationLatency: Double
peakMemory: Int
```

3. Ser exportável e versionado por `algorithmVersion`, `corpusIdentifier` e data.
4. Servir como referência para calibrar `TonalFamilyWeights`, `pickScale`, `pickContour` e os guardrails provisórios (ver 29).

Somente após essa fase os thresholds finais podem ser confirmados. A spec pode manter valores provisórios como guardrails iniciais (29), deixando claro que são hipóteses.

## 18. Plano de Testes

### 18.1 Golden tests de seed e perfil

Os golden tests capturam o resultado determinístico do contrato de seed e da derivação de `MusicalProfile`. Cada caso declara:

- `fingerprint` (string hex de 64 chars);
- `VisualAnalysis` esperado (gerado por uma fixture sintética conhecida);
- `seed64` esperado;
- `tonalFamily` esperado;
- `root` esperado (índice 0..11);
- `scale` esperado;
- `MusicalProfile` esperado.

Casos obrigatórios (mínimo):

- fingerprint de 64 zeros: `seed64 = 0`, e o resultado completo do pipeline até `MusicalProfile`.
- fingerprint de 64 'f': `seed64 = UInt64.max`, e o resultado completo.
- fingerprint alternado "ab" repetido: resultado congelado.
- fingerprint com bytes 0x00, 0xFF intercalados: resultado congelado.
- fingerprint gerado por uma `Fixtures.patternImage` real: o pipeline até `MusicalProfile` é golden.
- 6 fingerprints adicionais escolhidos para cobrir cada `TonalFamily` pelo menos uma vez.

Os testes falham se:

- endianness muda;
- função `splitMix64` muda;
- `SeedDomain.tag` muda;
- ordem dos casos em `TonalFamily` muda e isso afeta `tonalFamily.rawValue` usado em algum lugar;
- `String(format: "%02x", ...)` muda para uppercase (afeta comparação de hex no `fingerprint16`).

Os testes comparam **byte-for-byte** o JSON codificado de `MusicalProfile` e **campo por campo** seus componentes. `fingerprint` é comparado como string.

### 18.2 Golden tests do compositor

Cada caso declara:

- `MusicalProfile` (gerado por um caso golden do item 18.1);
- `generationSeed` (já presente em `MusicalProfile`);
- `PedalSequence` esperado (codificado em JSON).

Casos obrigatórios:

- 6 perfis cobrindo cada `TonalFamily` × cada `PedalScale` × cada `MelodicContour`.
- 3 perfis com `density` baixa, média, alta.
- 3 perfis com `intervalRange` mínimo, médio, máximo.

Os testes comparam byte-for-byte o JSON codificado de `PedalSequence`. Detectam:

- mudança de ordem de iteração sobre `Set` ou `Dictionary`;
- mudança de `PedalScale` raw values;
- mudança de `MelodicContour` raw values;
- mudança de algoritmo de seleção interna (`motifSeed`, `rhythmSeed`, `contourSeed`);
- mudança de `splitMix64`;
- mudança de plataforma (testado em simulador iOS e CI x86_64 separadamente);
- refactor que preserve compilação mas altere a saída musical.

### 18.3 Determinismo de reprodução

- Mesma `PreparedImage` produz o mesmo `VisualAnalysis`.
- Mesmo `VisualAnalysis` produz o mesmo `MusicalProfile`.
- Mesmo `MusicalProfile` produz o mesmo `PedalSequence`.
- Mesma `PhotoPedal` codificada e decodificada preserva `generatorVersion` e sequência.
- Codificar `PedalSequence` N vezes produz JSON byte-equivalente.
- SHA-256 de `notes + harmony + soundProfile` é idêntico em N execuções.

### 18.4 Testes de invariantes

- A soma de `TonalFamilyWeights[family]` é 1.0 ± 1e-9 para cada família.
- Nenhum peso é ≤ 0.
- Para cada família, exaustão de `rootSeed` em `[0, 1_000_000)` cobre as 12 pitch classes.
- `0 ≤ rootPitchClass.rawValue ≤ 11` em todo output.
- `register.upperBound - register.lowerBound ≥ 12`.
- `density ∈ [0.10, 0.95]`.
- `intervalRange.upperBound ≤ 24`.
- `noteCount` em `[1, 128]`.
- Sequência nunca vazia (a menos que explicitamente habilitado por spec futura).

### 18.5 Distribuição

- Corpus procedural completo não apresenta `C + C# root share > guardrailProvisorio` (ver 29).
- Nenhuma pitch class domina além do limite acordado.
- Retratos diurnos sintéticos não colapsam predominantemente em C/C♯.
- Diferentes categorias visuais produzem variedade suficiente.

A spec **não** exige distribuição perfeitamente uniforme. Os testes verificam limites, não médias perfeitas.

### 18.6 Musicalidade

- `uniquePitchClasses` mínimo por sequência conforme comprimento.
- Limite para saltos consecutivos.
- Limite para repetição involuntária.
- Presença de rests dentro das faixas esperadas.
- Notas dentro do `register` permitido.
- Notas dentro da escala escolhida.
- Acordes dentro do limite de vozes (e.g., 3 vozes no máximo).

### 18.7 Compatibilidade

- Identidade cromática por pitch continua correta: a paleta tonal de um pedal persistido é estável.
- Capas persistidas não são recoloridas indevidamente.
- Pedais existentes continuam abrindo.
- Não há migração destrutiva automática.
- Playback e pedalboards existentes continuam funcionando.
- Fixtures DEBUG permanecem válidas ou são atualizadas explicitamente.
- `generatorVersion` ausente é tratado como `1`.
- `generatorVersion` desconhecido é preservado.

### 18.8 Cobertura mínima sugerida

- `SeedContractTests`: 10 testes, cobrindo `seed64`, `splitMix64`, `subSeed`, `SeedDomain`.
- `VisualAnalysisTests`: 8 testes, cobrindo histograma, contrastes, entropia, balanço espacial, `tonalFamily`.
- `MusicalProfileTests`: 6 testes, cobrindo invariantes e famílias.
- `RootAndScaleStrategyTests`: 10 testes, cobrindo famílias, alcance de pitch classes, soma de pesos, exaustão de `rootSeed`.
- `CompositionTests`: 10 testes, cobrindo motivo, contorno, intervalo, descanso, resolução, acordes.
- `VersioningTests`: 6 testes, cobrindo `generatorVersion` ausente, `1`, `2`, desconhecido, recodificação, atualização de metadados.
- `ABComparisonTests`: 4 testes, cobrindo reaproveitamento de buffer, ausência de persistência, paridade de `fingerprint` entre v1 e v2.
- `DistributionTests`: 4 testes, cobrindo o corpus procedural.
- `CompatibilityTests`: 4 testes, cobrindo `dominantPitchClass` derivada, identidade cromática, pedais antigos.

## 19. Performance

### 19.1 Orçamento

A spec preserva o orçamento atual e adiciona o custo da nova camada:

- `visualAnalysis` (estendido): ≤ 5 ms adicionais.
- `musicalProfile` (puro, sem alocações significativas): ≤ 1 ms.
- `composition` (puro, sem alocações significativas): ≤ 2 ms.
- `totalPipeline`: deve permanecer dentro do observado (`100–500 ms` para o pipeline essencial completo). A meta concreta é **não aumentar** o `totalPipeline` em mais de 8 ms para imagens 4032×3024.

### 19.2 Alocações

- `VisualAnalysis` aloca 4 arrays pequenos (≤ 12 + 8 + 4 + 4 = 28 doubles). Total ≪ 1 KB.
- `MusicalProfile` é um struct de tipos `Double`/`Int`/enums. Sem alocações dinâmicas.
- `composition` aloca no máximo 128 `PedalNote` (já é o caso).
- Buffers do `PhotoColorAnalyzer` são reusados.

### 19.3 Medição

A spec reutiliza `PerformanceDiagnostics.measure` para os novos estágios. Os testes não medem tempo absoluto, mas verificam que o orçamento é respeitado na média de 5 execuções. A validação física é responsabilidade da spec de rollout, não desta.

## 20. Rollout

A v2 entra em produção em 5 incrementos pequenos, cada um com seu próprio conjunto de testes, validação física e gate explícito.

### 20.1 Incremento 1 — Instrumentação e Baseline

- medir o algoritmo atual (v1) sobre o corpus procedural;
- registrar `MusicalRunDiagnostics` em `#if DEBUG`;
- construir o corpus procedural;
- produzir o relatório de baseline (ver 17.4);
- comparar `H`, `root distribution` e `uniquePitches` antes da v2.

Não altera geração de produção.

**Status (2026-07-22): implementado.**

Entrega Incremento 1:

- infraestrutura DEBUG em `snap-battle/Services/Debug/MusicDiagnostics/`:
  `CorpusCategory`, `MusicalRunDiagnostics`, `MusicalCorpusReport`,
  `MusicalCorpusReportAggregator`, `MusicalDiagnosticsCalculator`,
  `ProceduralCorpus`, `MusicalDiagnosticsHarness`;
- testes em `snap-battleTests/`: `MusicalDiagnosticsCalculatorTests`,
  `MusicalCorpusReportTests`, `ProceduralCorpusTests`,
  `MusicalDiagnosticsEquivalenceTests`;
- ponto de entrada DEBUG no `LibraryDebugLauncher` (botão
  "Executar baseline e exportar JSON" que grava o JSON em
  `Application Support/debug-musical-baseline/`);
- baseline capturado sobre `procedural-v1` (14 fixtures). Detalhes e
  números objetivos em `docs/audits/photo-midi-v1-baseline.md`.

Resumo do baseline (somente corpus procedural, n = 14):

- `C + C♯ root share`: 42,9% (guardrail provisório: 25%);
- root C isolada: 35,7%;
- 7 de 14 categorias mapeiam para C ou C♯;
- `globalPitchClassEntropy`: 3,53 bits;
- `meanUniquePitchClassesPerSequence`: 4,7;
- `meanMaximumPitchClassShare`: 0,26;
- `meanNotesPerActiveStep`: 6,43 (média global; 0 quando não há steps ativos);
- `meanSingleVoiceStepShare`: 0,05; `meanTwoVoiceStepShare`: 0,02;
  `meanThreeOrMoreVoiceStepShare`: 0,86 — confirma a predominância
  de acordes densos (3+ vozes) em 86% dos steps ativos;
- `meanZeroIntervalTransitionShare`: 0,79 — 79% das transições
  melódicas repetem a mesma nota (intervalo 0), explicando o
  `meanIntervalSemitones = 0,4` observado;
- `runsWithMemorySamples`: 14; `meanResidentMemoryDeltaBytes`:
  -1,6 MB (proxy grossa no Simulator; valores exatos variam entre
  execuções porque `resident_size` depende do estado do processo;
  ver `docs/audits/photo-midi-v1-baseline.md`);
- `meanSequenceGenerationDurationMilliseconds`: 7,50 ms;
- `meanDiagnosticsDurationMilliseconds`: 0,20 ms;
- `meanTotalRunDurationMilliseconds`: 27,32 ms.

Definições formais adotadas:

- `noteDensity = noteCount / PedalSequence.maximumNoteSlots`, onde
  `maximumNoteSlots = steps * rows = 16 * 8 = 128`. A constante
  nomeada em `PedalSequence` substitui o número mágico `128`.
- `meanNotesPerActiveStep = noteCount / activeStepCount` (0 quando
  não há steps ativos).
- Distribuição de vozes: passos ativos com 1, 2 ou ≥3 notas,
  contados independentemente da ordem de inserção.
- `zeroIntervalTransitionShare = zeroIntervalTransitionCount /
  melodicTransitionCount` (0 quando não há transições).
- `meanResidentMemoryDeltaBytes` é a média de
  `residentMemoryBytesAfter - residentMemoryBytesBefore` (com
  sinal) sobre os runs com ambos os samples válidos.

Auditoria de proteção Release: a infraestrutura de diagnóstico
(`MusicalDiagnosticsHarness`, `MusicalDiagnosticsCalculator`,
`MusicalCorpusReport`, `MusicalCorpusReportAggregator`,
`MusicalRunDiagnostics`, `CorpusCategory`, `ProceduralCorpus`),
o botão do harness em `LibraryDebugLauncher` e a fixture store
em `LibraryDebugFixtures` estão integralmente protegidos por
`#if DEBUG`. O `xcodebuild -configuration Release build` passa.
A baseline é DEBUG-only e o relatório versionado usa a versão
`.normalized` (sem `generatedAt`) — ver
`docs/audits/photo-midi-v1-baseline.md` para os detalhes.

A v2 **não** foi implementada. Nenhuma parte do `MusicalProfile`, do
novo seed, do novo `TonalFamily` ou do compositor v2 está no
repositório. A spec continua `Draft` até que `Open Decisions Before
Ready` (32) esteja vazio. Captura com imagens reais permanece aberta
(ver 21.1 e os próximos dados necessários listados em
`docs/audits/photo-midi-v1-baseline.md`).

### 20.2 Incremento 2 — Perfil musical

- introduzir `VisualAnalysis` e `MusicalProfile` como “no-op” para `generatorVersion == 1`;
- preservar saída atual quando o `generatorVersion == 1`;
- adicionar `generatorVersion` à persistência;
- adicionar testes de invariantes e equivalência.

### 20.3 Incremento 3 — Root e escala v2

- implementar `TonalFamily` e `TonalFamilyWeights`;
- implementar `seedFromFingerprint` (contrato 12.2) e `subSeed` (contrato 12.3);
- mudar `generatorVersion` para `2` na geração;
- comparar A/B usando o corpus procedural (15.3).

### 20.4 Incremento 4 — Compositor v2

- implementar motivo, contorno, syncopação, descansos, repetição, acordes;
- validar invariantes musicais;
- preservar determinismo.

### 20.5 Incremento 5 — Validação física

- rodar o corpus real DEBUG (200 imagens) no dispositivo;
- verificar playback, performance, regressões;
- conduzir validação subjetiva leve (ver 21);
- decidir rollout final.

Cada incremento é fechado por uma `Ready` spec interna (não esta).

## 21. Validação Subjetiva

Métricas objetivas não provam que a sequência soa melhor. A spec exige uma avaliação subjetiva estruturada, com escopo limitado.

### 21.1 Protocolo

- **Sujeitos**: time interno (3–5 pessoas, sem requisito de formação musical).
- **Material**: 16 imagens escolhidas para cobrir todas as `TonalFamily` e categorias do corpus procedural.
- **Procedimento**:
  1. Para cada imagem, gerar duas sequências: v1 e v2, em ordens aleatórias balanceadas.
  2. Tocar par a par (A/B) com cegamento: o ouvinte não sabe qual é v1 e qual é v2.
  3. O ouvinte registra, em uma escala de 1–5, os critérios abaixo.
  4. Repetir para 16 imagens. Tempo total: cerca de 30 minutos.
- **Critérios** (cada um 1–5):
  - **Variedade**: a sequência explora notas diferentes da outra?
  - **Coerência com a foto**: a sequência "combina" com a imagem?
  - **Musicalidade**: a sequência soa musicalmente interessante?
  - **Memorabilidade**: a sequência é reconhecível quando repetida?
  - **Excesso de aleatoriedade**: a sequência parece aleatória sem significado?
  - **Preferência geral**: qual é a favorita?
- **Saída**: planilha CSV com `imageID`, `criterio`, `score`, `v1Score`, `v2Score`, `vencedor`.

### 21.2 Restrições

- Não é pesquisa acadêmica.
- Não envolve usuários externos.
- Não bloqueia promoção se os resultados forem inconclusivos; apenas informa a decisão.
- Pode ser repetida após ajustes de baseline.

### 21.3 Critério de aceitação

A v2 é aceitável do ponto de vista subjetivo se:

- "Preferência geral" vence ou empata em ≥ 12 das 16 imagens;
- "Excesso de aleatoriedade" é ≤ 2 em ≥ 12 das 16 imagens.

Esses números são hipóteses calibráveis após o baseline. A spec não exige resultado estatisticamente significativo.

## 22. Riscos

- **Quebra de identidade cromática** se `dominantPitchClass` mudar drasticamente. Mitigação: validar visualmente que a paleta média da biblioteca melhora; persistir capas antigas.
- **Overfitting do corpus procedural**: o corpus pode não representar a distribuição real. Mitigação: usar o corpus real DEBUG (200 imagens) na validação final.
- **Custo de CPU** se as estatísticas espaciais forem mal implementadas. Mitigação: reusar buffers; budget explícito.
- **Determinismo perdido** se a composição usar `Set` ou `Dictionary` ou se a função de mistura mudar. Mitigação: regra explícita de ordem; golden tests.
- **Resistência do schema** se outros lugares esperarem `generatorVersion` ausente. Mitigação: `Int?` com default `1`; testes de decodificação tolerante.
- **Métrica H manipulada para parecer boa**: usar apenas `H` global seria perigoso. Mitigação: exigir `uniquePitches` mínimo por sequência e `pitchClassShareMax` por sequência.
- **Pedais existentes soarem diferentes em novo dispositivo**: impossível porque a sequência persistida é reproduzida literalmente. Mitigação: já garantido por ADR 0002.
- **Visual identity drift** se a v2 produzir pitches predominantes muito diferentes dos atuais. Mitigação: a paleta tonal é determinística por pitch, então a mudança é global e auto-consistente.
- **Proibição residual** se algum mantenedor reintroduzir `antiPreferred` na família. Mitigação: testes de alcance (18.4) que falham se qualquer peso for ≤ 0 ou se a exaustão de `rootSeed` não cobre as 12 classes.
- **Função de mistura alterada silenciosamente**: mitigar com golden test do `seed64` em 18.1 e teste explícito de `splitMix64`.
- **Endianness trocada**: mitigar com golden test do `seed64` (18.1) que detecta byte-a-byte.

## 23. Alternativas Consideradas

- **Hash puro como root** (`fingerprint mod 12`): rejeitada (perde coerência perceptual; o fingerprint já é a fonte de "aletoriedade" controlada dentro de cada família, então misturar família e hash em uma única operação destruía a estrutura).
- **Permutação balanceada por família**: rejeitada como estratégia principal; investigada em 10.1.
- **Offset calibrado por família**: rejeitada como estratégia principal; investigada em 10.1.
- **Bins calibrados em amostra real**: rejeitada como arquitetura principal; usada como heurística interna de famílias.
- **Core ML imediato**: rejeitado. Ver 25.
- **Mudar `PedalScale` persistido**: rejeitada para o primeiro rollout. Ver 10.12.
- **`ExtendedScale` com tradução silenciosa**: rejeitada nesta revisão. Ver 10.12.
- **Proibir pitch classes por família visual** (proposta da revisão anterior): rejeitada nesta revisão. Substitui um viés acidental por um viés deliberado.
- **Reescrever o sintetizador**: rejeitada. Não relacionado a geração.
- **Aumentar tamanho do grid para 32×16**: rejeitada. Aumento de custo sem ganho claro de variedade.

## 24. Critérios de Aceite da Spec

A spec só será promovida a `Ready` quando:

- a estratégia de root for **distribuição ponderada determinística** (10.1);
- todas as 12 pitch classes forem alcançáveis em todas as famílias (10.4, 18.4);
- o contrato de seed (`seed64`, `subSeed`, `splitMix64`, `SeedDomain`) estiver congelado e golden-tested (12, 18.1);
- a representação de escala for `PedalScale` atual, sem `ExtendedScale` (10.12, 7.2);
- a família tonal não depender apenas de hue dominante (10.3, 7.1);
- a identidade cromática continuar sendo saída da música, sem ciclo (14);
- o contrato de `generatorVersion` estiver completo (13.2, 18.7);
- a estratégia A/B em DEBUG estiver especificada e não persistir (15.3);
- a fase de baseline tiver sido executada e o relatório estiver versionado (17.4);
- os guardrails provisórios tiverem sido calibrados pelo baseline (29);
- a validação subjetiva tiver sido executada (21);
- Core ML estiver explicitamente fora do primeiro rollout (25);
- a spec não tiver alterações de produção pendentes;
- a seção `Open Decisions Before Ready` estiver vazia.

## 25. Plano Incremental de Implementação

A spec não implementa nada nesta entrega. O plano de implementação é de responsabilidade de uma spec `Ready` subsequente. Resumo:

- **Incremento 1**: instrumentação DEBUG-only, sem mudança de produção; baseline (17.4).
- **Incremento 2**: introduzir `VisualAnalysis` e `MusicalProfile` como "no-op" para `generatorVersion == 1`.
- **Incremento 3**: `TonalFamily` + `TonalFamilyWeights` + `seedFromFingerprint` + `subSeed` + `generatorVersion == 2`.
- **Incremento 4**: compositor v2 com motivo, contorno, descanso, syncopação.
- **Incremento 5**: validação física no dispositivo, com corpus real opcional, validação subjetiva (21), e decisão final de rollout.

## 26. Avaliação Futura de Core ML

A spec **não** introduz Core ML. A investigação conclui que:

- uma biblioteca isolada de MIDIs ensina estrutura musical, mas **não** ensina a relação entre foto e música;
- geração direta `image → MIDI` exigiria dataset pareado, que o produto não possui;
- Core ML não deve ser introduzido sem evidência de que descritores determinísticos são insuficientes;
- a v2 é justamente a etapa que **mede** se os descritores determinísticos são suficientes.

Três direções possíveis para iteração futura, **nenhuma** autorizada agora:

1. Classificar atributos musicais abstratos da imagem (e.g., “energetic”, “calm”).
2. Extrair embeddings visuais e convertê-los em `MusicalProfile`.
3. Gerar MIDI diretamente da imagem.

Esta spec recomenda começar a investigar (1) como um experimento isolado, em um branch separado, com um dataset sintético, somente após o rollout da v2 ter mostrado evidência de que descritores determinísticos ainda não são suficientes.

## 27. Arquivos Provavelmente Afetados

Esta spec não altera arquivos. A futura implementação deverá tocar (entre outros):

- `snap-battle/Services/Pedal/PhotoColorAnalyzer.swift` (estender para emitir `VisualAnalysis`).
- `snap-battle/Services/Pedal/ImageSequenceGenerator.swift` (substituir pela nova pipeline `VisualAnalysis → MusicalProfile → Compositor`).
- `snap-battle/Services/Pedal/PedalHeuristics.swift` (novos limites calibráveis).
- `snap-battle/Services/Pedal/PhotoPedalPipeline.swift` (integração da nova pipeline, instrumentação, A/B DEBUG).
- `snap-battle/Domain/Pedal/Pedal.swift` (adicionar `generatorVersion: Int?`).
- `snap-battle/Services/Persistence/PedalStore.swift` (atualizar validação para tolerar `generatorVersion`).
- `snap-battle/Features/Library/Debug/LibraryDebugFixtures.swift` (atualizar fixtures para incluir `generatorVersion`).
- `snap-battleTests/` (novos testes: `SeedContractTests`, `VisualAnalysisTests`, `MusicalProfileTests`, `RootAndScaleStrategyTests`, `CompositionTests`, `VersioningTests`, `ABComparisonTests`, `DistributionTests`, `CompatibilityTests`).
- `docs/IMAGE_TO_MUSIC.md` (atualizar contrato para a v2).
- `docs/DATA_MODEL.md` (documentar `generatorVersion`).
- `specs/current/music-generation-v2.md` (mover para `superseded` quando a v2 for promovida).

## 28. Apêndice A — Causa Provável Confirmada

A investigação confirma a hipótese principal. O mapeamento `root = floor(hue / 30)` faz com que a faixa 0–59° (vermelho, laranja, amarelo) mapeie exclusivamente para C e C♯. Como fotos de pessoas, especialmente diurnas, têm hue médio nessa faixa por causa de pele e iluminação quente, a maioria das fotos com pessoas cai em C ou C♯. O offset entre fotos quase idênticas (e.g., duas selfies com iluminação levemente diferente) é nulo.

A distribuição de pitch classes dentro da sequência é, então, dominada pela combinação `(root + scale_degrees + octaveRange)`, que mantém a maioria das notas dentro de uma janela de 12–24 semitons a partir do root. Sequências com root C concentram notas em C, E, G, A; com root C♯ concentram em C♯, F, G♯, A♯. Esse padrão é coerente do ponto de vista musical, mas é exatamente a "concentração na diagonal próxima à tonalidade" observada.

A simulação procedural em Python (descartável, fora do repositório) reproduz o viés: em 12 categorias sintéticas, fotos de pessoas diurnas/noturnas colapsam 100% em C/C♯; o corpus combinado tem `C + C# root share ≈ 32%` contra 16.7% esperado para uma distribuição uniforme.

A direção proposta (distribuição ponderada) ataca o problema na raiz, porque:

- a família `warm` reduz o peso médio de C e C♯ sem proibi-los;
- a seleção dentro da família é feita pelo fingerprint, distribuindo o "acaso" entre as 12 classes;
- diferentes famílias têm pesos diferentes, preservando a relação perceptual entre foto e música;
- o corpus simulado com a nova estratégia (rodada fora do repositório) mostra `C + C# root share ≈ 21%` no corpus completo e ≈ 18% em retratos diurnos, ambos abaixo do guardrail provisório de 25%.

A ausência de qualquer camada intermediária (motivo, contorno, repetição) significa que a sequência é puramente função da capa 2-bit. Isso explica por que imagens visualmente diferentes podem produzir sequências parecidas: dois padrões espaciais diferentes que, quando projetados na mesma escala no mesmo registro, geram sequências similares. A v2 ataca isso com compositor determinístico (ver 11).

## 29. Apêndice B — Lacunas de Instrumentação

A spec documenta as seguintes lacunas atuais:

- sem `pitchClassHistogram`;
- sem `musicalRunDiagnostics` agregável;
- sem corpus reproduzível;
- sem métrica de unique pitches por sequência;
- sem métrica de entropy;
- sem evento DEBUG para `contour` ou `tension`;
- sem evento DEBUG para `scale` final (apenas `rootName` aparece no log de Foundation Models, fora do pipeline musical);
- sem `generatorVersion` no JSON persistido;
- sem A/B entre v1 e v2;
- sem relatório de baseline versionado.

A spec de Incremento 1 fecha essas lacunas **antes** de qualquer mudança comportamental.

## 30. Apêndice C — Guardrails Provisórios

Valores iniciais. **Hipóteses**, não metas rígidas. Sujeitos à calibração pelo baseline (17.4).

### 30.1 No corpus completo

- `C + C# root share` abaixo de 25% (medido sobre o corpus);
- nenhuma `root` individual acima de 18%;
- todas as 12 roots alcançáveis no corpus amplo;
- ausência de concentração injustificada por categoria;
- `pitchClassEntropyGlobal ≥ 3.0` (limite empírico, não `log2(12)`);
- nenhuma regressão determinística (golden tests idênticos byte-a-byte).

### 30.2 Em retratos diurnos

- pelo menos 6 roots distintas no corpus da categoria;
- `C + C#` não formam maioria absoluta;
- nenhuma root individual domina acima do limite calibrado (a ser fixado após baseline);
- `meanUniquePitchClassesPerSequence ≥ 4`.

### 30.3 Por sequência

- mínimo de pitch classes únicas conforme comprimento:
  - sequências com `noteCount ≥ 8`: `uniquePitchClasses ≥ 4`;
  - sequências com `noteCount < 8`: `uniquePitchClasses ≥ 2`;
- nenhuma pitch class ocupa proporção extrema sem justificativa do perfil (`pitchClassShareMax ≤ 0.40` para `noteCount ≥ 16`);
- notas dentro do `register` declarado;
- acordes dentro do limite de vozes (≤ 3);
- sequência não vazia;
- intervalos consecutivos respeitam `intervalRange`;
- `meanIntervalSemitones ≤ 7`.

### 30.4 Calibração

Estes valores serão ajustados depois do baseline (17.4) com o seguinte método:

1. Medir a distribuição atual (v1) sobre o corpus procedural.
2. Medir a distribuição proposta (v2) sobre o mesmo corpus.
3. Comparar global e por categoria.
4. Ajustar `TonalFamilyWeights` para mover a distribuição v2 em direção a:
   - `C + C# root share` abaixo de 25% no corpus completo;
   - 6+ roots distintas em retratos diurnos;
   - entropia global ≥ 3.0.
5. Re-rodar o corpus; congelar em uma spec interna de Incremento 3.
6. Se a calibração não atingir os guardrails, registrar como risco e reescalar a spec.

Esses valores **não** forçam uniformidade perfeita. Eles combatem o viés observado e mantêm espaço para que a relação perceptual com a foto continue significativa.

## 31. Confirmações desta Entrega

Esta entrega cumpre as restrições explícitas:

- não implementou a nova geração;
- não alterou código de produção;
- não alterou testes existentes;
- não criou branch nova;
- não fez commit;
- não abriu PR;
- não fez merge;
- não modificou specs atuais além desta spec planejada;
- não promoveu a spec para `Ready`;
- removeu a proibição absoluta de C e C♯ da família `warm` (10.1, 10.2);
- formalizou o contrato de seed (12.2, 12.3);
- proibiu `Swift.Hasher`, `hashValue`, RNG global e iteração não ordenada (12.4, 12.5);
- removeu `ExtendedScale` e a tradução silenciosa (7.2, 10.12);
- separou variedade global de variedade interna (17.1);
- exigiu baseline antes de thresholds finais (17.4);
- incluiu guardrails provisórios calibráveis (30);
- definiu família tonal sem depender apenas de hue dominante (10.3);
- preservou a cadeia sequência → pitch identity → cor (14);
- definiu o contrato de `generationAlgorithmVersion` (13.2);
- proibiu regeneração silenciosa de pedais antigos (13.3);
- definiu estratégia A/B em DEBUG sem persistência (15.3);
- incluiu validação subjetiva leve (21);
- manteve Core ML fora do primeiro rollout (25).

## 32. Open Decisions Before Ready

A spec ainda **não** pode ser promovida para `Ready` enquanto as decisões abaixo não forem resolvidas. Cada item lista o que precisa ser decidido, a evidência que falta e quem é responsável.

1. **Pesos finais de `TonalFamilyWeights`**. Os valores em 10.2 são hipóteses. O baseline v1 está capturado em `docs/audits/photo-midi-v1-baseline.md` (somente corpus procedural). Falta capturar a distribuição v2 com os pesos de partida para confirmar a redução do viés, e ajustar os pesos com base nos dados. Evidência necessária: relatório de baseline v2 (Incremento 3) com a distribuição proposta. Responsável: Incremento 3.

2. **Thresholds finais dos guardrails**. Os valores em 30 são hipóteses. O baseline v1 está capturado, mas somente sobre corpus procedural sintético. Falta: (a) calibrar os thresholds para o corpus real, (b) confirmar que os números provisórios refletem o estado real (ex.: `C + C♯ root share` no baseline v1 está em 42,9%, acima do guardrail de 25%). Evidência necessária: baseline v1 sobre corpus real (200+ imagens) e dados suficientes para diferenciar categorias. Responsável: Incremento 1 (parcial) + Incremento 5.

3. **Mapeamento `MelodicContour → bias de scale/bpm`**. A spec diz que `pickScale` e `bpm` usam o `scaleSeed` e `contourSeed`, mas a forma exata (e.g., se `wholeTone` continua sendo escolhido por alta variância) ainda não foi congelada. Evidência necessária: especificação interna de Incremento 3. Responsável: Incremento 3.

4. **Política de `MelodicContour` em Release vs. A/B**. O A/B DEBUG (15.3) gera duas sequências; ainda não está decidido se o Release v2 sempre usa um `MelodicContour` derivado do `contourSeed` ou se também pode usar a classificação empírica observada. Evidência necessária: golden test que cobre o caminho. Responsável: Incremento 4.

5. **Critério de aceitação da validação subjetiva**. Os números em 21.3 (≥ 12 de 16, ≤ 2 em aleatoriedade) são hipóteses. Eles precisam ser confirmados pela primeira rodada de validação subjetiva. Evidência necessária: CSV de 21.1. Responsável: Incremento 5.

6. **Política de rollout da `generatorVersion` em testes DEBUG**. A spec permite o A/B em DEBUG, mas não decidiu se testes unitários comuns (CI) devem usar `1`, `2` ou ambos. Evidência necessária: alinhamento com a estratégia de testes existente. Responsável: Incremento 2.

7. **Evolução de `PedalScale`**. A spec rejeita `ExtendedScale` para o primeiro rollout. Mas não decidiu se uma evolução de schema para incluir `blues`/`darkPentatonic`/`suspended` virá em spec separada e quando. Evidência necessária: roadmap aprovado. Responsável: fora desta spec.

8. **Critério para introduzir Core ML**. A spec diz "depois da v2 ter mostrado evidência de que descritores determinísticos ainda não são suficientes". Mas não há métrica objetiva para essa decisão. Evidência necessária: critério explícito (e.g., "se `pitchClassEntropyGlobal < 3.0` após baseline e após ajustes de pesos, justificar Core ML"). Responsável: fora desta spec.

Quando esta seção estiver vazia, a spec está pronta para ser promovida para `Ready`.
