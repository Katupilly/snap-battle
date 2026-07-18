# Pedalboard Foundation — Validação da Etapa 1

Status: concluída sem dívida funcional após correção dos P2 do PR #2
Data: 2026-07-17
Escopo: domínio `Pedalboard` + `PedalboardStore` isolado, validação determinística, sem playback nem UI.

## Resumo executivo

Foi introduzido o modelo de domínio `Pedalboard`/`PedalboardEntry` e o envelope versionado `PedalboardDocument` em [`snap-battle/Domain/Pedalboard/Pedalboard.swift`](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Domain/Pedalboard/Pedalboard.swift), acompanhado de um store isolado em [`snap-battle/Services/Persistence/PedalboardStore.swift`](/Users/pedrolima/Documents/Academy%202026/snap-battle/snap-battle/Services/Persistence/PedalboardStore.swift). O store escreve em `Application Support/pedalboards/<uuid>.json` com envelope `schemaVersion == 1`, valida o documento temporário antes da promoção, tolera corrupção e versões desconhecidas, e remove arquivos temporários deixados por escritas parciais.

Nenhum arquivo de produção do `PedalStore`, do pipeline musical, da Gallery ou do Jam foi alterado. Nenhuma view SwiftUI foi tocada. Nenhum depurador novo nem caminho de release foi exposto. A suíte completa de testes do projeto passou, junto com os novos arquivos `PedalboardDomainTests` e `PedalboardStoreTests`.

Decisão: **Phase 2 Step 1: Unblocked, sem dívida funcional**.

## Atualização PR #2 — Findings P2 corrigidos

Em 2026-07-17, o PR #2 recebeu dois findings P2 abertos pela revisão automatizada:

1. **Restore backups left by interrupted promotion** em `PedalboardStore.promote`.
2. **Reject boards with duplicate entry IDs** em `PedalboardStore.load(id:)`.

Ambos foram corrigidos no escopo de domínio e persistência do Pedalboard, sem alterar `PedalStore`, `StoredPedal`, UI, playback, Jam, Gallery, Library, App Intents, roadmap, ADRs ou `.agents/audits/`.

### Causas raiz

- O protocolo de save move o final `<uuid>.json` para o backup `<uuid>.json.tmp-backup-<token>` antes de promover o temporário `<uuid>.tmp-<token>.json`. Se o app fosse interrompido nessa janela, o próximo `loadCollection()` chamava um cleanup genérico que removia qualquer arquivo contendo `.tmp-`, apagando também o único backup válido.
- A carga aceitava qualquer `PedalboardDocument` cujo schema e `pedalboard.id` batessem com o filename. Um documento externo poderia persistir duas `PedalboardEntry` com o mesmo `entry.id`, tornando remoção, reordenação, identidade SwiftUI e futuras operações de playback ambíguas.

### Política de recuperação de backups

- `loadCollection()` agora separa backups reais de promoção (`<uuid>.json.tmp-backup-<token>`) de temporários comuns (`<uuid>.tmp-<token>.json`) antes do cleanup.
- Se o final estiver ausente e houver backup válido, o backup é restaurado para `<uuid>.json` após validar schema, filename/board ID e invariantes do board.
- Se o final for válido, ele vence; backups de promoção órfãos do mesmo UUID são removidos sem sobrescrever o estado mais recente.
- Se o final estiver ausente e o backup for inválido, nenhum board é carregado para aquele UUID, um issue é registrado e o backup inválido fica preservado para diagnóstico.
- Se o final existir mas for inválido e houver backup válido, o final inválido é movido para `<uuid>.json.invalid-<token>`, o backup válido é restaurado e um issue explícito registra a recuperação.
- Quando houver múltiplos backups válidos para o mesmo UUID, a escolha é determinística: maior `updatedAt`, depois maior `createdAt`, depois nome de arquivo em ordem ascendente. A regra não depende da ordem do filesystem.
- A recuperação é idempotente, limitada ao diretório `Application Support/pedalboards/` e só deriva IDs de UUIDs válidos.

### Política para entry IDs duplicados

