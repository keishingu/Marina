<p align="center">
  <img src="Marina/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" width="160" alt="Marina app icon">
</p>

<h1 align="center">Marina</h1>

<p align="center">
  <a href="README.md">English</a> | 日本語
</p>

Marinaは、ローカルで待ち受けているTCPポート、その所有プロセス、推定されるサービス種別、Docker/Composeのポートマッピングを、コンパクトなパネルにまとめて表示するmacOSネイティブのメニューバーユーティリティです。

![Marinaの待ち受けポート一覧](docs/marina-panel.png)

このスクリーンショットは、固定されたテストデータを使って本番のSwiftUI Viewから生成しています。同じテストで[ライトモード版](docs/marina-panel-light.png)も生成されます。実際のパネルには、使用中のMacから取得した`lsof`とDockerのデータが表示されます。

## 動作要件

- macOS 14 Sonoma以降
- Xcode 15以降（Xcode 26.3で動作確認済み）
- コンテナ情報を表示する場合はDocker CLIと起動中のDockerデーモン（通常のポートスキャンはDockerなしでも動作します）

## ダウンロード

[GitHub Releases](https://github.com/keishingu/Marina/releases/latest)から最新の`Marina-macos-universal.zip`をダウンロードして展開し、`Marina.app`をアプリケーションフォルダへ移動してください。UniversalビルドはApple SiliconとIntel Macの両方に対応し、Marinaのアプリアイコンも含まれています。

配布ビルドはDeveloper ID Application証明書で署名され、Appleのnotarization（公証）を受けています。公証ticketも`Marina.app`へstapleされているため、通常のアプリと同じようにFinderから起動できます。

Pull Requestのマージを含め、`main`へpushされるたびにリリース構成がビルドされ、バージョン付きのGitHub Releaseが自動公開されます。ZIPと一緒に`Marina-macos-universal.zip.sha256`としてチェックサムも提供されます。

## ビルドとテスト

`Marina.xcodeproj`を開き、`Marina`スキームを選択して実行してください。Marinaは`LSUIElement`アプリのため、Dockではなくメニューバーに表示されます。

コマンドラインでのビルド：

```sh
xcodebuild \
  -project Marina.xcodeproj \
  -scheme Marina \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

テスト：

```sh
xcodebuild \
  -project Marina.xcodeproj \
  -scheme Marina \
  -configuration Debug \
  -destination 'platform=macOS' \
  test
```

## アーキテクチャ

```text
Marina/
├── App/                    MenuBarExtra、共有状態、設定
├── Features/Ports/         一覧、行、詳細、ViewModel
├── Core/
│   ├── CommandRunner/      Processベースのコマンド境界と操作
│   ├── DockerResolver/     Docker JSON解析、利用可否、照合
│   ├── Models/             Listener、プロセス、サービス、コンテナのモデル
│   ├── PortScanner/        lsofフィールド解析と正規化
│   ├── ProcessResolver/    ps/lsofによるプロセスメタデータの補完
│   ├── ServiceResolver/    控えめなサービス推定
│   └── TunnelResolver/     ngrok/Cloudflareの公開元照合
└── DesignSystem/           サービスロゴ、SF Symbolフォールバック、状態表示
```

SwiftUIは表示だけを担当します。外部コマンドは`CommandRunning`の背後に配置し、パーサとリゾルバは値型としてテストデータで検証できます。`PortListViewModel`はポートとDockerのスキャンを並行実行し、更新処理の重複を防ぎます。また、後続のDocker更新が失敗した場合は、直前に取得できたDockerコンテナデータを保持します。

## ポート検出

Marinaは`Foundation.Process`を介して、明示的な引数とともに`/usr/sbin/lsof`を実行します。

```text
-nP -iTCP -sTCP:LISTEN -F0pcuLftnPT
```

`-F0`は表示用の表ではなく、NUL区切りのフィールドを返します。Marinaはプロセス名、PID、ユーザー、エンドポイント、TCP状態、IPv4/IPv6のアドレスファミリを解析し、各PIDについて次の情報を補完します。

- `/bin/ps -p <pid> -o ppid= -o command=`
- `/usr/sbin/lsof -a -p <pid> -d txt -Fn`
- `/usr/sbin/lsof -a -p <pid> -d cwd -Fn`

同じPID、ホストポート、プロトコルに属するIPv4とIPv6のソケットは、すべてのバインドアドレスとアドレスファミリを保持したまま、1つのlistenerに正規化されます。結果はポートの昇順で並びます。

## トンネル連携

Marinaは一般的な`ngrok http <port>`と`cloudflared tunnel --url <local URL>`コマンドを認識します。指定された公開元が実際にLISTEN中の場合、プロバイダーのバッジと専用メニューを公開元サービスへ表示します。ngrokのInspectorやcloudflaredのmetrics listenerは、無関係なポートとして並べず公開元へ畳み込みます。

専用メニューからプロバイダーのダッシュボードを開き、実行中のコマンドをコピーできます。ngrokがローカルのTraffic Inspectorを公開している場合は、その画面も開けます。named tunnelや公開元ポートを特定できない場合は推測せず、管理用listenerを残したままトンネル固有の警告を表示します。

## Docker連携

Marinaは標準的なHomebrew、`/usr/local`、Docker Desktopアプリケーションの各パスからDocker CLIを探し、次のコマンドを使用します。

1. `docker ps --format '{{json .}}'`で起動中のコンテナIDを列挙します。
2. 1回の`docker inspect <id>…`で、正式なコンテナ状態、イメージ、ポートバインディング、ラベルを取得します。

inspect JSONからホストIP/ポート、コンテナポート、プロトコル、実行状態、次のComposeラベルを取得します。

- `com.docker.compose.project`
- `com.docker.compose.service`
- `com.docker.compose.container-number`
- `com.docker.compose.project.working_dir`
- `com.docker.compose.project.config_files`

TCPホストポートと互換性のあるバインドIPを各`ListeningPort`と照合します。ワイルドカードバインドは具体的なDockerホストIPと互換とみなします。複数のコンテナが一致した場合は候補を明示し、Marinaが黙って1つを選ぶことはありません。1つだけ一致した場合は、`com.docker.backend`のような表示をCompose/コンテナ情報に置き換えます。

Docker Desktopが必要なのは、Docker情報の補完またはコンテナ操作を使う場合だけです。CLIが見つからない、デーモンが停止している、権限がない、JSONが不正といった問題はDocker固有の警告として表示し、通常のlistenerは引き続き表示します。

## サービスロゴと第三者商標

認識したサービスにはSimple Icons 16.21.0のモノクロまたは控えめなブランドカラーのSVGマークを使用します。不明なサービスには引き続きSF Symbolを使い、Dockerの状態は別のshipping-boxバッジで示すため、ブランドカラーだけに状態表示を依存しません。

Simple IconsはCC0-1.0で配布されていますが、個別のマークには著作権、商標、所有者の利用条件が引き続き適用される場合があります。Marinaは検出した技術を識別する目的にのみ使用し、推奨、提携、後援を示すものではありません。[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)と、`Marina/Resources/Licenses`に同梱されたSimple Iconsのライセンスおよび免責事項を参照してください。

## App Sandboxと権限

MVPではApp Sandboxを無効にしています。システムのプロセスメタデータ、`/usr/sbin/lsof`、`/bin/ps`、Docker CLI、Docker Desktopのデーモンエンドポイントへ確実にアクセスすることが製品の中核機能であり、一般的なsandboxアプリではこれらの操作が制限されるか、現実的に実装できないためです。

これに伴う方針は次のとおりです。

- 現在のビルドはMac App Storeではなく、直接配布とDeveloper ID notarizationを想定しています。
- Marinaは`sudo`を実行せず、ユーザー入力をshellへ展開せず、環境変数をログへ記録しません。
- コマンドには固定された実行ファイルURLと明示的な引数配列を使用します。
- PIDとコンテナIDは、破壊的操作の直前に同一性を再確認します。
- プロセス終了時は最初に`SIGTERM`を送り、`SIGKILL`は別の明示的操作として提供します。
- Dockerの停止と再起動は設定に応じて確認します。`docker kill`は提供しません。
- 権限エラーは表示し、架空のデータへ置き換えません。

将来のsandbox対応案としては、限定的なXPC contractを持つ個別インストール・署名済みhelper、真に必要な場合のみ使うprivileged helper、ユーザーが許可したエンドポイントを介するDocker Engine連携などがあります。どの案にも専用の脅威モデルと配布方式のレビューが必要です。

## 現在の制約

- Docker Engine APIではなくCLI JSONを使用しています。
- 表示はホストポートごとに1行です。コンテナグループ化のモデルはありますが、その表示モードが存在するまでは設定を無効にしています。
- IPv4/IPv6の重複正規化は必須です。動作を説明するため、設定項目は無効な状態で表示しています。
- アクティビティモニタを開くことはできますが、公開APIではPIDを事前選択できません。
- サービス識別はヒューリスティックであり、根拠が弱い場合は意図的にランタイムまたは`Unknown`へフォールバックします。
- `lsof`が返せるのは現在のユーザーから見えるプロセスメタデータだけです。Marinaは権限昇格を要求しません。
- このMVPにはGit、worktree、エディタ、Terminalとの関連付けはありません。

## 今後の予定

1. 制限時間付きCLIフォールバックを備えたDocker Engine API対応。
2. 複数ポートを持つサービスのコンテナ単位表示。
3. sandboxまたはMac App Store配布が必要になった場合の署名済みhelper設計。
4. メニューバー起動、確認ダイアログ、設定永続化を対象としたend-to-end UIテスト。
5. 過度な推測ではなく、根拠とバージョンを持つルールによるservice signatureの拡充。
