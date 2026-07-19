# Photo MIDI Variety V2 — Incremento 2: Persistência e Tipos de Análise

Status: Ready
Last updated: 2026-07-19
Feature: Fundação da v2 do gerador foto → MIDI — versionamento de gerador, tipos de `VisualAnalysis`/`MusicalProfile`/`MelodicContour` e `TonalFamily` como no-op para `generatorVersion == 1`
Platform: iOS 26+
Framework: Swift (pipeline determinístico local)
Supersedes: nada
Depende de: `specs/current/photo-midi-variety-v2.md` (design v2), `specs/current/pitch-color-identity.md`, ADRs 0001/0002
Antecede: Incremento 3 (`TonalFamilyWeights` + `seedFromFingerprint` + `subSeed` + `generatorVersion == 2`), Incremento 4 (compositor v2), Incremento 5 (validação física)

> Esta spec autoriza **apenas** o escopo declarado em §3. O pipeline musical em produção permanece determinístico e byte-idêntico ao v1; o algoritmo v2 (root, scale, contour, compositor) **não** é introduzido por esta entrega. O contrato de `generatorVersion` (§13 do design) e os tipos de domínio (`VisualAnalysis`, `MusicalProfile`, `MelodicContour`, `TonalFamily`) são introduzidos em modo no-op, de modo que os Incrementos 3–4 possam trocar a implementação sem alterar o schema persistido nem o tipo da função de geração.

## 1. Contexto

A spec `specs/current/photo-midi-variety-v2.md` divide a v2 do gerador foto → MIDI em 5 incrementos. O Incremento 1 (instrumentação e baseline v1) está implementado e versionado em `docs/audits/photo-midi-v1-baseline.md` (squash `2bd84b8`, 2026-07-19). O pipeline musical atual produz `PedalSequence` a partir de `ImageSequenceGenerator.makeSequence` usando apenas `PhotoColorProfile` (5 números) e a capa 2-bit; `PhotoPedal` é persistido sem campo `generatorVersion`.

Esta spec implementa o **Incremento 2** do design: a fundação de tipos e o versionamento de gerador, sem alterar a geração musical.

## 2. Problema

- O `PhotoPedal` persistido não carrega a versão do algoritmo que o produziu. Após o rollout da v2, pedais antigos (v1) e novos (v2) serão indistinguíveis no disco, e qualquer mudança no `ImageSequenceGenerator` corre o risco de alterar a sequência de pedais antigos ao recarregá-los — embora ADR 0002 já garanta que a sequência persistida é reproduzida literalmente, a ausência de `generatorVersion` impede que o pipeline reporte com qual algoritmo cada pedal foi criado e abre a porta para regressões silenciosas durante refactors do gerador.
- O design v2 depende de um tipo `VisualAnalysis` (≥16 descritores: histogramas, contrastes, `spatialEnergy`, balanços, `visualEntropy`, `fingerprint`) que hoje não existe no domínio. Introduzi-lo junto com o `generatorVersion` permite que os Incrementos 3–4 substituam o gerador sem nova migração de schema nem de domínio.
- O `MelodicContour` e o `TonalFamily` são enums de classificação que o design v2 referencia, mas que o pipeline atual não produz. Definir os enums (sem a lógica de classificação) nesta entrega remove um bloqueio estrutural para o Incremento 3.

## 3. Objetivos

1. Adicionar `generatorVersion: Int?` a `PhotoPedal` com o contrato completo de `§13` do design (decode tolerante, encode = `1` para novos pedais, preservação em `updatingMetadata`/`updating`, `PedalStore` tolerante).
2. Introduzir `VisualAnalysis` (subset definido em §6.1) e `VisualAnalyzer` (puro, `Sendable`, determinístico) reaproveitando o buffer 64×64 do `PhotoColorAnalyzer` (`PedalHeuristics.analysisSide = 64`), sem segunda passada completa sobre os pixels.
3. Introduzir `MusicalProfile` (struct `Sendable`/`Equatable`), `MelodicContour` (enum) e `TonalFamily` (enum) como tipos do domínio, sem wiring na geração de produção.
4. Manter a saída de produção **byte-idêntica** ao v1 para todo `generatorVersion == 1` (ou ausente).
5. Persistir e expor o `generatorVersion` em DEBUG via `PerformanceDiagnostics.event` (`generatorVersion`) e em `MusicalRunDiagnostics.algorithmVersion` (infraestrutura já existente do Incremento 1).

## 4. Não Objetivos

- Implementar a estratégia de root por `TonalFamilyWeights` (§10 do design) — Incremento 3.
- Implementar `seedFromFingerprint` (§12.2) e `subSeed` / `splitMix64` (§12.3) — Incremento 3.
- Implementar `pickScale`/`pickContour` com viés por `subSeed` — Incremento 3.
- Implementar o compositor v2 (motivo, syncopação, descansos, resolução) — Incremento 4.
- Migrar pedais existentes em massa ou recolorir capas — proibido por ADR 0002 e pelo design (§13.3/§13.4).
- Alterar a identidade cromática por pitch (`specs/current/pitch-color-identity.md`).
- Alterar o contrato de `dominantPitchClass` ou da capa persistida.
- Modificar testes existentes ou fixtures do Incremento 1 (`MusicalDiagnostics*`, `ProceduralCorpus`, `PhotoPedalStabilizationTests`).
- Introduzir Core ML, Vision embeddings, Foundation Models na geração musical ou novos tipos `PedalScale`.
- Regenerar pedais antigos ao recarregar a biblioteca.
- Expor `TonalFamily`/`MelodicContour`/`generatorVersion` na UI ou na acessibilidade nesta entrega (eles permanecem internos; o Incremento 3 e 4 decidem a exposição).

## 5. Escopo

### 5.1 Em escopo

