# Marina Design System

## Direction

夜間や日中の開発作業中、メニューバーから数秒だけ開く計器盤。システムMaterialの背景に、冷たい港の信号灯を思わせる青を操作色として使い、緑・橙・赤は状態表示だけに使う。

## Color

- Surface: macOSの`.regularMaterial`とシステム背景色。独自の固定背景色は持たない。
- Primary: system blue。更新、選択、フォーカスなど操作上の意味だけに使う。
- Success: system green。正常なLISTEN状態。
- Warning: system orange。Dockerの利用不可や部分的な取得失敗。
- Error: system red。ポート取得や操作の失敗。
- Text: `.primary` / `.secondary` / `.tertiary` を使い、light/darkのコントラストをOSへ委ねる。

## Typography

SF Pro（システムフォント）のみを使用する。タイトルはheadline、サービス名はsubheadline semibold、メタデータはcaption。ポート番号、PID、更新時刻にはmonospaced digitを使用する。

## Layout

パネル幅420pt、最大高560pt。4pt基準の8/12/16/24ptスケールを使う。ヘッダーは16pt、各行は12ptの水平余白と10ptの垂直余白。サービス情報とポート番号を左右に分け、補足情報は最大2行へ畳む。

## Components

- Header: Marinaアイコン、名称、件数、更新、設定。
- Port row: 状態、サービスアイコン、主要ラベル、メタデータ、monospaced port、アクションメニュー。
- Error banner: アイコン、具体的な失敗理由、再試行。Docker警告は一覧を覆わない。
- Empty state: 錨アイコンと短い学習的コピー。
- Confirmation: プロセス終了とDocker操作に対象名を明示する標準alert。

## Interaction

更新中も既存一覧を維持し、更新ボタンだけで進行を示す。行選択は詳細表示、コンテキストメニューはコピー・ブラウザ・詳細・危険操作を区切る。アニメーションは状態遷移の短いフェードに限定し、Reduce Motion時は無効化する。
