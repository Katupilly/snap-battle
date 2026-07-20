# Pitch Color Identity

Status: Ready
Last updated: 2026-07-19
Feature: Identidade cromática por nota predominante
Platform: iOS 26+
Framework: SwiftUI

## Context

- A capa atual usa uma paleta retrô fixa (`RetroImageConfiguration.fourToneRetro`) e não comunica uma propriedade musical do pedal.
- Cada pedal já possui sequência musical determinística persistida em `PhotoPedal.sequence`.
- Biblioteca, detalhe, picker e pedalboard consomem a capa persistida e se beneficiam de leitura musical-visual mais rápida antes de organizar Jam/pedalboards.
- Foundation Models continua restrito a metadados semânticos; não deve controlar sequência, harmonia ou perfil sonoro.

## Objective

Aplicar uma transformação determinística única:

`sequência persistida -> pitch class predominante -> cor fixa -> paleta tonal da capa`

Sem classificar combinações musicais como certas/erradas.

## Non-goals

Esta etapa não inclui:

- Game Center;
- multiplayer;
- sincronização de sessões/Jam;
- recomendações harmônicas avançadas;
- bloqueio de combinações;
- análise completa de acordes;
- determinação de tonalidade maior/menor global;
- redesign geral da Jam;
- edição manual de cor;
- seletor de escala;
- mudanças arbitrárias no algoritmo musical;
- migração ampla sem necessidade comprovada.

## Domain model

Introduzir um tipo seguro para pitch classes em um módulo/arquivo semântico de música (por exemplo `Domain/Music/PitchClass.swift`), não acoplado a SwiftUI:

```swift
enum PitchClass: Int, Codable, CaseIterable, Sendable {
    case c = 0
    case cSharp
    case d
    case dSharp
    case e
    case f
    case fSharp
    case g
    case gSharp
    case a
    case aSharp
    case b
}
```

Regras do tipo:

- semântica musical permanece cromática por semitons (`C = 0 ... B = 11`);
- conversão segura de MIDI e inteiros externos para pitch class;
- suporte a normalização de valores negativos via módulo matemático;
- apresentação textual e acessível centralizada no domínio (`symbol`, nome localizado e nome acessível), evitando duplicação de regras na UI.

## Ordering contract (musical vs color)

A spec estabelece explicitamente duas ordens distintas:

1. **ordem cromática musical** (enum/rawValue): `C, C♯, D, ... B` (`0...11`);
2. **ordem perceptual de cores** (inspirada no círculo de quintas) usada apenas para organização visual do mapeamento.

A ordem perceptual de cores **não** altera semântica MIDI nem raw values do domínio musical.

## Predominant pitch-class rule

### Sequência observada na implementação

- `PedalSequence.notes` contém eventos individuais (`PedalNote`) com `midiNote`.
- rests/silêncios são ausência de evento.
- duração por nota não está modelada no domínio atual.
- acordes aparecem como múltiplos `PedalNote` no mesmo step.

### Regra aprovada

1. Consumir notas na ordem temporal canônica do domínio (estável).
2. Ignorar rests (ausência de nota).
3. Converter cada `midiNote` para `PitchClass` com módulo 12.
4. Contar cada nota individualmente (acordes contam nota a nota).
5. Selecionar a pitch class de maior incidência.
6. Em empate, selecionar a empatada com primeira ocorrência temporal mais cedo.
7. Se não houver notas, usar `PedalHarmony.rootPitchClass`.
8. Se esse valor estiver inválido/indisponível, fallback final `.c`.

Não usar aleatoriedade, velocity, média de cor da foto ou peso por duração nesta feature.

## Color identity mapping

Criar uma única fonte de verdade no domínio/serviço de música para:

`PitchClass -> PitchColorIdentity`

Requisitos:

- exatamente 12 entradas;
- valores sRGB explícitos, estáveis e testáveis;
- sem dependência de tema/sistema;
- sem dependência de `SwiftUI.Color`/`UIColor` no domínio puro.

Representação sugerida:

```swift
struct SRGBColor: Equatable, Sendable, Codable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}
```

A organização visual das 12 cores deve ser inspirada no círculo de quintas para sugerir proximidade harmônica, mantendo distinção clara entre notas e sem promessas de compatibilidade musical.

## Tonal palette for cover

A cor base da pitch class não deve virar overlay uniforme.

Gerar uma paleta tonal de quatro níveis:

- `shadow`
- `dark`
- `base`
- `highlight`

Preservar:

- estética retrô/posterizada;
- dithering existente;
- silhueta e legibilidade da foto;
- alpha;
- orientação;
- determinismo.

## Image pipeline integration

Não criar segundo pipeline visual.

A adaptação ocorre no pipeline atual (`RetroImageProcessor`), trocando a paleta fixa por paleta derivada da pitch class predominante do próprio pedal.

Não usar recoloração tardia por SwiftUI runtime para substituir a fonte de verdade persistida.

## Calculation timing

A pitch class predominante deve ser calculada a partir da sequência já gerada no fluxo, antes da versão final da capa colorida.

Não executar o gerador musical duas vezes para descobrir cor.

## Persistence and compatibility

Decisão desta etapa: **não persistir `dominantPitchClass` em `PhotoPedal`**.

Ela será derivada da sequência persistida.

Consequências:

- sem mudança obrigatória de schema do JSON;
- sem aumento de versão de documento por esta feature;
- pedais existentes continuam carregando;
- fallback determinístico para dados inválidos;
- nenhuma migração destrutiva.