- `PedalboardDocument.validatedPedalboard(expectedID:)` centraliza a validação persistida de schema, board ID e unicidade de `PedalboardEntry.id`.
- Boards com `entry.id` duplicado são rejeitados como inválidos durante `load(id:)` e `loadCollection()`.
- O arquivo inválido não é sobrescrito nem sanitizado; os demais boards válidos continuam carregando e o issue inclui `duplicate entry id <uuid>`.
- Repetir o mesmo `pedalID` continua permitido quando os `entry.id` são distintos.

### Testes adicionados

`PedalboardStoreTests` adicionou regressões de filesystem real para:

- backup válido + final ausente restaura o backup byte a byte;
- backup válido + final válido preserva o final e remove o backup;
- backup inválido + final ausente não carrega board, registra issue e preserva o backup;
- final inválido + backup válido restaura o backup e preserva o final inválido renomeado;
- recuperação repetida é idempotente;
- backup de um board não afeta outro board;
- temporários comuns continuam sendo limpos sem apagar backup recuperável;
- duas entries com o mesmo `entry.id` e `pedalID` diferente são rejeitadas;
- duas entries com o mesmo `entry.id` e mesmo `pedalID` são rejeitadas;
- mesmo `pedalID` com entry IDs distintos continua válido;
- board inválido é isolado enquanto outro válido carrega;
- arquivo inválido com IDs duplicados permanece intacto byte a byte e o issue identifica a violação.

### Resultados desta atualização

- Testes focados `PedalboardDomainTests` + `PedalboardStoreTests`: 55/55 passaram.
- Suíte completa no Simulator (iPhone 17 Pro / iOS 26.5): 164/164 passaram.
- Build Debug para iOS Simulator: passou.
- Build Release para iOS Simulator: passou.
- `git diff --check`: passou.

Risco residual: backups de deleção (`<uuid>.tmp-delete-<token>.json`) continuam seguindo a semântica existente de deleção com marker e não foram reclassificados como backups de promoção nesta correção, para manter o escopo restrito aos dois P2 abertos.

## Divergência documental registrada

O briefing inicial afirmava "o commit `7172001` está no HEAD". Na inspeção real do repositório o HEAD da branch `codex/pedalboard-phase2-foundation` era `6c76249 feat(library): add gallery canvas grid background` e `7172001 docs(pedalboard): define phase 2 foundation` era seu parent. O push inicial foi feito a partir desse HEAD real, sem force push, e a Etapa 1 foi commitada em cima dele. Nenhuma premissa foi silenciosamente substituída.

Em uma revisão independente posterior, esse mesmo commit `6c76249` (canvas grid da Biblioteca) foi reclassificado como **Unrelated commit** porque não pertence ao escopo do Pedalboard: ele toca apenas `snap-battle/Features/Gallery/GalleryView.swift` e `snap-battle/Features/Library/CanvasGridBackground.swift`, sem dependência funcional nem textual com o domínio ou a persistência do Pedalboard. A branch da Phase 2 foi então reconstruída:

- Tag de backup local: `backup/pedalboard-phase2-pre-cleanup-2026-07-17` apontando para o HEAD anterior (`259a31a`).
- Branch dedicada publicada: `codex/library-canvas-grid` em `e7d7afb` (reaplicação limpa de `6c76249` sobre `origin/main`).
- Branch da Phase 2 reconstruída via `git reset --hard origin/main` + `git cherry-pick 25a7ee2 7172001 259a31a`, preservando o conteúdo e mensagens de cada commit mas com hashes novos (`53b171f`, `9bc8050`, `7185953`).
- Push aplicado com `--force-with-lease` na branch da Phase 2 (nunca em `main`).

Estado final do histórico:

```text
* 7185953 (HEAD -> codex/pedalboard-phase2-foundation, origin/codex/pedalboard-phase2-foundation) feat(pedalboard): add domain model and persistence
* 9bc8050 docs(pedalboard): define phase 2 foundation
* 53b171f docs: add skill routing guidance
* 19cb922 (origin/main, origin/HEAD, main) feat(library): complete chronological gallery phase (#1)
* 3a2fd1c Finalize contextual bottom bar increment
* …
```

