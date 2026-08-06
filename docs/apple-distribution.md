# Apple Developer署名とnotarizationの設定

GitHub ActionsからMarinaを直接配布するために、Developer ID Application証明書で署名し、Appleのnotary serviceへ提出します。notarizationがAcceptedになった後、ticketを`Marina.app`へstapleしてから配布用ZIPとchecksumを作り直します。

## 必要なApple Developer資材

Apple Developer ProgramのAccount Holderが次を準備します。

1. `Developer ID Application`証明書
2. 証明書と秘密鍵を含むpassword付き`.p12`ファイル
3. App Store ConnectのTeam API Key（`.p8`）
4. Apple Developer Team ID
5. API Key IDとIssuer ID

`Developer ID Installer`証明書は不要です。Marinaはinstaller packageではなくZIPで配布します。

## Developer ID Application証明書

1. Apple DeveloperのCertificates, Identifiers & Profilesを開きます。
2. Certificatesの追加画面でDeveloper IDを選びます。
3. `Developer ID Application`を作成してMacのKeychainへinstallします。
4. Keychain Accessの「自分の証明書」で、証明書と秘密鍵を一緒に選択して`.p12`へexportします。
5. export時に設定したpasswordを安全に保管します。

Keychainへ正しくinstallされると、次のコマンドに`Developer ID Application: ... (TEAM_ID)`が1件表示されます。

```sh
security find-identity -v -p codesigning
```

## App Store Connect API Key

App Store Connectの「ユーザとアクセス」からTeam API Keyを作成します。秘密鍵の`.p8`は一度しかdownloadできないため、安全な場所へ保管してください。Key IDとIssuer IDも記録します。

workflowはTeam API Keyを使用するため、Issuer IDが必要です。Individual API Keyはこの設定では使用しません。

## GitHub Repository Variables

`keishingu/Marina`のSettings > Secrets and variables > Actions > Variablesへ次を登録します。

| Name | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Developer ID Application証明書のTeam ID |
| `APP_STORE_CONNECT_KEY_ID` | Team API KeyのKey ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Team API KeyのIssuer ID |

GitHub CLIを使う場合：

```sh
gh variable set APPLE_TEAM_ID --repo keishingu/Marina
gh variable set APP_STORE_CONNECT_KEY_ID --repo keishingu/Marina
gh variable set APP_STORE_CONNECT_ISSUER_ID --repo keishingu/Marina
```

各コマンドのpromptへ値を入力します。

## GitHub Repository Secrets

同じ画面のSecretsへ次を登録します。

| Name | Value |
| --- | --- |
| `DEVELOPER_ID_APPLICATION_P12_BASE64` | `.p12`全体をbase64化した値 |
| `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | `.p12`のexport password |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | `.p8`全体をbase64化した値 |

GitHub CLIを使う場合、秘密値をcommand line引数へ含めず標準入力から登録します。

```sh
base64 -i DeveloperIDApplication.p12 \
  | gh secret set DEVELOPER_ID_APPLICATION_P12_BASE64 --repo keishingu/Marina

gh secret set DEVELOPER_ID_APPLICATION_P12_PASSWORD --repo keishingu/Marina

base64 -i AuthKey_KEYID.p8 \
  | gh secret set APP_STORE_CONNECT_API_KEY_P8_BASE64 --repo keishingu/Marina
```

passwordは2番目のコマンドが表示するpromptへ入力します。`.p12`、`.p8`、password、base64文字列をrepositoryへcommitしないでください。

## Release workflow

`main`へのpushで次を実行します。

1. 必須VariablesとSecretsの存在確認
2. 一時Keychainの作成とDeveloper ID Application証明書のimport
3. テスト
4. Universal binaryのbuild
5. Hardened Runtimeとsecure timestamp付きDeveloper ID署名
6. ZIPを`notarytool submit --wait`で送信
7. `Accepted`の明示確認
8. notarization ticketのstapleと検証
9. staple済みアプリからZIPとchecksumを再生成
10. GitHub Releaseの公開
11. 一時Keychainの削除

設定が不足している場合やnotarizationがAccepted以外の場合は、Releaseを公開せずworkflowを失敗させます。

## 配布物の確認

GitHub ReleaseからZIPをdownloadして展開した後、次を実行します。

```sh
codesign --verify --deep --strict --verbose=2 Marina.app
spctl --assess --type execute --verbose=4 Marina.app
xcrun stapler validate Marina.app
```

`codesign`が成功し、`spctl`が`accepted`、`stapler`がvalidation successを返すことを確認します。

## 公式資料

- [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [GitHub Actions secrets](https://docs.github.com/en/actions/concepts/security/secrets)
