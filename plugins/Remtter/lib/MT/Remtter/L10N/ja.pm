package MT::Remtter::L10N::ja;

use strict;
use base qw/ MT::Remtter::L10N MT::L10N MT::Plugin::L10N /;
use vars qw( %Lexicon );

our %Lexicon = (
    # new remtter.tmpl
    'Available Remtter.' => 'リムーブされたらメール通知します(OAuth 対応)。<br />run-periodic-tasks の実行によって動作します。',
    'Settings for OAuth' => 'Twitter 認証に関する設定',
    'Register' => '登録する',
    'Register an Application' => 'アプリケーションの登録',
    'Click to register remtter' => 'クリックして Remtter を登録してください。',
    'Please copy and paste from registered screen.' => '以下の入力欄には、登録後に表示される画面からコピー&ペーストしてください',
    'Please input following url at \'Callback URL\'' => '「コールバック URL」の欄には以下の URL を入力してください',
    'Please check \'Read & Write\' at \'Default Access type\'' => '「Default Access type」では、「Read & Write」をチェックしてください',
    'Copy and paste from twitter registration.' => 'Twitter のアプリケーション登録結果画面からコピー&ペーストしてください',
    'Your Consumer key' => 'Consumer key',
    'Your Consumer secret' => 'Consumer secret',
    'Callback URL' => 'Callback URL',
    'Get' => '取得する',
    'Get Access token' => 'Token の取得',
    'Access to get token' => 'クリックして Token を取得してください。',
    'Get token, following is filled in by auto.' => 'Token の取得により以下の設定は自動的に取得されます',
    'Your Twitter Access token' => 'Access token',
    'Your Twitter Access secret' => 'Access secret',
    'Test post with your OAuth token' => 'テスト投稿',
    'Click to test post' => 'クリックするとテスト投稿します',
    'Settings for Flickr' => 'Flickr に関する設定',
    'Flickr ID' => 'Flickr の ID',
    'Comma district switching off, space is removed at posting.' => 'カンマ区切り(スペースは取り除かれます)',
    'Must be include http://' => 'http:// を含む形式である必要があります。',
    'If you don\'t have special reason, Plase use this' => '特別な理由がない限り以下を使用してください',
    'ex' => '例',
    'Click to check bit.ly API' => 'bit.ly の API key を確認する',
    'Test post success!' => 'テスト投稿に成功しました',
    'Please check your twitter.' => 'テスト投稿に成功しました。認証情報は正しく設定されています。',
    'Test post failed!' => 'テスト投稿に失敗しました',
    'Test post failed. Please check your settings.' => 'テスト投稿に失敗しました。設定を確認してください。',
    'OAuth failed!' => '認証に失敗しました。',
    'OAuth failed. Please check your settings' => '認証に失敗しました。設定を確認してください。',
    'Get Access Token Success!' => '認証に成功しました。',
    'Get Access Token Success! <a href="[_1]">The setting is completed a little more.</a>.' => '認証に成功しました。<a href="[_1]">設定はもう少しで完了します。</a>',
    'Get Access Token Success! <a href="[_1]">click to test post</a>.' => '認証に成功しました。<a href="[_1]">テスト投稿してみましょう。</a>',
    'Get Access Token failed!' => '認証に失敗しました。',
    'Error update twitter: [_1]' => 'つぶやきに失敗しました: [_1]',
    'Getting RSS failed.' => 'RSS の取得に失敗しました。',
    'Tweet format' => 'つぶやきのフォーマット',
    'Update twitter success: [_1]' => 'つぶやきました: [_1]',
    'Settings for mail' => 'メールに関する設定',
    'Mail subject' => '件名',
    'Mail body' => '本文',
    'Mail from' => '送信元',
    'Mail to' => '送信先',
    'Separated by comma' => 'カンマ区切り',
    'One setting per line' => '一行ずつ',
    'No remover.' => 'リムーブされていません。',
    'No remover. Follower: [_1]' => 'リムーブされていません(フォロワー数: [_1])。',
    'Others' => 'その他',
    'Status(at last task)' => '前回の実行時のステータス',
    'Follower number' => 'フォロワー数',
    'Removed by [_1]' => '[_1] にリムーブされました。',

    # Remtter.pl
    'Remtter Task' => 'Remtter のタスク',
    'This post is test for Remtter' => 'Remtter からのテストポスト',
    'Tweet' => 'つぶやき',
    'Tweet list' => '一覧',
    'Error get followers ids: [_1]' => 'フォロワー ID が取得できませんでした: [_1]',
    
    
    # test
    '__test__' => 'Remtter からのテストポスト http://google.com/ http://yahoo.com/',
    '__test2__' => '8ストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中テストポストを実行中12345',
);

1;