### Existing pedals

- pedais/capas antigas permanecem válidos e carregáveis;
- capas novas passam a usar identidade cromática imediatamente;
- não iniciar regeneração em massa no reload da biblioteca;
- eventual regeneração incremental futura exige operação segura e autorizada por spec.

## Physical device validation

Validação física em dispositivo real confirmou o fluxo essencial da feature com imagens reais de diferentes dimensões e orientações, incluindo `4032 x 3024`, `1179 x 2556`, `2688 x 4032`, `3088 x 2316` e `5712 x 4284`.

Foram observadas capas geradas com pitch classes distintas, incluindo `C`, `C♯`, `F`, `G` e `B`. O fluxo essencial concluiu fingerprint, preparação da imagem, processamento retrô, análise de cor, geração da sequência, recolor baseado em pitch, criação do resultado essencial, persistência, apresentação do resultado e reload da galeria.

Tempos observados para o pipeline essencial completo incluíram aproximadamente `122.9 ms`, `134.9 ms`, `179.3 ms`, `310.4 ms`, `325.6 ms`, `376.5 ms` e `472.5 ms`. Esses valores são evidência observacional de execução física, não benchmark formal nem promessa de desempenho.

A persistência de pedais individuais concluiu corretamente, geralmente em aproximadamente `10-14 ms` no primeiro save do fluxo e `4-8 ms` em várias escritas subsequentes observadas. PNGs e JSONs foram gravados, capas reapareceram após reload, e reloads observados reportaram `issues=0`, `missingArtwork=0`, `malformedDocuments=0` e `unreadableStorage=0` enquanto a coleção cresceu de 6 até 13 pedais.

Mensagens de framework/sistema como `FigXPCUtilities`, `FigCaptureSourceRemote`, `MADService Client XPC connection invalidated`, `LaunchServices` e `Visual isTranslatable: NO` foram observadas durante captura/picker/execução DEBUG, mas não bloquearam o fluxo essencial de pitch-color e não têm evidência de regressão causada por esta branch.

`semanticEnrichmentFailed details=reason=semanticStage` foi observado em execuções físicas após o resultado essencial já estar criado, persistido e apresentado. A etapa semântica é progressiva e independente da sequência determinística, do cálculo de pitch e do recolor; a falha não impede salvar, reabrir ou usar o pedal. Investigação de disponibilidade/qualidade da etapa semântica fica como dívida separada.

## Affected surfaces

Consumidores reais mapeados:

- `Features/Library/LibraryGridView`
- `Features/Gallery/PedalDetailView`
- `Features/Pedal/PedalResultView`
- `Features/Pedalboard/PedalPickerView`
- `Features/Pedalboard/PedalboardDetailView`
- fixtures/debug (`Features/Library/Debug/*`)
- thumbnails (`Services/ImageLoading/ThumbnailLoader` e uso via store/view models)

## Accessibility requirements

A nota não pode ser comunicada somente por cor:

- expor nome acessível da pitch class;
- incluir texto/badge onde fizer sentido (principalmente detalhe/seleção), sem poluir todas as miniaturas;
- manter contraste legível para conteúdos sobrepostos;
- suportar VoiceOver, Increase Contrast e Differentiate Without Color;
- preservar comportamento existente de Reduce Motion.

## Testing requirements

### Predominant note

- nota única;
- mesma pitch class em oitavas diferentes;
- sequência com rests;
- acorde com múltiplas notas;
- frequência majoritária;
- empate simples e entre 3+ pitch classes;
- empate em notas simultâneas com ordenação canônica determinística;
- sequência vazia;
- estabilidade entre execuções;
- cobertura de todas as 12 pitch classes.

### PitchClass domain

- normalização de MIDI em pelo menos duas oitavas completas;
- normalização de valores negativos;
- enumeração cromática preservada (`rawValue 0...11`);
- ordem perceptual de cores não altera semântica MIDI.

### Color mapping

- cada pitch class tem exatamente uma identidade cromática;
- valores estáveis;
- fallback determinístico;
- paleta tonal com contraste tonal mínimo razoável;
- domínio cromático sem import de SwiftUI no target de domínio, quando aplicável.

### Visual processing

- mesma entrada + mesma pitch class => mesmo resultado;
- pitch classes diferentes => paletas diferentes;
- dimensões, alpha e orientação preservados;
- cancelamento preservado;
- equivalência do pipeline fora da mudança intencional de paleta.

### Persistence/library compatibility

- documento antigo continua decodificando;
- round-trip de documento atual;
- fallback para campos ausentes/inválidos;
- biblioteca não dispara regeneração síncrona em massa.

## Acceptance criteria

- [ ] Existe tipo seguro `PitchClass` para 12 classes cromáticas.
- [ ] Regra de dominante segue incidência com desempate por primeira ocorrência estável.
- [ ] Mapeamento de cor é único, estável e centralizado.
- [ ] Capa usa paleta tonal (`shadow/dark/base/highlight`) derivada da dominante.
- [ ] `RetroImageProcessor` segue como pipeline único.
- [ ] Pedais antigos continuam carregando sem migração destrutiva.
- [ ] Superfícies relevantes expõem informação de nota também por texto/acessibilidade.
- [ ] Testes focados da feature passam.
- [ ] Suíte completa, builds Debug/Release Simulator e `git diff --check` passam.
- [ ] Diff final não inclui Game Center nem multiplayer.