- **Schema (`PhotoPedal`):** novo campo opcional `generatorVersion: Int?` com decodificação tolerante (ausente → `nil`, valor desconhecido preservado) e codificação que omite `nil`. O construtor explícito recebe `generatorVersion` com default `1` para a API de produção. `updatingMetadata` e `updating(effect:soundProfile:)` preservam `generatorVersion` sem sobrescrevê-lo.
- **Persistência:** `PhotoPedalPipeline.runEssential` grava `generatorVersion = 1` em todo novo pedal (o algoritmo em uso é v1). `PedalStore.validateMetadataUpdateTemporaryJSON` continua comparando apenas `id`/`createdAt`/`sequence`/`effect`/`coverFilename` (o `generatorVersion` é somente leitura na atualização de metadados); nenhuma outra mudança de validação é necessária porque o campo é `Int?` e o `JSONDecoder` sintetizado trata ausentes e desconhecidos. A migração de arquivos legados é automática: ausência do campo → `nil`, tratado como `1` em runtime.
- **Domínio (não persistido):** novos tipos `VisualAnalysis` (struct, §6.1), `VisualAnalyzer` (enum com função pura `analyze(_:)`), `MusicalProfile` (struct, §6.2), `MelodicContour` (enum), `TonalFamily` (enum). Nenhum desses tipos é `Codable` para o disco nesta entrega; eles vivem apenas no pipeline de produção (in-memory) e nos testes.
- **Pipeline de produção:** o `PhotoPedalPipeline` calcula `VisualAnalysis` (a partir do `PreparedImage`/`UIImage` já materializado pelo `ImageInputPreparer`) reaproveitando o buffer 64×64 que o `PhotoColorAnalyzer` já lê, sem segunda passada completa. O cálculo de `VisualAnalysis` é opcional na pipeline de Release (computado quando há `PerformanceDiagnostics` instrumentando); em Release puro, pode ser computado lazy ou omitido, desde que a saída de `PedalSequence` permaneça byte-idêntica. O `MusicalProfile` **não** é construído na pipeline de produção nesta entrega (seu builder completo depende de `seedFromFingerprint`/`subSeed`/`TonalFamilyWeights`, Incremento 3).
- **Observabilidade DEBUG:** `PerformanceDiagnostics.event("generatorVersion", ...)` reporta `1` (ou `nil` se chamado em caminho de decodificação pura) e `PerformanceDiagnostics.event("musicAnalysis", ...)` (§15.1 do design) emite os descritores disponíveis no Incremento 2: `side`, `fingerprint16`, `meanLuminance`, `luminanceContrast`, `edgeDensity`, `visualEntropy` (os campos `tonalFamily` e os histogramas de pitch são adiados para o Incremento 3). `MusicalRunDiagnostics.algorithmVersion` (§13.9 do design) passa a ser alimentado com o valor efetivamente usado na geração (sempre `1` nesta entrega); a infraestrutura do Incremento 1 já possui o campo.
- **Fixtures DEBUG:** `LibraryDebugFixtures.swift` (50/200/500 pedais sintéticos) é atualizado para criar `PhotoPedal` com `generatorVersion = 1` (e opcionalmente fixtures de teste com valores desconhecidos para cobrir a tolerância de decode). Nenhuma fixture passa a usar valores v2 nesta entrega.
- **Documentação:** `docs/DATA_MODEL.md` ganha o registro de `generatorVersion` no quadro de tipos e na seção "Serialization And Storage" (§13.5 do design); `docs/IMAGE_TO_MUSIC.md` deixa de afirmar "There is no `generatorVersion` in the current model" e passa a referenciar a presença do campo e a ausência de regeneração automática; `AGENTS.md` ganha a observação de que o `generatorVersion` é persistido a partir desta entrega (revogando a frase "no generator version exists yet"). `specs/README.md` **não** é atualizado nesta entrega (índice de specs não referencia a v2 no estado atual; tarefa de housekeeping fora do escopo).
- **Testes:** nova suíte `VersioningTests` (6 testes, §8), `VisualAnalysisDeterminismTests` (subset de §18.3 do design), `MusicalProfileInvariantTests` (§9.2 do design via construção direta), `V1EquivalenceTests` (estende `PhotoPedalStabilizationTests` provando que a pipeline produz `PedalSequence` byte-idêntica com/sem o cálculo de `VisualAnalysis` e com/sem o novo campo `generatorVersion`). Total previsto: ~20 testes novos.

### 5.2 Fora de escopo (adiado)

Listado explicitamente para evitar acoplamento entre incrementos:

- Classificação de `TonalFamily` a partir de `VisualAnalysis` (limiares `thresholdLow`/`thresholdHigh`/`varianceHigh`/`marginFloor`/`contrastLow` não fixados numericamente no design; dependem do baseline v2 — Incremento 3).
- `TonalFamilyWeights` (os valores de partida de §10.2 do design são pontos de partida; o Incremento 3 congela ou ajusta com base no baseline v2).
- `seedFromFingerprint` (§12.2) e `subSeed` / `splitMix64` (§12.3) e os `SeedDomain` tags.
- `pickRoot`/`pickScale`/`pickContour`/`pickBpm` consumindo seeds.
- O compositor v2 (motivo, syncopação, descansos, resolução, acordes) — Incremento 4.
- Exposição de `TonalFamily`/`MelodicContour`/`generatorVersion` na UI, acessibilidade, logs de Foundation Models, debug launcher.
- A/B DEBUG v1↔v2 lado a lado (§15.3 do design) — Incremento 3.
- Adição de novas `PedalScale` ou reintrodução de `ExtendedScale` — proibido pelo design (§10.12, §33 D7).
- Migração de `PedalStore` para além do decode tolerante automático.
- Validação subjetiva (corpus real 200+, protocolo §21) — Incremento 5.
- Inclusão de imagens licenciadas ou expansão do corpus procedural além dos 14 fixtures atuais.