`git diff --check origin/main...HEAD` passou após a reconstrução, com 9 arquivos modificados (1756 inserções, 2 deleções) — apenas Phase 2, sem o canvas grid da Biblioteca.

## Arquivos implementados

| Arquivo | Função |
| --- | --- |
| `snap-battle/Domain/Pedalboard/Pedalboard.swift` | `Pedalboard`, `PedalboardEntry`, `PedalboardDocument`, enum `PedalboardMutation` |
| `snap-battle/Services/Persistence/PedalboardStore.swift` | Store isolado, `PedalboardStoreLoadResult`, `PedalboardStoreError` |
| `snap-battleTests/PedalboardDomainTests.swift` | 19 testes determinísticos de domínio |
| `snap-battleTests/PedalboardStoreTests.swift` | 36 testes determinísticos de persistência |
| `snap-battle.xcodeproj/project.pbxproj` | Inclusão dos dois novos arquivos de teste no `PBXBuildFile`, `PBXFileReference`, grupo `snap-battleTests` e `PBXSourcesBuildPhase` |
| `docs/DATA_MODEL.md` | Entradas de `Pedalboard`, `PedalboardEntry`, `PedalboardDocument`, seção de storage e invariantes |

Nenhum arquivo do `PedalStore` foi alterado. Nenhuma spec em `specs/current/` foi modificada porque a decisão de manter fallback neutro no domínio é compatível com a spec `pedalboard-phase2-foundation.md`, que prevê escolha entre normalizar ou rejeitar nomes em branco. O fallback neutro preserva a regra de "testável e independente de idioma" exigida pelo briefing.

## Modelo de domínio e invariantes

```swift
struct Pedalboard: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var entries: [PedalboardEntry]
}

struct PedalboardEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let pedalID: StoredPedal.ID
}

struct PedalboardDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let pedalboard: Pedalboard
}
```

Invariantes aplicadas e testadas:

- `Pedalboard.id`, `PedalboardEntry.id` e `PedalboardEntry.pedalID` são imutáveis após `init`.
- `entries` é a ordem semântica; `PedalboardMutation.moveEntry(id:to:in:now:)` preserva o `entry.id` das entries movidas e apenas troca sua posição.
- `Pedalboard.normalize(_:)` remove whitespace nas extremidades; quando o resultado é vazio, devolve `Pedalboard.defaultName = "Pedalboard"` (constante técnica, sem cópia localizada).
- `PedalboardMutation.rename(_:board:now:)` é no-op se a versão normalizada coincidir com o nome atual e não toca em `updatedAt` nesse caso.
- `updatedAt` é refrescado em todas as mutações estruturais (`addPedal`, `removeEntry`, `moveEntry`, `rename`) e nunca pelo playback (que não existe nesta etapa).
- `createdAt` é preservado em todas as mutações.
- `removeEntry(id:)` usa `PedalboardEntry.ID`; remover uma ocorrência específica não afeta outras duplicatas.
- `moveEntry(id:to:in:now:)` clampa o destino em `[0, count-1]`, devolve `nil` quando o ID não existe e devolve o board inalterado quando o destino coincide com a posição atual.
- Pedais duplicados são permitidos por meio de `PedalboardEntry.id` distintos.
- Referências ausentes (`pedalID` sem `StoredPedal` correspondente) permanecem serializáveis; o store não remove nem reescreve a entrada durante o load.

## Store e paths

| Aspecto | Decisão |
| --- | --- |
| Diretório | `Application Support/pedalboards/` (calculado a partir do mesmo `applicationSupportDirectory` usado por `PedalStore`) |
| Nome do arquivo | `<uuid>.json`, derivado estritamente de `UUID.uuidString`; nenhum input externo entra no path |
| Envelope | `PedalboardDocument { schemaVersion: Int, pedalboard: Pedalboard }` |
| Versão inicial | `schemaVersion == 1` |
| Escrita temporária | `<uuid>.tmp-<token>.json` no mesmo diretório, com `defer { try? removeItem }` |
| Validação pré-promoção | Decode de `PedalboardDocument`, comparação de `pedalboard.id` com o UUID alvo e checagem de `schemaVersion == 1` |
| Promoção | `moveItem` para o path final, com backup `.tmp-backup-<token>` em caso de falha |
| Deleção | Move para backup + escrita de marker `.deleted`; marker é removido em `save` subsequente |
| Injeção de I/O | `init(directory:fileManager:writeData:loadCollectionDidRun:)` permite testes isolados e simulação de falhas de disco |
| `#if DEBUG` | Expõe `debugCollectionDirectory` para que fixtures e testes possam inspecionar a pasta dedicada |
| Isolamento | `PedalboardStore` nunca lê, escreve, deleta ou enriquece o diretório `Application Support/pedals/` |

