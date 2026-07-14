# Relatório de execução física — 14/07/2026

## O que foi confirmado

- Xcode 26.5 (build 17F42).
- Build Debug para o destino físico `Roque`, iPhone 16 (`iPhone17,3`), UDID `00008140-001404A80E02801C`: **sucesso**.
- Assinatura: `Apple Development: Pedro Lima (PGZ89K3X2M)`.
- Provisioning: `iOS Team Provisioning Profile: *`, gerenciado pelo Xcode, Team `3YFDTC5X3L`, válido até 25/06/2027 e contendo o UDID do aparelho.
- Entitlements efetivos: application identifier `3YFDTC5X3L.PedroKosciuk.snap-battle`, team identifier e `get-task-allow`; nenhum entitlement customizado do Foundation Models.
- Info.plist do produto: bundle id `PedroKosciuk.snap-battle`, mínimo iOS 26.5 e `NSCameraUsageDescription` presente.
- Instalação no `Roque`: **sucesso**.
- Build arm64 final para `generic/platform=iOS`, após os últimos ajustes: **sucesso**, com a mesma identidade/profile.
- Build Release para simulador: **sucesso**.
- Testes automatizados: **13/13 passaram** no iPhone 17 Simulator com iOS 26.5.
- Warnings de concorrência: nenhum.
- Warning restante: somente `Metadata extraction skipped. No AppIntents.framework dependency found`, esperado porque o app não usa App Intents.

## O que não foi validado

A tentativa de abrir o app instalado no `Roque` foi recusada pelo SpringBoard com `FBSOpenApplicationErrorDomain code 7 / Locked`: o aparelho estava bloqueado. Na tentativa seguinte, os dois iPhones pareados estavam indisponíveis para execução por precisarem ser desbloqueados.

Logo, **nenhum comportamento do pipeline real foi declarado validado no iPhone**. Ainda faltam observação do estado real do Foundation Models, câmera, subject lifting, Vision, geração, stats, repetição, tempos, memória e cancelamento. Esses testes dependem do usuário desbloquear/manusear o aparelho e seguir `DEVICE_TEST_PLAN.md`.