## 6. Arquitetura Proposta

### 6.1 `VisualAnalysis` (struct, in-memory, não persistido)

```swift
struct VisualAnalysis: Sendable, Equatable {
    let colorProfile: PhotoColorProfile
    let fingerprint: String                          // SHA-256 hex 64 chars (já existe)
    let hueHistogram: [Double]                       // 12 bins, soma 1.0, ≥ 0
    let luminanceHistogram: [Double]                 // 8 bins, soma 1.0, ≥ 0
    let saturationHistogram: [Double]                // 4 bins, soma 1.0, ≥ 0
    let meanLuminance: Double                        // [0, 1]
    let meanSaturation: Double                       // [0, 1]
    let luminanceContrast: Double                    // desvio padrão, ≥ 0
    let edgeDensity: Double                          // já existe em PhotoColorProfile
    let spatialEnergy: (topLeft: Double, topRight: Double, bottomLeft: Double, bottomRight: Double)  // 4 quadrantes
    let verticalBalance: Double                      // razão superior / inferior, ≥ 0
    let horizontalBalance: Double                    // razão esquerda / direita, ≥ 0
    let subjectPresence: Double                      // 0.0 nesta entrega (placeholder, §7.1 do design)
    let visualEntropy: Double                        // H sobre luminanceHistogram, em bits, ≥ 0
}
```

Campos adiados para o Incremento 3: `isLowSaturation`, `isHighSaturation`, `isBright`, `isDark` (dependem de limiares ainda não fixados numericamente), `tonalFamily: TonalFamily`, `tonalFamilyWeights: TonalFamilyWeights`. A struct do Incremento 2 é, portanto, um **subset estrito** do §7.1 do design; os campos adiados serão adicionados no Incremento 3 sem migração (o tipo é in-memory, não `Codable`).

Invariantes da `VisualAnalysis` (verificadas por testes):

- `hueHistogram.count == 12`; soma em `[0.9999, 1.0001]` (tolerância 1e-4); cada bin `≥ 0`.
- `luminanceHistogram.count == 8`; soma em `[0.9999, 1.0001]`; cada bin `≥ 0`.
- `saturationHistogram.count == 4`; soma em `[0.9999, 1.0001]`; cada bin `≥ 0`.
- `meanLuminance ∈ [0, 1]`, `meanSaturation ∈ [0, 1]`.
- `luminanceContrast ≥ 0`.
- `visualEntropy ≥ 0` e `≤ log2(8) ≈ 3.0`.
- `subjectPresence == 0.0` (placeholder congelado nesta entrega).
- `fingerprint.count == 64` e todos os caracteres são hexadecimais minúsculos.

### 6.2 `VisualAnalyzer` (enum, função pura)

```swift
enum VisualAnalyzer {
    static func analyze(preparedImage: PreparedImage) -> VisualAnalysis
}
```

Regras:

- A função é **pura** e **`Sendable`**: mesma `PreparedImage` → mesma `VisualAnalysis` (sem `Date`, `UUID`, RNG).
- A função **reaproveita** o buffer 64×64 que o `PhotoColorAnalyzer.analyze(_:side:)` já lê, conforme §12.6 do design. A implementação é livre para fazer uma única passada sobre os pixels e emitir ambos os resultados (`PhotoColorProfile` + `VisualAnalysis`) — mas isso é um detalhe de implementação: o contrato observável é que o `totalPipeline` não aumenta em mais de 5 ms (§19.1 do design) e que a `VisualAnalysis` é determinística.
- `subjectPresence` é `0.0` por construção nesta entrega.
- A função **não** lê o `generatorVersion`; ela é independente do algoritmo de geração.

### 6.3 `MusicalProfile` (struct, in-memory, não persistido)

```swift
struct MusicalProfile: Sendable, Equatable {
    let rootPitchClass: PitchClass                   // 0...11
    let scale: PedalScale                            // enum atual, sem novos cases
    let register: ClosedRange<Int>                   // semitones acima do C0
    let density: Double                              // [0.10, 0.95]
    let syncopation: Double                          // [0, 1]
    let intervalRange: ClosedRange<Int>              // lowerBound ≥ 1, upperBound ≤ 24
    let repetitionFactor: Double                     // [0, 1]
    let tension: Double                              // [0, 1]
    let contour: MelodicContour                      // enum
    let bpm: Int                                     // [70, 140]
    let baseOctave: Int                              // 4 ou 5 (derivado)
    let timeSignatureSteps: Int                      // 16 fixo nesta entrega
    let generationSeed: UInt64                       // ver §9 desta spec
    let tonalFamily: TonalFamily                     // enum
}
```

Esta entrega **não** implementa o builder de `MusicalProfile` a partir de `VisualAnalysis` (§9.1 do design): esse builder depende de `seedFromFingerprint`/`subSeed` (Incremento 3) e de `TonalFamilyWeights`/`pickScale`/`pickContour` (Incremento 3). O tipo é introduzido agora com invariantes (§9.2 do design) e testes de construção direta, para que o Incremento 3 adicione o builder sem nova migração de domínio. O campo `generationSeed` está presente mas, na ausência do builder §9.1, é sempre `0` em qualquer `MusicalProfile` construída nesta entrega (ver §9).

Invariantes (verificadas por testes `MusicalProfileInvariantTests`, §8.4):

- `0 ≤ rootPitchClass.rawValue ≤ 11`.
- `scale` é um dos quatro `PedalScale` atuais.
- `register.lowerBound ≥ 0`; `register.upperBound ≤ 96`; `upperBound − lowerBound ≥ 12`.
- `density ∈ [0.10, 0.95]`; `syncopation ∈ [0, 1]`; `tension ∈ [0, 1]`; `repetitionFactor ∈ [0, 1]`.
- `intervalRange.lowerBound ≥ 1`; `intervalRange.upperBound ≤ 24`.
- `bpm ∈ [70, 140]`; `baseOctave ∈ {4, 5}`; `timeSignatureSteps == 16`.
- `generationSeed ∈ [0, UInt64.max]`; nesta entrega, sempre `0` (placeholder).
- `contour` é um caso válido de `MelodicContour`; `tonalFamily` é um caso válido de `TonalFamily`.