## Comportamento com corrupção e schema desconhecido

- Arquivo `<uuid>.json` que não decodifica como `PedalboardDocument`: o erro é capturado em `loadCollection`, o arquivo continua no disco, `issues += 1` e os outros boards válidos permanecem visíveis. `hasPartialError == true` quando há pelo menos um board válido e ao menos um issue.
- `schemaVersion != 1`: o erro é mapeado para `PedalboardStoreError.unsupportedSchemaVersion(version)`, o arquivo continua no disco (não há tentativa de migração destrutiva), `issues` recebe uma mensagem com a versão observada.
- Arquivo parcialmente escrito (`<uuid>.tmp-<token>.json` deixado para trás): `cleanupTemporaryArtifacts()` remove o que casar `.tmp-` antes da enumeração principal.
- Marker `<uuid>.deleted` encontrado no `loadCollection`: removido por `cleanupDeletionMarkers()` para evitar acúmulo; o board correspondente é descartado pelo usuário quando ele chama `delete(id:)`.
- Falha de escrita simulada em `writeData`: `save` propaga o erro, não cria arquivo final, e (quando o alvo já existe) restaura o backup na posição original, evitando corromper o estado anterior.

## Comportamento com referências ausentes e duplicadas

- `PedalboardEntry.pedalID` pode referenciar um `StoredPedal.ID` que não existe no `PedalStore`. O store persiste a referência sem tentar resolvê-la. O round trip Codable preserva exatamente o `pedalID` original.
- O mesmo `pedalID` pode aparecer N vezes; cada inserção é uma `PedalboardEntry` distinta com `id` próprio, preservada após save/load.
- Esta etapa não introduz nenhuma abstração pública de resolução. O acoplamento com `PedalStore` deve ocorrer apenas nas camadas de UI ou playback, conforme autorizado pela spec.

## Testes adicionados

`PedalboardDomainTests` cobre:

- normalização de nome (vazio, whitespace, trim de bordas, espaços internos preservados);
- criação com nome default e normalização de nome em branco;
- `updatedAt` e `createdAt` em mutações estruturais;
- duplicatas produzem `entry.id` distintos;
- `removeEntry` afeta apenas a entry alvo;
- `removeEntry` é no-op para ID inexistente e não toca em `updatedAt`;
- `moveEntry` reordena preservando IDs e clampa destinos fora dos limites;
- `moveEntry` devolve `nil` para ID desconhecido;
- `rename` preserva `createdAt`, refresca `updatedAt`, é no-op quando nome normalizado coincide;
- round trip Codable preserva todos os campos;
- envelope serializa `schemaVersion == 1`;
- `PedalboardStore.ordered(_:)` aplica `updatedAt` desc, `createdAt` desc, `id.uuidString` asc;
- tie-break por `id.uuidString` asc;
- mutações inválidas não corrompem o board.

`PedalboardStoreTests` cobre:

