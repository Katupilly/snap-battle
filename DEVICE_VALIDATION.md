# Validação da PoC em dispositivo

Estado documentado em 14/07/2026. Este arquivo separa o que foi inspecionado/compilado do que só pode ser confirmado ao executar e observar o app em um iPhone.

## Configuração do target

- Target/scheme: `snap-battle`.
- Bundle identifier: `PedroKosciuk.snap-battle`.
- Deployment target: iOS 26.5.
- Assinatura: automática, Team `3YFDTC5X3L`. O build físico deve produzir um provisioning profile compatível com o bundle id e com o UDID do aparelho. Não há entitlement customizado do Foundation Models porque a PoC usa o modelo padrão, sem adapter.
- Info.plist: gerado pelo build. `NSCameraUsageDescription` é `Use the camera to capture a photo for creature analysis.` em Debug e Release.
- Foundation Models: framework do sistema, disponível a partir do iOS 26. O app consulta `SystemLanguageModel.default.availability` antes de cada geração e não assume disponibilidade com base no modelo do iPhone.
- Release: o painel, a repetição, o mock e os logs estruturados estão cercados por `#if DEBUG`.

## Requisitos de Apple Intelligence

Segundo a documentação da Apple consultada nesta data:

- iPhone compatível: iPhone 15 Pro/Pro Max e linha iPhone 16 ou posterior;
- Apple Intelligence ativada em Ajustes > Apple Intelligence e Siri;
- idioma do dispositivo e idioma da Siri iguais e em um idioma suportado;
- cerca de 7 GB de armazenamento livre para os modelos;
- modelos locais baixados. O download é gerenciado pelo sistema e varia com Wi‑Fi, energia, bateria e carga do sistema;
- região elegível. Há restrições específicas para China continental.

Idiomas listados pela Apple para iOS 26.1: inglês, dinamarquês, neerlandês, francês, alemão, italiano, norueguês, português, espanhol, sueco, turco, chinês simplificado, chinês tradicional, japonês, coreano e vietnamita. A lista pode mudar por versão. Por isso, o painel mostra `supportedLanguages` do próprio modelo instalado e o resultado de `supportsLocale(Locale.current)`; essa consulta no aparelho é a fonte de verdade para a execução.

Estados exibidos pelo app:

- `available`: modelo pronto;
- `notReady`: `modelNotReady`, incluindo download/preparação ou outra condição temporária do sistema;
- `unavailable`: aparelho inelegível, Apple Intelligence desativada, locale não suportado ou motivo desconhecido.

O app não inicia uma sessão quando o estado não é `available` ou quando o locale corrente não é suportado. Ele não tenta baixar o modelo e não faz polling automático; reabrir a tela ou iniciar uma nova tentativa atualiza o diagnóstico.

Referências: [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel), [idiomas e locales no Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models), [requisitos do Apple Intelligence](https://support.apple.com/121115).

## Origem dos dados e dos stats

Dados diretos do Vision:

- até cinco labels da `ClassifyImageRequest` e a confidence individual de cada label.

Dados de VisionKit/extração:

- imagem do sujeito quando o subject lifting funciona;
- não há confidence calibrada de subject lifting nessa API, portanto `subjectConfidence` permanece ausente;
- quando não há sujeito ou a extração falha, a imagem inteira é usada como fallback e isso aparece como falha de subject lifting no diagnóstico.

Dados heurísticos locais:

- material e confidence fixa da regra (`0.35` quando uma regra casa; `0` para desconhecido), inferidos por termos nas labels;
- aspect ratio, quantidade de pixels do sujeito e presença de alpha, derivados da geometria/bitmap;
- fingerprint SHA‑256 da representação RGBA sRGB 32×32 após normalização de orientação. Ele não usa `hashValue`, nome ou caminho e não é enviado ao Foundation Models.

Dados do Foundation Models:

- `name`, `role` (equivalente ao arquétipo atual), `temperament`, `description` e `tags`;
- a PoC não produz `species`, `affinity` nem `rarityHint`; a comparação mostra esses campos como não gerados, sem inventar equivalências.

Budget de stats:

- sempre 240, com mínimo 20 e máximo 100 por stat;
- nenhum campo altera o budget.

Distribuição dos stats:

- `role`, gerado pelo Foundation Models, define os pesos principais;
- `material`, heurístico a partir do Vision, modifica um peso;
- `name` (Foundation Models), `role` (Foundation Models), labels (Vision) e material (heurístico) entram na seed FNV‑1a estável usada para o jitter;
- confidence das labels, confidence do material, aspect ratio, pixels, alpha, temperament, description e tags não alteram os números.

Consequência: o calculador é determinístico para o mesmo `name + role + labels + material`, mas uma nova geração do Foundation Models pode mudar `name` ou `role` e, portanto, mudar os stats. A PoC não força determinismo do modelo. O resultado visível permanece congelado após a primeira geração; somente a ação Debug explícita executa uma segunda rodada e ela não substitui a criatura exibida.

## Como executar

### Gerador real

1. Abra `snap-battle.xcodeproj` no Xcode 26.5 ou posterior.
2. Selecione o scheme `snap-battle`, configuração Debug e o iPhone físico.
3. Confirme Signing & Capabilities com Team `3YFDTC5X3L`; se o perfil não incluir o aparelho, deixe o Xcode registrá-lo ou selecione um Team que possa assinar `PedroKosciuk.snap-battle`.
4. Execute com Run. No aparelho, confirme confiança do desenvolvedor se o iOS solicitar.

### `--mock-generator`

O argumento só funciona em Debug e ignora completamente o Foundation Models:

1. Product > Scheme > Edit Scheme…
2. Run > Arguments.
3. Em “Arguments Passed On Launch”, adicione e marque `--mock-generator`.
4. Execute novamente. O painel deve mostrar `Mock generator` e informar que o modelo foi ignorado.

Remova ou desmarque o argumento para validar o pipeline real.

### Painel Debug

Compile e execute a configuração Debug. O painel aparece no fim da tela inicial e no fim da tela de resultado; role a tela para baixo. Depois da primeira geração, o botão `Run Again With Same Image` fica imediatamente acima do painel. Em Release, ambos não são compilados.

## Checklist de evidência no iPhone

Registrar para cada rodada: modelo/OS/idioma/região do aparelho, estado e detalhe do modelo, run id, fingerprint curto, tamanhos, subject lifting, labels/confidences, material/confidence, quatro durações, total, memória residente aproximada e erro completo. Não copiar imagem ou lore completa para logs.

O build e os testes automatizados não validam câmera, subject lifting, disponibilidade real do modelo, download/preparação, qualidade das labels, geração, cancelamento observado nem memória no aparelho. Esses itens exigem execução manual conforme `DEVICE_TEST_PLAN.md`.