### 6.4 `MelodicContour` (enum, in-memory)

```swift
enum MelodicContour: String, Sendable, Equatable, Codable, CaseIterable {
    case ascending
    case descending
    case arched
    case stable
    case meandering
}
```

O enum é `Codable` apenas para uso em logs e serialização DEBUG (`MusicalRunDiagnostics`, Incremento 1 já existente); **não** é persistido no `PhotoPedal`. A ordem dos `case` é congelada e o `rawValue` é o nome do case (`String`); reordenar os `case` **quebra** serializações DEBUG existentes (regra alinhada ao §10.12 e à §33 D7 do design).

### 6.5 `TonalFamily` (enum, in-memory)

```swift
enum TonalFamily: String, Sendable, Equatable, Codable, CaseIterable {
    case warm
    case cool
    case green
    case purple
    case neutral
    case lowSaturation
    case highSaturation
}
```

Mesmas regras do `MelodicContour`: `Codable` para DEBUG, **não** persistido no `PhotoPedal`, ordem congelada. A classificação de `TonalFamily` a partir de `VisualAnalysis` (com limiares `thresholdLow`/`thresholdHigh`/etc.) é Incremento 3; nesta entrega, qualquer `MusicalProfile` construída tem `tonalFamily = .neutral` como placeholder, registrado por teste.

### 6.6 `PhotoPedal.generatorVersion`

```swift
struct PhotoPedal: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let sequence: PedalSequence
    let effect: PedalEffect
    let createdAt: Date
    let coverFilename: String
    let generatorVersion: Int?   // novo nesta entrega
}
```

Regras de codificação/decodificação:

- `Codable` sintetizado do Swift trata `Int?` ausente no JSON como `nil` na decodificação e omite `nil` na codificação (§13.10 do design). Nenhum `init(from:)` ou `encode(to:)` customizado é necessário.
- A API de produção expõe um inicializador com `generatorVersion: Int = 1` como default, de modo que `PhotoPedal(...)` no `PhotoPedalPipeline.runEssential` continue a compilar sem mudança e produza `generatorVersion == 1` por padrão. O inicializador `memberwise` sintetizado também fica disponível, recebendo `nil` para o caso de decodificação manual em testes.
- `updatingMetadata(name:description:)` e `updating(effect:soundProfile:)` preservam `generatorVersion` sem sobrescrevê-lo (ver §13.8 do design).
- `PedalStore.validateMetadataUpdateTemporaryJSON` continua comparando apenas `id`/`createdAt`/`sequence`/`effect`/`coverFilename`; o `generatorVersion` é somente leitura em updates de metadados (§13.5 do design). Nenhuma modificação de validação é necessária.

## 7. Contratos de Dados

### 7.1 Persistência

| Campo | Tipo | Origem | Default | Observações |
| --- | --- | --- | --- | --- |
| `id` | `UUID` | pipeline | novo a cada save | inalterado |
| `name` | `String` | pipeline (fallback ou FM) | fallback `"Photo Pedal"` | inalterado |
| `description` | `String` | pipeline (fallback ou FM) | fallback | inalterado |
| `sequence` | `PedalSequence` | pipeline | — | inalterado, byte-idêntico ao v1 |
| `effect` | `PedalEffect` | pipeline | `.reverb` | inalterado |
| `createdAt` | `Date` | pipeline | `.now` | inalterado |
| `coverFilename` | `String` | pipeline | `"latest-pedal.png"` | inalterado |
| `generatorVersion` | `Int?` | **novo** | `1` na API de produção; `nil` se ausente no JSON | opcional, decode tolerante, encode omite `nil` |

Compatibilidade com `PhotoPedal` legados (sem o campo):

- Decodificação: `JSONDecoder` sintetizado → `generatorVersion == nil`. Em runtime, qualquer código que consome `PhotoPedal` trata `nil` como `1` (§13.2 do design).
- Recodificação: `JSONEncoder` sintetizado omite o campo quando o valor é `nil`, preservando a forma original do JSON legado. Nenhuma migração destrutiva (§13.3/§13.4 do design).
- Codificação de novos pedais: o `PhotoPedalPipeline.runEssential` constrói `PhotoPedal` com `generatorVersion = 1` (o algoritmo em uso é v1). O valor `2` só passa a ser gravado no Incremento 3, quando a geração v2 é ativada (regra alinhada à §13.2 do design: "gerar um novo pedal: gravar `generatorVersion = 2` no JSON" — explicitamente adiada para o Incremento 3).

### 7.2 Domínio (in-memory)

| Tipo | Categoria | Persistido? | Incremento que adiciona o builder |
| --- | --- | --- | --- |
| `VisualAnalysis` | struct | não | 2 (analyzer) → 3 (campos adicionais) |
| `VisualAnalyzer` | enum (puro) | não | 2 |
| `MusicalProfile` | struct | não | 2 (tipo) → 3 (builder via §9.1 do design) |
| `MelodicContour` | enum | não | 2 (enum) → 3 (classificação) |
| `TonalFamily` | enum | não | 2 (enum) → 3 (classificação e `TonalFamilyWeights`) |

## 8. Contratos de Determinismo

### 8.1 Determinismo da `VisualAnalysis`

