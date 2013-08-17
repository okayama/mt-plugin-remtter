package Remtter::L10N::ja;
use strict;
use base qw( Remtter::L10N MT::L10N MT::Plugin::L10N );
use vars qw( %Lexicon );

our %Lexicon = (
    'Available Remtter.' => 'タスク実行によって自動的に Twitter アカウントがリムーブ/アンフォローされたことをメールまたはダイレクトメッセージで通知します。',
    'Remtter Task' => 'Remtter のタスク',
    'Failed to get response from [_1], ([_2])' => '[_1]から応答を得られません。([_2])',
    'Authorize error' => '認証エラー',
    'Authorize this plugin and enter the PIN#.' => 'アプリケーションの認証を行い、取得されるPIN番号を入力してください。',
    'Get authentication' => '認証を行う',
    'Done' => '実行',
    'Authentication' => '認証',
    'You need authentication about Twitter.' => 'Twitter への認証を行う',
    'Authentication finished.' => '認証が完了しました。ダイアログを閉じると画面の再読み込みが行われます。',
    'Authentication failed.' => '認証に失敗しました。',
    'Already authenticated.' => 'すでに認証されています。',
    'Get authentication again.' => '再度認証を行う',
    'Settings for Twitter' => 'Twitter に関する設定',
    'Settings for mail' => 'メールに関する設定',
    'Notification by mail' => 'メールによる通知',
    'Settings for log' => 'ログに関する設定',
    'Settings for direct message' => 'ダイレクトメッセージに関する設定',
    'Notification by direct message' => 'ダイレクトメッセージに<br />よる通知',
    'Enable' => '有効',
    'Message body' => '本文',
    'Mail subject' => '件名',
    'Mail body' => '本文',
    'Mail from' => '送信元',
    'Mail to' => '送信先',
    'One setting per line' => '一行につきひとつの設定を入力してください',
    'No remover. Follower: [_1]' => 'リムーブされていません(フォロワー数: [_1])。',
    'Others' => 'その他',
    'Status(at last task)' => '前回の実行時のステータス',
    'Follower number' => 'フォロワー数',
    'Removed by [_1]' => '[_1] にリムーブされました。',
    '[_1] was(were) suspended' => '[_1] は停止されました。',
    'Send direct message success: [_1]' => 'ダイレクトメッセージを送信しました: [_1]',
    'Remtter Task' => 'Remtter のタスク',
    'Error get followers ids: [_1]' => 'フォロワー ID が取得できませんでした: [_1]',
    'Error get screen name of user [_1]: [_2]' => 'ユーザ ID [_1] のユーザ名が取得できませんでした: [_2]',
    'Result log' => '実行ログ',
    'Loging' => 'ログを残す',
    'If this setting is on, write to log about being removed or followers num, per execute.' => 'チェックすると、実行の度にフォロワー数またはリムーブされたことをログに残します。',
);

1;
