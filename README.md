# OCI Object Storage Explorer for macOS

Aplicação desktop nativa para macOS, escrita em Swift + SwiftUI, para autenticar no Oracle Cloud Infrastructure e navegar pelo OCI Object Storage com uma experiência próxima a um file explorer moderno.

## Visão geral

O projeto prioriza:

- UX nativa de macOS com `NavigationSplitView`, toolbar, inspector e dark/light mode.
- Arquitetura em camadas, com separação clara entre UI, ViewModels, serviços, autenticação, modelos e utilitários.
- Integração real com OCI Object Storage via REST API assinada.
- Armazenamento seguro de segredos no Keychain do macOS.
- Base pronta para evolução futura em múltiplos métodos de autenticação e novos fluxos operacionais.

## Arquitetura proposta

### Camadas

- `OCIExplorerApp`
  - Camada de apresentação em SwiftUI.
  - Views, view models, shell da aplicação e utilitários de interação nativa.
- `OCIExplorerCore`
  - Modelos tipados, erros, formatação, validação e logging.
- `OCIExplorerServices`
  - Integração com OCI, assinatura de requests, HTTP client, persistência de perfis, Keychain e coordenação de transferências.

### Padrão

- UI: SwiftUI
- Arquitetura: MVVM
- Concorrência: `async/await`
- Injeção de dependência: container simples (`AppContainer`)
- Persistência: JSON para perfis + Keychain para segredos
- Integração OCI: REST API com assinatura RSA SHA-256

## Estrutura de pastas

```text
Sources/
  OCIExplorerApp/
    App/
    Components/
    Features/
      Authentication/
      Diagnostics/
      Explorer/
      PAR/
      Transfers/
    Utilities/
  OCIExplorerCore/
    Errors/
    Logging/
    Models/
    Utilities/
  OCIExplorerServices/
    Authentication/
    Networking/
    ObjectStorage/
    Transfers/

Tests/
  OCIExplorerAppTests/
  OCIExplorerServicesTests/
```

## Principais decisões técnicas

### 1. Integração OCI via REST assinada

Não há, na prática, um SDK Swift maduro e amplamente adotado cobrindo de forma confortável todo o fluxo necessário para um explorer macOS moderno. Por isso, a aplicação usa uma camada REST própria e organizada:

- `OCIRequestSigner`
- `OCIHTTPClient`
- `OCIObjectStorageService`

Vantagens:

- Controle fino sobre autenticação e headers assinados.
- Menos dependências externas.
- Maior previsibilidade para evolução de features específicas.

### 2. Perfis seguros

Perfis salvos armazenam apenas metadados não sensíveis:

- nome
- tenancy OCID
- user OCID
- fingerprint
- region
- namespace
- compartment padrão
- hint do caminho da chave

Segredos ficam no Keychain:

- PEM da chave privada
- passphrase

### 3. Navegação por pastas virtuais

OCI Object Storage é flat. A experiência de diretórios é construída com base em:

- `prefix`
- `delimiter=/`

Isso permite navegação com breadcrumb e visualização amigável de pseudo-pastas.

### 4. Transfer queue separada

Uploads e downloads são enviados para uma fila central (`TransferCoordinator`) com:

- progresso por item
- cancelamento
- retry
- estados de fila

## Funcionalidades implementadas

### Autenticação

- Tela de autenticação com perfil salvo e edição
- API Key como método principal
- Campos:
  - profile name
  - tenancy OCID
  - user OCID
  - fingerprint
  - region
  - namespace opcional
  - compartment padrão
  - caminho/importação da chave PEM
  - passphrase
- Teste de conexão
- Detecção automática de namespace
- Salvamento seguro no Keychain
- Duplicação e remoção de perfis

### Object Storage Explorer

- Lista de buckets na sidebar
- Criação e exclusão de bucket
- Carregamento de detalhes do bucket
- Navegação por prefixos
- Breadcrumb
- Busca local incremental
- Alternância entre modos de visualização “lista” e “árvore”
- Inspector com detalhes do bucket e do objeto selecionado

### Objetos

- Listagem de objetos
- Exclusão de objetos
- Leitura de metadados do objeto
- Copiar nome do objeto

### Transferências

- Upload de múltiplos arquivos via diálogo nativo
- Download de múltiplos objetos para pasta local
- Resolução de conflito de nome no download
- Progresso por item
- Cancelamento
- Retry
- Fila visual de transferências

### PAR

- Criação de Pre-Authenticated Requests
- Listagem de PARs do bucket atual
- Remoção de PAR
- Cópia da URL gerada

### Diagnóstico

