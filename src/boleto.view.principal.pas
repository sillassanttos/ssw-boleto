unit boleto.view.principal;

{$MODE DELPHI}{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  Graphics,
  Dialogs,
  ComCtrls,
  ExtCtrls,
  StdCtrls,
  IniFiles,
  rxspin,
  rxctrls,
  Horse,
  //Horse.Jhonson,
  //Horse.HandleException,
  //Horse.OctetStream,
  Horse.Logger,
  Horse.Logger.Provider.LogFile,
  //DataSet.Serialize,
  //DataSet.Serialize.Config,
  boleto.util.biblioteca,
  boleto.controller;

type
  TPrincipalView = class(TForm)
    btnIniciar: TButton;
    pnlTitulo: TPanel;
    pnlCentral: TPanel;
    lblPorta: TRxLabel;
    edtPorta: TRxSpinEdit;
    stbPrincipal: TStatusBar;
    procedure btnIniciarClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  LLogFileConfig: THorseLoggerLogFileConfig;
  PrincipalView: TPrincipalView;

implementation

{$R *.lfm}

procedure TPrincipalView.FormCreate(Sender: TObject);
begin
  with TIniFile.Create(ChangeFileExt('boleto', '.ini')) do
  try
    GCaptionApp := ReadString('Licenca', 'Caption', '');
    GTituloApp := ReadString('Licenca', 'Titulo', '');
    GPrefixo := ReadString('API', 'Prefixo', 'ssw/boleto/');
    edtPorta.Value := ReadInt64('Servidor', 'Porta', 8883);
    stbPrincipal.Panels[0].Text := Concat('Licenciado para: ', ReadString('Licenca', 'Licenciado', ''));
  finally
    Free;
  end;

  Self.Caption := GCaptionApp;

  pnlTitulo.Caption := GTituloApp;

  LLogFileConfig := THorseLoggerLogFileConfig
    .New
      .SetDir(ExtractFilePath(ParamStr(0)) + 'Log\');

  THorseLoggerManager.RegisterProvider(THorseLoggerProviderLogFile.New());

  THorse
    //.Use(Jhonson())
    //.Use(HandleException)
    //.Use(OctetStream)
    .Use(THorseLoggerManager.HorseCallback);

  TBoletoController.Registry;
end;

procedure TPrincipalView.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if THorse.IsRunning then
    THorse.StopListen;
end;

procedure TPrincipalView.btnIniciarClick(Sender: TObject);
begin
  if edtPorta.Value <= 0 then
    raise Exception.Create('Informe uma Porta Válida!');

  if Trim(btnIniciar.Caption).Equals('Iniciar') then
  begin
    THorse.Port := edtPorta.AsInteger;
    THorse.Listen;
    btnIniciar.Caption := 'Parar';
    Self.Caption := Concat(GTituloApp, ' [Serviço rodando na porta: ', THorse.Port.ToString, ']');
  end
  else
  begin
    THorse.StopListen;
    btnIniciar.Caption := 'Iniciar';
    Self.Caption := Concat(GTituloApp, ' [Servidor Parado]');
  end;
end;

end.