- save/load de um board;
- coleção com múltiplos boards em ordem estável;
- atualização não afeta outros boards;
- delete remove apenas o alvo e os demais permanecem;
- ordenação por `updatedAt` com tie-breaks;
- arquivo corrompido gera issue e preserva válidos;
- schema desconhecido (`999`) gera issue e preserva o arquivo no disco byte a byte;
- referência a pedal inexistente sobrevive ao round trip com `pedalID` original;
- duplicatas sobrevivem ao round trip com `entry.id` distintos;
- diretório `pedals/` do `PedalStore` plantado no mesmo `rootDirectory` é ignorado;
- diretório vazio e diretório ausente;
- save repetido do mesmo `id` não acumula arquivos;
- falha de escrita no temporário não cria arquivo final;
- falha de escrita durante a promoção não corrompe o board existente (backup restaurado);
- arquivos `.tmp-` órfãos são limpos no próximo `loadCollection`;
- marker `.deleted` impede novo `save` e é removido em um `save` bem-sucedido posterior;
- extensões desconhecidas (`.txt`, `.png`) são ignoradas e não geram issues;
- todos os arquivos no diretório dedicado terminam em `.json` e nenhum contém `/` ou `..`;
- filenames com texto que não é UUID são ignorados;
- `PedalboardStore.shared` resolve para `Application Support/pedalboards/`;
- injeção de `loadCollectionDidRun` permite observar chamadas.

Total de testes adicionados nesta etapa após a correção dos P2: 55 focados em domínio/store (19 de domínio + 36 de store). A suíte completa do projeto terminou com `164 testes`, todos passaram.

## Resultados de testes

- `PedalboardDomainTests`: 19/19 passaram.
- `PedalboardStoreTests`: 36/36 passaram.
- Suíte completa no Simulator (iPhone 17 Pro / iOS 26.5): 164/164 passaram.
- `git diff --check`: passou.
- `git diff --check origin/main...HEAD`: passou (após o commit desta etapa; nada para verificar antes do commit porque o working tree só continha o que entrou no commit).

## Builds executados

- Build Debug para iOS Simulator: passou.
- Build Release para iOS Simulator: passou.

## Limitações e verificações não executadas

- Sem execução em dispositivo físico (memória, acessibilidade completa, VoiceOver/Dynamic Type extensivos, Instruments). Mantido como item não bloqueante, consistente com o restante do projeto.
- Sem teste de estresse com milhares de boards — não exigido pela spec e fora do escopo desta etapa.
- Sem auditoria de concorrência adicional além da separação de I/O em funções síncronas e ausência de captura de `self` em closures; nenhum `Task` ou `actor` foi introduzido.

## Decisões adiadas para playback e UI

- Semântica de `Play` quando já está tocando (restart vs ignore).
- Comportamento de board vazio ao tocar.
- Apresentação visual de `Pedalboard` na raiz `Jam`.
- Nomenclatura final entre `Jam` e `Pedalboard`.
- Resolução concreta de `pedalID` em `StoredPedal` para UI/playback (sem abstração pública nesta etapa).
- Coordenador de playback sequencial.
- Acessibilidade e Reduce Motion das telas de board.

## Riscos residuais

- `PedalboardStore` e `PedalStore` compartilham apenas o mesmo `rootDirectory` (Application Support). Qualquer mudança futura nesse diretório raiz afeta os dois simultaneamente; vale documentar a relação quando o diretório raiz passar a ser configurável.
- A spec não proíbe múltiplos boards referenciando o mesmo `pedalID`; o domínio permite e o store preserva, mas a UI de adicionar pedais precisa tratar isso explicitamente.
- A spec menciona explicitamente que `PhotoPedalSynth` ainda não expõe callback de fim de sequência; essa pendência continua fora do escopo desta etapa.

## Confirmações de isolamento

- `PedalStore.swift`: 0 alterações.
- `snap-battle/Features/Library/**`: 0 alterações.
- `snap-battle/Features/Gallery/**`: 0 alterações.
- `snap-battle/Features/Capture/**`: 0 alterações.
- `snap-battle/Features/Pedal/**`: 0 alterações.
- `snap-battle/Features/Navigation/**`: 0 alterações.
- `snap-battle/Services/Audio/**`: 0 alterações.
- `snap-battle/Services/Pedal/**`: 0 alterações.
- `snap-battle/Services/Vision/**`: 0 alterações.
- `snap-battle/Services/FoundationModels/**`: 0 alterações.
- `snap-battle/Intents/**`: 0 alterações.
- `snap-battle/Domain/Pedal/**`: 0 alterações.
- `specs/current/**`: 0 alterações.
- `.agents/audits/`: continua fora do Git (untracked, não commitado).