- Logging básico em memória
- Tela simples de diagnósticos
- Redação de informações sensíveis nos logs

## Pré-requisitos

- macOS 13 ou superior
- Xcode com suporte a Swift 6.3
- Swift 6.3
- Permissões e política OCI adequadas para Object Storage

## Como abrir no Xcode

Como o projeto foi organizado como Swift Package executável com SwiftUI:

1. Execute `./scripts/xcode_doctor.sh` para validar o ambiente.
2. Se o terminal ainda estiver apontando para `CommandLineTools`, rode:
   `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
3. Abra o package com `./scripts/open_in_xcode.sh`
4. Aguarde a indexação do package.
5. No Xcode, selecione o produto executável `OCIObjectStorageExplorer`.
6. Rode com `Run`.

### Observação importante

Se o `xcodebuild` ou `xed` falharem com mensagem parecida com:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

isso não é erro do projeto. Significa apenas que o macOS ainda está usando Command Line Tools em vez do `Xcode.app` como developer directory ativo.

## Como buildar

### Via Xcode

Use o esquema do app e execute `Build`.

### Via terminal

```bash
swift build
```

Observação: se o ambiente local estiver apontando para Command Line Tools com toolchain/SDK incompatíveis, pode ser necessário corrigir a seleção do Xcode/developer directory antes do build.

## Como executar

```bash
swift run OCIObjectStorageExplorer
```

Em ambiente Xcode, basta rodar o target do app.

## Como gerar o `.app`

Depois do build release, gere o bundle final com:

```bash
swift build -c release
./scripts/package_app.sh
```

Saída esperada:

```text
dist/OCI Object Storage Explorer.app
```

O usuário final pode arrastar esse `.app` para `Applications`.

## Configuração de autenticação no OCI

### Passos gerais

1. Gere ou use uma chave API associada ao usuário OCI.
2. Cadastre a chave pública no usuário OCI.
3. Copie para o app:
   - Tenancy OCID
   - User OCID
   - Fingerprint
   - Region
   - Namespace, se quiser informar manualmente
4. Importe o arquivo PEM privado no app.
5. Informe o compartment padrão para listagem/criação de buckets.
6. Clique em `Testar conexão`.
7. Clique em `Conectar`.

### Sobre o compartment padrão

O fluxo principal do explorer usa um compartment padrão para listagem/criação de buckets. Se ele não for preenchido, o app usa o `Tenancy OCID` como fallback.

## Exemplo de fluxo de uso

1. Criar ou selecionar um perfil salvo.
2. Importar a chave PEM privada.
3. Testar a conexão.
4. Conectar.
5. Escolher um bucket na sidebar.
6. Navegar pelos prefixos usando breadcrumb.
7. Fazer upload para a pasta virtual atual.
8. Selecionar objetos e baixar para uma pasta local.
9. Criar um PAR para bucket ou objeto selecionado.
10. Acompanhar fila e diagnósticos quando necessário.

## Testes incluídos

- Persistência de perfis em disco
- Fluxo de conexão no `AuthenticationViewModel`
- Filtro de objetos no `ExplorerViewModel`

Os testes usam mocks para a camada de serviço e Keychain em memória.

## Limitações conhecidas

- A listagem de buckets usa um compartment padrão, em vez de varrer toda a árvore de compartments/tenancy.
- Suporte completo a PEM criptografado com passphrase ainda não está finalizado no importador RSA atual.
- Multipart upload ainda não foi implementado; uploads grandes usam `PUT` direto.
- Rename/copy de objetos ainda não foram finalizados.
- Preview de arquivos ainda é um placeholder funcional para evolução futura.
- Refresh automático e múltiplas janelas ainda não foram adicionados.

## Próximos passos sugeridos

- Multipart upload para arquivos grandes
- Suporte completo a chaves PEM criptografadas
- Importação automática de `~/.oci/config`
- Renomear objeto via `renameObject` ou `copy + delete`
- Preview de texto, JSON e imagens pequenas
- Navegação expandida por compartments via Identity API
- Busca remota incremental com paginação mais sofisticada
- Drag and drop direto no browser de objetos
- Histórico persistente de operações

## Segurança

- Segredos não são persistidos em texto puro.
- Logs são sanitizados.
- Timeouts HTTP estão configurados.
- Erros são apresentados de forma amigável sem expor material sensível.

## Observações de implementação

- O projeto foi estruturado para ser evoluído em módulos.
- Onde um fluxo mais profundo não foi finalizado, a base foi deixada preparada com tipos, protocolos e separação de responsabilidades para continuação profissional.
