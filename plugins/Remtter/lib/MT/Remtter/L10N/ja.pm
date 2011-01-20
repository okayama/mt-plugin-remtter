package MT::Remtter::L10N::ja;

use strict;
use base qw/ MT::Remtter::L10N MT::L10N MT::Plugin::L10N /;
use vars qw( %Lexicon );

our %Lexicon = (
    'Available Remtter.' => 'リムーブされたことをメール通知します(OAuth 対応)。<br />run-periodic-tasks の実行によって動作します。',
    'Failed to get response from [_1], ([_2])' => '[_1]から応答を得られません。([_2])',
    'Authorize error' => '認証エラー',
    'Authorize this plugin and enter the PIN#.' => 'このプラグインを認証してから、PIN番号を入力してください。',
    'Get PIN#' => 'PIN番号を取得する',
    'Done' => '実行',
    'Authentication' => '認証',
    'OAuth authentication' => 'OAuthによる認証',
    'Authentication succeeded' => '認証に成功しました',
    'Authentication failed' => '認証に失敗しました',
    'Settings for Twitter' => 'Twitter に関する設定',
    'Settings for mail' => 'メールに関する設定',
    'Settings for direct message' => 'ダイレクトメッセージに関する設定',
    'Message body' => '本文',
    'Mail subject' => '件名',
    'Mail body' => '本文',
    'Mail from' => '送信元',
    'Mail to' => '送信先',
    'One setting per line' => '一行にひとつ入力してください',
    'No remover. Follower: [_1]' => 'リムーブされていません(フォロワー数: [_1])。',
    'Others' => 'その他',
    'Status(at last task)' => '前回の実行時のステータス',
    'Follower number' => 'フォロワー数',
    'Removed by [_1]' => '[_1] にリムーブされました。',
    'Send direct message success: [_1]' => 'ダイレクトメッセージを送信しました: [_1]',
    'Remtter Task' => 'Remtter のタスク',
    'Error get followers ids: [_1]' => 'フォロワー ID が取得できませんでした: [_1]',
    'Error get screen name of user [_1]: [_2]' => 'ユーザ ID [_1] のユーザ名が取得できませんでした: [_2]',
);

1;
