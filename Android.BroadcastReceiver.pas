﻿unit Android.BroadcastReceiver;

interface

uses
  System.Classes
  , System.Generics.Collections
  , FMX.Platform
  , Androidapi.JNIBridge
  , Androidapi.JNI.App
  , Androidapi.JNI.Embarcadero
  , Androidapi.JNI.GraphicsContentViewText
  , Androidapi.JNI.JavaTypes
  , Androidapi.Helpers
  ;

type
  // 直接 class(TJavaLocal, JFMXBroadcastReceiverListener) を定義するとダメ！
  // グローバル変数にインスタンスをつっこんでも削除されて、Broadcast 受信で
  // アプリが落ちる！
  // なので、TInterfacedObject を継承していないクラスから派生したクラスの
  // インナークラスとして JFMXBroadcastReceiverListener を定義する
  // このクラスは自動的に削除されないため、上手く動作する！
  TBroadcastReceiver = class
  public type
    // Broadcast Receiver を通知するイベント
    // JString にしているので、Intent.ACTION_XXX と equals で比較可能
    TBroadcastReceiverEvent = procedure(const iAction: JString) of object;
    // JFMXBroadcastReceiver を実装した JavaClass として Listener を定義
    TBroadcastReceiverListener =
      class(TJavaLocal, JFMXBroadcastReceiverListener)
    private var
      FBroadcastReceiver: TBroadcastReceiver;
    public
      constructor Create(const iBroadcastReceiver: TBroadcastReceiver);
      // Broadcast Receiver から呼び出されるコールバック
      procedure onReceive(context: JContext; intent: JIntent); cdecl;
    end;
  private var
    // つぎの２つは保存しないと消えて無くなる！
    FBroadcastReceiverListener: JFMXBroadcastReceiverListener;
    FReceiver: JFMXBroadcastReceiver;
    // 通知対象の ACTION を保持している変数
    FActions: TList<String>;
    // イベントハンドラ
    FOnReceived: TBroadcastReceiverEvent;
  protected
    constructor Create;
    // Broadcast Receiver の設定と解除
    procedure SetReceiver;
    procedure UnsetReceiver;
  public
    destructor Destroy; override;
    // 通知して欲しい ACTION の登録と削除
    procedure AddAction(const iActions: array of JString);
    procedure RemoveAction(const iAction: JString);
    procedure ClearAction;
    // Boradcast Receiver を受け取った時のイベント
    property OnReceived: TBroadcastReceiverEvent
      read FOnReceived write FOnReceived;
  end;

// Boradcast Receiver のインスタンスを返す
function BroadcastReceiver: TBroadcastReceiver;

implementation

uses
  System.UITypes, System.SysUtils
  , Androidapi.NativeActivity
  , FMX.Forms
  , FMX.Types
  ;

// Braodcast Receiver の唯一のインスタンス
var
  GBroadcastReceiver: TBroadcastReceiver = nil;

function BroadcastReceiver: TBroadcastReceiver;
begin
  if (GBroadcastReceiver = nil) then
    GBroadcastReceiver := TBroadcastReceiver.Create;

  Result := GBroadcastReceiver;
end;

{ TBroadcastReceiver.TBroadcastReceiverListener }

constructor TBroadcastReceiver.TBroadcastReceiverListener.Create(
  const iBroadcastReceiver: TBroadcastReceiver);
begin
  inherited Create;
  FBroadcastReceiver := iBroadcastReceiver;
end;

procedure TBroadcastReceiver.TBroadcastReceiverListener.onReceive(
  context: JContext;
  intent: JIntent);
var
  JStr: String;
  Str: String;

  procedure CallEvent;
  var
    Action: String;
  begin
    // Broadcast は Delphi のメインスレッドで届くわけでは無いので
    // Synchronize で呼び出す
    Action := JStr;
    TThread.CreateAnonymousThread(
      procedure
      begin
        TThread.Synchronize(
          TThread.CurrentThread,
          procedure
          begin
            if (Assigned(FBroadcastReceiver.FOnReceived)) then
              FBroadcastReceiver.FOnReceived(StringToJString(Action));
          end
        );
      end
    ).Start;
  end;

begin
  // Broadcast を受け取ったら、このメソッドが呼ばれる！
  JStr := JStringToString(intent.getAction);

  for Str in FBroadcastReceiver.FActions do
    if (Str = JStr) then
      CallEvent;
end;

{ TReceiverListener }

procedure TBroadcastReceiver.AddAction(const iActions: array of JString);
var
  Str: String;
  JStr: String;
  Action: JString;
  OK: Boolean;
  Changed: Boolean;
begin
  Changed := False;

  for Action in iActions do
  begin
    OK := True;

    JStr := JStringToString(Action);

    for Str in FActions do
      if (Str = JStr) then
      begin
        OK := False;
        Break;
      end;

    if (OK) then begin
      FActions.Add(JStr);
      Changed := True;
    end;
  end;

  if (Changed) then
    SetReceiver;
  Log.d('Exiting AddAction');
end;

procedure TBroadcastReceiver.ClearAction;
begin
  FActions.Clear;
  UnsetReceiver;
end;

constructor TBroadcastReceiver.Create;
begin
  inherited;

  FActions := TList<String>.Create;

  // Boardcast Receiver を設定
  SetReceiver;
end;

destructor TBroadcastReceiver.Destroy;
begin
  // Broadcast Receiver を解除
  UnsetReceiver;

  FActions.DisposeOf;

  inherited;
end;

procedure TBroadcastReceiver.RemoveAction(const iAction: JString);
var
  i: Integer;
  JStr: String;
begin
  JStr := JStringToString(iAction);

  for i := 0 to FActions.Count - 1 do
    if (FActions[i] = JStr) then
    begin
      FActions.Delete(i);
      SetReceiver;
      Break;
    end;
end;

procedure TBroadcastReceiver.SetReceiver;
var
  Filter: JIntentFilter;
  Str: String;
begin
  if (FReceiver <> nil) then
    UnsetReceiver;

  // Intent Filter を作成
  Filter := TJIntentFilter.JavaClass.init;

  for Str in FActions do
    Filter.addAction(StringToJString(Str));

  // TBroadcastReceiverListener を実体とした BroadcastReceiver を作成
  Log.d('TBroadcastReceiverListener.Create');
  FBroadcastReceiverListener := TBroadcastReceiverListener.Create(Self);
  Log.d('TJFMXBroadcastReceiver.init');
  FReceiver :=
    TJFMXBroadcastReceiver.JavaClass.init(FBroadcastReceiverListener);

  try
    // レシーバーとして登録
    Log.d('register receiver');
    SharedActivityContext.getApplicationContext.registerReceiver(
      FReceiver,
      Filter);
  except
    on E: Exception do
      Log.d('Exception: %s', [E.Message]);
  end;
  Log.d('Exiting SetReceiver');
end;

procedure TBroadcastReceiver.UnsetReceiver;
begin
  // アプリケーションが終了中でなければ、BroadcastReceiver を解除
  if
    (FReceiver <> nil) and
    (not (SharedActivityContext as JActivity).isFinishing)
  then
    try
      SharedActivityContext.getApplicationContext.unregisterReceiver(FReceiver);
    except
    end;

  FReceiver := nil;
end;

initialization
finalization
  if (GBroadcastReceiver <> nil) then
    GBroadcastReceiver.DisposeOf;

end.
