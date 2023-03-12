program boleto;

{$MODE DELPHI}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces,
  Forms,
  zcomponent,
  indylaz,
  rxnew,
  boleto.view.principal,
  boleto.util.converte.arquivo.base64,
  boleto.util.biblioteca,
  boleto.util.terceiro.j4dl,
  boleto.database,
  boleto.controller;

{$R *.res}

begin
  RequireDerivedFormResource := True;

  Application.Scaled := True;

  Application.Initialize;

  Application.CreateForm(TPrincipalView, PrincipalView);

  Application.Run;
end.