Para qualquer `PreparedImage` idêntica (mesmo `image`, `originalSize`, `processedSize`, `fingerprint`), a `VisualAnalyzer.analyze(preparedImage:)` produz `VisualAnalysis` byte-equivalente em todas as execuções, plataformas (Simulator iPhone 17 Pro iOS 26.5 arm64 e CI x86_64) e ordens de chamada. Sem `Date`, `UUID`, `Int.random`, `Double.random`, `SystemRandomNumberGenerator`, `arc4random`, `Swift.Hasher`/`hashValue`, iteração não ordenada de `Dictionary`/`Set` (§12.4 do design). O cálculo de histogramas usa índice explícito em `Array` de tamanho fixo.

### 8.2 Determinismo da geração musical

A geração musical **não muda** nesta entrega. O `ImageSequenceGenerator.makeSequence` é chamado com os mesmos argumentos (`retroImage`, `colorProfile`) e produz `PedalSequence` byte-idêntico. O `generatorVersion` é metadado, não influencia a geração. `MusicalRunDiagnostics.algorithmVersion == 1` para todo pedal gerado nesta entrega.

### 8.3 Determinismo do `MusicalProfile`

Como o builder de `MusicalProfile` (§9.1 do design) **não** é implementado nesta entrega, qualquer `MusicalProfile` construída em testes ou DEBUG usa inicializadores diretos e é determinística por construção. O `generationSeed` é sempre `0` (placeholder); a exaustão do espaço de seeds é Incremento 3.

## 9. Estratégia de Seed e Sub-Seeds

Esta entrega **não** utiliza o contrato de seed (`seed64`, `splitMix64`, `subSeed`, `SeedDomain`) definido em §12 do design. O `MusicalProfile.generationSeed` é introduzido como `UInt64` com placeholder `0`; ele só será populado pelo builder do Incremento 3, que consome `seedFromFingerprint(analysis.fingerprint)` (§12.2) e `subSeed(seed, .root|.scale|.rhythm|.contour|.motif)` (§12.3).

A infraestrutura de seed (`SeedContractTests`, `seed64`/`splitMix64`/`subSeed`/`SeedDomain.tag`) pertence ao Incremento 3 e é explicitamente listada em §5.2.

## 10. Compatibilidade com a Geração v1

- `PhotoPedalPipeline.runEssential` continua chamando `ImageSequenceGenerator.makeSequence(retroImage:colorProfile:)` com os mesmos argumentos; nenhuma mudança no caminho de produção. O cálculo de `VisualAnalysis` é **aditivo** e não influencia `PedalSequence`/`PedalHarmony`/`PedalNote`/`PedalSoundProfile`.
- O novo campo `PhotoPedal.generatorVersion` é gravado como `1` (não `nil`).
- A capa persistida é idêntica (mesma `dominantPitchClass`, mesma `PitchColorIdentity.tonalPalette`, mesmo `RetroImageProcessor.recolor`).
- A reprodução de pedais antigos é literal (ADR 0002): `PedalSequence` persistido é tocado do storage, sem regeneração.

## 11. Compatibilidade com Persistência

- `PedalStore` não exige mudança de validação: o decode do `PhotoPedal` aceita o campo ausente e o encode omite `nil` automaticamente. `validateMetadataUpdateTemporaryJSON` continua verificando apenas `id`/`createdAt`/`sequence`/`effect`/`coverFilename` (§13.5 do design); a igualdade de `generatorVersion` é mantida implicitamente porque `updatingMetadata`/`updating` preservam o valor.
- Não há migração em massa (§13.4 do design). Não há recoloração de capas (§13.11 do design).
- `library/gallery` continua carregando sem mudança de comportamento.
- `PedalboardStore` não é afetado (não consome `PhotoPedal.generatorVersion`).
- Foundation Models continua restrito a metadados semânticos; nenhuma parte desta entrega altera `FoundationModelsPedalGenerator`, `VisionObjectAnalyzer`, `SubjectExtractionService` ou seus consumidores.

## 12. Comportamento de `generatorVersion`

Tabela de execução (reproduzindo §13.2 do design para referência de runtime):

| Origem do `generatorVersion` | Tratamento |
| --- | --- |
| Ausente no JSON | decodifica como `nil`; em runtime, tratado como `1` |
| `1` no JSON | decodifica como `1`; sequencia reproduzida literalmente |
| `2` no JSON (futuro) | decodifica como `2`; sequencia reproduzida literalmente (Incremento 3+) |
| Valor desconhecido (e.g., `3`, `99`, `-1`) no JSON | decodifica como o valor literal; em runtime, sequencia reproduzida literalmente; nunca regenera |
| Novo pedal gerado nesta entrega | escrito como `1` (algoritmo v1 em uso) |
| Novo pedal gerado no Incremento 3+ | escrito como `2` (quando a v2 for ativada) |

Regras operacionais:

- O `PhotoPedal` carregado nunca é regenerado em runtime. Pedais antigos (sem campo) são reproduzidos a partir da `PedalSequence` persistida; pedais novos são gerados pelo algoritmo ativo no momento do save.
- `MusicalRunDiagnostics.algorithmVersion` reflete o valor usado durante a geração (sempre `1` nesta entrega).
- `PerformanceDiagnostics.event("generatorVersion", ...)` (§13.9 do design) emite o valor inteiro ou a string `nil` para diagnóstico.

## 13. Critérios de Aceite

A entrega é aceitável quando **todas** as condições abaixo forem verdadeiras:

1. `PhotoPedal` ganha o campo `generatorVersion: Int?`; novos pedais gravam `1`; pedais legados decodificam com `nil`; recodificação de pedal legado omite o campo.
2. Decodificação tolerante: `JSONDecoder` aceita `generatorVersion = nil`, `1`, `2`, `99`, `-1` sem erro; valores desconhecidos são preservados literalmente.
3. `updatingMetadata(name:description:)` e `updating(effect:soundProfile:)` preservam `generatorVersion` sem sobrescrevê-lo.
4. A geração de `PedalSequence` é byte-idêntica ao v1 para qualquer `PreparedImage` e qualquer `PhotoColorProfile` (provado por `V1EquivalenceTests` que comparam o JSON de `PedalSequence` pré e pós-entrega).
5. `VisualAnalyzer.analyze(preparedImage:)` produz `VisualAnalysis` determinística para a mesma `PreparedImage` em múltiplas execuções e plataformas.
6. Invariantes de `VisualAnalysis` (§6.1) e `MusicalProfile` (§6.3) são verificadas por testes unitários.
7. `MelodicContour` e `TonalFamily` existem como enums com todos os casos do design; ordem dos casos congelada; `Codable` para DEBUG.
8. `MusicalRunDiagnostics.algorithmVersion == 1` para todo `MusicalRunDiagnostics` produzido nesta entrega (via harness do Incremento 1).
9. `PerformanceDiagnostics.event("generatorVersion", ...)` é emitido durante o pipeline essencial com o valor `1` (verificável em teste que inspeciona o sink DEBUG).
10. `xcodebuild test -configuration Debug` passa (suíte completa, incluindo a suíte v1 atual e os novos testes do Incremento 2); `xcodebuild -configuration Release build` passa; `git diff --check` permanece limpo.
11. Nenhum `.swift` de produção fora dos arquivos listados em §14 é modificado, exceto pelas inserções aditivas (novo campo, novos tipos, novo evento DEBUG) sem mudança de comportamento do código v1.
12. `project.pbxproj` não é alterado (uso de `PBXFileSystemSynchronizedRootGroup` para o target principal; novos arquivos `.swift` são descobertos automaticamente).

## 14. Arquivos e Componentes Provavelmente Envolvidos

Produção:

- `snap-battle/Domain/Pedal/Pedal.swift` — adicionar `generatorVersion: Int?` a `PhotoPedal`; ajustar `updating`/`updatingMetadata` para preservar o campo; adicionar inicializador público com default.
- `snap-battle/Domain/Pedal/VisualAnalysis.swift` (novo) — struct `VisualAnalysis` (§6.1).
- `snap-battle/Domain/Pedal/VisualAnalyzer.swift` (novo) — enum `VisualAnalyzer` com `analyze(preparedImage:)` (§6.2).
- `snap-battle/Domain/Pedal/MusicalProfile.swift` (novo) — struct `MusicalProfile` (§6.3) e helpers de invariantes.
- `snap-battle/Domain/Pedal/MelodicContour.swift` (novo) — enum `MelodicContour` (§6.4).
- `snap-battle/Domain/Pedal/TonalFamily.swift` (novo) — enum `TonalFamily` (§6.5).
- `snap-battle/Services/Pedal/PhotoColorAnalyzer.swift` — possivelmente estendido para emitir `VisualAnalysis` no mesmo loop, ou `VisualAnalyzer` separado que consome o mesmo `PreparedImage`; decisão de implementação livre desde que a saída de `PhotoColorProfile` permaneça byte-idêntica e o total de passadas sobre o buffer não exceda 2 (1 para o perfil, 1 para a análise estendida, com reuso de buffers).
- `snap-battle/Services/Pedal/PhotoPedalPipeline.swift` — calcular `VisualAnalysis` no caminho de produção (ou em hook DEBUG-only); emitir `PerformanceDiagnostics.event("generatorVersion", ...)` e `PerformanceDiagnostics.event("musicAnalysis", ...)`; passar `generatorVersion: 1` ao construir `PhotoPedal`.
- `snap-battle/Services/Pedal/PedalHeuristics.swift` — sem mudança obrigatória nesta entrega; qualquer nova constante necessária para o cálculo de histogramas (e.g., número de bins) é adicionada aqui com valores explícitos.
- `snap-battle/Services/Persistence/PedalStore.swift` — sem mudança obrigatória; o decode tolerante é automático via `Codable` sintetizado. A spec exige a verificação explícita de que `validateMetadataUpdateTemporaryJSON` continua funcionando sem alteração (§13.5 do design).
- `snap-battle/Features/Library/Debug/LibraryDebugFixtures.swift` — fixtures de pedais sintéticos passam a incluir `generatorVersion = 1`; opcionalmente, fixtures com valores desconhecidos para teste de decode tolerante.
- `snap-battle/Services/Debug/MusicDiagnostics/MusicalRunDiagnostics.swift` — o campo `algorithmVersion` já existe (Incremento 1); verificar que é alimentado com `1` pela pipeline.

Testes (novo alvo `snap-battleTests/`):

- `snap-battleTests/VersioningTests.swift` (novo) — 6 testes do contrato `generatorVersion` (§8 do design, §13.10).
- `snap-battleTests/VisualAnalysisDeterminismTests.swift` (novo) — determinismo, histogramas normalizados, invariantes da struct, reuso de buffer (medição de tempo opcional).
- `snap-battleTests/MusicalProfileInvariantTests.swift` (novo) — invariantes via construção direta.
- `snap-battleTests/V1EquivalenceTests.swift` (novo) — extensão de `PhotoPedalStabilizationTests`: pipeline produz `PedalSequence` byte-idêntica com/sem cálculo de `VisualAnalysis`; presença/ausência de `generatorVersion` no JSON não altera `PedalSequence`.
- `snap-battleTests/PhotoPedalStampingTests.swift` (novo) — `updatingMetadata`/`updating` preservam `generatorVersion`; recodificação de pedal legado omite o campo; decode tolerante de `nil`/`1`/`2`/`99`/`-1`.

Documentação:

- `docs/DATA_MODEL.md` — adicionar `generatorVersion` à tabela de tipos e à seção "Serialization And Storage" (§13.5 do design).
- `docs/IMAGE_TO_MUSIC.md` — atualizar "Determinism Boundaries / Not Guaranteed By This Contract" para remover a frase "There is no `generatorVersion` in the current model" e referenciar a presença do campo.
- `AGENTS.md` — atualizar o invariante "no generator version exists yet" para refletir que o `generatorVersion` é persistido a partir do Incremento 2 e nunca dispara regeneração automática.

