# Pedalboard Playback — Validação da Etapa 2

Status: validado
Data: 2026-07-18
Escopo: coordinator de playback sequencial, resolução de entries, duração determinística, callbacks de parada do synth, testes focados, sem UI.

## Resumo executivo

A Etapa 2 introduz `PedalboardPlaybackCoordinator` como camada independente de SwiftUI para reproduzir entries de um `Pedalboard` em ordem. O coordinator resolve referências para `PhotoPedal` persistido, pula entries ausentes, preserva índices originais, mantém `finished` até novo `play` ou `stop`, e cancela callbacks tardios por token de geração.

Nenhuma UI de pedalboard foi implementada. `PedalboardStore` continua sem responsabilidade de playback. A leitura de pedais para playback usa JSON-only em `PedalStore`, sem decodificar PNG.

## Arquitetura do coordinator

- `PedalboardPlaybackCoordinator` fica em `snap-battle/Services/Audio/PedalboardPlaybackCoordinator.swift`.
- O estado público é `PedalboardPlaybackState`, com `idle`, `preparing`, `playing`, `stopping`, `finished` e `failed`.
- `playing` expõe `boardID`, `entryID`, `index` e `total` usando o índice e total originais de `Pedalboard.entries`.
- `entryPlaybackInfo` expõe, por entry, `entryID`, `pedalID`, índice original e status `playable` ou `missing`, sem carregar imagens nem armazenar payloads de áudio.
- O coordinator não persiste boards, não navega, não altera `PedalboardStore`, não carrega imagens e não implementa UI.

## Contrato com o synth

- `PhotoPedalSynth` continua sendo o dono do `AVAudioEngine` e do render de áudio.
- `PedalPlaying` ganhou um `stopHandler` mínimo com `PhotoPedalSynthStopReason`.
- `requested` representa `stop()` explícito ou substituição intencional e é ignorado como falha pelo coordinator.
- `interruption` e `engineFailure` são tratadas como parada inesperada e encerram a reprodução da board.
- `PhotoPedalSynth.play(_:)` mantém o contrato atual: para a reprodução anterior, configura sessão, aplica efeito persistido, renderiza a sequência e inicia o engine.

## Estratégia de conclusão

`PhotoPedalSynth` ainda não expõe callback natural de fim do buffer renderizado. A progressão da board usa um scheduler injetável com a duração calculada a partir do mesmo comportamento do render:

```text
samplesPerStep = max(1, Int(sampleRate * 60 / bpm / 4))
totalSamples = samplesPerStep * 16
duration = totalSamples / sampleRate
```

Rests, gate e quantidade de notas não alteram a duração total, porque o synth percorre e renderiza todos os 16 steps. Gate, BPM, sample rate e posições de notas são validados separadamente para evitar sequências inválidas.

## Políticas

- `play(board:)` durante playback usa restart: cancela espera anterior, invalida geração, chama `stop()` no player e começa da primeira entry resolvível.
- `stop()` é idempotente, cancela progressão futura, invalida callbacks tardios, chama o player quando há reprodução ativa e volta para `idle`.
- Board vazio termina em `finished` sem tocar áudio.
- Board composto apenas por entries ausentes termina em `finished` sem tocar áudio.
- Entry ausente é pulada, preservada no domínio e exposta em `entryPlaybackInfo`.
- Falha estrutural de resolução, documento incompatível, sequência inválida ou falha de start do synth encerra em `failed` e não continua para entries seguintes.

## Concorrência e cancelamento

- O coordinator é `@MainActor` e usa uma única espera cancelável por entry.
- Cada sessão recebe um token de geração; callbacks de scheduler ou do synth só têm efeito se ainda pertencem à sessão atual.
- O scheduler de produção usa espera temporal injetável como fallback necessário à ausência de callback natural do synth; testes usam scheduler manual.
- O teste de desalocação valida ausência de retenção por callbacks via seam injetado, sem depender de `deinit` chamar APIs de áudio.

## Testes

Cobertura adicionada em `PedalboardPlaybackCoordinatorTests`:

- board vazio;
- uma entry válida;
- múltiplas entries válidas em ordem;
- duplicata do mesmo pedal tocando em posições distintas;
- entry ausente entre válidas;
- todas ausentes;
- board original não mutado;
- restart durante playback;
- callback tardio cancelado;
- Stop durante playback, Stop repetido e Stop após finished;
- `requested` tardio ignorado;
- falha ao iniciar synth;
- falha no meio do board;
- falha estrutural de resolução;
- sequência inválida;
- interrupção inesperada;
- desalocação sem retenção;
- duração sample-aligned independente de rests.

Cobertura adicionada em `PhotoPedalStabilizationTests`:

- `PedalStore.loadPhotoPedal(id:)` carrega JSON sem PNG;
- validação de ID esperado no caminho JSON-only;
- `stop()` do synth quando idle não emite parada inesperada.

## Limitações

- Não há callback natural sample-accurate de término do `AVAudioSourceNode`; a progressão usa duração calculada e scheduler injetável.
- Validação em dispositivo físico, áudio perceptual, Bluetooth, route changes e interrupções reais continuam fora dos testes automatizados.
- UI de pedalboards, Jam root, Gallery/Library hooks, drag-and-drop, colaboração e Etapa 3 não foram implementados.

## Resultados de validação

- Testes focados de playback: passou, `PedalboardPlaybackCoordinatorTests`, 17 testes.
- Testes focados de navegação afetada: passou, `NavigationGalleryTests`, 18 testes, com DerivedData isolado após falhas de bootstrap do Simulator/XCTest.
- Testes focados de áudio/persistência afetados: cobertos em `PhotoPedalStabilizationTests` dentro da suíte completa.
- Testes de domínio/store do Pedalboard: cobertos em `PedalboardDomainTests` e `PedalboardStoreTests` dentro da suíte completa.
- Suíte completa: passou, 185 testes em 14 suítes, `xcodebuild test -project "snap-battle.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- Build Debug Simulator: passou, `xcodebuild build -project "snap-battle.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug`.
- Build Release Simulator: passou, `xcodebuild build -project "snap-battle.xcodeproj" -scheme "snap-battle" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Release`.
- `git diff --check`: passou.
- `git diff --check origin/main...HEAD`: passou para o intervalo commitado atual; repetir após commit final.

Observação: uma tentativa de suíte completa executada em paralelo com build Release falhou por lock do banco de build do Xcode (`build.db`), sem executar testes. A suíte completa foi repetida isoladamente e passou.
