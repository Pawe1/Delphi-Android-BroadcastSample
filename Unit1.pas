unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.StdCtrls,
  Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.JavaTypes,
  Androidapi.Helpers, FMX.Controls.Presentation;

type
  // JString �� Androidapi.JNI.JavaTypes ��
  // JIntent �� Androidapi.JNI.GraphicsContentViewText ��
  // JStringToString �� Androidapi.Helpers ��
  // ���ꂼ���`����Ă��܂�
  TForm1 = class(TForm)
    btnRegister: TButton;
    procedure btnRegisterClick(Sender: TObject);
  private
    procedure Received(const iAction: JString);
  public
  end;

var
  Form1: TForm1;

implementation

uses
  Android.BroadcastReceiver;

{$R *.fmx}

{ TForm1 }

procedure TForm1.btnRegisterClick(Sender: TObject);
var
  TSL: TStrings;
begin
  BroadcastReceiver.OnReceived := Received;

  // �X�N���[�� ON / OFF ���󂯎��悤�ɐݒ�
  BroadcastReceiver.AddAction(
    [
      TJIntent.JavaClass.ACTION_SCREEN_OFF,
      TJIntent.JavaClass.ACTION_SCREEN_ON
    ]
  );
end;

procedure TForm1.Received(const iAction: JString);
begin
  Log.d('Broadcast Received = ' + JStringToString(iAction));
end;

end.