## 15. Estratégia de Testes

### 15.1 Suíte nova (nesta entrega)

| Suíte | Nº aprox. de testes | Cobertura |
| --- | --- | --- |
| `VersioningTests` | 6 | §13.10 do design: decode de ausente/`nil`/`1`/`2`/`99`/`-1`; encode de `1`; recodificação de legado omite o campo; `updatingMetadata` preserva; `updating(effect:soundProfile:)` preserva. |
| `VisualAnalysisDeterminismTests` | 8 | mesma `PreparedImage` → mesma `VisualAnalysis` em N execuções; histogramas normalizados (12/8/4 bins, soma 1.0, ≥ 0); invariantes da struct; `subjectPresence == 0.0`; `visualEntropy` em `[0, log2(8)]`; `fingerprint` é hex de 64 chars. |
| `MusicalProfileInvariantTests` | 4 | invariantes da `MusicalProfile` (§6.3, §9.2 do design) via construção direta; `generationSeed == 0` como placeholder. |
| `V1EquivalenceTests` | 4 | pipeline produz `PedalSequence` byte-idêntica com/sem `VisualAnalysis` calculado; presença/ausência de `generatorVersion` no JSON não altera `PedalSequence`; capa persistida idêntica; `dominantPitchClass` inalterada. |
| `PhotoPedalStampingTests` | 2 | `updatingMetadata` e `updating` preservam `generatorVersion`; recodificação de pedal legado omite o campo. |

Total previsto: ~24 testes novos. Estes testes **não** substituem a suíte do Incremento 3 (`SeedContractTests`, `VisualAnalysisTests` completos, `RootAndScaleStrategyTests`, `CompositionTests`, `ABComparisonTests`, `DistributionTests`, `CompatibilityTests`) — apenas entregam a fatia compatível com esta entrega.

### 15.2 Testes de regressão v1 (existentes, devem passar inalterados)

Toda a suíte atual do Incremento 1 e anteriores deve continuar passando sem modificação:

- `PhotoPedalStabilizationTests` (`identicalNormalizedInputProducesEqualMusicalData`, `boundaryPreparationPreservesColorCoverAndSequence`, `gridLevelsProduceCurrentRestsAndVelocitiesInOrder`, `sequenceBoundsThresholdsAndSoundProfileRemainCurrent`).
- `DominantPitchClassResolverTests`.
- `PitchClassDomainTests`.
- `MusicalDiagnosticsEquivalenceTests`, `MusicalDiagnosticsCalculatorTests`, `MusicalCorpusReportTests`, `ProceduralCorpusTests`.
- `CreatureAuditTests` (legado).
- Demais testes do alvo.

Nenhum teste existente é modificado nesta entrega. Se um teste existente precisar de ajuste (e.g., para incluir `generatorVersion` em asserções), isso é registrado como risco e exige uma spec própria.

### 15.3 Testes determinísticos / golden

Esta entrega **não** introduz golden tests de `PedalSequence` (esses são Incremento 3, §18.1 do design). Os "testes determinísticos" desta entrega são:

- `VisualAnalysisDeterminismTests`: `VisualAnalysis` byte-equivalente em N execuções para a mesma `PreparedImage` (comparação `Equatable` e/ou SHA-256 de `JSONEncoder` ordenado).
- `V1EquivalenceTests`: `PedalSequence` JSON byte-equivalente pré e pós-cálculo de `VisualAnalysis` e pré e pós-adição de `generatorVersion` ao `PhotoPedal`.

## 16. Performance

Orçamento de latência adicionado pela `VisualAnalysis` (orçamento do design, §19.1):

- `visualAnalysis` (estendido): ≤ 5 ms adicionais para imagens 4032×3024, na média de 5 execuções no Simulator iPhone 17 Pro iOS 26.5 arm64.
- `totalPipeline`: não aumentar em mais de 8 ms para imagens 4032×3024.

A spec **não** introduz testes de tempo absoluto em CI (esses são flaky). O orçamento é validado por medição manual em Release após o merge, registrada em comentário do PR e em `docs/IMAGE_TO_MUSIC.md` (seção "Determinism Boundaries"). A infra DEBUG do Incremento 1 (`PerformanceDiagnostics.measure` + `MusicalRunDiagnostics.diagnosticsCalculationDuration`) já cobre o ponto de medição.

## 17. Observabilidade DEBUG

Novos eventos adicionados a `PerformanceDiagnostics` (todos `#if DEBUG`):

- `PerformanceDiagnostics.event("generatorVersion", runID:, details: "value=1")` — emitido em `runEssential` após a geração de `PhotoPedal`.
- `PerformanceDiagnostics.event("musicAnalysis", runID:, details: "side=64 fingerprint16=... meanLuminance=... luminanceContrast=... edgeDensity=... visualEntropy=...")` — emitido quando `VisualAnalysis` é calculada. O campo `tonalFamily` é omitido nesta entrega (adicionado no Incremento 3).
- `PerformanceDiagnostics.event("visualAnalysisDuration", runID:, details: "durationMs=...")` — emitido opcionalmente para medição de orçamento.

`MusicalRunDiagnostics.algorithmVersion` já existe (Incremento 1). A pipeline passa a alimentá-lo com `1` para todo pedal gerado nesta entrega; nenhum outro campo de `MusicalRunDiagnostics` é alterado.

Nenhuma mudança no harness do Incremento 1 (`MusicalDiagnosticsHarness`, `LibraryDebugLauncher` "Executar baseline e exportar JSON"); a baseline v1 continua reprodutível e seus relatórios JSON permanecem byte-idênticos.

## 18. Riscos

| Risco | Mitigação |
| --- | --- |
| O cálculo de `VisualAnalysis` aumenta o `totalPipeline` além do orçamento | Reuso obrigatório do buffer 64×64 (§12.6 do design); medição em Release antes do merge; se exceder, fallback em Release para cálculo lazy/omitido (§5.1 desta spec) — saída de `PedalSequence` permanece byte-idêntica. |
| Reordenar `case` de `MelodicContour` ou `TonalFamily` quebra serializações DEBUG existentes (raw value) | Ordem congelada por testes de `rawValue` literal e por `CodingKey` determinístico; mudanças de ordem exigem spec própria (§33 D7 do design). |
| Código de produção v1 referencia `MusicalProfile`/`VisualAnalysis` antes da entrega | Os tipos são introduzidos no mesmo PR, em arquivos novos; nenhum consumidor v1 é alterado para usá-los nesta entrega. |
| `JSONDecoder` não trata `Int?` ausente como `nil` em alguma versão do Swift/iOS | Coberto por teste explícito (`VersioningTests`); o comportamento é parte do contrato de `Codable` sintetizado. |
| `PedalStore` precisa de mudança não antecipada para tolerar o campo | `PedalStore.validateMetadataUpdateTemporaryJSON` é verificada explicitamente por `V1EquivalenceTests`; nenhuma modificação é feita no validator. |
| Adicionar `generatorVersion` quebra algum teste existente que serializa `PhotoPedal` para comparação byte-a-byte | Coberto por `MusicalDiagnosticsEquivalenceTests` (já existente) e `V1EquivalenceTests`; nenhum teste existente é modificado. |
| Fixture DEBUG legada (`LibraryDebugFixtures`) não cobre o novo campo | Atualização mínima das fixtures (§14); adição opcional de fixture com valor desconhecido para teste de decode. |
| O placeholder `generationSeed == 0` é confundido com seed real em logging | Documentação no `MusicalProfile` e em teste explícito: `assertEqual(0)` na suíte de invariantes; comentário no código. |

## 19. Plano de Rollback

Reverter esta entrega é um `git revert` do PR do Incremento 2. Os pedais gerados com `generatorVersion = 1` permanecem válidos após o revert, porque o `PhotoPedal` legado **aceita o campo ausente** (`generatorVersion: nil` é tratado como `1` em runtime). Não há migração destrutiva nem mudança de schema obrigatória após o revert.

Critério de rollback:

- Se um teste de regressão v1 falhar após o merge e a causa raiz for esta entrega (e não puder ser corrigida com um patch trivial), o PR é revertido. A baseline v1 é referência para comparar o estado musical pré e pós-entrega.
- Se o orçamento de latência for excedido em Release no dispositivo físico de validação, o cálculo de `VisualAnalysis` é tornado opcional (lazy/omitido em Release) sem rollback do PR.

## 20. Dependências

- **Design v2:** `specs/current/photo-midi-variety-v2.md` (autoridade para contratos de `generatorVersion`, `VisualAnalysis`, `MusicalProfile`, `MelodicContour`, `TonalFamily`).
- **ADRs:** 0001 (geração local determinística), 0002 (persistência literal dos resultados gerados).
- **Spec de identidade cromática:** `specs/current/pitch-color-identity.md` (garante que `dominantPitchClass` continua sendo derivada da sequência e a paleta é única por pitch class).
- **Infraestrutura Incremento 1:** `snap-battle/Services/Debug/MusicDiagnostics/` (`MusicalRunDiagnostics`, `MusicalDiagnosticsHarness`, `ProceduralCorpus`) já em `origin/main` desde o squash `2bd84b8`.
- **`ImageInputPreparer`:** `fingerprint(of:runID:)` produz o `String` hex de 64 chars consumido por `VisualAnalysis.fingerprint` e, no Incremento 3, por `seedFromFingerprint`.

## 21. Itens Explicitamente Adiados

Listados aqui para que Incrementos futuros saibam o que **não** esperar desta entrega:

- `TonalFamilyWeights` (valores de §10.2 do design são pontos de partida; o Incremento 3 calibra).
- Classificação de `TonalFamily` (limiares `thresholdLow`/`thresholdHigh`/`varianceHigh`/`marginFloor`/`contrastLow`).
- Flags `isLowSaturation`/`isHighSaturation`/`isBright`/`isDark` em `VisualAnalysis` (dependem dos mesmos limiares).
- `seedFromFingerprint` (§12.2 do design).
- `splitMix64` e `subSeed` (§12.3 do design).
- `SeedDomain` com `tag` fixo (§12.3 do design).
- `pickRoot` com `TonalFamilyWeights` (§10.4 do design).
- `pickScale`/`pickContour`/`pickBpm` consumindo seeds (§10.11, §33 D3 do design).
- Compositor v2 (motivo, syncopação, descansos, resolução, acordes — §11 do design).
- Gravação de `generatorVersion = 2` em novos pedais (somente Incremento 3, quando a geração v2 for ativada).
- A/B DEBUG v1↔v2 lado a lado (§15.3 do design).
- Exposição de `TonalFamily`/`MelodicContour`/`generatorVersion` na UI, acessibilidade, logs de Foundation Models, debug launcher.
- Suíte de testes do Incremento 3: `SeedContractTests`, `VisualAnalysisTests` (completos), `MusicalProfileTests` (com `pickRoot`/`pickScale`/`pickContour`), `RootAndScaleStrategyTests`, `CompositionTests`, `ABComparisonTests`, `DistributionTests`, `CompatibilityTests` (§18.8 do design).
- Golden tests de `PedalSequence` (§18.1/§18.2 do design).
- Corpus real 200+ imagens, validação subjetiva, baseline v2 (Incrementos 3 e 5).
- Adição de novas `PedalScale`, reintrodução de `ExtendedScale` (§10.12, §33 D7 do design).
- Core ML (§26, §33 D8 do design).
